#!/bin/bash

# Script to fix permissions for building containers in the devcontainer
# Run this as root inside the container if you encounter permission issues

echo "Fixing permissions for container operations..."

# Ensure the user has proper storage directories
mkdir -p /home/immutablue/.local/share/containers/storage
chown -R immutablue:immutablue /home/immutablue/.local

# Fix runtime directory
mkdir -p /run/user/1000
chown -R immutablue:immutablue /run/user/1000

# Fix setuid permissions for uid/gid mapping
chmod u+s /usr/bin/newuidmap /usr/bin/newgidmap

echo "Done! You should now be able to build containers."