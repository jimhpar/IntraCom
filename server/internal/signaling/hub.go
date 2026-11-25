package signaling

import (
	"context"
	"encoding/json"
	"log"
	"strings"
	"sync"
	"time"

	"github.com/gofiber/websocket/v2"
	"intracom-server/internal/db"
)

// SignalMessage defines the standard signaling packet format for WebRTC & Hangouts
type SignalMessage struct {
	Type        string      `json:"type"`                  // call_offer, call_answer, call_ice, call_ringing, call_hangup, call_reject, hangout_join, etc.
	From        string      `json:"from,omitempty"`        // Sender's IntraCom number (e.g. +1-3847291)
	CallerName  string      `json:"caller_name,omitempty"` // Sender's display name
	To          string      `json:"to,omitempty"`          // Recipient's IntraCom number or phone
	CallType    string      `json:"call_type,omitempty"`   // audio, video
	Payload     interface{} `json:"payload,omitempty"`     // SDP offer/answer or ICE candidate
	HangoutID   string      `json:"hangout_id,omitempty"`  // Voice Hub ID
	Timestamp   int64       `json:"timestamp,omitempty"`
}

type Client struct {
	FullNumber  string
	DisplayName string
	Conn        *websocket.Conn
	Send        chan []byte
	Hub         *Hub
}

type Hub struct {
	// Registered online clients by their IntraCom number: maps fullNumber -> set of active *Client connections
	clients     map[string]map[*Client]bool
	hangoutHubs map[string]map[string]*Client // hangout_id -> map[fullNumber]*Client
	broadcast   chan []byte
	register    chan *Client
	unregister  chan *Client
	mu          sync.RWMutex
}

var GlobalHub = NewHub()

func NewHub() *Hub {
	return &Hub{
		clients:     make(map[string]map[*Client]bool),
		hangoutHubs: make(map[string]map[string]*Client),
		broadcast:   make(chan []byte),
		register:    make(chan *Client),
		unregister:  make(chan *Client),
	}
}

func (h *Hub) Run() {
	for {
		select {
		case client := <-h.register:
			h.mu.Lock()
			if h.clients[client.FullNumber] == nil {
				h.clients[client.FullNumber] = make(map[*Client]bool)
			}
			isFirstSession := len(h.clients[client.FullNumber]) == 0
			h.clients[client.FullNumber][client] = true

			onlineSnapshot := make([]string, 0, len(h.clients))
			for num := range h.clients {
				onlineSnapshot = append(onlineSnapshot, num)
			}
			sessionCount := len(h.clients[client.FullNumber])
			h.mu.Unlock()

			log.Printf("User session registered: %s (Active tabs/sessions: %d, Total online users: %d)",
				client.FullNumber, sessionCount, len(onlineSnapshot))

			// Send initial presence list to the newly connected client immediately
			initMsg := SignalMessage{
				Type:    "initial_presence",
				From:    "system",
				Payload: onlineSnapshot,
			}
			if initBytes, err := json.Marshal(initMsg); err == nil {
				select {
				case client.Send <- initBytes:
				default:
				}
			}

			if isFirstSession {
				h.broadcastPresence(client.FullNumber, "online")
			}

		case client := <-h.unregister:
			h.mu.Lock()
			var isFullyOffline bool
			if clientMap, ok := h.clients[client.FullNumber]; ok {
				delete(clientMap, client)
				close(client.Send)
				if len(clientMap) == 0 {
					delete(h.clients, client.FullNumber)
					isFullyOffline = true
				}
			}

			// Remove from any active hangout hubs
			for hubID, members := range h.hangoutHubs {
				if _, inHub := members[client.FullNumber]; inHub {
					delete(members, client.FullNumber)
					h.notifyHangoutMemberLeft(hubID, client.FullNumber)
				}
			}
			onlineCount := len(h.clients)
			h.mu.Unlock()

			if isFullyOffline {
				log.Printf("User completely offline: %s (Total online users: %d)", client.FullNumber, onlineCount)
				h.broadcastPresence(client.FullNumber, "offline")
			} else {
				log.Printf("User session closed: %s (Remaining active sessions: %d)", client.FullNumber, len(h.clients[client.FullNumber]))
			}

		case message := <-h.broadcast:
			h.mu.RLock()
			for _, clientMap := range h.clients {
				for client := range clientMap {
					select {
					case client.Send <- message:
					default:
						close(client.Send)
						delete(clientMap, client)
					}
				}
			}
			h.mu.RUnlock()
		}
	}
}

