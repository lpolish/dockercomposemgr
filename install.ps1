# Docker Compose Manager Installer for Windows
# A command-line tool for managing Docker Compose applications

# Colors for output
$Red = [System.ConsoleColor]::Red
$Green = [System.ConsoleColor]::Green
$Yellow = [System.ConsoleColor]::Yellow
$Cyan = [System.ConsoleColor]::Cyan

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
    Write-Host "  --update       Update Docker Compose Manager to the latest version"
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
        Write-Host "Error downloading file: $_" -ForegroundColor $Red
        return $false
    }
}

# Function to check requirements
function Test-Requirements {
    $missing = 0
    Write-Host "Checking requirements..." -ForegroundColor $Cyan

    # Check Docker Desktop
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        Write-Host "Docker Desktop is not installed." -ForegroundColor $Red
        $missing = 1
    }
    elseif (-not (docker compose version 2>$null)) {
        Write-Host "Docker Compose is not available." -ForegroundColor $Red
        $missing = 1
    }

    # Check jq
    if (-not (Get-Command jq -ErrorAction SilentlyContinue)) {
        Write-Host "jq is not installed." -ForegroundColor $Red
        $missing = 1
    }

    if ($missing -eq 1) {
        return $false
    }
    Write-Host "All requirements satisfied." -ForegroundColor $Green
    return $true
}

# Function to install Docker Desktop
function Install-DockerDesktop {
    Write-Host "Installing Docker Desktop..." -ForegroundColor $Cyan
    
    # Download Docker Desktop installer
    $installerPath = "$env:TEMP\DockerDesktopInstaller.exe"
    if (-not (Download-File "https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe" $installerPath)) {
        Write-Host "Failed to download Docker Desktop installer." -ForegroundColor $Red
        return $false
    }

    # Run the installer
    Write-Host "Running Docker Desktop installer..." -ForegroundColor $Cyan
    Start-Process -FilePath $installerPath -ArgumentList "install --quiet" -Wait

    # Clean up
    Remove-Item $installerPath -Force

    Write-Host "Docker Desktop installed successfully." -ForegroundColor $Green
    Write-Host "Please restart your computer to complete the installation." -ForegroundColor $Yellow
    return $true
}

# Function to install jq
function Install-Jq {
    Write-Host "Installing jq..." -ForegroundColor $Cyan
    
    # Download jq
    $jqPath = "$env:TEMP\jq.exe"
    if (-not (Download-File "https://github.com/stedolan/jq/releases/download/jq-1.6/jq-win64.exe" $jqPath)) {
        Write-Host "Failed to download jq." -ForegroundColor $Red
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

    Write-Host "jq installed successfully." -ForegroundColor $Green
    return $true
}

# Function to create directory with proper permissions
function Create-Directory {
    param (
        [string]$Path,
        [string]$Permissions = "FullControl"
    )
    
    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Force -Path $Path | Out-Null
    }
    
    # Set permissions
    $acl = Get-Acl $Path
    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($env:USERNAME, $Permissions, "ContainerInherit,ObjectInherit", "None", "Allow")
    $acl.SetAccessRule($rule)
    Set-Acl $Path $acl
}

# Function to create file with proper permissions
function Create-File {
    param (
        [string]$Path,
        [string]$Content,
        [string]$Permissions = "FullControl"
    )
    
    Set-Content -Path $Path -Value $Content -Force
    
    # Set permissions
    $acl = Get-Acl $Path
    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($env:USERNAME, $Permissions, "Allow")
    $acl.SetAccessRule($rule)
    Set-Acl $Path $acl
}

# Function to create default configuration
function New-DefaultConfig {
    Write-Host "Creating default configuration..." -ForegroundColor $Cyan
    
    # Create config directory with proper permissions
    Create-Directory $CONFIG_DIR
    
    # Create config.json if it doesn't exist
    $configPath = "$CONFIG_DIR\config.json"
    if (-not (Test-Path $configPath)) {
        $config = @{
            apps_directory = $DEFAULT_APPS_DIR
            log_level = "info"
            log_retention_days = 7
            backup = @{
                include_volumes = $true
                retention_days = 30
            }
        } | ConvertTo-Json
        Create-File $configPath $config
    }
    
    # Create apps.json if it doesn't exist
    $appsPath = "$CONFIG_DIR\apps.json"
    if (-not (Test-Path $appsPath)) {
        $apps = @{
            apps = @{}
        } | ConvertTo-Json
        Create-File $appsPath $apps
    }
    
    Write-Host "Default configuration created successfully" -ForegroundColor $Green
}

# Function to create apps directory structure
function New-AppsDirectory {
    Write-Host "Creating apps directory structure..." -ForegroundColor $Cyan
    
    # Create apps directory with proper permissions
    Create-Directory $DEFAULT_APPS_DIR
    Create-Directory "$DEFAULT_APPS_DIR\backups"
    
    # Create README if it doesn't exist
    $readmePath = "$DEFAULT_APPS_DIR\README.md"
    if (-not (Test-Path $readmePath)) {
        $readme = @"
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
"@
        Create-File $readmePath $readme
    }
    
    Write-Host "Apps directory structure created successfully" -ForegroundColor $Green
}

