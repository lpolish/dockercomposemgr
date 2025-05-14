#!/bin/bash

# Docker Compose Manager Uninstaller for Linux
# A command-line tool for uninstalling Docker Compose Manager

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Installation paths
if [ "$EUID" -eq 0 ]; then
    # Root installation
    INSTALL_DIR="/usr/local/bin"
    CONFIG_DIR="/etc/dockercomposemgr"
    DEFAULT_APPS_DIR="/opt/dockerapps"
else
    # User installation
    INSTALL_DIR="$HOME/.local/bin"
    CONFIG_DIR="$HOME/.config/dockercomposemgr"
    DEFAULT_APPS_DIR="$HOME/dockerapps"
fi

# Function to display usage
show_usage() {
    echo "Docker Compose Manager Uninstaller"
    echo "Usage: curl -fsSL https://raw.githubusercontent.com/lpolish/dockercomposemgr/main/uninstall.sh | bash"
    echo ""
    echo "This script will remove Docker Compose Manager from your system."
    echo "Your Docker applications in $DEFAULT_APPS_DIR will not be affected."
}

# Function to uninstall
uninstall() {
    echo -e "${CYAN}Uninstalling Docker Compose Manager...${NC}"
    
    # Remove management script
    if [ -f "$INSTALL_DIR/dcm" ]; then
        rm -f "$INSTALL_DIR/dcm"
        echo -e "${GREEN}Removed management script${NC}"
    fi
    
    # Remove configuration directory
    if [ -d "$CONFIG_DIR" ]; then
        rm -rf "$CONFIG_DIR"
        echo -e "${GREEN}Removed configuration directory${NC}"
    fi
    
    echo -e "${GREEN}Docker Compose Manager uninstalled successfully${NC}"
    echo -e "${YELLOW}Note: Docker applications in $DEFAULT_APPS_DIR were not removed${NC}"
}

# Main script logic
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    show_usage
    exit 0
fi

# Confirm uninstallation
echo -e "${YELLOW}This will remove Docker Compose Manager from your system.${NC}"
echo -e "${YELLOW}Your Docker applications in $DEFAULT_APPS_DIR will not be affected.${NC}"
read -p "Do you want to continue? [y/N] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${RED}Uninstallation cancelled${NC}"
    exit 1
fi

uninstall 