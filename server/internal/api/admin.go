package api

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"
	"time"

	"github.com/gofiber/fiber/v2"
	"intracom-server/internal/auth"
	"intracom-server/internal/db"
	"intracom-server/internal/numbering"
)

// AdminAuthMiddleware ensures only users with is_admin = true can access admin endpoints
func AdminAuthMiddleware(c *fiber.Ctx) error {
	authHeader := c.Get("Authorization")
	if !strings.HasPrefix(authHeader, "Bearer ") {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"success": false, "error": "Admin access requires authorization token"})
	}

	tokenStr := strings.TrimPrefix(authHeader, "Bearer ")
	claims, err := auth.ValidateToken(tokenStr)
	if err != nil {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"success": false, "error": "Invalid token"})
	}

	// Verify is_admin in DB
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()

	var isAdmin bool
	err = db.Pool.QueryRow(ctx, "SELECT is_admin FROM users WHERE id = $1", claims.UserID).Scan(&isAdmin)
	if err != nil || !isAdmin {
		return c.Status(fiber.StatusForbidden).JSON(fiber.Map{"success": false, "error": "Forbidden: Admin privileges required"})
	}

	c.Locals("user", claims)
	return c.Next()
}

// UserAuthMiddleware standard user authentication
func UserAuthMiddleware(c *fiber.Ctx) error {
	authHeader := c.Get("Authorization")
	if !strings.HasPrefix(authHeader, "Bearer ") {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"success": false, "error": "Authentication required"})
	}

	tokenStr := strings.TrimPrefix(authHeader, "Bearer ")
	claims, err := auth.ValidateToken(tokenStr)
	if err != nil {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"success": false, "error": "Invalid token"})
	}

	c.Locals("user", claims)
	return c.Next()
}

// GET /api/v1/admin/stats - Live system metrics
func AdminStatsHandler(c *fiber.Ctx) error {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	var totalUsers, suspendedUsers, totalHubs, pendingRequests int
	_ = db.Pool.QueryRow(ctx, "SELECT COUNT(*) FROM users").Scan(&totalUsers)
	_ = db.Pool.QueryRow(ctx, "SELECT COUNT(*) FROM users WHERE is_suspended = TRUE").Scan(&suspendedUsers)
	_ = db.Pool.QueryRow(ctx, "SELECT COUNT(*) FROM hangouts").Scan(&totalHubs)
	_ = db.Pool.QueryRow(ctx, "SELECT COUNT(*) FROM hangout_requests WHERE status = 'pending'").Scan(&pendingRequests)

	return c.JSON(fiber.Map{
		"success": true,
		"data": fiber.Map{
			"total_users":      totalUsers,
			"suspended_users":  suspendedUsers,
			"active_users":     totalUsers - suspendedUsers,
			"total_hubs":       totalHubs,
			"pending_requests": pendingRequests,
		},
	})
}

// GET /api/v1/admin/users - Search and list users
func AdminListUsersHandler(c *fiber.Ctx) error {
	q := strings.TrimSpace(c.Query("q"))
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	query := `
		SELECT id, full_number, district_name, display_name, phone, COALESCE(email, ''), is_suspended, is_admin, created_at
		FROM users
		WHERE ($1 = '' OR full_number ILIKE '%' || $1 || '%' OR display_name ILIKE '%' || $1 || '%' OR phone ILIKE '%' || $1 || '%')
		ORDER BY created_at DESC
		LIMIT 100
	`
	rows, err := db.Pool.Query(ctx, query, q)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"success": false, "error": "Failed to list users"})
	}
	defer rows.Close()

	var users []fiber.Map
	for rows.Next() {
		var (
			id, fullNum, districtName, name, phone, email string
			isSuspended, isAdmin                          bool
			createdAt                                     time.Time
		)
		if err := rows.Scan(&id, &fullNum, &districtName, &name, &phone, &email, &isSuspended, &isAdmin, &createdAt); err == nil {
			users = append(users, fiber.Map{
				"id":            id,
				"full_number":   fullNum,
				"district_name": districtName,
				"display_name":  name,
				"phone":         phone,
				"email":         email,
				"is_suspended":  isSuspended,
				"is_admin":      isAdmin,
				"created_at":    createdAt.Format(time.RFC3339),
			})
		}
	}

	return c.JSON(fiber.Map{"success": true, "data": users})
}

