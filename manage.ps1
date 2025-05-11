# Docker Compose Manager for Windows
# A command-line tool for managing Docker Compose applications

# Configuration
$ConfigDir = "$env:USERPROFILE\.config\dockercomposemgr\config"
$AppsDir = "$env:USERPROFILE\.config\dockercomposemgr\apps"
$LogDir = "$env:USERPROFILE\.config\dockercomposemgr\logs"

# Colors for output
$Red = [System.ConsoleColor]::Red
$Green = [System.ConsoleColor]::Green
$Yellow = [System.ConsoleColor]::Yellow
$Blue = [System.ConsoleColor]::Blue

# Ensure required directories exist
New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null
New-Item -ItemType Directory -Path $AppsDir -Force | Out-Null
New-Item -ItemType Directory -Path $LogDir -Force | Out-Null

# Function to display usage
function Show-Usage {
    Write-Host "Docker Compose Manager"
    Write-Host "Usage: dcm [command] [options]"
    Write-Host ""
    Write-Host "Commands:"
    Write-Host "  list                    List all managed applications"
    Write-Host "  status [app]           Show status of all or specific application"
    Write-Host "  info [app]             Show detailed information about application"
    Write-Host "  start [app]            Start all or specific application"
    Write-Host "  stop [app]             Stop all or specific application"
    Write-Host "  restart [app]          Restart all or specific application"
    Write-Host "  logs [app]             Show logs for all or specific application"
    Write-Host "  add <name> <path>      Add new application to manage"
    Write-Host "  remove <app>           Remove application from management"
    Write-Host "  update [app]           Update all or specific application"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -h, --help             Show this help message"
}

# Function to check if Docker is installed
function Test-Docker {
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        Write-Host "Error: Docker is not installed" -ForegroundColor $Red
        exit 1
    }
    if (-not (docker compose version -ErrorAction SilentlyContinue)) {
        Write-Host "Error: Docker Compose is not installed" -ForegroundColor $Red
        exit 1
    }
}

# Function to list all managed applications
function Get-Applications {
    $apps = Get-ChildItem -Path $AppsDir -Directory
    if (-not $apps) {
        Write-Host "No applications are currently being managed."
        return
    }
    
    Write-Host "Managed Applications:"
    Write-Host "-------------------"
    foreach ($app in $apps) {
        Write-Host "- $($app.Name)"
    }
}

# Function to get application status
function Get-ApplicationStatus {
    param (
        [string]$AppName
    )
    
    if (-not $AppName) {
        $apps = Get-ChildItem -Path $AppsDir -Directory
        foreach ($app in $apps) {
            Write-Host "Checking $($app.Name)..."
            docker compose -f "$AppsDir\$($app.Name)\docker-compose.yml" ps
        }
    } else {
        if (Test-Path "$AppsDir\$AppName") {
            docker compose -f "$AppsDir\$AppName\docker-compose.yml" ps
        } else {
            Write-Host "Error: Application '$AppName' not found" -ForegroundColor $Red
            exit 1
        }
    }
}

# Function to get detailed application information
function Get-ApplicationInfo {
    param (
        [string]$AppName
    )
    
    if (-not $AppName) {
        Write-Host "Error: Application name required" -ForegroundColor $Red
        Write-Host "Usage: dcm info <app>"
        exit 1
    }

    if (-not (Test-Path "$AppsDir\$AppName")) {
        Write-Host "Error: Application '$AppName' not found" -ForegroundColor $Red
        exit 1
    }

    Write-Host "=== Detailed Information for $AppName ===" -ForegroundColor $Blue
    Write-Host ""

    # Get container status
    Write-Host "Container Status:" -ForegroundColor $Yellow
    docker compose -f "$AppsDir\$AppName\docker-compose.yml" ps
    Write-Host ""

    # Get container resource usage
    Write-Host "Resource Usage:" -ForegroundColor $Yellow
    Write-Host "CPU and Memory usage for each container:"
    $containers = docker compose -f "$AppsDir\$AppName\docker-compose.yml" ps -q
    foreach ($container in $containers) {
        $containerName = docker inspect --format '{{.Name}}' $container
        Write-Host "Container: $containerName" -ForegroundColor $Green
        docker stats --no-stream $container
    }
    Write-Host ""

    # Get network information
    Write-Host "Network Information:" -ForegroundColor $Yellow
    docker compose -f "$AppsDir\$AppName\docker-compose.yml" network ls
    Write-Host ""

    # Get volume information
    Write-Host "Volume Information:" -ForegroundColor $Yellow
    docker compose -f "$AppsDir\$AppName\docker-compose.yml" volume ls
    Write-Host ""

    # Get environment variables
    Write-Host "Environment Configuration:" -ForegroundColor $Yellow
    docker compose -f "$AppsDir\$AppName\docker-compose.yml" config
    Write-Host ""

    # Get recent logs
    Write-Host "Recent Logs (last 5 lines):" -ForegroundColor $Yellow
    docker compose -f "$AppsDir\$AppName\docker-compose.yml" logs --tail=5
    Write-Host ""

    # Get health status
    Write-Host "Health Status:" -ForegroundColor $Yellow
    foreach ($container in $containers) {
        $health = docker inspect --format='{{.State.Health.Status}}' $container 2>$null
        if ($health) {
            $containerName = docker inspect --format '{{.Name}}' $container
            Write-Host "Container: $containerName" -ForegroundColor $Green
            Write-Host "Health: $health"
        }
    }
}

