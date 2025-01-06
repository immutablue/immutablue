#!/bin/bash
set -euo pipefail

echo "Immutablue is starting up"

echo "Starting docs..."
systemctl enable --now immutablue.build
systemctl enable --now immutablue.container

