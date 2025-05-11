# FastAPI Application Template

This is a modern FastAPI application template with PostgreSQL integration.

## Features

- FastAPI web framework
- PostgreSQL database with SQLAlchemy ORM
- Docker and Docker Compose setup
- Environment configuration
- Basic project structure

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
   - API: http://localhost:8000
   - API Documentation: http://localhost:8000/docs
   - Health Check: http://localhost:8000/health

## Project Structure

```
.
├── app/
│   ├── main.py          # FastAPI application entry point
│   └── database.py      # Database configuration
├── Dockerfile           # Docker configuration
├── docker-compose.yml   # Docker Compose configuration
├── requirements.txt     # Python dependencies
└── .env                 # Environment variables (create from .env.example)
```

## Development

- The application uses hot-reload, so changes to the code will automatically restart the server
- Database migrations can be managed using Alembic (included in requirements.txt)
- Tests can be run using pytest (included in requirements.txt)

## Environment Variables

Create a `.env` file with the following variables:

```env
# Application
PORT=8000
DB_NAME=app

# Database
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres
POSTGRES_DB=app
``` 