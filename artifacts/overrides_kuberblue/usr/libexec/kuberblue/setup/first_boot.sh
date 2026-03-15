#!/bin/bash
set -euo pipefail

source /usr/libexec/kuberblue/99-common.sh
source /usr/libexec/kuberblue/variables.sh

FIRST_BOOT_MARKER="/etc/kuberblue/did_first_boot"

mkdir -p /etc/kuberblue "${STATE_DIR}"

if [[ -f "${FIRST_BOOT_MARKER}" ]]; then
    echo "First boot already completed. Skipping init."
    exit 0
fi

echo "=== Kuberblue first boot: topology=${KUBERBLUE_TOPOLOGY}, role=${KUBERBLUE_NODE_ROLE} ==="

# --- Tailscale (host-level, must run before kubeadm) ---
if [[ "${KUBERBLUE_TAILSCALE_ENABLED}" == "true" ]]; then
    echo "Setting up Tailscale..."
    /usr/libexec/kuberblue/kube_setup/kube_tailscale_setup.sh
fi

# If advertise_address is 'tailscale', verify we actually have a Tailscale IP
if [[ "${KUBERBLUE_ADVERTISE_ADDR}" == "tailscale" ]] && [[ ! -f "${STATE_DIR}/tailscale-ip" ]]; then
    echo "ERROR: advertise_address=tailscale but Tailscale IP not available"
    echo "Ensure networking.tailscale.enabled=true in cni.yaml and an authkey is configured"
    exit 1
fi

# --- Control-plane init ---
if [[ "${KUBERBLUE_NODE_ROLE}" == "control-plane" ]]; then
    echo "Initializing Kubernetes control-plane..."
    /usr/libexec/kuberblue/kube_setup/kube_init.sh

    touch "${FIRST_BOOT_MARKER}"
    export KUBECONFIG=/etc/kubernetes/admin.conf

    echo "Waiting for node to become Ready..."
    sleep 5
    wait_for_node_ready_state

    # In single-node topology, untaint the control-plane so workloads can schedule
    if [[ "${KUBERBLUE_TOPOLOGY}" == "single" ]]; then
        echo "Single-node topology: removing control-plane taint..."
        /usr/libexec/kuberblue/kube_setup/kube_untaint_master.sh
    fi

    # Run post-install (user setup, deploy core manifests)
    KUBECONFIG="${KUBECONFIG}" /usr/libexec/kuberblue/kube_setup/kube_post_install.sh

    # SOPS+Age key setup (after cluster is ready)
    if [[ "${KUBERBLUE_SOPS_ENABLED}" == "true" ]]; then
        echo "Setting up SOPS+Age secrets..."
        KUBECONFIG="${KUBECONFIG}" /usr/libexec/kuberblue/kube_setup/kube_sops_setup.sh
    fi

    # Flux bootstrap (after core manifests are deployed)
    if [[ "${KUBERBLUE_GITOPS_ENABLED}" == "true" ]]; then
        echo "Bootstrapping Flux CD..."
        KUBECONFIG="${KUBECONFIG}" /usr/libexec/kuberblue/kube_setup/kube_flux_bootstrap.sh
    fi

    # Generate join token for multi/ha topologies
    if [[ "${KUBERBLUE_TOPOLOGY}" == "multi" ]] || [[ "${KUBERBLUE_TOPOLOGY}" == "ha" ]]; then
        echo "Generating worker join token..."
        kubeadm token create --print-join-command > "${STATE_DIR}/worker-join-command"
        chmod 0640 "${STATE_DIR}/worker-join-command"
        chown root:kuberblue "${STATE_DIR}/worker-join-command"
        echo "Worker join command stored at ${STATE_DIR}/worker-join-command"
        echo "Run 'kuberblue join-token' to retrieve it."
    fi

# --- Worker node join ---
elif [[ "${KUBERBLUE_NODE_ROLE}" == "worker" ]]; then
    if [[ -f "${STATE_DIR}/worker-join-command" ]]; then
        if [[ ! -s "${STATE_DIR}/worker-join-command" ]]; then
            echo "ERROR: worker-join-command exists but is empty"
            exit 1
        fi
        echo "Joining cluster as worker node..."
        bash "${STATE_DIR}/worker-join-command"
        touch "${FIRST_BOOT_MARKER}"
    else
        echo "ERROR: node_role is 'worker' but no join command found at ${STATE_DIR}/worker-join-command"
        echo "On the control-plane node, run: kuberblue join-token"
        echo "Then copy the join command to this node at ${STATE_DIR}/worker-join-command"
        exit 1
    fi
fi

echo "=== Kuberblue first boot complete ==="
