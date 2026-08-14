#Requires -Version 5.0

# ============================================================
# Docker Manager (PowerShell) - Windows
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
            Write-Host "Make sure Docker Desktop is running."
            exit 1
        }
    }
    catch {
        Write-Red "Docker is not installed or not in PATH."
        exit 1
    }
}

# ============================================================
# List Images
# ============================================================

function List-Images {
    Clear-Host
    Write-Cyan "========== Docker Images =========="
    Write-Host ""
    
    $images = docker image ls --no-trunc --format "{{.ID}}|{{.Repository}}|{{.Tag}}|{{.Size}}|{{.CreatedSince}}"
    
    if ($images.Count -eq 0) {
        Write-Yellow "No images found."
        return
    }
    
    Write-Host ("{0,-15} {1,-35} {2,-15} {3,-12}" -f "IMAGE ID", "REPOSITORY:TAG", "SIZE", "CREATED")
    Write-Host "================================================================================"
    
    foreach ($image in $images) {
        $parts = $image -split '\|'
        $imageId = $parts[0].Substring(0, 12)
        $repo = $parts[1]
        $tag = $parts[2]
        $size = $parts[3]
        $created = $parts[4]
        
        if ($repo -eq "<none>") {
            $repoTag = "<none>"
        } else {
            $repoTag = "$repo`:$tag"
        }
        
        $repoTag = if ($repoTag.Length -gt 35) { $repoTag.Substring(0, 32) + "..." } else { $repoTag }
        $created = if ($created.Length -gt 12) { $created.Substring(0, 9) + "..." } else { $created }
        
        Write-Host ("{0,-15} {1,-35} {2,-12} {3,-12}" -f $imageId, $repoTag, $size, $created)
    }
    
    Write-Host ""
}

# ============================================================
# Delete Images
# ============================================================

function Delete-Images {
    Clear-Host
    Write-Cyan "========== Delete Images =========="
    Write-Host ""
    
    $images = @(docker image ls --no-trunc --format "{{.ID}} | {{.Repository}}:{{.Tag}} | {{.Size}}")
    
    if ($images.Count -eq 0) {
        Write-Yellow "No images found."
        return
    }
    
    $global:IMAGES = $images
    $i = 1
    
    foreach ($image in $images) {
        $parts = $image -split '\s*\|\s*'
        $imageId = $parts[0]
        $imageName = $parts[1]
        $imageSize = $parts[2]
        
        if (Test-Protected $imageId) {
            Write-Green "[$i] $imageName ($imageSize) [PROTECTED]"
        }
        else {
            Write-Host "[$i] $imageName ($imageSize)"
        }
        $i++
    }
    
    Write-Host ""
    Write-Host "[0] Cancel"
    Write-Host ""
    
    $selection = Read-Host "Enter image numbers to delete (comma-separated)"
    
    if ($selection -eq "0") {
        return
    }
    
    $selected = @()
    $selection -split "," | ForEach-Object {
        $index = [int]$_.Trim() - 1
        if ($index -ge 0 -and $index -lt $images.Count) {
            if ($selected -notcontains $index) {
                $selected += $index
            }
        }
    }
    
    if ($selected.Count -eq 0) {
        Write-Host ""
        Write-Host "No images selected for deletion."
        return
    }
    
    # Check for protected images
    $protectedCount = 0
    foreach ($index in $selected) {
        $image = $global:IMAGES[$index]
        $parts = $image -split '\s*\|\s*'
        $imageId = $parts[0]
        if (Test-Protected $imageId) {
            $protectedCount++
        }
    }
    
    if ($protectedCount -gt 0) {
        Write-Host ""
        Write-Red "Cannot delete protected images!"
        Write-Host "$protectedCount image(s) selected are protected."
        return
    }
    
    Write-Host ""
    Write-Red "Images that will be deleted:"
    Write-Host ""
    
    foreach ($index in $selected) {
        $image = $global:IMAGES[$index]
        $parts = $image -split '\s*\|\s*'
        $imageName = $parts[1]
        $imageSize = $parts[2]
        Write-Host "  - $imageName ($imageSize)"
    }
    
    Write-Host ""
    if (-not (Confirm-Action "Delete these images?")) {
        Write-Yellow "Cancelled."
        return
    }
    
    foreach ($index in $selected) {
        $image = $global:IMAGES[$index]
        $parts = $image -split '\s*\|\s*'
        $imageId = $parts[0]
        $imageName = $parts[1]
        
        Write-Host "Deleting $imageName..."
        docker image rm $imageId 2>&1 | Out-Null
        
        if ($LASTEXITCODE -eq 0) {
            Write-Green "Deleted: $imageName"
        }
        else {
            Write-Red "Failed to delete: $imageName"
        }
    }
    
    Write-Host ""
    Write-Green "Done!"
}

