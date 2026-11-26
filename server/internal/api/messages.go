package api

import (
	"context"
	"strings"
	"time"

	"github.com/gofiber/fiber/v2"
	"intracom-server/internal/auth"
	"intracom-server/internal/db"
	"intracom-server/internal/signaling"
)

// Helper to find a user by full_number, user_number, phone, or UUID
func findUserByTarget(ctx context.Context, target string) (userID, fullNum, name string, err error) {
	clean := strings.TrimSpace(target)
	digits := strings.Map(func(r rune) rune {
		if r >= '0' && r <= '9' {
			return r
		}
		return -1
	}, clean)

	query := `
		SELECT id, full_number, display_name
		FROM users
		WHERE id::text = $1
		   OR full_number = $1
		   OR user_number = $1
		   OR phone = $1
		   OR ($2 != '' AND user_number = $2)
		   OR ($2 != '' AND phone = $2)
		   OR ($2 != '' AND REPLACE(REPLACE(full_number, '+', ''), '-', '') = $2)
		   OR ($2 != '' AND full_number LIKE '%-' || $2)
		   OR ($2 != '' AND REPLACE(REPLACE(full_number, '+', ''), '-', '') LIKE '%' || $2)
		LIMIT 1
	`
	err = db.Pool.QueryRow(ctx, query, clean, digits).Scan(&userID, &fullNum, &name)
	return
}

// Helper to get or create direct conversation between two users
func getOrCreateDirectConversation(ctx context.Context, userA, userB string) (string, error) {
	var convID string
	query := `
		SELECT c.id
		FROM conversations c
		JOIN conversation_members cm1 ON c.id = cm1.conversation_id AND cm1.user_id = $1
		JOIN conversation_members cm2 ON c.id = cm2.conversation_id AND cm2.user_id = $2
		WHERE c.type = 'direct'
		LIMIT 1
	`
	err := db.Pool.QueryRow(ctx, query, userA, userB).Scan(&convID)
	if err == nil && convID != "" {
		return convID, nil
	}

	// Create new conversation
	err = db.Pool.QueryRow(ctx, "INSERT INTO conversations (type) VALUES ('direct') RETURNING id").Scan(&convID)
	if err != nil {
		return "", err
	}

	// Add both members
	_, _ = db.Pool.Exec(ctx, "INSERT INTO conversation_members (conversation_id, user_id) VALUES ($1, $2), ($1, $3) ON CONFLICT DO NOTHING", convID, userA, userB)
	return convID, nil
}

// GET /api/v1/messages/conversations - List all direct conversations for current user
func ListConversationsHandler(c *fiber.Ctx) error {
	claims, ok := c.Locals("user").(*auth.JWTClaims)
	if !ok {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"success": false, "error": "Unauthorized"})
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	query := `
		SELECT 
			c.id as conversation_id,
			u.id as peer_id,
			u.full_number as peer_number,
			u.display_name as peer_name,
			u.district_name as peer_district,
			COALESCE(m.content, '') as last_message,
			COALESCE(m.created_at, c.last_message_at) as last_message_time,
			COALESCE(m.sender_id::text, '') as last_sender_id,
			(
				SELECT COUNT(*)
				FROM messages um
				WHERE um.conversation_id = c.id
				  AND um.is_deleted = FALSE
				  AND um.sender_id != $1
				  AND um.created_at > COALESCE(my_m.last_read_at, '1970-01-01'::timestamptz)
			) as unread_count
		FROM conversations c
		JOIN conversation_members my_m ON c.id = my_m.conversation_id AND my_m.user_id = $1
		JOIN conversation_members peer_m ON c.id = peer_m.conversation_id AND peer_m.user_id != $1
		JOIN users u ON peer_m.user_id = u.id
		LEFT JOIN LATERAL (
			SELECT content, created_at, sender_id
			FROM messages
			WHERE conversation_id = c.id AND is_deleted = FALSE
			ORDER BY created_at DESC
			LIMIT 1
		) m ON TRUE
		WHERE c.type = 'direct'
		ORDER BY c.last_message_at DESC
	`

	rows, err := db.Pool.Query(ctx, query, claims.UserID)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"success": false, "error": "Failed to load conversations"})
	}
	defer rows.Close()

	onlineList := signaling.GlobalHub.GetOnlineUsers()
	onlineSet := make(map[string]bool)
	for _, num := range onlineList {
		onlineSet[num] = true
	}

	results := make([]fiber.Map, 0)
	for rows.Next() {
		var (
			convID, peerID, peerNum, peerName, peerDistrict string
			lastMsg, lastSenderID                           string
			lastMsgTime                                     time.Time
			unreadCount                                     int
		)
		if err := rows.Scan(&convID, &peerID, &peerNum, &peerName, &peerDistrict, &lastMsg, &lastMsgTime, &lastSenderID, &unreadCount); err == nil {
			isOnline := onlineSet[peerNum]
			results = append(results, fiber.Map{
				"conversation_id":   convID,
				"peer_id":           peerID,
				"peer_number":       peerNum,
				"peer_name":         peerName,
				"peer_district":     peerDistrict,
				"last_message":      lastMsg,
				"last_message_time": lastMsgTime.Format(time.RFC3339),
				"is_me_last":        lastSenderID == claims.UserID,
				"is_online":         isOnline,
				"unread_count":      unreadCount,
			})
		}
	}

	return c.JSON(fiber.Map{
		"success": true,
		"data":    results,
	})
}

