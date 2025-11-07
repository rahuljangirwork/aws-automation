#!/bin/bash

source "$(dirname "${BASH_SOURCE[0]}")/config.sh"
source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"

install_tailscale() {
    print_status "Installing Tailscale VPN..."
    
    # Add Tailscale repository
    curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/$(lsb_release -cs).noarmor.gpg | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
    curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/$(lsb_release -cs).tailscale-keyring.list | sudo tee /etc/apt/sources.list.d/tailscale.list
    
    # Install Tailscale
    sudo apt-get update
    sudo apt-get install -y tailscale
    
    print_status "Tailscale installed successfully"
}

setup_tailscale() {
    print_status "Setting up Tailscale connection..."

    # Always run 'tailscale up' to ensure correct settings
    if [ -n "$TS_AUTH_KEY" ]; then
        print_status "Authenticating with auth key..."
        sudo tailscale up --authkey="${TS_AUTH_KEY}" --accept-dns=false --hostname="aws-rustdesk-server"
    else
        print_status "Running tailscale up... If needed, please authenticate in your browser."
        sudo tailscale up --accept-dns=false --hostname="aws-rustdesk-server"
    fi

    # Check status after attempting to bring it up
    if ! tailscale status >/dev/null 2>&1; then
        print_error "Tailscale failed to connect. Please check your authentication or network."
        exit 1
    fi

    TAILSCALE_IP=$(get_tailscale_ip)
    if [ ! -z "$TAILSCALE_IP" ]; then
        print_status "Tailscale is running. Current IP: $TAILSCALE_IP"
    else
        print_error "Could not get Tailscale IP after setup."
        exit 1
    fi
    
    # Enable IP forwarding
    echo 'net.ipv4.ip_forward = 1' | sudo tee /etc/sysctl.conf > /dev/null
    echo 'net.ipv6.conf.all.forwarding = 1' | sudo tee -a /etc/sysctl.conf > /dev/null
    sudo sysctl -p
}

get_tailscale_ip() {
    local ip=''
    
    # Wait for Tailscale to be fully connected
    sleep 5
    
    # Get Tailscale IP
    ip=$(tailscale ip -4 2>/dev/null | head -1 | tr -d ' \n\r')
    
    if [ -z "$ip" ]; then
        # Alternative method
        ip=$(ip addr show tailscale0 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)
    fi
    
    echo "$ip"
}
