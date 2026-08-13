#Requires -Version 5.0

# ============================================================
# Docker Manager (PowerShell)
# ============================================================

$ErrorActionPreference = "Continue"

$CONFIG_DIR = "$HOME\.docker-image-manager"
$PROTECTED_FILE = "$CONFIG_DIR\protected"

# Ensure config directory exists
if (-not (Test-Path $CONFIG_DIR)) {
    New-Item -ItemType Directory -Path $CONFIG_DIR -Force | Out-Null
}

if (-not (Test-Path $PROTECTED_FILE)) {
    New-Item -ItemType File -Path $PROTECTED_FILE -Force | Out-Null
}

# ============================================================
# Colors
# ============================================================

function Write-Red {
    Write-Host $args -ForegroundColor Red
}

function Write-Green {
    Write-Host $args -ForegroundColor Green
}

function Write-Yellow {
    Write-Host $args -ForegroundColor Yellow
}

function Write-Cyan {
    Write-Host $args -ForegroundColor Cyan
}

function Write-Bold {
    Write-Host $args -NoNewline
    Write-Host $args
}

# ============================================================
# Helpers
# ============================================================

function Pause-Script {
    Write-Host ""
    Read-Host "Press Enter to continue..."
}

function Confirm-Action {
    param([string]$Message)
    
    $response = Read-Host "$Message [y/N]"
    return $response -match "^[Yy]$"
}

function Test-Protected {
    param([string]$ImageId)
    
    if (-not (Test-Path $PROTECTED_FILE)) {
        return $false
    }
    
    $protected = @(Get-Content $PROTECTED_FILE -ErrorAction SilentlyContinue)
    return $protected -contains $ImageId
}

function Add-Protected {
    param([string]$ImageId)
    
    if (-not (Test-Protected $ImageId)) {
        Add-Content -Path $PROTECTED_FILE -Value $ImageId
    }
}

function Remove-Protected {
    param([string]$ImageId)
    
    $protected = @(Get-Content $PROTECTED_FILE -ErrorAction SilentlyContinue)
    $protected = $protected | Where-Object { $_ -ne $ImageId }
    Set-Content -Path $PROTECTED_FILE -Value $protected -Force
}

# ============================================================
# Check Docker
# ============================================================

function Test-Docker {
    try {
        $null = docker info 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Red "Cannot communicate with Docker."
            Write-Host "Make sure Docker is running."
            exit 1
        }
    }
    catch {
        Write-Red "Docker is not installed or not in PATH."
        exit 1
    }
}

# ============================================================
# IMAGE FUNCTIONS
# ============================================================

function List-Images {
    Write-Host ""
    Write-Cyan "🐳 Docker Images"
    Write-Host "============================================================"

    $images = @(docker image ls --no-trunc --format '{{.ID}}|{{.Repository}}:{{.Tag}}|{{.Size}}|{{.CreatedSince}}' 2>$null)

    if ($images.Count -eq 0) {
        Write-Host "No Docker images found."
        return $false
    }

    $global:IMAGES = $images

    Write-Host ("{0,-5} {1,-30} {2,-15} {3,-15}" -f "#", "IMAGE", "SIZE", "CREATED")
    Write-Host "------------------------------------------------------------"

    $i = 1
    foreach ($image in $images) {
        $parts = $image -split '\|'
        $imageId = $parts[0]
        $imageName = $parts[1]
        $imageSize = $parts[2]
        $created = $parts[3]

        $status = ""
        if (Test-Protected $imageId) {
            $status = " "
            Write-Host ("{0,-5} {1,-30} {2,-15} {3,-15}" -f "[$i]", $imageName, $imageSize, $created) -NoNewline
            Write-Yellow "🛡 PROTECTED"
        }
        else {
            Write-Host ("{0,-5} {1,-30} {2,-15} {3,-15}" -f "[$i]", $imageName, $imageSize, $created)
        }

        $i++
    }

    Write-Host ""
    return $true
}

# ============================================================
# Protect Images
# ============================================================

