# Docker Compose Manager Installer for Windows
# A command-line tool for managing Docker Compose applications

# Colors for output
$Red = [System.ConsoleColor]::Red
$Green = [System.ConsoleColor]::Green
$Yellow = [System.ConsoleColor]::Yellow
$Blue = [System.ConsoleColor]::Blue

# Installation paths
$InstallDir = "$env:ProgramFiles\DockerComposeManager"
$ConfigDir = "$env:USERPROFILE\.config\dockercomposemgr"
$DefaultAppsDir = "$env:USERPROFILE\dockerapps"

# Function to display usage
function Show-Usage {
    Write-Host "Docker Compose Manager Installer"
    Write-Host "Usage: $($MyInvocation.MyCommand.Name) [options]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -h, --help     Show this help message"
    Write-Host "  -u, --uninstall Remove Docker Compose Manager"
}

# Function to check if running as administrator
function Test-Administrator {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Function to install dependencies
function Install-Dependencies {
    Write-Host "Installing dependencies..." -ForegroundColor $Blue
    
    # Check if winget is available
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Host "Error: winget is not installed. Please install the App Installer from the Microsoft Store." -ForegroundColor $Red
        exit 1
    }
    
    # Install jq if not present
    if (-not (Get-Command jq -ErrorAction SilentlyContinue)) {
        Write-Host "Installing jq..." -ForegroundColor $Blue
        winget install -e --id stedolan.jq
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    }
    
    # Check if Docker Desktop is installed
    if (-not (Test-Path "C:\Program Files\Docker\Docker\Docker Desktop.exe")) {
        Write-Host "Docker Desktop is not installed. Please install it from:" -ForegroundColor $Yellow
        Write-Host "https://www.docker.com/products/docker-desktop"
        Write-Host "After installation, please restart your computer and run this installer again."
        exit 1
    }
    
    # Check if Docker service is running
    $dockerService = Get-Service -Name "com.docker.service" -ErrorAction SilentlyContinue
    if (-not $dockerService -or $dockerService.Status -ne "Running") {
        Write-Host "Docker service is not running. Please start Docker Desktop and try again." -ForegroundColor $Red
        exit 1
    }
    
    Write-Host "Dependencies installed successfully" -ForegroundColor $Green
}

# Function to create default configuration
function Create-DefaultConfig {
    Write-Host "Creating default configuration..." -ForegroundColor $Blue
    
    # Create config directory
    New-Item -ItemType Directory -Force -Path $ConfigDir | Out-Null
    
    # Create config.json if it doesn't exist
    if (-not (Test-Path "$ConfigDir\config.json")) {
        @{
            apps_directory = $DefaultAppsDir
            log_level = "info"
            log_retention_days = 7
            backup = @{
                include_volumes = $true
                retention_days = 30
            }
        } | ConvertTo-Json | Set-Content "$ConfigDir\config.json"
    }
    
    # Create apps.json if it doesn't exist
    if (-not (Test-Path "$ConfigDir\apps.json")) {
        @{
            apps = @{}
        } | ConvertTo-Json | Set-Content "$ConfigDir\apps.json"
    }
    
    Write-Host "Default configuration created successfully" -ForegroundColor $Green
}

# Function to create apps directory structure
function Create-AppsDirectory {
    Write-Host "Creating apps directory structure..." -ForegroundColor $Blue
    
    # Create apps directory
    New-Item -ItemType Directory -Force -Path "$DefaultAppsDir\backups" | Out-Null
    
    # Create README if it doesn't exist
    if (-not (Test-Path "$DefaultAppsDir\README.md")) {
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
dcm add app_name C:\path\to\docker-compose.yml

# Remove an application
dcm remove app_name
\`\`\`
"@ | Set-Content "$DefaultAppsDir\README.md"
    }
    
    Write-Host "Apps directory structure created successfully" -ForegroundColor $Green
}

# Function to install Docker Compose Manager
function Install-DockerComposeManager {
    Write-Host "Installing Docker Compose Manager..." -ForegroundColor $Blue
    
    # Check if running as administrator
    if (-not (Test-Administrator)) {
        Write-Host "Error: This script needs to be run as administrator" -ForegroundColor $Red
        Write-Host "Please run PowerShell as administrator and try again"
        exit 1
    }
    
    # Install dependencies
    Install-Dependencies
    
    # Create installation directory
    New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
    
    # Download management script
    Write-Host "Downloading management script..." -ForegroundColor $Blue
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/lpolish/dockercomposemgr/main/manage.ps1" -OutFile "$InstallDir\dcm.ps1"
    
    # Create PowerShell profile if it doesn't exist
    if (-not (Test-Path $PROFILE)) {
        New-Item -ItemType File -Force -Path $PROFILE | Out-Null
    }
    
    # Add alias to PowerShell profile
    $aliasLine = "Set-Alias -Name dcm -Value '$InstallDir\dcm.ps1'"
    if (-not (Select-String -Path $PROFILE -Pattern $aliasLine -Quiet)) {
        Add-Content -Path $PROFILE -Value "`n$aliasLine"
    }
    
    # Create default configuration
    Create-DefaultConfig
    
    # Create apps directory structure
    Create-AppsDirectory
    
    Write-Host "Docker Compose Manager installed successfully" -ForegroundColor $Green
    Write-Host "Please restart your PowerShell session to use the 'dcm' command" -ForegroundColor $Yellow
}

# Function to uninstall Docker Compose Manager
function Uninstall-DockerComposeManager {
    Write-Host "Uninstalling Docker Compose Manager..." -ForegroundColor $Blue
    
    # Check if running as administrator
    if (-not (Test-Administrator)) {
        Write-Host "Error: This script needs to be run as administrator" -ForegroundColor $Red
        Write-Host "Please run PowerShell as administrator and try again"
        exit 1
    }
    
    # Remove installation directory
    Remove-Item -Path $InstallDir -Recurse -Force -ErrorAction SilentlyContinue
    
    # Remove alias from PowerShell profile
    if (Test-Path $PROFILE) {
        $profileContent = Get-Content $PROFILE
        $newContent = $profileContent | Where-Object { $_ -notmatch "Set-Alias -Name dcm -Value" }
        Set-Content -Path $PROFILE -Value $newContent
    }
    
    # Remove configuration directory
    Remove-Item -Path $ConfigDir -Recurse -Force -ErrorAction SilentlyContinue
    
    Write-Host "Docker Compose Manager uninstalled successfully" -ForegroundColor $Green
    Write-Host "Note: Docker applications in $DefaultAppsDir were not removed" -ForegroundColor $Yellow
}

# Main script logic
switch ($args[0]) {
    "-h" { Show-Usage }
    "--help" { Show-Usage }
    "-u" { Uninstall-DockerComposeManager }
    "--uninstall" { Uninstall-DockerComposeManager }
    default { Install-DockerComposeManager }
} 