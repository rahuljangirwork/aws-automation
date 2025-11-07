#!/bin/bash

set -euo pipefail

# Source config and utils for variables and functions
source ./scripts/config.sh
source ./scripts/utils.sh

declare -a CHOICES
declare -a COMPOSE_CMD=()

detect_compose_cli() {
    if docker compose version >/dev/null 2>&1; then
        COMPOSE_CMD=("docker" "compose")
    elif command -v docker-compose >/dev/null 2>&1; then
        COMPOSE_CMD=("docker-compose")
    else
        COMPOSE_CMD=()
    fi
}

run_compose_down() {
    local compose_file="$1"
    local app_name="$2"

    if [ ! -f "$compose_file" ]; then
        print_warning "$app_name compose file not found at $compose_file. Skipping stack shutdown."
        return 1
    fi

    if [ ${#COMPOSE_CMD[@]} -eq 0 ]; then
        print_error "Neither 'docker compose' nor 'docker-compose' is available. Install Docker Compose to manage $app_name."
        return 1
    fi

    (cd "$(dirname "$compose_file")" && "${COMPOSE_CMD[@]}" -f "$compose_file" down -v)
}

safe_delete_path() {
    local target="$1"
    local label="$2"

    if [ -z "$target" ] || [ ! -d "$target" ]; then
        return
    fi

    if mountpoint -q "$target"; then
        print_status "$label is a mount point; deleting its contents only."
        find "$target" -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null || true
    else
        rm -rf "$target"
    fi
}

# --- Interactive Menu ---
show_destroy_menu() {
    echo -e "${YELLOW}Please choose which services to DESTROY and CLEAN UP:${NC}"
    echo "  1) Portainer"
    echo "  2) RustDesk Server"
    echo "  3) Nextcloud"
    echo "  4) Nginx Proxy Manager"
    echo "  5) Pi-hole + Unbound"
    echo "  ---------------------"
    echo "  99) DESTROY ALL"
    echo ""
    echo "You can select multiple services. For example, enter: 1 3"
    echo ""
    
    read -p "Enter your choices (space-separated): " -a CHOICES
    
    if [ ${#CHOICES[@]} -eq 0 ]; then
        print_error "No selection made. Exiting."
        exit 1
    fi
}

# --- Destruction Dispatcher ---
destroy_selected_apps() {
    print_warning "You are about to permanently delete the selected services AND all their data."
    read -p "Are you absolutely sure? (y/n): " CONFIRM
    if [ "$CONFIRM" != "y" ]; then
        echo "Aborting."
        exit 0
    fi

    print_status "Proceeding with destruction..."

    # Handle 'DESTROY ALL' option
    if [[ " ${CHOICES[*]} " =~ " 99 " ]]; then
        CHOICES=(1 2 3 4 5)
    fi

    for choice in "${CHOICES[@]}"; do
        case $choice in
            1)
                print_status "Destroying Portainer..."
                docker stop $PORTAINER_CONTAINER &>/dev/null || true
                docker rm $PORTAINER_CONTAINER &>/dev/null || true
                docker volume rm $PORTAINER_DATA_VOLUME &>/dev/null || true
                print_status "Portainer destroyed."
                ;;
            2)
                print_status "Destroying RustDesk Server..."
                docker stop $CONTAINER_NAME &>/dev/null || true
                docker rm $CONTAINER_NAME &>/dev/null || true
                print_status "Cleaning up RustDesk data at $DATA_DIR..."
                safe_delete_path "$DATA_DIR" "RustDesk data mount"
                print_status "RustDesk destroyed."
                ;;
            3)
                print_status "Destroying Nextcloud..."
                run_compose_down "$NC_COMPOSE_FILE" "Nextcloud" || true
                print_status "Cleaning up Nextcloud data at $NC_DATA_DIR..."
                safe_delete_path "$NC_DATA_DIR" "Nextcloud data"
                print_status "Nextcloud destroyed."
                ;;
            4)
                print_status "Destroying Nginx Proxy Manager..."
                run_compose_down "$NPM_COMPOSE_FILE" "Nginx Proxy Manager" || true
                print_status "Cleaning up Nginx Proxy Manager data at $NPM_DATA_DIR..."
                safe_delete_path "$NPM_DATA_DIR" "NPM data"
                print_status "Nginx Proxy Manager destroyed."
                ;;
            5)
                print_status "Destroying Pi-hole + Unbound..."
                run_compose_down "$PIHOLE_COMPOSE_FILE" "Pi-hole + Unbound" || true
                print_status "Cleaning up Pi-hole data at $PIHOLE_DATA_DIR..."
                safe_delete_path "$PIHOLE_DATA_DIR" "Pi-hole data"
                print_status "Pi-hole destroyed."
                ;;
            *)
                print_warning "Invalid choice: $choice. Skipping."
                ;;
        esac
    done
    
    print_status "Cleanup of crontab..."
    (crontab -l 2>/dev/null | grep -v "rustdesk_backup.sh") | crontab -

    echo -e "${GREEN}Destruction complete.${NC}"
}

# --- Main Execution ---
main() {
    echo -e "${RED}"
    echo "========================================================="
    echo "    Interactive Service Destroyer and Cleanup Tool"
    echo "========================================================="
    echo -e "${NC}"

    detect_compose_cli
    
    show_destroy_menu
    destroy_selected_apps
}

main "$@"
