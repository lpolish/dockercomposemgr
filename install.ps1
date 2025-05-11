# Installation script for Docker Compose Manager (Windows)

# Colors for output
$Red = [System.ConsoleColor]::Red
$Green = [System.ConsoleColor]::Green
$Yellow = [System.ConsoleColor]::Yellow

# Installation paths
$DefaultInstallDir = "$env:ProgramFiles\DockerComposeManager"
$UserInstallDir = "$env:USERPROFILE\AppData\Local\DockerComposeManager"
$ScriptName = "dcm.ps1"
$RepoUrl = "https://raw.githubusercontent.com/lpolish/dockercomposemgr/main"
$TempDir = "$env:TEMP\dockercomposemgr_install"
$ConfigDir = "$env:USERPROFILE\.config\dockercomposemgr"
$DefaultAppsDir = "$env:USERPROFILE\dockerapps"

# Function to display usage
function Show-Usage {
    Write-Host "Docker Compose Manager Installer"
    Write-Host "Usage: .\install.ps1 [option]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  install     Install Docker Compose Manager"
    Write-Host "  uninstall   Uninstall Docker Compose Manager"
    Write-Host "  -h, --help  Show this help message"
}

# Function to check prerequisites
function Test-Prerequisites {
    # Check if running as administrator
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Host "Warning: Not running as administrator. Some features may be limited." -ForegroundColor $Yellow
    }

    # Check if Docker is installed
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        Write-Host "Error: Docker is not installed" -ForegroundColor $Red
        exit 1
    }

    # Check if Docker Compose is installed
    if (-not (Get-Command docker-compose -ErrorAction SilentlyContinue)) {
        Write-Host "Error: Docker Compose is not installed" -ForegroundColor $Red
        exit 1
    }

    # Check if PowerShell version is sufficient
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        Write-Host "Error: PowerShell 5.0 or higher is required" -ForegroundColor $Red
        exit 1
    }
}

# Function to download file
function Get-File {
    param (
        [string]$Url,
        [string]$Output
    )
    try {
        Invoke-WebRequest -Uri $Url -OutFile $Output -UseBasicParsing
        return $true
    }
    catch {
        Write-Host "Error: Failed to download $Url" -ForegroundColor $Red
        return $false
    }
}

