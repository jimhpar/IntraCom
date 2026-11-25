package api

import (
	"context"
	"strings"
	"time"

	"github.com/gofiber/fiber/v2"
	"intracom-server/internal/auth"
	"intracom-server/internal/db"
	"intracom-server/internal/numbering"
	"intracom-server/internal/signaling"
)

type HubRequestInput struct {
	Name         string `json:"name"`
	Description  string `json:"description"`
	DistrictCode int    `json:"district_code"`
}

type PrivateHubInput struct {
	Name        string   `json:"name"`
	Description string   `json:"description"`
	MemberNums  []string `json:"member_numbers"` // e.g. ["+1-3847291", "+2-1000001"]
}

type HubMessageInput struct {
	Content string `json:"content"`
}

// GET /api/v1/hangouts/public - List all approved public hubs
func GetPublicHubsHandler(c *fiber.Ctx) error {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	rows, err := db.Pool.Query(ctx, `
		SELECT h.id, h.name, h.description, h.hub_type, h.district_code, u.display_name,
		       (SELECT COUNT(*) FROM hangout_members WHERE hangout_id = h.id) as member_count
		FROM hangouts h
		JOIN users u ON h.owner_id = u.id
		WHERE h.hub_type = 'public'
		ORDER BY h.created_at DESC
	`)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"success": false, "error": "Failed to fetch hubs"})
	}
	defer rows.Close()

	var hubs []fiber.Map
	for rows.Next() {
		var (
			id, name, desc, hubType, ownerName string
			districtCode, memberCount          int
		)
		if err := rows.Scan(&id, &name, &desc, &hubType, &districtCode, &ownerName, &memberCount); err == nil {
			districtName := "General"
			if d, ok := numbering.Districts[districtCode]; ok {
				districtName = d.NameEn
			}
			hubs = append(hubs, fiber.Map{
				"id":            id,
				"name":          name,
				"description":   desc,
				"hub_type":      hubType,
				"district_name": districtName,
				"owner_name":    ownerName,
				"member_count":  memberCount,
			})
		}
	}

	return c.JSON(fiber.Map{"success": true, "data": hubs})
}

// POST /api/v1/hangouts/request-public - Normal user requests new public hub
func RequestPublicHubHandler(c *fiber.Ctx) error {
	claims, ok := c.Locals("user").(*auth.JWTClaims)
	if !ok {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"success": false, "error": "Unauthorized"})
	}

	var input HubRequestInput
	if err := c.BodyParser(&input); err != nil || strings.TrimSpace(input.Name) == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"success": false, "error": "Hub name is required"})
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	var reqID string
	query := `
		INSERT INTO hangout_requests (requester_id, name, description, district_code, status)
		VALUES ($1, $2, $3, $4, 'pending')
		RETURNING id
	`
	err := db.Pool.QueryRow(ctx, query, claims.UserID, input.Name, input.Description, input.DistrictCode).Scan(&reqID)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"success": false, "error": "Failed to submit request"})
	}

	return c.Status(fiber.StatusCreated).JSON(fiber.Map{
		"success": true,
		"message": "Public hub creation request submitted to admin for approval",
		"data":    fiber.Map{"request_id": reqID},
	})
}

// GET /api/v1/hangouts/private - List private tables that current user created or was added to
func GetPrivateTablesHandler(c *fiber.Ctx) error {
	claims, ok := c.Locals("user").(*auth.JWTClaims)
	if !ok {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"success": false, "error": "Unauthorized"})
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	query := `
		SELECT h.id, h.name, h.description, h.hub_type, u.display_name as owner_name,
		       (SELECT COUNT(*) FROM hangout_members WHERE hangout_id = h.id) as member_count
		FROM hangouts h
		JOIN users u ON h.owner_id = u.id
		WHERE h.hub_type = 'private' AND (
			h.owner_id = $1 OR 
			EXISTS (SELECT 1 FROM hangout_members WHERE hangout_id = h.id AND user_id = $1)
		)
		ORDER BY h.created_at DESC
	`
	rows, err := db.Pool.Query(ctx, query, claims.UserID)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"success": false, "error": "Failed to fetch private tables"})
	}
	defer rows.Close()

	var tables []fiber.Map
	for rows.Next() {
		var (
			id, name, desc, hubType, ownerName string
			memberCount                        int
		)
		if err := rows.Scan(&id, &name, &desc, &hubType, &ownerName, &memberCount); err == nil {
			tables = append(tables, fiber.Map{
				"id":           id,
				"name":         name,
				"description":  desc,
				"hub_type":     hubType,
				"owner_name":   ownerName,
				"member_count": memberCount,
			})
		}
	}

	return c.JSON(fiber.Map{"success": true, "data": tables})
}

