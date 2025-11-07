#!/bin/bash

SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_ROOT/config.sh"
source "$SCRIPT_ROOT/utils.sh"

# Color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

show_service_menu() {
    echo ""
    echo -e "${CYAN}${BOLD}========================================${NC}"
    echo -e "${CYAN}${BOLD}AWS Self-Hosted Services Installer${NC}"
    echo -e "${CYAN}${BOLD}========================================${NC}"
    echo ""
    echo -e "${BLUE}Using Tailscale IP: ${GREEN}${TAILSCALE_IP}${NC}"
    echo ""
    echo -e "${YELLOW}Which services do you want to install?${NC}"
    echo ""
    echo "  1) Portainer (Container Management)"
    echo "  2) RustDesk Server (Remote Desktop)"
    echo "  3) Nextcloud (File Sharing)"
    echo "  4) Nginx Proxy Manager (Reverse Proxy)"
    echo ""
    echo -e "${YELLOW}Enter choices (space-separated): ${NC}"
    read -r CHOICES
    
    echo ""
    echo -e "${GREEN}Starting installation...${NC}"
    echo ""
}

install_services() {
    for choice in $CHOICES; do
        case $choice in
            1)
                echo -e "${YELLOW}📦 Installing Portainer...${NC}"
                bash "$SCRIPT_ROOT/deploy_portainer.sh"
                display_portainer_summary
                echo ""
                ;;
            2)
                echo -e "${YELLOW}📦 Installing RustDesk Server...${NC}"
                bash "$SCRIPT_ROOT/deploy_rustdesk.sh"
                echo ""
                ;;
            3)
                echo -e "${YELLOW}📦 Installing Nextcloud...${NC}"
                bash "$SCRIPT_ROOT/deploy_nextcloud.sh"
                display_nextcloud_summary
                echo ""
                ;;
            4)
                echo -e "${YELLOW}📦 Installing Nginx Proxy Manager...${NC}"
                bash "$SCRIPT_ROOT/deploy_npm.sh"
                display_npm_summary
                echo ""
                ;;
            *)
                print_warning "Invalid choice: $choice"
                ;;
        esac
    done
    
    display_final_summary
}

display_portainer_summary() {
    echo ""
    echo -e "${GREEN}${BOLD}==================================================${NC}"
    echo -e "${GREEN}${BOLD}✅ Portainer Installation Complete!${NC}"
    echo -e "${GREEN}${BOLD}==================================================${NC}"
    echo ""
    echo -e "${BLUE}🌐 Access URL:${NC}     https://${TAILSCALE_IP}:9443/"
    echo -e "${BLUE}📋 Default User:${NC}   admin"
    echo -e "${BLUE}🔐 Password:${NC}       Set on first login"
    echo ""
}

display_nextcloud_summary() {
    echo ""
    echo -e "${GREEN}${BOLD}==================================================${NC}"
    echo -e "${GREEN}${BOLD}✅ Nextcloud Installation Complete!${NC}"
    echo -e "${GREEN}${BOLD}==================================================${NC}"
    echo ""
    echo -e "${BLUE}🌐 Access URL:${NC}     http://${TAILSCALE_IP}:8080/"
    echo -e "${BLUE}📋 Default User:${NC}   admin"
    echo -e "${BLUE}🔐 Password:${NC}       Check container logs"
    echo ""
}

display_npm_summary() {
    echo ""
    echo -e "${GREEN}${BOLD}==================================================${NC}"
    echo -e "${GREEN}${BOLD}✅ Nginx Proxy Manager Installation Complete!${NC}"
    echo -e "${GREEN}${BOLD}==================================================${NC}"
    echo ""
    echo -e "${BLUE}🌐 Access URL:${NC}     http://${TAILSCALE_IP}:81/"
    echo -e "${BLUE}📋 Default User:${NC}   admin@example.com"
    echo -e "${BLUE}🔐 Default Pass:${NC}   changeme"
    echo ""
}

display_final_summary() {
    echo ""
    echo -e "${GREEN}${BOLD}==================================================${NC}"
    echo -e "${GREEN}${BOLD}🎉 All Services Installed Successfully!${NC}"
    echo -e "${GREEN}${BOLD}==================================================${NC}"
    echo ""
    echo -e "${CYAN}${BOLD}📱 Access Your Services:${NC}"
    echo ""
    echo -e "${BLUE}Your Tailscale IP: ${GREEN}${TAILSCALE_IP}${NC}"
    echo ""
    echo -e "${BLUE}Services:${NC}"
    echo "  • Portainer:     https://${TAILSCALE_IP}:9443/"
    echo "  • RustDesk:      http://${TAILSCALE_IP}:21114/"
    echo "  • Nextcloud:     http://${TAILSCALE_IP}:8080/"
    echo "  • Nginx PM:      http://${TAILSCALE_IP}:81/"
    echo ""
    echo -e "${CYAN}${BOLD}💡 Important:${NC}"
    echo "  1. Install Tailscale on all client devices"
    echo "  2. All services are only accessible via Tailscale"
    echo "  3. Change default passwords immediately"
    echo "  4. Check logs if you have issues"
    echo ""
    echo -e "${GREEN}${BOLD}✅ Setup Complete!${NC}"
    echo -e "${GREEN}${BOLD}==================================================${NC}"
    echo ""
}

# Run the menu
show_service_menu
install_services