// PUT /api/v1/admin/users/:id/suspend - Toggle suspend / unsuspend
func AdminToggleSuspendHandler(c *fiber.Ctx) error {
	userID := c.Params("id")
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	var currentStatus bool
	err := db.Pool.QueryRow(ctx, "SELECT is_suspended FROM users WHERE id = $1", userID).Scan(&currentStatus)
	if err != nil {
		return c.Status(fiber.StatusNotFound).JSON(fiber.Map{"success": false, "error": "User not found"})
	}

	newStatus := !currentStatus
	_, err = db.Pool.Exec(ctx, "UPDATE users SET is_suspended = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2", newStatus, userID)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"success": false, "error": "Failed to update status"})
	}

	actionStr := "unsuspended"
	if newStatus {
		actionStr = "suspended"
	}

	return c.JSON(fiber.Map{
		"success":      true,
		"message":      fmt.Sprintf("User successfully %s", actionStr),
		"is_suspended": newStatus,
	})
}

// POST /api/v1/admin/users/manual - Admin manually creates a new user
func AdminManualCreateUserHandler(c *fiber.Ctx) error {
	return RegisterHandler(c) // Uses same district & 7-digit generator pipeline
}

// AdminUpdateUserInput represents fields an admin can update for any user
type AdminUpdateUserInput struct {
	DisplayName  *string `json:"display_name"`
	Phone        *string `json:"phone"`
	Email        *string `json:"email"`
	FullNumber   *string `json:"full_number"`
	Password     *string `json:"password"`
	DistrictCode *int    `json:"district_code"`
	IsAdmin      *bool   `json:"is_admin"`
	IsSuspended  *bool   `json:"is_suspended"`
}

// PUT /api/v1/admin/users/:id - Admin updates any information of a user
func AdminUpdateUserFullHandler(c *fiber.Ctx) error {
	userID := c.Params("id")
	var input AdminUpdateUserInput
	if err := json.Unmarshal(c.Body(), &input); err != nil {
		if err2 := c.BodyParser(&input); err2 != nil {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"success": false, "error": "Invalid request body"})
		}
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	// Verify user exists
	var currentNum string
	err := db.Pool.QueryRow(ctx, "SELECT full_number FROM users WHERE id = $1", userID).Scan(&currentNum)
	if err != nil {
		return c.Status(fiber.StatusNotFound).JSON(fiber.Map{"success": false, "error": "User not found"})
	}

	// If FullNumber changed, ensure uniqueness
	if input.FullNumber != nil && strings.TrimSpace(*input.FullNumber) != "" {
		newNum := strings.TrimSpace(*input.FullNumber)
		var conflictID string
		err := db.Pool.QueryRow(ctx, "SELECT id FROM users WHERE full_number = $1 AND id != $2", newNum, userID).Scan(&conflictID)
		if err == nil && conflictID != "" {
			return c.Status(fiber.StatusConflict).JSON(fiber.Map{"success": false, "error": "IntraCom number is already taken"})
		}
		_, _ = db.Pool.Exec(ctx, "UPDATE users SET full_number = $1 WHERE id = $2", newNum, userID)
	}

	// If Phone changed, ensure uniqueness
	if input.Phone != nil && strings.TrimSpace(*input.Phone) != "" {
		newPhone := strings.TrimSpace(*input.Phone)
		var conflictID string
		err := db.Pool.QueryRow(ctx, "SELECT id FROM users WHERE phone = $1 AND id != $2", newPhone, userID).Scan(&conflictID)
		if err == nil && conflictID != "" {
			return c.Status(fiber.StatusConflict).JSON(fiber.Map{"success": false, "error": "Phone number is already taken"})
		}
		_, _ = db.Pool.Exec(ctx, "UPDATE users SET phone = $1 WHERE id = $2", newPhone, userID)
	}

	// Update DisplayName
	if input.DisplayName != nil && strings.TrimSpace(*input.DisplayName) != "" {
		_, _ = db.Pool.Exec(ctx, "UPDATE users SET display_name = $1 WHERE id = $2", strings.TrimSpace(*input.DisplayName), userID)
	}

	// Update Email
	if input.Email != nil {
		emailVal := strings.TrimSpace(strings.ToLower(*input.Email))
		if emailVal == "" {
			_, _ = db.Pool.Exec(ctx, "UPDATE users SET email = NULL WHERE id = $1", userID)
		} else {
			_, _ = db.Pool.Exec(ctx, "UPDATE users SET email = $1 WHERE id = $2", emailVal, userID)
		}
	}

	// Update Password if provided
	if input.Password != nil && strings.TrimSpace(*input.Password) != "" {
		newHash, err := auth.HashPassword(strings.TrimSpace(*input.Password))
		if err == nil {
			_, _ = db.Pool.Exec(ctx, "UPDATE users SET password_hash = $1 WHERE id = $2", newHash, userID)
		}
	}

	// Update District if provided
	if input.DistrictCode != nil && *input.DistrictCode > 0 {
		if d, ok := numbering.Districts[*input.DistrictCode]; ok {
			_, _ = db.Pool.Exec(ctx, "UPDATE users SET district_code = $1, district_name = $2 WHERE id = $3", d.Code, d.NameEn, userID)
		}
	}

	// Update IsAdmin
	if input.IsAdmin != nil {
		_, _ = db.Pool.Exec(ctx, "UPDATE users SET is_admin = $1 WHERE id = $2", *input.IsAdmin, userID)
	}

	// Update IsSuspended
	if input.IsSuspended != nil {
		_, _ = db.Pool.Exec(ctx, "UPDATE users SET is_suspended = $1 WHERE id = $2", *input.IsSuspended, userID)
	}

	_, _ = db.Pool.Exec(ctx, "UPDATE users SET updated_at = CURRENT_TIMESTAMP WHERE id = $1", userID)

	return c.JSON(fiber.Map{
		"success": true,
		"message": "User details successfully updated by Administrator",
	})
}

