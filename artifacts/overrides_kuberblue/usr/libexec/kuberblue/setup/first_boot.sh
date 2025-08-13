#!/bin/bash 
set -euo pipefail

source /usr/libexec/kuberblue/99-common.sh

mkdir -p /etc/kuberblue
if [ ! -f /etc/kuberblue/did_first_boot ]; then 
    # Safety check: if control planes already exist, join as worker instead
    source /usr/libexec/kuberblue/discovery.sh
    if systemctl is-active --quiet avahi-daemon && discover_control_planes 5 | head -1 | grep -q .; then
        echo "Found existing control plane, joining as worker instead of creating new control plane"
        /usr/libexec/kuberblue/setup/first_boot_worker.sh
        exit 0
    fi
    
    sudo /usr/libexec/kuberblue/kube_setup/kube_init.sh
    touch /etc/kuberblue/did_first_boot
    export KUBECONFIG=/etc/kubernetes/admin.conf 
    sleep 5
    wait_for_node_ready_state
    sudo /usr/libexec/kuberblue/kube_setup/kube_post_install.sh
fi
