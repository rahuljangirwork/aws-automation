#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/setup.sh"

show_bootstrap_usage() {
    cat <<'EOF'
Usage: ./bootstrap.sh [--force-bootstrap]

Runs only the prerequisite phase (packages, Tailscale, EFS, directories).
Use --force-bootstrap to re-run even if it already completed.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --force-bootstrap|--force)
            FORCE_BOOTSTRAP=true
            ;;
        -h|--help)
            show_bootstrap_usage
            exit 0
            ;;
        *)
            show_bootstrap_usage
            exit 1
            ;;
    esac
    shift
done

check_root
run_bootstrap_phase
