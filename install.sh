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

# Check if running in non-interactive mode
if [ -t 0 ]; then
    INTERACTIVE=1
else
    INTERACTIVE=0
fi

# Function to display usage
show_usage() {
    echo "Docker Compose Manager Installer"
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -u, --uninstall Remove Docker Compose Manager"
    echo "  -y, --yes      Non-interactive mode, install everything"
    echo "  --update       Update Docker Compose Manager to the latest version"
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

# Function to install Docker on Ubuntu/Debian
install_docker_ubuntu() {
    echo -e "${CYAN}Installing Docker on Ubuntu/Debian...${NC}"
    
    # Remove old versions
    apt-get remove -y docker docker-engine docker.io containerd runc || true
    
    # Update package index
    apt-get update
    
    # Install prerequisites
    apt-get install -y \
        apt-transport-https \
        ca-certificates \
        gnupg \
        lsb-release
    
    # Add Docker's official GPG key
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    
    # Set up the repository
    echo \
        "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
        "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
        tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker Engine
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Start and enable Docker
    systemctl start docker
    systemctl enable docker
    
    # Add current user to docker group
    usermod -aG docker $SUDO_USER
    
    echo -e "${GREEN}Docker installed successfully${NC}"
    echo -e "${YELLOW}Please log out and log back in for Docker group changes to take effect${NC}"
}

# Function to install Docker on CentOS/RHEL
install_docker_centos() {
    echo -e "${CYAN}Installing Docker on CentOS/RHEL...${NC}"
    
    # Remove old versions
    yum remove -y docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine || true
    
    # Install prerequisites
    yum install -y yum-utils
    
    # Add Docker repository
    yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    
    # Install Docker Engine
    yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Start and enable Docker
    systemctl start docker
    systemctl enable docker
    
    # Add current user to docker group
    usermod -aG docker $SUDO_USER
    
    echo -e "${GREEN}Docker installed successfully${NC}"
    echo -e "${YELLOW}Please log out and log back in for Docker group changes to take effect${NC}"
}

# Function to install jq
install_jq() {
    echo -e "${CYAN}Installing jq...${NC}"
    
    case $OS in
        "Ubuntu"|"Debian GNU/Linux")
            apt-get update
            apt-get install -y jq
            ;;
        "CentOS Linux"|"Red Hat Enterprise Linux")
            yum install -y jq
            ;;
        *)
            echo -e "${RED}Error: Unsupported Linux distribution for jq installation${NC}"
            return 1
            ;;
    esac
    
    echo -e "${GREEN}jq installed successfully${NC}"
}

# Function to install curl
install_curl() {
    echo -e "${CYAN}Installing curl...${NC}"
    
    case $OS in
        "Ubuntu"|"Debian GNU/Linux")
            apt-get update
            apt-get install -y curl
            ;;
        "CentOS Linux"|"Red Hat Enterprise Linux")
            yum install -y curl
            ;;
        *)
            echo -e "${RED}Error: Unsupported Linux distribution for curl installation${NC}"
            return 1
            ;;
    esac
    
    echo -e "${GREEN}curl installed successfully${NC}"
}

# Function to install wget
install_wget() {
    echo -e "${CYAN}Installing wget...${NC}"
    
    case $OS in
        "Ubuntu"|"Debian GNU/Linux")
            apt-get update
            apt-get install -y wget
            ;;
        "CentOS Linux"|"Red Hat Enterprise Linux")
            yum install -y wget
            ;;
        *)
            echo -e "${RED}Error: Unsupported Linux distribution for wget installation${NC}"
            return 1
            ;;
    esac
    
    echo -e "${GREEN}wget installed successfully${NC}"
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
        return 1
    fi
    echo -e "${GREEN}All requirements satisfied.${NC}"
    return 0
}

# Function to show interactive menu
show_menu() {
    if [ $INTERACTIVE -eq 0 ]; then
        # Non-interactive mode, install everything
        install_dependencies
        install_manager
        return
    fi

    local max_retries=3
    local retry_count=0

    while [ $retry_count -lt $max_retries ]; do
        echo -e "${CYAN}Docker Compose Manager Installation${NC}"
        echo "----------------------------------------"
        echo "1. Install Docker Compose Manager only"
        echo "2. Install missing dependencies"
        echo "3. Install everything"
        echo "4. Update Docker Compose Manager"
        echo "5. Exit"
        echo "----------------------------------------"
        read -p "Enter your choice [1-5]: " choice

        case $choice in
            1)
                install_manager
                return
                ;;
            2)
                install_dependencies
                return
                ;;
            3)
                install_dependencies
                install_manager
                return
                ;;
            4)
                install_manager
                return
                ;;
            5)
                echo "Exiting..."
                exit 0
                ;;
            *)
                retry_count=$((retry_count + 1))
                if [ $retry_count -lt $max_retries ]; then
                    echo -e "${RED}Invalid choice. Please try again.${NC}"
                    echo -e "${YELLOW}Attempts remaining: $((max_retries - retry_count))${NC}"
                else
                    echo -e "${RED}Too many invalid choices. Exiting...${NC}"
                    exit 1
                fi
                ;;
        esac
    done
}

# Function to install dependencies
install_dependencies() {
    check_root
    detect_distro
    
    echo -e "${CYAN}Installing dependencies...${NC}"
    
    # Install Docker if needed
    if ! command -v docker &> /dev/null; then
        case $OS in
            "Ubuntu"|"Debian GNU/Linux")
                install_docker_ubuntu
                ;;
            "CentOS Linux"|"Red Hat Enterprise Linux")
                install_docker_centos
                ;;
            *)
                echo -e "${RED}Error: Unsupported Linux distribution for Docker installation${NC}"
                exit 1
                ;;
        esac
    fi
    
    # Install jq if needed
    if ! command -v jq &> /dev/null; then
        install_jq
    fi
    
    # Install curl or wget if needed
    if ! command -v curl &> /dev/null && ! command -v wget &> /dev/null; then
        read -p "Neither curl nor wget is installed. Which would you prefer to install? (curl/wget): " choice
        case $choice in
            curl)
                install_curl
                ;;
            wget)
                install_wget
                ;;
            *)
                echo -e "${RED}Invalid choice${NC}"
                exit 1
                ;;
        esac
    fi
}

# Function to install manager
install_manager() {
    echo -e "${CYAN}Installing Docker Compose Manager...${NC}"
    
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
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    show_usage
    exit 0
elif [ "$1" = "-u" ] || [ "$1" = "--uninstall" ]; then
    uninstall
    exit 0
elif [ "$1" = "--update" ]; then
    install_manager
    exit 0
elif [ "$1" = "-y" ] || [ "$1" = "--yes" ]; then
    # Non-interactive mode
    INTERACTIVE=0
    install_dependencies
    install_manager
    exit 0
fi

# Show interactive menu
show_menu 