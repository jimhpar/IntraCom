package db

import (
	"context"
	"fmt"
	"log"
	"os"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

var Pool *pgxpool.Pool

func ConnectDB() (*pgxpool.Pool, error) {
	dbURL := os.Getenv("DATABASE_URL")
	if dbURL == "" {
		dbURL = "postgres://intracom:secretpassword@localhost:5432/intracom?sslmode=disable"
	}

	config, err := pgxpool.ParseConfig(dbURL)
	if err != nil {
		return nil, fmt.Errorf("unable to parse database config: %w", err)
	}

	config.MaxConns = 25
	config.MinConns = 2
	config.MaxConnLifetime = time.Hour

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	pool, err := pgxpool.NewWithConfig(ctx, config)
	if err != nil {
		return nil, fmt.Errorf("unable to create connection pool: %w", err)
	}

	if err := pool.Ping(ctx); err != nil {
		return nil, fmt.Errorf("unable to ping database: %w", err)
	}

	Pool = pool
	log.Println("PostgreSQL connection established successfully")
	return pool, nil
}
