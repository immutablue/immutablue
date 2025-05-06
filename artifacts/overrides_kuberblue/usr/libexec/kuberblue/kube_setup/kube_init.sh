#!/bin/bash 
set -euxo pipefail

sudo kubeadm init --skip-phases=addon/kube-proxy --config /etc/kuberblue/kubeadm.yaml | sudo tee /etc/kuberblue/kubeadm_init_result.log
