#!/bin/bash

# Log file setup
LOG_FILE="$HOME/sync_$(date +%Y%m%d).log"

# Function for logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Get input parameters
read -p "Enter source VM username: " SOURCE_USER
read -p "Enter source VM IP: " SOURCE_IP
read -p "Enter source VM SSH port (default: 22): " SOURCE_PORT
SOURCE_PORT=${SOURCE_PORT:-22}

read -p "Enter destination VM username: " DEST_USER
read -p "Enter destination VM IP: " DEST_IP
read -p "Enter destination VM SSH port (default: 22): " DEST_PORT
DEST_PORT=${DEST_PORT:-22}

read -p "Enter folder path to sync: " SYNC_PATH

# Build SSH connection strings
SOURCE_SSH="ssh -p $SOURCE_PORT $SOURCE_USER@$SOURCE_IP"
DEST_SSH="ssh -p $DEST_PORT $DEST_USER@$DEST_IP"

# Function to test SSH connection
test_ssh() {
    local ssh_cmd="$1"
    $ssh_cmd "exit" > /dev/null 2>&1
    return $?
}

# Check SSH connections
log "Checking SSH connections..."

if ! test_ssh "$SOURCE_SSH"; then
    log "ERROR: Cannot connect to source VM ($SOURCE_USER@$SOURCE_IP:$SOURCE_PORT)"
    exit 1
fi

if ! test_ssh "$DEST_SSH"; then
    log "ERROR: Cannot connect to destination VM ($DEST_USER@$DEST_IP:$DEST_PORT)"
    exit 1
fi

# Test if source can directly access destination
log "Testing direct connection from source to destination..."
DIRECT_ACCESS=$($SOURCE_SSH "ssh -p $DEST_PORT -o BatchMode=yes -o ConnectTimeout=5 $DEST_USER@$DEST_IP exit 2>/dev/null && echo yes || echo no")

# Create directory on destination
log "Creating directory on destination..."
$DEST_SSH "mkdir -p $SYNC_PATH"

if [ "$DIRECT_ACCESS" = "yes" ]; then
    # Direct sync from source to destination
    log "Direct access available. Performing direct sync..."
    $SOURCE_SSH "rsync -az -e 'ssh -p $DEST_PORT' $SYNC_PATH/ $DEST_USER@$DEST_IP:$SYNC_PATH/"
    
    if [ $? -eq 0 ]; then
        log "Direct sync completed successfully!"
    else
        log "ERROR: Direct sync failed!"
        exit 1
    fi
else
    # Indirect sync through main VM
    log "No direct access. Performing indirect sync through main VM..."
    
    # Create temporary directory on main VM
    TEMP_DIR="/tmp/sync_$$"
    mkdir -p "$TEMP_DIR"
    
    # Step 1: Source to Main
    log "Step 1: Copying from source to main VM..."
    rsync -az -e "ssh -p $SOURCE_PORT" "$SOURCE_USER@$SOURCE_IP:$SYNC_PATH/" "$TEMP_DIR/"
    
    if [ $? -ne 0 ]; then
        log "ERROR: Failed to copy from source to main VM"
        rm -rf "$TEMP_DIR"
        exit 1
    fi
    
    # Step 2: Main to Destination
    log "Step 2: Copying from main VM to destination..."
    rsync -az -e "ssh -p $DEST_PORT" "$TEMP_DIR/" "$DEST_USER@$DEST_IP:$SYNC_PATH/"
    
    if [ $? -ne 0 ]; then
        log "ERROR: Failed to copy from main VM to destination"
        rm -rf "$TEMP_DIR"
        exit 1
    fi
    
    # Cleanup
    rm -rf "$TEMP_DIR"
    log "Indirect sync completed successfully!"
fi

log "Sync operation completed!"