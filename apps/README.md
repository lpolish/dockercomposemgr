# Docker Apps Directory Structure

This directory is where you'll store your Docker Compose applications. Each application should be in its own subdirectory.

## Directory Structure

```
~/dockerapps/
├── app1/                  # Application directory
│   ├── docker-compose.yml # Symbolic link to Docker Compose configuration
│   ├── .env              # Symbolic link to environment variables (optional)
│   ├── data/             # Persistent data (if needed)
│   └── README.md         # Application documentation
├── app2/
│   └── ...
└── backups/              # Backup directory (managed by dcm)
```

## Best Practices

1. **Application Organization**
   - Each application should have its own directory
   - Use descriptive names for application directories
   - Keep related files together (compose file, env files, etc.)
   - Docker Compose files are referenced via symbolic links to maintain synchronization with source files

2. **Configuration**
   - Use `.env` files for environment variables
   - Keep sensitive data in `.env` files (not in docker-compose.yml)
   - Document configuration in README.md
   - Changes to source docker-compose files will be automatically reflected

3. **Data Management**
   - Use named volumes for persistent data
   - Keep application data in the `data/` subdirectory
   - Document data requirements in README.md

4. **Documentation**
   - Each application should have a README.md
   - Include setup instructions
   - Document any special requirements
   - List environment variables

## Example Application Structure

```yaml
# docker-compose.yml (referenced via symbolic link)
version: '3.8'
services:
  web:
    image: nginx:latest
    volumes:
      - ./data:/usr/share/nginx/html
    environment:
      - NGINX_HOST=example.com
    ports:
      - "80:80"
```

```env
# .env (referenced via symbolic link)
NGINX_HOST=example.com
```

## Available Commands

* `list` - List all managed applications
* `status [app]` - Show status of all or specific application
* `info [app]` - Show detailed information about application
* `start [app]` - Start all or specific application
* `stop [app]` - Stop all or specific application
* `restart [app]` - Restart all or specific application
* `logs [app]` - Show logs for all or specific application
* `add <name> <path>` - Add new application to manage (creates symbolic links)
* `clone <repo_url> <app_name>` - Clone a repository and add it as a managed application
* `remove <app>` - Remove application from management
* `update [app]` - Update all or specific application
* `create` - Create a new application using templates

## Managing Applications

Use the `dcm` command to manage your applications:

```bash
# List all applications
dcm list

# Add a new application (creates symbolic links)
dcm add myapp /path/to/docker-compose.yml

# Clone and add a repository as an application
dcm clone https://github.com/username/repo.git myapp

# Start an application
dcm start myapp

# Stop an application
dcm stop myapp

# Restart an application
dcm restart myapp

# View application status
dcm status myapp

# View application logs
dcm logs myapp

# Update an application
dcm update myapp

# Remove an application
dcm remove myapp

# Backup an application
dcm backup myapp

# Restore an application from backup
dcm restore myapp backup_file

# Create a new application from template
dcm create
```

### Cloning Applications

The `clone` command makes it easy to add existing Docker Compose applications from Git repositories:

```bash
# Clone a repository and add it as a managed application
dcm clone <repository_url> <app_name>
```

The command will:
1. Clone the repository
2. Check if it contains a `docker-compose.yml` file
3. If found, create symbolic links to the files in your managed apps directory
4. Copy any relevant documentation files (README.md)
5. Clean up temporary files

This is particularly useful for:
- Adding applications from public repositories
- Cloning your own repositories
- Quickly setting up pre-configured Docker Compose applications

## Configuration

The default apps directory can be changed in the configuration file:
`~/.config/dockercomposemgr/config.json`

```json
{
    "apps_directory": "~/dockerapps"
}
``` 