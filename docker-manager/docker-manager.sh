#!/usr/bin/env bash

set -uo pipefail

# ============================================================
# Docker Manager
# ============================================================

CONFIG_DIR="$HOME/.docker-image-manager"
PROTECTED_FILE="$CONFIG_DIR/protected"

mkdir -p "$CONFIG_DIR"
touch "$PROTECTED_FILE"

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

is_protected() {
    local image_id="$1"

    grep -Fxq "$image_id" "$PROTECTED_FILE"
}

add_protected() {
    local image_id="$1"

    if ! is_protected "$image_id"; then
        echo "$image_id" >> "$PROTECTED_FILE"
    fi
}

remove_protected() {
    local image_id="$1"

    grep -Fxv "$image_id" "$PROTECTED_FILE" > "${PROTECTED_FILE}.tmp"
    mv "${PROTECTED_FILE}.tmp" "$PROTECTED_FILE"
}

# ------------------------------------------------------------
# Check Docker
# ------------------------------------------------------------

check_docker() {
    if ! command -v docker >/dev/null 2>&1; then
        echo -e "${RED}Docker is not installed or not in PATH.${RESET}"
        exit 1
    fi

    if ! docker info >/dev/null 2>&1; then
        echo -e "${RED}Cannot communicate with Docker.${RESET}"
        echo "Make sure Docker is running."
        exit 1
    fi
}

# ============================================================
# IMAGE FUNCTIONS
# ============================================================

