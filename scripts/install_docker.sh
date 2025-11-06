#!/bin/bash

set -e

# Source the config file to get variables
source "$(dirname "$0")/config.sh"
# Source the print_status function
source "$(dirname "$0")/helpers.sh"

install_dependencies() {
    print_status "Installing prerequisites including unzip and Docker..."

    # Update package list
    sudo apt-get update

    # Install prerequisites
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y apt-transport-https ca-certificates curl software-properties-common unzip jq wget

    # Remove existing Docker GPG key to prevent conflicts
    sudo rm -f /usr/share/keyrings/docker-archive-keyring.gpg

    # Install Docker CE (official method)
    print_status "Setting up Docker repository..."
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    # Update and install Docker
    sudo apt-get update
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

    # Start and enable Docker
    sudo systemctl enable --now docker

    # Add user to docker group
    sudo usermod -aG docker $USER

    print_status "Docker installed successfully"

    # Install AWS CLI v2 if not present
    if ! command -v aws &> /dev/null; then
        print_status "Installing AWS CLI v2..."
        curl -s https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o awscliv2.zip
        unzip -q awscliv2.zip
        sudo ./aws/install
        rm -rf awscliv2.zip aws
        print_status "AWS CLI installed successfully"
    else
        print_status "AWS CLI already installed"
    fi
}

install_dependencies