# Function to install dependencies
function Install-Dependencies {
    if (-not (Test-Administrator)) {
        Write-Host "This operation requires administrator privileges." -ForegroundColor $Red
        Write-Host "Please run the script as administrator." -ForegroundColor $Yellow
        return $false
    }

    Write-Host "Installing dependencies..." -ForegroundColor $Cyan
    
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

# Function to install Docker Compose Manager
function Install-Manager {
    Write-Host "Installing Docker Compose Manager..." -ForegroundColor $Cyan
    
    # Create installation directory with proper permissions
    Create-Directory $INSTALL_DIR
    
    # Download management script
    Write-Host "Downloading management script..." -ForegroundColor $Cyan
    try {
        Invoke-WebRequest -Uri "https://raw.githubusercontent.com/lpolish/dockercomposemgr/main/manage.ps1" -OutFile "$INSTALL_DIR\dcm.ps1" -UseBasicParsing
    }
    catch {
        Write-Host "Failed to download management script" -ForegroundColor $Red
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
    
    Write-Host "Docker Compose Manager installed successfully" -ForegroundColor $Green
    Write-Host "You can now use the 'dcm' command to manage your Docker Compose applications" -ForegroundColor $Yellow
    Write-Host "Please restart your PowerShell session for the changes to take effect" -ForegroundColor $Yellow
    return $true
}

# Function to uninstall Docker Compose Manager
function Uninstall-DockerComposeManager {
    Write-Host "Uninstalling Docker Compose Manager..." -ForegroundColor $Cyan
    
    # Check if running as administrator
    if (-not (Test-Administrator)) {
        Write-Host "This operation requires administrator privileges." -ForegroundColor $Red
        Write-Host "Please run the script as administrator." -ForegroundColor $Yellow
        return $false
    }

    # Remove management script
    $installPath = "$env:ProgramFiles\DockerComposeManager"
    if (Test-Path $installPath) {
        Remove-Item -Path $installPath -Recurse -Force
    }

    # Remove configuration directory
    $configDir = "$env:USERPROFILE\.config\dockercomposemgr"
    if (Test-Path $configDir) {
        Remove-Item -Path $configDir -Recurse -Force
    }

    Write-Host "Docker Compose Manager uninstalled successfully" -ForegroundColor $Green
    Write-Host "Note: Docker applications in $DEFAULT_APPS_DIR were not removed" -ForegroundColor $Yellow
}

# Function to show interactive menu
function Show-Menu {
    if (-not $INTERACTIVE) {
        # Non-interactive mode, install everything
        Install-Dependencies
        Install-Manager
        return
    }

    $maxRetries = 3
    $retryCount = 0

    while ($retryCount -lt $maxRetries) {
        Write-Host "Docker Compose Manager Installation" -ForegroundColor $Cyan
        Write-Host "----------------------------------------"
        Write-Host "1. Install Docker Compose Manager only"
        Write-Host "2. Install missing dependencies"
        Write-Host "3. Install everything"
        Write-Host "4. Update Docker Compose Manager"
        Write-Host "5. Uninstall Docker Compose Manager"
        Write-Host "6. Exit"
        Write-Host "----------------------------------------"
        $choice = Read-Host "Enter your choice [1-6]"

        switch ($choice) {
            "1" { 
                Install-Manager
                return
            }
            "2" { 
                Install-Dependencies
                return
            }
            "3" { 
                Install-Dependencies
                Install-Manager
                return
            }
            "4" {
                Install-Manager
                return
            }
            "5" {
                Uninstall-DockerComposeManager
                return
            }
            "6" { 
                Write-Host "Exiting..."
                exit 0
            }
            default {
                $retryCount++
                if ($retryCount -lt $maxRetries) {
                    Write-Host "Invalid choice. Please try again." -ForegroundColor $Red
                    Write-Host "Attempts remaining: $($maxRetries - $retryCount)" -ForegroundColor $Yellow
                }
                else {
                    Write-Host "Too many invalid choices. Exiting..." -ForegroundColor $Red
                    exit 1
                }
            }
        }
    }
}

# Main script logic
param(
    [switch]$Help,
    [switch]$Uninstall,
    [switch]$Yes,
    [switch]$Update
)

if ($Help) {
    Show-Usage
    exit 0
}
elseif ($Uninstall) {
    Uninstall-DockerComposeManager
    exit 0
}
elseif ($Update) {
    Install-Manager
    exit 0
}
elseif ($Yes) {
    # Non-interactive mode
    $INTERACTIVE = $false
    Install-Dependencies
    Install-Manager
    exit 0
}

# Show interactive menu by default
Show-Menu 