#!/bin/bash

source ./scripts/config.sh
source ./scripts/utils.sh

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
    
    # Check if already connected
    if tailscale status >/dev/null 2>&1; then
        print_status "Tailscale is already running"
        TAILSCALE_IP=$(get_tailscale_ip)
        
        if [ ! -z "$TAILSCALE_IP" ]; then
            print_status "Current Tailscale IP: $TAILSCALE_IP"
        fi
    else
        print_warning "Tailscale needs to be authenticated"
        echo ""
        echo "=================================================="
        echo -e "${YELLOW}TAILSCALE AUTHENTICATION REQUIRED${NC}"
        echo "=================================================="
        echo ""
        echo "Run this command to authenticate Tailscale:"
        echo -e "${GREEN}sudo tailscale up${NC}"
        echo ""
        echo "This will provide a URL to authenticate in your browser."
        echo "After authentication, run this script again."
        echo ""
        exit 0
    fi
    
    # Enable IP forwarding for Tailscale (optional but recommended)
    echo 'net.ipv4.ip_forward = 1' | sudo tee -a /etc/sysctl.conf
    echo 'net.ipv6.conf.all.forwarding = 1' | sudo tee -a /etc/sysctl.conf
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
