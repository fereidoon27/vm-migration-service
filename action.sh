#!/bin/bash

# Log file setup
ACTION_LOG="$HOME/service_actions_$(date +%Y%m%d).log"
TIMESTAMP_LOG="$HOME/service_timestamps_$(date +%Y%m%d).log"

# Set Info directory path
INFO_PATH="$(dirname "$0")/Info"

# Function for logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$ACTION_LOG"
}

# Function for timestamp logging
log_timestamp() {
    local action=$1
    local status=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] Action $action: $status" >> "$TIMESTAMP_LOG"
}

# Function to load defaults from file
load_defaults() {
    local file=$1
    if [ -f "$file" ]; then
        log "Loading defaults from $file"
        source "$file"
    else
        log "WARNING: Default file $file not found"
    fi
}

# Function to execute action
execute_action() {
    local action_num=$1
    local ssh_cmd=$2
    local target_path=$3
    
    case $action_num in
        1)
            action_name="Create newfile_1.txt"
            action_command="echo '(this is written by action 1 )' > $target_path/newfile_1.txt"
            ;;
        2)
            action_name="Create newfile_2.txt"
            action_command="echo '(this is written by action 2 )' > $target_path/newfile_2.txt"
            ;;
        3)
            action_name="Create newfile_3.txt"
            action_command="echo '(this is written by action 3 )' > $target_path/newfile_3.txt"
            ;;
        4)
            action_name="Create newfile_4.txt"
            action_command="echo '(this is written by action 4 )' > $target_path/newfile_4.txt"
            ;;
        *)
            log "ERROR: Invalid action number: $action_num"
            return 1
            ;;
    esac
    log "Starting action $action_num: $action_name"
    log_timestamp "$action_name" "Started"
    
    $ssh_cmd "$action_command"
    local result=$?
    
    if [ $result -eq 0 ]; then
        log "Action $action_num ($action_name) completed successfully"
        log_timestamp "$action_name" "Completed"
    else
        log "ERROR: Action $action_num ($action_name) failed"
        log_timestamp "$action_name" "Failed"
        return 1
    fi
}

# Load default values
load_defaults "$INFO_PATH/Info_Dest.txt"
load_defaults "$INFO_PATH/Info_Source.txt"

# Get source VM details with defaults
echo -e "\n--- SOURCE VM CONFIGURATION ---"
read -p "Enter source VM username [$SOURCE_USER]: " input_source_user
SOURCE_USER=${input_source_user:-$SOURCE_USER}

read -p "Enter source VM IP [$SOURCE_IP]: " input_source_ip
SOURCE_IP=${input_source_ip:-$SOURCE_IP}

read -p "Enter source VM SSH port [$SOURCE_PORT]: " input_source_port
SOURCE_PORT=${input_source_port:-$SOURCE_PORT}

read -p "Enter source VM path [$SOURCE_PATH]: " input_source_path
SOURCE_PATH=${input_source_path:-$SOURCE_PATH}

# Get destination VM details with defaults
echo -e "\n--- DESTINATION VM CONFIGURATION ---"
read -p "Enter destination VM username [$DEST_USER]: " input_dest_user
DEST_USER=${input_dest_user:-$DEST_USER}

read -p "Enter destination VM IP [$DEST_IP]: " input_dest_ip
DEST_IP=${input_dest_ip:-$DEST_IP}

read -p "Enter destination VM SSH port [$DEST_PORT]: " input_dest_port
DEST_PORT=${input_dest_port:-$DEST_PORT}

read -p "Enter destination VM path [$DEST_PATH]: " input_dest_path
DEST_PATH=${input_dest_path:-$DEST_PATH}

# Build SSH connection strings
SOURCE_SSH_CMD="ssh -p $SOURCE_PORT $SOURCE_USER@$SOURCE_IP"
DEST_SSH_CMD="ssh -p $DEST_PORT $DEST_USER@$DEST_IP"