// GET /api/v1/messages/chat/:peer - Get message history with peer
func GetChatMessagesHandler(c *fiber.Ctx) error {
	claims, ok := c.Locals("user").(*auth.JWTClaims)
	if !ok {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"success": false, "error": "Unauthorized"})
	}

	peerTarget := c.Params("peer")
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	peerID, peerNum, peerName, err := findUserByTarget(ctx, peerTarget)
	if err != nil {
		return c.Status(fiber.StatusNotFound).JSON(fiber.Map{"success": false, "error": "Contact not found"})
	}

	convID, err := getOrCreateDirectConversation(ctx, claims.UserID, peerID)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"success": false, "error": "Failed to access conversation"})
	}

	// Mark conversation as read for current user
	_, _ = db.Pool.Exec(ctx, "UPDATE conversation_members SET last_read_at = CURRENT_TIMESTAMP WHERE conversation_id = $1 AND user_id = $2", convID, claims.UserID)

	query := `
		SELECT m.id, m.sender_id, m.content, m.created_at, u.display_name, u.full_number
		FROM messages m
		JOIN users u ON m.sender_id = u.id
		WHERE m.conversation_id = $1 AND m.is_deleted = FALSE
		ORDER BY m.created_at ASC
		LIMIT 200
	`
	rows, err := db.Pool.Query(ctx, query, convID)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"success": false, "error": "Failed to fetch messages"})
	}
	defer rows.Close()

	var msgs []fiber.Map
	for rows.Next() {
		var (
			id, senderID, content, senderName, senderNum string
			createdAt                                    time.Time
		)
		if err := rows.Scan(&id, &senderID, &content, &createdAt, &senderName, &senderNum); err == nil {
			msgs = append(msgs, fiber.Map{
				"id":          id,
				"is_me":       senderID == claims.UserID,
				"content":     content,
				"sender_name": senderName,
				"sender_num":  senderNum,
				"created_at":  createdAt.Format(time.RFC3339),
			})
		}
	}

	return c.JSON(fiber.Map{
		"success": true,
		"data": fiber.Map{
			"conversation_id": convID,
			"peer_id":         peerID,
			"peer_number":     peerNum,
			"peer_name":       peerName,
			"messages":        msgs,
		},
	})
}

