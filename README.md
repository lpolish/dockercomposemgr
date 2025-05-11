# Docker Compose Manager for Ubuntu

A command-line tool for managing Docker Compose applications on Ubuntu servers. This tool provides a simple and efficient way to manage multiple Docker Compose applications from a single interface.

## Features

- Manage multiple Docker Compose applications
- Start, stop, and restart applications
- View application status and logs
- Detailed application information and health monitoring
- Add and remove applications from management
- Update applications with latest images
- Simple and intuitive command-line interface

## Prerequisites

- Ubuntu 24.04 or later
- Docker installed
- Docker Compose installed
- Git installed

## Installation

### Quick Install

```bash
# Download the installation script
curl -O https://raw.githubusercontent.com/lpolish/dockercomposemgr/main/install.sh

# Make it executable
chmod +x install.sh

# Run the installer (requires sudo)
sudo ./install.sh install
```

### Manual Installation

1. Clone this repository:
```bash
git clone https://github.com/lpolish/dockercomposemgr.git
cd dockercomposemgr
```

2. Make the script executable:
```bash
chmod +x manage.sh
```

3. Create a symbolic link to make the command available system-wide:
```bash
sudo ln -s "$(pwd)/manage.sh" /usr/local/bin/dcm
```

### Uninstallation

To uninstall the tool:

```bash
sudo ./install.sh uninstall
```

## Usage

The tool provides the following commands:

### Main Menu
```bash
$ dcm --help
Docker Compose Manager
Usage: dcm [command] [options]

Commands:
  list                    List all managed applications
  status [app]           Show status of all or specific application
  info [app]             Show detailed information about application
  start [app]            Start all or specific application
  stop [app]             Stop all or specific application
  restart [app]          Restart all or specific application
  logs [app]             Show logs for all or specific application
  add <name> <path>      Add new application to manage
  remove <app>           Remove application from management
  update [app]           Update all or specific application

Options:
  -h, --help             Show this help message
```

### List Applications
```bash
$ dcm list
Managed Applications:
-------------------
- wordpress
- nginx
- postgres
```

### Show Application Status
```bash
$ dcm status wordpress
Checking wordpress...
Name                Command               State           Ports
------------------------------------------------------------------
wordpress_db_1      docker-entrypoint.sh  Up      5432/tcp
wordpress_web_1     docker-entrypoint.sh  Up      0.0.0.0:8080->80/tcp
```

### Show Detailed Application Information
```bash
$ dcm info wordpress
=== Detailed Information for wordpress ===

Container Status:
Name                Command               State           Ports
------------------------------------------------------------------
wordpress_db_1      docker-entrypoint.sh  Up      5432/tcp
wordpress_web_1     docker-entrypoint.sh  Up      0.0.0.0:8080->80/tcp

Resource Usage:
CPU and Memory usage for each container:
Container: wordpress_db_1
CONTAINER ID   NAME            CPU %     MEM USAGE / LIMIT     MEM %     NET I/O           BLOCK I/O         PIDS
abc123def456   wordpress_db_1  0.50%     156.3MiB / 2GiB      7.64%     1.2MB / 2.1MB     0B / 0B          12

Container: wordpress_web_1
CONTAINER ID   NAME             CPU %     MEM USAGE / LIMIT     MEM %     NET I/O           BLOCK I/O         PIDS
def456ghi789   wordpress_web_1  1.20%     245.7MiB / 2GiB      12.00%    2.5MB / 4.2MB     0B / 0B          8

Network Information:
NETWORK ID     NAME                DRIVER    SCOPE
abc123def456   wordpress_default   bridge    local

Volume Information:
DRIVER    VOLUME NAME
local     wordpress_db_data

Environment Configuration:
services:
  db:
    image: mysql:5.7
    environment:
      MYSQL_ROOT_PASSWORD: wordpress
      MYSQL_DATABASE: wordpress
  web:
    image: wordpress:latest
    ports:
      - "8080:80"
    depends_on:
      - db

Recent Logs (last 5 lines):
wordpress_db_1  | 2024-03-14 10:15:23.123 UTC [1] LOG:  database system is ready to accept connections
wordpress_web_1 | 2024-03-14 10:15:24.456 UTC [1] INFO: Starting Apache web server

Health Status:
Container: wordpress_db_1
Health: healthy
Container: wordpress_web_1
Health: healthy
```

### Start Applications
```bash
$ dcm start wordpress
Starting wordpress...
Creating network "wordpress_default"
Creating wordpress_db_1 ... done
Creating wordpress_web_1 ... done
```

### Stop Applications
```bash
$ dcm stop wordpress
Stopping wordpress...
Stopping wordpress_web_1 ... done
Stopping wordpress_db_1 ... done
Removing wordpress_web_1 ... done
Removing wordpress_db_1 ... done
Removing network wordpress_default
```

### Restart Applications
```bash
$ dcm restart wordpress
Restarting wordpress...
Restarting wordpress_db_1 ... done
Restarting wordpress_web_1 ... done
```

### View Logs
```bash
$ dcm logs wordpress
Logs for wordpress:
wordpress_db_1  | 2024-03-14 10:15:23.123 UTC [1] LOG:  database system is ready to accept connections
wordpress_web_1 | 2024-03-14 10:15:24.456 UTC [1] INFO: Starting Apache web server
```

### Add New Application
```bash
$ dcm add myapp /path/to/app
Application 'myapp' added successfully
```

### Remove Application
```bash
$ dcm remove myapp
Application 'myapp' removed successfully
```

### Update Applications
```bash
$ dcm update wordpress
Updating wordpress...
Pulling wordpress:latest ... done
Pulling mysql:5.7 ... done
Recreating wordpress_web_1 ... done
Recreating wordpress_db_1 ... done
```

## Directory Structure

```
.
├── manage.sh          # Main management script
├── install.sh         # Installation script
├── config/           # Configuration directory
├── apps/            # Managed applications directory
│   ├── wordpress/   # Application directory
│   │   └── docker-compose.yml
│   ├── nginx/       # Application directory
│   │   └── docker-compose.yml
│   └── postgres/    # Application directory
│       └── docker-compose.yml
└── logs/            # Log files directory
```

## Adding an Application

To add a new application to manage:

1. Ensure you have a valid `docker-compose.yml` file for your application. Example:
```yaml
version: '3'
services:
  web:
    image: nginx:latest
    ports:
      - "80:80"
  db:
    image: mysql:5.7
    environment:
      MYSQL_ROOT_PASSWORD: example
```

2. Run the add command:
```bash
dcm add myapp /path/to/app
```

The tool will copy the `docker-compose.yml` file to the apps directory and manage it from there.

## Best Practices

1. Always use the tool to manage your Docker Compose applications instead of running docker-compose commands directly
2. Keep your docker-compose.yml files organized and well-documented
3. Regularly update your applications using the update command
4. Monitor application logs for any issues
5. Use meaningful names for your applications
6. Keep your docker-compose.yml files in version control
7. Document any special configuration or environment variables needed
8. Use the info command regularly to monitor application health and resource usage

## Error Handling

The tool provides clear error messages for common issues:

```bash
$ dcm start nonexistent
Error: Application 'nonexistent' not found

$ dcm add myapp /invalid/path
Error: docker-compose.yml not found in specified path

$ dcm add
Error: Application name and path required
Usage: dcm add <name> <path>
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details. 