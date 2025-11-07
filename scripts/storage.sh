#!/bin/bash

SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_ROOT/config.sh"
source "$SCRIPT_ROOT/utils.sh"

create_directories() {
    print_status "Preparing shared RustDesk data directories..."
    mkdir -p "$DATA_DIR/api" "$DATA_DIR/server"

    local owner="${SUDO_USER:-$USER}"
    if id "$owner" >/dev/null 2>&1; then
        chown -R "$owner:$owner" "$DATA_DIR"
    else
        chown -R root:root "$DATA_DIR"
    fi
}