// POST /api/v1/hangouts/private - Create private table & auto-invite member numbers
func CreatePrivateTableHandler(c *fiber.Ctx) error {
	claims, ok := c.Locals("user").(*auth.JWTClaims)
	if !ok {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"success": false, "error": "Unauthorized"})
	}

	var input PrivateHubInput
	if err := c.BodyParser(&input); err != nil || strings.TrimSpace(input.Name) == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"success": false, "error": "Table name is required"})
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	var tableID string
	err := db.Pool.QueryRow(ctx, `
		INSERT INTO hangouts (owner_id, name, description, hub_type)
		VALUES ($1, $2, $3, 'private')
		RETURNING id
	`, claims.UserID, input.Name, input.Description).Scan(&tableID)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"success": false, "error": "Failed to create table"})
	}

	// Add creator as member
	_, _ = db.Pool.Exec(ctx, `INSERT INTO hangout_members (hangout_id, user_id, role) VALUES ($1, $2, 'owner')`, tableID, claims.UserID)

	// Add invitees by IntraCom number
	var addedMembers []string
	for _, num := range input.MemberNums {
		num = strings.TrimSpace(num)
		if num == "" {
			continue
		}
		var invitedUserID string
		err := db.Pool.QueryRow(ctx, "SELECT id FROM users WHERE full_number = $1", num).Scan(&invitedUserID)
		if err == nil && invitedUserID != claims.UserID {
			_, _ = db.Pool.Exec(ctx, `
				INSERT INTO hangout_members (hangout_id, user_id, role)
				VALUES ($1, $2, 'member') ON CONFLICT DO NOTHING
			`, tableID, invitedUserID)
			addedMembers = append(addedMembers, num)

			// Notify user in real-time via WebSocket
			signaling.GlobalHub.RouteMessage(signaling.SignalMessage{
				Type: "private_hub_invite",
				From: claims.FullNumber,
				To:   num,
				Payload: fiber.Map{
					"table_id":   tableID,
					"table_name": input.Name,
					"owner":      claims.FullNumber,
				},
			})
		}
	}

	return c.Status(fiber.StatusCreated).JSON(fiber.Map{
		"success": true,
		"data": fiber.Map{
			"id":            tableID,
			"name":          input.Name,
			"added_members": addedMembers,
		},
	})
}

// GET /api/v1/hangouts/:id/members - Get list of users in a hub/table
func GetHangoutMembersHandler(c *fiber.Ctx) error {
	hubID := c.Params("id")
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	// 1. First attempt to get users explicitly enrolled in hangout_members
	rows, err := db.Pool.Query(ctx, `
		SELECT u.id, u.full_number, u.display_name, u.district_name, COALESCE(hm.role, 'member') as role
		FROM hangout_members hm
		JOIN users u ON hm.user_id = u.id
		WHERE hm.hangout_id = $1
		ORDER BY hm.joined_at ASC
	`, hubID)

	var members []fiber.Map
	if err == nil {
		for rows.Next() {
			var id, fullNum, name, district, role string
			if err := rows.Scan(&id, &fullNum, &name, &district, &role); err == nil {
				members = append(members, fiber.Map{
					"id":            id,
					"full_number":   fullNum,
					"display_name":  name,
					"district_name": district,
					"role":          role,
				})
			}
		}
		rows.Close()
	}

	// 2. If no explicit members found (e.g. for a global public hub), return community directory users
	if len(members) == 0 {
		userRows, err := db.Pool.Query(ctx, `
			SELECT id, full_number, display_name, district_name
			FROM users
			WHERE is_suspended = FALSE
			ORDER BY created_at DESC
			LIMIT 25
		`)
		if err == nil {
			for userRows.Next() {
				var id, fullNum, name, district string
				if err := userRows.Scan(&id, &fullNum, &name, &district); err == nil {
					members = append(members, fiber.Map{
						"id":            id,
						"full_number":   fullNum,
						"display_name":  name,
						"district_name": district,
						"role":          "member",
					})
				}
			}
			userRows.Close()
		}
	}

	return c.JSON(fiber.Map{
		"success": true,
		"data":    members,
	})
}

