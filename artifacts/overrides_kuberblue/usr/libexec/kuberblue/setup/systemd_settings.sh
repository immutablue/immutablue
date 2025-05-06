#!/bin/bash 
set -euxo pipefail

sudo rm /etc/resolv.conf
sudo systemctl restart NetworkManager