# Main script logic
Test-Docker

switch ($args[0]) {
    "list" {
        Get-Applications
    }
    "status" {
        Get-ApplicationStatus $args[1]
    }
    "info" {
        Get-ApplicationInfo $args[1]
    }
    "start" {
        if (-not $args[1]) {
            $apps = Get-ChildItem -Path $AppsDir -Directory
            foreach ($app in $apps) {
                Write-Host "Starting $($app.Name)..."
                docker compose -f "$AppsDir\$($app.Name)\docker-compose.yml" up -d
            }
        } else {
            if (Test-Path "$AppsDir\$($args[1])") {
                docker compose -f "$AppsDir\$($args[1])\docker-compose.yml" up -d
            } else {
                Write-Host "Error: Application '$($args[1])' not found" -ForegroundColor $Red
                exit 1
            }
        }
    }
    "stop" {
        if (-not $args[1]) {
            $apps = Get-ChildItem -Path $AppsDir -Directory
            foreach ($app in $apps) {
                Write-Host "Stopping $($app.Name)..."
                docker compose -f "$AppsDir\$($app.Name)\docker-compose.yml" down
            }
        } else {
            if (Test-Path "$AppsDir\$($args[1])") {
                docker compose -f "$AppsDir\$($args[1])\docker-compose.yml" down
            } else {
                Write-Host "Error: Application '$($args[1])' not found" -ForegroundColor $Red
                exit 1
            }
        }
    }
    "restart" {
        if (-not $args[1]) {
            $apps = Get-ChildItem -Path $AppsDir -Directory
            foreach ($app in $apps) {
                Write-Host "Restarting $($app.Name)..."
                docker compose -f "$AppsDir\$($app.Name)\docker-compose.yml" restart
            }
        } else {
            if (Test-Path "$AppsDir\$($args[1])") {
                docker compose -f "$AppsDir\$($args[1])\docker-compose.yml" restart
            } else {
                Write-Host "Error: Application '$($args[1])' not found" -ForegroundColor $Red
                exit 1
            }
        }
    }
    "logs" {
        if (-not $args[1]) {
            $apps = Get-ChildItem -Path $AppsDir -Directory
            foreach ($app in $apps) {
                Write-Host "Logs for $($app.Name):"
                docker compose -f "$AppsDir\$($app.Name)\docker-compose.yml" logs
            }
        } else {
            if (Test-Path "$AppsDir\$($args[1])") {
                docker compose -f "$AppsDir\$($args[1])\docker-compose.yml" logs
            } else {
                Write-Host "Error: Application '$($args[1])' not found" -ForegroundColor $Red
                exit 1
            }
        }
    }
    "add" {
        if (-not $args[1] -or -not $args[2]) {
            Write-Host "Error: Application name and path required" -ForegroundColor $Red
            Write-Host "Usage: dcm add <name> <path>"
            exit 1
        }
        if (-not (Test-Path "$($args[2])\docker-compose.yml")) {
            Write-Host "Error: docker-compose.yml not found in specified path" -ForegroundColor $Red
            exit 1
        }
        New-Item -ItemType Directory -Path "$AppsDir\$($args[1])" -Force | Out-Null
        Copy-Item "$($args[2])\docker-compose.yml" "$AppsDir\$($args[1])\"
        Write-Host "Application '$($args[1])' added successfully" -ForegroundColor $Green
    }
    "remove" {
        if (-not $args[1]) {
            Write-Host "Error: Application name required" -ForegroundColor $Red
            Write-Host "Usage: dcm remove <app>"
            exit 1
        }
        if (Test-Path "$AppsDir\$($args[1])") {
            Remove-Item -Path "$AppsDir\$($args[1])" -Recurse -Force
            Write-Host "Application '$($args[1])' removed successfully" -ForegroundColor $Green
        } else {
            Write-Host "Error: Application '$($args[1])' not found" -ForegroundColor $Red
            exit 1
        }
    }
    "update" {
        if (-not $args[1]) {
            $apps = Get-ChildItem -Path $AppsDir -Directory
            foreach ($app in $apps) {
                Write-Host "Updating $($app.Name)..."
                docker compose -f "$AppsDir\$($app.Name)\docker-compose.yml" pull
                docker compose -f "$AppsDir\$($app.Name)\docker-compose.yml" up -d
            }
        } else {
            if (Test-Path "$AppsDir\$($args[1])") {
                docker compose -f "$AppsDir\$($args[1])\docker-compose.yml" pull
                docker compose -f "$AppsDir\$($args[1])\docker-compose.yml" up -d
            } else {
                Write-Host "Error: Application '$($args[1])' not found" -ForegroundColor $Red
                exit 1
            }
        }
    }
    "-h" { Show-Usage }
    "--help" { Show-Usage }
    default {
        Write-Host "Error: Unknown command" -ForegroundColor $Red
        Show-Usage
        exit 1
    }
} 