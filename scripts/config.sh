#!/bin/bash

# AWS Configuration
AWS_REGION='eu-north-1'
EFS_ID='fs-03bf8df05a4cfb96c'

# RustDesk Configuration
CONTAINER_NAME='rustdesk-server'
IMAGE='lejianwen/rustdesk-api:full-s6'
DATA_DIR='/data/rustdesk'

# Portainer Configuration
PORTAINER_CONTAINER='portainer'
PORTAINER_DATA_VOLUME='portainer_data'

# Tailscale Configuration
TAILSCALE_IP=''

# Nginx Proxy Manager Configuration
NPM_CONTAINER='npm'
NPM_DATA_DIR='/data/npm'
NPM_COMPOSE_FILE='/data/npm/docker-compose.yml'

# Nextcloud Configuration
NC_CONTAINER='nextcloud'
NC_DB_CONTAINER='nextcloud-db'
NC_DATA_DIR='/data/nextcloud'
NC_COMPOSE_FILE='/data/nextcloud/docker-compose.yml'
NC_DB_ROOT_PASSWORD='$(openssl rand -base64 16)'
NC_DB_PASSWORD='$(openssl rand -base64 16)'

# Pi-hole + Unbound Configuration
PIHOLE_CONTAINER='pihole'
PIHOLE_DATA_DIR='/data/pihole'
PIHOLE_COMPOSE_FILE='/data/pihole/docker-compose.yml'