# ============================================================
# Force Delete Images
# ============================================================

function Delete-Images-Force {
    Clear-Host
    Write-Cyan "========== Force Delete Images =========="
    Write-Host ""
    
    $images = @(docker image ls --no-trunc --format "{{.ID}} | {{.Repository}}:{{.Tag}} | {{.Size}}")
    
    if ($images.Count -eq 0) {
        Write-Yellow "No images found."
        return
    }
    
    $global:IMAGES = $images
    $i = 1
    
    foreach ($image in $images) {
        $parts = $image -split '\s*\|\s*'
        $imageId = $parts[0]
        $imageName = $parts[1]
        $imageSize = $parts[2]
        
        if (Test-Protected $imageId) {
            Write-Green "[$i] $imageName ($imageSize) [PROTECTED]"
        }
        else {
            Write-Host "[$i] $imageName ($imageSize)"
        }
        $i++
    }
    
    Write-Host ""
    Write-Host "[0] Cancel"
    Write-Host ""
    
    $selection = Read-Host "Enter image numbers to force delete (comma-separated)"
    
    if ($selection -eq "0") {
        return
    }
    
    $selected = @()
    $selection -split "," | ForEach-Object {
        $index = [int]$_.Trim() - 1
        if ($index -ge 0 -and $index -lt $images.Count) {
            if ($selected -notcontains $index) {
                $selected += $index
            }
        }
    }
    
    if ($selected.Count -eq 0) {
        Write-Host ""
        Write-Host "No images selected for deletion."
        return
    }
    
    # Check for protected images
    $protectedCount = 0
    foreach ($index in $selected) {
        $image = $global:IMAGES[$index]
        $parts = $image -split '\s*\|\s*'
        $imageId = $parts[0]
        if (Test-Protected $imageId) {
            $protectedCount++
        }
    }
    
    if ($protectedCount -gt 0) {
        Write-Host ""
        Write-Red "Cannot delete protected images!"
        Write-Host "$protectedCount image(s) selected are protected."
        Write-Host "Unprotect them first if you want to delete."
        return
    }
    
    Write-Host ""
    Write-Red "WARNING: These images will be force deleted (this cannot be undone):"
    Write-Host ""
    
    foreach ($index in $selected) {
        $image = $global:IMAGES[$index]
        $parts = $image -split '\s*\|\s*'
        $imageName = $parts[1]
        $imageSize = $parts[2]
        Write-Host "  - $imageName ($imageSize)"
    }
    
    Write-Host ""
    if (-not (Confirm-Action "Force delete these images?")) {
        Write-Yellow "Cancelled."
        return
    }
    
    foreach ($index in $selected) {
        $image = $global:IMAGES[$index]
        $parts = $image -split '\s*\|\s*'
        $imageId = $parts[0]
        $imageName = $parts[1]
        
        Write-Host "Force deleting $imageName..."
        docker image rm -f $imageId 2>&1 | Out-Null
        
        if ($LASTEXITCODE -eq 0) {
            Write-Green "Deleted: $imageName"
        }
        else {
            Write-Red "Failed to delete: $imageName"
        }
    }
    
    Write-Host ""
    Write-Green "Done!"
}

# ============================================================
# Protect Images
# ============================================================