func (h *Hub) RegisterClient(client *Client) {
	h.register <- client
}

func (h *Hub) UnregisterClient(client *Client) {
	h.unregister <- client
}

// GetOnlineUsers returns a snapshot of all currently connected IntraCom numbers
func (h *Hub) GetOnlineUsers() []string {
	h.mu.RLock()
	defer h.mu.RUnlock()
	list := make([]string, 0, len(h.clients))
	for num := range h.clients {
		list = append(list, num)
	}
	return list
}

// BroadcastHubMessage relays a message to all users connected to a hangout or broadcasts system-wide
func (h *Hub) BroadcastHubMessage(hangoutID string, msg SignalMessage) {
	bytes, err := json.Marshal(msg)
	if err != nil {
		return
	}
	h.mu.RLock()
	defer h.mu.RUnlock()
	if members, ok := h.hangoutHubs[hangoutID]; ok && len(members) > 0 {
		for _, member := range members {
			select {
			case member.Send <- bytes:
			default:
			}
		}
	} else {
		// Broadcast to all connected clients
		for _, clientMap := range h.clients {
			for client := range clientMap {
				select {
				case client.Send <- bytes:
				default:
				}
			}
		}
	}
}

func cleanNumber(s string) string {
	var b strings.Builder
	for _, r := range s {
		if r >= '0' && r <= '9' {
			b.WriteRune(r)
		}
	}
	return b.String()
}

// FindClients locates all connected client sessions for a given target number or alias
func (h *Hub) FindClients(target string) []*Client {
	h.mu.RLock()
	defer h.mu.RUnlock()

	var results []*Client

	// 1. Direct exact match (e.g. "+1-1111111")
	if m, ok := h.clients[target]; ok && len(m) > 0 {
		for c := range m {
			results = append(results, c)
		}
		return results
	}

	// 2. Normalized match (strip +, -, spaces)
	cleanTarget := cleanNumber(target)
	if cleanTarget != "" {
		for num, m := range h.clients {
			cleanNum := cleanNumber(num)
			if cleanNum == cleanTarget || (len(cleanTarget) == 7 && strings.HasSuffix(cleanNum, cleanTarget)) {
				for c := range m {
					results = append(results, c)
				}
			}
		}
		if len(results) > 0 {
			return results
		}
	}

	// 3. Database lookup if target is phone number, clean digits, or subscriber portion
	if db.Pool != nil {
		ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
		defer cancel()
		var fullNumber string
		query := `
			SELECT full_number FROM users 
			WHERE phone = $1 
			   OR full_number = $1 
			   OR full_number = $2
			   OR user_number = $1
			   OR ($3 != '' AND user_number = $3)
			   OR ($3 != '' AND phone = $3)
			   OR ($3 != '' AND REPLACE(REPLACE(full_number, '+', ''), '-', '') = $3)
			   OR ($3 != '' AND full_number LIKE '%-' || $3)
			LIMIT 1
		`
		err := db.Pool.QueryRow(ctx, query, target, "+"+target, cleanTarget).Scan(&fullNumber)
		if err == nil && fullNumber != "" {
			if m, ok := h.clients[fullNumber]; ok && len(m) > 0 {
				for c := range m {
					results = append(results, c)
				}
				return results
			}
			cleanDbNum := cleanNumber(fullNumber)
			for num, m := range h.clients {
				if cleanNumber(num) == cleanDbNum {
					for c := range m {
						results = append(results, c)
					}
				}
			}
		}
	}

	return results
}

// FindClient locates a single connected client for backward compatibility
func (h *Hub) FindClient(target string) (*Client, bool) {
	clients := h.FindClients(target)
	if len(clients) > 0 {
		return clients[0], true
	}
	return nil, false
}

