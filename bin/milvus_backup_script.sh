#!/bin/bash

# Milvus Backup Script
# This script creates daily backups and maintains 3-day retention

set -euo pipefail

# Configuration
BACKUP_DIR="/data/backups"
DOCKER_IMAGE="milvusdb/milvus-backup:v0.5.8"
MILVUS_HOST="localhost"  # Change if Milvus is on different host
MILVUS_PORT="19530"      # Default Milvus port
CONFIG_FILE=""           # Optional: path to backup config file
LOG_FILE="/var/log/milvus-backup.log"
RETENTION_DAYS=3

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Function to log messages
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Function to cleanup old backups
cleanup_old_backups() {
    log "Cleaning up backups older than $RETENTION_DAYS days..."
    find "$BACKUP_DIR" -name "backup-*" -type d -mtime +$RETENTION_DAYS -exec rm -rf {} \; 2>/dev/null || true
    log "Cleanup completed"
}

# Main backup function
create_backup() {
    local backup_name="backup-$(date +%Y%m%d-%H%M%S)"
    
    log "Starting backup: $backup_name"
    
    # Prepare Docker command
    local docker_cmd="docker run --rm"
    docker_cmd="$docker_cmd -v $BACKUP_DIR:/backup"
    docker_cmd="$docker_cmd -e MILVUS_ADDRESS=$MILVUS_HOST:$MILVUS_PORT"
    
    # Add config file if specified
    if [ -n "$CONFIG_FILE" ] && [ -f "$CONFIG_FILE" ]; then
        docker_cmd="$docker_cmd -v $CONFIG_FILE:/config/backup.yaml"
        docker_cmd="$docker_cmd -e CONFIG_FILE=/config/backup.yaml"
    fi
    
    docker_cmd="$docker_cmd $DOCKER_IMAGE"
    docker_cmd="$docker_cmd create --backup-name $backup_name --backup-dir /backup"
    
    # Create backup using Docker
    if eval "$docker_cmd"; then
        log "Backup $backup_name created successfully"
        
        # Verify backup exists
        if [ -d "$BACKUP_DIR/$backup_name" ]; then
            log "Backup verified: $(du -sh "$BACKUP_DIR/$backup_name" | cut -f1)"
        else
            log "ERROR: Backup directory not found after creation"
            exit 1
        fi
    else
        log "ERROR: Backup creation failed"
        exit 1
    fi
}

# Main execution
main() {
    log "=== Starting Milvus backup process ==="
    
    # Check if Docker is available
    if ! command -v docker &> /dev/null; then
        log "ERROR: Docker is not installed or not in PATH"
        exit 1
    fi
    
    # Check if Docker daemon is running
    if ! docker info &> /dev/null; then
        log "ERROR: Docker daemon is not running"
        exit 1
    fi
    
    # Pull the latest backup image
    log "Pulling latest backup image..."
    docker pull "$DOCKER_IMAGE"
    
    # Create backup
    create_backup
    
    # Cleanup old backups
    cleanup_old_backups
    
    log "=== Backup process completed ==="
}

# Execute main function
main "$@"
