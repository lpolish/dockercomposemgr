# Docker Compose Manager Templates

This directory contains application templates for the Docker Compose Manager. These templates provide ready-to-use application structures with Docker Compose configurations.

## Available Templates

### Node.js Template
- **Name**: Node.js (Express + PostgreSQL + Redis)
- **Description**: A full-stack Node.js application with Express, PostgreSQL, and Redis
- **Features**:
  - Express.js web framework
  - PostgreSQL database
  - Redis for caching
  - TypeScript support
  - Docker configuration
  - Development tools (nodemon, jest)

### FastAPI Template
- **Name**: FastAPI (Python + PostgreSQL)
- **Description**: A modern Python web application with FastAPI and PostgreSQL
- **Features**:
  - FastAPI framework
  - PostgreSQL database
  - SQLAlchemy ORM
  - Alembic migrations
  - Docker configuration
  - Testing setup

### Next.js Template
- **Name**: Next.js (React + PostgreSQL)
- **Description**: A modern React application with Next.js and PostgreSQL
- **Features**:
  - Next.js framework
  - PostgreSQL database
  - Docker configuration
  - Development tools

## Template Registry

The `registry.json` file contains metadata about all available templates, including:
- Template name and description
- Version information
- Required files
- Download URLs
- Tags for searching

## Using Templates

To create a new application using these templates:

```bash
# Using the Docker Compose Manager
dcm create

# Follow the interactive prompts to:
# 1. Select a template
# 2. Enter application name
# 3. Enter application description
```

The manager will:
1. Download the selected template
2. Initialize a Git repository
3. Set up the application structure
4. Configure the necessary files

## Template Structure

Each template directory should contain:
- `docker-compose.yml`: Docker Compose configuration
- `Dockerfile`: Container build instructions
- Required configuration files (e.g., `package.json`, `requirements.txt`)
- Any additional files needed for the application

## Adding New Templates

To add a new template:
1. Create a new directory in the `templates` folder
2. Add all necessary files
3. Update `registry.json` with the template metadata
4. Submit a pull request

See `CONTRIBUTING.md` for detailed contribution guidelines. 