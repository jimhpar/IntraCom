package main

import (
	"log"
	"os"

	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/fiber/v2/middleware/cors"
	"github.com/gofiber/fiber/v2/middleware/logger"
	"github.com/gofiber/fiber/v2/middleware/recover"
	"intracom-server/internal/numbering"
)

func main() {
	app := fiber.New(fiber.Config{
		AppName: "IntraCom Backend v1.0",
	})

	app.Use(logger.New())
	app.Use(recover.New())
	app.Use(cors.New(cors.Config{
		AllowOrigins: "*",
		AllowHeaders: "Origin, Content-Type, Accept, Authorization",
	}))

	// Health check
	app.Get("/health", func(c *fiber.Ctx) error {
		return c.JSON(fiber.Map{
			"status":  "healthy",
			"service": "IntraCom Core API",
		})
	})

	api := app.Group("/api/v1")

	// Public district list for registration
	api.Get("/districts", func(c *fiber.Ctx) error {
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

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	log.Printf("IntraCom Core API server listening on :%s", port)
	if err := app.Listen(":" + port); err != nil {
		log.Fatalf("Server failed to start: %v", err)
	}
}
