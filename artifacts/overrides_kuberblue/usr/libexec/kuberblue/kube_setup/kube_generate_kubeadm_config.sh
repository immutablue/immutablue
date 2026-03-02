#!/bin/bash
# kube_generate_kubeadm_config.sh
#
# Generates /var/lib/kuberblue/kubeadm-generated.yaml at runtime by merging:
#   1. /usr/kuberblue/kubeadm.yaml  (vendor template)
#   2. /etc/kuberblue/kubeadm.yaml  (user override, if present)
# and then patching in live values from cluster.yaml:
#   - advertiseAddress (auto-detect, tailscale IP, or explicit)
#   - criSocket
#   - podSubnet / serviceSubnet / dnsDomain
#   - controlPlaneEndpoint (for HA topology)
#
# Usage: source variables.sh first, then call this script.
set -euxo pipefail

source /usr/libexec/kuberblue/variables.sh

STATE_DIR="${STATE_DIR:-/var/lib/kuberblue}"
GENERATED_KUBEADM="${STATE_DIR}/kubeadm-generated.yaml"

mkdir -p "${STATE_DIR}"

# Resolve the kubeadm template (user override wins)
KUBEADM_TPL="/usr/kuberblue/kubeadm.yaml"
if [[ -f "/etc/kuberblue/kubeadm.yaml" ]]; then
    KUBEADM_TPL="/etc/kuberblue/kubeadm.yaml"
fi

# Resolve advertise address
resolve_advertise_address () {
    local addr="${KUBERBLUE_ADVERTISE_ADDR}"

    if [[ "${addr}" == "tailscale" ]]; then
        # Read stored Tailscale IP (written by kube_tailscale_setup.sh)
        if [[ -f "${STATE_DIR}/tailscale-ip" ]]; then
            addr="$(<"${STATE_DIR}/tailscale-ip")"
        elif command -v tailscale &>/dev/null; then
            addr="$(tailscale ip -4 2>/dev/null | head -1)"
        fi
        if [[ -z "${addr}" ]] || [[ "${addr}" == "tailscale" ]]; then
            echo "ERROR: tailscale advertise address requested but tailscale IP not available" >&2
            exit 1
        fi
    elif [[ "${addr}" == "auto" ]]; then
        # Use the primary interface IP (first non-loopback IPv4)
        addr="$(ip -4 route get 1 2>/dev/null | grep -oP '(?<=src )\S+' | head -1)"
        if [[ -z "${addr}" ]]; then
            # Fallback: first non-loopback address
            addr="$(hostname -I 2>/dev/null | awk '{print $1}')"
        fi
    fi

    if [[ -z "${addr}" ]]; then
        echo "ERROR: could not determine advertise address" >&2
        exit 1
    fi

    echo "${addr}"
}

ADVERTISE_ADDR="$(resolve_advertise_address)"

# Read networking config
POD_SUBNET="$(kuberblue_config_get cluster.yaml .cluster.networking.pod_subnet "10.244.0.0/16")"
SVC_SUBNET="$(kuberblue_config_get cluster.yaml .cluster.networking.service_subnet "10.96.0.0/16")"
DNS_DOMAIN="$(kuberblue_config_get cluster.yaml .cluster.networking.dns_domain "cluster.local")"
CRI_SOCKET="$(kuberblue_config_get cluster.yaml .cluster.cri_socket "/var/run/crio/crio.sock")"

# Determine node name
NODE_NAME="$(hostname)"

# Build the generated kubeadm config from the template
cp "${KUBEADM_TPL}" "${GENERATED_KUBEADM}"

# Patch InitConfiguration — use yq --arg for safe interpolation (no injection)
yq -i \
    --arg addr "${ADVERTISE_ADDR}" \
    --arg socket "${CRI_SOCKET}" \
    --arg name "${NODE_NAME}" \
    '(select(.kind == "InitConfiguration") | .localAPIEndpoint.advertiseAddress) = $addr |
     (select(.kind == "InitConfiguration") | .nodeRegistration.criSocket) = $socket |
     (select(.kind == "InitConfiguration") | .nodeRegistration.name) = $name' \
    "${GENERATED_KUBEADM}"

# Patch ClusterConfiguration
yq -i \
    --arg pod "${POD_SUBNET}" \
    --arg svc "${SVC_SUBNET}" \
    --arg dns "${DNS_DOMAIN}" \
    '(select(.kind == "ClusterConfiguration") | .networking.podSubnet) = $pod |
     (select(.kind == "ClusterConfiguration") | .networking.serviceSubnet) = $svc |
     (select(.kind == "ClusterConfiguration") | .networking.dnsDomain) = $dns' \
    "${GENERATED_KUBEADM}"

# Patch controlPlaneEndpoint for HA topology (required for multi-master)
if [[ "${KUBERBLUE_TOPOLOGY}" == "ha" ]]; then
    VIP_ADDR="$(kuberblue_config_get cluster.yaml .cluster.ha.vip_address "")"
    if [[ -z "${VIP_ADDR}" ]] || [[ "${VIP_ADDR}" == "null" ]]; then
        echo "ERROR: topology=ha requires cluster.ha.vip_address to be set" >&2
        exit 1
    fi
    yq -i \
        --arg vip "${VIP_ADDR}:6443" \
        '(select(.kind == "ClusterConfiguration") | .controlPlaneEndpoint) = $vip' \
        "${GENERATED_KUBEADM}"
fi

echo "Generated kubeadm config: ${GENERATED_KUBEADM}"
echo "  advertiseAddress:     ${ADVERTISE_ADDR}"
echo "  criSocket:            ${CRI_SOCKET}"
echo "  podSubnet:            ${POD_SUBNET}"
echo "  serviceSubnet:        ${SVC_SUBNET}"
echo "  dnsDomain:            ${DNS_DOMAIN}"
if [[ "${KUBERBLUE_TOPOLOGY}" == "ha" ]]; then
    echo "  controlPlaneEndpoint: ${VIP_ADDR}:6443"
fi
