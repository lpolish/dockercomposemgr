package main

import (
	"app/internal/api"
	"app/internal/config"
	"app/internal/database"
	"app/internal/utils"
	"log"
)

func main() {
	// Load configuration
	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("Failed to load configuration: %v", err)
	}

	// Initialize logger
	logger := utils.NewLogger()
	logger.Info("Starting application...")

	// Initialize database
	db, err := database.NewPostgres(cfg)
	if err != nil {
		logger.Fatalf("Failed to connect to database: %v", err)
	}

	// Initialize Redis
	redis, err := database.NewRedis(cfg)
	if err != nil {
		logger.Fatalf("Failed to connect to Redis: %v", err)
	}

	// Initialize router
	router := api.NewRouter(db, redis, logger)

	// Start server
	logger.Infof("Server starting on port %s", cfg.Port)
	if err := router.Run(":" + cfg.Port); err != nil {
		logger.Fatalf("Failed to start server: %v", err)
	}
} 