list_images() {

    echo
    echo -e "${CYAN}${BOLD}🐳 Docker Images${RESET}"
    echo "============================================================"

    mapfile -t IMAGES < <(
        docker image ls --no-trunc \
        --format '{{.ID}}|{{.Repository}}:{{.Tag}}|{{.Size}}|{{.CreatedSince}}'
    )

    if [[ ${#IMAGES[@]} -eq 0 ]]; then
        echo "No Docker images found."
        return 1
    fi

    printf "%-5s %-30s %-15s %-15s\n" \
        "#" "IMAGE" "SIZE" "CREATED"

    echo "------------------------------------------------------------"

    local i=1

    for image in "${IMAGES[@]}"; do

        IFS='|' read -r image_id image_name image_size created <<< "$image"

        if is_protected "$image_id"; then
            status="${YELLOW}🛡 PROTECTED${RESET}"
        else
            status=""
        fi

        printf "%-5s %-30s %-15s %-15s %b\n" \
            "[$i]" "$image_name" "$image_size" "$created" "$status"

        ((i++))
    done

    echo

    return 0
}

# ------------------------------------------------------------
# Add protected images
# ------------------------------------------------------------

protect_images() {

    list_images || return

    echo
    echo -e "${YELLOW}Enter image numbers to protect.${RESET}"
    echo "Example: 1,3,5"
    echo

    read -rp "> " selection

    [[ -z "$selection" ]] && return

    IFS=',' read -ra NUMBERS <<< "$selection"

    local selected=()

    for number in "${NUMBERS[@]}"; do

        number="${number//[[:space:]]/}"

        if ! [[ "$number" =~ ^[0-9]+$ ]]; then
            echo -e "${RED}Invalid number: $number${RESET}"
            continue
        fi

        if (( number < 1 || number > ${#IMAGES[@]} )); then
            echo -e "${RED}Number out of range: $number${RESET}"
            continue
        fi

        index=$((number - 1))

        IFS='|' read -r image_id image_name image_size created \
            <<< "${IMAGES[$index]}"

        if is_protected "$image_id"; then
            echo -e "${YELLOW}Already protected: $image_name${RESET}"
            continue
        fi

        selected+=("$index")
    done

    if [[ ${#selected[@]} -eq 0 ]]; then
        echo "Nothing to protect."
        return
    fi

    echo
    echo -e "${BOLD}Images to protect:${RESET}"

    for index in "${selected[@]}"; do
        IFS='|' read -r image_id image_name image_size created \
            <<< "${IMAGES[$index]}"

        echo "  • $image_name ($image_size)"
    done

    echo

    if ! confirm "Add these images to protected list?"; then
        echo "Cancelled."
        return
    fi

    for index in "${selected[@]}"; do

        IFS='|' read -r image_id image_name image_size created \
            <<< "${IMAGES[$index]}"

        add_protected "$image_id"

        echo -e "${GREEN}✓ Protected:${RESET} $image_name"
    done
}

# ------------------------------------------------------------
# View protected images
# ------------------------------------------------------------

view_protected() {

    echo
    echo -e "${CYAN}${BOLD}🛡 Protected Images${RESET}"
    echo "============================================================"

    mapfile -t IMAGES < <(
        docker image ls --no-trunc \
        --format '{{.ID}}|{{.Repository}}:{{.Tag}}|{{.Size}}|{{.CreatedSince}}'
    )

    local found=0
    local i=1

    for image in "${IMAGES[@]}"; do

        IFS='|' read -r image_id image_name image_size created <<< "$image"

        if is_protected "$image_id"; then

            printf "%-5s %-30s %-15s %-15s\n" \
                "[$i]" "$image_name" "$image_size" "$created"

            ((i++))
            found=1
        fi
    done

    if [[ $found -eq 0 ]]; then
        echo "No protected images."
    fi
}

# ------------------------------------------------------------
# Remove protection
# ------------------------------------------------------------

unprotect_images() {

    mapfile -t IMAGES < <(
        docker image ls --no-trunc \
        --format '{{.ID}}|{{.Repository}}:{{.Tag}}|{{.Size}}|{{.CreatedSince}}'
    )

    local protected=()

    for image in "${IMAGES[@]}"; do

        IFS='|' read -r image_id image_name image_size created <<< "$image"

        if is_protected "$image_id"; then
            protected+=("$image")
        fi
    done

    if [[ ${#protected[@]} -eq 0 ]]; then
        echo "No protected images."
        return
    fi

    echo
    echo -e "${CYAN}${BOLD}🔓 Protected Images${RESET}"
    echo "============================================================"

    local i=1

    for image in "${protected[@]}"; do

        IFS='|' read -r image_id image_name image_size created <<< "$image"

        printf "%-5s %-30s %-15s\n" \
            "[$i]" "$image_name" "$image_size"

        ((i++))
    done

    echo
    read -rp "Enter numbers to unprotect (example: 1,3): " selection

    IFS=',' read -ra NUMBERS <<< "$selection"

    for number in "${NUMBERS[@]}"; do

        number="${number//[[:space:]]/}"

        if ! [[ "$number" =~ ^[0-9]+$ ]]; then
            echo -e "${RED}Invalid number: $number${RESET}"
            continue
        fi

        if (( number < 1 || number > ${#protected[@]} )); then
            echo -e "${RED}Invalid selection: $number${RESET}"
            continue
        fi

        index=$((number - 1))

        IFS='|' read -r image_id image_name image_size created \
            <<< "${protected[$index]}"

        remove_protected "$image_id"

        echo -e "${GREEN}✓ Protection removed:${RESET} $image_name"
    done
}

# ------------------------------------------------------------
# Delete images
# ------------------------------------------------------------

delete_images() {

    list_images || return

    echo
    echo -e "${RED}${BOLD}⚠️  Delete Images${RESET}"
    echo "Enter numbers separated by commas."
    echo "Example: 2,4,7"
    echo

    read -rp "> " selection

    [[ -z "$selection" ]] && return

    IFS=',' read -ra NUMBERS <<< "$selection"

    local selected=()

    for number in "${NUMBERS[@]}"; do

        number="${number//[[:space:]]/}"

        if ! [[ "$number" =~ ^[0-9]+$ ]]; then
            echo -e "${RED}Invalid number: $number${RESET}"
            continue
        fi

        if (( number < 1 || number > ${#IMAGES[@]} )); then
            echo -e "${RED}Number out of range: $number${RESET}"
            continue
        fi

        index=$((number - 1))

        IFS='|' read -r image_id image_name image_size created \
            <<< "${IMAGES[$index]}"

        # Protection check
        if is_protected "$image_id"; then
            echo -e "${YELLOW}🛡 Skipping protected image: $image_name${RESET}"
            continue
        fi

        # Prevent duplicate selections
        duplicate=0

        for existing in "${selected[@]}"; do
            [[ "$existing" == "$index" ]] && duplicate=1
        done

        (( duplicate == 0 )) && selected+=("$index")
    done

    if [[ ${#selected[@]} -eq 0 ]]; then
        echo
        echo "No images selected for deletion."
        return
    fi

    echo
    echo -e "${RED}${BOLD}Images that will be deleted:${RESET}"
    echo

    for index in "${selected[@]}"; do

        IFS='|' read -r image_id image_name image_size created \
            <<< "${IMAGES[$index]}"

        echo "  • $image_name ($image_size)"
    done

    echo

    if ! confirm "Permanently delete these images?"; then
        echo "Cancelled."
        return
    fi

    echo

    for index in "${selected[@]}"; do

        IFS='|' read -r image_id image_name image_size created \
            <<< "${IMAGES[$index]}"

        echo -e "${YELLOW}🗑 Deleting:${RESET} $image_name"

        if docker image rm "$image_id"; then
            echo -e "${GREEN}✓ Deleted${RESET}"
        else
            echo -e "${RED}✗ Failed to delete${RESET}"
        fi

        echo
    done
}

# ============================================================
# CONTAINER FUNCTIONS
# ============================================================

list_containers() {

    echo
    echo -e "${CYAN}${BOLD}🐳 Docker Containers${RESET}"
    echo "============================================================"

    mapfile -t CONTAINERS < <(
        docker ps -a --no-trunc \
        --format '{{.ID}}|{{.Names}}|{{.Image}}|{{.Status}}'
    )

    if [[ ${#CONTAINERS[@]} -eq 0 ]]; then
        echo "No containers found."
        return 1
    fi

    printf "%-5s %-25s %-30s %-20s\n" \
        "#" "NAME" "IMAGE" "STATUS"

    echo "------------------------------------------------------------"

    local i=1

    for container in "${CONTAINERS[@]}"; do

        IFS='|' read -r container_id container_name image status \
            <<< "$container"

        printf "%-5s %-25s %-30s %-20s\n" \
            "[$i]" "$container_name" "$image" "$status"

        ((i++))
    done

    echo

    return 0
}

# ------------------------------------------------------------
# Force delete containers
# ------------------------------------------------------------

delete_containers() {

    list_containers || return

    echo -e "${RED}${BOLD}💀 FORCE DELETE CONTAINERS${RESET}"
    echo
    echo "This uses:"
    echo
    echo "    docker rm -f"
    echo
    echo "Running containers will be forcefully stopped and removed."
    echo

    read -rp "Enter container numbers (example: 1,3,5): " selection

    [[ -z "$selection" ]] && return

    IFS=',' read -ra NUMBERS <<< "$selection"

    local selected=()

    for number in "${NUMBERS[@]}"; do

        number="${number//[[:space:]]/}"

        if ! [[ "$number" =~ ^[0-9]+$ ]]; then
            echo -e "${RED}Invalid number: $number${RESET}"
            continue
        fi

        if (( number < 1 || number > ${#CONTAINERS[@]} )); then
            echo -e "${RED}Number out of range: $number${RESET}"
            continue
        fi

        index=$((number - 1))

        duplicate=0

        for existing in "${selected[@]}"; do
            [[ "$existing" == "$index" ]] && duplicate=1
        done

        (( duplicate == 0 )) && selected+=("$index")
    done

    if [[ ${#selected[@]} -eq 0 ]]; then
        echo "No containers selected."
        return
    fi

    echo
    echo -e "${RED}${BOLD}Containers that will be FORCE DELETED:${RESET}"
    echo

    for index in "${selected[@]}"; do

        IFS='|' read -r container_id container_name image status \
            <<< "${CONTAINERS[$index]}"

        echo "  💀 $container_name"
        echo "     Image:  $image"
        echo "     Status: $status"
        echo
    done

    if ! confirm "FORCE DELETE these containers?"; then
        echo "Cancelled."
        return
    fi

    echo

    for index in "${selected[@]}"; do

        IFS='|' read -r container_id container_name image status \
            <<< "${CONTAINERS[$index]}"

        echo -e "${YELLOW}💀 Force deleting:${RESET} $container_name"

        if docker rm -f "$container_id"; then
            echo -e "${GREEN}✓ Deleted${RESET}"
        else
            echo -e "${RED}✗ Failed${RESET}"
        fi

        echo
    done
}

# ============================================================
# DOCKER DISK USAGE
# ============================================================

docker_usage() {

    echo
    echo -e "${CYAN}${BOLD}💾 Docker Disk Usage${RESET}"
    echo "============================================================"

    docker system df

    echo
}

# ============================================================
# MAIN MENU
# ============================================================

main_menu() {

    while true; do

        clear

        echo -e "${CYAN}${BOLD}"
        echo "╔══════════════════════════════════════════════╗"
        echo "║          🐳 Docker Manager                  ║"
        echo "╚══════════════════════════════════════════════╝"
        echo -e "${RESET}"

        echo "  1) 📋 List images"
        echo "  2) 🗑  Delete images"
        echo "  3) 🛡  Add protected images"
        echo "  4) 👀 View protected images"
        echo "  5) 🔓 Remove image protection"
        echo
        echo "  6) 📦 List containers"
        echo "  7) 💀 Force delete containers"
        echo
        echo "  8) 💾 Docker disk usage"
        echo
        echo "  0) 🚪 Exit"
        echo

        read -rp "Select option: " choice

        case "$choice" in

            1)
                list_images
                pause
                ;;

            2)
                delete_images
                pause
                ;;

            3)
                protect_images
                pause
                ;;

            4)
                view_protected
                pause
                ;;

            5)
                unprotect_images
                pause
                ;;

            6)
                list_containers
                pause
                ;;

            7)
                delete_containers
                pause
                ;;

            8)
                docker_usage
                pause
                ;;

            0)
                echo
                echo "Bye 👋"
                exit 0
                ;;

            *)
                echo
                echo -e "${RED}Invalid option.${RESET}"
                sleep 1
                ;;
        esac
    done
}

# ============================================================
# START
# ============================================================

check_docker
main_menu