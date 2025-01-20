#!/bin/bash
set -euo pipefail

echo "Immutablue is starting up"

# Check for settings file, if not present create it 
if [[ ! -f /etc/immutablue/settings.yaml ]]
then 
    mkdir -p /etc/immutablue
    echo -e "# Immutablue Settings file -- see /usr/immutablue/settings.yaml\n" > /etc/immutablue/settings.yaml
fi

echo "Starting docs..."
systemctl enable --now immutablue.container

