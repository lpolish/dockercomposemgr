# Go Application Template

A modern Go application template with Gin framework, PostgreSQL, and Redis.

## Features

- Gin web framework
- PostgreSQL database with GORM
- Redis for caching and session management
- JWT authentication
- Structured logging
- Environment configuration
- Docker and Docker Compose setup

## Getting Started

1. Copy the `.env.example` file to `.env` and adjust the values:
   ```bash
   cp .env.example .env
   ```

2. Build and start the application:
   ```bash
   docker compose up --build
   ```

3. Access the application:
   - API: http://localhost:8080
   - Health Check: http://localhost:8080/health

## Project Structure

```
.
├── internal/
│   ├── api/          # API handlers and routes
│   ├── config/       # Configuration management
│   ├── database/     # Database connections
│   ├── middleware/   # HTTP middleware
│   ├── models/       # Data models
│   └── utils/        # Utility functions
├── Dockerfile        # Docker configuration
├── docker-compose.yml # Docker Compose configuration
├── go.mod           # Go module file
├── go.sum           # Go module checksum
└── main.go          # Application entry point
```

## Development

- The application uses hot-reload with Air (included in development)
- Database migrations are handled using GORM
- Tests can be run using the standard Go testing package

## Environment Variables

Create a `.env` file with the following variables:

```env
# Application
PORT=8080
DB_NAME=app

# Database
DB_HOST=db
DB_PORT=5432
DB_USER=postgres
DB_PASSWORD=postgres

# Redis
REDIS_URL=redis:6379
``` 