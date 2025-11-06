#!/bin/bash

print_status() {
    echo "-----> $1"
}

print_error() {
    echo "-----> Error: $1" >&2
}
