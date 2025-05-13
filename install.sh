#!/bin/bash

# Docker Compose Manager Installer for Linux
# A command-line tool for managing Docker Compose applications

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Installation paths
INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="$HOME/.config/dockercomposemgr"
DEFAULT_APPS_DIR="$HOME/dockerapps"

# Function to display usage
show_usage() {
    echo "Docker Compose Manager Installer"
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -u, --uninstall Remove Docker Compose Manager"
}

# Function to check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}Error: This script needs to be run as root${NC}"
        echo "Please run: sudo $0"
        exit 1
    fi
}

# Function to detect Linux distribution
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
    else
        echo -e "${RED}Error: Could not detect Linux distribution${NC}"
        exit 1
    fi
}

# Function to download a file using curl or wget
download_file() {
    local url=$1
    local output=$2
    
    if command -v curl &> /dev/null; then
        curl -fsSL "$url" -o "$output"
    elif command -v wget &> /dev/null; then
        wget -q "$url" -O "$output"
    else
        echo -e "${RED}Error: Neither curl nor wget is installed${NC}"
        echo "Please install either curl or wget and try again"
        exit 1
    fi
}

# Function to check requirements
check_requirements() {
    local missing=0
    echo -e "${CYAN}Checking requirements...${NC}"

    if ! command -v docker &> /dev/null; then
        echo -e "${RED}Docker is not installed.${NC}"
        missing=1
    fi
    if ! docker compose version &> /dev/null; then
        echo -e "${RED}Docker Compose is not available (docker compose plugin missing).${NC}"
        missing=1
    fi
    if ! command -v jq &> /dev/null; then
        echo -e "${RED}jq is not installed.${NC}"
        missing=1
    fi
    if ! command -v curl &> /dev/null && ! command -v wget &> /dev/null; then
        echo -e "${RED}Neither curl nor wget is installed.${NC}"
        missing=1
    fi

    if [ $missing -eq 1 ]; then
        echo -e "${YELLOW}Please install the missing requirements and re-run the installer.${NC}"
        echo "Required: docker, docker compose, jq, and either curl or wget."
        exit 1
    fi
    echo -e "${GREEN}All requirements satisfied.${NC}"
}

# Function to create default configuration
create_default_config() {
    echo -e "${CYAN}Creating default configuration...${NC}"
    
    # Create config directory
    mkdir -p "$CONFIG_DIR"
    
    # Create config.json if it doesn't exist
    if [ ! -f "$CONFIG_DIR/config.json" ]; then
        cat > "$CONFIG_DIR/config.json" << EOF
{
    "apps_directory": "$DEFAULT_APPS_DIR",
    "log_level": "info",
    "log_retention_days": 7,
    "backup": {
        "include_volumes": true,
        "retention_days": 30
    }
}
EOF
    fi
    
    # Create apps.json if it doesn't exist
    if [ ! -f "$CONFIG_DIR/apps.json" ]; then
        cat > "$CONFIG_DIR/apps.json" << EOF
{
    "apps": {}
}
EOF
    fi

    # Ensure proper permissions
    chown -R $SUDO_USER:$SUDO_USER "$CONFIG_DIR"
    chmod 755 "$CONFIG_DIR"
    chmod 644 "$CONFIG_DIR"/*.json
    
    echo -e "${GREEN}Default configuration created successfully${NC}"
}

# Function to create apps directory structure
create_apps_directory() {
    echo -e "${CYAN}Creating apps directory structure...${NC}"
    
    # Create apps directory
    mkdir -p "$DEFAULT_APPS_DIR/backups"
    
    # Create README if it doesn't exist
    if [ ! -f "$DEFAULT_APPS_DIR/README.md" ]; then
        cat > "$DEFAULT_APPS_DIR/README.md" << EOF
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

## Managing Applications

Use the \`dcm\` command to manage your applications:

\`\`\`bash
# List all applications
dcm list

# Start an application
dcm start app_name

# Stop an application
dcm stop app_name

# View application logs
dcm logs app_name

# Add a new application
dcm add app_name /path/to/docker-compose.yml

# Remove an application
dcm remove app_name
\`\`\`
EOF
    fi
    
    echo -e "${GREEN}Apps directory structure created successfully${NC}"
}

# Function to install Docker Compose Manager
install() {
    echo -e "${CYAN}Installing Docker Compose Manager...${NC}"

    # Check requirements
    check_requirements

    # Download management script
    echo -e "${CYAN}Downloading management script...${NC}"
    download_file "https://raw.githubusercontent.com/lpolish/dockercomposemgr/main/manage.sh" "$INSTALL_DIR/dcm"
    chmod +x "$INSTALL_DIR/dcm"

    # Create default configuration
    create_default_config

    # Create apps directory structure
    create_apps_directory

    echo -e "${GREEN}Docker Compose Manager installed successfully${NC}"
    echo -e "${YELLOW}You can now use the 'dcm' command to manage your Docker Compose applications${NC}"
}

# Function to uninstall Docker Compose Manager
uninstall() {
    echo -e "${CYAN}Uninstalling Docker Compose Manager...${NC}"
    
    # Check if running as root
    check_root
    
    # Remove management script
    rm -f "$INSTALL_DIR/dcm"
    
    # Remove configuration directory
    rm -rf "$CONFIG_DIR"
    
    echo -e "${GREEN}Docker Compose Manager uninstalled successfully${NC}"
    echo -e "${YELLOW}Note: Docker applications in $DEFAULT_APPS_DIR were not removed${NC}"
}

# Main script logic
case "$1" in
    -h|--help)
        show_usage
        ;;
    -u|--uninstall)
        uninstall
        ;;
    *)
        install
        ;;
esac 