// RouteMessage sends signaling packets directly to all active sessions of the target user
func (h *Hub) RouteMessage(msg SignalMessage) {
	// 1:1 Calling or Direct Chat Signal
	if msg.To != "" {
		recipients := h.FindClients(msg.To)
		if len(recipients) > 0 {
			data, err := json.Marshal(msg)
			if err == nil {
				log.Printf("[Signaling] Routed %s from %s to %s (%d active sessions)", msg.Type, msg.From, msg.To, len(recipients))
				for _, recipient := range recipients {
					select {
					case recipient.Send <- data:
					default:
					}
				}
			}
		} else {
			log.Printf("[Signaling] User unavailable for %s: Target=%s, Caller=%s", msg.Type, msg.To, msg.From)
			// Target is offline -> notify caller if it's a call offer
			callers := h.FindClients(msg.From)
			if len(callers) > 0 && (msg.Type == "call_offer" || msg.Type == "chat_message") {
				offlineMsg := SignalMessage{
					Type: "call_unavailable",
					From: "system",
					To:   msg.From,
					Payload: map[string]string{
						"target": msg.To,
						"reason": "User is currently offline or unreachable",
					},
				}
				bytes, _ := json.Marshal(offlineMsg)
				for _, caller := range callers {
					select {
					case caller.Send <- bytes:
					default:
					}
				}
			}
		}
		return
	}

	// Hangout Hub Multi-party Audio Signal
	if msg.HangoutID != "" {
		members, ok := h.hangoutHubs[msg.HangoutID]
		if ok {
			data, err := json.Marshal(msg)
			if err == nil {
				for number, member := range members {
					if number != msg.From { // Don't echo back to sender
						select {
						case member.Send <- data:
						default:
						}
					}
				}
			}
		}
	}
}

func (h *Hub) JoinHangout(hangoutID, fullNumber string) {
	h.mu.Lock()
	defer h.mu.Unlock()

	clientMap, ok := h.clients[fullNumber]
	if !ok || len(clientMap) == 0 {
		return
	}

	var anyClient *Client
	for c := range clientMap {
		anyClient = c
		break
	}

	if _, exists := h.hangoutHubs[hangoutID]; !exists {
		h.hangoutHubs[hangoutID] = make(map[string]*Client)
	}

	h.hangoutHubs[hangoutID][fullNumber] = anyClient
	log.Printf("User %s joined hangout %s (Total in hub: %d)", fullNumber, hangoutID, len(h.hangoutHubs[hangoutID]))

	// Notify all existing members that someone joined
	joinMsg := SignalMessage{
		Type:      "hangout_member_joined",
		HangoutID: hangoutID,
		From:      fullNumber,
	}
	bytes, _ := json.Marshal(joinMsg)
	for num, member := range h.hangoutHubs[hangoutID] {
		if num != fullNumber {
			select {
			case member.Send <- bytes:
			default:
			}
		}
	}
}

func (h *Hub) LeaveHangout(hangoutID, fullNumber string) {
	h.mu.Lock()
	defer h.mu.Unlock()

	if members, exists := h.hangoutHubs[hangoutID]; exists {
		delete(members, fullNumber)
		h.notifyHangoutMemberLeft(hangoutID, fullNumber)
	}
}

func (h *Hub) notifyHangoutMemberLeft(hangoutID, fullNumber string) {
	if members, exists := h.hangoutHubs[hangoutID]; exists {
		leaveMsg := SignalMessage{
			Type:      "hangout_member_left",
			HangoutID: hangoutID,
			From:      fullNumber,
		}
		bytes, _ := json.Marshal(leaveMsg)
		for _, member := range members {
			select {
			case member.Send <- bytes:
			default:
			}
		}
	}
}

func (h *Hub) broadcastPresence(fullNumber, status string) {
	msg := SignalMessage{
		Type: "presence_update",
		From: fullNumber,
		Payload: map[string]string{
			"number": fullNumber,
			"status": status,
		},
	}
	bytes, _ := json.Marshal(msg)
	h.broadcast <- bytes
}
