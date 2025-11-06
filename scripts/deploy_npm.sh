#!/bin/bash

run_npm() {
    print_status "Setting up Nginx Proxy Manager..."

    # Create directories on EFS
    sudo mkdir -p "$NPM_DATA_DIR/data"
    sudo mkdir -p "$NPM_DATA_DIR/letsencrypt"

    # Create Docker Compose file
    sudo tee "$NPM_COMPOSE_FILE" > /dev/null <<EOF
version: '3.8'
services:
  app:
    image: 'jc21/nginx-proxy-manager:latest'
    container_name: '${NPM_CONTAINER}'
    restart: unless-stopped
    ports:
      # These ports are in use by the web server
      - '80:80'
      - '443:443'
      # The Admin Web Port
      - '81:81'
    volumes:
      - ${NPM_DATA_DIR}/data:/data
      - ${NPM_DATA_DIR}/letsencrypt:/etc/letsencrypt
EOF

    print_status "Starting Nginx Proxy Manager container..."
    (cd "$(dirname "$NPM_COMPOSE_FILE")" && sudo docker-compose -f "$NPM_COMPOSE_FILE" up -d)

    print_status "Nginx Proxy Manager setup complete."
    echo "You can access the admin panel at http://$TAILSCALE_IP:81"
    echo "Default Admin User:"
    echo "  Email:    admin@example.com"
    echo "  Password: changeme"
}
