#!/usr/bin/env bash

# Simple system maintenance script for Arch Linux
# Performs update/upgrade, cleans cache, and shows memory & disk usage.

set -e

# Update and upgrade the system
update_system() {
    echo "Updating package database and upgrading packages..."
    sudo pacman -Syu --noconfirm
}

# Clean package cache and temporary files
clean_cache() {
    echo "Cleaning package cache..."
    echo "Removing temporary files..."
    sudo rm -rf /tmp/*
}

# Show memory and disk usage in a clean format
show_status() {
    echo "--- Memory Usage ---"
    free -h | awk 'NR==1 || /Mem/ {print}'
    echo "--- Disk Usage (root) ---"
    df -h / | awk 'NR==1 || /\// {print}'
}

# Main execution flow
main() {
    update_system
    clean_cache
    show_status
    echo "All tasks completed."
}

main "$@"
