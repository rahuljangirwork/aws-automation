#!/bin/bash

SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_ROOT/config.sh"

source "$SCRIPT_ROOT/utils.sh"

# Ensure DNS resolution works
ensure_dns_resolution() {
    print_status "Ensuring DNS resolution..."
    
    # Add AWS DNS servers if not already present
    if ! grep -q "nameserver 8.8.8.8" /etc/resolv.conf; then
        echo "nameserver 8.8.8.8" | sudo tee -a /etc/resolv.conf >/dev/null
        echo "nameserver 8.8.4.4" | sudo tee -a /etc/resolv.conf >/dev/null
        print_status "Added DNS servers to /etc/resolv.conf"
    fi
    
    # For AWS metadata
    echo "nameserver 169.254.169.253" | sudo tee -a /etc/resolv.conf >/dev/null
}

mount_efs() {
    print_status "Mounting EFS file system using NFS..."
    
    mkdir -p "$DATA_DIR"
    
    local EFS_DNS="${EFS_ID}.efs.${AWS_REGION}.amazonaws.com"
    
    print_status "EFS DNS: $EFS_DNS"
    print_status "EFS Region: $AWS_REGION"
    print_status "Mount point: $DATA_DIR"
    
    if mountpoint -q "$DATA_DIR"; then
        print_status "EFS already mounted at $DATA_DIR; skipping DNS wait."
        return 0
    fi
    
    # Ensure DNS is configured
    ensure_dns_resolution
    
    print_status "Waiting for EFS DNS to resolve..."
    
    local RETRY_COUNT=0
    local MAX_RETRIES=15
    local RETRY_DELAY=10
    
    # Try to resolve DNS
    while ! getent hosts "$EFS_DNS" > /dev/null 2>&1; do
        RETRY_COUNT=$((RETRY_COUNT + 1))
        
        if [ $RETRY_COUNT -gt $MAX_RETRIES ]; then
            print_error "EFS DNS name ($EFS_DNS) could not be resolved after $MAX_RETRIES retries"
            print_error "Attempting to use IP-based mount as fallback..."
            
            # Try direct mount with region endpoint
            local EFS_ENDPOINT="${EFS_ID}.efs.${AWS_REGION}.amazonaws.com"
            print_status "Trying mount with: ${EFS_ENDPOINT}:/"
            
            sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport "$EFS_ENDPOINT:/" "$DATA_DIR" 2>/dev/null
            
            if [ $? -eq 0 ]; then
                print_status "EFS mounted successfully via fallback method"
                break
            else
                print_error "Failed to mount EFS. Possible causes:"
                print_error "1. Security Group doesn't allow NFS (port 2049) from this instance"
                print_error "2. EC2 and EFS are not in the same VPC"
                print_error "3. Network connectivity issue"
                print_error ""
                print_error "Debug info:"
                print_error "- EC2 instance region: $AWS_REGION"
                print_error "- EFS ID: $EFS_ID"
                print_error "- Expected DNS: $EFS_DNS"
                exit 1
            fi
        fi
        
        print_status "DNS not ready, retrying in ${RETRY_DELAY}s... (${RETRY_COUNT}/${MAX_RETRIES})"
        sleep $RETRY_DELAY
    done
    
    if [ $RETRY_COUNT -le $MAX_RETRIES ]; then
        print_status "EFS DNS resolved successfully on attempt $RETRY_COUNT"
        
        # Perform the mount
        sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport "${EFS_DNS}:/" "$DATA_DIR"
        
        if [ $? -ne 0 ]; then
            print_error "Failed to mount EFS after DNS resolved"
            print_error "Make sure the EFS Security Group allows NFS traffic (port 2049) from this instance"
            exit 1
        fi
    fi
    
    # Verify mount
    if mountpoint -q "$DATA_DIR"; then
        print_status "[OK] EFS mount verified"
        sudo chown -R ubuntu:ubuntu "$DATA_DIR"
    else
        print_error "[FAIL] EFS not mounted properly"
        exit 1
    fi
}

configure_efs_automount() {
    print_status "Configuring EFS auto-mount..."
    
    local EFS_DNS="${EFS_ID}.efs.${AWS_REGION}.amazonaws.com"
    local FSTAB_ENTRY="${EFS_DNS}:/ $DATA_DIR nfs4 nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport,_netdev 0 0"
    
    if ! grep -q "${EFS_DNS}" /etc/fstab; then
        echo "$FSTAB_ENTRY" | sudo tee -a /etc/fstab >/dev/null
        print_status "EFS auto-mount configured in /etc/fstab"
    else
        print_status "EFS already configured in /etc/fstab"
    fi
}
