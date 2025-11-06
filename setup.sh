#!/bin/bash

set -e

# Source all the scripts
source ./scripts/config.sh
source ./scripts/utils.sh
source ./scripts/install_docker.sh
source ./scripts/install_tailscale.sh
source ./scripts/setup_efs.sh
source ./scripts/deploy_rustdesk.sh
source ./scripts/deploy_portainer.sh
source ./scripts/deploy_npm.sh
source ./scripts/deploy_nextcloud.sh

# --- Globals ---
declare -a CHOICES

# --- Interactive Menu ---
show_menu_and_get_choices() {
    echo -e "${YELLOW}Please choose which services to install:${NC}"
    echo "  1) Portainer"
    echo "  2) RustDesk Server"
    echo "  3) Nextcloud"
    echo "  4) Nginx Proxy Manager"
    echo ""
    echo "You can select multiple services. For example, enter: 1 2"
    echo ""
    
    read -p "Enter your choices (space-separated): " -a CHOICES
    
    if [ ${#CHOICES[@]} -eq 0 ]; then
        print_error "No selection made. Exiting."
        exit 1
    fi
}

# --- Installation Dispatcher ---
install_selected_apps() {
    print_status "Starting installation of selected services..."
    
    # Always create base directories first
    create_directories

    for choice in "${CHOICES[@]}"; do
        case $choice in
            1)
                print_status "Installing Portainer..."
                run_portainer
                ;;
            2)
                print_status "Installing RustDesk Server..."
                run_rustdesk_container
                ;;
            3)
                print_status "Installing Nextcloud..."
                run_nextcloud
                ;;
            4)
                print_status "Installing Nginx Proxy Manager..."
                run_npm
                ;;
            *)
                print_warning "Invalid choice: $choice. Skipping."
                ;;
        esac
    done
}

# --- Verification and Final Info ---
verify_and_display_info() {
    print_status "Verifying installations..."
    
    local rustdesk_installed=false
    local portainer_installed=false
    local npm_installed=false
    local nextcloud_installed=false

    for choice in "${CHOICES[@]}"; do
        case $choice in
            1)
                if sudo docker ps | grep -q $PORTAINER_CONTAINER; then
                    print_status "✓ Portainer container is running"
                    portainer_installed=true
                else
                    print_error "✗ Portainer container is not running"
                fi
                ;;
            2)
                if sudo docker ps | grep -q $CONTAINER_NAME; then
                    print_status "✓ RustDesk container is running"
                    rustdesk_installed=true
                else
                    print_error "✗ RustDesk container is not running"
                fi
                
                if curl -s --max-time 10 http://localhost:21114/_admin/ >/dev/null 2>&1; then
                    print_status "✓ RustDesk API is responding"
                else
                    print_warning "⚠ RustDesk API may not be ready yet"
                fi
                ;;
            3)
                if sudo docker ps | grep -q $NC_CONTAINER; then
                    print_status "✓ Nextcloud container is running"
                    nextcloud_installed=true
                else
                    print_error "✗ Nextcloud container is not running"
                fi
                ;;
            4)
                if sudo docker ps | grep -q $NPM_CONTAINER; then
                    print_status "✓ Nginx Proxy Manager container is running"
                    npm_installed=true
                else
                    print_error "✗ Nginx Proxy Manager container is not running"
                fi
                ;;
        esac
    done

    # Common verification
    if tailscale status >/dev/null 2>&1; then
        print_status "✓ Tailscale VPN is connected"
    else
        print_warning "⚠ Tailscale may not be connected"
    fi

    # --- Display Final Info ---
    echo ""
    echo "=================================================="
    echo -e "${GREEN}      Service Installation Complete!${NC}"
    echo "=================================================="
    echo ""
    echo -e "${YELLOW}🌐 Access URLs (via Tailscale ONLY):${NC}"
    if [ "$portainer_installed" = true ]; then
        echo "   Portainer:           https://$TAILSCALE_IP:9443/"
    fi
    if [ "$rustdesk_installed" = true ]; then
        echo "   RustDesk Admin Panel: http://$TAILSCALE_IP:21114/_admin/"
        echo "   RustDesk Web Client:  http://$TAILSCALE_IP:21114/"
    fi
    if [ "$npm_installed" = true ]; then
        echo "   Nginx Proxy Manager: http://$TAILSCALE_IP:81/"
    fi
    if [ "$nextcloud_installed" = true ]; then
        echo "   Nextcloud:           http://$TAILSCALE_IP:8080/"
    fi
    echo ""

    if [ "$rustdesk_installed" = true ]; then
        # Retrieve RustDesk info
        ADMIN_PASSWORD=$(sudo docker logs $CONTAINER_NAME 2>&1 | grep -i "admin password" | tail -1 | awk -F': ' '{print $2}' | tr -d '\n\r')
        PUBLIC_KEY=$(sudo docker exec $CONTAINER_NAME cat /data/id_ed25519.pub 2>/dev/null | tr -d '\n\r')

        echo -e "${YELLOW}🔐 RustDesk Credentials & Config:${NC}"
        echo "   Admin Username: admin"
        echo "   Admin Password: ${ADMIN_PASSWORD:-Not found, check logs}"
        echo "   ID Server:    $TAILSCALE_IP:21116"
        echo "   Public Key:   ${PUBLIC_KEY:-Not found, check logs}"
        echo ""
    fi
    
    if [ "$npm_installed" = true ]; then
        echo -e "${YELLOW}🔐 Nginx Proxy Manager Default Credentials:${NC}"
        echo "   Email:    admin@example.com"
        echo "   Password: changeme"
        echo ""
    fi

    echo -e "${YELLOW}💡 Important Notes:${NC}"
    echo "   - All services are accessible ONLY through the Tailscale VPN."
    echo "   - For RustDesk, ensure Relay is disabled in the client."
    echo ""
    echo -e "${GREEN}✅ Setup finished!${NC}"
    echo ""
}


