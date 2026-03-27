#!/bin/bash
# kube_tailscale_setup.sh
#
# Configure Tailscale as a host-level mesh networking daemon BEFORE the cluster
# exists. This runs during system boot (before kubeadm init) so that the
# Tailscale IP is available for use as the API server advertise address in
# multi-node and HA topologies.
#
# Must be run as root.
set -euxo pipefail

source /usr/libexec/kuberblue/variables.sh

if [[ "$(kuberblue_tailscale_enabled)" != "true" ]]; then
    echo "Tailscale not enabled in cni.yaml — skipping."
    exit 0
fi

if ! command -v tailscale &>/dev/null; then
    echo "ERROR: tailscale binary not found. Install tailscale package first."
    exit 1
fi

# Ensure tailscaled is running
if ! systemctl is-active --quiet tailscaled; then
    systemctl enable --now tailscaled
fi

# Wait for tailscaled to be ready
i=0
until tailscale status &>/dev/null; do
    i=$((i + 1))
    if [[ ${i} -ge 12 ]]; then
        echo "ERROR: tailscaled not ready after 60s"
        exit 1
    fi
    echo "Waiting for tailscaled... (${i}/12)"
    sleep 5
done

# Build the full argument list for a single `tailscale up` call.
# This avoids redundant re-authentication when the authkey was just used.
ADVERTISE_ROUTES="$(kuberblue_config_get cni.yaml .networking.tailscale.advertise_routes "")"
ACCEPT_ROUTES="$(kuberblue_config_get cni.yaml .networking.tailscale.accept_routes "true")"

ts_args=(--accept-routes="${ACCEPT_ROUTES}")
if [[ -n "${ADVERTISE_ROUTES}" ]] && [[ "${ADVERTISE_ROUTES}" != "null" ]]; then
    ts_args+=(--advertise-routes="${ADVERTISE_ROUTES}")
fi

# Check if already authenticated (tailscale ip -4 succeeds only when logged in)
if tailscale ip -4 &>/dev/null; then
    echo "Tailscale already authenticated. Updating route settings..."
else
    echo "Tailscale not authenticated."

    if [[ -f /etc/kuberblue/tailscale-authkey ]]; then
        # Trim whitespace/newlines from authkey
        AUTH_KEY="$(tr -d '[:space:]' < /etc/kuberblue/tailscale-authkey)"
        if [[ -z "${AUTH_KEY}" ]]; then
            echo "ERROR: /etc/kuberblue/tailscale-authkey exists but is empty"
            exit 1
        fi
        ts_args+=(--authkey="${AUTH_KEY}")
    else
        echo "ERROR: Tailscale enabled but no authkey found at /etc/kuberblue/tailscale-authkey"
        echo "Provide a pre-auth key or run 'tailscale up' manually before boot."
        exit 1
    fi
fi

# Suppress xtrace to prevent auth key from leaking into logs
{ set +x; } 2>/dev/null
tailscale up "${ts_args[@]}"
set -x

TS_IP="$(tailscale ip -4 2>/dev/null | head -1)"
if [[ -z "${TS_IP}" ]]; then
    echo "ERROR: Tailscale authenticated but could not retrieve IPv4 address"
    exit 1
fi
echo "Tailscale ready. Node IP: ${TS_IP}"

# Store Tailscale IP for use by kubeadm config generation
mkdir -p "${STATE_DIR}"
echo "${TS_IP}" > "${STATE_DIR}/tailscale-ip"
