#!/bin/bash

run_pihole() {
    print_status "Setting up Pi-hole + Unbound..."

    # Create directories on EFS
    sudo mkdir -p "$PIHOLE_DATA_DIR/pihole"
    sudo mkdir -p "$PIHOLE_DATA_DIR/unbound"

    # Create Docker Compose file
    tee "$PIHOLE_COMPOSE_FILE" > /dev/null <<EOF
version: "3.8"

services:
  pihole:
    image: pihole/pihole:latest
    container_name: ${PIHOLE_CONTAINER}
    ports:
      - "53:53/tcp"
      - "53:53/udp"
      - "8081:80/tcp"
    environment:
      TZ: 'auto'
      WEBPASSWORD: '${PIHOLE_PASSWORD}'
      DNS1: '127.0.0.1#5335'
      DNS2: 'no'
    volumes:
      - "${PIHOLE_DATA_DIR}/pihole:/etc/pihole"
      - "${PIHOLE_DATA_DIR}/dnsmasq.d:/etc/dnsmasq.d"
    depends_on:
      - unbound
    restart: unless-stopped
    networks:
      - pihole-net

  unbound:
    image: mvance/unbound:latest
    container_name: unbound
    ports:
      - "5335:5335/tcp"
      - "5335:5335/udp"
    volumes:
      - "${PIHOLE_DATA_DIR}/unbound:/opt/unbound/etc/unbound/"
    restart: unless-stopped
    networks:
      - pihole-net

networks:
  pihole-net:
    driver: bridge
EOF

    print_status "Starting Pi-hole and Unbound containers..."
    (cd "$(dirname "$PIHOLE_COMPOSE_FILE")" && sudo docker-compose -f "$PIHOLE_COMPOSE_FILE" up -d)

    print_status "Pi-hole setup complete."
    echo "Pi-hole admin panel will be available at http://$TAILSCALE_IP:8081/admin/"
    echo "Admin password is: ${PIHOLE_PASSWORD}"
}
