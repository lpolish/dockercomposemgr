#!/bin/bash

# Installation script for Docker Compose Manager

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Installation paths
INSTALL_DIR="/usr/local/bin"
SCRIPT_NAME="dcm"
REPO_URL="https://github.com/lpolish/dockercomposemgr.git"
TEMP_DIR="/tmp/dockercomposemgr_install"

# Function to display usage
show_usage() {
    echo "Docker Compose Manager Installer"
    echo "Usage: $0 [option]"
    echo ""
    echo "Options:"
    echo "  install     Install Docker Compose Manager"
    echo "  uninstall   Uninstall Docker Compose Manager"
    echo "  -h, --help  Show this help message"
}

# Function to check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}Error: This script must be run as root${NC}"
        exit 1
    fi
}

# Function to check prerequisites
check_prerequisites() {
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}Error: Docker is not installed${NC}"
        exit 1
    fi
    if ! command -v docker-compose &> /dev/null; then
        echo -e "${RED}Error: Docker Compose is not installed${NC}"
        exit 1
    fi
    if ! command -v git &> /dev/null; then
        echo -e "${RED}Error: Git is not installed${NC}"
        exit 1
    fi
}

# Function to install
install() {
    echo -e "${YELLOW}Installing Docker Compose Manager...${NC}"
    
    # Create temporary directory
    rm -rf "$TEMP_DIR"
    mkdir -p "$TEMP_DIR"
    
    # Clone repository
    echo "Cloning repository..."
    git clone "$REPO_URL" "$TEMP_DIR"
    
    # Copy files
    echo "Installing files..."
    cp "$TEMP_DIR/manage.sh" "$INSTALL_DIR/$SCRIPT_NAME"
    chmod +x "$INSTALL_DIR/$SCRIPT_NAME"
    
    # Create configuration directory
    mkdir -p "$HOME/.config/dockercomposemgr"
    cp -r "$TEMP_DIR/config" "$HOME/.config/dockercomposemgr/"
    cp -r "$TEMP_DIR/apps" "$HOME/.config/dockercomposemgr/"
    cp -r "$TEMP_DIR/logs" "$HOME/.config/dockercomposemgr/"
    
    # Cleanup
    rm -rf "$TEMP_DIR"
    
    echo -e "${GREEN}Installation complete!${NC}"
    echo "You can now use the 'dcm' command to manage your Docker Compose applications."
    echo "Run 'dcm --help' to see available commands."
}

# Function to uninstall
uninstall() {
    echo -e "${YELLOW}Uninstalling Docker Compose Manager...${NC}"
    
    # Remove binary
    rm -f "$INSTALL_DIR/$SCRIPT_NAME"
    
    # Remove configuration
    rm -rf "$HOME/.config/dockercomposemgr"
    
    echo -e "${GREEN}Uninstallation complete!${NC}"
}

# Main script logic
case "$1" in
    install)
        check_root
        check_prerequisites
        install
        ;;
    uninstall)
        check_root
        uninstall
        ;;
    -h|--help)
        show_usage
        ;;
    *)
        echo -e "${RED}Error: Unknown option${NC}"
        show_usage
        exit 1
        ;;
esac 