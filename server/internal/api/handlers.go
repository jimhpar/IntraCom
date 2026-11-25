package api

import (
	"context"
	"database/sql"
	"encoding/json"
	"log"
	"strings"
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/websocket/v2"
	"intracom-server/internal/auth"
	"intracom-server/internal/db"
	"intracom-server/internal/numbering"
	"intracom-server/internal/signaling"
)

type RegisterRequest struct {
	DisplayName  string `json:"display_name"`
	Email        string `json:"email"` // OPTIONAL
	Phone        string `json:"phone"`
	Password     string `json:"password"`
	DistrictCode int    `json:"district_code"`
}

type LoginRequest struct {
	Identifier string `json:"identifier"` // full_number (+1-3847291) or phone or email
	Password   string `json:"password"`
}

type UpdateProfileRequest struct {
	DisplayName string `json:"display_name"`
	Bio         string `json:"bio"`
}

func RegisterHandler(c *fiber.Ctx) error {
	var req RegisterRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"error":   "Invalid request body",
		})
	}

	req.Email = strings.TrimSpace(strings.ToLower(req.Email))
	req.Phone = strings.TrimSpace(req.Phone)
	req.DisplayName = strings.TrimSpace(req.DisplayName)

	// Note: Email is OPTIONAL. Only DisplayName, Phone, Password, and District are required!
	if req.DisplayName == "" || req.Password == "" || req.Phone == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"error":   "Name, phone number, and password are required",
		})
	}

	// 1. Verify District Code
	district, ok := numbering.Districts[req.DistrictCode]
	if !ok {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"error":   "Invalid Bangladesh district code. Must be between 1 and 64.",
		})
	}

	// 2. Hash Password
	passwordHash, err := auth.HashPassword(req.Password)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"success": false,
			"error":   "Failed to process password",
		})
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	// 3. Generate unique 7-digit ID (retry if collision)
	var userNumber, fullNumber string
	for attempts := 0; attempts < 5; attempts++ {
		genID, err := numbering.Generate7DigitID()
		if err != nil {
			continue
		}
		candidateNumber := numbering.FormatIntraComNumber(district.Code, genID)

		var exists bool
		err = db.Pool.QueryRow(ctx, "SELECT EXISTS(SELECT 1 FROM users WHERE full_number = $1)", candidateNumber).Scan(&exists)
		if err == nil && !exists {
			userNumber = genID
			fullNumber = candidateNumber
			break
		}
	}

	if fullNumber == "" {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"success": false,
			"error":   "Failed to assign unique IntraCom number. Please try again.",
		})
	}

	// Handle optional email
	var emailParam interface{} = nil
	if req.Email != "" {
		emailParam = req.Email
	}

	// 4. Insert into database
	var userID string
	var isAdmin bool
	query := `
		INSERT INTO users (district_code, user_number, full_number, display_name, email, phone, password_hash, district_name)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
		RETURNING id, is_admin
	`
	err = db.Pool.QueryRow(ctx, query,
		district.Code,
		userNumber,
		fullNumber,
		req.DisplayName,
		emailParam,
		req.Phone,
		passwordHash,
		district.NameEn,
	).Scan(&userID, &isAdmin)

	if err != nil {
		log.Printf("Registration DB error: %v", err)
		if strings.Contains(err.Error(), "users_phone_key") {
			return c.Status(fiber.StatusConflict).JSON(fiber.Map{"success": false, "error": "This mobile phone number is already registered"})
		}
		if strings.Contains(err.Error(), "users_email_key") {
			return c.Status(fiber.StatusConflict).JSON(fiber.Map{"success": false, "error": "This email is already registered"})
		}
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"success": false, "error": "Database registration failed"})
	}

	// 5. Generate JWT token
	token, err := auth.GenerateToken(userID, fullNumber)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"success": false, "error": "Failed to create session token"})
	}

	return c.Status(fiber.StatusCreated).JSON(fiber.Map{
		"success": true,
		"message": "Account created successfully",
		"data": fiber.Map{
			"user_id":       userID,
			"full_number":   fullNumber,
			"district_code": district.Code,
			"district_name": district.NameEn,
			"district_bn":   district.NameBn,
			"display_name":  req.DisplayName,
			"email":         req.Email,
			"phone":         req.Phone,
			"is_admin":      isAdmin,
			"token":         token,
		},
	})
}

