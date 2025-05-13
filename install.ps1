# Docker Compose Manager Installer for Windows
# A command-line tool for managing Docker Compose applications

# Colors for output
$RED = [System.ConsoleColor]::Red
$GREEN = [System.ConsoleColor]::Green
$YELLOW = [System.ConsoleColor]::Yellow
$CYAN = [System.ConsoleColor]::Cyan

# Installation paths
$INSTALL_DIR = "$env:USERPROFILE\AppData\Local\DockerComposeManager"
$CONFIG_DIR = "$env:USERPROFILE\.config\dockercomposemgr"
$DEFAULT_APPS_DIR = "$env:USERPROFILE\dockerapps"

# Check if running in non-interactive mode
$INTERACTIVE = [Console]::IsInputRedirected -eq $false

# Function to display usage
function Show-Usage {
    Write-Host "Docker Compose Manager Installer"
    Write-Host "Usage: $($MyInvocation.MyCommand.Name) [options]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -h, --help     Show this help message"
    Write-Host "  -u, --uninstall Remove Docker Compose Manager"
    Write-Host "  -y, --yes      Non-interactive mode, install everything"
}

# Function to check if running as administrator
function Test-Administrator {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Function to download a file
function Download-File {
    param (
        [string]$Url,
        [string]$Output
    )
    
    try {
        Invoke-WebRequest -Uri $Url -OutFile $Output -UseBasicParsing
        return $true
    }
    catch {
        Write-Host "Error downloading file: $_" -ForegroundColor $RED
        return $false
    }
}

# Function to check requirements
function Test-Requirements {
    $missing = 0
    Write-Host "Checking requirements..." -ForegroundColor $CYAN

    # Check Docker Desktop
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        Write-Host "Docker Desktop is not installed." -ForegroundColor $RED
        $missing = 1
    }
    elseif (-not (docker compose version 2>$null)) {
        Write-Host "Docker Compose is not available." -ForegroundColor $RED
        $missing = 1
    }

    # Check jq
    if (-not (Get-Command jq -ErrorAction SilentlyContinue)) {
        Write-Host "jq is not installed." -ForegroundColor $RED
        $missing = 1
    }

    if ($missing -eq 1) {
        return $false
    }
    Write-Host "All requirements satisfied." -ForegroundColor $GREEN
    return $true
}

# Function to install Docker Desktop
function Install-DockerDesktop {
    Write-Host "Installing Docker Desktop..." -ForegroundColor $CYAN
    
    # Download Docker Desktop installer
    $installerPath = "$env:TEMP\DockerDesktopInstaller.exe"
    if (-not (Download-File "https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe" $installerPath)) {
        Write-Host "Failed to download Docker Desktop installer." -ForegroundColor $RED
        return $false
    }

    # Run the installer
    Write-Host "Running Docker Desktop installer..." -ForegroundColor $CYAN
    Start-Process -FilePath $installerPath -ArgumentList "install --quiet" -Wait

    # Clean up
    Remove-Item $installerPath -Force

    Write-Host "Docker Desktop installed successfully." -ForegroundColor $GREEN
    Write-Host "Please restart your computer to complete the installation." -ForegroundColor $YELLOW
    return $true
}

# Function to install jq
function Install-Jq {
    Write-Host "Installing jq..." -ForegroundColor $CYAN
    
    # Download jq
    $jqPath = "$env:TEMP\jq.exe"
    if (-not (Download-File "https://github.com/stedolan/jq/releases/download/jq-1.6/jq-win64.exe" $jqPath)) {
        Write-Host "Failed to download jq." -ForegroundColor $RED
        return $false
    }

    # Create directory if it doesn't exist
    $jqDir = "$env:ProgramFiles\jq"
    if (-not (Test-Path $jqDir)) {
        New-Item -ItemType Directory -Path $jqDir -Force | Out-Null
    }

    # Move jq to Program Files
    Move-Item -Path $jqPath -Destination "$jqDir\jq.exe" -Force

    # Add to PATH
    $currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    if (-not $currentPath.Contains($jqDir)) {
        [Environment]::SetEnvironmentVariable("Path", "$currentPath;$jqDir", "Machine")
    }

    Write-Host "jq installed successfully." -ForegroundColor $GREEN
    return $true
}

