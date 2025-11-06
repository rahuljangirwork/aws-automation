#!/bin/bash

source ./scripts/config.sh
source ./scripts/utils.sh

create_directories() {
    print_status "Creating data directories..."
    sudo mkdir -p $DATA_DIR/api $DATA_DIR/server
    sudo chown -R $USER:$USER $DATA_DIR
}

run_rustdesk_container() {
    print_status "Setting up RustDesk container with Tailscale (RELAY DISABLED)..."

    # Pull latest image
    sudo docker pull $IMAGE

    # Stop and remove existing container
    sudo docker stop $CONTAINER_NAME 2>/dev/null || true
    sudo docker rm $CONTAINER_NAME 2>/dev/null || true

    print_status "Starting RustDesk container with Tailscale IP: $TAILSCALE_IP"
    print_status "⚠️  RELAY CONNECTIONS ARE DISABLED - Only Tailscale VPN connections allowed"

    # Run container WITHOUT relay server settings (forces direct connection only)
    sudo docker run -d --name $CONTAINER_NAME \
        -p 21114:21114 -p 21115:21115 -p 21116:21116 -p 21116:21116/udp -p 21117:21117 \
        -p 21118:21118 -p 21119:21119 \
        -v $DATA_DIR/server:/data \
        -v $DATA_DIR/api:/app/data \
        -e TZ=Asia/Shanghai \
        -e ENCRYPTED_ONLY=1 \
        -e ALWAYS_USE_RELAY=N \
        -e DIRECT_IP_ACCESS=1 \
        -e MUST_LOGIN=N \
        -e RUSTDESK_API_RUSTDESK_ID_SERVER=$TAILSCALE_IP:21116 \
        -e RUSTDESK_API_RUSTDESK_API_SERVER=http://$TAILSCALE_IP:21114 \
        -e RUSTDESK_API_LANG=en \
        -e RUSTDESK_API_APP_SHOW_SWAGGER=1 \
        -e RUSTDESK_API_APP_REGISTER=false \
        -e RUSTDESK_API_APP_TOKEN_EXPIRE=168h \
        --restart unless-stopped $IMAGE

    if [ $? -eq 0 ]; then
        print_status "RustDesk container started successfully"
    else
        print_error "Failed to start RustDesk container"
        exit 1
    fi
}