func LoginHandler(c *fiber.Ctx) error {
	var req LoginRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"success": false, "error": "Invalid request body"})
	}

	req.Identifier = strings.TrimSpace(req.Identifier)
	if req.Identifier == "" || req.Password == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"success": false, "error": "Identifier and password required"})
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	var (
		userID       string
		fullNumber   string
		districtCode int
		districtName string
		displayName  string
		phone        string
		passwordHash string
		email        sql.NullString
		bio          sql.NullString
		isSuspended  bool
		isAdmin      bool
	)

	query := `
		SELECT id, full_number, district_code, district_name, display_name, phone, password_hash, email, bio, is_suspended, is_admin
		FROM users
		WHERE full_number = $1 OR phone = $1 OR (email IS NOT NULL AND LOWER(email) = LOWER($1))
	`
	err := db.Pool.QueryRow(ctx, query, req.Identifier).Scan(
		&userID,
		&fullNumber,
		&districtCode,
		&districtName,
		&displayName,
		&phone,
		&passwordHash,
		&email,
		&bio,
		&isSuspended,
		&isAdmin,
	)

	if err != nil {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
			"success": false,
			"error":   "User not found with provided number/phone",
		})
	}

	// Check if user is suspended
	if isSuspended {
		return c.Status(fiber.StatusForbidden).JSON(fiber.Map{
			"success": false,
			"error":   "Your IntraCom account has been suspended by an administrator. Please contact support.",
		})
	}

	if !auth.CheckPassword(req.Password, passwordHash) {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
			"success": false,
			"error":   "Incorrect password",
		})
	}

	token, err := auth.GenerateToken(userID, fullNumber)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"success": false, "error": "Failed to create session token"})
	}

	return c.JSON(fiber.Map{
		"success": true,
		"data": fiber.Map{
			"user_id":       userID,
			"full_number":   fullNumber,
			"district_code": districtCode,
			"district_name": districtName,
			"display_name":  displayName,
			"email":         email.String,
			"phone":         phone,
			"bio":           bio.String,
			"is_admin":      isAdmin,
			"token":         token,
		},
	})
}

// GET /api/v1/users/me - Fetch latest profile information from DB
func GetProfileHandler(c *fiber.Ctx) error {
	claims, ok := c.Locals("user").(*auth.JWTClaims)
	if !ok {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"success": false, "error": "Unauthorized"})
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	var (
		id, fullNumber, displayName, phone, districtName string
		email, bio                                       sql.NullString
		districtCode                                     int
		isAdmin, isSuspended                             bool
	)

	query := `
		SELECT id, full_number, district_code, district_name, display_name, phone, email, bio, is_admin, is_suspended
		FROM users
		WHERE id = $1
	`
	err := db.Pool.QueryRow(ctx, query, claims.UserID).Scan(
		&id, &fullNumber, &districtCode, &districtName, &displayName, &phone, &email, &bio, &isAdmin, &isSuspended,
	)
	if err != nil {
		return c.Status(fiber.StatusNotFound).JSON(fiber.Map{"success": false, "error": "User not found"})
	}

	return c.JSON(fiber.Map{
		"success": true,
		"data": fiber.Map{
			"user_id":       id,
			"full_number":   fullNumber,
			"district_code": districtCode,
			"district_name": districtName,
			"display_name":  displayName,
			"phone":         phone,
			"email":         email.String,
			"bio":           bio.String,
			"is_admin":      isAdmin,
			"is_suspended":  isSuspended,
		},
	})
}

type ChangePasswordRequest struct {
	OldPassword string `json:"old_password"`
	NewPassword string `json:"new_password"`
}