function Protect-Images {
    Clear-Host
    Write-Cyan "========== Protect Images =========="
    Write-Host ""
    
    $images = @(docker image ls --no-trunc --format "{{.ID}} | {{.Repository}}:{{.Tag}} | {{.Size}}")
    
    if ($images.Count -eq 0) {
        Write-Yellow "No images found."
        return
    }
    
    $global:IMAGES = $images
    $i = 1
    
    foreach ($image in $images) {
        $parts = $image -split '\s*\|\s*'
        $imageId = $parts[0]
        $imageName = $parts[1]
        
        if (Test-Protected $imageId) {
            Write-Green "[$i] [PROTECTED] $imageName"
        }
        else {
            Write-Host "[$i] $imageName"
        }
        $i++
    }
    
    Write-Host ""
    Write-Host "[0] Cancel"
    Write-Host ""
    
    $selection = Read-Host "Enter image numbers to protect (comma-separated)"
    
    if ($selection -eq "0") {
        return
    }
    
    $selected = @()
    $selection -split "," | ForEach-Object {
        $index = [int]$_.Trim() - 1
        if ($index -ge 0 -and $index -lt $images.Count) {
            if ($selected -notcontains $index) {
                $selected += $index
            }
        }
    }
    
    foreach ($index in $selected) {
        $image = $global:IMAGES[$index]
        $parts = $image -split '\s*\|\s*'
        $imageId = $parts[0]
        $imageName = $parts[1]
        
        Add-Protected $imageId
        Write-Green "Protected: $imageName"
    }
    
    Write-Host ""
    Write-Green "Done!"
}

# ============================================================
# View Protected
# ============================================================

function View-Protected {
    Clear-Host
    Write-Cyan "========== Protected Images =========="
    Write-Host ""
    
    $images = @(docker image ls --no-trunc --format "{{.ID}} | {{.Repository}}:{{.Tag}} | {{.Size}} | {{.CreatedSince}}")
    
    $found = $false
    $i = 1
    
    foreach ($image in $images) {
        $parts = $image -split '\s*\|\s*'
        $imageId = $parts[0]
        $imageName = $parts[1]
        $imageSize = $parts[2]
        $created = $parts[3]
        
        if (Test-Protected $imageId) {
            Write-Green "[$i] $imageName"
            Write-Host "    Size: $imageSize | Created: $created"
            $i++
            $found = $true
        }
    }
    
    if (-not $found) {
        Write-Yellow "No protected images."
    }
    
    Write-Host ""
}

# ============================================================
# Unprotect Images
# ============================================================

function Unprotect-Images {
    Clear-Host
    Write-Cyan "========== Unprotect Images =========="
    Write-Host ""
    
    $images = @(docker image ls --no-trunc --format "{{.ID}} | {{.Repository}}:{{.Tag}} | {{.Size}}")
    
    if ($images.Count -eq 0) {
        Write-Yellow "No images found."
        return
    }
    
    $global:IMAGES = $images
    $i = 1
    
    foreach ($image in $images) {
        $parts = $image -split '\s*\|\s*'
        $imageId = $parts[0]
        $imageName = $parts[1]
        
        if (Test-Protected $imageId) {
            Write-Green "[$i] [PROTECTED] $imageName"
        }
        else {
            Write-Host "[$i] $imageName"
        }
        $i++
    }
    
    Write-Host ""
    Write-Host "[0] Cancel"
    Write-Host ""
    
    $selection = Read-Host "Enter image numbers to unprotect (comma-separated)"
    
    if ($selection -eq "0") {
        return
    }
    
    $selected = @()
    $selection -split "," | ForEach-Object {
        $index = [int]$_.Trim() - 1
        if ($index -ge 0 -and $index -lt $images.Count) {
            if ($selected -notcontains $index) {
                $selected += $index
            }
        }
    }
    
    foreach ($index in $selected) {
        $image = $global:IMAGES[$index]
        $parts = $image -split '\s*\|\s*'
        $imageId = $parts[0]
        $imageName = $parts[1]
        
        Remove-Protected $imageId
        Write-Green "Unprotected: $imageName"
    }
    
    Write-Host ""
    Write-Green "Done!"
}

# ============================================================
# List Containers
# ============================================================

function List-Containers {
    Clear-Host
    Write-Cyan "========== Docker Containers =========="
    Write-Host ""
    
    $containers = docker container ls -a --no-trunc --format "{{.ID}}|{{.Names}}|{{.Status}}|{{.Image}}|{{.Size}}"
    
    if ($containers.Count -eq 0) {
        Write-Yellow "No containers found."
        return
    }
    
    Write-Host ("{0,-15} {1,-25} {2,-35} {3,-20}" -f "CONTAINER ID", "NAME", "STATUS", "SIZE")
    Write-Host "======================================================================================="
    
    foreach ($container in $containers) {
        $parts = $container -split '\|'
        $containerId = $parts[0].Substring(0, 12)
        $name = $parts[1]
        $status = $parts[2]
        $size = $parts[4]
        
        $name = if ($name.Length -gt 25) { $name.Substring(0, 22) + "..." } else { $name }
        $status = if ($status.Length -gt 35) { $status.Substring(0, 32) + "..." } else { $status }
        
        Write-Host ("{0,-15} {1,-25} {2,-35} {3,-20}" -f $containerId, $name, $status, $size)
    }
    
    Write-Host ""
}

