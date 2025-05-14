# Docker Compose Manager Uninstaller for Windows
# A command-line tool for uninstalling Docker Compose Manager

# Colors for output
$Red = [System.ConsoleColor]::Red
$Green = [System.ConsoleColor]::Green
$Yellow = [System.ConsoleColor]::Yellow
$Cyan = [System.ConsoleColor]::Cyan

# Installation paths
$InstallDir = "$env:USERPROFILE\AppData\Local\DockerComposeManager"
$ConfigDir = "$env:USERPROFILE\.config\dockercomposemgr"
$DefaultAppsDir = "$env:USERPROFILE\dockerapps"

# Function to display usage
function Show-Usage {
    Write-Host "Docker Compose Manager Uninstaller"
    Write-Host "Usage: Invoke-Expression (New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/lpolish/dockercomposemgr/main/uninstall.ps1')"
    Write-Host ""
    Write-Host "This script will remove Docker Compose Manager from your system."
    Write-Host "Your Docker applications in $DefaultAppsDir will not be affected."
}

# Function to uninstall
function Uninstall-DockerComposeManager {
    Write-Host "Uninstalling Docker Compose Manager..." -ForegroundColor $Cyan
    
    # Remove management script
    if (Test-Path "$InstallDir\dcm.ps1") {
        Remove-Item -Path "$InstallDir\dcm.ps1" -Force
        Write-Host "Removed management script" -ForegroundColor $Green
    }
    
    # Remove configuration directory
    if (Test-Path $ConfigDir) {
        Remove-Item -Path $ConfigDir -Recurse -Force
        Write-Host "Removed configuration directory" -ForegroundColor $Green
    }
    
    Write-Host "Docker Compose Manager uninstalled successfully" -ForegroundColor $Green
    Write-Host "Note: Docker applications in $DefaultAppsDir were not removed" -ForegroundColor $Yellow
}

# Main script logic
if ($args -contains "--help" -or $args -contains "-h") {
    Show-Usage
    exit 0
}

# Confirm uninstallation
Write-Host "This will remove Docker Compose Manager from your system." -ForegroundColor $Yellow
Write-Host "Your Docker applications in $DefaultAppsDir will not be affected." -ForegroundColor $Yellow
$confirmation = Read-Host "Do you want to continue? [y/N]"
if ($confirmation -ne 'y') {
    Write-Host "Uninstallation cancelled" -ForegroundColor $Red
    exit 1
}

Uninstall-DockerComposeManager 