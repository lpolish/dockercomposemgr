# PowerShell installation script for Docker Compose Manager

# Colors for output
$Red = [System.ConsoleColor]::Red
$Green = [System.ConsoleColor]::Green
$Yellow = [System.ConsoleColor]::Yellow

# Installation paths
$DefaultInstallDir = "$env:ProgramFiles\DockerComposeManager"
$UserInstallDir = "$env:USERPROFILE\AppData\Local\DockerComposeManager"
$ScriptName = "dcm.ps1"
$RepoUrl = "https://github.com/lpolish/dockercomposemgr.git"
$TempDir = "$env:TEMP\dockercomposemgr_install"

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
    # Check if Docker is installed
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        Write-Host "Error: Docker is not installed" -ForegroundColor $Red
        exit 1
    }

    # Check if Docker Compose is installed
    if (-not (docker compose version -ErrorAction SilentlyContinue)) {
        Write-Host "Error: Docker Compose is not installed" -ForegroundColor $Red
        exit 1
    }

    # Check if Git is installed
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Host "Error: Git is not installed" -ForegroundColor $Red
        exit 1
    }
}

# Function to install
function Install-DockerComposeManager {
    Write-Host "Installing Docker Compose Manager..." -ForegroundColor $Yellow
    
    # Create temporary directory
    Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Path $TempDir -Force | Out-Null
    
    # Clone repository
    Write-Host "Cloning repository..."
    git clone $RepoUrl $TempDir
    
    # Determine install location
    if ([System.Security.Principal.WindowsIdentity]::GetCurrent().IsSystem) {
        $InstallDir = $DefaultInstallDir
    } else {
        $InstallDir = $UserInstallDir
    }
    
    # Create installation directory
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
    
    # Copy files
    Write-Host "Installing files to $InstallDir..."
    Copy-Item "$TempDir\manage.ps1" "$InstallDir\$ScriptName" -Force
    
    # Create configuration directory
    $ConfigDir = "$env:USERPROFILE\.config\dockercomposemgr"
    New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null
    Copy-Item "$TempDir\config" $ConfigDir -Recurse -Force
    Copy-Item "$TempDir\apps" $ConfigDir -Recurse -Force
    Copy-Item "$TempDir\logs" $ConfigDir -Recurse -Force
    
    # Add to PATH if not already present
    $UserPath = [Environment]::GetEnvironmentVariable("PATH", "User")
    if ($UserPath -notlike "*$InstallDir*") {
        [Environment]::SetEnvironmentVariable("PATH", "$UserPath;$InstallDir", "User")
        $env:PATH = "$env:PATH;$InstallDir"
    }
    
    # Cleanup
    Remove-Item -Path $TempDir -Recurse -Force
    
    Write-Host "Installation complete!" -ForegroundColor $Green
    Write-Host "You can now use the 'dcm' command to manage your Docker Compose applications."
    Write-Host "Run 'dcm --help' to see available commands."
}

# Function to uninstall
function Uninstall-DockerComposeManager {
    Write-Host "Uninstalling Docker Compose Manager..." -ForegroundColor $Yellow
    
    # Remove from both locations
    Remove-Item -Path "$DefaultInstallDir\$ScriptName" -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$UserInstallDir\$ScriptName" -Force -ErrorAction SilentlyContinue
    
    # Remove configuration
    Remove-Item -Path "$env:USERPROFILE\.config\dockercomposemgr" -Recurse -Force -ErrorAction SilentlyContinue
    
    # Remove from PATH
    $UserPath = [Environment]::GetEnvironmentVariable("PATH", "User")
    $NewPath = ($UserPath.Split(';') | Where-Object { $_ -ne $DefaultInstallDir -and $_ -ne $UserInstallDir }) -join ';'
    [Environment]::SetEnvironmentVariable("PATH", $NewPath, "User")
    
    Write-Host "Uninstallation complete!" -ForegroundColor $Green
}

# Main script logic
switch ($args[0]) {
    "install" {
        Test-Prerequisites
        Install-DockerComposeManager
    }
    "uninstall" {
        Uninstall-DockerComposeManager
    }
    "-h" { Show-Usage }
    "--help" { Show-Usage }
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