// PUT /api/v1/admin/users/:id/number - Admin customizes/updates a user's IntraCom number
func AdminUpdateUserNumberHandler(c *fiber.Ctx) error {
	userID := c.Params("id")
	type NumberInput struct {
		FullNumber string `json:"full_number"`
	}
	var input NumberInput
	if err := c.BodyParser(&input); err != nil || strings.TrimSpace(input.FullNumber) == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"success": false, "error": "full_number is required (e.g. +1-7777777)"})
	}

	newNumber := strings.TrimSpace(input.FullNumber)
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	// Check if already taken by another user
	var existingID string
	err := db.Pool.QueryRow(ctx, "SELECT id FROM users WHERE full_number = $1 AND id != $2", newNumber, userID).Scan(&existingID)
	if err == nil && existingID != "" {
		return c.Status(fiber.StatusConflict).JSON(fiber.Map{"success": false, "error": "This number is already assigned to another user"})
	}

	_, err = db.Pool.Exec(ctx, "UPDATE users SET full_number = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2", newNumber, userID)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"success": false, "error": "Failed to update number"})
	}

	return c.JSON(fiber.Map{
		"success":     true,
		"message":     fmt.Sprintf("User number updated to %s", newNumber),
		"full_number": newNumber,
	})
}

// GET /api/v1/admin/hub-requests - List pending requests
func AdminListHubRequestsHandler(c *fiber.Ctx) error {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	rows, err := db.Pool.Query(ctx, `
		SELECT r.id, r.name, r.description, r.district_code, r.status, r.created_at, u.display_name, u.full_number
		FROM hangout_requests r
		JOIN users u ON r.requester_id = u.id
		ORDER BY r.created_at DESC
	`)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"success": false, "error": "Failed to load requests"})
	}
	defer rows.Close()

	var requests []fiber.Map
	for rows.Next() {
		var (
			id, name, desc, status, requesterName, requesterNum string
			districtCode                                        int
			createdAt                                           time.Time
		)
		if err := rows.Scan(&id, &name, &desc, &districtCode, &status, &createdAt, &requesterName, &requesterNum); err == nil {
			districtName := "All Districts"
			if d, ok := numbering.Districts[districtCode]; ok {
				districtName = d.NameEn
			}
			requests = append(requests, fiber.Map{
				"id":             id,
				"name":           name,
				"description":    desc,
				"district_name":  districtName,
				"district_code":  districtCode,
				"status":         status,
				"created_at":     createdAt.Format(time.RFC3339),
				"requester_name": requesterName,
				"requester_num":  requesterNum,
			})
		}
	}

	return c.JSON(fiber.Map{"success": true, "data": requests})
}

