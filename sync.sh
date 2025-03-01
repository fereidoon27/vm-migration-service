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
DEFAULT_DEST_PATH=$(read_config "DEST_PATH" "/tmp")

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

read -p "Enter destination folder path [$DEFAULT_DEST_PATH]: " DEST_PATH
DEST_PATH=${DEST_PATH:-$DEFAULT_DEST_PATH}

# Display options for transfer
echo "Transfer options:"
echo "1. Transfer a specific file from source VM to destination VM"
echo "2. Transfer a specific folder from source VM to destination VM"
echo "3. Transfer specific files/folders from home directory based on patterns"
echo "   (van-buren-* directories, .sh files, .secret/ folder)"
read -p "Choose an option (1-3) [1]: " TRANSFER_OPTION
TRANSFER_OPTION=${TRANSFER_OPTION:-1}

# Based on option, get additional input
case $TRANSFER_OPTION in
    1)
        read -p "Enter the path to the specific file on source VM: " SOURCE_PATH
        ;;
    2)
        read -p "Enter the path to the specific folder on source VM: " SOURCE_PATH
        ;;
    3)
        # Option 3 uses predefined patterns from home directory
        SOURCE_PATH="~"
        ;;
    *)
        log "ERROR: Invalid option selected"
        exit 1
        ;;
esac

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

# Create directory on destination
log "Creating directory on destination..."
$DEST_SSH "mkdir -p $DEST_PATH"

# Test if source can directly access destination
log "Testing direct connection from source to destination..."
DIRECT_ACCESS=$($SOURCE_SSH "ssh -p $DEST_PORT -o BatchMode=yes -o ConnectTimeout=5 $DEST_USER@$DEST_IP exit 2>/dev/null && echo yes || echo no")

# Prepare rsync options based on the option selected
if [ "$TRANSFER_OPTION" -eq 1 ]; then
    # For single file, don't add trailing slash to SOURCE_PATH
    RSYNC_OPTS="-az"
    FILE_NAME=$(basename "$SOURCE_PATH")
    DEST_FULL="$DEST_PATH/$FILE_NAME"
    log "Transferring specific file: $SOURCE_PATH to $DEST_FULL"
elif [ "$TRANSFER_OPTION" -eq 2 ]; then
    # For directory, add trailing slash to SOURCE_PATH to copy contents
    RSYNC_OPTS="-az"
    SOURCE_PATH="${SOURCE_PATH%/}/"
    DEST_FULL="$DEST_PATH"
    log "Transferring specific folder: $SOURCE_PATH to $DEST_FULL"
elif [ "$TRANSFER_OPTION" -eq 3 ]; then
    # For specific patterns, create a pattern list as an array
    INCLUDE_PATTERNS=(
        "--include=van-buren-*/"
        "--include=van-buren-*/**"
        "--include=*.sh"
        "--include=.secret/"
        "--include=.secret/**"
        "--exclude=*"
    )
    RSYNC_OPTS="-az ${INCLUDE_PATTERNS[*]}"
    SOURCE_PATH="~/"
    DEST_FULL="$DEST_PATH"
    log "Transferring pattern-matched files/folders from home directory"
fi

if [ "$DIRECT_ACCESS" = "yes" ]; then
    # Direct sync from source to destination
    log "Direct access available. Performing direct sync..."
    
    if [ "$TRANSFER_OPTION" -eq 1 ]; then
        # For single file
        $SOURCE_SSH "rsync $RSYNC_OPTS -e 'ssh -p $DEST_PORT' $SOURCE_PATH $DEST_USER@$DEST_IP:$DEST_FULL"
    elif [ "$TRANSFER_OPTION" -eq 3 ]; then
        # For pattern matching, create the command with proper include/exclude patterns
        REMOTE_CMD="rsync -az --include='van-buren-*/' --include='van-buren-*/**' --include='*.sh' --include='.secret/' --include='.secret/**' --exclude='*' -e 'ssh -p $DEST_PORT' $SOURCE_PATH $DEST_USER@$DEST_IP:$DEST_FULL"
        $SOURCE_SSH "$REMOTE_CMD"
    else
        # For regular directory
        $SOURCE_SSH "rsync $RSYNC_OPTS -e 'ssh -p $DEST_PORT' $SOURCE_PATH $DEST_USER@$DEST_IP:$DEST_FULL"
    fi
    
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
    
    if [ "$TRANSFER_OPTION" -eq 1 ]; then
        # For single file
        rsync $RSYNC_OPTS -e "ssh -p $SOURCE_PORT" "$SOURCE_USER@$SOURCE_IP:$SOURCE_PATH" "$TEMP_DIR/"
    elif [ "$TRANSFER_OPTION" -eq 3 ]; then
        # For pattern matching, use separate include/exclude options
        rsync -az --include="van-buren-*/" --include="van-buren-*/**" --include="*.sh" --include=".secret/" --include=".secret/**" --exclude="*" -e "ssh -p $SOURCE_PORT" "$SOURCE_USER@$SOURCE_IP:$SOURCE_PATH" "$TEMP_DIR/"
    else
        # For regular directory
        rsync $RSYNC_OPTS -e "ssh -p $SOURCE_PORT" "$SOURCE_USER@$SOURCE_IP:$SOURCE_PATH" "$TEMP_DIR/"
    fi
    
    if [ $? -ne 0 ]; then
        log "ERROR: Failed to copy from source to main VM"
        rm -rf "$TEMP_DIR"
        exit 1
    fi
    
    # Step 2: Main to Destination
    log "Step 2: Copying from main VM to destination..."
    
    if [ "$TRANSFER_OPTION" -eq 1 ]; then
        # For single file, get filename
        FILE_NAME=$(basename "$SOURCE_PATH")
        rsync $RSYNC_OPTS -e "ssh -p $DEST_PORT" "$TEMP_DIR/$FILE_NAME" "$DEST_USER@$DEST_IP:$DEST_FULL"
    else
        # For directory or patterns
        rsync -az -e "ssh -p $DEST_PORT" "$TEMP_DIR/" "$DEST_USER@$DEST_IP:$DEST_FULL"
    fi
    
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