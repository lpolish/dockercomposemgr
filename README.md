# Docker Compose Manager

A simple tool to manage multiple Docker Compose applications on both Linux and Windows.

## Directory Structure

### Linux (System-wide Installation)
```
/etc/dockercomposemgr/
├── config.json        # Global configuration file
├── apps.json         # Application configuration file
└── /opt/dockerapps/  # Application directory
    ├── backups/      # Backup directory
    └── app1/         # Application directory
        └── README.md # Application documentation
```

### Linux (User-specific Installation)
```
~/.config/dockercomposemgr/
├── config.json        # Global configuration file
├── apps.json         # Application configuration file
└── ~/dockerapps/     # Application directory
    ├── backups/      # Backup directory
    └── app1/         # Application directory
        └── README.md # Application documentation
```

### Windows
```
%USERPROFILE%\.config\dockercomposemgr\
├── config.json        # Global configuration file
├── apps.json         # Application configuration file
└── %USERPROFILE%\dockerapps\  # Application directory
    ├── backups/      # Backup directory
    └── app1/         # Application directory
        └── README.md # Application documentation
```

## Configuration

The `config.json` file stores global configuration:

```json
{
  "apps_directory": "~/dockerapps",
  "backup": {
    "include_volumes": true
  }
}
```

The `apps.json` file stores the configuration for all managed applications:

```json
{
  "version": "1.0.0",
  "apps": {
    "app1": {
      "path": "/path/to/original/app1"
    },
    "app2": {
      "path": "/path/to/original/app2"
    }
  },
  "last_updated": "2024-03-21T12:00:00Z"
}
```

## Available Commands

- `list` - List all managed applications
- `add <name> <path>` - Add a new application by referencing its path
- `clone <repo> <name>` - Clone and add an application from a repository
- `remove <name>` - Remove an application
- `start <name>` - Start an application
- `stop <name>` - Stop an application
- `restart <name>` - Restart an application
- `status [name]` - Show application status
- `logs <name>` - Show application logs
- `info <name>` - Show detailed application information
- `backup <name>` - Backup an application
- `restore <name> <backup>` - Restore an application from backup
- `update <name>` - Update an application
- `help` - Show help message

## Adding Applications

When adding a new application, the system will:
1. Create a directory for the application in the configured apps directory
2. Store the original path in `apps.json`
3. Create symbolic links to the original docker-compose.yml and .env files

Example:
```bash
# Linux
dcm add myapp /path/to/myapp

# Windows
dcm add myapp C:\path\to\myapp
```

## Cloning Applications

When cloning a repository, the system will:
1. Clone the repository to a temporary directory
2. Create a directory for the application in the configured apps directory
3. Store the cloned repository path in `apps.json`
4. Copy the docker-compose.yml and .env files
5. Copy the README.md if it exists

Example:
```bash
dcm clone https://github.com/user/repo.git myapp
```

## Best Practices

1. **Application Organization**
   - Keep original docker-compose files in their source locations
   - Use the manager to reference and manage these applications
   - Store application-specific documentation in the original application directory

2. **Configuration**
   - Use environment variables in .env files for configuration
   - Keep sensitive data in .env files
   - Use docker-compose.yml for container configuration

3. **Data Management**
   - Use named volumes for persistent data
   - Backup important data regularly
   - Use the backup/restore commands for application data

4. **Documentation**
   - Include a README.md in your original application directory
   - Document any special configuration requirements
   - Keep track of application dependencies

## Examples

### Adding an Existing Application

```bash
# Add an application from a local path
dcm add myapp /path/to/myapp

# Check its status
dcm status myapp

# Start the application
dcm start myapp
```

### Cloning and Managing a Repository

```bash
# Clone a repository
dcm clone https://github.com/user/repo.git myapp

# Check its status
dcm status myapp

# Start the application
dcm start myapp
```

### Managing Multiple Applications

```bash
# List all applications
dcm list

# Check status of all applications
dcm status

# Update a specific application
dcm update myapp
```

### Backup and Restore

```bash
# Backup a specific application
dcm backup myapp

# Restore an application
dcm restore myapp backup_file.tar.gz
```

## Features

- Manage multiple Docker Compose applications
- Start, stop, and restart applications
- View application status and logs
- Detailed application information and health monitoring
- Add and remove applications from management
- Update applications with latest images
- Simple and intuitive command-line interface
- Cross-platform support (Linux and Windows)
- Automatic backup and restore functionality
- Volume management and backup
- Health status monitoring
- Resource usage tracking

## Prerequisites

### Linux
- Docker installed
- Docker Compose installed
- Git installed
- Bash shell
- jq installed (can be installed with `apt-get install jq` on Ubuntu/Debian)
- Either curl or wget installed (wget can be installed with `apt-get install wget` on Ubuntu/Debian)

### Windows
- Windows 10/11
- Docker Desktop for Windows installed
- Git for Windows installed
- PowerShell 5.1 or later
- Administrator privileges (for symbolic links)

## Quick Install

### Linux
You can install the tool with a single command using either curl or wget:

#### System-wide Installation (requires sudo)
Using curl (recommended, comes pre-installed on most systems):
```bash
curl -fsSL https://raw.githubusercontent.com/lpolish/dockercomposemgr/main/install.sh | sudo bash -s -- -y
```

Or using wget (if you prefer, may need to be installed first):
```bash
# Install wget if not already installed (Ubuntu/Debian)
sudo apt-get update && sudo apt-get install -y wget

# Then run the installation
wget -qO- https://raw.githubusercontent.com/lpolish/dockercomposemgr/main/install.sh | sudo bash -s -- -y
```

#### User-specific Installation (no sudo required)
Using curl:
```bash
curl -fsSL https://raw.githubusercontent.com/lpolish/dockercomposemgr/main/install.sh | bash -s -- --user
```

Or using wget:
```bash
wget -qO- https://raw.githubusercontent.com/lpolish/dockercomposemgr/main/install.sh | bash -s -- --user
```

The user-specific installation will:
1. Install the tool in `~/.local/bin`
2. Create configuration in `~/.config/dockercomposemgr`
3. Create application directory in `~/dockerapps`
4. Add `~/.local/bin` to your PATH (requires shell restart or `source ~/.bashrc`)

### Windows
You can install the tool with a single command in PowerShell:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/lpolish/dockercomposemgr/main/install.ps1'))
```

## Uninstallation

### Linux

```bash
# Run the uninstaller
./install.sh --uninstall

# Or use the -u flag
./install.sh -u
```

### Windows

```powershell
# Run the uninstaller
.\install.ps1 -Uninstall
```

## Troubleshooting

### Common Issues

1. **Symbolic Link Creation Fails (Windows)**
   - Ensure you're running PowerShell as Administrator
   - Enable Developer Mode in Windows Settings
   - Or use the `mklink` command manually

2. **Docker Not Running**
   - Ensure Docker Desktop is running (Windows)
   - Check Docker daemon status (Linux)
   - Verify Docker service is running

3. **Permission Issues**
   - Check file and directory permissions
   - Ensure you have write access to the apps directory
   - Verify Docker socket permissions (Linux)
   - For user-specific installation, ensure `~/.local/bin` is in your PATH

4. **Backup/Restore Issues**
   - Ensure sufficient disk space
   - Check volume permissions
   - Verify tar command availability

5. **Command Not Found After Installation**
   - For user-specific installation, restart your shell or run `source ~/.bashrc`
   - Verify that `~/.local/bin` is in your PATH
   - Check if the installation completed successfully

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details. 