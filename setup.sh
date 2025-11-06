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

# Main execution
main() {
    echo -e "${GREEN}"
    echo "========================================================="
    echo "  RustDesk + Tailscale VPN + EFS + Portainer Setup"
    echo "  AWS Ubuntu - Secure Direct Connections Only"
    echo "========================================================="
    echo -e "${NC}"
    
    check_root
    install_dependencies
    install_tailscale
    setup_tailscale
    
    # Get Tailscale IP after setup
    TAILSCALE_IP=$(get_tailscale_ip)
    
    if [ -z "$TAILSCALE_IP" ]; then
        print_error "Could not detect Tailscale IP. Please ensure Tailscale is connected."
        exit 1
    fi
    
    print_status "Using Tailscale IP: $TAILSCALE_IP"
    

    mount_efs
    configure_efs_automount
    create_directories
    run_rustdesk_container
    run_portainer
    setup_backup_cron
    wait_for_services
    verify_installation
    display_final_info
}

setup_backup_cron() {
    print_status "Setting up automated backups..."
    
    BACKUP_SCRIPT="/usr/local/bin/rustdesk_backup.sh"
    
    sudo tee $BACKUP_SCRIPT > /dev/null <<EOF
#!/bin/bash
# RustDesk Backup Script
DATE=\$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/var/backups/rustdesk"
mkdir -p \$BACKUP_DIR
tar czf \$BACKUP_DIR/rustdesk_backup_\$DATE.tar.gz -C $DATA_DIR .
# Keep only last 7 days of backups
find \$BACKUP_DIR -name "rustdesk_backup_*.tar.gz" -mtime +7 -delete
echo "\$(date): Backup completed - rustdesk_backup_\$DATE.tar.gz"
EOF
    
    sudo chmod +x $BACKUP_SCRIPT
    
    # Add to crontab (daily backup at 3 AM)
    (crontab -l 2>/dev/null | grep -v "$BACKUP_SCRIPT"; echo "0 3 * * * $BACKUP_SCRIPT") | crontab -
    
    print_status "Backup cron job configured for daily 3 AM"
}

wait_for_services() {
    print_status "Waiting for services to initialize..."
    sleep 15
    
    # Get admin password from logs
    print_status "Retrieving admin password from container logs..."
    ADMIN_PASSWORD=$(sudo docker logs $CONTAINER_NAME 2>&1 | grep -i "admin password" | tail -1 | awk -F': ' '{print $2}' | tr -d ' \n\r')
    
    if [ -z "$ADMIN_PASSWORD" ]; then
        # Try alternative patterns
        ADMIN_PASSWORD=$(sudo docker logs $CONTAINER_NAME 2>&1 | grep -i "password.*admin\|admin.*password" | tail -1 | awk '{print $NF}' | tr -d ' \n\r')
    fi
    
    # Get public key
    print_status "Retrieving server public key..."
    sleep 5
    PUBLIC_KEY=$(sudo docker exec $CONTAINER_NAME cat /data/id_ed25519.pub 2>/dev/null | tr -d ' \n\r')
    
    if [ -z "$PUBLIC_KEY" ]; then
        PUBLIC_KEY=$(sudo docker exec $CONTAINER_NAME find /data /app -name "*.pub" -exec cat {} \; 2>/dev/null | head -1 | tr -d ' \n\r')
    fi
}

verify_installation() {
    print_status "Verifying installation..."
    
    # Check if containers are running
    if sudo docker ps | grep -q $CONTAINER_NAME; then
        print_status "✓ RustDesk container is running"
    else
        print_error "✗ RustDesk container is not running"
        return 1
    fi
    
    if sudo docker ps | grep -q $PORTAINER_CONTAINER; then
        print_status "✓ Portainer container is running"
    else
        print_error "✗ Portainer container is not running"
        return 1
    fi
    
    # Check Tailscale status
    if tailscale status >/dev/null 2>&1; then
        print_status "✓ Tailscale VPN is connected"
    else
        print_warning "⚠ Tailscale may not be connected"
    fi
    
    # Test API endpoint
    if curl -s --max-time 10 http://localhost:21114/_admin/ >/dev/null 2>&1; then
        print_status "✓ RustDesk API is responding"
    else
        print_warning "⚠ RustDesk API may not be ready yet (this is normal)"
    fi
}

