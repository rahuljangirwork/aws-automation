#!/bin/bash

source ./scripts/config.sh
source ./scripts/utils.sh

install_efs_utils() {
    print_status "Installing Amazon EFS utilities..."
    
    sudo apt-get update
    sudo apt-get install -y git binutils nfs-common
    
    # Clone and build amazon-efs-utils
    cd /tmp
    git clone https://github.com/aws/efs-utils
    cd efs-utils
    ./build-deb.sh
    sudo apt-get -y install ./build/amazon-efs-utils*deb
    
    # Clean up
    cd ~
    rm -rf /tmp/efs-utils
    
    print_status "EFS utilities installed successfully"
}

mount_efs() {
    print_status "Mounting EFS file system..."
    
    # Create mount point
    sudo mkdir -p $DATA_DIR
    
    # Mount EFS using mount helper
    sudo mount -t efs -o tls $EFS_ID:/ $DATA_DIR
    
    if [ $? -eq 0 ]; then
        print_status "EFS mounted successfully at $DATA_DIR"
    else
        print_error "Failed to mount EFS"
        exit 1
    fi
    
    # Verify mount
    if mountpoint -q $DATA_DIR; then
        print_status "✓ EFS mount verified"
    else
        print_error "✗ EFS not mounted properly"
        exit 1
    fi
    
    # Set permissions
    sudo chown -R $USER:$USER $DATA_DIR
}

configure_efs_automount() {
    print_status "Configuring EFS auto-mount..."
    
    # Add to /etc/fstab for automatic mounting
    FSTAB_ENTRY="$EFS_ID:/ $DATA_DIR efs _netdev,tls,iam 0 0"
    
    # Check if entry already exists
    if ! grep -q "$EFS_ID" /etc/fstab; then
        echo "$FSTAB_ENTRY" | sudo tee -a /etc/fstab
        print_status "EFS auto-mount configured in /etc/fstab"
    else
        print_status "EFS already configured in /etc/fstab"
    fi
}
