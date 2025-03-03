#!/bin/bash

# Default values
# DEFAULT_REMOTE_USER="ubuntu"
# DEFAULT_REMOTE_IP="45.61.149.207"
# DEFAULT_SSH_PORT="22"

DEFAULT_REMOTE_USER="test1"
DEFAULT_REMOTE_IP="10.10.20.206"
DEFAULT_SSH_PORT="22"

# Prompt user for input with defaults
read -p "Enter remote VM username [$DEFAULT_REMOTE_USER]: " REMOTE_USER
REMOTE_USER=${REMOTE_USER:-$DEFAULT_REMOTE_USER}

read -p "Enter remote VM IP address [$DEFAULT_REMOTE_IP]: " REMOTE_IP
REMOTE_IP=${REMOTE_IP:-$DEFAULT_REMOTE_IP}

read -p "Enter SSH port [$DEFAULT_SSH_PORT]: " SSH_PORT
SSH_PORT=${SSH_PORT:-$DEFAULT_SSH_PORT}

# Display selected values
echo "Using:"
echo " - User: $REMOTE_USER"
echo " - IP: $REMOTE_IP"
echo " - SSH Port: $SSH_PORT"
echo "--------------------------------------"

# Define the commands to run on the remote VM
REMOTE_COMMANDS="
    echo 'Updating package list...'
    sudo apt-get update -y
    echo 'Upgrading installed packages...'
    sudo apt-get upgrade -y
    echo 'Rebooting system...'
    sudo reboot
"

# Execute commands remotely before reboot
echo "Connecting to $REMOTE_USER@$REMOTE_IP via SSH..."
ssh -p "$SSH_PORT" "$REMOTE_USER@$REMOTE_IP" "$REMOTE_COMMANDS"

# Wait for VM to reboot
echo "Waiting for the VM to reboot..."
sleep 30  # Adjust if necessary

# Install required packages after reboot
echo "Reconnecting to install additional packages..."
ssh -p "$SSH_PORT" "$REMOTE_USER@$REMOTE_IP" "
    echo 'Installing required packages...'
    sudo apt-get install -y zip unzip openjdk-17-jdk telnet chrony prometheus-node-exporter
    echo 'Installation completed successfully!'
"

echo "Remote update and installation process completed!"
