# Docker Compose Manager for Windows
# A command-line tool for managing Docker Compose applications

# Load configuration
$ConfigDir = "$env:USERPROFILE\.config\dockercomposemgr"
$ConfigFile = "$ConfigDir\config.json"
$AppsFile = "$ConfigDir\apps.json"
$DefaultAppsDir = "$env:USERPROFILE\dockerapps"

# Colors for output
$Red = [System.ConsoleColor]::Red
$Green = [System.ConsoleColor]::Green
$Yellow = [System.ConsoleColor]::Yellow
$Blue = [System.ConsoleColor]::Blue

# Function to load configuration
function Load-Config {
    if (-not (Test-Path $ConfigFile)) {
        Write-Host "Error: Configuration file not found" -ForegroundColor $Red
        Write-Host "Please run the installer first:"
        Write-Host "Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/lpolish/dockercomposemgr/main/install.ps1'))"
        exit 1
    }
    
    # Load apps directory from config
    $config = Get-Content $ConfigFile | ConvertFrom-Json
    $script:AppsDir = $config.apps_directory
    if (-not $script:AppsDir) {
        $script:AppsDir = $DefaultAppsDir
    }
    
    # Create apps directory if it doesn't exist
    New-Item -ItemType Directory -Force -Path "$script:AppsDir\backups" | Out-Null
}

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
    Write-Host "  backup [app]           Backup application data and volumes"
    Write-Host "  restore <app> <backup> Restore application from backup"
    Write-Host "  create                 Create a new application from template"
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
    if (-not (Get-Command docker-compose -ErrorAction SilentlyContinue)) {
        Write-Host "Error: Docker Compose is not installed" -ForegroundColor $Red
        exit 1
    }
}

# Function to check if git is installed
function Check-Git {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Host "Git is not installed. Would you like to install it? (y/n)" -ForegroundColor Yellow
        $installGit = Read-Host
        if ($installGit -eq 'y' -or $installGit -eq 'Y') {
            if (Get-Command winget -ErrorAction SilentlyContinue) {
                winget install --id Git.Git -e --source winget
            } elseif (Get-Command choco -ErrorAction SilentlyContinue) {
                choco install git -y
            } else {
                Write-Host "Error: Could not install git. Please install it manually from https://git-scm.com/download/win" -ForegroundColor Red
                exit 1
            }
        } else {
            Write-Host "Error: Git is required for creating new applications" -ForegroundColor Red
            exit 1
        }
    }
}

# Function to get available templates
function Get-AvailableTemplates {
    $registryUrl = "https://raw.githubusercontent.com/lpolish/dockercomposemgr/main/templates/registry.json"
    try {
        $response = Invoke-WebRequest -Uri $registryUrl -UseBasicParsing
        $registry = $response.Content | ConvertFrom-Json
        return $registry.templates
    } catch {
        Write-Host "Error: Could not fetch template registry" -ForegroundColor $Red
        Write-Host "Falling back to local templates..."
        return $null
    }
}

# Function to download template
function Download-Template {
    param (
        [string]$TemplateId,
        [string]$Destination
    )
    
    $templates = Get-AvailableTemplates
    if (-not $templates -or -not $templates.$TemplateId) {
        Write-Host "Error: Template '$TemplateId' not found in registry" -ForegroundColor $Red
        exit 1
    }
    
    $template = $templates.$TemplateId
    $templateUrl = $template.url
    
    try {
        # Create template directory
        New-Item -ItemType Directory -Force -Path $Destination | Out-Null
        
        # Download each file
        foreach ($file in $template.files) {
            $fileUrl = "$templateUrl/$file"
            $filePath = Join-Path $Destination $file
            Write-Host "Downloading $file..."
            Invoke-WebRequest -Uri $fileUrl -OutFile $filePath -UseBasicParsing
        }
        
        return $true
    } catch {
        Write-Host "Error: Failed to download template files" -ForegroundColor $Red
        Write-Host $_.Exception.Message
        return $false
    }
}

