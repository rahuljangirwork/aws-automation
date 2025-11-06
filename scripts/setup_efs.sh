#!/bin/bash

source "$(dirname "${BASH_SOURCE[0]}")/config.sh"
source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"

mount_efs() {
    print_status "Mounting EFS file system using direct IP..."
    
    # Create mount point
    sudo mkdir -p $DATA_DIR

    # NOTE: Using direct IP address as a workaround for AWS DNS failure.
    # This IP corresponds to the mount target in subnet eu-north-1c.
    MOUNT_TARGET_IP="172.31.11.25"
    
    # Check if already mounted to prevent errors on re-run
    if ! mountpoint -q $DATA_DIR; then
        sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport ${MOUNT_TARGET_IP}:/ $DATA_DIR
        
        if [ $? -ne 0 ]; then
            print_error "Failed to mount EFS using IP. Check Security Group rules for NFS (port 2049)."
            exit 1
        fi
    else
        print_status "EFS already mounted at $DATA_DIR"
    fi

    # Verify mount & set permissions
    if mountpoint -q $DATA_DIR; then
        print_status "✓ EFS mount verified"
        sudo chown -R $USER:$USER $DATA_DIR
    else
        print_error "✗ EFS not mounted properly"
        exit 1
    fi
}

configure_efs_automount() {
    print_status "Configuring EFS auto-mount using direct IP..."
    
    MOUNT_TARGET_IP="172.31.11.25"
    FSTAB_ENTRY="${MOUNT_TARGET_IP}:/ $DATA_DIR nfs4 nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport,_netdev 0 0"
    
    if ! grep -q "${MOUNT_TARGET_IP}" /etc/fstab; then
        echo "$FSTAB_ENTRY" | sudo tee -a /etc/fstab
        print_status "EFS auto-mount configured in /etc/fstab"
    else
        print_status "EFS already configured in /etc/fstab"
    fi
}
