#!/bin/bash
set -euxo pipefail

# Set up kubeconfig for the kuberblue service user only.
# Human users should run `kuberblue get-config` themselves to opt in.

KUBECONFIG_SRC="/etc/kubernetes/admin.conf"
KUBERBLUE_HOME="/var/home/kuberblue"

if [[ ! -f "${KUBECONFIG_SRC}" ]]; then
    echo "ERROR: ${KUBECONFIG_SRC} not found. Was kubeadm init successful?"
    exit 1
fi

mkdir -p "${KUBERBLUE_HOME}/.kube"
install -o kuberblue -g kuberblue -m 0600 "${KUBECONFIG_SRC}" "${KUBERBLUE_HOME}/.kube/config"
chown kuberblue:kuberblue "${KUBERBLUE_HOME}/.kube"

echo "Kubeconfig installed for kuberblue service user."
echo "Human users: run 'kuberblue get-config' to set up your own ~/.kube/config"