function Protect-Images {
    if (-not (List-Images)) {
        return
    }

    Write-Yellow "Enter image numbers to protect."
    Write-Host "Example: 1,3,5"
    Write-Host ""

    $selection = Read-Host "> "

    if ([string]::IsNullOrEmpty($selection)) {
        return
    }

    $numbers = $selection -split ','
    $selected = @()

    foreach ($number in $numbers) {
        $number = $number -replace '\s+', ''

        if ($number -notmatch '^\d+$') {
            Write-Red "Invalid number: $number"
            continue
        }

        $num = [int]$number
        if ($num -lt 1 -or $num -gt $global:IMAGES.Count) {
            Write-Red "Number out of range: $number"
            continue
        }

        $index = $num - 1
        $image = $global:IMAGES[$index]
        $imageId = ($image -split '\|')[0]
        $imageName = ($image -split '\|')[1]

        if (Test-Protected $imageId) {
            Write-Yellow "Already protected: $imageName"
            continue
        }

        $selected += $index
    }

    if ($selected.Count -eq 0) {
        Write-Host "Nothing to protect."
        return
    }

    Write-Host ""
    Write-Host "Images to protect:" -NoNewline
    Write-Host "" -ForegroundColor Cyan

    foreach ($index in $selected) {
        $image = $global:IMAGES[$index]
        $imageName = ($image -split '\|')[1]
        $imageSize = ($image -split '\|')[2]
        Write-Host "  • $imageName ($imageSize)"
    }

    Write-Host ""

    if (-not (Confirm-Action "Add these images to protected list?")) {
        Write-Host "Cancelled."
        return
    }

    foreach ($index in $selected) {
        $image = $global:IMAGES[$index]
        $imageId = ($image -split '\|')[0]
        $imageName = ($image -split '\|')[1]

        Add-Protected $imageId
        Write-Green "✓ Protected:" $imageName
    }
}

# ============================================================
# View Protected Images
# ============================================================

function View-Protected {
    Write-Host ""
    Write-Cyan "🛡 Protected Images"
    Write-Host "============================================================"

    $images = @(docker image ls --no-trunc --format '{{.ID}}|{{.Repository}}:{{.Tag}}|{{.Size}}|{{.CreatedSince}}' 2>$null)

    $found = $false
    $i = 1

    foreach ($image in $images) {
        $imageId = ($image -split '\|')[0]
        $imageName = ($image -split '\|')[1]
        $imageSize = ($image -split '\|')[2]
        $created = ($image -split '\|')[3]

        if (Test-Protected $imageId) {
            Write-Host ("{0,-5} {1,-30} {2,-15} {3,-15}" -f "[$i]", $imageName, $imageSize, $created)
            $i++
            $found = $true
        }
    }

    if (-not $found) {
        Write-Host "No protected images."
    }

    Write-Host ""
}

# ============================================================
# Unprotect Images
# ============================================================

function Unprotect-Images {
    $images = @(docker image ls --no-trunc --format '{{.ID}}|{{.Repository}}:{{.Tag}}|{{.Size}}|{{.CreatedSince}}' 2>$null)

    $protected = @()

    foreach ($image in $images) {
        $imageId = ($image -split '\|')[0]
        if (Test-Protected $imageId) {
            $protected += $image
        }
    }

    if ($protected.Count -eq 0) {
        Write-Host "No protected images."
        return
    }

    Write-Host ""
    Write-Cyan "🔓 Protected Images"
    Write-Host "============================================================"

    $i = 1

    foreach ($image in $protected) {
        $imageName = ($image -split '\|')[1]
        $imageSize = ($image -split '\|')[2]
        Write-Host ("{0,-5} {1,-30} {2,-15}" -f "[$i]", $imageName, $imageSize)
        $i++
    }

    Write-Host ""
    $selection = Read-Host "Enter numbers to unprotect (example: 1,3)"

    $numbers = $selection -split ','

    foreach ($number in $numbers) {
        $number = $number -replace '\s+', ''

        if ($number -notmatch '^\d+$') {
            Write-Red "Invalid number: $number"
            continue
        }

        $num = [int]$number
        if ($num -lt 1 -or $num -gt $protected.Count) {
            Write-Red "Invalid selection: $number"
            continue
        }

        $index = $num - 1
        $image = $protected[$index]
        $imageId = ($image -split '\|')[0]
        $imageName = ($image -split '\|')[1]

        Remove-Protected $imageId
        Write-Green "✓ Protection removed:" $imageName
    }
}

