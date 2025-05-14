#!/bin/bash

# Docker Compose Manager for Linux
# A command-line tool for managing Docker Compose applications

# Load configuration
CONFIG_DIR="$HOME/.config/dockercomposemgr"
CONFIG_FILE="$CONFIG_DIR/config.json"
APPS_FILE="$CONFIG_DIR/apps.json"
DEFAULT_APPS_DIR="$HOME/dockerapps"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to check if Docker is installed and running
check_docker() {
    # Check if we're in a container
    if [ -f /.dockerenv ] || [ -f /run/.containerenv ]; then
        echo -e "${YELLOW}Running in container environment - skipping Docker checks${NC}"
        return 0
    fi

    if ! command -v docker &> /dev/null; then
        echo -e "${RED}Error: Docker is not installed${NC}"
        echo "Please run the installer first:"
        echo "curl -fsSL https://raw.githubusercontent.com/lpolish/dockercomposemgr/main/install.sh | bash"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        echo -e "${RED}Error: Docker daemon is not running${NC}"
        echo "Please start the Docker daemon and try again"
        exit 1
    fi
}

# Function to display usage
show_usage() {
    echo "Docker Compose Manager"
    echo "Usage: dcm [command] [options]"
    echo ""
    echo "Commands:"
    echo "  list                    List all applications"
    echo "  add <name> <path>       Add a new application"
    echo "  clone <repo> <name>     Clone and add an application from a repository"
    echo "  remove <name>           Remove an application"
    echo "  start <name>            Start an application"
    echo "  stop <name>             Stop an application"
    echo "  restart <name>          Restart an application"
    echo "  status [name]           Show application status"
    echo "  logs <name>             Show application logs"
    echo "  info <name>             Show detailed application information"
    echo "  backup <name>           Backup an application"
    echo "  restore <name> <backup> Restore an application from backup"
    echo "  update <name>           Update an application"
    echo "  self-update             Update Docker Compose Manager to the latest version"
    echo "  help                    Show this help message"
    echo ""
    echo "Options:"
    echo "  -h, --help              Show this help message"
}

# Function to load configuration
load_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "${RED}Error: Configuration file not found${NC}"
        echo "Please run the installer first:"
        echo "curl -fsSL https://raw.githubusercontent.com/lpolish/dockercomposemgr/main/install.sh | bash"
        exit 1
    fi
    
    # Load apps directory from config
    APPS_DIR=$(jq -r '.apps_directory' "$CONFIG_FILE")
    if [ "$APPS_DIR" = "null" ] || [ -z "$APPS_DIR" ]; then
        APPS_DIR="$DEFAULT_APPS_DIR"
    fi
    
    # Expand ~ to home directory
    APPS_DIR="${APPS_DIR/#\~/$HOME}"
    
    # Create apps directory if it doesn't exist
    mkdir -p "$APPS_DIR/backups"

    # Load apps configuration
    if [ ! -f "$APPS_FILE" ]; then
        echo "{}" > "$APPS_FILE"
        chmod 644 "$APPS_FILE"
    fi

    # Ensure proper permissions
    chmod 644 "$CONFIG_FILE"
    chmod 644 "$APPS_FILE"
}

# Function to get application path
get_app_path() {
    local app=$1
    local path=$(jq -r --arg app "$app" '.apps[$app].path' "$APPS_FILE")
    if [ "$path" = "null" ]; then
        echo ""
    else
        echo "$path"
    fi
}

