# Docker Compose Manager

A command-line tool for managing Docker Compose applications on Ubuntu 24.04.

## Features

- Manage multiple Docker Compose applications
- Start, stop, and restart applications
- View application status and logs
- Detailed application information and health monitoring
- Add and remove applications from management
- Update applications with latest images
- Simple and intuitive command-line interface

## Prerequisites

- Ubuntu 24.04
- Docker installed
- Docker Compose installed
- Git installed

## Quick Install

You can install the tool with a single command:

```bash
curl -fsSL https://raw.githubusercontent.com/lpolish/dockercomposemgr/main/install.sh | bash
```

Or if you prefer to download and run the script manually:

```bash
curl -fsSL https://raw.githubusercontent.com/lpolish/dockercomposemgr/main/install.sh -o install.sh
chmod +x install.sh
./install.sh
```

## Manual Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/lpolish/dockercomposemgr.git
   cd dockercomposemgr
   ```

2. Make the script executable:
   ```bash
   chmod +x manage.sh
   ```

3. Create a symbolic link to make it available system-wide:
   ```bash
   sudo ln -s "$(pwd)/manage.sh" /usr/local/bin/dcm
   ```

## Usage

The tool provides several commands for managing your Docker Compose applications:

```bash
dcm [command] [options]
```

### Available Commands

- `list` - List all managed applications
- `status [app]` - Show status of all or specific application
- `info [app]` - Show detailed information about application
- `start [app]` - Start all or specific application
- `stop [app]` - Stop all or specific application
- `restart [app]` - Restart all or specific application
- `logs [app]` - Show logs for all or specific application
- `add <name> <path>` - Add new application to manage
- `remove <app>` - Remove application from management
- `update [app]` - Update all or specific application

### Examples

1. List all managed applications:
   ```bash
   dcm list
   ```

2. Add a new application:
   ```bash
   dcm add myapp /path/to/docker-compose.yml
   ```

3. Start a specific application:
   ```bash
   dcm start myapp
   ```

4. View logs for an application:
   ```bash
   dcm logs myapp
   ```

5. Update all applications:
   ```bash
   dcm update
   ```

## Uninstallation

To uninstall the tool, run:

```bash
curl -fsSL https://raw.githubusercontent.com/lpolish/dockercomposemgr/main/install.sh | bash -s uninstall
```

Or if you installed manually:

```bash
sudo rm /usr/local/bin/dcm
```

## License

This project is licensed under the MIT License - see the LICENSE file for details. 