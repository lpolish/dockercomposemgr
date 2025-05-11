# Ruby on Rails Application Template

A modern Ruby on Rails application template with PostgreSQL and Redis.

## Features

- Ruby on Rails 7.1
- PostgreSQL database
- Redis for caching and background jobs
- Devise for authentication
- Pundit for authorization
- Sidekiq for background processing
- RSpec for testing
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
   - Web: http://localhost:3000
   - API: http://localhost:3000/api/v1
   - Sidekiq Dashboard: http://localhost:3000/sidekiq

## Project Structure

```
.
├── app/
│   ├── controllers/    # Application controllers
│   ├── models/        # Data models
│   ├── views/         # View templates
│   ├── helpers/       # View helpers
│   ├── mailers/       # Mailer classes
│   └── jobs/          # Background jobs
├── config/            # Application configuration
├── db/                # Database files
├── lib/               # Library modules
├── spec/              # Test files
├── Dockerfile         # Docker configuration
├── docker-compose.yml # Docker Compose configuration
└── Gemfile           # Ruby dependencies
```

## Development

- The application uses hot-reload in development
- Database migrations are handled using Rails migrations
- Tests can be run using RSpec
- Code style is enforced using RuboCop

## Environment Variables

Create a `.env` file with the following variables:

```env
# Application
PORT=3000
RAILS_ENV=development
SECRET_KEY_BASE=your_secret_key_base

# Database
DATABASE_URL=postgresql://postgres:postgres@db:5432/app
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres
POSTGRES_DB=app

# Redis
REDIS_URL=redis://redis:6379/1
``` 