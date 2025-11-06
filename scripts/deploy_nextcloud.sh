#!/bin/bash

run_nextcloud() {
    print_status "Setting up Nextcloud..."

    # Create directories on EFS
    mkdir -p "$NC_DATA_DIR/html"
    mkdir -p "$NC_DATA_DIR/db"

    # Create Docker Compose file
    tee "$NC_COMPOSE_FILE" > /dev/null <<EOF
version: '3.8'

services:
  db:
    image: mariadb:latest
    container_name: ${NC_DB_CONTAINER}
    restart: unless-stopped
    command: --transaction-isolation=READ-COMMITTED --binlog-format=ROW
    volumes:
      - ${NC_DATA_DIR}/db:/var/lib/mysql
    environment:
      - MYSQL_ROOT_PASSWORD=${NC_DB_ROOT_PASSWORD}
      - MYSQL_PASSWORD=${NC_DB_PASSWORD}
      - MYSQL_DATABASE=nextcloud
      - MYSQL_USER=nextcloud
    mem_limit: 256m
    networks:
      - nextcloud-net

  app:
    image: nextcloud:latest
    container_name: ${NC_CONTAINER}
    restart: unless-stopped
    ports:
      - 8080:80
    links:
      - db
    volumes:
      - ${NC_DATA_DIR}/html:/var/www/html
    environment:
      - MYSQL_PASSWORD=${NC_DB_PASSWORD}
      - MYSQL_DATABASE=nextcloud
      - MYSQL_USER=nextcloud
      - MYSQL_HOST=db
    networks:
      - nextcloud-net
    depends_on:
      - db
    mem_limit: 512m

networks:
  nextcloud-net:
    driver: bridge
EOF

    print_status "Starting Nextcloud and MariaDB containers..."
    (cd "$(dirname "$NC_COMPOSE_FILE")" && sudo docker-compose -f "$NC_COMPOSE_FILE" up -d)

    print_status "Nextcloud setup complete."
    echo "Nextcloud will be available at http://$TAILSCALE_IP:8080 after a few minutes of initialization."
    echo "You will be prompted to create an admin account on your first visit."
}
