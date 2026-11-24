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
