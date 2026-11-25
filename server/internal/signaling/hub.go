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
	// Registered online clients by their IntraCom number (e.g. "+1-3847291")
	clients    map[string]*Client
	hangoutHubs map[string]map[string]*Client // hangout_id -> map[fullNumber]*Client
	broadcast  chan []byte
	register   chan *Client
	unregister chan *Client
	mu         sync.RWMutex
}

var GlobalHub = NewHub()

func NewHub() *Hub {
	return &Hub{
		clients:     make(map[string]*Client),
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
			h.clients[client.FullNumber] = client
			onlineSnapshot := make([]string, 0, len(h.clients))
			for num := range h.clients {
				onlineSnapshot = append(onlineSnapshot, num)
			}
			h.mu.Unlock()
			log.Printf("User online: %s (Total online: %d)", client.FullNumber, len(onlineSnapshot))
			// Send initial presence list to the connected user immediately
			initMsg := SignalMessage{
				Type: "initial_presence",
				From: "system",
				Payload: onlineSnapshot,
			}
			if initBytes, err := json.Marshal(initMsg); err == nil {
				select {
				case client.Send <- initBytes:
				default:
				}
			}
			h.broadcastPresence(client.FullNumber, "online")

		case client := <-h.unregister:
			h.mu.Lock()
			if _, ok := h.clients[client.FullNumber]; ok {
				delete(h.clients, client.FullNumber)
				close(client.Send)
				// Remove from any active hangout hubs
				for hubID, members := range h.hangoutHubs {
					if _, inHub := members[client.FullNumber]; inHub {
						delete(members, client.FullNumber)
						h.notifyHangoutMemberLeft(hubID, client.FullNumber)
					}
				}
			}
			h.mu.Unlock()
			log.Printf("User offline: %s (Total online: %d)", client.FullNumber, len(h.clients))
			h.broadcastPresence(client.FullNumber, "offline")

		case message := <-h.broadcast:
			h.mu.RLock()
			for _, client := range h.clients {
				select {
				case client.Send <- message:
				default:
					close(client.Send)
					delete(h.clients, client.FullNumber)
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
		// Broadcast to all connected clients if specific hangout room is empty
		for _, client := range h.clients {
			select {
			case client.Send <- bytes:
			default:
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

// FindClient locates a connected client by exact full_number, clean digits, or phone lookup
func (h *Hub) FindClient(target string) (*Client, bool) {
	h.mu.RLock()
	// 1. Direct exact match (e.g. "+1-1111111")
	if client, ok := h.clients[target]; ok {
		h.mu.RUnlock()
		return client, true
	}

	// 2. Normalized match (strip +, -, spaces)
	cleanTarget := cleanNumber(target)
	if cleanTarget != "" {
		for num, client := range h.clients {
			cleanNum := cleanNumber(num)
			if cleanNum == cleanTarget {
				h.mu.RUnlock()
				return client, true
			}
			// If target is 7 digits (subscriber portion), match suffix
			if len(cleanTarget) == 7 && strings.HasSuffix(cleanNum, cleanTarget) {
				h.mu.RUnlock()
				return client, true
			}
		}
	}
	h.mu.RUnlock()

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
			h.mu.RLock()
			defer h.mu.RUnlock()
			if client, ok := h.clients[fullNumber]; ok {
				return client, true
			}
			cleanDbNum := cleanNumber(fullNumber)
			for num, client := range h.clients {
				if cleanNumber(num) == cleanDbNum {
					return client, true
				}
			}
		}
	}

	return nil, false
}

// RouteMessage sends signaling packets (offer, answer, ice, reject, hangup) directly to the target user
func (h *Hub) RouteMessage(msg SignalMessage) {
	// 1:1 Calling Signal
	if msg.To != "" {
		recipient, ok := h.FindClient(msg.To)
		if ok {
			data, err := json.Marshal(msg)
			if err == nil {
				log.Printf("[Signaling] Routed %s from %s to %s (%s)", msg.Type, msg.From, recipient.FullNumber, recipient.DisplayName)
				recipient.Send <- data
			}
		} else {
			log.Printf("[Signaling] User unavailable for %s: Target=%s, Caller=%s", msg.Type, msg.To, msg.From)
			// Target is offline -> notify caller
			caller, hasCaller := h.FindClient(msg.From)
			if hasCaller {
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
				caller.Send <- bytes
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

	client, ok := h.clients[fullNumber]
	if !ok {
		return
	}

	if _, exists := h.hangoutHubs[hangoutID]; !exists {
		h.hangoutHubs[hangoutID] = make(map[string]*Client)
	}

	h.hangoutHubs[hangoutID][fullNumber] = client
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
			member.Send <- bytes
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
			member.Send <- bytes
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
