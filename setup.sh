#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/scripts/config.sh"
source "$SCRIPT_DIR/scripts/utils.sh"
source "$SCRIPT_DIR/scripts/install_docker.sh"
source "$SCRIPT_DIR/scripts/install_tailscale.sh"
source "$SCRIPT_DIR/scripts/setup_efs.sh"
source "$SCRIPT_DIR/scripts/storage.sh"
source "$SCRIPT_DIR/scripts/deploy_rustdesk.sh"
source "$SCRIPT_DIR/scripts/deploy_portainer.sh"
source "$SCRIPT_DIR/scripts/deploy_npm.sh"
source "$SCRIPT_DIR/scripts/deploy_nextcloud.sh"
source "$SCRIPT_DIR/scripts/bootstrap_phase.sh"
source "$SCRIPT_DIR/scripts/services_phase.sh"

STATE_DIR="${STATE_DIR:-/var/local/aws-office}"
BOOTSTRAP_STATE_FILE="${BOOTSTRAP_STATE_FILE:-$STATE_DIR/bootstrap.done}"
RUN_BOOTSTRAP=true
RUN_SERVICES=true
FORCE_BOOTSTRAP=false

usage() {
    cat <<'EOF'
Usage: ./setup.sh [options]

Options:
  bootstrap           Run only the prerequisite/bootstrap phase (same as ./bootstrap.sh)
  services            Run only the interactive container deployment phase (same as ./deploy_services.sh)
  all (default)       Run bootstrap (skipping if already completed) and then deploy services
  --force-bootstrap   Re-run bootstrap phase even if it was completed earlier
  -h, --help          Show this help text
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            bootstrap|--bootstrap-only)
                RUN_BOOTSTRAP=true
                RUN_SERVICES=false
                ;;
            services|--services-only)
                RUN_BOOTSTRAP=false
                RUN_SERVICES=true
                ;;
            all|--all)
                RUN_BOOTSTRAP=true
                RUN_SERVICES=true
                ;;
            --force-bootstrap)
                FORCE_BOOTSTRAP=true
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                print_warning "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
        shift
    done
}

main() {
    > "$SCRIPT_DIR/last-script-logs.txt"
    exec &> >(tee -a "$SCRIPT_DIR/last-script-logs.txt")
    parse_args "$@"

    echo -e "${GREEN}"
    echo "========================================================="
    echo "    Interactive AWS Self-Hosted Service Installer"
    echo "========================================================="
    echo -e "${NC}"

    check_root

    if $RUN_BOOTSTRAP; then
        run_bootstrap_phase
    fi

    if $RUN_SERVICES; then
        run_services_phase
    fi

    if ! $RUN_BOOTSTRAP && ! $RUN_SERVICES; then
        print_warning "Nothing to do. Use 'bootstrap', 'services', or 'all'."
    fi
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
