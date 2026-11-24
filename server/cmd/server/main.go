package main

import (
	"log"
	"os"

	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/fiber/v2/middleware/cors"
	"github.com/gofiber/fiber/v2/middleware/logger"
	"github.com/gofiber/fiber/v2/middleware/recover"
	"github.com/gofiber/websocket/v2"

	"intracom-server/internal/api"
	"intracom-server/internal/db"
	"intracom-server/internal/numbering"
	"intracom-server/internal/signaling"
)

func main() {
	// 1. Initialize PostgreSQL Connection Pool
	_, err := db.ConnectDB()
	if err != nil {
		log.Printf("Warning: Database connection failed (will retry on operations): %v", err)
	}

	// 2. Start WebSocket Signaling Hub
	go signaling.GlobalHub.Run()
	log.Println("IntraCom Real-Time WebSocket Signaling Hub started")

	app := fiber.New(fiber.Config{
		AppName: "IntraCom Backend v1.1",
	})

	app.Use(logger.New())
	app.Use(recover.New())
	app.Use(cors.New(cors.Config{
		AllowOrigins: "*",
		AllowHeaders: "Origin, Content-Type, Accept, Authorization",
		AllowMethods: "GET, POST, PUT, DELETE, OPTIONS",
	}))

	// Health check
	app.Get("/health", func(c *fiber.Ctx) error {
		return c.JSON(fiber.Map{
			"status":  "healthy",
			"service": "IntraCom Core API",
			"version": "1.1.0",
		})
	})

	// Public district list
	app.Get("/api/v1/districts", func(c *fiber.Ctx) error {
		districts := make([]numbering.District, 0, len(numbering.Districts))
		for i := 1; i <= 64; i++ {
			if d, ok := numbering.Districts[i]; ok {
				districts = append(districts, d)
			}
		}
		return c.JSON(fiber.Map{
			"success": true,
			"data":    districts,
		})
	})

	// Auth routes
	authGroup := app.Group("/api/v1/auth")
	authGroup.Post("/register", api.RegisterHandler)
	authGroup.Post("/login", api.LoginHandler)

	// User protected routes
	userGroup := app.Group("/api/v1/users", api.UserAuthMiddleware)
	userGroup.Put("/me", api.UpdateProfileHandler)

	// Hangouts routes
	hangoutGroup := app.Group("/api/v1/hangouts")
	hangoutGroup.Get("/public", api.GetPublicHubsHandler)
	hangoutGroup.Post("/request-public", api.UserAuthMiddleware, api.RequestPublicHubHandler)
	hangoutGroup.Get("/private", api.UserAuthMiddleware, api.GetPrivateTablesHandler)
	hangoutGroup.Post("/private", api.UserAuthMiddleware, api.CreatePrivateTableHandler)

	// Admin protected routes
	adminGroup := app.Group("/api/v1/admin", api.AdminAuthMiddleware)
	adminGroup.Get("/stats", api.AdminStatsHandler)
	adminGroup.Get("/users", api.AdminListUsersHandler)
	adminGroup.Post("/users/manual", api.AdminManualCreateUserHandler)
	adminGroup.Put("/users/:id/suspend", api.AdminToggleSuspendHandler)
	adminGroup.Put("/users/:id/number", api.AdminUpdateUserNumberHandler)
	adminGroup.Get("/hub-requests", api.AdminListHubRequestsHandler)
	adminGroup.Post("/hub-requests/:id/review", api.AdminReviewHubRequestHandler)
	adminGroup.Post("/hubs/:id/bans", api.AdminBanUserFromHubHandler)

	// WebSocket Signaling Route (Audio, Video & Hangout voice channels)
	app.Use("/ws", func(c *fiber.Ctx) error {
		if websocket.IsWebSocketUpgrade(c) {
			c.Locals("allowed", true)
			return c.Next()
		}
		return fiber.ErrUpgradeRequired
	})
	app.Get("/ws", websocket.New(api.WebSocketHandler))

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	log.Printf("IntraCom Core API server listening on :%s", port)
	if err := app.Listen(":" + port); err != nil {
		log.Fatalf("Server failed to start: %v", err)
	}
}
