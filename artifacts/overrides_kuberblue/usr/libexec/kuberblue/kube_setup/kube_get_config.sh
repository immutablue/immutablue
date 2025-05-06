#!/bin/bash 
set -euxo pipefail

mkdir -p "$HOME"/.kube
sudo cp /etc/kubernetes/admin.conf "$HOME"/.kube/config 
sudo chown "$(id -u)":"$(id -g)" "$HOME"/.kube/config
