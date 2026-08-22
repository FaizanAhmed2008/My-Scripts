#!/bin/bash

# Simple Backup Script
# -----------------------------------

# Define directories to backup (space separated)
# Note: Customize these paths to suit your needs.
BACKUP_DIRS="$HOME/Pictures/Camera"

# Define backup destination directory
BACKUP_DEST="$HOME/Backups"

# Create a timestamp for the filename
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
BACKUP_FILE="$BACKUP_DEST/backup_$TIMESTAMP.tar.gz"

# Create destination directory if it doesn't exist
mkdir -p "$BACKUP_DEST"

echo "==================================="
echo "Starting Backup"
echo "==================================="
echo "Source directories: $BACKUP_DIRS"
echo "Destination file: $BACKUP_FILE"
echo "-----------------------------------"

# Create the compressed tarball (ignoring errors about directories changing as we read them)
tar -czf "$BACKUP_FILE" $BACKUP_DIRS 2>/dev/null

# Check if the tar command succeeded
if [ $? -eq 0 ]; then
    echo "Backup completed successfully!"
    
    # Display the size of the generated backup file
    SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
    echo "Backup size: $SIZE"
else
    echo "Error: Backup failed!"
fi
echo "==================================="
