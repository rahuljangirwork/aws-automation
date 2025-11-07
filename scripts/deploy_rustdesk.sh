# #!/bin/bash

# SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# source "$SCRIPT_ROOT/config.sh"
# source "$SCRIPT_ROOT/utils.sh"
# source "$SCRIPT_ROOT/storage.sh"

# run_rustdesk_container() {
#     print_status "Setting up RustDesk container with Tailscale (RELAY DISABLED)..."

#     create_directories

#     # Pull latest image
#     sudo docker pull "$IMAGE"

#     # Stop and remove existing container
#     sudo docker stop "$CONTAINER_NAME" 2>/dev/null || true
#     sudo docker rm "$CONTAINER_NAME" 2>/dev/null || true

#     print_status "Starting RustDesk container with Tailscale IP: $TAILSCALE_IP"
#     print_status "[!] Relay connections are disabled; clients must use Tailscale VPN."

#     # Run container WITHOUT relay server settings (forces direct connection only)
#     sudo docker run -d --name "$CONTAINER_NAME" \
#         --memory=384m \
#         --memory-swap=512m \
#         -p 21114:21114 -p 21115:21115 -p 21116:21116 -p 21116:21116/udp -p 21117:21117 \
#         -p 21118:21118 -p 21119:21119 \
#         -v "$DATA_DIR/server:/data" \
#         -v "$DATA_DIR/api:/app/data" \
#         -e TZ=Asia/Shanghai \
#         -e ENCRYPTED_ONLY=1 \
#         -e ALWAYS_USE_RELAY=N \
#         -e DIRECT_IP_ACCESS=1 \
#         -e MUST_LOGIN=N \
#         -e RUSTDESK_API_RUSTDESK_ID_SERVER="${TAILSCALE_IP}:21116" \
#         -e RUSTDESK_API_RUSTDESK_API_SERVER="http://${TAILSCALE_IP}:21114" \
#         -e RUSTDESK_API_LANG=en \
#         -e RUSTDESK_API_APP_SHOW_SWAGGER=1 \
#         -e RUSTDESK_API_APP_REGISTER=false \
#         -e RUSTDESK_API_APP_TOKEN_EXPIRE=168h \
#         --restart unless-stopped "$IMAGE"

#     if [ $? -eq 0 ]; then
#         print_status "RustDesk container started successfully"
#     else
#         print_error "Failed to start RustDesk container"
#         exit 1
#     fi
# }


#!/bin/bash

SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_ROOT/config.sh"
source "$SCRIPT_ROOT/utils.sh"
source "$SCRIPT_ROOT/storage.sh"

# Color codes for better readability
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

run_rustdesk_container() {
    print_status "Setting up RustDesk container with Tailscale (RELAY DISABLED)..."

    create_directories

    # Pull latest image
    sudo docker pull "$IMAGE"

    # Stop and remove existing container
    sudo docker stop "$CONTAINER_NAME" 2>/dev/null || true
    sudo docker rm "$CONTAINER_NAME" 2>/dev/null || true

    print_status "Starting RustDesk container with Tailscale IP: $TAILSCALE_IP"
    print_status "[!] Relay connections are disabled; clients must use Tailscale VPN."

    # Run container WITHOUT relay server settings (forces direct connection only)
    sudo docker run -d --name "$CONTAINER_NAME" \
        --memory=384m \
        --memory-swap=512m \
        -p 21114:21114 -p 21115:21115 -p 21116:21116 -p 21116:21116/udp -p 21117:21117 \
        -p 21118:21118 -p 21119:21119 \
        -v "$DATA_DIR/server:/data" \
        -v "$DATA_DIR/api:/app/data" \
        -e TZ=Asia/Shanghai \
        -e ENCRYPTED_ONLY=1 \
        -e ALWAYS_USE_RELAY=N \
        -e DIRECT_IP_ACCESS=1 \
        -e MUST_LOGIN=N \
        -e RUSTDESK_API_RUSTDESK_ID_SERVER="${TAILSCALE_IP}:21116" \
        -e RUSTDESK_API_RUSTDESK_API_SERVER="http://${TAILSCALE_IP}:21114" \
        -e RUSTDESK_API_LANG=en \
        -e RUSTDESK_API_APP_SHOW_SWAGGER=1 \
        -e RUSTDESK_API_APP_REGISTER=false \
        -e RUSTDESK_API_APP_TOKEN_EXPIRE=168h \
        --restart unless-stopped "$IMAGE"

    if [ $? -eq 0 ]; then
        print_status "RustDesk container started successfully"
        
        # Wait for container to initialize
        sleep 5
        
        # Extract admin password from logs
        print_status "Extracting admin credentials..."
        ADMIN_PASSWORD=$(sudo docker logs "$CONTAINER_NAME" 2>&1 | grep -oP 'Admin Password:\s*\K[^\s]+' | head -1)
        
        # Get public key
        PUBLIC_KEY=$(sudo docker exec "$CONTAINER_NAME" cat /data/id_ed25519.pub 2>/dev/null || echo "Check container logs")
        
        # Check Tailscale status
        TS_STATUS=$(tailscale status --json 2>/dev/null | grep -q "Online" && echo "Online" || echo "Connected")
        
        # Get EFS info if available
        EFS_ID="${EFS_ID:-N/A}"
        MOUNT_POINT="${DATA_DIR:-/data/rustdesk}"
        
        # Display comprehensive summary
        display_installation_summary
    else
        print_error "Failed to start RustDesk container"
        exit 1
    fi
}