# Function to create default configuration
function New-DefaultConfig {
    Write-Host "Creating default configuration..." -ForegroundColor $CYAN
    
    # Create config directory
    if (-not (Test-Path $CONFIG_DIR)) {
        New-Item -ItemType Directory -Path $CONFIG_DIR -Force | Out-Null
    }
    
    # Create config.json if it doesn't exist
    $configPath = "$CONFIG_DIR\config.json"
    if (-not (Test-Path $configPath)) {
        @{
            apps_directory = $DEFAULT_APPS_DIR
            log_level = "info"
            log_retention_days = 7
            backup = @{
                include_volumes = $true
                retention_days = 30
            }
        } | ConvertTo-Json | Set-Content $configPath
    }
    
    # Create apps.json if it doesn't exist
    $appsPath = "$CONFIG_DIR\apps.json"
    if (-not (Test-Path $appsPath)) {
        @{
            apps = @{}
        } | ConvertTo-Json | Set-Content $appsPath
    }
    
    Write-Host "Default configuration created successfully." -ForegroundColor $GREEN
}

# Function to create apps directory structure
function New-AppsDirectory {
    Write-Host "Creating apps directory structure..." -ForegroundColor $CYAN
    
    # Create apps directory
    if (-not (Test-Path $DEFAULT_APPS_DIR)) {
        New-Item -ItemType Directory -Path $DEFAULT_APPS_DIR -Force | Out-Null
    }
    if (-not (Test-Path "$DEFAULT_APPS_DIR\backups")) {
        New-Item -ItemType Directory -Path "$DEFAULT_APPS_DIR\backups" -Force | Out-Null
    }
    
    # Create README if it doesn't exist
    $readmePath = "$DEFAULT_APPS_DIR\README.md"
    if (-not (Test-Path $readmePath)) {
        @"
# Docker Applications Directory

This directory contains your Docker Compose applications managed by Docker Compose Manager.

## Directory Structure

Each application should be in its own subdirectory with the following structure:

\`\`\`
app_name/
├── docker-compose.yml    # Docker Compose configuration
├── .env                  # Environment variables (optional)
└── data/                # Application data (optional)
\`\`\`

## Best Practices

1. Keep each application in its own directory
2. Use descriptive names for applications
3. Include a README.md in each application directory
4. Store sensitive data in .env files
5. Use named volumes for persistent data

## Managing Applications

Use the \`dcm\` command to manage your applications:

\`\`\`powershell
# List all applications
dcm list

# Start an application
dcm start app_name

# Stop an application
dcm stop app_name

# View application logs
dcm logs app_name

# Add a new application
dcm add app_name /path/to/docker-compose.yml

# Remove an application
dcm remove app_name
\`\`\`
"@ | Set-Content $readmePath
    }
    
    Write-Host "Apps directory structure created successfully." -ForegroundColor $GREEN
}

# Function to install dependencies
function Install-Dependencies {
    if (-not (Test-Administrator)) {
        Write-Host "This operation requires administrator privileges." -ForegroundColor $RED
        Write-Host "Please run the script as administrator." -ForegroundColor $YELLOW
        return $false
    }

    Write-Host "Installing dependencies..." -ForegroundColor $CYAN
    
    # Install Docker Desktop if needed
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        if (-not (Install-DockerDesktop)) {
            return $false
        }
    }
    
    # Install jq if needed
    if (-not (Get-Command jq -ErrorAction SilentlyContinue)) {
        if (-not (Install-Jq)) {
            return $false
        }
    }
    
    return $true
}

# Function to install manager
function Install-Manager {
    Write-Host "Installing Docker Compose Manager..." -ForegroundColor $CYAN
    
    # Create installation directory
    if (-not (Test-Path $INSTALL_DIR)) {
        New-Item -ItemType Directory -Path $INSTALL_DIR -Force | Out-Null
    }
    
    # Download management script
    Write-Host "Downloading management script..." -ForegroundColor $CYAN
    if (-not (Download-File "https://raw.githubusercontent.com/lpolish/dockercomposemgr/main/manage.ps1" "$INSTALL_DIR\dcm.ps1")) {
        Write-Host "Failed to download management script." -ForegroundColor $RED
        return $false
    }
    
    # Create PowerShell profile if it doesn't exist
    if (-not (Test-Path $PROFILE)) {
        New-Item -ItemType File -Path $PROFILE -Force | Out-Null
    }
    
    # Add to PowerShell profile
    $profileContent = Get-Content $PROFILE -Raw
    if (-not $profileContent.Contains($INSTALL_DIR)) {
        Add-Content -Path $PROFILE -Value "`$env:Path += `";$INSTALL_DIR`""
    }
    
    # Create default configuration
    New-DefaultConfig
    
    # Create apps directory structure
    New-AppsDirectory
    
    Write-Host "Docker Compose Manager installed successfully." -ForegroundColor $GREEN
    Write-Host "You can now use the 'dcm' command to manage your Docker Compose applications." -ForegroundColor $YELLOW
    Write-Host "Please restart your PowerShell session for the changes to take effect." -ForegroundColor $YELLOW
    return $true
}

