#!/bin/bash

# Installation script for Docker Compose Manager

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Installation paths
DEFAULT_INSTALL_DIR="/usr/local/bin"
USER_INSTALL_DIR="$HOME/.local/bin"
SCRIPT_NAME="dcm"
REPO_URL="https://raw.githubusercontent.com/lpolish/dockercomposemgr/main"
TEMP_DIR="/tmp/dockercomposemgr_install"
CONFIG_DIR="$HOME/.config/dockercomposemgr"
DEFAULT_APPS_DIR="$HOME/dockerapps"

# Function to display usage
show_usage() {
    echo "Docker Compose Manager Installer"
    echo "Usage: bash <(curl -fsSL https://raw.githubusercontent.com/lpolish/dockercomposemgr/main/install.sh) [option]"
    echo "       ./install.sh [option]"
    echo ""
    echo "Options:"
    echo "  install     Install Docker Compose Manager"
    echo "  uninstall   Uninstall Docker Compose Manager"
    echo "  -h, --help  Show this help message"
}

# Function to check prerequisites
check_prerequisites() {
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}Error: Docker is not installed${NC}"
        exit 1
    fi
    if ! command -v docker compose &> /dev/null; then
        echo -e "${RED}Error: Docker Compose is not installed${NC}"
        exit 1
    fi
    if ! command -v curl &> /dev/null; then
        echo -e "${RED}Error: curl is not installed${NC}"
        exit 1
    fi
    if ! command -v jq &> /dev/null; then
        echo -e "${RED}Error: jq is not installed${NC}"
        exit 1
    fi
}

# Function to download file
download_file() {
    local url="$1"
    local output="$2"
    if ! curl -fsSL "$url" -o "$output"; then
        echo -e "${RED}Error: Failed to download $url${NC}"
        return 1
    fi
    return 0
}

# Function to create default configuration
create_default_config() {
    local config_file="$CONFIG_DIR/config.json"
    local apps_file="$CONFIG_DIR/apps.json"
    
    # Create config directory
    mkdir -p "$CONFIG_DIR/logs"
    
    # Create default config if it doesn't exist
    if [ ! -f "$config_file" ]; then
        cat > "$config_file" << EOF
{
    "version": "1.0.0",
    "apps_directory": "$DEFAULT_APPS_DIR",
    "log_level": "info",
    "log_retention_days": 30,
    "default_timeout": 300,
    "notifications": {
        "enabled": true,
        "on_start": true,
        "on_stop": true,
        "on_error": true
    },
    "backup": {
        "enabled": true,
        "directory": "$DEFAULT_APPS_DIR/backups",
        "retention_days": 7,
        "include_volumes": true
    },
    "update": {
        "check_interval_hours": 24,
        "auto_update": false
    }
}
EOF
    fi
    
    # Create apps registry if it doesn't exist
    if [ ! -f "$apps_file" ]; then
        cat > "$apps_file" << EOF
{
    "version": "1.0.0",
    "apps": {},
    "last_updated": null
}
EOF
    fi
}

# Function to create apps directory structure
create_apps_directory() {
    local apps_dir="$DEFAULT_APPS_DIR"
    
    # Create apps directory
    mkdir -p "$apps_dir/backups"
    
    # Create README if it doesn't exist
    if [ ! -f "$apps_dir/README.md" ]; then
        cat > "$apps_dir/README.md" << EOF
# Docker Apps Directory

This directory is where you'll store your Docker Compose applications. Each application should be in its own subdirectory.

## Directory Structure

\`\`\`
$apps_dir/
├── app1/                  # Application directory
│   ├── docker-compose.yml # Docker Compose configuration
│   ├── .env              # Environment variables (optional)
│   ├── data/             # Persistent data (if needed)
│   └── README.md         # Application documentation
├── app2/
│   └── ...
└── backups/              # Backup directory (managed by dcm)
\`\`\`

For more information, run: dcm --help
EOF
    fi
}

# Function to install
install() {
    echo -e "${YELLOW}Installing Docker Compose Manager...${NC}"
    
    # Create temporary directory
    rm -rf "$TEMP_DIR"
    mkdir -p "$TEMP_DIR"
    
    # Download required files
    echo "Downloading required files..."
    if ! download_file "$REPO_URL/manage.sh" "$TEMP_DIR/manage.sh"; then
        rm -rf "$TEMP_DIR"
        exit 1
    fi
    
    # Determine install location
    if [ "$EUID" -eq 0 ]; then
        INSTALL_DIR="$DEFAULT_INSTALL_DIR"
    else
        INSTALL_DIR="$USER_INSTALL_DIR"
        mkdir -p "$INSTALL_DIR"
    fi
    
    # Install the script
    echo "Installing files to $INSTALL_DIR..."
    if ! cp "$TEMP_DIR/manage.sh" "$INSTALL_DIR/$SCRIPT_NAME"; then
        echo -e "${RED}Error: Failed to copy files${NC}"
        rm -rf "$TEMP_DIR"
        exit 1
    fi
    chmod +x "$INSTALL_DIR/$SCRIPT_NAME"
    
    # Create configuration and apps directory structure
    create_default_config
    create_apps_directory
    
    # Cleanup
    rm -rf "$TEMP_DIR"
    
    echo -e "${GREEN}Installation complete!${NC}"
    echo "You can now use the 'dcm' command to manage your Docker Compose applications."
    echo "Run 'dcm --help' to see available commands."
    
    # Check if user bin is in PATH
    if [ "$INSTALL_DIR" = "$USER_INSTALL_DIR" ]; then
        case ":$PATH:" in
            *":$USER_INSTALL_DIR:"*) :;;
            *)
                echo -e "${YELLOW}Warning: $USER_INSTALL_DIR is not in your PATH.${NC}"
                echo "Add the following line to your shell profile (e.g., ~/.bashrc):"
                echo "  export PATH=\"$USER_INSTALL_DIR:\$PATH\""
                ;;
        esac
    fi
}

# Function to uninstall
uninstall() {
    echo -e "${YELLOW}Uninstalling Docker Compose Manager...${NC}"
    
    # Remove binary from both locations
    rm -f "$DEFAULT_INSTALL_DIR/$SCRIPT_NAME"
    rm -f "$USER_INSTALL_DIR/$SCRIPT_NAME"
    
    # Remove configuration
    rm -rf "$CONFIG_DIR"
    
    echo -e "${GREEN}Uninstallation complete!${NC}"
    echo "Note: Your Docker applications in $DEFAULT_APPS_DIR were not removed."
    echo "To remove them, delete the directory manually: rm -rf $DEFAULT_APPS_DIR"
}

# Check if script is being piped
if [ -t 0 ]; then
    # Interactive mode
    case "$1" in
        install)
            check_prerequisites
            install
            ;;
        uninstall)
            uninstall
            ;;
        -h|--help)
            show_usage
            ;;
        "")
            # Default to install if no argument is given
            check_prerequisites
            install
            ;;
        *)
            echo -e "${RED}Error: Unknown option${NC}"
            show_usage
            exit 1
            ;;
    esac
else
    # Piped mode - always install
    check_prerequisites
    install
fi 