# Function to add application
add_app() {
    local app_name=$1
    local app_path=$2

    if [ -z "$app_name" ] || [ -z "$app_path" ]; then
        echo -e "${RED}Error: Application name and path required${NC}"
        echo "Usage: dcm add <name> <path>"
        exit 1
    fi

    # Remove trailing slash from app_path if present
    app_path="${app_path%/}"

    if [ ! -f "$app_path/docker-compose.yml" ]; then
        echo -e "${RED}Error: docker-compose.yml not found in specified path${NC}"
        exit 1
    fi

    # Ensure config directory exists with proper permissions
    mkdir -p "$CONFIG_DIR"
    chmod 755 "$CONFIG_DIR"

    # Create application directory
    mkdir -p "$APPS_DIR/$app_name"

    # Store application path in config
    local config
    if [ -f "$APPS_FILE" ]; then
        config=$(cat "$APPS_FILE")
    else
        config='{"version": "1.0.0", "apps": {}, "last_updated": null}'
    fi

    # Update the config with the new app
    config=$(echo "$config" | jq --arg app "$app_name" --arg path "$app_path" '.apps[$app] = {"path": $path} | .last_updated = now')
    echo "$config" > "$APPS_FILE"
    chmod 644 "$APPS_FILE"

    # Create symbolic links with normalized paths
    ln -sf "$(realpath "$app_path/docker-compose.yml")" "$APPS_DIR/$app_name/docker-compose.yml"
    if [ -f "$app_path/.env" ]; then
        ln -sf "$(realpath "$app_path/.env")" "$APPS_DIR/$app_name/.env"
    fi

    # Verify the app was added correctly
    if ! jq -e --arg app "$app_name" '.apps[$app]' "$APPS_FILE" > /dev/null; then
        echo -e "${RED}Error: Failed to add application to configuration${NC}"
        exit 1
    fi

    echo -e "${GREEN}Application '$app_name' added successfully${NC}"
}

# Function to clone and add application
clone_app() {
    local repo=$1
    local name=$2
    local temp_dir=$(mktemp -d)
    local apps_dir=$(get_config_value "apps_directory")
    
    echo "Cloning repository..."
    if ! git clone "$repo" "$temp_dir"; then
        echo "Failed to clone repository"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Create application directory in the configured apps directory
    local app_dir="$apps_dir/$name"
    if [ ! -d "$app_dir" ]; then
        mkdir -p "$app_dir"
    fi
    
    # Copy docker-compose.yml and .env if they exist
    if [ -f "$temp_dir/docker-compose.yml" ]; then
        cp "$temp_dir/docker-compose.yml" "$app_dir/"
    else
        echo "Warning: No docker-compose.yml found in repository"
    fi
    
    if [ -f "$temp_dir/.env" ]; then
        cp "$temp_dir/.env" "$app_dir/"
    fi
    
    # Copy README.md if it exists
    if [ -f "$temp_dir/README.md" ]; then
        cp "$temp_dir/README.md" "$app_dir/"
    fi
    
    # Add to apps.json
    local apps_file="$CONFIG_DIR/apps.json"
    local temp_file=$(mktemp)
    
    if [ -f "$apps_file" ]; then
        jq --arg name "$name" --arg path "$temp_dir" '.apps[$name] = {"path": $path}' "$apps_file" > "$temp_file"
    else
        echo "{\"apps\": {\"$name\": {\"path\": \"$temp_dir\"}}}" > "$temp_file"
    fi
    
    mv "$temp_file" "$apps_file"
    rm -rf "$temp_dir"
    
    echo "Application '$name' cloned and added successfully"
}