# Function to uninstall
function Uninstall-Manager {
    Write-Host "Uninstalling Docker Compose Manager..." -ForegroundColor $CYAN
    
    # Remove from PowerShell profile
    if (Test-Path $PROFILE) {
        $profileContent = Get-Content $PROFILE -Raw
        $newContent = $profileContent -replace [regex]::Escape("`$env:Path += `";$INSTALL_DIR`""), ""
        Set-Content -Path $PROFILE -Value $newContent
    }
    
    # Remove installation directory
    if (Test-Path $INSTALL_DIR) {
        Remove-Item -Path $INSTALL_DIR -Recurse -Force
    }
    
    # Remove configuration directory
    if (Test-Path $CONFIG_DIR) {
        Remove-Item -Path $CONFIG_DIR -Recurse -Force
    }
    
    Write-Host "Docker Compose Manager uninstalled successfully." -ForegroundColor $GREEN
    Write-Host "Note: Docker applications in $DEFAULT_APPS_DIR were not removed." -ForegroundColor $YELLOW
}

# Function to show interactive menu
function Show-Menu {
    if (-not $INTERACTIVE) {
        # Non-interactive mode, install everything
        Install-Dependencies
        Install-Manager
        return
    }

    Write-Host "Docker Compose Manager Installation" -ForegroundColor $CYAN
    Write-Host "----------------------------------------"
    Write-Host "1. Install Docker Compose Manager only"
    Write-Host "2. Install missing dependencies"
    Write-Host "3. Install everything"
    Write-Host "4. Exit"
    Write-Host "----------------------------------------"
    $choice = Read-Host "Enter your choice [1-4]"

    switch ($choice) {
        "1" { Install-Manager }
        "2" { Install-Dependencies }
        "3" { 
            Install-Dependencies
            Install-Manager
        }
        "4" { 
            Write-Host "Exiting..."
            exit 0
        }
        default {
            Write-Host "Invalid choice" -ForegroundColor $RED
            Show-Menu
        }
    }
}

# Main script logic
param(
    [switch]$Help,
    [switch]$Uninstall,
    [switch]$Yes
)

if ($Help) {
    Show-Usage
    exit 0
}
elseif ($Uninstall) {
    Uninstall-Manager
    exit 0
}
elseif ($Yes) {
    # Non-interactive mode
    $INTERACTIVE = $false
    Install-Dependencies
    Install-Manager
    exit 0
}

# Show interactive menu
Show-Menu 