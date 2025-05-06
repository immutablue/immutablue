#!/bin/bash 
set -euo pipefail

source /usr/libexec/kuberblue/99-common.sh

mkdir -p /etc/kuberblue
if [ ! -f /etc/kuberblue/did_first_boot ]; then 
    sudo /usr/libexec/kuberblue/kube_setup/kube_init.sh
    touch /etc/kuberblue/did_first_boot
    export KUBECONFIG=/etc/kubernetes/admin.conf 
    sleep 5
    wait_for_node_ready_state
    sudo /usr/libexec/kuberblue/kube_setup/kube_post_install.sh
fi