# Function to create a new application
function Create-App {
    Check-Git
    
    Write-Host "=== Create New Application ===" -ForegroundColor Blue
    
    # Get available templates
    $templates = Get-AvailableTemplates
    if (-not $templates) {
        Write-Host "Error: Could not fetch templates. Please check your internet connection." -ForegroundColor $Red
        exit 1
    }
    
    # Display available templates
    Write-Host "Available templates:"
    $i = 1
    $templateList = @{}
    foreach ($template in $templates.PSObject.Properties) {
        $templateList[$i] = $template.Name
        Write-Host "$i. $($template.Value.name)"
        Write-Host "   $($template.Value.description)"
        Write-Host "   Tags: $($template.Value.tags -join ', ')"
        Write-Host ""
        $i++
    }
    
    $templateChoice = Read-Host "Select template (1-$($i-1))"
    if (-not $templateList.ContainsKey([int]$templateChoice)) {
        Write-Host "Invalid template choice" -ForegroundColor $Red
        exit 1
    }
    
    $templateId = $templateList[[int]$templateChoice]
    $template = $templates.$templateId
    
    $appName = Read-Host "Enter application name"
    $appDescription = Read-Host "Enter application description"
    
    # Create application directory
    $appDir = Join-Path $script:AppsDir $appName
    if (Test-Path $appDir) {
        Write-Host "Error: Application directory already exists" -ForegroundColor $Red
        exit 1
    }
    
    # Download template
    Write-Host "Downloading template..."
    if (-not (Download-Template -TemplateId $templateId -Destination $appDir)) {
        Write-Host "Error: Failed to download template" -ForegroundColor $Red
        exit 1
    }
    
    # Initialize git repository
    Set-Location $appDir
    git init
    
    # Update package.json or requirements.txt with app name and description
    if ($templateId -eq "nodejs" -or $templateId -eq "nextjs") {
        $packageJson = Get-Content "package.json" -Raw | ConvertFrom-Json
        $packageJson.name = $appName
        $packageJson.description = $appDescription
        $packageJson | ConvertTo-Json -Depth 10 | Set-Content "package.json"
    } elseif ($templateId -eq "fastapi") {
        Set-Content -Path "README.md" -Value "# $appName`n$appDescription"
    }
    
    # Create .gitignore
    @"
node_modules/
.next/
__pycache__/
*.pyc
.env
.DS_Store
dist/
build/
*.log
"@ | Set-Content ".gitignore"
    
    # Initial commit
    git add .
    git commit -m "Initial commit: $appName"
    
    Write-Host "Application '$appName' created successfully!" -ForegroundColor Green
    Write-Host "Directory: $appDir"
    Write-Host "To start the application, run: dcm start $appName"
}

