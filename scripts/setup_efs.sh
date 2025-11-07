#!/bin/bash

SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_ROOT/config.sh"
source "$SCRIPT_ROOT/utils.sh"

mount_efs() {
    print_status "Mounting EFS file system using NFS..."

    mkdir -p "$DATA_DIR"
    local EFS_DNS="${EFS_ID}.efs.${AWS_REGION}.amazonaws.com"

    if mountpoint -q "$DATA_DIR"; then
        print_status "EFS already mounted at $DATA_DIR; skipping DNS wait."
    else
        print_status "Waiting for EFS DNS to resolve..."
        local RETRY_COUNT=0
        local MAX_RETRIES=10
        local RETRY_DELAY=15
        while ! getent hosts "$EFS_DNS" > /dev/null; do
            RETRY_COUNT=$((RETRY_COUNT + 1))
            if [ $RETRY_COUNT -gt $MAX_RETRIES ]; then
                print_error "EFS DNS name ($EFS_DNS) could not be resolved after several retries."
                exit 1
            fi
            print_status "DNS not ready, retrying in ${RETRY_DELAY}s... (${RETRY_COUNT}/${MAX_RETRIES})"
            sleep $RETRY_DELAY
        done
        print_status "EFS DNS resolved successfully."

        mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport "${EFS_DNS}:/" "$DATA_DIR"
        if [ $? -ne 0 ]; then
            print_error "Failed to mount EFS. Make sure the EFS Security Group allows NFS traffic from this instance."
            exit 1
        fi
    fi

    if mountpoint -q "$DATA_DIR"; then
        print_status "[OK] EFS mount verified"
        chown -R ubuntu:ubuntu "$DATA_DIR"
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
        echo "$FSTAB_ENTRY" | tee -a /etc/fstab
        print_status "EFS auto-mount configured in /etc/fstab"
    else
        print_status "EFS already configured in /etc/fstab"
    fi
}