display_installation_summary() {
    echo ""
    echo -e "${GREEN}${BOLD}==================================================${NC}"
    echo -e "${GREEN}${BOLD}RustDesk + Tailscale + EFS Installation Complete!${NC}"
    echo -e "${GREEN}${BOLD}==================================================${NC}"
    echo ""
    
    echo -e "${CYAN}${BOLD}🌐 Access URLs (via Tailscale ONLY):${NC}"
    echo -e "${BLUE}   RustDesk Admin Panel:${NC} http://${TAILSCALE_IP}:21114/_admin/"
    echo -e "${BLUE}   RustDesk Web Client:${NC}  http://${TAILSCALE_IP}:21114/"
    echo -e "${BLUE}   Portainer:${NC}            https://${TAILSCALE_IP}:9443/"
    echo -e "${BLUE}   API Documentation:${NC}   http://${TAILSCALE_IP}:21114/swagger/index.html"
    echo ""
    
    echo -e "${CYAN}${BOLD}🔐 Credentials:${NC}"
    echo -e "${BLUE}   Admin Username:${NC} admin"
    if [ -n "$ADMIN_PASSWORD" ]; then
        echo -e "${BLUE}   Admin Password:${NC} ${YELLOW}${ADMIN_PASSWORD}${NC}"
    else
        echo -e "${BLUE}   Admin Password:${NC} ${YELLOW}Check logs: sudo docker logs $CONTAINER_NAME${NC}"
    fi
    echo ""
    
    echo -e "${CYAN}${BOLD}🔧 RustDesk Client Configuration:${NC}"
    echo -e "${BLUE}   ID Server:${NC}    ${TAILSCALE_IP}:21116"
    echo -e "${BLUE}   Relay Server:${NC} ${RED}DISABLED (Direct connection only)${NC}"
    echo -e "${BLUE}   API Server:${NC}   http://${TAILSCALE_IP}:21114"
    if [ -n "$PUBLIC_KEY" ] && [ "$PUBLIC_KEY" != "Check container logs" ]; then
        echo -e "${BLUE}   Public Key:${NC}   ${PUBLIC_KEY}"
    else
        echo -e "${BLUE}   Public Key:${NC}   ${YELLOW}Check: sudo docker exec $CONTAINER_NAME cat /data/id_ed25519.pub${NC}"
    fi
    echo ""
    
    echo -e "${CYAN}${BOLD}🔐 Tailscale Network:${NC}"
    echo -e "${BLUE}   Your Tailscale IP:${NC} ${GREEN}${TAILSCALE_IP}${NC}"
    echo -e "${BLUE}   Network Status:${NC}    ${GREEN}${TS_STATUS}${NC}"
    echo ""
    
    if [ "$EFS_ID" != "N/A" ]; then
        echo -e "${CYAN}${BOLD}📁 EFS Storage:${NC}"
        echo -e "${BLUE}   EFS ID:${NC}        ${EFS_ID}"
        echo -e "${BLUE}   Mount Point:${NC}   ${MOUNT_POINT}"
        echo -e "${BLUE}   Auto-mount:${NC}    Enabled in /etc/fstab"
        echo ""
    fi
    
    echo -e "${CYAN}${BOLD}💡 Important Notes:${NC}"
    echo -e "${RED}   ⚠️  RELAY IS DISABLED${NC} - Connections work ONLY via Tailscale VPN"
    echo -e "   1. Install Tailscale on all client devices"
    echo -e "   2. Use Tailscale IP (${TAILSCALE_IP}) for RustDesk ID Server"
    echo -e "   3. Connect using direct IP or ID (no relay fallback)"
    echo -e "   4. Change admin password: ${YELLOW}sudo docker exec $CONTAINER_NAME /app/apimain reset-admin-pwd YOUR_PASSWORD${NC}"
    echo -e "   5. Monitor logs: ${YELLOW}sudo docker logs -f $CONTAINER_NAME${NC}"
    echo ""
    
    echo -e "${CYAN}${BOLD}📱 Client Setup Instructions:${NC}"
    echo -e "   1. Install Tailscale on client device: ${BLUE}https://tailscale.com/download${NC}"
    echo -e "   2. Connect to your Tailscale network"
    echo -e "   3. Install RustDesk client"
    echo -e "   4. Go to Settings → Network"
    echo -e "   5. Set ID Server: ${GREEN}${TAILSCALE_IP}:21116${NC}"
    echo -e "   6. Leave Relay Server EMPTY or set to 127.0.0.1"
    echo -e "   7. Apply settings and restart RustDesk"
    echo ""
    
    echo -e "${GREEN}${BOLD}✅ Installation completed successfully!${NC}"
    echo -e "${GREEN}${BOLD}==================================================${NC}"
    echo ""
}
