# Docker Compose Manager

A simple tool to manage multiple Docker Compose applications.

## Directory Structure

```
~/dockerapps/
├── apps.json           # Application configuration file
├── backups/           # Backup directory
└── app1/              # Application directory
    └── README.md      # Application documentation
```

## Configuration

The `apps.json` file stores the configuration for all managed applications in the following format:

```json
{
  "apps": {
    "app1": {
      "path": "/path/to/original/app1"
    },
    "app2": {
      "path": "/path/to/original/app2"
    }
  }
}
```

## Available Commands

- `list` - List all managed applications
- `status` - Show status of applications
- `info` - Show detailed information about an application
- `start` - Start application(s)
- `stop` - Stop application(s)
- `restart` - Restart application(s)
- `logs` - Show logs for application(s)
- `add <name> <path>` - Add a new application by referencing its path
- `clone <repo_url> <app_name>` - Clone a repository and add it as an application
- `remove <app>` - Remove an application
- `update` - Update application(s)
- `backup` - Backup application(s)
- `restore` - Restore application(s)
- `create` - Create a new application from template

## Adding Applications

When adding a new application, the system will:
1. Create a directory for the application in `~/dockerapps/`
2. Store the original path in `apps.json`
3. Copy any README.md file if it exists
4. Use the original docker-compose.yml file directly from the source path

Example:
```bash
dcm add myapp /path/to/myapp
```

## Cloning Applications

When cloning a repository, the system will:
1. Clone the repository to a temporary directory
2. Create a directory for the application in `~/dockerapps/`
3. Store the cloned repository path in `apps.json`
4. Copy any README.md file if it exists
5. Use the docker-compose.yml file directly from the cloned repository

Example:
```bash
dcm clone https://github.com/user/repo.git myapp
```

## Best Practices

1. **Application Organization**
   - Keep original docker-compose files in their source locations
   - Use the manager to reference and manage these applications
   - Store application-specific documentation in the application directory

2. **Configuration**
   - Use environment variables in .env files for configuration
   - Keep sensitive data in .env files
   - Use docker-compose.yml for container configuration

3. **Data Management**
   - Use named volumes for persistent data
   - Backup important data regularly
   - Use the backup/restore commands for application data

4. **Documentation**
   - Include a README.md in each application directory
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

# Start all applications
dcm start

# Check status of all applications
dcm status

# Update all applications
dcm update
```

### Backup and Restore

```bash
# Backup all applications
dcm backup

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

## Prerequisites

### Linux
- Docker installed
- Docker Compose installed
- Git installed
- Bash shell
- Either curl or wget installed (wget can be installed with `apt-get install wget` on Ubuntu/Debian)

### Windows
- Windows 10/11
- Docker Desktop for Windows installed
- Git for Windows installed
- PowerShell 5.1 or later

## Quick Install

### Linux
You can install the tool with a single command using either curl or wget:

Using curl (recommended, comes pre-installed on most systems):
```bash
curl -fsSL https://raw.githubusercontent.com/lpolish/dockercomposemgr/main/install.sh | bash
```

Or using wget (if you prefer, may need to be installed first):
```bash
# Install wget if not already installed (Ubuntu/Debian)
sudo apt-get update && sudo apt-get install -y wget

# Then run the installation
wget -qO- https://raw.githubusercontent.com/lpolish/dockercomposemgr/main/install.sh | bash
```

Or if you prefer to download and run the script manually:

Using curl:
```bash
curl -fsSL https://raw.githubusercontent.com/lpolish/dockercomposemgr/main/install.sh -o install.sh
chmod +x install.sh
./install.sh
```

Using wget:
```bash
wget https://raw.githubusercontent.com/lpolish/dockercomposemgr/main/install.sh
chmod +x install.sh
./install.sh
```

### Windows
You can install the tool using PowerShell:

```powershell
# Run in PowerShell as Administrator
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/lpolish/dockercomposemgr/main/install.ps1'))
```

Or if you prefer to download and run the script manually:

```powershell
# Run in PowerShell as Administrator
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/lpolish/dockercomposemgr/main/install.ps1" -OutFile "install.ps1"
Set-ExecutionPolicy Bypass -Scope Process -Force
.\install.ps1
```

## Manual Installation

### Linux
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

### Windows
1. Clone the repository:
   ```powershell
   git clone https://github.com/lpolish/dockercomposemgr.git
   cd dockercomposemgr
   ```

2. Create a PowerShell profile if it doesn't exist:
   ```powershell
   if (!(Test-Path -Path $PROFILE)) {
       New-Item -ItemType File -Path $PROFILE -Force
   }
   ```

3. Add the script to your PowerShell profile:
   ```powershell
   Add-Content -Path $PROFILE -Value "`$env:Path += `";$(pwd)`""
   ```

4. Copy the script to a permanent location:
   ```powershell
   Copy-Item "manage.ps1" "$env:USERPROFILE\AppData\Local\DockerComposeManager\dcm.ps1"
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
- `clone <repo_url> <app_name>` - Clone a repository and add it as a managed application
- `remove <app>` - Remove application from management
- `update [app]` - Update all or specific application
- `create` - Create a new application using templates

### Examples

1. List all managed applications:
   ```bash
   dcm list
   ```

2. Create a new application using templates:
   ```bash
   dcm create
   ```
   This will start an interactive wizard that:
   - Checks for Git installation
   - Shows available templates (Node.js, FastAPI, Next.js)
   - Downloads the selected template
   - Creates a new application directory
   - Initializes a Git repository
   - Updates configuration files with your application details

3. Add a new application:
   ```bash
   dcm add myapp /path/to/docker-compose.yml
   ```

4. Clone and add a repository as an application:
   ```bash
   dcm clone https://github.com/username/repo.git myapp
   ```

5. Start a specific application:
   ```bash
   dcm start myapp
   ```

6. View logs for an application:
   ```bash
   dcm logs myapp
   ```

7. Update all applications:
   ```bash
   dcm update
   ```

## Uninstallation

### Linux
To uninstall the tool, run:

```bash
curl -fsSL https://raw.githubusercontent.com/lpolish/dockercomposemgr/main/install.sh | bash -s uninstall
```

Or if you installed manually:

```bash
sudo rm /usr/local/bin/dcm
```

### Windows
To uninstall the tool, run:

```powershell
# Run in PowerShell as Administrator
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/lpolish/dockercomposemgr/main/install.ps1')) -ArgumentList "uninstall"
```

Or if you installed manually:

```powershell
Remove-Item -Path "$env:USERPROFILE\AppData\Local\DockerComposeManager" -Recurse -Force
```

## License

This project is licensed under the MIT License - see the LICENSE file for details. 