display_final_info() {
    echo ""
    echo "=================================================="
    echo -e "${GREEN}  RustDesk + Tailscale + EFS Installation Complete!${NC}"
    echo "=================================================="
    echo ""
    echo -e "${YELLOW}🌐 Access URLs (via Tailscale ONLY):${NC}"
    echo "   RustDesk Admin Panel: http://$TAILSCALE_IP:21114/_admin/"
    echo "   RustDesk Web Client:  http://$TAILSCALE_IP:21114/"
    echo "   Portainer:           https://$TAILSCALE_IP:9443/"
    echo "   API Documentation:   http://$TAILSCALE_IP:21114/swagger/index.html"
    echo ""
    echo -e "${YELLOW}🔐 Credentials:${NC}"
    echo "   Admin Username: admin"
    if [ ! -z "$ADMIN_PASSWORD" ]; then
        echo "   Admin Password: $ADMIN_PASSWORD"
    else
        echo "   Admin Password: Check logs with: sudo docker logs $CONTAINER_NAME | grep -i password"
    fi
    echo ""
    echo -e "${YELLOW}🔧 RustDesk Client Configuration:${NC}"
    echo "   ID Server:    $TAILSCALE_IP:21116"
    echo "   Relay Server: DISABLED (Direct connection only)"
    echo "   API Server:   http://$TAILSCALE_IP:21114"
    if [ ! -z "$PUBLIC_KEY" ]; then
        echo "   Public Key:   $PUBLIC_KEY"
    else
        echo "   Public Key:   Run: sudo docker exec $CONTAINER_NAME cat /data/id_ed25519.pub"
    fi
    echo ""
    echo -e "${YELLOW}🔐 Tailscale Network:${NC}"
    echo "   Your Tailscale IP: $TAILSCALE_IP"
    echo "   Network Status:    $(tailscale status --json 2>/dev/null | jq -r '.Self.Online' || echo 'Connected')"
    echo ""
    echo -e "${YELLOW}📁 EFS Storage:${NC}"
    echo "   EFS ID:        $EFS_ID"
    echo "   Mount Point:   $DATA_DIR"
    echo "   Auto-mount:    Enabled in /etc/fstab"
    echo ""
    echo -e "${YELLOW}💡 Important Notes:${NC}"
    echo "   ⚠️  RELAY IS DISABLED - Connections work ONLY via Tailscale VPN"
    echo "   1. Install Tailscale on all client devices"
    echo "   2. Use Tailscale IP ($TAILSCALE_IP) for RustDesk ID Server"
    echo "   3. Connect using direct IP or ID (no relay fallback)"
    echo "   4. Change admin password: sudo docker exec rustdesk-server /app/apimain reset-admin-pwd YOUR_PASSWORD"
    echo "   5. Monitor logs: sudo docker logs -f $CONTAINER_NAME"
    echo ""
    echo -e "${YELLOW}📱 Client Setup Instructions:${NC}"
    echo "   1. Install Tailscale on client device: https://tailscale.com/download"
    echo "   2. Connect to your Tailscale network"
    echo "   3. Install RustDesk client"
    echo "   4. Go to Settings → Network"
    echo "   5. Set ID Server: $TAILSCALE_IP:21116"
    echo "   6. Leave Relay Server EMPTY or set to 127.0.0.1"
    echo "   7. Apply settings and restart RustDesk"
    echo ""
    echo -e "${GREEN}✅ Installation completed successfully!${NC}"
    echo ""
}

# Run main function
main "$@"
