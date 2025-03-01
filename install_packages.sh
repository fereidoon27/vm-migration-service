#!/bin/bash

# Update package list
echo "Updating package list..."
sudo apt update -y

# Install required packages
echo "Installing zip, unzip, openjdk-17-jdk, telnet, chrony, and prometheus-node-exporter..."
sudo apt install -y zip unzip openjdk-17-jdk telnet chrony prometheus-node-exporter

# # Verify installation
# echo "Verifying installation..."
# for pkg in zip unzip openjdk-17-jdk telnet chrony prometheus-node-exporter; do
#     if dpkg -l | grep -q $pkg; then
#         echo "$pkg is installed successfully."
#     else
#         echo "Error: $pkg is not installed."
#     fi
# done

# # Enable and start chrony service
# echo "Enabling and starting chrony..."
# sudo systemctl enable chrony
# sudo systemctl start chrony

# # Enable and start prometheus-node-exporter
# echo "Enabling and starting prometheus-node-exporter..."
# sudo systemctl enable prometheus-node-exporter
# sudo systemctl start prometheus-node-exporter

# echo "Installation completed successfully!"


the destination vm dose not have the public ssh of source vm .
so transfering must be done through the main vm. 
but : 


