#!/bin/bash
set -euo pipefail

source /usr/libexec/kuberblue/99-common.sh

mkdir -p /etc/kuberblue

if [[ ! -f /etc/kuberblue/did_first_boot ]]; then
    echo "First boot: initializing control plane..."
    
    # Do the standard kuberblue cluster initialization
    sudo /usr/libexec/kuberblue/kube_setup/kube_init.sh
    touch /etc/kuberblue/did_first_boot
    export KUBECONFIG=/etc/kubernetes/admin.conf 
    sleep 5
    wait_for_node_ready_state
    sudo /usr/libexec/kuberblue/kube_setup/kube_post_install.sh
    
    # THEN advertise via mDNS (after cluster is ready)
    /usr/libexec/kuberblue/create_control_plane_service.sh
else
    echo "Subsequent boot: resuming control plane..."
    # Re-advertise control plane service
    /usr/libexec/kuberblue/create_control_plane_service.sh
fi