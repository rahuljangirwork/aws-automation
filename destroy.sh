#!/bin/bash

# Source config and utils for variables and functions
source ./scripts/config.sh
source ./scripts/utils.sh

declare -a CHOICES

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
                if [ -d "$DATA_DIR" ]; then
                    print_status "Cleaning up RustDesk data at $DATA_DIR..."
                    rm -rf "$DATA_DIR"
                fi
                print_status "RustDesk destroyed."
                ;;
            3)
                print_status "Destroying Nextcloud..."
                if [ -f "$NC_COMPOSE_FILE" ]; then
                    (cd "$(dirname "$NC_COMPOSE_FILE")" && docker-compose -f "$NC_COMPOSE_FILE" down -v)
                    print_status "Cleaning up Nextcloud data at $NC_DATA_DIR..."
                    rm -rf "$NC_DATA_DIR"
                else
                    print_warning "Nextcloud compose file not found. Skipping."
                fi
                print_status "Nextcloud destroyed."
                ;;
            4)
                print_status "Destroying Nginx Proxy Manager..."
                if [ -f "$NPM_COMPOSE_FILE" ]; then
                    (cd "$(dirname "$NPM_COMPOSE_FILE")" && docker-compose -f "$NPM_COMPOSE_FILE" down -v)
                    print_status "Cleaning up Nginx Proxy Manager data at $NPM_DATA_DIR..."
                    rm -rf "$NPM_DATA_DIR"
                else
                    print_warning "NPM compose file not found. Skipping."
                fi
                print_status "Nginx Proxy Manager destroyed."
                ;;
            5)
                print_status "Destroying Pi-hole + Unbound..."
                if [ -f "$PIHOLE_COMPOSE_FILE" ]; then
                    (cd "$(dirname "$PIHOLE_COMPOSE_FILE")" && docker-compose -f "$PIHOLE_COMPOSE_FILE" down -v)
                    print_status "Cleaning up Pi-hole data at $PIHOLE_DATA_DIR..."
                    rm -rf "$PIHOLE_DATA_DIR"
                else
                    print_warning "Pi-hole compose file not found. Skipping."
                fi
                print_status "Pi-hole destroyed."
                ;;
            *)
                print_warning "Invalid choice: $choice. Skipping."
                ;;
        esac
    done
    
    print_status "Cleanup of crontab..."
    (crontab -l 2>/dev/null | grep -v "rustdesk_backup.sh") | crontab -

    echo -e "${GREEN}✅ Destruction complete.${NC}"
}

# --- Main Execution ---
main() {
    echo -e "${RED}"
    echo "========================================================="
    echo "    Interactive Service Destroyer and Cleanup Tool"
    echo "========================================================="
    echo -e "${NC}"
    
    show_destroy_menu
    destroy_selected_apps
}

main "$@"
