#!/bin/bash

# Docker Compose Manager Installer for Linux
# A command-line tool for managing Docker Compose applications

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

# Function to install Docker
install_docker() {
    echo -e "${BLUE}Installing Docker...${NC}"
    
    case $OS in
        "Ubuntu"|"Debian GNU/Linux")
            # Remove old versions
            apt-get remove -y docker docker-engine docker.io containerd runc || true
            
            # Update package index
            apt-get update
            
            # Install prerequisites
            apt-get install -y \
                apt-transport-https \
                ca-certificates \
                curl \
                gnupg \
                lsb-release \
                jq
            
            # Add Docker's official GPG key
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
            
            # Set up the stable repository
            echo \
                "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
                $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
            
            # Install Docker Engine
            apt-get update
            apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
            
            # Start Docker service
            systemctl start docker || true
            
            # Add current user to docker group if not in container
            if [ -z "$(cat /proc/1/cgroup | grep docker)" ]; then
                usermod -aG docker $SUDO_USER
            fi
            ;;
            
        "CentOS Linux"|"Red Hat Enterprise Linux")
            # Remove old versions
            yum remove -y docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine || true
            
            # Install prerequisites
            yum install -y yum-utils jq
            
            # Add Docker repository
            yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
            
            # Install Docker Engine
            yum install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
            
            # Start and enable Docker
            systemctl start docker || true
            systemctl enable docker || true
            
            # Add current user to docker group if not in container
            if [ -z "$(cat /proc/1/cgroup | grep docker)" ]; then
                usermod -aG docker $SUDO_USER
            fi
            ;;
            
        *)
            echo -e "${RED}Error: Unsupported Linux distribution${NC}"
            exit 1
            ;;
    esac
    
    # Verify Docker installation
    if ! docker info &> /dev/null; then
        echo -e "${RED}Error: Docker installation failed${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}Docker installed successfully${NC}"
}

# Function to create default configuration
create_default_config() {
    echo -e "${BLUE}Creating default configuration...${NC}"
    
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
    
    echo -e "${GREEN}Default configuration created successfully${NC}"
}

# Function to create apps directory structure
create_apps_directory() {
    echo -e "${BLUE}Creating apps directory structure...${NC}"
    
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
    echo -e "${BLUE}Installing Docker Compose Manager...${NC}"
    
    # Check if running as root
    check_root
    
    # Detect Linux distribution
    detect_distro
    
    # Install Docker and dependencies
    install_docker
    
    # Download management script
    echo -e "${BLUE}Downloading management script...${NC}"
    curl -fsSL https://raw.githubusercontent.com/lpolish/dockercomposemgr/main/manage.sh -o "$INSTALL_DIR/dcm"
    chmod +x "$INSTALL_DIR/dcm"
    
    # Create default configuration
    create_default_config
    
    # Create apps directory structure
    create_apps_directory
    
    echo -e "${GREEN}Docker Compose Manager installed successfully${NC}"
    echo -e "${YELLOW}Please log out and log back in for Docker group changes to take effect${NC}"
}

# Function to uninstall Docker Compose Manager
uninstall() {
    echo -e "${BLUE}Uninstalling Docker Compose Manager...${NC}"
    
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