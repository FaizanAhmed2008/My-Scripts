#!/usr/bin/env bash

set -uo pipefail

# ============================================================
# Interactive System Maintenance Script
# ============================================================

# ------------------------------------------------------------
# Colors
# ------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# ------------------------------------------------------------
# Helpers
# ------------------------------------------------------------
pause() {
    echo
    read -rp "Press Enter to continue..."
}

confirm() {
    local answer
    read -rp "$1 [y/N]: " answer
    [[ "$answer" =~ ^[Yy]$ ]]
}

# ------------------------------------------------------------
# System Detection
# ------------------------------------------------------------
detect_package_manager() {
    PKG_MANAGER=""
    UPDATE_CMD=""
    CLEAN_CMD=""

    if command -v paru >/dev/null 2>&1; then
        PKG_MANAGER="paru"
        UPDATE_CMD="paru -Syu"
        CLEAN_CMD="paru -Sc"
    elif command -v yay >/dev/null 2>&1; then
        PKG_MANAGER="yay"
        UPDATE_CMD="yay -Syu"
        CLEAN_CMD="yay -Sc"
    elif command -v pacman >/dev/null 2>&1; then
        PKG_MANAGER="pacman"
        UPDATE_CMD="sudo pacman -Syu"
        CLEAN_CMD="sudo pacman -Sc"
    elif command -v apt-get >/dev/null 2>&1; then
        PKG_MANAGER="apt"
        UPDATE_CMD="sudo apt update && sudo apt upgrade -y"
        CLEAN_CMD="sudo apt autoremove -y && sudo apt clean"
    elif command -v dnf >/dev/null 2>&1; then
        PKG_MANAGER="dnf"
        UPDATE_CMD="sudo dnf upgrade -y"
        CLEAN_CMD="sudo dnf clean all"
    elif command -v zypper >/dev/null 2>&1; then
        PKG_MANAGER="zypper"
        UPDATE_CMD="sudo zypper refresh && sudo zypper update -y"
        CLEAN_CMD="sudo zypper clean"
    elif command -v flatpak >/dev/null 2>&1; then
        PKG_MANAGER="flatpak"
        UPDATE_CMD="flatpak update -y"
        CLEAN_CMD="flatpak uninstall --unused -y"
    elif command -v snap >/dev/null 2>&1; then
        PKG_MANAGER="snap"
        UPDATE_CMD="sudo snap refresh"
        CLEAN_CMD="sudo snap set system refresh.retain=2"
    elif command -v nix-env >/dev/null 2>&1; then
        PKG_MANAGER="nix"
        UPDATE_CMD="nix-channel --update && nix-env -u"
        CLEAN_CMD="nix-collect-garbage -d"
    else
        echo -e "${RED}Unsupported package manager. Cannot update system automatically.${RESET}"
        pause
        exit 1
    fi
}

# ------------------------------------------------------------
# Core Functions
# ------------------------------------------------------------
update_system() {
    echo -e "${CYAN}${BOLD}🔄 Updating System (${PKG_MANAGER})${RESET}"
    echo "============================================================"
    
    if confirm "Do you want to proceed with the system update?"; then
        echo -e "${YELLOW}Running: ${UPDATE_CMD}${RESET}"
        eval "$UPDATE_CMD"
        echo -e "${GREEN}✓ Update completed.${RESET}"
    else
        echo "Update cancelled."
    fi
}

