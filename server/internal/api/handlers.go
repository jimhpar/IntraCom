package api

import (
	"context"
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
	Email        string `json:"email"`
	Phone        string `json:"phone"`
	Password     string `json:"password"`
	DistrictCode int    `json:"district_code"`
}

type LoginRequest struct {
	Identifier string `json:"identifier"` // full_number (+1-3847291) or email or phone
	Password   string `json:"password"`
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

	if req.DisplayName == "" || req.Password == "" || req.Email == "" || req.Phone == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"error":   "All fields (name, email, phone, password, district) are required",
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

	// 4. Insert into database
	var userID string
	query := `
		INSERT INTO users (district_code, user_number, full_number, display_name, email, phone, password_hash, district_name)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
		RETURNING id
	`
	err = db.Pool.QueryRow(ctx, query,
		district.Code,
		userNumber,
		fullNumber,
		req.DisplayName,
		req.Email,
		req.Phone,
		passwordHash,
		district.NameEn,
	).Scan(&userID)

	if err != nil {
		log.Printf("Registration DB error: %v", err)
		if strings.Contains(err.Error(), "users_email_key") {
			return c.Status(fiber.StatusConflict).JSON(fiber.Map{"success": false, "error": "Email is already registered"})
		}
		if strings.Contains(err.Error(), "users_phone_key") {
			return c.Status(fiber.StatusConflict).JSON(fiber.Map{"success": false, "error": "Phone number is already registered"})
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
		email        string
		phone        string
		passwordHash string
	)

	query := `
		SELECT id, full_number, district_code, district_name, display_name, email, phone, password_hash
		FROM users
		WHERE full_number = $1 OR LOWER(email) = LOWER($1) OR phone = $1
	`
	err := db.Pool.QueryRow(ctx, query, req.Identifier).Scan(
		&userID,
		&fullNumber,
		&districtCode,
		&districtName,
		&displayName,
		&email,
		&phone,
		&passwordHash,
	)

	if err != nil {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
			"success": false,
			"error":   "User not found with provided number/email",
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
			"email":         email,
			"phone":         phone,
			"token":         token,
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
