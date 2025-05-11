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
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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
}

# Function to display usage
show_usage() {
    echo "Docker Compose Manager"
    echo "Usage: dcm [command] [options]"
    echo ""
    echo "Commands:"
    echo "  list                    List all managed applications"
    echo "  status [app]           Show status of all or specific application"
    echo "  info [app]             Show detailed information about application"
    echo "  start [app]            Start all or specific application"
    echo "  stop [app]             Stop all or specific application"
    echo "  restart [app]          Restart all or specific application"
    echo "  logs [app]             Show logs for all or specific application"
    echo "  add <name> <path>      Add new application to manage"
    echo "  remove <app>           Remove application from management"
    echo "  update [app]           Update all or specific application"
    echo "  backup [app]           Backup application data and volumes"
    echo "  restore <app> <backup> Restore application from backup"
    echo "  create                 Create a new application from template"
    echo ""
    echo "Options:"
    echo "  -h, --help             Show this help message"
}

# Function to check if Docker is installed
check_docker() {
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}Error: Docker is not installed${NC}"
        exit 1
    fi
    if ! command -v docker compose &> /dev/null; then
        echo -e "${RED}Error: Docker Compose is not installed${NC}"
        exit 1
    fi
    if ! command -v jq &> /dev/null; then
        echo -e "${RED}Error: jq is not installed${NC}"
        exit 1
    fi
}

# Function to check if git is installed
check_git() {
    if ! command -v git &> /dev/null; then
        echo -e "${YELLOW}Git is not installed. Would you like to install it? (y/n)${NC}"
        read -r install_git
        if [ "$install_git" = "y" ] || [ "$install_git" = "Y" ]; then
            if command -v apt-get &> /dev/null; then
                sudo apt-get update && sudo apt-get install -y git
            elif command -v yum &> /dev/null; then
                sudo yum install -y git
            else
                echo -e "${RED}Error: Could not install git. Please install it manually.${NC}"
                exit 1
            fi
        else
            echo -e "${RED}Error: Git is required for creating new applications${NC}"
            exit 1
        fi
    fi
}