# Function to get application status
get_status() {
    local app=$1
    if [ -z "$app" ]; then
        for app_dir in "$APPS_DIR"/*; do
            if [ -d "$app_dir" ]; then
                app_name=$(basename "$app_dir")
                app_path=$(get_app_path "$app_name")
                if [ ! -z "$app_path" ]; then
                    echo "Checking $app_name..."
                    docker compose -f "$app_path/docker-compose.yml" ps
                fi
            fi
        done
    else
        app_path=$(get_app_path "$app")
        if [ ! -z "$app_path" ]; then
            docker compose -f "$app_path/docker-compose.yml" ps
        else
            echo -e "${RED}Error: Application '$app' not found${NC}"
            exit 1
        fi
    fi
}

# Function to get detailed application information
get_app_info() {
    local app=$1
    if [ -z "$app" ]; then
        echo -e "${RED}Error: Application name required${NC}"
        echo "Usage: dcm info <app>"
        exit 1
    fi

    app_path=$(get_app_path "$app")
    if [ -z "$app_path" ]; then
        echo -e "${RED}Error: Application '$app' not found${NC}"
        exit 1
    fi

    echo -e "${CYAN}=== Detailed Information for $app ===${NC}"
    echo

    # Get container status
    echo -e "${YELLOW}Container Status:${NC}"
    docker compose -f "$app_path/docker-compose.yml" ps
    echo

    # Get container resource usage
    echo -e "${YELLOW}Resource Usage:${NC}"
    echo "CPU and Memory usage for each container:"
    for container in $(docker compose -f "$app_path/docker-compose.yml" ps -q); do
        echo -e "${GREEN}Container: $(docker inspect --format '{{.Name}}' $container)${NC}"
        docker stats --no-stream $container
    done
    echo

    # Get network information
    echo -e "${YELLOW}Network Information:${NC}"
    docker compose -f "$app_path/docker-compose.yml" network ls
    echo

    # Get volume information
    echo -e "${YELLOW}Volume Information:${NC}"
    docker compose -f "$app_path/docker-compose.yml" volume ls
    echo

    # Get environment variables
    echo -e "${YELLOW}Environment Configuration:${NC}"
    docker compose -f "$app_path/docker-compose.yml" config
    echo

    # Get recent logs
    echo -e "${YELLOW}Recent Logs (last 5 lines):${NC}"
    docker compose -f "$app_path/docker-compose.yml" logs --tail=5
    echo

    # Get health status
    echo -e "${YELLOW}Health Status:${NC}"
    for container in $(docker compose -f "$app_path/docker-compose.yml" ps -q); do
        health=$(docker inspect --format='{{.State.Health.Status}}' $container 2>/dev/null)
        if [ ! -z "$health" ]; then
            echo -e "${GREEN}Container: $(docker inspect --format '{{.Name}}' $container)${NC}"
            echo "Health: $health"
        fi
    done
}

# Function to backup application
backup_app() {
    local app=$1
    local backup_dir="$APPS_DIR/backups"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    
    if [ -z "$app" ]; then
        echo -e "${RED}Error: Application name required${NC}"
        echo "Usage: dcm backup <app>"
        exit 1
    fi

    if [ ! -d "$APPS_DIR/$app" ] || [ ! -f "$APPS_DIR/$app/docker-compose.yml" ]; then
        echo -e "${RED}Error: Application '$app' not found${NC}"
        exit 1
    fi

    echo "Creating backup for $app..."
    
    # Create backup directory
    mkdir -p "$backup_dir/$app"
    
    # Backup docker-compose.yml and .env
    cp "$APPS_DIR/$app/docker-compose.yml" "$backup_dir/$app/docker-compose.yml"
    if [ -f "$APPS_DIR/$app/.env" ]; then
        cp "$APPS_DIR/$app/.env" "$backup_dir/$app/.env"
    fi
    
    # Backup volumes if enabled
    if [ "$(jq -r '.backup.include_volumes' "$CONFIG_FILE")" = "true" ]; then
        for volume in $(docker compose -f "$APPS_DIR/$app/docker-compose.yml" config --format json | jq -r '.volumes | keys[]'); do
            echo "Backing up volume: $volume"
            docker run --rm -v "$volume:/source" -v "$backup_dir/$app:/backup" alpine tar czf "/backup/${volume}.tar.gz" -C /source .
        done
    fi
    
    # Create backup archive
    cd "$backup_dir/$app"
    tar czf "../${app}_${timestamp}.tar.gz" .
    cd - > /dev/null
    
    # Cleanup temporary files
    rm -rf "$backup_dir/$app"
    
    echo -e "${GREEN}Backup created: ${app}_${timestamp}.tar.gz${NC}"
}

# Function to restore application
restore_app() {
    local app=$1
    local backup=$2
    local backup_dir="$APPS_DIR/backups"
    
    if [ -z "$app" ] || [ -z "$backup" ]; then
        echo -e "${RED}Error: Application name and backup file required${NC}"
        echo "Usage: dcm restore <app> <backup>"
        exit 1
    fi

    if [ ! -f "$backup_dir/$backup" ]; then
        echo -e "${RED}Error: Backup file '$backup' not found${NC}"
        exit 1
    fi

    echo "Restoring $app from backup..."
    
    # Create temporary directory
    local temp_dir=$(mktemp -d)
    
    # Extract backup
    tar xzf "$backup_dir/$backup" -C "$temp_dir"
    
    # Create application directory
    mkdir -p "$APPS_DIR/$app"
    
    # Restore docker-compose.yml and .env
    cp "$temp_dir/docker-compose.yml" "$APPS_DIR/$app/"
    if [ -f "$temp_dir/.env" ]; then
        cp "$temp_dir/.env" "$APPS_DIR/$app/"
    fi
    
    # Restore volumes if they exist
    if [ "$(jq -r '.backup.include_volumes' "$CONFIG_FILE")" = "true" ]; then
        for volume_file in "$temp_dir"/*.tar.gz; do
            if [ -f "$volume_file" ]; then
                volume_name=$(basename "$volume_file" .tar.gz)
                echo "Restoring volume: $volume_name"
                docker volume create "$volume_name"
                docker run --rm -v "$volume_name:/target" -v "$temp_dir:/backup" alpine sh -c "cd /target && tar xzf /backup/$(basename "$volume_file")"
            fi
        done
    fi
    
    # Cleanup
    rm -rf "$temp_dir"
    
    echo -e "${GREEN}Application restored successfully${NC}"
}

# Function to get available templates
get_available_templates() {
    local registry_url="https://raw.githubusercontent.com/lpolish/dockercomposemgr/main/templates/registry.json"
    if ! command -v curl &> /dev/null; then
        echo -e "${RED}Error: curl is required for downloading templates${NC}"
        exit 1
    fi
    
    if ! templates=$(curl -s "$registry_url"); then
        echo -e "${RED}Error: Could not fetch template registry${NC}"
        echo "Falling back to local templates..."
        return 1
    fi
    
    echo "$templates"
}

# Function to download template
download_template() {
    local template_id=$1
    local destination=$2
    local templates
    
    templates=$(get_available_templates)
    if [ $? -ne 0 ]; then
        return 1
    fi
    
    # Extract template info using jq
    local template_url=$(echo "$templates" | jq -r ".templates.$template_id.url")
    if [ "$template_url" = "null" ]; then
        echo -e "${RED}Error: Template '$template_id' not found in registry${NC}"
        return 1
    fi
    
    # Create template directory
    mkdir -p "$destination"
    
    # Download each file
    local files=$(echo "$templates" | jq -r ".templates.$template_id.files[]")
    for file in $files; do
        echo "Downloading $file..."
        if ! curl -s "$template_url/$file" -o "$destination/$file"; then
            echo -e "${RED}Error: Failed to download $file${NC}"
            return 1
        fi
    done
    
    return 0
}

# Function to create a new application
create_app() {
    check_git

    # Get app name
    read -p "Enter application name: " app_name
    if [ -z "$app_name" ]; then
        echo "Application name cannot be empty"
        return 1
    fi

    # Get app description
    read -p "Enter application description: " app_description
    if [ -z "$app_description" ]; then
        echo "Application description cannot be empty"
        return 1
    fi

    # Get app directory
    read -p "Enter application directory (default: ./$app_name): " app_dir
    app_dir=${app_dir:-"./$app_name"}

    # Check if directory exists
    if [ -d "$app_dir" ]; then
        echo "Directory $app_dir already exists"
        return 1
    fi

    # Create directory
    mkdir -p "$app_dir"

    # Get available templates
    templates=("nodejs" "fastapi" "nextjs")
    echo "Available templates:"
    for i in "${!templates[@]}"; do
        echo "$((i+1)). ${templates[$i]}"
    done

    # Get template choice
    read -p "Select template (1-${#templates[@]}): " template_choice
    if ! [[ "$template_choice" =~ ^[1-${#templates[@]}]$ ]]; then
        echo "Invalid template choice"
        return 1
    fi

    template=${templates[$((template_choice-1))]}
    
    # Get template registry
    echo "Fetching template registry..."
    registry_url="https://raw.githubusercontent.com/lpolish/dockercomposemgr/main/templates/registry.json"
    if ! templates_json=$(curl -s "$registry_url"); then
        echo -e "${RED}Error: Could not fetch template registry${NC}"
        return 1
    fi

    # Extract template info
    template_url=$(echo "$templates_json" | jq -r ".templates.$template.url")
    if [ "$template_url" = "null" ]; then
        echo -e "${RED}Error: Template '$template' not found in registry${NC}"
        return 1
    fi

    # Download template files
    echo "Downloading template files..."
    files=$(echo "$templates_json" | jq -r ".templates.$template.files[]")
    for file in $files; do
        echo "Downloading $file..."
        if ! curl -s "$template_url/$file" -o "$app_dir/$file"; then
            echo -e "${RED}Error: Failed to download $file${NC}"
            return 1
        fi
    done

    # Initialize git repository
    cd "$app_dir" || return 1
    git init
    git add .
    git commit -m "Initial commit"

    # Update package.json or requirements.txt with app name and description
    if [ -f "package.json" ]; then
        sed -i "s/\"name\": \".*\"/\"name\": \"$app_name\"/" package.json
        sed -i "s/\"description\": \".*\"/\"description\": \"$app_description\"/" package.json
    elif [ -f "requirements.txt" ]; then
        echo "# $app_name" > requirements.txt.new
        echo "# $app_description" >> requirements.txt.new
        cat requirements.txt >> requirements.txt.new
        mv requirements.txt.new requirements.txt
    fi

    echo -e "${GREEN}Application created successfully in $app_dir${NC}"
    echo "You can now start developing your application"
}

# Function to list all applications
list_apps() {
    # Ensure config directory exists with proper permissions
    if [ ! -d "$CONFIG_DIR" ]; then
        mkdir -p "$CONFIG_DIR"
        chmod 755 "$CONFIG_DIR"
    else
        # Fix permissions if they're incorrect
        chmod 755 "$CONFIG_DIR"
    fi

    # Ensure apps.json exists with proper permissions
    if [ ! -f "$APPS_FILE" ]; then
        echo "{}" > "$APPS_FILE"
        chmod 644 "$APPS_FILE"
    else
        # Fix permissions if they're incorrect
        chmod 644 "$APPS_FILE"
    fi

    # Check if jq is installed
    if ! command -v jq &> /dev/null; then
        echo -e "${RED}Error: jq is required but not installed${NC}"
        exit 1
    fi

    local apps
    if ! apps=$(jq -r '.apps | keys[]' "$APPS_FILE" 2>/dev/null); then
        echo -e "${RED}Error: Failed to read applications configuration${NC}"
        echo -e "${YELLOW}Attempting to fix permissions...${NC}"
        chmod 644 "$APPS_FILE"
        if ! apps=$(jq -r '.apps | keys[]' "$APPS_FILE" 2>/dev/null); then
            echo -e "${RED}Error: Still unable to read applications configuration${NC}"
            exit 1
        fi
    fi

    if [ -z "$apps" ]; then
        echo -e "${YELLOW}No applications configured yet${NC}"
        return 0
    fi

    echo -e "${CYAN}Configured Applications:${NC}"
    echo "----------------------------------------"
    for app in $apps; do
        local path
        if ! path=$(jq -r --arg app "$app" '.apps[$app].path' "$APPS_FILE" 2>/dev/null); then
            echo -e "${RED}Error: Failed to get path for application '$app'${NC}"
            continue
        fi
        echo -e "${GREEN}$app${NC}"
        echo "  Path: $path"
        if [ -d "$APPS_DIR/$app" ]; then
            if [ -f "$APPS_DIR/$app/docker-compose.yml" ]; then
                local status
                if status=$(docker compose -f "$APPS_DIR/$app/docker-compose.yml" ps --format json 2>/dev/null | jq -r 'if . == [] then "Not running" else "Running" end'); then
                    echo "  Status: $status"
                else
                    echo "  Status: Error checking status"
                fi
            else
                echo "  Status: Configuration missing"
            fi
        else
            echo "  Status: Directory missing"
        fi
        echo "----------------------------------------"
    done
}

# Function to self-update the script
self_update() {
    echo -e "${CYAN}Checking for updates...${NC}"
    
    # Get the current script's directory
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    SCRIPT_PATH="$SCRIPT_DIR/dcm"
    
    # Calculate current script's checksum
    CURRENT_CHECKSUM=$(sha256sum "$SCRIPT_PATH" 2>/dev/null | cut -d' ' -f1)
    if [ -z "$CURRENT_CHECKSUM" ]; then
        echo -e "${RED}Error: Could not calculate current script checksum${NC}"
        return 1
    fi
    
    # Download the latest version to a temporary file
    TEMP_FILE=$(mktemp)
    if ! curl -fsSL "https://raw.githubusercontent.com/lpolish/dockercomposemgr/main/manage.sh" -o "$TEMP_FILE"; then
        echo -e "${RED}Failed to download update${NC}"
        rm -f "$TEMP_FILE"
        return 1
    fi
    
    # Calculate new script's checksum
    NEW_CHECKSUM=$(sha256sum "$TEMP_FILE" 2>/dev/null | cut -d' ' -f1)
    if [ -z "$NEW_CHECKSUM" ]; then
        echo -e "${RED}Error: Could not calculate new script checksum${NC}"
        rm -f "$TEMP_FILE"
        return 1
    fi
    
    # Compare checksums
    if [ "$CURRENT_CHECKSUM" = "$NEW_CHECKSUM" ]; then
        echo -e "${GREEN}Already running the latest version${NC}"
        rm -f "$TEMP_FILE"
        return 0
    fi
    
    # Create backup of current script
    BACKUP_PATH="${SCRIPT_PATH}.bak"
    cp "$SCRIPT_PATH" "$BACKUP_PATH"
    
    # Replace current script with new version
    if ! mv "$TEMP_FILE" "$SCRIPT_PATH"; then
        echo -e "${RED}Failed to update script${NC}"
        mv "$BACKUP_PATH" "$SCRIPT_PATH"
        return 1
    fi
    
    # Ensure script remains executable
    chmod +x "$SCRIPT_PATH"
    
    echo -e "${GREEN}Script updated successfully${NC}"
    echo -e "${YELLOW}A backup of the previous version was created at: $BACKUP_PATH${NC}"
    return 0
}

# Function to remove application
remove_app() {
    local app=$1
    
    if [ -z "$app" ]; then
        echo -e "${RED}Error: Application name required${NC}"
        echo "Usage: dcm remove <app>"
        exit 1
    fi

    # Check if app exists
    if ! jq -e --arg app "$app" '.apps[$app]' "$APPS_FILE" > /dev/null; then
        echo -e "${RED}Error: Application '$app' not found${NC}"
        exit 1
    fi

    # Stop the application if it's running
    if docker compose -f "$APPS_DIR/$app/docker-compose.yml" ps -q | grep -q .; then
        echo "Stopping application..."
        docker compose -f "$APPS_DIR/$app/docker-compose.yml" down
    fi

    # Remove from config
    local config=$(cat "$APPS_FILE")
    config=$(echo "$config" | jq --arg app "$app" 'del(.apps[$app])')
    echo "$config" > "$APPS_FILE"

    # Remove application directory
    rm -rf "$APPS_DIR/$app"

    echo -e "${GREEN}Application '$app' removed successfully${NC}"
}

# Function to start application
start_app() {
    local app=$1
    
    if [ -z "$app" ]; then
        echo -e "${RED}Error: Application name required${NC}"
        echo "Usage: dcm start <app>"
        exit 1
    fi

    app_path=$(get_app_path "$app")
    if [ -z "$app_path" ]; then
        echo -e "${RED}Error: Application '$app' not found${NC}"
        exit 1
    fi

    echo "Starting $app..."
    if docker compose -f "$app_path/docker-compose.yml" up -d; then
        echo -e "${GREEN}Application '$app' started successfully${NC}"
    else
        echo -e "${RED}Error: Failed to start application${NC}"
        exit 1
    fi
}

# Function to stop application
stop_app() {
    local app=$1
    
    if [ -z "$app" ]; then
        echo -e "${RED}Error: Application name required${NC}"
        echo "Usage: dcm stop <app>"
        exit 1
    fi

    app_path=$(get_app_path "$app")
    if [ -z "$app_path" ]; then
        echo -e "${RED}Error: Application '$app' not found${NC}"
        exit 1
    fi

    echo "Stopping $app..."
    if docker compose -f "$app_path/docker-compose.yml" down; then
        echo -e "${GREEN}Application '$app' stopped successfully${NC}"
    else
        echo -e "${RED}Error: Failed to stop application${NC}"
        exit 1
    fi
}

# Function to restart application
restart_app() {
    local app=$1
    
    if [ -z "$app" ]; then
        echo -e "${RED}Error: Application name required${NC}"
        echo "Usage: dcm restart <app>"
        exit 1
    fi

    app_path=$(get_app_path "$app")
    if [ -z "$app_path" ]; then
        echo -e "${RED}Error: Application '$app' not found${NC}"
        exit 1
    fi

    echo "Restarting $app..."
    if docker compose -f "$app_path/docker-compose.yml" restart; then
        echo -e "${GREEN}Application '$app' restarted successfully${NC}"
    else
        echo -e "${RED}Error: Failed to restart application${NC}"
        exit 1
    fi
}

# Function to show application logs
show_logs() {
    local app=$1
    
    if [ -z "$app" ]; then
        echo -e "${RED}Error: Application name required${NC}"
        echo "Usage: dcm logs <app>"
        exit 1
    fi

    app_path=$(get_app_path "$app")
    if [ -z "$app_path" ]; then
        echo -e "${RED}Error: Application '$app' not found${NC}"
        exit 1
    fi

    echo "Showing logs for $app..."
    docker compose -f "$app_path/docker-compose.yml" logs -f
}

# Function to update application
update_app() {
    local app=$1
    
    if [ -z "$app" ]; then
        echo -e "${RED}Error: Application name required${NC}"
        echo "Usage: dcm update <app>"
        exit 1
    fi

    app_path=$(get_app_path "$app")
    if [ -z "$app_path" ]; then
        echo -e "${RED}Error: Application '$app' not found${NC}"
        exit 1
    fi

    echo "Updating $app..."
    
    # Pull latest images
    if ! docker compose -f "$app_path/docker-compose.yml" pull; then
        echo -e "${RED}Error: Failed to pull latest images${NC}"
        exit 1
    fi

    # Stop the application
    if ! docker compose -f "$app_path/docker-compose.yml" down; then
        echo -e "${RED}Error: Failed to stop application${NC}"
        exit 1
    fi

    # Start the application with new images
    if ! docker compose -f "$app_path/docker-compose.yml" up -d; then
        echo -e "${RED}Error: Failed to start application with new images${NC}"
        exit 1
    fi

    echo -e "${GREEN}Application '$app' updated successfully${NC}"
}

# Main script logic
if [ $# -eq 0 ] || [ -z "$1" ]; then
    show_usage
    exit 0
fi

case "$1" in
    "list")
        list_apps
        ;;
    "start")
        if [ -z "$2" ]; then
            echo -e "${RED}Error: Application name is required${NC}"
            echo "Usage: dcm start <app_name>"
            exit 1
        fi
        start_app "$2"
        ;;
    "stop")
        if [ -z "$2" ]; then
            echo -e "${RED}Error: Application name is required${NC}"
            echo "Usage: dcm stop <app_name>"
            exit 1
        fi
        stop_app "$2"
        ;;
    "restart")
        if [ -z "$2" ]; then
            echo -e "${RED}Error: Application name is required${NC}"
            echo "Usage: dcm restart <app_name>"
            exit 1
        fi
        restart_app "$2"
        ;;
    "logs")
        if [ -z "$2" ]; then
            echo -e "${RED}Error: Application name is required${NC}"
            echo "Usage: dcm logs <app_name>"
            exit 1
        fi
        show_logs "$2"
        ;;
    "add")
        if [ -z "$2" ] || [ -z "$3" ]; then
            echo -e "${RED}Error: Application name and path are required${NC}"
            echo "Usage: dcm add <app_name> <path>"
            exit 1
        fi
        add_app "$2" "$3"
        ;;
    "remove")
        if [ -z "$2" ]; then
            echo -e "${RED}Error: Application name is required${NC}"
            echo "Usage: dcm remove <app_name>"
            exit 1
        fi
        remove_app "$2"
        ;;
    "backup")
        if [ -z "$2" ]; then
            echo -e "${RED}Error: Application name is required${NC}"
            echo "Usage: dcm backup <app_name>"
            exit 1
        fi
        backup_app "$2"
        ;;
    "restore")
        if [ -z "$2" ] || [ -z "$3" ]; then
            echo -e "${RED}Error: Application name and backup name are required${NC}"
            echo "Usage: dcm restore <app_name> <backup_name>"
            exit 1
        fi
        restore_app "$2" "$3"
        ;;
    "update")
        if [ -z "$2" ]; then
            echo -e "${RED}Error: Application name is required${NC}"
            echo "Usage: dcm update <app_name>"
            exit 1
        fi
        update_app "$2"
        ;;
    "status")
        if [ -z "$2" ]; then
            get_status
        else
            get_status "$2"
        fi
        ;;
    "info")
        if [ -z "$2" ]; then
            echo -e "${RED}Error: Application name is required${NC}"
            echo "Usage: dcm info <app_name>"
            exit 1
        fi
        get_app_info "$2"
        ;;
    "clone")
        if [ -z "$2" ] || [ -z "$3" ]; then
            echo -e "${RED}Error: Repository URL and application name are required${NC}"
            echo "Usage: dcm clone <repo_url> <app_name>"
            exit 1
        fi
        clone_app "$2" "$3"
        ;;
    "self-update")
        self_update
        ;;
    "help"|"-h"|"--help")
        show_usage
        ;;
    *)
        echo -e "${RED}Unknown command: $1${NC}"
        show_usage
        exit 1
        ;;
esac 