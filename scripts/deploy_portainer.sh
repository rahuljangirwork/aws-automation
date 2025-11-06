#!/bin/bash

source ./scripts/config.sh
source ./scripts/utils.sh

run_portainer() {
    print_status "Setting up Portainer..."

    # Create docker volume
    sudo docker volume create $PORTAINER_DATA_VOLUME

    # Stop and remove existing container
    sudo docker stop $PORTAINER_CONTAINER 2>/dev/null || true
    sudo docker rm $PORTAINER_CONTAINER 2>/dev/null || true

    # Run Portainer
    sudo docker run -d --name $PORTAINER_CONTAINER \
        -p 9443:9443 -p 8000:8000 \
        --restart=always \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v $PORTAINER_DATA_VOLUME:/data \
        portainer/portainer-ce:lts

    if [ $? -eq 0 ]; then
        print_status "Portainer started successfully"
    else
        print_error "Failed to start Portainer"
        exit 1
    fi
}