clean_cache() {
    echo -e "${CYAN}${BOLD}🧹 Cleaning Cache & Temp Files${RESET}"
    echo "============================================================"

    if confirm "Proceed with cleaning package cache and /tmp directory?"; then
        echo -e "${YELLOW}Running package cache clean (${CLEAN_CMD})...${RESET}"
        eval "$CLEAN_CMD"

        echo -e "${YELLOW}Cleaning /tmp files...${RESET}"
        sudo rm -rf /tmp/* 2>/dev/null || true

        echo -e "${GREEN}✓ Cleaning completed.${RESET}"
    else
        echo "Cleaning cancelled."
    fi
}

clean_trash() {
    echo -e "${CYAN}${BOLD}🗑️  Cleaning Trash${RESET}"
    echo "============================================================"

    local user_trash="$HOME/.local/share/Trash"
    local root_trash="/root/.local/share/Trash"
    local cleaned=0

    if confirm "Proceed with cleaning user and root trash directories?"; then
        if [[ -d "$user_trash/files" ]] || [[ -d "$user_trash/info" ]]; then
            echo -e "${YELLOW}Cleaning user trash ($user_trash)...${RESET}"
            rm -rf "$user_trash/files"/* "$user_trash/info"/* 2>/dev/null || true
            cleaned=1
        else
            echo -e "${GREEN}User trash already empty.${RESET}"
        fi

        if [[ $EUID -eq 0 ]] || sudo -n true 2>/dev/null; then
            if [[ -d "$root_trash/files" ]] || [[ -d "$root_trash/info" ]]; then
                echo -e "${YELLOW}Cleaning root trash ($root_trash)...${RESET}"
                sudo rm -rf "$root_trash/files"/* "$root_trash/info"/* 2>/dev/null || true
                cleaned=1
            else
                echo -e "${GREEN}Root trash already empty.${RESET}"
            fi
        else
            echo -e "${YELLOW}Skipping root trash (requires sudo).${RESET}"
        fi

        if [[ $cleaned -eq 1 ]]; then
            echo -e "${GREEN}✓ Trash cleaning completed.${RESET}"
        else
            echo -e "${GREEN}✓ No trash to clean.${RESET}"
        fi
    else
        echo "Trash cleaning cancelled."
    fi
}

show_status() {
    echo -e "${CYAN}${BOLD}📊 System Status${RESET}"
    echo "============================================================"
    
    echo -e "${YELLOW}Memory Usage:${RESET}"
    free -h | awk 'NR==1 || /Mem/ {printf "% -10s %8s %8s %8s %8s %8s\n", $1,$2,$3,$4,$5,$6}'
    
    echo ""
    echo -e "${YELLOW}Disk Usage (root):${RESET}"
    df -h / | awk 'NR==1 || /\// {printf "% -20s %8s %8s %8s %8s %8s\n", $1,$2,$3,$4,$5,$6}'
}

perform_all() {
    update_system
    echo
    clean_cache
    echo
    clean_trash
    echo
    show_status
}

# ------------------------------------------------------------
# Main Menu
# ------------------------------------------------------------
main_menu() {
    detect_package_manager

    while true; do
        clear
        echo -e "${BLUE}${BOLD}========================================${RESET}"
        echo -e "${GREEN}${BOLD}       System Maintenance Utility       ${RESET}"
        echo -e "${BLUE}${BOLD}========================================${RESET}"
        echo -e "Detected Package Manager: ${YELLOW}${PKG_MANAGER}${RESET}"
        echo
        echo -e "  [1] 🔄 Update System"
        echo -e "  [2] 🧹 Clean Cache & Temp Files"
        echo -e "  [3] 🗑️  Clean Trash"
        echo -e "  [4] 📊 Show System Status"
        echo -e "  [5] 🚀 Perform All Tasks"
        echo -e "  [0] ❌ Exit"
        echo
        read -rp "Select an option [0-5]: " choice

        case "$choice" in
            1)
                echo
                update_system
                pause
                ;;
            2)
                echo
                clean_cache
                pause
                ;;
            3)
                echo
                clean_trash
                pause
                ;;
            4)
                echo
                show_status
                pause
                ;;
            5)
                echo
                perform_all
                pause
                ;;
            0)
                echo -e "${GREEN}Exiting...${RESET}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option!${RESET}"
                pause
                ;;
        esac
    done
}

main_menu