// POST /api/v1/admin/hub-requests/:id/review - Approve or reject hub request
func AdminReviewHubRequestHandler(c *fiber.Ctx) error {
	reqID := c.Params("id")
	type ReviewInput struct {
		Action string `json:"action"` // approve or reject
		Note   string `json:"note"`
	}
	var input ReviewInput
	if err := c.BodyParser(&input); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"success": false, "error": "Invalid body"})
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if strings.ToLower(input.Action) == "approve" {
		// 1. Fetch request details
		var (
			requesterID, name, desc string
			districtCode            int
		)
		err := db.Pool.QueryRow(ctx, "SELECT requester_id, name, description, district_code FROM hangout_requests WHERE id = $1", reqID).
			Scan(&requesterID, &name, &desc, &districtCode)
		if err != nil {
			return c.Status(fiber.StatusNotFound).JSON(fiber.Map{"success": false, "error": "Request not found"})
		}

		// 2. Insert into hangouts table
		_, err = db.Pool.Exec(ctx, `
			INSERT INTO hangouts (owner_id, name, description, hub_type, district_code)
			VALUES ($1, $2, $3, 'public', $4)
		`, requesterID, name, desc, districtCode)
		if err != nil {
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"success": false, "error": "Failed to create public hub"})
		}

		// 3. Mark request approved
		_, _ = db.Pool.Exec(ctx, "UPDATE hangout_requests SET status = 'approved', reviewed_at = CURRENT_TIMESTAMP WHERE id = $1", reqID)
		return c.JSON(fiber.Map{"success": true, "message": "Public Hub approved and activated"})
	}

	// Reject
	_, _ = db.Pool.Exec(ctx, "UPDATE hangout_requests SET status = 'rejected', admin_note = $1, reviewed_at = CURRENT_TIMESTAMP WHERE id = $2", input.Note, reqID)
	return c.JSON(fiber.Map{"success": true, "message": "Public Hub request rejected"})
}

// POST /api/v1/admin/hubs/:id/bans - Ban user from a specific hub
func AdminBanUserFromHubHandler(c *fiber.Ctx) error {
	hubID := c.Params("id")
	type BanInput struct {
		UserNum string `json:"user_number"`
		Reason  string `json:"reason"`
	}
	var input BanInput
	if err := c.BodyParser(&input); err != nil || input.UserNum == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"success": false, "error": "user_number is required"})
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	var targetUserID string
	err := db.Pool.QueryRow(ctx, "SELECT id FROM users WHERE full_number = $1", input.UserNum).Scan(&targetUserID)
	if err != nil {
		return c.Status(fiber.StatusNotFound).JSON(fiber.Map{"success": false, "error": "User not found"})
	}

	_, err = db.Pool.Exec(ctx, `
		INSERT INTO hangout_bans (hangout_id, user_id, reason)
		VALUES ($1, $2, $3)
		ON CONFLICT (hangout_id, user_id) DO UPDATE SET reason = $3
	`, hubID, targetUserID, input.Reason)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"success": false, "error": "Failed to apply ban"})
	}

	// Remove from members if present
	_, _ = db.Pool.Exec(ctx, "DELETE FROM hangout_members WHERE hangout_id = $1 AND user_id = $2", hubID, targetUserID)

	return c.JSON(fiber.Map{"success": true, "message": fmt.Sprintf("User %s banned from this hub", input.UserNum)})
}
