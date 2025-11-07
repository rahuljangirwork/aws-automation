#!/bin/bash

# Define color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to print status messages
print_status() {
    echo -e "${GREEN}-----> $1${NC}"
}

# Function to print warning messages
print_warning() {
    echo -e "${YELLOW}-----> WARNING: $1${NC}" >&2
}

# Function to print error messages
print_error() {
    echo -e "${RED}-----> ERROR: $1${NC}" >&2
}

# Function to check if the script is run as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "Run this script with sudo or as root."
        exit 1
    fi
}