# Function to create default configuration
function New-DefaultConfig {
    # Create config directory
    New-Item -ItemType Directory -Force -Path "$ConfigDir\logs" | Out-Null
    
    # Create default config if it doesn't exist
    $configFile = "$ConfigDir\config.json"
    if (-not (Test-Path $configFile)) {
        @{
            version = "1.0.0"
            apps_directory = $DefaultAppsDir.Replace("\", "/")
            log_level = "info"
            log_retention_days = 30
            default_timeout = 300
            notifications = @{
                enabled = $true
                on_start = $true
                on_stop = $true
                on_error = $true
            }
            backup = @{
                enabled = $true
                directory = "$DefaultAppsDir\backups".Replace("\", "/")
                retention_days = 7
                include_volumes = $true
            }
            update = @{
                check_interval_hours = 24
                auto_update = $false
            }
        } | ConvertTo-Json -Depth 10 | Set-Content $configFile
    }
    
    # Create apps registry if it doesn't exist
    $appsFile = "$ConfigDir\apps.json"
    if (-not (Test-Path $appsFile)) {
        @{
            version = "1.0.0"
            apps = @{}
            last_updated = $null
        } | ConvertTo-Json -Depth 10 | Set-Content $appsFile
    }
}

# Function to create apps directory structure
function New-AppsDirectory {
    # Create apps directory
    New-Item -ItemType Directory -Force -Path "$DefaultAppsDir\backups" | Out-Null
    
    # Create README if it doesn't exist
    $readmeFile = "$DefaultAppsDir\README.md"
    if (-not (Test-Path $readmeFile)) {
        @"
# Docker Apps Directory

This directory is where you'll store your Docker Compose applications. Each application should be in its own subdirectory.

## Directory Structure

\`\`\`
$DefaultAppsDir/
├── app1/                  # Application directory
│   ├── docker-compose.yml # Docker Compose configuration
│   ├── .env              # Environment variables (optional)
│   ├── data/             # Persistent data (if needed)
│   └── README.md         # Application documentation
├── app2/
│   └── ...
└── backups/              # Backup directory (managed by dcm)
\`\`\`

For more information, run: dcm --help
"@ | Set-Content $readmeFile
    }
}

# Function to install
function Install-DockerComposeManager {
    Write-Host "Installing Docker Compose Manager..." -ForegroundColor $Yellow
    
    # Create temporary directory
    Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Force -Path $TempDir | Out-Null
    
    # Download required files
    Write-Host "Downloading required files..."
    if (-not (Get-File -Url "$RepoUrl/manage.ps1" -Output "$TempDir\manage.ps1")) {
        Remove-Item -Path $TempDir -Recurse -Force
        exit 1
    }
    
    # Determine install location
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if ($isAdmin) {
        $InstallDir = $DefaultInstallDir
    } else {
        $InstallDir = $UserInstallDir
    }
    
    # Install the script
    Write-Host "Installing files to $InstallDir..."
    New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
    Copy-Item "$TempDir\manage.ps1" "$InstallDir\$ScriptName" -Force
    
    # Create configuration and apps directory structure
    New-DefaultConfig
    New-AppsDirectory
    
    # Create PowerShell profile if it doesn't exist
    $profilePath = $PROFILE
    if (-not (Test-Path $profilePath)) {
        New-Item -ItemType File -Force -Path $profilePath | Out-Null
    }
    
    # Add to PATH if not already there
    $pathEntry = "$InstallDir"
    $currentPath = [Environment]::GetEnvironmentVariable("PATH", "User")
    if ($currentPath -notlike "*$pathEntry*") {
        [Environment]::SetEnvironmentVariable("PATH", "$currentPath;$pathEntry", "User")
        $env:PATH = "$env:PATH;$pathEntry"
    }
    
    # Cleanup
    Remove-Item -Path $TempDir -Recurse -Force
    
    Write-Host "Installation complete!" -ForegroundColor $Green
    Write-Host "You can now use the 'dcm' command to manage your Docker Compose applications."
    Write-Host "Run 'dcm --help' to see available commands."
    
    # Check if user bin is in PATH
    if ($InstallDir -eq $UserInstallDir) {
        Write-Host "Warning: You may need to restart your PowerShell session for the changes to take effect." -ForegroundColor $Yellow
    }
}

# Function to uninstall
function Uninstall-DockerComposeManager {
    Write-Host "Uninstalling Docker Compose Manager..." -ForegroundColor $Yellow
    
    # Remove binary from both locations
    Remove-Item -Path "$DefaultInstallDir\$ScriptName" -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$UserInstallDir\$ScriptName" -Force -ErrorAction SilentlyContinue
    
    # Remove configuration
    Remove-Item -Path $ConfigDir -Recurse -Force -ErrorAction SilentlyContinue
    
    Write-Host "Uninstallation complete!" -ForegroundColor $Green
    Write-Host "Note: Your Docker applications in $DefaultAppsDir were not removed."
    Write-Host "To remove them, delete the directory manually: Remove-Item -Path $DefaultAppsDir -Recurse -Force"
}

# Main script
$ErrorActionPreference = "Stop"

# Check if script is being piped
if ($MyInvocation.Line -match "|") {
    # Piped mode - always install
    Test-Prerequisites
    Install-DockerComposeManager
} else {
    # Interactive mode
    switch ($args[0]) {
        "install" {
            Test-Prerequisites
            Install-DockerComposeManager
        }
        "uninstall" {
            Uninstall-DockerComposeManager
        }
        { $_ -in "-h", "--help" } {
            Show-Usage
        }
        "" {
            # Default to install if no argument is given
            Test-Prerequisites
            Install-DockerComposeManager
        }
        default {
            Write-Host "Error: Unknown option" -ForegroundColor $Red
            Show-Usage
            exit 1
        }
    }
} 