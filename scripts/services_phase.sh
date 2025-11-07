#!/bin/bash

declare -a CHOICES

run_services_phase() {
    if ! tailscale status >/dev/null 2>&1; then
        print_error "Tailscale VPN is not connected. Run './bootstrap.sh' first."
        exit 1
    fi

    TAILSCALE_IP=$(get_tailscale_ip)
    if [[ -z "$TAILSCALE_IP" ]]; then
        print_error "Could not detect Tailscale IP."
        exit 1
    fi
    export TAILSCALE_IP
    print_status "Using Tailscale IP: $TAILSCALE_IP"

    if ! mountpoint -q "$DATA_DIR"; then
        print_warning "EFS is not mounted at $DATA_DIR. Attempting to mount now..."
        mount_efs
    fi

    if ! mountpoint -q "$DATA_DIR"; then
        print_error "EFS is still not mounted. Aborting container deployment."
        exit 1
    fi

    create_directories

    show_menu_and_get_choices
    warn_if_low_memory_selection
    install_selected_apps

    if [[ " ${CHOICES[*]} " =~ " 2 " ]]; then
        setup_backup_cron
    fi

    print_status "Waiting for services to initialize..."
    sleep 15

    verify_and_display_info
}

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

warn_if_low_memory_selection() {
    local mem_total_kb mem_total_mb
    if [[ ${#CHOICES[@]} -le 2 ]]; then
        return
    fi

    mem_total_kb=$(grep -i MemTotal /proc/meminfo 2>/dev/null | awk '{print $2}')
    if [[ -z "$mem_total_kb" ]]; then
        return
    fi

    mem_total_mb=$((mem_total_kb / 1024))
    if (( mem_total_mb <= 1200 )); then
        print_warning "Host reports only ${mem_total_mb} MB of RAM. Running ${#CHOICES[@]} containers at once may exhaust memory."
        read -r -p "Continue anyway? [y/N]: " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            print_status "Skipping service deployment per user request."
            exit 0
        fi
    fi
}

install_selected_apps() {
    print_status "Starting installation of selected services..."

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

verify_and_display_info() {
    print_status "Verifying installations..."

    local rustdesk_installed=false
    local portainer_installed=false
    local npm_installed=false
    local nextcloud_installed=false

    for choice in "${CHOICES[@]}"; do
        case $choice in
            1)
                if docker ps | grep -q "$PORTAINER_CONTAINER"; then
                    print_status "[OK] Portainer container is running"
                    portainer_installed=true
                else
                    print_error "[FAIL] Portainer container is not running"
                fi
                ;;
            2)
                if docker ps | grep -q "$CONTAINER_NAME"; then
                    print_status "[OK] RustDesk container is running"
                    rustdesk_installed=true
                else
                    print_error "[FAIL] RustDesk container is not running"
                fi

                if curl -s --max-time 10 http://localhost:21114/_admin/ >/dev/null 2>&1; then
                    print_status "[OK] RustDesk API is responding"
                else
                    print_warning "[WARN] RustDesk API may not be ready yet"
                fi
                ;;
            3)
                if docker ps | grep -q "$NC_CONTAINER"; then
                    print_status "[OK] Nextcloud container is running"
                    nextcloud_installed=true
                else
                    print_error "[FAIL] Nextcloud container is not running"
                fi
                ;;
            4)
                if docker ps | grep -q "$NPM_CONTAINER"; then
                    print_status "[OK] Nginx Proxy Manager container is running"
                    npm_installed=true
                else
                    print_error "[FAIL] Nginx Proxy Manager container is not running"
                fi
                ;;
        esac
    done

    if tailscale status >/dev/null 2>&1; then
        print_status "[OK] Tailscale VPN is connected"
    else
        print_warning "[WARN] Tailscale may not be connected"
    fi

    echo ""
    echo -e "${GREEN}${BOLD}==================================================${NC}"
    echo -e "${GREEN}${BOLD}      Service Installation Complete!${NC}"
    echo -e "${GREEN}${BOLD}==================================================${NC}"
    echo ""
    
    echo -e "${CYAN}${BOLD}🌐 Access URLs (via Tailscale ONLY):${NC}"
    if [ "$portainer_installed" = true ]; then
        echo -e "${BLUE}   Portainer:           https://${TAILSCALE_IP}:9443/${NC}"
    fi
    if [ "$rustdesk_installed" = true ]; then
        echo -e "${BLUE}   RustDesk Admin Panel: http://${TAILSCALE_IP}:21114/_admin/${NC}"
        echo -e "${BLUE}   RustDesk Web Client:  http://${TAILSCALE_IP}:21114/${NC}"
    fi
    if [ "$npm_installed" = true ]; then
        echo -e "${BLUE}   Nginx Proxy Manager: http://${TAILSCALE_IP}:81/${NC}"
    fi
    if [ "$nextcloud_installed" = true ]; then
        echo -e "${BLUE}   Nextcloud:           http://${TAILSCALE_IP}:8080/${NC}"
    fi
    echo ""

    if [ "$rustdesk_installed" = true ]; then
        echo -e "${CYAN}${BOLD}🔐 RustDesk Credentials & Config:${NC}"
        echo -e "${BLUE}   Admin Username: admin${NC}"
        if [ -n "$ADMIN_PASSWORD" ]; then
            echo -e "${BLUE}   Admin Password: ${YELLOW}${ADMIN_PASSWORD}${NC}"
        else
            echo -e "${BLUE}   Admin Password: ${YELLOW}Not found, check logs: sudo docker logs $CONTAINER_NAME${NC}"
        fi
        echo -e "${BLUE}   ID Server:    ${TAILSCALE_IP}:21116${NC}"
        if [ -n "$PUBLIC_KEY" ] && [ "$PUBLIC_KEY" != "Check container logs" ]; then
            echo -e "${BLUE}   Public Key:   ${PUBLIC_KEY}${NC}"
        else
            echo -e "${BLUE}   Public Key:   ${YELLOW}Check: sudo docker exec $CONTAINER_NAME cat /data/id_ed25519.pub${NC}"
        fi
        echo ""
    fi

    if [ "$npm_installed" = true ]; then
        echo -e "${CYAN}${BOLD}🔐 Nginx Proxy Manager Default Credentials:${NC}"
        echo -e "${BLUE}   Email:    admin@example.com${NC}"
        echo -e "${BLUE}   Password: changeme${NC}"
        echo ""
    fi

    if [ "$rustdesk_installed" = true ]; then
        echo -e "${CYAN}${BOLD}📱 RustDesk Client Setup Instructions:${NC}"
        echo -e "   1. Install Tailscale on client device: ${BLUE}https://tailscale.com/download${NC}"
        echo -e "   2. Connect to your Tailscale network"
        echo -e "   3. Install RustDesk client"
        echo -e "   4. Go to Settings → Network"
        echo -e "   5. Set ID Server: ${GREEN}${TAILSCALE_IP}:21116${NC}"
        echo -e "   6. Leave Relay Server EMPTY or set to 127.0.0.1"
        echo -e "   7. Apply settings and restart RustDesk"
        echo ""
    fi

    echo -e "${YELLOW}${BOLD}💡 Important Notes:${NC}"
    echo -e "   - All services are accessible ONLY through the Tailscale VPN."
    echo -e "   - A 1 GB RAM instance can struggle if every container runs at once; enable services selectively."
    if [ "$rustdesk_installed" = true ]; then
        echo -e "   - For RustDesk, ensure Relay is disabled in the client."
    fi
    echo ""
    echo -e "${GREEN}Setup finished!${NC}"
    echo ""
}

setup_backup_cron() {
    print_status "Setting up automated backups for RustDesk..."
    local BACKUP_SCRIPT="/usr/local/bin/rustdesk_backup.sh"
    tee $BACKUP_SCRIPT > /dev/null <<'EOF'
#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/var/backups/rustdesk"
mkdir -p "${BACKUP_DIR}"
tar czf "${BACKUP_DIR}/rustdesk_backup_${DATE}.tar.gz" -C "$DATA_DIR" .
find "${BACKUP_DIR}" -name "rustdesk_backup_*.tar.gz" -mtime +7 -delete
EOF
    chmod +x $BACKUP_SCRIPT
    (crontab -l 2>/dev/null | grep -v "$BACKUP_SCRIPT"; echo "0 3 * * * $BACKUP_SCRIPT") | crontab -
    print_status "RustDesk backup cron job configured."
}