#!/bin/bash
# kube_upgrade.sh — upgrade Kubernetes on this node
#
# Usage: kube_upgrade.sh [--force|-f] [<version>]
#   If no version specified, uses the version from kubeadm.
#   --force/-f skips interactive confirmation prompts.
#
# For control-plane: check etcd → drain → kubeadm upgrade apply → uncordon
# For worker: kubeadm upgrade node
set -euo pipefail

source /usr/libexec/kuberblue/99-common.sh
source /usr/libexec/kuberblue/variables.sh
source /usr/libexec/kuberblue/kube_setup/kube_state.sh

# Parse flags
FORCE=false
TARGET_VERSION=""
for arg in "$@"; do
    case "${arg}" in
        --force|-f) FORCE=true ;;
        -*) echo "Unknown flag: ${arg}"; exit 1 ;;
        *) TARGET_VERSION="${arg}" ;;
    esac
done

# Determine version
if [[ -z "${TARGET_VERSION}" ]]; then
    TARGET_VERSION="$(kubeadm version -o short 2>/dev/null || true)"
    if [[ -z "${TARGET_VERSION}" ]]; then
        echo "ERROR: Could not detect kubeadm version. Pass version as argument."
        exit 1
    fi
fi

echo "=== Kuberblue Upgrade ==="
echo "Target version: ${TARGET_VERSION}"

node_role="$(kuberblue_state_get node-role "$(kuberblue_node_role)")"
node_name="$(hostname)"

# Safety check: verify node is Ready
if command -v kubectl &>/dev/null; then
    node_status="$(kubectl get nodes "${node_name}" --no-headers 2>/dev/null | awk '{print $2}' || true)"
    if [[ "${node_status}" != "Ready" && -n "${node_status}" ]]; then
        echo "WARNING: Node ${node_name} status is '${node_status}', not 'Ready'"
        if [[ "${FORCE}" != "true" ]]; then
            read -r -p "Continue anyway? (yes/no): " confirm
            if [[ "${confirm}" != "yes" ]]; then
                echo "Aborted."
                exit 0
            fi
        else
            echo "Continuing (--force set)."
        fi
    fi
fi

# Version skew check
if command -v kubelet &>/dev/null; then
    kubelet_version="$(kubelet --version 2>/dev/null | awk '{print $2}' || true)"
    if [[ -n "${kubelet_version}" ]]; then
        echo "kubelet version:  ${kubelet_version}"
        echo "kubeadm version:  ${TARGET_VERSION}"
    fi
fi

if [[ "${node_role}" == "control-plane" ]]; then
    echo ""
    echo "--- Control-Plane Upgrade ---"

    # Check etcd health
    echo "Checking etcd health..."
    if command -v kubectl &>/dev/null; then
        etcd_pods="$(kubectl get pods -n kube-system -l component=etcd --no-headers 2>/dev/null || true)"
        if [[ -n "${etcd_pods}" ]]; then
            not_running="$(echo "${etcd_pods}" | grep -v "Running" || true)"
            if [[ -n "${not_running}" ]]; then
                echo "WARNING: etcd pods not all Running:"
                echo "${not_running}"
                echo "Upgrade may fail. Proceed with caution."
            else
                echo "etcd is healthy."
            fi
        fi
    fi

    # Drain self
    echo "Draining node ${node_name}..."
    kubectl drain "${node_name}" \
        --ignore-daemonsets \
        --delete-emptydir-data \
        --force \
        --timeout=120s 2>/dev/null || echo "WARNING: Drain failed or timed out"

    # Run upgrade
    echo "Running kubeadm upgrade apply ${TARGET_VERSION}..."
    kubeadm upgrade apply "${TARGET_VERSION}" --yes

    # Uncordon
    echo "Uncordoning node ${node_name}..."
    kubectl uncordon "${node_name}"

else
    echo ""
    echo "--- Worker Node Upgrade ---"

    echo "Running kubeadm upgrade node..."
    kubeadm upgrade node
fi

# Restart kubelet
echo "Restarting kubelet..."
systemctl daemon-reload
systemctl restart kubelet

echo ""
echo "=== Upgrade complete ==="
echo "Verify with: kubectl get nodes"
