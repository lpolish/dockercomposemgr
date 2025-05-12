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

    # Load apps configuration
    if [ ! -f "$APPS_FILE" ]; then
        echo "{}" > "$APPS_FILE"
    fi
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

    if [ ! -f "$app_path/docker-compose.yml" ]; then
        echo -e "${RED}Error: docker-compose.yml not found in specified path${NC}"
        exit 1
    fi

    # Create application directory
    mkdir -p "$APPS_DIR/$app_name"

    # Store application path in config
    local config=$(cat "$APPS_FILE")
    config=$(echo "$config" | jq --arg app "$app_name" --arg path "$app_path" '.apps[$app] = {"path": $path}')
    echo "$config" > "$APPS_FILE"

    # Copy README.md if it exists
    if [ -f "$app_path/README.md" ]; then
        cp "$app_path/README.md" "$APPS_DIR/$app_name/"
    fi

    echo -e "${GREEN}Application '$app_name' added successfully${NC}"
}

# Function to clone and add application
clone_app() {
    local repo_url=$1
    local app_name=$2

    if [ -z "$repo_url" ] || [ -z "$app_name" ]; then
        echo -e "${RED}Error: Repository URL and application name required${NC}"
        echo "Usage: dcm clone <repo_url> <app_name>"
        exit 1
    fi

    # Create temporary directory
    local temp_dir=$(mktemp -d)
    
    echo "Cloning repository..."
    if ! git clone "$repo_url" "$temp_dir"; then
        echo -e "${RED}Error: Failed to clone repository${NC}"
        rm -rf "$temp_dir"
        exit 1
    fi

    # Check if docker-compose.yml exists
    if [ ! -f "$temp_dir/docker-compose.yml" ]; then
        echo -e "${RED}Error: Repository does not contain a docker-compose.yml file${NC}"
        rm -rf "$temp_dir"
        exit 1
    fi

    # Create application directory
    mkdir -p "$APPS_DIR/$app_name"

    # Store application path in config
    local config=$(cat "$APPS_FILE")
    config=$(echo "$config" | jq --arg app "$app_name" --arg path "$temp_dir" '.apps[$app] = {"path": $path}')
    echo "$config" > "$APPS_FILE"

    # Copy README.md if it exists
    if [ -f "$temp_dir/README.md" ]; then
        cp "$temp_dir/README.md" "$APPS_DIR/$app_name/"
    fi

    echo -e "${GREEN}Application '$app_name' cloned and added successfully${NC}"
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

    echo -e "${BLUE}=== Detailed Information for $app ===${NC}"
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

# Function to clone and add application
clone_app() {
    local repo_url=$1
    local app_name=$2

    if [ -z "$repo_url" ] || [ -z "$app_name" ]; then
        echo -e "${RED}Error: Repository URL and application name required${NC}"
        echo "Usage: dcm clone <repo_url> <app_name>"
        exit 1
    fi

    # Create temporary directory
    local temp_dir=$(mktemp -d)
    
    echo "Cloning repository..."
    if ! git clone "$repo_url" "$temp_dir"; then
        echo -e "${RED}Error: Failed to clone repository${NC}"
        rm -rf "$temp_dir"
        exit 1
    fi

    # Check if docker-compose.yml exists
    if [ ! -f "$temp_dir/docker-compose.yml" ]; then
        echo -e "${RED}Error: Repository does not contain a docker-compose.yml file${NC}"
        rm -rf "$temp_dir"
        exit 1
    fi

    # Create application directory
    mkdir -p "$APPS_DIR/$app_name"

    # Create symbolic links for docker-compose.yml and .env if it exists
    ln -sf "$temp_dir/docker-compose.yml" "$APPS_DIR/$app_name/docker-compose.yml"
    if [ -f "$temp_dir/.env" ]; then
        ln -sf "$temp_dir/.env" "$APPS_DIR/$app_name/.env"
    fi

    # Copy any other relevant files (README.md, etc.)
    if [ -f "$temp_dir/README.md" ]; then
        cp "$temp_dir/README.md" "$APPS_DIR/$app_name/"
    fi

    # Cleanup
    rm -rf "$temp_dir"

    echo -e "${GREEN}Application '$app_name' cloned and added successfully${NC}"
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
        ln -sf "$3/docker-compose.yml" "$APPS_DIR/$2/docker-compose.yml"
        if [ -f "$3/.env" ]; then
            ln -sf "$3/.env" "$APPS_DIR/$2/.env"
        fi
        echo -e "${GREEN}Application '$2' added successfully${NC}"
        ;;
    clone)
        clone_app "$2" "$3"
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