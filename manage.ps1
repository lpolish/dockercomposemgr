# Docker Compose Manager for Windows
# A command-line tool for managing Docker Compose applications

# Configuration
$ConfigDir = "$env:USERPROFILE\.config\dockercomposemgr"
$ConfigFile = "$ConfigDir\config.json"
$AppsFile = "$ConfigDir\apps.json"
$DefaultAppsDir = "$env:USERPROFILE\dockerapps"

# Colors for output
$Red = [System.ConsoleColor]::Red
$Green = [System.ConsoleColor]::Green
$Yellow = [System.ConsoleColor]::Yellow
$Cyan = [System.ConsoleColor]::Cyan

# Function to check if Docker is installed and running
function Check-Docker {
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        Write-Host "Error: Docker is not installed" -ForegroundColor $Red
        Write-Host "Please install Docker Desktop for Windows first"
        exit 1
    }
    
    try {
        $null = docker info
    }
    catch {
        Write-Host "Error: Docker daemon is not running" -ForegroundColor $Red
        Write-Host "Please start Docker Desktop and try again"
        exit 1
    }
}

# Function to display usage
function Show-Usage {
    Write-Host "Docker Compose Manager"
    Write-Host "Usage: dcm [command] [options]"
    Write-Host ""
    Write-Host "Commands:"
    Write-Host "  list                    List all applications"
    Write-Host "  add <name> <path>       Add a new application"
    Write-Host "  clone <repo> <name>     Clone and add an application from a repository"
    Write-Host "  remove <name>           Remove an application"
    Write-Host "  start <name>            Start an application"
    Write-Host "  stop <name>             Stop an application"
    Write-Host "  restart <name>          Restart an application"
    Write-Host "  status [name]           Show application status"
    Write-Host "  logs <name>             Show application logs"
    Write-Host "  info <name>             Show detailed application information"
    Write-Host "  backup <name>           Backup an application"
    Write-Host "  restore <name> <backup> Restore an application from backup"
    Write-Host "  update <name>           Update an application"
    Write-Host "  self-update             Update Docker Compose Manager to the latest version"
    Write-Host "  help                    Show this help message"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -h, --help              Show this help message"
}