# --- Main Execution ---
main() {
    echo -e "${GREEN}"
    echo "========================================================="
    echo "    Interactive AWS Self-Hosted Service Installer"
    echo "========================================================="
    echo -e "${NC}"
    
    # --- Core Setup ---
    check_root
    install_dependencies
    install_tailscale
    setup_tailscale
    
    TAILSCALE_IP=$(get_tailscale_ip)
    if [ -z "$TAILSCALE_IP" ]; then
        print_error "Could not detect Tailscale IP. Exiting."
        exit 1
    fi
    print_status "Using Tailscale IP: $TAILSCALE_IP"
    
    mount_efs
    configure_efs_automount
    
    # --- Interactive Installation ---
    show_menu_and_get_choices
    install_selected_apps
    
    # --- Finalization ---
    # The backup cron job is specific to RustDesk, let's make it conditional
    if [[ " ${CHOICES[*]} " =~ " 2 " ]]; then
        setup_backup_cron
    fi
    
    print_status "Waiting for services to initialize..."
    sleep 15
    
    verify_and_display_info
}

setup_backup_cron() {
    # This function is now conditional, only for RustDesk
    print_status "Setting up automated backups for RustDesk..."
    # (Backup script content remains the same as original)
    BACKUP_SCRIPT="/usr/local/bin/rustdesk_backup.sh"
    sudo tee $BACKUP_SCRIPT > /dev/null <<EOF
#!/bin/bash
DATE=\$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/var/backups/rustdesk"
mkdir -p \$BACKUP_DIR
tar czf \$BACKUP_DIR/rustdesk_backup_\$DATE.tar.gz -C $DATA_DIR .
find \$BACKUP_DIR -name "rustdesk_backup_*.tar.gz" -mtime +7 -delete
EOF
    sudo chmod +x $BACKUP_SCRIPT
    (crontab -l 2>/dev/null | grep -v "$BACKUP_SCRIPT"; echo "0 3 * * * $BACKUP_SCRIPT") | crontab -
    print_status "RustDesk backup cron job configured."
}

# Run main function
main "$@"