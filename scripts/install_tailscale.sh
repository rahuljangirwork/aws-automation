#!/bin/bash

source "$(dirname "${BASH_SOURCE[0]}")/config.sh"
source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"

install_tailscale() {
    print_status "Installing Tailscale VPN..."
    
    # Add Tailscale repository
    curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/$(lsb_release -cs).noarmor.gpg | tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
    curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/$(lsb_release -cs).tailscale-keyring.list | tee /etc/apt/sources.list.d/tailscale.list
    
    # Install Tailscale
    apt-get update
    apt-get install -y tailscale
    
    print_status "Tailscale installed successfully"
}

setup_tailscale() {
    print_status "Setting up Tailscale connection..."
    
    # Check if Tailscale is already running and authenticated
    local backend_state=""
    if command -v tailscale >/dev/null 2>&1; then
        backend_state=$(tailscale status --json 2>/dev/null | grep -o '"BackendState":"[^"]*"' | cut -d'"' -f4)
    fi
    
    if [ "$backend_state" = "Running" ]; then
        print_status "Tailscale is already authenticated and running"
        TAILSCALE_IP=$(get_tailscale_ip)
        if [ ! -z "$TAILSCALE_IP" ]; then
            print_status "Current Tailscale IP: $TAILSCALE_IP"
            # Enable IP forwarding
            setup_ip_forwarding
            return 0
        fi
    fi
    
    print_status "Tailscale not authenticated. Starting authentication process..."

    # Check if auth key is provided
    if [ -n "${TS_AUTH_KEY:-}" ]; then
        print_status "Authenticating with auth key..."
        sudo tailscale up --authkey="${TS_AUTH_KEY}" --accept-dns=false --hostname="aws-rustdesk-server"
    else
        print_status "===================================================="
        print_status "MANUAL AUTHENTICATION REQUIRED"
        print_status "===================================================="
        print_status "Running tailscale up..."
        print_status ""
        print_status "Please follow these steps:"
        print_status "1. Copy the authentication URL that will appear below"
        print_status "2. Open it in your browser"
        print_status "3. Login and approve the device"
        print_status "4. This script will automatically continue after approval"
        print_status ""
        print_status "Starting authentication process..."
        print_status "===================================================="
        
        # Run tailscale up and wait for authentication
        sudo tailscale up --accept-dns=false --hostname="aws-rustdesk-server"
    fi

    # Wait a moment for connection to establish
    sleep 3

    # Verify connection after authentication
    backend_state=$(tailscale status --json 2>/dev/null | grep -o '"BackendState":"[^"]*"' | cut -d'"' -f4)
    if [ "$backend_state" != "Running" ]; then
        print_error "Tailscale failed to connect. Please check your authentication or network."
        print_error "Current backend state: $backend_state"
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
    setup_ip_forwarding
}

setup_ip_forwarding() {
    # Enable IP forwarding
    echo 'net.ipv4.ip_forward = 1' | tee /etc/sysctl.conf > /dev/null
    echo 'net.ipv6.conf.all.forwarding = 1' | tee -a /etc/sysctl.conf > /dev/null
    sysctl -p
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