# Function to list all managed applications
function Get-Applications {
    $apps = Get-ChildItem -Path $script:AppsDir -Directory | Where-Object { Test-Path "$($_.FullName)\docker-compose.yml" }
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
        $apps = Get-ChildItem -Path $script:AppsDir -Directory | Where-Object { Test-Path "$($_.FullName)\docker-compose.yml" }
        foreach ($app in $apps) {
            Write-Host "Checking $($app.Name)..."
            docker compose -f "$($app.FullName)\docker-compose.yml" ps
        }
    } else {
        if (Test-Path "$script:AppsDir\$AppName\docker-compose.yml") {
            docker compose -f "$script:AppsDir\$AppName\docker-compose.yml" ps
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

    if (-not (Test-Path "$script:AppsDir\$AppName\docker-compose.yml")) {
        Write-Host "Error: Application '$AppName' not found" -ForegroundColor $Red
        exit 1
    }

    Write-Host "=== Detailed Information for $AppName ===" -ForegroundColor $Blue
    Write-Host ""

    # Get container status
    Write-Host "Container Status:" -ForegroundColor $Yellow
    docker compose -f "$script:AppsDir\$AppName\docker-compose.yml" ps
    Write-Host ""

    # Get container resource usage
    Write-Host "Resource Usage:" -ForegroundColor $Yellow
    Write-Host "CPU and Memory usage for each container:"
    $containers = docker compose -f "$script:AppsDir\$AppName\docker-compose.yml" ps -q
    foreach ($container in $containers) {
        $containerName = docker inspect --format '{{.Name}}' $container
        Write-Host "Container: $containerName" -ForegroundColor $Green
        docker stats --no-stream $container
    }
    Write-Host ""

    # Get network information
    Write-Host "Network Information:" -ForegroundColor $Yellow
    docker compose -f "$script:AppsDir\$AppName\docker-compose.yml" network ls
    Write-Host ""

    # Get volume information
    Write-Host "Volume Information:" -ForegroundColor $Yellow
    docker compose -f "$script:AppsDir\$AppName\docker-compose.yml" volume ls
    Write-Host ""

    # Get environment variables
    Write-Host "Environment Configuration:" -ForegroundColor $Yellow
    docker compose -f "$script:AppsDir\$AppName\docker-compose.yml" config
    Write-Host ""

    # Get recent logs
    Write-Host "Recent Logs (last 5 lines):" -ForegroundColor $Yellow
    docker compose -f "$script:AppsDir\$AppName\docker-compose.yml" logs --tail=5
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

# Function to backup application
function Backup-Application {
    param (
        [string]$AppName
    )
    
    if (-not $AppName) {
        Write-Host "Error: Application name required" -ForegroundColor $Red
        Write-Host "Usage: dcm backup <app>"
        exit 1
    }

    if (-not (Test-Path "$script:AppsDir\$AppName\docker-compose.yml")) {
        Write-Host "Error: Application '$AppName' not found" -ForegroundColor $Red
        exit 1
    }

    $backupDir = "$script:AppsDir\backups"
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    
    Write-Host "Creating backup for $AppName..."
    
    # Create backup directory
    New-Item -ItemType Directory -Force -Path "$backupDir\$AppName" | Out-Null
    
    # Backup docker-compose.yml and .env
    Copy-Item "$script:AppsDir\$AppName\docker-compose.yml" "$backupDir\$AppName\"
    if (Test-Path "$script:AppsDir\$AppName\.env") {
        Copy-Item "$script:AppsDir\$AppName\.env" "$backupDir\$AppName\"
    }
    
    # Backup volumes if enabled
    $config = Get-Content $ConfigFile | ConvertFrom-Json
    if ($config.backup.include_volumes) {
        $volumes = docker compose -f "$script:AppsDir\$AppName\docker-compose.yml" config --format json | ConvertFrom-Json | Select-Object -ExpandProperty volumes | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
        foreach ($volume in $volumes) {
            Write-Host "Backing up volume: $volume"
            docker run --rm -v "${volume}:/source" -v "$backupDir\$AppName:/backup" alpine tar czf "/backup/${volume}.tar.gz" -C /source .
        }
    }
    
    # Create backup archive
    $backupFile = "$backupDir\${AppName}_${timestamp}.tar.gz"
    Set-Location "$backupDir\$AppName"
    tar czf $backupFile .
    Set-Location $PSScriptRoot
    
    # Cleanup temporary files
    Remove-Item -Path "$backupDir\$AppName" -Recurse -Force
    
    Write-Host "Backup created: ${AppName}_${timestamp}.tar.gz" -ForegroundColor $Green
}

# Function to restore application
function Restore-Application {
    param (
        [string]$AppName,
        [string]$BackupFile
    )
    
    if (-not $AppName -or -not $BackupFile) {
        Write-Host "Error: Application name and backup file required" -ForegroundColor $Red
        Write-Host "Usage: dcm restore <app> <backup>"
        exit 1
    }

    $backupDir = "$script:AppsDir\backups"
    if (-not (Test-Path "$backupDir\$BackupFile")) {
        Write-Host "Error: Backup file '$BackupFile' not found" -ForegroundColor $Red
        exit 1
    }

    Write-Host "Restoring $AppName from backup..."
    
    # Create temporary directory
    $tempDir = Join-Path $env:TEMP ([System.Guid]::NewGuid().ToString())
    New-Item -ItemType Directory -Force -Path $tempDir | Out-Null
    
    # Extract backup
    Set-Location $tempDir
    tar xzf "$backupDir\$BackupFile"
    
    # Create application directory
    New-Item -ItemType Directory -Force -Path "$script:AppsDir\$AppName" | Out-Null
    
    # Restore docker-compose.yml and .env
    Copy-Item "docker-compose.yml" "$script:AppsDir\$AppName\"
    if (Test-Path ".env") {
        Copy-Item ".env" "$script:AppsDir\$AppName\"
    }
    
    # Restore volumes if they exist
    $config = Get-Content $ConfigFile | ConvertFrom-Json
    if ($config.backup.include_volumes) {
        Get-ChildItem -Path $tempDir -Filter "*.tar.gz" | ForEach-Object {
            $volumeName = $_.BaseName
            Write-Host "Restoring volume: $volumeName"
            docker volume create $volumeName
            docker run --rm -v "${volumeName}:/target" -v "$tempDir:/backup" alpine sh -c "cd /target && tar xzf /backup/$($_.Name)"
        }
    }
    
    # Cleanup
    Set-Location $PSScriptRoot
    Remove-Item -Path $tempDir -Recurse -Force
    
    Write-Host "Application restored successfully" -ForegroundColor $Green
}

# Main script logic
Test-Docker
Load-Config

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
            $apps = Get-ChildItem -Path $script:AppsDir -Directory | Where-Object { Test-Path "$($_.FullName)\docker-compose.yml" }
            foreach ($app in $apps) {
                Write-Host "Starting $($app.Name)..."
                docker compose -f "$($app.FullName)\docker-compose.yml" up -d
            }
        } else {
            if (Test-Path "$script:AppsDir\$($args[1])\docker-compose.yml") {
                docker compose -f "$script:AppsDir\$($args[1])\docker-compose.yml" up -d
            } else {
                Write-Host "Error: Application '$($args[1])' not found" -ForegroundColor $Red
                exit 1
            }
        }
    }
    "stop" {
        if (-not $args[1]) {
            $apps = Get-ChildItem -Path $script:AppsDir -Directory | Where-Object { Test-Path "$($_.FullName)\docker-compose.yml" }
            foreach ($app in $apps) {
                Write-Host "Stopping $($app.Name)..."
                docker compose -f "$($app.FullName)\docker-compose.yml" down
            }
        } else {
            if (Test-Path "$script:AppsDir\$($args[1])\docker-compose.yml") {
                docker compose -f "$script:AppsDir\$($args[1])\docker-compose.yml" down
            } else {
                Write-Host "Error: Application '$($args[1])' not found" -ForegroundColor $Red
                exit 1
            }
        }
    }
    "restart" {
        if (-not $args[1]) {
            $apps = Get-ChildItem -Path $script:AppsDir -Directory | Where-Object { Test-Path "$($_.FullName)\docker-compose.yml" }
            foreach ($app in $apps) {
                Write-Host "Restarting $($app.Name)..."
                docker compose -f "$($app.FullName)\docker-compose.yml" restart
            }
        } else {
            if (Test-Path "$script:AppsDir\$($args[1])\docker-compose.yml") {
                docker compose -f "$script:AppsDir\$($args[1])\docker-compose.yml" restart
            } else {
                Write-Host "Error: Application '$($args[1])' not found" -ForegroundColor $Red
                exit 1
            }
        }
    }
    "logs" {
        if (-not $args[1]) {
            $apps = Get-ChildItem -Path $script:AppsDir -Directory | Where-Object { Test-Path "$($_.FullName)\docker-compose.yml" }
            foreach ($app in $apps) {
                Write-Host "Logs for $($app.Name):"
                docker compose -f "$($app.FullName)\docker-compose.yml" logs
            }
        } else {
            if (Test-Path "$script:AppsDir\$($args[1])\docker-compose.yml") {
                docker compose -f "$script:AppsDir\$($args[1])\docker-compose.yml" logs
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
        New-Item -ItemType Directory -Force -Path "$script:AppsDir\$($args[1])" | Out-Null
        Copy-Item "$($args[2])\docker-compose.yml" "$script:AppsDir\$($args[1])\"
        if (Test-Path "$($args[2])\.env") {
            Copy-Item "$($args[2])\.env" "$script:AppsDir\$($args[1])\"
        }
        Write-Host "Application '$($args[1])' added successfully" -ForegroundColor $Green
    }
    "remove" {
        if (-not $args[1]) {
            Write-Host "Error: Application name required" -ForegroundColor $Red
            Write-Host "Usage: dcm remove <app>"
            exit 1
        }
        if (Test-Path "$script:AppsDir\$($args[1])") {
            Remove-Item -Path "$script:AppsDir\$($args[1])" -Recurse -Force
            Write-Host "Application '$($args[1])' removed successfully" -ForegroundColor $Green
        } else {
            Write-Host "Error: Application '$($args[1])' not found" -ForegroundColor $Red
            exit 1
        }
    }
    "update" {
        if (-not $args[1]) {
            $apps = Get-ChildItem -Path $script:AppsDir -Directory | Where-Object { Test-Path "$($_.FullName)\docker-compose.yml" }
            foreach ($app in $apps) {
                Write-Host "Updating $($app.Name)..."
                docker compose -f "$($app.FullName)\docker-compose.yml" pull
                docker compose -f "$($app.FullName)\docker-compose.yml" up -d
            }
        } else {
            if (Test-Path "$script:AppsDir\$($args[1])\docker-compose.yml") {
                docker compose -f "$script:AppsDir\$($args[1])\docker-compose.yml" pull
                docker compose -f "$script:AppsDir\$($args[1])\docker-compose.yml" up -d
            } else {
                Write-Host "Error: Application '$($args[1])' not found" -ForegroundColor $Red
                exit 1
            }
        }
    }
    "backup" {
        Backup-Application $args[1]
    }
    "restore" {
        Restore-Application $args[1] $args[2]
    }
    "create" {
        Create-App
    }
    "-h" { Show-Usage }
    "--help" { Show-Usage }
    default {
        Write-Host "Error: Unknown command" -ForegroundColor $Red
        Show-Usage
        exit 1
    }
} 