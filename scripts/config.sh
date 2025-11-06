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
