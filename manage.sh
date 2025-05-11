#!/bin/bash

# Docker Compose Manager for Ubuntu
# A command-line tool for managing Docker Compose applications

# Configuration
CONFIG_DIR="./config"
APPS_DIR="./apps"
LOG_DIR="./logs"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Ensure required directories exist
mkdir -p "$CONFIG_DIR" "$APPS_DIR" "$LOG_DIR"

# Function to display usage
show_usage() {
    echo "Docker Compose Manager"
    echo "Usage: $0 [command] [options]"
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
    if ! command -v docker-compose &> /dev/null; then
        echo -e "${RED}Error: Docker Compose is not installed${NC}"
        exit 1
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
        if [ -d "$app" ]; then
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
            if [ -d "$app_dir" ]; then
                app_name=$(basename "$app_dir")
                echo "Checking $app_name..."
                docker-compose -f "$app_dir/docker-compose.yml" ps
            fi
        done
    else
        if [ -d "$APPS_DIR/$app" ]; then
            docker-compose -f "$APPS_DIR/$app/docker-compose.yml" ps
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
        echo "Usage: $0 info <app>"
        exit 1
    fi

    if [ ! -d "$APPS_DIR/$app" ]; then
        echo -e "${RED}Error: Application '$app' not found${NC}"
        exit 1
    fi

    echo -e "${BLUE}=== Detailed Information for $app ===${NC}"
    echo

    # Get container status
    echo -e "${YELLOW}Container Status:${NC}"
    docker-compose -f "$APPS_DIR/$app/docker-compose.yml" ps
    echo

    # Get container resource usage
    echo -e "${YELLOW}Resource Usage:${NC}"
    echo "CPU and Memory usage for each container:"
    for container in $(docker-compose -f "$APPS_DIR/$app/docker-compose.yml" ps -q); do
        echo -e "${GREEN}Container: $(docker inspect --format '{{.Name}}' $container)${NC}"
        docker stats --no-stream $container
    done
    echo

    # Get network information
    echo -e "${YELLOW}Network Information:${NC}"
    docker-compose -f "$APPS_DIR/$app/docker-compose.yml" network ls
    echo

    # Get volume information
    echo -e "${YELLOW}Volume Information:${NC}"
    docker-compose -f "$APPS_DIR/$app/docker-compose.yml" volume ls
    echo

    # Get environment variables
    echo -e "${YELLOW}Environment Configuration:${NC}"
    docker-compose -f "$APPS_DIR/$app/docker-compose.yml" config
    echo

    # Get recent logs
    echo -e "${YELLOW}Recent Logs (last 5 lines):${NC}"
    docker-compose -f "$APPS_DIR/$app/docker-compose.yml" logs --tail=5
    echo

    # Get health status
    echo -e "${YELLOW}Health Status:${NC}"
    for container in $(docker-compose -f "$APPS_DIR/$app/docker-compose.yml" ps -q); do
        health=$(docker inspect --format='{{.State.Health.Status}}' $container 2>/dev/null)
        if [ ! -z "$health" ]; then
            echo -e "${GREEN}Container: $(docker inspect --format '{{.Name}}' $container)${NC}"
            echo "Health: $health"
        fi
    done
}

# Main script logic
check_docker

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
                if [ -d "$app_dir" ]; then
                    app_name=$(basename "$app_dir")
                    echo "Starting $app_name..."
                    docker-compose -f "$app_dir/docker-compose.yml" up -d
                fi
            done
        else
            if [ -d "$APPS_DIR/$2" ]; then
                docker-compose -f "$APPS_DIR/$2/docker-compose.yml" up -d
            else
                echo -e "${RED}Error: Application '$2' not found${NC}"
                exit 1
            fi
        fi
        ;;
    stop)
        if [ -z "$2" ]; then
            for app_dir in "$APPS_DIR"/*; do
                if [ -d "$app_dir" ]; then
                    app_name=$(basename "$app_dir")
                    echo "Stopping $app_name..."
                    docker-compose -f "$app_dir/docker-compose.yml" down
                fi
            done
        else
            if [ -d "$APPS_DIR/$2" ]; then
                docker-compose -f "$APPS_DIR/$2/docker-compose.yml" down
            else
                echo -e "${RED}Error: Application '$2' not found${NC}"
                exit 1
            fi
        fi
        ;;
    restart)
        if [ -z "$2" ]; then
            for app_dir in "$APPS_DIR"/*; do
                if [ -d "$app_dir" ]; then
                    app_name=$(basename "$app_dir")
                    echo "Restarting $app_name..."
                    docker-compose -f "$app_dir/docker-compose.yml" restart
                fi
            done
        else
            if [ -d "$APPS_DIR/$2" ]; then
                docker-compose -f "$APPS_DIR/$2/docker-compose.yml" restart
            else
                echo -e "${RED}Error: Application '$2' not found${NC}"
                exit 1
            fi
        fi
        ;;
    logs)
        if [ -z "$2" ]; then
            for app_dir in "$APPS_DIR"/*; do
                if [ -d "$app_dir" ]; then
                    app_name=$(basename "$app_dir")
                    echo "Logs for $app_name:"
                    docker-compose -f "$app_dir/docker-compose.yml" logs
                fi
            done
        else
            if [ -d "$APPS_DIR/$2" ]; then
                docker-compose -f "$APPS_DIR/$2/docker-compose.yml" logs
            else
                echo -e "${RED}Error: Application '$2' not found${NC}"
                exit 1
            fi
        fi
        ;;
    add)
        if [ -z "$2" ] || [ -z "$3" ]; then
            echo -e "${RED}Error: Application name and path required${NC}"
            echo "Usage: $0 add <name> <path>"
            exit 1
        fi
        if [ ! -f "$3/docker-compose.yml" ]; then
            echo -e "${RED}Error: docker-compose.yml not found in specified path${NC}"
            exit 1
        fi
        mkdir -p "$APPS_DIR/$2"
        cp "$3/docker-compose.yml" "$APPS_DIR/$2/"
        echo -e "${GREEN}Application '$2' added successfully${NC}"
        ;;
    remove)
        if [ -z "$2" ]; then
            echo -e "${RED}Error: Application name required${NC}"
            echo "Usage: $0 remove <app>"
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
                if [ -d "$app_dir" ]; then
                    app_name=$(basename "$app_dir")
                    echo "Updating $app_name..."
                    docker-compose -f "$app_dir/docker-compose.yml" pull
                    docker-compose -f "$app_dir/docker-compose.yml" up -d
                fi
            done
        else
            if [ -d "$APPS_DIR/$2" ]; then
                docker-compose -f "$APPS_DIR/$2/docker-compose.yml" pull
                docker-compose -f "$APPS_DIR/$2/docker-compose.yml" up -d
            else
                echo -e "${RED}Error: Application '$2' not found${NC}"
                exit 1
            fi
        fi
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