// GET /api/v1/hangouts/:id/messages - Get recent chat history for a hub
func GetHangoutMessagesHandler(c *fiber.Ctx) error {
	hubID := c.Params("id")
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	rows, err := db.Pool.Query(ctx, `
		SELECT m.id, m.content, m.created_at, u.display_name, u.full_number
		FROM hangout_messages m
		JOIN users u ON m.sender_id = u.id
		WHERE m.hangout_id = $1 AND m.is_deleted = FALSE
		ORDER BY m.created_at ASC
		LIMIT 100
	`, hubID)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"success": false, "error": "Failed to fetch messages"})
	}
	defer rows.Close()

	var messages []fiber.Map
	for rows.Next() {
		var id, content, senderName, senderNum string
		var createdAt time.Time
		if err := rows.Scan(&id, &content, &createdAt, &senderName, &senderNum); err == nil {
			messages = append(messages, fiber.Map{
				"id":          id,
				"content":     content,
				"sender_name": senderName,
				"sender_num":  senderNum,
				"created_at":  createdAt.Format(time.RFC3339),
			})
		}
	}

	return c.JSON(fiber.Map{
		"success": true,
		"data":    messages,
	})
}

// POST /api/v1/hangouts/:id/messages - Send message to hub chat
func PostHangoutMessageHandler(c *fiber.Ctx) error {
	hubID := c.Params("id")
	claims, ok := c.Locals("user").(*auth.JWTClaims)
	if !ok {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"success": false, "error": "Unauthorized"})
	}

	var input HubMessageInput
	if err := c.BodyParser(&input); err != nil || strings.TrimSpace(input.Content) == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"success": false, "error": "Content is required"})
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	var msgID string
	var createdAt time.Time
	err := db.Pool.QueryRow(ctx, `
		INSERT INTO hangout_messages (hangout_id, sender_id, content)
		VALUES ($1, $2, $3)
		RETURNING id, created_at
	`, hubID, claims.UserID, strings.TrimSpace(input.Content)).Scan(&msgID, &createdAt)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"success": false, "error": "Failed to save message"})
	}

	// Fetch sender display name
	var senderName string
	_ = db.Pool.QueryRow(ctx, "SELECT display_name FROM users WHERE id = $1", claims.UserID).Scan(&senderName)

	// Broadcast to active WebSocket clients in this hub
	signaling.GlobalHub.BroadcastHubMessage(hubID, signaling.SignalMessage{
		Type:      "hub_chat_message",
		HangoutID: hubID,
		From:      claims.FullNumber,
		Payload: fiber.Map{
			"id":          msgID,
			"content":     strings.TrimSpace(input.Content),
			"sender_name": senderName,
			"sender_num":  claims.FullNumber,
			"hangout_id":  hubID,
			"created_at":  createdAt.Format(time.RFC3339),
		},
	})

	return c.Status(fiber.StatusCreated).JSON(fiber.Map{
		"success": true,
		"data": fiber.Map{
			"id":          msgID,
			"content":     input.Content,
			"sender_name": senderName,
			"sender_num":  claims.FullNumber,
			"created_at":  createdAt.Format(time.RFC3339),
		},
	})
}
