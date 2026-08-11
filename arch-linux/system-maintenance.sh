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
    # Print a clean, aligned status report for memory and disk usage
    echo "=== System Status ==="

    echo "Memory Usage:"
    # Header and Mem line, formatted into columns
    free -h | awk 'NR==1 || /Mem/ {printf "% -10s %8s %8s %8s %8s %8s\n", $1,$2,$3,$4,$5,$6}'

    echo ""
    echo "Disk Usage (root):"
    # Header and root filesystem line, formatted into columns
    df -h / | awk 'NR==1 || /\// {printf "% -20s %8s %8s %8s %8s %8s\n", $1,$2,$3,$4,$5,$6}'

    echo "====================="
}

# Main execution flow
main() {
    update_system
    clean_cache
    show_status
    echo "All tasks completed."
}

main "$@"