// POST /api/v1/messages/chat/:peer - Send message to peer
func SendMessageHandler(c *fiber.Ctx) error {
	claims, ok := c.Locals("user").(*auth.JWTClaims)
	if !ok {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"success": false, "error": "Unauthorized"})
	}

	peerTarget := c.Params("peer")
	type SendInput struct {
		Content string `json:"content"`
	}
	var input SendInput
	if err := c.BodyParser(&input); err != nil || strings.TrimSpace(input.Content) == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"success": false, "error": "Message content cannot be empty"})
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	peerID, peerNum, peerName, err := findUserByTarget(ctx, peerTarget)
	if err != nil {
		return c.Status(fiber.StatusNotFound).JSON(fiber.Map{"success": false, "error": "Contact not found"})
	}

	convID, err := getOrCreateDirectConversation(ctx, claims.UserID, peerID)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"success": false, "error": "Failed to access conversation"})
	}

	// Mark conversation as read for current user
	_, _ = db.Pool.Exec(ctx, "UPDATE conversation_members SET last_read_at = CURRENT_TIMESTAMP WHERE conversation_id = $1 AND user_id = $2", convID, claims.UserID)

	var msgID string
	var createdAt time.Time
	err = db.Pool.QueryRow(ctx, `
		INSERT INTO messages (conversation_id, sender_id, content)
		VALUES ($1, $2, $3)
		RETURNING id, created_at
	`, convID, claims.UserID, strings.TrimSpace(input.Content)).Scan(&msgID, &createdAt)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"success": false, "error": "Failed to save message"})
	}

	// Update conversation last_message_at
	_, _ = db.Pool.Exec(ctx, "UPDATE conversations SET last_message_at = CURRENT_TIMESTAMP WHERE id = $1", convID)

	// Fetch sender display name
	var senderName string
	_ = db.Pool.QueryRow(ctx, "SELECT display_name FROM users WHERE id = $1", claims.UserID).Scan(&senderName)

	msgPayload := fiber.Map{
		"id":          msgID,
		"content":     strings.TrimSpace(input.Content),
		"sender_name": senderName,
		"sender_num":  claims.FullNumber,
		"to_number":   peerNum,
		"created_at":  createdAt.Format(time.RFC3339),
	}

	// Push real-time WebSocket packet to peer
	signaling.GlobalHub.RouteMessage(signaling.SignalMessage{
		Type:       "chat_message",
		From:       claims.FullNumber,
		To:         peerNum,
		CallerName: senderName,
		Payload:    msgPayload,
	})

	return c.Status(fiber.StatusCreated).JSON(fiber.Map{
		"success": true,
		"data": fiber.Map{
			"id":          msgID,
			"is_me":       true,
			"content":     input.Content,
			"sender_name": senderName,
			"sender_num":  claims.FullNumber,
			"created_at":  createdAt.Format(time.RFC3339),
			"peer_name":   peerName,
			"peer_number": peerNum,
		},
	})
}

// DELETE /api/v1/messages/chat/:peer - Clear / delete conversation history with peer
func DeleteConversationHandler(c *fiber.Ctx) error {
	claims, ok := c.Locals("user").(*auth.JWTClaims)
	if !ok {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"success": false, "error": "Unauthorized"})
	}

	peerTarget := c.Params("peer")
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	peerID, _, _, err := findUserByTarget(ctx, peerTarget)
	if err != nil {
		return c.Status(fiber.StatusNotFound).JSON(fiber.Map{"success": false, "error": "Contact not found"})
	}

	convID, err := getOrCreateDirectConversation(ctx, claims.UserID, peerID)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"success": false, "error": "Failed to find conversation"})
	}

	// Hard delete all messages in this conversation
	_, err = db.Pool.Exec(ctx, "DELETE FROM messages WHERE conversation_id = $1", convID)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"success": false, "error": "Failed to clear chat"})
	}

	return c.JSON(fiber.Map{
		"success": true,
		"message": "Chat history successfully deleted",
	})
}

// DELETE /api/v1/messages/msg/:id - Delete a specific message
func DeleteMessageHandler(c *fiber.Ctx) error {
	claims, ok := c.Locals("user").(*auth.JWTClaims)
	if !ok {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"success": false, "error": "Unauthorized"})
	}

	msgID := c.Params("id")
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	res, err := db.Pool.Exec(ctx, "DELETE FROM messages WHERE id = $1 AND sender_id = $2", msgID, claims.UserID)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"success": false, "error": "Failed to delete message"})
	}
	if res.RowsAffected() == 0 {
		return c.Status(fiber.StatusNotFound).JSON(fiber.Map{"success": false, "error": "Message not found or not sender"})
	}

	return c.JSON(fiber.Map{
		"success": true,
		"message": "Message deleted",
	})
}
