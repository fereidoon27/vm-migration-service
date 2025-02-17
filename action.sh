#!/bin/bash
# Log file setup
ACTION_LOG="$HOME/service_actions_$(date +%Y%m%d).log"
TIMESTAMP_LOG="$HOME/service_timestamps_$(date +%Y%m%d).log"

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

# Function to execute action
execute_action() {
    local action_num=$1
    case $action_num in
        1)
            action_script="Create newfile_1.txt"
            action_name="Create newfile_1.txt"
            action_command="echo '(this is written by action 1 )' > $TARGET_FOLDER/newfile_1.txt"
            ;;
        2)
            action_script="Create newfile_2.txt"
            action_name="Create newfile_2.txt"
            action_command="echo '(this is written by action 2 )' > $TARGET_FOLDER/newfile_2.txt"
            ;;
        3)
            action_script="Create newfile_3.txt"
            action_name="Create newfile_3.txt"
            action_command="echo '(this is written by action 3 )' > $TARGET_FOLDER/newfile_3.txt"
            ;;
        4)
            action_script="Create newfile_4.txt"
            action_name="Create newfile_4.txt"
            action_command="echo '(this is written by action 4 )' > $TARGET_FOLDER/newfile_4.txt"
            ;;
        *)
            log "ERROR: Invalid action number: $action_num"
            return 1
            ;;
    esac
    log "Starting action $action_num: $action_name"
    log_timestamp "$action_name" "Started"
    
    # Execute the command to create the text file on the target VM
    $SSH_CMD "$action_command"
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

# Get input parameters
read -p "Enter target VM username: " TARGET_USER
read -p "Enter target VM IP: " TARGET_IP
read -p "Enter target VM SSH port (default: 22): " TARGET_PORT
TARGET_PORT=${TARGET_PORT:-22}
read -p "Enter target folder name (e.g., van-buren-bubbles-wallex): " TARGET_FOLDER

# Build SSH connection string
SSH_CMD="ssh -p $TARGET_PORT $TARGET_USER@$TARGET_IP"

# Test SSH connection
log "Testing SSH connection..."
if ! $SSH_CMD "exit" > /dev/null 2>&1; then
    log "ERROR: Cannot connect to target VM ($TARGET_USER@$TARGET_IP:$TARGET_PORT)"
    exit 1
fi

# Check if folder exists
if ! $SSH_CMD "[ -d $TARGET_FOLDER ]"; then
    log "ERROR: Folder '$TARGET_FOLDER' does not exist on target VM"
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
echo "This will execute the following actions in order:"
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
echo -e "\nExecuting sequence..."
for (( i=0; i<${#sequence}; i++ )); do
    action_num=${sequence:$i:1}
    echo -e "\nExecuting step $(($i+1)) of ${#sequence}: Action $action_num"
    if ! execute_action $action_num; then
        echo "Sequence failed at step $(($i+1))"
        exit 1
    fi
done

echo -e "\nSequence completed successfully!"
echo "Timestamp log: $TIMESTAMP_LOG"
echo "Action log: $ACTION_LOG"
