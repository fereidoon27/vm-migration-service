#!/bin/bash

# Default connection values
DEFAULT_USER="amin"
DEFAULT_IP="10.10.20.201"
DEFAULT_PORT="22"

# Ask for connection values with defaults
read -p "Enter username [$DEFAULT_USER]: " DEST_USER
DEST_USER=${DEST_USER:-$DEFAULT_USER}

read -p "Enter IP address [$DEFAULT_IP]: " DEST_IP
DEST_IP=${DEST_IP:-$DEFAULT_IP}

read -p "Enter SSH port [$DEFAULT_PORT]: " DEST_PORT
DEST_PORT=${DEST_PORT:-$DEFAULT_PORT}

# Create the remote script content that first detects the network
REMOTE_SCRIPT="
#!/bin/bash

# Detect the network environment on the remote server
# CURRENT_IP=\$(ip -4 -o addr show scope global | awk '{print \$4}' | cut -d/ -f1 | head -n1)
CURRENT_IP=172.20.10.20 #just for test
echo \"Detected IP on remote server: \$CURRENT_IP\"

# Determine the proper proxy setting based on network
if [[ \"\$CURRENT_IP\" == 172.20.* ]]; then
    echo \"Network: Internal (172.20.*) - Setting proxy to true\"
    SHOULD_USE_PROXY=true
else
    echo \"Network: External - Setting proxy to false\"
    SHOULD_USE_PROXY=false
fi

# Process the files
for dir in \$HOME/van-buren-*; do
    if [ -d \"\$dir\" ]; then
        find \"\$dir\" -name \"system*.edn\" | while read file; do
            echo \"Processing: \$file\"
            
            if [ \"\$SHOULD_USE_PROXY\" = \"true\" ]; then
                sed -i 's/\\(:use-proxy?[[:space:]]*\\)false/\\1true/g' \"\$file\"
                sed -i 's/\\(Set-Proxy?[[:space:]]*\\)false/\\1true/g' \"\$file\"
            else
                sed -i 's/\\(:use-proxy?[[:space:]]*\\)true/\\1false/g' \"\$file\"
                sed -i 's/\\(Set-Proxy?[[:space:]]*\\)true/\\1false/g' \"\$file\"
            fi
        done
    fi
done

echo \"Proxy settings updated based on remote server network.\"
"

# Execute the script on the remote server
echo "Connecting to ${DEST_USER}@${DEST_IP}:${DEST_PORT}..."
ssh -p "$DEST_PORT" "${DEST_USER}@${DEST_IP}" "$REMOTE_SCRIPT"

echo "Done."