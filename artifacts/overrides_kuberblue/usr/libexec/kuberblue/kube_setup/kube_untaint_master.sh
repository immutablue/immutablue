#!/bin/bash 
set -euxo pipefail

KUBECONFIG=/etc/kubernetes/admin.conf kubectl taint nodes --all node-role.kubernetes.io/control-plane- || true