# Function to load configuration
function Load-Config {
    if (-not (Test-Path $ConfigFile)) {
        Write-Host "Error: Configuration file not found" -ForegroundColor $Red
        Write-Host "Please run the installer first"
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

    # Load apps configuration
    if (-not (Test-Path $AppsFile)) {
        Set-Content -Path $AppsFile -Value '{}'
    }
}

# Function to get application path
function Get-AppPath {
    param (
        [string]$App
    )
    
    $apps = Get-Content $AppsFile | ConvertFrom-Json
    return $apps.apps.$App.path
}

# Function to add application
function Add-App {
    param (
        [string]$AppName,
        [string]$AppPath
    )

    if (-not $AppName -or -not $AppPath) {
        Write-Host "Error: Application name and path required" -ForegroundColor $Red
        Write-Host "Usage: dcm add <name> <path>"
        exit 1
    }

    # Remove trailing slash from app_path if present
    $AppPath = $AppPath.TrimEnd('\')

    if (-not (Test-Path "$AppPath\docker-compose.yml")) {
        Write-Host "Error: docker-compose.yml not found in specified path" -ForegroundColor $Red
        exit 1
    }

    # Ensure config directory exists
    New-Item -ItemType Directory -Force -Path $ConfigDir | Out-Null

    # Create application directory
    New-Item -ItemType Directory -Force -Path "$script:AppsDir\$AppName" | Out-Null

    # Store application path in config
    $apps = Get-Content $AppsFile | ConvertFrom-Json
    if (-not $apps) {
        $apps = @{
            version = "1.0.0"
            apps = @{}
            last_updated = $null
        }
    }
    
    $apps.apps.$AppName = @{
        path = $AppPath
    }
    $apps.last_updated = (Get-Date).ToString("o")
    
    $apps | ConvertTo-Json -Depth 10 | Set-Content $AppsFile

    # Create symbolic links
    $targetCompose = (Resolve-Path "$AppPath\docker-compose.yml").Path
    New-Item -ItemType SymbolicLink -Force -Path "$script:AppsDir\$AppName\docker-compose.yml" -Target $targetCompose | Out-Null
    
    if (Test-Path "$AppPath\.env") {
        $targetEnv = (Resolve-Path "$AppPath\.env").Path
        New-Item -ItemType SymbolicLink -Force -Path "$script:AppsDir\$AppName\.env" -Target $targetEnv | Out-Null
    }

    Write-Host "Application '$AppName' added successfully" -ForegroundColor $Green
}

# Function to clone and add application
function Clone-App {
    param (
        [string]$Repo,
        [string]$Name
    )
    
    $tempDir = Join-Path $env:TEMP ([System.Guid]::NewGuid().ToString())
    $appsDir = Get-ConfigValue "apps_directory"
    
    Write-Host "Cloning repository..."
    try {
        git clone $Repo $tempDir
    }
    catch {
        Write-Host "Failed to clone repository" -ForegroundColor $Red
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        return $false
    }
    
    # Create application directory in the configured apps directory
    $appDir = Join-Path $appsDir $Name
    if (-not (Test-Path $appDir)) {
        New-Item -ItemType Directory -Path $appDir -Force | Out-Null
    }
    
    # Copy docker-compose.yml and .env if they exist
    $composeFile = Join-Path $tempDir "docker-compose.yml"
    if (Test-Path $composeFile) {
        Copy-Item $composeFile $appDir
    }
    else {
        Write-Host "Warning: No docker-compose.yml found in repository" -ForegroundColor $Yellow
    }
    
    $envFile = Join-Path $tempDir ".env"
    if (Test-Path $envFile) {
        Copy-Item $envFile $appDir
    }
    
    # Copy README.md if it exists
    $readmeFile = Join-Path $tempDir "README.md"
    if (Test-Path $readmeFile) {
        Copy-Item $readmeFile $appDir
    }
    
    # Add to apps.json
    $appsFile = Join-Path $CONFIG_DIR "apps.json"
    $tempFile = Join-Path $env:TEMP ([System.Guid]::NewGuid().ToString())
    
    if (Test-Path $appsFile) {
        $apps = Get-Content $appsFile | ConvertFrom-Json
        $apps.apps | Add-Member -NotePropertyName $Name -NotePropertyValue @{path = $tempDir}
        $apps | ConvertTo-Json | Set-Content $tempFile
    }
    else {
        @{
            apps = @{
                $Name = @{
                    path = $tempDir
                }
            }
        } | ConvertTo-Json | Set-Content $tempFile
    }
    
    Move-Item -Path $tempFile -Destination $appsFile -Force
    Remove-Item -Path $tempDir -Recurse -Force
    
    Write-Host "Application '$Name' cloned and added successfully" -ForegroundColor $Green
}

# Function to get application status
function Get-Status {
    param (
        [string]$App
    )
    
    if (-not $App) {
        Get-ChildItem $script:AppsDir -Directory | ForEach-Object {
            $appName = $_.Name
            $appPath = Get-AppPath $appName
            if ($appPath) {
                Write-Host "Checking $appName..."
                docker compose -f "$appPath\docker-compose.yml" ps
            }
        }
    }
    else {
        $appPath = Get-AppPath $App
        if ($appPath) {
            docker compose -f "$appPath\docker-compose.yml" ps
        }
        else {
            Write-Host "Error: Application '$App' not found" -ForegroundColor $Red
            exit 1
        }
    }
}

# Function to get detailed application information
function Get-AppInfo {
    param (
        [string]$App
    )
    
    if (-not $App) {
        Write-Host "Error: Application name required" -ForegroundColor $Red
        Write-Host "Usage: dcm info <app>"
        exit 1
    }

    $appPath = Get-AppPath $App
    if (-not $appPath) {
        Write-Host "Error: Application '$App' not found" -ForegroundColor $Red
        exit 1
    }

    Write-Host "=== Detailed Information for $App ===" -ForegroundColor $Cyan
    Write-Host ""

    # Get container status
    Write-Host "Container Status:" -ForegroundColor $Yellow
    docker compose -f "$appPath\docker-compose.yml" ps
    Write-Host ""

    # Get container resource usage
    Write-Host "Resource Usage:" -ForegroundColor $Yellow
    Write-Host "CPU and Memory usage for each container:"
    $containers = docker compose -f "$appPath\docker-compose.yml" ps -q
    foreach ($container in $containers) {
        Write-Host "Container: $(docker inspect --format '{{.Name}}' $container)" -ForegroundColor $Green
        docker stats --no-stream $container
    }
    Write-Host ""

    # Get network information
    Write-Host "Network Information:" -ForegroundColor $Yellow
    docker compose -f "$appPath\docker-compose.yml" network ls
    Write-Host ""

    # Get volume information
    Write-Host "Volume Information:" -ForegroundColor $Yellow
    docker compose -f "$appPath\docker-compose.yml" volume ls
    Write-Host ""

    # Get environment variables
    Write-Host "Environment Configuration:" -ForegroundColor $Yellow
    docker compose -f "$appPath\docker-compose.yml" config
    Write-Host ""

    # Get recent logs
    Write-Host "Recent Logs (last 5 lines):" -ForegroundColor $Yellow
    docker compose -f "$appPath\docker-compose.yml" logs --tail=5
    Write-Host ""

    # Get health status
    Write-Host "Health Status:" -ForegroundColor $Yellow
    foreach ($container in $containers) {
        $health = docker inspect --format='{{.State.Health.Status}}' $container 2>$null
        if ($health) {
            Write-Host "Container: $(docker inspect --format '{{.Name}}' $container)" -ForegroundColor $Green
            Write-Host "Health: $health"
        }
    }
}

# Function to backup application
function Backup-App {
    param (
        [string]$App
    )
    
    if (-not $App) {
        Write-Host "Error: Application name required" -ForegroundColor $Red
        Write-Host "Usage: dcm backup <app>"
        exit 1
    }

    if (-not (Test-Path "$script:AppsDir\$App") -or -not (Test-Path "$script:AppsDir\$App\docker-compose.yml")) {
        Write-Host "Error: Application '$App' not found" -ForegroundColor $Red
        exit 1
    }

    Write-Host "Creating backup for $App..."
    
    # Create backup directory
    $backupDir = "$script:AppsDir\backups\$App"
    New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
    
    # Backup docker-compose.yml and .env
    Copy-Item "$script:AppsDir\$App\docker-compose.yml" "$backupDir\"
    if (Test-Path "$script:AppsDir\$App\.env") {
        Copy-Item "$script:AppsDir\$App\.env" "$backupDir\"
    }
    
    # Backup volumes if enabled
    $config = Get-Content $ConfigFile | ConvertFrom-Json
    if ($config.backup.include_volumes) {
        $volumes = docker compose -f "$script:AppsDir\$App\docker-compose.yml" config --format json | ConvertFrom-Json | Select-Object -ExpandProperty volumes | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
        foreach ($volume in $volumes) {
            Write-Host "Backing up volume: $volume"
            docker run --rm -v "${volume}:/source" -v "${backupDir}:/backup" alpine tar czf "/backup/${volume}.tar.gz" -C /source .
        }
    }
    
    # Create backup archive
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $archivePath = "$script:AppsDir\backups\${App}_${timestamp}.tar.gz"
    Set-Location $backupDir
    tar czf $archivePath .
    Set-Location $PSScriptRoot
    
    # Cleanup temporary files
    Remove-Item -Recurse -Force $backupDir
    
    Write-Host "Backup created: ${App}_${timestamp}.tar.gz" -ForegroundColor $Green
}

# Function to restore application
function Restore-App {
    param (
        [string]$App,
        [string]$Backup
    )
    
    if (-not $App -or -not $Backup) {
        Write-Host "Error: Application name and backup file required" -ForegroundColor $Red
        Write-Host "Usage: dcm restore <app> <backup>"
        exit 1
    }

    if (-not (Test-Path "$script:AppsDir\backups\$Backup")) {
        Write-Host "Error: Backup file '$Backup' not found" -ForegroundColor $Red
        exit 1
    }

    Write-Host "Restoring $App from backup..."
    
    # Create temporary directory
    $tempDir = Join-Path $env:TEMP ([System.Guid]::NewGuid().ToString())
    New-Item -ItemType Directory -Force -Path $tempDir | Out-Null
    
    # Extract backup
    tar xzf "$script:AppsDir\backups\$Backup" -C $tempDir
    
    # Create application directory
    New-Item -ItemType Directory -Force -Path "$script:AppsDir\$App" | Out-Null
    
    # Restore docker-compose.yml and .env
    Copy-Item "$tempDir\docker-compose.yml" "$script:AppsDir\$App\"
    if (Test-Path "$tempDir\.env") {
        Copy-Item "$tempDir\.env" "$script:AppsDir\$App\"
    }
    
    # Restore volumes if they exist
    $config = Get-Content $ConfigFile | ConvertFrom-Json
    if ($config.backup.include_volumes) {
        Get-ChildItem $tempDir -Filter "*.tar.gz" | ForEach-Object {
            $volumeName = $_.BaseName
            Write-Host "Restoring volume: $volumeName"
            docker volume create $volumeName
            docker run --rm -v "${volumeName}:/target" -v "${tempDir}:/backup" alpine sh -c "cd /target && tar xzf /backup/$($_.Name)"
        }
    }
    
    # Cleanup
    Remove-Item -Recurse -Force $tempDir
    
    Write-Host "Application restored successfully" -ForegroundColor $Green
}

# Function to remove application
function Remove-App {
    param (
        [string]$App
    )
    
    if (-not $App) {
        Write-Host "Error: Application name required" -ForegroundColor $Red
        Write-Host "Usage: dcm remove <app>"
        exit 1
    }

    # Check if app exists
    $apps = Get-Content $AppsFile | ConvertFrom-Json
    if (-not $apps.apps.$App) {
        Write-Host "Error: Application '$App' not found" -ForegroundColor $Red
        exit 1
    }

    # Stop the application if it's running
    if (docker compose -f "$script:AppsDir\$App\docker-compose.yml" ps -q) {
        Write-Host "Stopping application..."
        docker compose -f "$script:AppsDir\$App\docker-compose.yml" down
    }

    # Remove from config
    $apps.apps.PSObject.Properties.Remove($App)
    $apps | ConvertTo-Json -Depth 10 | Set-Content $AppsFile

    # Remove application directory
    Remove-Item -Recurse -Force "$script:AppsDir\$App"

    Write-Host "Application '$App' removed successfully" -ForegroundColor $Green
}

# Function to start application
function Start-App {
    param (
        [string]$App
    )
    
    if (-not $App) {
        Write-Host "Error: Application name required" -ForegroundColor $Red
        Write-Host "Usage: dcm start <app>"
        exit 1
    }

    $appPath = Get-AppPath $App
    if (-not $appPath) {
        Write-Host "Error: Application '$App' not found" -ForegroundColor $Red
        exit 1
    }

    Write-Host "Starting $App..."
    try {
        docker compose -f "$appPath\docker-compose.yml" up -d
        Write-Host "Application '$App' started successfully" -ForegroundColor $Green
    }
    catch {
        Write-Host "Error: Failed to start application" -ForegroundColor $Red
        exit 1
    }
}

# Function to stop application
function Stop-App {
    param (
        [string]$App
    )
    
    if (-not $App) {
        Write-Host "Error: Application name required" -ForegroundColor $Red
        Write-Host "Usage: dcm stop <app>"
        exit 1
    }

    $appPath = Get-AppPath $App
    if (-not $appPath) {
        Write-Host "Error: Application '$App' not found" -ForegroundColor $Red
        exit 1
    }

    Write-Host "Stopping $App..."
    try {
        docker compose -f "$appPath\docker-compose.yml" down
        Write-Host "Application '$App' stopped successfully" -ForegroundColor $Green
    }
    catch {
        Write-Host "Error: Failed to stop application" -ForegroundColor $Red
        exit 1
    }
}

# Function to restart application
function Restart-App {
    param (
        [string]$App
    )
    
    if (-not $App) {
        Write-Host "Error: Application name required" -ForegroundColor $Red
        Write-Host "Usage: dcm restart <app>"
        exit 1
    }

    $appPath = Get-AppPath $App
    if (-not $appPath) {
        Write-Host "Error: Application '$App' not found" -ForegroundColor $Red
        exit 1
    }

    Write-Host "Restarting $App..."
    try {
        docker compose -f "$appPath\docker-compose.yml" restart
        Write-Host "Application '$App' restarted successfully" -ForegroundColor $Green
    }
    catch {
        Write-Host "Error: Failed to restart application" -ForegroundColor $Red
        exit 1
    }
}

# Function to show application logs
function Show-Logs {
    param (
        [string]$App
    )
    
    if (-not $App) {
        Write-Host "Error: Application name required" -ForegroundColor $Red
        Write-Host "Usage: dcm logs <app>"
        exit 1
    }

    $appPath = Get-AppPath $App
    if (-not $appPath) {
        Write-Host "Error: Application '$App' not found" -ForegroundColor $Red
        exit 1
    }

    Write-Host "Showing logs for $App..."
    docker compose -f "$appPath\docker-compose.yml" logs -f
}

# Function to update application
function Update-App {
    param (
        [string]$App
    )
    
    if (-not $App) {
        Write-Host "Error: Application name required" -ForegroundColor $Red
        Write-Host "Usage: dcm update <app_name>"
        exit 1
    }

    $appPath = Get-AppPath $App
    if (-not $appPath) {
        Write-Host "Error: Application '$App' not found" -ForegroundColor $Red
        exit 1
    }

    Write-Host "Updating $App..."
    
    try {
        # Pull latest images
        docker compose -f "$appPath\docker-compose.yml" pull

        # Stop the application
        docker compose -f "$appPath\docker-compose.yml" down

        # Start the application with new images
        docker compose -f "$appPath\docker-compose.yml" up -d

        Write-Host "Application '$App' updated successfully" -ForegroundColor $Green
    }
    catch {
        Write-Host "Error: Failed to update application" -ForegroundColor $Red
        exit 1
    }
}

# Function to list all applications
function List-Apps {
    # Ensure config directory exists with proper permissions
    if (-not (Test-Path $ConfigDir)) {
        New-Item -ItemType Directory -Force -Path $ConfigDir | Out-Null
        $acl = Get-Acl $ConfigDir
        $acl.SetAccessRuleProtection($false, $true)
        Set-Acl $ConfigDir $acl
    }

    # Ensure apps.json exists with proper permissions
    if (-not (Test-Path $AppsFile)) {
        Set-Content -Path $AppsFile -Value '{}'
        $acl = Get-Acl $AppsFile
        $acl.SetAccessRuleProtection($false, $true)
        Set-Acl $AppsFile $acl
    }

    try {
        $apps = Get-Content $AppsFile | ConvertFrom-Json
        if (-not $apps.apps -or $apps.apps.PSObject.Properties.Count -eq 0) {
            Write-Host "No applications configured yet" -ForegroundColor $Yellow
            return
        }
    }
    catch {
        Write-Host "Error: Failed to read applications configuration" -ForegroundColor $Red
        Write-Host "Attempting to fix permissions..." -ForegroundColor $Yellow
        $acl = Get-Acl $AppsFile
        $acl.SetAccessRuleProtection($false, $true)
        Set-Acl $AppsFile $acl
        try {
            $apps = Get-Content $AppsFile | ConvertFrom-Json
            if (-not $apps.apps -or $apps.apps.PSObject.Properties.Count -eq 0) {
                Write-Host "No applications configured yet" -ForegroundColor $Yellow
                return
            }
        }
        catch {
            Write-Host "Error: Still unable to read applications configuration" -ForegroundColor $Red
            exit 1
        }
    }

    Write-Host "Configured Applications:" -ForegroundColor $Cyan
    Write-Host "----------------------------------------"
    foreach ($app in $apps.apps.PSObject.Properties) {
        Write-Host $app.Name -ForegroundColor $Green
        Write-Host "  Path: $($app.Value.path)"
        if (Test-Path "$script:AppsDir\$($app.Name)") {
            if (Test-Path "$script:AppsDir\$($app.Name)\docker-compose.yml") {
                try {
                    $status = docker compose -f "$script:AppsDir\$($app.Name)\docker-compose.yml" ps --format json | ConvertFrom-Json
                    if ($status.Count -eq 0) {
                        Write-Host "  Status: Not running"
                    }
                    else {
                        Write-Host "  Status: Running"
                    }
                }
                catch {
                    Write-Host "  Status: Error checking status"
                }
            }
            else {
                Write-Host "  Status: Configuration missing"
            }
        }
        else {
            Write-Host "  Status: Directory missing"
        }
        Write-Host "----------------------------------------"
    }
}

# Main script logic
if ($args.Count -eq 0) {
    Show-Usage
    exit 0
}

# Load configuration
Load-Config

# Check Docker
Check-Docker

switch ($args[0]) {
    "list" {
        List-Apps
    }
    "start" {
        if (-not $args[1]) {
            Write-Host "Error: Application name is required" -ForegroundColor $Red
            Write-Host "Usage: dcm start <app_name>"
            exit 1
        }
        Start-App $args[1]
    }
    "stop" {
        if (-not $args[1]) {
            Write-Host "Error: Application name is required" -ForegroundColor $Red
            Write-Host "Usage: dcm stop <app_name>"
            exit 1
        }
        Stop-App $args[1]
    }
    "restart" {
        if (-not $args[1]) {
            Write-Host "Error: Application name is required" -ForegroundColor $Red
            Write-Host "Usage: dcm restart <app_name>"
            exit 1
        }
        Restart-App $args[1]
    }
    "logs" {
        if (-not $args[1]) {
            Write-Host "Error: Application name is required" -ForegroundColor $Red
            Write-Host "Usage: dcm logs <app_name>"
            exit 1
        }
        Show-Logs $args[1]
    }
    "add" {
        if (-not $args[1] -or -not $args[2]) {
            Write-Host "Error: Application name and path are required" -ForegroundColor $Red
            Write-Host "Usage: dcm add <app_name> <path>"
            exit 1
        }
        Add-App $args[1] $args[2]
    }
    "remove" {
        if (-not $args[1]) {
            Write-Host "Error: Application name is required" -ForegroundColor $Red
            Write-Host "Usage: dcm remove <app_name>"
            exit 1
        }
        Remove-App $args[1]
    }
    "backup" {
        if (-not $args[1]) {
            Write-Host "Error: Application name is required" -ForegroundColor $Red
            Write-Host "Usage: dcm backup <app_name>"
            exit 1
        }
        Backup-App $args[1]
    }
    "restore" {
        if (-not $args[1] -or -not $args[2]) {
            Write-Host "Error: Application name and backup name are required" -ForegroundColor $Red
            Write-Host "Usage: dcm restore <app_name> <backup_name>"
            exit 1
        }
        Restore-App $args[1] $args[2]
    }
    "update" {
        if (-not $args[1]) {
            Write-Host "Error: Application name is required" -ForegroundColor $Red
            Write-Host "Usage: dcm update <app_name>"
            exit 1
        }
        Update-App $args[1]
    }
    "status" {
        if (-not $args[1]) {
            Get-Status
        }
        else {
            Get-Status $args[1]
        }
    }
    "info" {
        if (-not $args[1]) {
            Write-Host "Error: Application name is required" -ForegroundColor $Red
            Write-Host "Usage: dcm info <app_name>"
            exit 1
        }
        Get-AppInfo $args[1]
    }
    "clone" {
        if (-not $args[1] -or -not $args[2]) {
            Write-Host "Error: Repository URL and application name are required" -ForegroundColor $Red
            Write-Host "Usage: dcm clone <repo_url> <app_name>"
            exit 1
        }
        Clone-App $args[1] $args[2]
    }
    "self-update" {
        # Implementation of self-update command
        Write-Host "Self-update command not implemented yet" -ForegroundColor $Yellow
    }
    "help" {
        Show-Usage
    }
    default {
        Write-Host "Unknown command: $($args[0])" -ForegroundColor $Red
        Show-Usage
        exit 1
    }
} 