# ============================================================
# Delete Images
# ============================================================

function Delete-Images {
    if (-not (List-Images)) {
        return
    }

    Write-Red "⚠️  Delete Images"
    Write-Host "Enter numbers separated by commas."
    Write-Host "Example: 2,4,7"
    Write-Host ""

    $selection = Read-Host "> "

    if ([string]::IsNullOrEmpty($selection)) {
        return
    }

    $numbers = $selection -split ','
    $selected = @()

    foreach ($number in $numbers) {
        $number = $number -replace '\s+', ''

        if ($number -notmatch '^\d+$') {
            Write-Red "Invalid number: $number"
            continue
        }

        $num = [int]$number
        if ($num -lt 1 -or $num -gt $global:IMAGES.Count) {
            Write-Red "Number out of range: $number"
            continue
        }

        $index = $num - 1
        $image = $global:IMAGES[$index]
        $imageId = ($image -split '\|')[0]

        # Protection check
        if (Test-Protected $imageId) {
            $imageName = ($image -split '\|')[1]
            Write-Yellow "🛡 Skipping protected image: $imageName"
            continue
        }

        # Prevent duplicate selections
        if ($selected -notcontains $index) {
            $selected += $index
        }
    }

    if ($selected.Count -eq 0) {
        Write-Host ""
        Write-Host "No images selected for deletion."
        return
    }

    Write-Host ""
    Write-Red "Images that will be deleted:"
    Write-Host ""

    foreach ($index in $selected) {
        $image = $global:IMAGES[$index]
        $imageName = ($image -split '\|')[1]
        $imageSize = ($image -split '\|')[2]
        Write-Host "  • $imageName ($imageSize)"
    }

    Write-Host ""

    if (-not (Confirm-Action "Permanently delete these images?")) {
        Write-Host "Cancelled."
        return
    }

    Write-Host ""

    foreach ($index in $selected) {
        $image = $global:IMAGES[$index]
        $imageId = ($image -split '\|')[0]
        $imageName = ($image -split '\|')[1]

        Write-Yellow "🗑 Deleting: $imageName"

        if (docker image rm $imageId 2>$null) {
            Write-Green "✓ Deleted"
        }
        else {
            Write-Red "✗ Failed to delete"
        }

        Write-Host ""
    }
}

# ============================================================
# CONTAINER FUNCTIONS
# ============================================================

function List-Containers {
    Write-Host ""
    Write-Cyan "🐳 Docker Containers"
    Write-Host "============================================================"

    $containers = @(docker ps -a --no-trunc --format '{{.ID}}|{{.Names}}|{{.Image}}|{{.Status}}' 2>$null)

    if ($containers.Count -eq 0) {
        Write-Host "No containers found."
        return $false
    }

    $global:CONTAINERS = $containers

    Write-Host ("{0,-5} {1,-25} {2,-30} {3,-20}" -f "#", "NAME", "IMAGE", "STATUS")
    Write-Host "------------------------------------------------------------"

    $i = 1

    foreach ($container in $containers) {
        $parts = $container -split '\|'
        $name = $parts[1]
        $image = $parts[2]
        $status = $parts[3]

        Write-Host ("{0,-5} {1,-25} {2,-30} {3,-20}" -f "[$i]", $name, $image, $status)
        $i++
    }

    Write-Host ""
    return $true
}

# ============================================================
# Force Delete Containers
# ============================================================

