#!/bin/bash

# ===================================================================
# SHIPYARD CLI GLOBAL INSTALLER
# ===================================================================

# Get absolute path of the current directory where the script is located
PROJECT_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BINARY_NAME="shipyard"
BINARY_PATH="$PROJECT_PATH/$BINARY_NAME"
TARGET_LINK="/usr/local/bin/$BINARY_NAME"

echo -e "\e[34m[INFO]\e[0m Setting up Shipyard CLI globally..."

# 1. Check if the binary exists
if [ ! -f "$BINARY_PATH" ]; then
    echo -e "\e[31m[ERROR]\e[0m '$BINARY_NAME' binary not found in $PROJECT_PATH."
    echo "Please run this script from the project root."
    exit 1
fi

# 2. Make the binary executable
chmod +x "$BINARY_PATH"
echo -e "\e[32m[SUCCESS]\e[0m Made '$BINARY_NAME' executable."

# 3. Create/Update the symbolic link dynamically
echo -e "\e[34m[INFO]\e[0m Creating symbolic link in $TARGET_LINK..."

# Attempt to remove existing link or file
if [ -L "$TARGET_LINK" ] || [ -f "$TARGET_LINK" ]; then
    sudo rm "$TARGET_LINK"
fi

# Create a fresh symlink pointing to THIS directory
sudo ln -s "$BINARY_PATH" "$TARGET_LINK"

if [ $? -eq 0 ]; then
    echo -e "\e[32m[SUCCESS]\e[0m Shipyard CLI is now installed globally!"
    echo "--------------------------------------------------------"
    echo "You can now run: shipyard server:list"
    echo "Path: $TARGET_LINK -> $BINARY_PATH"
    echo "--------------------------------------------------------"
else
    echo -e "\e[31m[ERROR]\e[0m Failed to create symbolic link. Sudo privileges required."
    exit 1
fi