# Choose which VM to operate on
echo -e "\n--- SELECT TARGET VM FOR OPERATIONS ---"
echo "1: Source VM ($SOURCE_USER@$SOURCE_IP:$SOURCE_PORT)"
echo "2: Destination VM ($DEST_USER@$DEST_IP:$DEST_PORT)"

while true; do
    read -p "Select VM (1 or 2): " vm_choice
    if [[ "$vm_choice" == "1" ]]; then
        ACTIVE_SSH_CMD="$SOURCE_SSH_CMD"
        ACTIVE_PATH="$SOURCE_PATH"
        ACTIVE_VM_NAME="Source VM"
        break
    elif [[ "$vm_choice" == "2" ]]; then
        ACTIVE_SSH_CMD="$DEST_SSH_CMD"
        ACTIVE_PATH="$DEST_PATH"
        ACTIVE_VM_NAME="Destination VM"
        break
    else
        echo "Invalid choice. Please enter 1 or 2."
    fi
done

# Test SSH connection
log "Testing SSH connection to $ACTIVE_VM_NAME..."
if ! $ACTIVE_SSH_CMD "exit" > /dev/null 2>&1; then
    log "ERROR: Cannot connect to $ACTIVE_VM_NAME"
    echo "ERROR: Cannot connect to $ACTIVE_VM_NAME"
    exit 1
fi

# Check if folder exists
if ! $ACTIVE_SSH_CMD "[ -d $ACTIVE_PATH ]"; then
    log "ERROR: Folder '$ACTIVE_PATH' does not exist on $ACTIVE_VM_NAME"
    echo "ERROR: Folder '$ACTIVE_PATH' does not exist on $ACTIVE_VM_NAME"
    exit 1
fi

# Display available actions
echo -e "\nAvailable actions:"
echo "1: Create newfile_1.txt (Write: (this is written by action 1 ))"
echo "2: Create newfile_2.txt (Write: (this is written by action 2 ))"
echo "3: Create newfile_3.txt (Write: (this is written by action 3 ))"
echo "4: Create newfile_4.txt (Write: (this is written by action 4 ))"

# Get sequence of actions
while true; do
    read -p "Enter sequence of actions (2-4 digits, e.g., 12 or 1234): " sequence
    if [[ ! $sequence =~ ^[1-4]{2,4}$ ]]; then
        echo "Error: Please enter 2-4 digits, using only numbers 1-4"
        continue
    fi
    break
done

# Confirm sequence
echo -e "\nYou entered sequence: $sequence"
echo "This will execute the following actions on $ACTIVE_VM_NAME:"
for (( i=0; i<${#sequence}; i++ )); do
    action_num=${sequence:$i:1}
    case $action_num in
        1) echo "$(($i+1)). Create newfile_1.txt" ;;
        2) echo "$(($i+1)). Create newfile_2.txt" ;;
        3) echo "$(($i+1)). Create newfile_3.txt" ;;
        4) echo "$(($i+1)). Create newfile_4.txt" ;;
    esac
done

read -p "Continue? (y/n): " confirm
if [[ $confirm != "y" ]]; then
    log "Sequence cancelled by user"
    exit 0
fi

# Execute sequence
echo -e "\nExecuting sequence on $ACTIVE_VM_NAME..."
for (( i=0; i<${#sequence}; i++ )); do
    action_num=${sequence:$i:1}
    echo -e "\nExecuting step $(($i+1)) of ${#sequence}: Action $action_num"
    if ! execute_action $action_num "$ACTIVE_SSH_CMD" "$ACTIVE_PATH"; then
        echo "Sequence failed at step $(($i+1))"
        exit 1
    fi
done

echo -e "\nSequence completed successfully on $ACTIVE_VM_NAME!"
echo "Timestamp log: $TIMESTAMP_LOG"
echo "Action log: $ACTION_LOG"
