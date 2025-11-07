#!/bin/bash

: "${STATE_DIR:=/var/local/aws-office}"
: "${BOOTSTRAP_STATE_FILE:=${STATE_DIR}/bootstrap.done}"
: "${FORCE_BOOTSTRAP:=false}"

ensure_state_dir() {
    mkdir -p "$STATE_DIR"
}

bootstrap_completed() {
    [[ -f "$BOOTSTRAP_STATE_FILE" ]]
}

mark_bootstrap_complete() {
    ensure_state_dir
    date --iso-8601=seconds > "$BOOTSTRAP_STATE_FILE"
}

ensure_hosts_entry() {
    local hostname_entry="127.0.0.1 $(hostname)"
    if ! grep -Fxq "$hostname_entry" /etc/hosts; then
        echo "$hostname_entry" >> /etc/hosts
    fi
}

ensure_dns_configuration() {
    local resolver="/etc/resolv.conf"
    local desired="nameserver 172.31.0.2"

    if command -v chattr >/dev/null 2>&1; then
        chattr -i "$resolver" >/dev/null 2>&1 || true
    fi

    if grep -Fxq "$desired" "$resolver"; then
        print_status "DNS already points to AWS resolver ($desired)"
        return
    fi

    if [[ ! -f /etc/resolv.conf.aws-office.backup ]]; then
        cp "$resolver" /etc/resolv.conf.aws-office.backup >/dev/null 2>&1 || true
    fi

    print_status "Forcing DNS to AWS default resolver to ensure EFS resolution..."
    printf '%s\n' "$desired" > "$resolver"
}

ensure_tailscale_packages() {
    if command -v tailscale >/dev/null 2>&1; then
        print_status "Tailscale already installed"
    else
        install_tailscale
    fi
}

ensure_tailscale_connection() {
    if ! $FORCE_BOOTSTRAP && tailscale status >/dev/null 2>&1 && [[ -n "$(get_tailscale_ip)" ]]; then
        print_status "Tailscale is already connected"
        return
    fi

    setup_tailscale
}

run_bootstrap_phase() {
    ensure_state_dir

    if bootstrap_completed && ! $FORCE_BOOTSTRAP; then
        local completed_at
        completed_at=$(cat "$BOOTSTRAP_STATE_FILE" 2>/dev/null)
        print_status "Bootstrap previously completed (${completed_at:-unknown}). Skipping."
        return
    fi

    print_status "Starting prerequisite/bootstrap phase..."

    install_dependencies
    ensure_tailscale_packages
    ensure_tailscale_connection
    ensure_hosts_entry
    ensure_dns_configuration
    mount_efs
    configure_efs_automount
    create_directories

    mark_bootstrap_complete
    print_status "Bootstrap phase finished."
}