# Function to list all managed applications
list_apps() {
    if [ -z "$(ls -A "$APPS_DIR")" ]; then
        echo "No applications are currently being managed."
        return
    fi
    
    echo "Managed Applications:"
    echo "-------------------"
    for app in "$APPS_DIR"/*; do
        if [ -d "$app" ] && [ -f "$app/docker-compose.yml" ]; then
            app_name=$(basename "$app")
            echo "- $app_name"
        fi
    done
}

# Function to get application status
get_status() {
    local app=$1
    if [ -z "$app" ]; then
        for app_dir in "$APPS_DIR"/*; do
            if [ -d "$app_dir" ] && [ -f "$app_dir/docker-compose.yml" ]; then
                app_name=$(basename "$app_dir")
                echo "Checking $app_name..."
                docker compose -f "$app_dir/docker-compose.yml" ps
            fi
        done
    else
        if [ -d "$APPS_DIR/$app" ] && [ -f "$APPS_DIR/$app/docker-compose.yml" ]; then
            docker compose -f "$APPS_DIR/$app/docker-compose.yml" ps
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

    if [ ! -d "$APPS_DIR/$app" ] || [ ! -f "$APPS_DIR/$app/docker-compose.yml" ]; then
        echo -e "${RED}Error: Application '$app' not found${NC}"
        exit 1
    fi

    echo -e "${BLUE}=== Detailed Information for $app ===${NC}"
    echo

    # Get container status
    echo -e "${YELLOW}Container Status:${NC}"
    docker compose -f "$APPS_DIR/$app/docker-compose.yml" ps
    echo

    # Get container resource usage
    echo -e "${YELLOW}Resource Usage:${NC}"
    echo "CPU and Memory usage for each container:"
    for container in $(docker compose -f "$APPS_DIR/$app/docker-compose.yml" ps -q); do
        echo -e "${GREEN}Container: $(docker inspect --format '{{.Name}}' $container)${NC}"
        docker stats --no-stream $container
    done
    echo

    # Get network information
    echo -e "${YELLOW}Network Information:${NC}"
    docker compose -f "$APPS_DIR/$app/docker-compose.yml" network ls
    echo

    # Get volume information
    echo -e "${YELLOW}Volume Information:${NC}"
    docker compose -f "$APPS_DIR/$app/docker-compose.yml" volume ls
    echo

    # Get environment variables
    echo -e "${YELLOW}Environment Configuration:${NC}"
    docker compose -f "$APPS_DIR/$app/docker-compose.yml" config
    echo

    # Get recent logs
    echo -e "${YELLOW}Recent Logs (last 5 lines):${NC}"
    docker compose -f "$APPS_DIR/$app/docker-compose.yml" logs --tail=5
    echo

    # Get health status
    echo -e "${YELLOW}Health Status:${NC}"
    for container in $(docker compose -f "$APPS_DIR/$app/docker-compose.yml" ps -q); do
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
    
    echo -e "${BLUE}=== Create New Application ===${NC}"
    
    # Get available templates
    local templates
    templates=$(get_available_templates)
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error: Could not fetch templates. Please check your internet connection.${NC}"
        exit 1
    fi
    
    # Display available templates
    echo "Available templates:"
    local i=1
    declare -A template_list
    while IFS= read -r template_id; do
        template_list[$i]=$template_id
        local name=$(echo "$templates" | jq -r ".templates.$template_id.name")
        local description=$(echo "$templates" | jq -r ".templates.$template_id.description")
        local tags=$(echo "$templates" | jq -r ".templates.$template_id.tags[]" | tr '\n' ', ' | sed 's/, $//')
        
        echo "$i. $name"
        echo "   $description"
        echo "   Tags: $tags"
        echo ""
        ((i++))
    done < <(echo "$templates" | jq -r '.templates | keys[]')
    
    read -rp "Select template (1-$((i-1))): " template_choice
    
    if [ -z "${template_list[$template_choice]}" ]; then
        echo -e "${RED}Invalid template choice${NC}"
        exit 1
    fi
    
    local template_id=${template_list[$template_choice]}
    
    read -rp "Enter application name: " app_name
    read -rp "Enter application description: " app_description
    
    # Create application directory
    app_dir="$APPS_DIR/$app_name"
    if [ -d "$app_dir" ]; then
        echo -e "${RED}Error: Application directory already exists${NC}"
        exit 1
    fi
    
    # Download template
    echo "Downloading template..."
    if ! download_template "$template_id" "$app_dir"; then
        echo -e "${RED}Error: Failed to download template${NC}"
        exit 1
    fi
    
    # Initialize git repository
    cd "$app_dir" || exit 1
    git init
    
    # Update package.json or requirements.txt with app name and description
    if [ "$template_id" = "nodejs" ] || [ "$template_id" = "nextjs" ]; then
        sed -i "s/\"name\": \"nodejs-app\"/\"name\": \"$app_name\"/" package.json
        sed -i "s/\"description\": \".*\"/\"description\": \"$app_description\"/" package.json
    elif [ "$template_id" = "fastapi" ]; then
        echo "# $app_name" > README.md
        echo "$app_description" >> README.md
    fi
    
    # Create .gitignore
    cat > .gitignore << EOL
node_modules/
.next/
__pycache__/
*.pyc
.env
.DS_Store
dist/
build/
*.log
EOL
    
    # Initial commit
    git add .
    git commit -m "Initial commit: $app_name"
    
    echo -e "${GREEN}Application '$app_name' created successfully!${NC}"
    echo -e "Directory: $app_dir"
    echo -e "To start the application, run: dcm start $app_name"
}

# Main script logic
check_docker
load_config

case "$1" in
    list)
        list_apps
        ;;
    status)
        get_status "$2"
        ;;
    info)
        get_app_info "$2"
        ;;
    start)
        if [ -z "$2" ]; then
            for app_dir in "$APPS_DIR"/*; do
                if [ -d "$app_dir" ] && [ -f "$app_dir/docker-compose.yml" ]; then
                    app_name=$(basename "$app_dir")
                    echo "Starting $app_name..."
                    docker compose -f "$app_dir/docker-compose.yml" up -d
                fi
            done
        else
            if [ -d "$APPS_DIR/$2" ] && [ -f "$APPS_DIR/$2/docker-compose.yml" ]; then
                docker compose -f "$APPS_DIR/$2/docker-compose.yml" up -d
            else
                echo -e "${RED}Error: Application '$2' not found${NC}"
                exit 1
            fi
        fi
        ;;
    stop)
        if [ -z "$2" ]; then
            for app_dir in "$APPS_DIR"/*; do
                if [ -d "$app_dir" ] && [ -f "$app_dir/docker-compose.yml" ]; then
                    app_name=$(basename "$app_dir")
                    echo "Stopping $app_name..."
                    docker compose -f "$app_dir/docker-compose.yml" down
                fi
            done
        else
            if [ -d "$APPS_DIR/$2" ] && [ -f "$APPS_DIR/$2/docker-compose.yml" ]; then
                docker compose -f "$APPS_DIR/$2/docker-compose.yml" down
            else
                echo -e "${RED}Error: Application '$2' not found${NC}"
                exit 1
            fi
        fi
        ;;
    restart)
        if [ -z "$2" ]; then
            for app_dir in "$APPS_DIR"/*; do
                if [ -d "$app_dir" ] && [ -f "$app_dir/docker-compose.yml" ]; then
                    app_name=$(basename "$app_dir")
                    echo "Restarting $app_name..."
                    docker compose -f "$app_dir/docker-compose.yml" restart
                fi
            done
        else
            if [ -d "$APPS_DIR/$2" ] && [ -f "$APPS_DIR/$2/docker-compose.yml" ]; then
                docker compose -f "$APPS_DIR/$2/docker-compose.yml" restart
            else
                echo -e "${RED}Error: Application '$2' not found${NC}"
                exit 1
            fi
        fi
        ;;
    logs)
        if [ -z "$2" ]; then
            for app_dir in "$APPS_DIR"/*; do
                if [ -d "$app_dir" ] && [ -f "$app_dir/docker-compose.yml" ]; then
                    app_name=$(basename "$app_dir")
                    echo "Logs for $app_name:"
                    docker compose -f "$app_dir/docker-compose.yml" logs
                fi
            done
        else
            if [ -d "$APPS_DIR/$2" ] && [ -f "$APPS_DIR/$2/docker-compose.yml" ]; then
                docker compose -f "$APPS_DIR/$2/docker-compose.yml" logs
            else
                echo -e "${RED}Error: Application '$2' not found${NC}"
                exit 1
            fi
        fi
        ;;
    add)
        if [ -z "$2" ] || [ -z "$3" ]; then
            echo -e "${RED}Error: Application name and path required${NC}"
            echo "Usage: dcm add <name> <path>"
            exit 1
        fi
        if [ ! -f "$3/docker-compose.yml" ]; then
            echo -e "${RED}Error: docker-compose.yml not found in specified path${NC}"
            exit 1
        fi
        mkdir -p "$APPS_DIR/$2"
        cp "$3/docker-compose.yml" "$APPS_DIR/$2/"
        if [ -f "$3/.env" ]; then
            cp "$3/.env" "$APPS_DIR/$2/"
        fi
        echo -e "${GREEN}Application '$2' added successfully${NC}"
        ;;
    remove)
        if [ -z "$2" ]; then
            echo -e "${RED}Error: Application name required${NC}"
            echo "Usage: dcm remove <app>"
            exit 1
        fi
        if [ -d "$APPS_DIR/$2" ]; then
            rm -rf "$APPS_DIR/$2"
            echo -e "${GREEN}Application '$2' removed successfully${NC}"
        else
            echo -e "${RED}Error: Application '$2' not found${NC}"
            exit 1
        fi
        ;;
    update)
        if [ -z "$2" ]; then
            for app_dir in "$APPS_DIR"/*; do
                if [ -d "$app_dir" ] && [ -f "$app_dir/docker-compose.yml" ]; then
                    app_name=$(basename "$app_dir")
                    echo "Updating $app_name..."
                    docker compose -f "$app_dir/docker-compose.yml" pull
                    docker compose -f "$app_dir/docker-compose.yml" up -d
                fi
            done
        else
            if [ -d "$APPS_DIR/$2" ] && [ -f "$APPS_DIR/$2/docker-compose.yml" ]; then
                docker compose -f "$APPS_DIR/$2/docker-compose.yml" pull
                docker compose -f "$APPS_DIR/$2/docker-compose.yml" up -d
            else
                echo -e "${RED}Error: Application '$2' not found${NC}"
                exit 1
            fi
        fi
        ;;
    backup)
        backup_app "$2"
        ;;
    restore)
        restore_app "$2" "$3"
        ;;
    create)
        create_app
        ;;
    -h|--help)
        show_usage
        ;;
    *)
        echo -e "${RED}Error: Unknown command${NC}"
        show_usage
        exit 1
        ;;
esac 