# ============================================================
# Delete Containers
# ============================================================

function Delete-Containers {
    Clear-Host
    Write-Cyan "========== Delete Containers =========="
    Write-Host ""
    
    $containers = @(docker container ls -a --no-trunc --format "{{.ID}} | {{.Names}} | {{.Status}}")
    
    if ($containers.Count -eq 0) {
        Write-Yellow "No containers found."
        return
    }
    
    $global:CONTAINERS = $containers
    $i = 1
    
    foreach ($container in $containers) {
        $parts = $container -split '\s*\|\s*'
        $containerId = $parts[0].Substring(0, 12)
        $name = $parts[1]
        $status = $parts[2]
        
        Write-Host "[$i] $name - $status"
        $i++
    }
    
    Write-Host ""
    Write-Host "[0] Cancel"
    Write-Host ""
    
    $selection = Read-Host "Enter container numbers to delete (comma-separated)"
    
    if ($selection -eq "0") {
        return
    }
    
    $selected = @()
    $selection -split "," | ForEach-Object {
        $index = [int]$_.Trim() - 1
        if ($index -ge 0 -and $index -lt $containers.Count) {
            if ($selected -notcontains $index) {
                $selected += $index
            }
        }
    }
    
    if ($selected.Count -eq 0) {
        Write-Host ""
        Write-Host "No containers selected for deletion."
        return
    }
    
    Write-Host ""
    Write-Red "Containers that will be deleted:"
    Write-Host ""
    
    foreach ($index in $selected) {
        $container = $global:CONTAINERS[$index]
        $parts = $container -split '\s*\|\s*'
        $name = $parts[1]
        Write-Host "  - $name"
    }
    
    Write-Host ""
    if (-not (Confirm-Action "Delete these containers?")) {
        Write-Yellow "Cancelled."
        return
    }
    
    foreach ($index in $selected) {
        $container = $global:CONTAINERS[$index]
        $parts = $container -split '\s*\|\s*'
        $containerId = $parts[0]
        $name = $parts[1]
        
        Write-Host "Deleting $name..."
        docker container rm -f $containerId 2>&1 | Out-Null
        
        if ($LASTEXITCODE -eq 0) {
            Write-Green "Deleted: $name"
        }
        else {
            Write-Red "Failed to delete: $name"
        }
    }
    
    Write-Host ""
    Write-Green "Done!"
}

# ============================================================
# Docker Usage
# ============================================================

function Show-DockerUsage {
    Clear-Host
    Write-Cyan "========== Docker Disk Usage =========="
    Write-Host ""
    
    docker system df
    Write-Host ""
}

# ============================================================
# Main Menu
# ============================================================

function Show-Menu {
    Write-Host ""
    Write-Cyan "========= Docker Manager =========="
    Write-Host ""
    Write-Cyan "[IMAGES]"
    Write-Host "  1) List images"
    Write-Host "  2) Delete images"
    Write-Host "  3) Force delete images"
    Write-Host "  4) Protect images"
    Write-Host "  5) View protected images"
    Write-Host "  6) Unprotect images"
    Write-Host ""
    Write-Cyan "[CONTAINERS]"
    Write-Host "  7) List containers"
    Write-Host "  8) Delete containers"
    Write-Host ""
    Write-Cyan "[SYSTEM]"
    Write-Host "  9) Docker disk usage"
    Write-Host ""
    Write-Host "  0) Exit"
    Write-Host ""
}

# ============================================================
# Main Loop
# ============================================================

Test-Docker

while ($true) {
    Clear-Host
    Show-Menu
    
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
            Delete-Images-Force
            Pause-Script
        }
        "4" {
            Protect-Images
            Pause-Script
        }
        "5" {
            View-Protected
            Pause-Script
        }
        "6" {
            Unprotect-Images
            Pause-Script
        }
        "7" {
            List-Containers
            Pause-Script
        }
        "8" {
            Delete-Containers
            Pause-Script
        }
        "9" {
            Show-DockerUsage
            Pause-Script
        }
        "0" {
            Write-Host ""
            Write-Green "Goodbye!"
            exit 0
        }
        default {
            Write-Host ""
            Write-Red "Invalid option."
            Start-Sleep -Seconds 1
        }
    }
}
