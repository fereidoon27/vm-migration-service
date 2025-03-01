#!/bin/bash

# Get script directory for finding config file
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
CONFIG_FILE="$SCRIPT_DIR/ST_INFO.txt"

# Log file setup
LOG_FILE="$HOME/sync_$(date +%Y%m%d).log"

# Function for logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Function to read config value with default
read_config() {
    local key="$1"
    local default="$2"
    local value=""
    
    if [ -f "$CONFIG_FILE" ]; then
        value=$(grep "^$key=" "$CONFIG_FILE" | cut -d= -f2)
    fi
    
    echo "${value:-$default}"
}

# Load default values from config file
DEFAULT_SOURCE_USER=$(read_config "SOURCE_USER" "root")
DEFAULT_SOURCE_IP=$(read_config "SOURCE_IP" "127.0.0.1")
DEFAULT_SOURCE_PORT=$(read_config "SOURCE_PORT" "22")
DEFAULT_DEST_USER=$(read_config "DEST_USER" "root")
DEFAULT_DEST_IP=$(read_config "DEST_IP" "127.0.0.1")
DEFAULT_DEST_PORT=$(read_config "DEST_PORT" "22")
DEFAULT_SOURCE_PATH=$(read_config "SOURCE_PATH" "/home/${DEFAULT_SOURCE_USER}")
DEFAULT_DEST_PATH=$(read_config "DEST_PATH" "")

# Get input parameters with defaults
read -p "Enter source VM username [$DEFAULT_SOURCE_USER]: " SOURCE_USER
SOURCE_USER=${SOURCE_USER:-$DEFAULT_SOURCE_USER}

read -p "Enter source VM IP [$DEFAULT_SOURCE_IP]: " SOURCE_IP
SOURCE_IP=${SOURCE_IP:-$DEFAULT_SOURCE_IP}

read -p "Enter source VM SSH port [$DEFAULT_SOURCE_PORT]: " SOURCE_PORT
SOURCE_PORT=${SOURCE_PORT:-$DEFAULT_SOURCE_PORT}

read -p "Enter destination VM username [$DEFAULT_DEST_USER]: " DEST_USER
DEST_USER=${DEST_USER:-$DEFAULT_DEST_USER}

read -p "Enter destination VM IP [$DEFAULT_DEST_IP]: " DEST_IP
DEST_IP=${DEST_IP:-$DEFAULT_DEST_IP}

read -p "Enter destination VM SSH port [$DEFAULT_DEST_PORT]: " DEST_PORT
DEST_PORT=${DEST_PORT:-$DEFAULT_DEST_PORT}

read -p "Enter source folder path to sync [$DEFAULT_SOURCE_PATH]: " SOURCE_PATH
SOURCE_PATH=${SOURCE_PATH:-$DEFAULT_SOURCE_PATH}

# If the default destination path is empty, use the source path as default
if [ -z "$DEFAULT_DEST_PATH" ]; then
    DEFAULT_DEST_PATH=$SOURCE_PATH
fi

read -p "Enter destination folder path [$DEFAULT_DEST_PATH]: " DEST_PATH
DEST_PATH=${DEST_PATH:-$DEFAULT_DEST_PATH}

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
$DEST_SSH "mkdir -p $DEST_PATH"

# Build rsync include/exclude patterns for the specific requirements
RSYNC_OPTS="-az --include='van-buren-*/' --include='van-buren-*/**' --include='*.sh' --include='.secret/' --include='.secret/**' --exclude='*'"

if [ "$DIRECT_ACCESS" = "yes" ]; then
    # Direct sync from source to destination
    log "Direct access available. Performing direct sync..."
    log "Only transferring: van-buren-* directories, *.sh files, and .secret/ folder"
    $SOURCE_SSH "rsync $RSYNC_OPTS -e 'ssh -p $DEST_PORT' $SOURCE_PATH/ $DEST_USER@$DEST_IP:$DEST_PATH/"
    
    if [ $? -eq 0 ]; then
        log "Direct sync completed successfully!"
    else
        log "ERROR: Direct sync failed!"
        exit 1
    fi
else
    # Indirect sync through main VM
    log "No direct access. Performing indirect sync through main VM..."
    log "Only transferring: van-buren-* directories, *.sh files, and .secret/ folder"
    
    # Create temporary directory on main VM
    TEMP_DIR="/tmp/sync_$$"
    mkdir -p "$TEMP_DIR"
    
    # Step 1: Source to Main
    log "Step 1: Copying from source to main VM..."
    rsync $RSYNC_OPTS -e "ssh -p $SOURCE_PORT" "$SOURCE_USER@$SOURCE_IP:$SOURCE_PATH/" "$TEMP_DIR/"
    
    if [ $? -ne 0 ]; then
        log "ERROR: Failed to copy from source to main VM"
        rm -rf "$TEMP_DIR"
        exit 1
    fi
    
    # Step 2: Main to Destination
    log "Step 2: Copying from main VM to destination..."
    rsync -az -e "ssh -p $DEST_PORT" "$TEMP_DIR/" "$DEST_USER@$DEST_IP:$DEST_PATH/"
    
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