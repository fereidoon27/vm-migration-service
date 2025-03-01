#!/bin/bash

# Define color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

while true; do


    echo -e "${CYAN}========================================${RESET}"
    echo -e "\n${YELLOW}This script runs from the main VM (e.g., Main-Crypto-AZMA), which has access to all other VMs.${RESET}"
    echo -e "\n${YELLOW}Select the action you would like to perform:${RESET}\n"

    echo -e "${GREEN}1: Deploy action.sh${RESET}"
    echo -e "   - ${CYAN}Remotely execute sequential actions on a target VM.${RESET}"
    echo -e "   - ${CYAN}Logs the timestamps for each action to keep track of progress.${RESET}"
    echo ""

    echo -e "${GREEN}2: Synchronize with sync.sh${RESET}"
    echo -e "   - ${CYAN}Sync a folder from a source VM to a destination VM.${RESET}"
    echo -e "   - ${CYAN}Direct synchronization or via an intermediate machine if needed.${RESET}"
    echo ""

    echo -e "${RED}0: Exit - Terminate the main script.${RESET}"
    echo -e "${CYAN}========================================${RESET}"


    
    # Prompt the user for input
    read -p "Enter a number (0, 1, 2): " choice

    case $choice in
        1)
            # Run action.sh script
            echo "Running action.sh..."
            ./action.sh
            ;;
        2)
            # Run sync.sh script
            echo "Running sync.sh..."
            ./sync.sh
            ;;
        0)
            # Exit the script
            echo "Exiting Main Script. Goodbye!"
            break
            ;;
        *)
            # Handle invalid input
            echo "Invalid choice. Please enter a valid number (0, 1, or 2)."
            ;;
    esac
done
