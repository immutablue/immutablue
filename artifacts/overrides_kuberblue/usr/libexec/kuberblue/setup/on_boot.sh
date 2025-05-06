#!/bin/bash 
set -euxo pipefail

echo "invoking kuberblue boot script..."
sudo swapoff -a
/usr/libexec/kuberblue/setup/systemd_settings.sh
/usr/libexec/kuberblue/setup/first_boot.sh