// PUT /api/v1/users/change-password - Change user password
func ChangePasswordHandler(c *fiber.Ctx) error {
	claims, ok := c.Locals("user").(*auth.JWTClaims)
	if !ok {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"success": false, "error": "Unauthorized"})
	}

	var req ChangePasswordRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"success": false, "error": "Invalid request body"})
	}

	if req.OldPassword == "" || req.NewPassword == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"success": false, "error": "Both old and new password are required"})
	}

	if len(req.NewPassword) < 6 {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"success": false, "error": "New password must be at least 6 characters"})
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	var currentHash string
	err := db.Pool.QueryRow(ctx, "SELECT password_hash FROM users WHERE id = $1", claims.UserID).Scan(&currentHash)
	if err != nil {
		return c.Status(fiber.StatusNotFound).JSON(fiber.Map{"success": false, "error": "User not found"})
	}

	if !auth.CheckPassword(req.OldPassword, currentHash) {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"success": false, "error": "Current password is incorrect"})
	}

	newHash, err := auth.HashPassword(req.NewPassword)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"success": false, "error": "Failed to hash new password"})
	}

	_, err = db.Pool.Exec(ctx, "UPDATE users SET password_hash = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2", newHash, claims.UserID)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"success": false, "error": "Failed to update password"})
	}

	return c.JSON(fiber.Map{
		"success": true,
		"message": "Password changed successfully",
	})
}

// GET /api/v1/users/online - Returns list of currently connected user numbers
func GetOnlineUsersHandler(c *fiber.Ctx) error {
	onlineList := signaling.GlobalHub.GetOnlineUsers()
	return c.JSON(fiber.Map{
		"success": true,
		"data":    onlineList,
	})
}

// PUT /api/v1/users/me - Update profile name and bio
func UpdateProfileHandler(c *fiber.Ctx) error {
	claims, ok := c.Locals("user").(*auth.JWTClaims)
	if !ok {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"success": false, "error": "Unauthorized"})
	}

	var req UpdateProfileRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"success": false, "error": "Invalid body"})
	}

	req.DisplayName = strings.TrimSpace(req.DisplayName)
	if req.DisplayName == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"success": false, "error": "Name cannot be empty"})
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	_, err := db.Pool.Exec(ctx, "UPDATE users SET display_name = $1, bio = $2, updated_at = CURRENT_TIMESTAMP WHERE id = $3",
		req.DisplayName, req.Bio, claims.UserID)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"success": false, "error": "Failed to update profile"})
	}

	return c.JSON(fiber.Map{
		"success": true,
		"message": "Profile updated successfully",
		"data": fiber.Map{
			"display_name": req.DisplayName,
			"bio":          req.Bio,
		},
	})
}

func WebSocketHandler(c *websocket.Conn) {
	token := c.Query("token")
	if token == "" {
		log.Println("WS connection rejected: no token provided")
		c.Close()
		return
	}

	claims, err := auth.ValidateToken(token)
	if err != nil {
		log.Printf("WS connection rejected: invalid token: %v", err)
		c.Close()
		return
	}

	// Verify suspension status before allowing connection
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	var isSuspended bool
	_ = db.Pool.QueryRow(ctx, "SELECT is_suspended FROM users WHERE id = $1", claims.UserID).Scan(&isSuspended)
	cancel()
	if isSuspended {
		log.Printf("WS connection rejected: user %s is suspended", claims.FullNumber)
		c.Close()
		return
	}

	client := &signaling.Client{
		FullNumber: claims.FullNumber,
		Conn:       c,
		Send:       make(chan []byte, 256),
		Hub:        signaling.GlobalHub,
	}

	signaling.GlobalHub.RegisterClient(client)

	// Pump outgoing messages from channel to websocket connection
	go func() {
		defer c.Close()
		for message := range client.Send {
			if err := c.WriteMessage(websocket.TextMessage, message); err != nil {
				break
			}
		}
	}()

	// Read incoming signals from client
	for {
		_, msgBytes, err := c.ReadMessage()
		if err != nil {
			break
		}

		var signal signaling.SignalMessage
		if err := json.Unmarshal(msgBytes, &signal); err != nil {
			continue
		}

		signal.From = client.FullNumber // Enforce authentic sender identity
		signal.Timestamp = time.Now().UnixMilli()

		switch signal.Type {
		case "hangout_join":
			if signal.HangoutID != "" {
				signaling.GlobalHub.JoinHangout(signal.HangoutID, client.FullNumber)
			}
		case "hangout_leave":
			if signal.HangoutID != "" {
				signaling.GlobalHub.LeaveHangout(signal.HangoutID, client.FullNumber)
			}
		default:
			signaling.GlobalHub.RouteMessage(signal)
		}
	}

	signaling.GlobalHub.UnregisterClient(client)
}
