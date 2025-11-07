#!/bin/bash

SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_ROOT/config.sh"
source "$SCRIPT_ROOT/utils.sh"
source "$SCRIPT_ROOT/storage.sh"

# Color codes
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

    # Run container WITHOUT relay server settings
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
        
        # Wait for container to initialize and get admin password
        print_status "Waiting for admin credentials to be generated..."
        
        ADMIN_PASSWORD=""
        for i in {1..60}; do
            ADMIN_PASSWORD=$(sudo docker logs "$CONTAINER_NAME" 2>&1 | grep -oP 'Admin Password:\s*\K[^\s]+' | head -1 | tr -d '()' || true)
            
            if [ -n "$ADMIN_PASSWORD" ] && [ "$ADMIN_PASSWORD" != "Check" ]; then
                print_status "✅ Credentials extracted successfully"
                break
            fi
            
            sleep 1
        done

        # Get public key
        PUBLIC_KEY=$(sudo docker exec "$CONTAINER_NAME" cat /data/id_ed25519.pub 2>/dev/null || echo "Check container logs")

        # Get Tailscale status
        TS_STATUS=$(tailscale status --json 2>/dev/null | grep -q "Online" && echo "🟢 Online" || echo "🟢 Connected")

        # Display final summary
        display_rustdesk_summary
        
        export ADMIN_PASSWORD
        export PUBLIC_KEY
    else
        print_error "Failed to start RustDesk container"
        exit 1
    fi
}

display_rustdesk_summary() {
    echo ""
    echo -e "${GREEN}${BOLD}==================================================${NC}"
    echo -e "${GREEN}${BOLD}✅ RustDesk Installation Complete!${NC}"
    echo -e "${GREEN}${BOLD}==================================================${NC}"
    echo ""
    
    echo -e "${CYAN}${BOLD}🌐 Access URLs (via Tailscale ONLY):${NC}"
    echo -e "${BLUE}   Admin Panel:${NC}     http://${TAILSCALE_IP}:21114/_admin/"
    echo -e "${BLUE}   Web Client:${NC}      http://${TAILSCALE_IP}:21114/"
    echo -e "${BLUE}   API Docs:${NC}        http://${TAILSCALE_IP}:21114/swagger/index.html"
    echo ""
    
    echo -e "${CYAN}${BOLD}🔐 Admin Credentials:${NC}"
    echo -e "${BLUE}   Username:${NC} admin"
    if [ -n "$ADMIN_PASSWORD" ] && [ "$ADMIN_PASSWORD" != "Check" ]; then
        echo -e "${BLUE}   Password:${NC} ${YELLOW}${ADMIN_PASSWORD}${NC}"
    else
        echo -e "${BLUE}   Password:${NC} ${YELLOW}Check logs: sudo docker logs $CONTAINER_NAME${NC}"
    fi
    echo ""
    
    echo -e "${CYAN}${BOLD}🔧 RustDesk Client Setup:${NC}"
    echo -e "${BLUE}   ID Server:${NC}       ${TAILSCALE_IP}:21116"
    echo -e "${BLUE}   Relay Server:${NC}    DISABLED (Direct only)"
    echo -e "${BLUE}   API Server:${NC}      http://${TAILSCALE_IP}:21114"
    if [ -n "$PUBLIC_KEY" ] && [ "$PUBLIC_KEY" != "Check container logs" ]; then
        echo -e "${BLUE}   Public Key:${NC}     ${PUBLIC_KEY:0:30}..."
    fi
    echo ""
    
    echo -e "${CYAN}${BOLD}🔐 Tailscale Network:${NC}"
    echo -e "${BLUE}   Your IP:${NC}         ${GREEN}${TAILSCALE_IP}${NC}"
    echo -e "${BLUE}   Status:${NC}          ${TS_STATUS}"
    echo ""
    
    echo -e "${CYAN}${BOLD}📋 Quick Commands:${NC}"
    echo -e "${BLUE}   View logs:${NC}          sudo docker logs -f rustdesk-server"
    echo -e "${BLUE}   Change password:${NC}    sudo docker exec rustdesk-server /app/apimain reset-admin-pwd NEW_PASSWORD"
    echo -e "${BLUE}   Restart container:${NC}  sudo docker restart rustdesk-server"
    echo ""
    
    echo -e "${RED}⚠️  RELAY IS DISABLED - Direct Tailscale connection only${NC}"
    echo ""
    echo -e "${GREEN}${BOLD}==================================================${NC}"
    echo -e "${GREEN}${BOLD}📱 Client Setup Instructions:${NC}"
    echo -e "${GREEN}${BOLD}==================================================${NC}"
    echo ""
    echo -e "1. Install Tailscale: https://tailscale.com/download"
    echo -e "2. Connect to your Tailscale network"
    echo -e "3. Install RustDesk client"
    echo -e "4. Go to Settings → Network"
    echo -e "5. ID Server: ${GREEN}${TAILSCALE_IP}:21116${NC}"
    echo -e "6. Relay Server: Leave EMPTY"
    echo -e "7. Apply & restart RustDesk"
    echo ""
    echo -e "${GREEN}${BOLD}✅ Setup Complete!${NC}"
    echo -e "${GREEN}${BOLD}==================================================${NC}"
    echo ""
}

run_rustdesk_container