function Delete-Containers {
    if (-not (List-Containers)) {
        return
    }

    Write-Red "💀 FORCE DELETE CONTAINERS"
    Write-Host ""
    Write-Host "This uses: docker rm -f"
    Write-Host ""
    Write-Host "Running containers will be forcefully stopped and removed."
    Write-Host ""

    $selection = Read-Host "Enter container numbers (example: 1,3,5)"

    if ([string]::IsNullOrEmpty($selection)) {
        return
    }

    $numbers = $selection -split ','
    $selected = @()

    foreach ($number in $numbers) {
        $number = $number -replace '\s+', ''

        if ($number -notmatch '^\d+$') {
            Write-Red "Invalid number: $number"
            continue
        }

        $num = [int]$number
        if ($num -lt 1 -or $num -gt $global:CONTAINERS.Count) {
            Write-Red "Number out of range: $number"
            continue
        }

        $index = $num - 1

        if ($selected -notcontains $index) {
            $selected += $index
        }
    }

    if ($selected.Count -eq 0) {
        Write-Host "No containers selected."
        return
    }

    Write-Host ""
    Write-Red "Containers that will be FORCE DELETED:"
    Write-Host ""

    foreach ($index in $selected) {
        $container = $global:CONTAINERS[$index]
        $parts = $container -split '\|'
        $name = $parts[1]
        $image = $parts[2]
        $status = $parts[3]

        Write-Host "  💀 $name"
        Write-Host "     Image:  $image"
        Write-Host "     Status: $status"
        Write-Host ""
    }

    if (-not (Confirm-Action "FORCE DELETE these containers?")) {
        Write-Host "Cancelled."
        return
    }

    Write-Host ""

    foreach ($index in $selected) {
        $container = $global:CONTAINERS[$index]
        $containerId = ($container -split '\|')[0]
        $name = ($container -split '\|')[1]

        Write-Yellow "💀 Force deleting: $name"

        if (docker rm -f $containerId 2>$null) {
            Write-Green "✓ Deleted"
        }
        else {
            Write-Red "✗ Failed"
        }

        Write-Host ""
    }
}

# ============================================================
# Docker Disk Usage
# ============================================================

function Show-DockerUsage {
    Write-Host ""
    Write-Cyan "💾 Docker Disk Usage"
    Write-Host "============================================================"

    docker system df

    Write-Host ""
}

# ============================================================
# MAIN MENU
# ============================================================

function Show-Menu {
    while ($true) {
        Clear-Host

        Write-Cyan "╔══════════════════════════════════════════════╗"
        Write-Cyan "║          🐳 Docker Manager                  ║"
        Write-Cyan "╚══════════════════════════════════════════════╝"

        Write-Host ""
        Write-Host "  1) 📋 List images"
        Write-Host "  2) 🗑  Delete images"
        Write-Host "  3) 🛡  Add protected images"
        Write-Host "  4) 👀 View protected images"
        Write-Host "  5) 🔓 Remove image protection"
        Write-Host ""
        Write-Host "  6) 📦 List containers"
        Write-Host "  7) 💀 Force delete containers"
        Write-Host ""
        Write-Host "  8) 💾 Docker disk usage"
        Write-Host ""
        Write-Host "  0) 🚪 Exit"
        Write-Host ""

        $choice = Read-Host "Select option"

        switch ($choice) {
            "1" {
                List-Images
                Pause-Script
            }
            "2" {
                Delete-Images
                Pause-Script
            }
            "3" {
                Protect-Images
                Pause-Script
            }
            "4" {
                View-Protected
                Pause-Script
            }
            "5" {
                Unprotect-Images
                Pause-Script
            }
            "6" {
                List-Containers
                Pause-Script
            }
            "7" {
                Delete-Containers
                Pause-Script
            }
            "8" {
                Show-DockerUsage
                Pause-Script
            }
            "0" {
                Write-Host ""
                Write-Host "Bye 👋"
                exit 0
            }
            default {
                Write-Host ""
                Write-Red "Invalid option."
                Start-Sleep -Seconds 1
            }
        }
    }
}

# ============================================================
# START
# ============================================================

Test-Docker
Show-Menu
