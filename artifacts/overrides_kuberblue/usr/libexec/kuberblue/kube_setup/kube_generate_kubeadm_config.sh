#!/bin/bash
# kube_generate_kubeadm_config.sh
#
# Generates /var/lib/kuberblue/generated/kubeadm-config.yaml at runtime.
#
# If /etc/kuberblue/kubeadm.yaml exists, it is used verbatim (user override).
# Otherwise, the entire kubeadm config is generated from cluster.yaml values:
#   - cluster.name
#   - cluster.container_runtime / cri_socket
#   - cluster.networking.pod_subnet / service_subnet / dns_domain
#   - cluster.advertise_address (auto-detect, tailscale, or explicit)
#   - cluster.ha.vip_address (for HA topology)
#
# Usage: source variables.sh first, then call this script.
set -euxo pipefail

source /usr/libexec/kuberblue/variables.sh
kuberblue_load_all

STATE_DIR="${STATE_DIR:-/var/lib/kuberblue}"
GENERATED_DIR="${STATE_DIR}/generated"
GENERATED_KUBEADM="${GENERATED_DIR}/kubeadm-config.yaml"

mkdir -p "${GENERATED_DIR}"

# --- User override: if /etc/kuberblue/kubeadm.yaml exists, use it verbatim ---
if [[ -f "/etc/kuberblue/kubeadm.yaml" ]]; then
    echo "Using user-provided kubeadm config from /etc/kuberblue/kubeadm.yaml"
    cp "/etc/kuberblue/kubeadm.yaml" "${GENERATED_KUBEADM}"
    echo "Generated kubeadm config: ${GENERATED_KUBEADM}"
    exit 0
fi

# --- Generate kubeadm config entirely from cluster.yaml values ---

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

# Read config values
# NOTE: Cilium Helm values (10-values.yaml) hardcode clusterPoolIPv4PodCIDRList
# to 10.244.0.0/16. If pod_subnet is changed, warn the operator.
CLUSTER_NAME="$(kuberblue_config_get cluster.yaml .cluster.name "kuberblue")"
POD_SUBNET="$(kuberblue_config_get cluster.yaml .cluster.networking.pod_subnet "10.244.0.0/16")"
SVC_SUBNET="$(kuberblue_config_get cluster.yaml .cluster.networking.service_subnet "10.96.0.0/16")"
DNS_DOMAIN="$(kuberblue_config_get cluster.yaml .cluster.networking.dns_domain "cluster.local")"
CRI_SOCKET="$(kuberblue_config_get cluster.yaml .cluster.cri_socket "/var/run/crio/crio.sock")"
NODE_NAME="$(hostname)"

# validate_input — reject values with characters unsafe for heredoc YAML
validate_input() {
    local name="$1" value="$2" pattern="$3"
    if ! [[ "$value" =~ $pattern ]]; then
        echo "ERROR: ${name} contains invalid characters: ${value}" >&2
        exit 1
    fi
}

# Validate all inputs before heredoc YAML generation to prevent injection
validate_input "CLUSTER_NAME" "${CLUSTER_NAME}" '^[a-zA-Z0-9-]+$'
validate_input "ADVERTISE_ADDR" "${ADVERTISE_ADDR}" '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'
validate_input "CRI_SOCKET" "${CRI_SOCKET}" '^[a-zA-Z0-9/_.-]+$'
validate_input "POD_SUBNET" "${POD_SUBNET}" '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+$'
validate_input "SVC_SUBNET" "${SVC_SUBNET}" '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+$'
validate_input "DNS_DOMAIN" "${DNS_DOMAIN}" '^[a-zA-Z0-9.-]+$'

# Validate pod_subnet matches Cilium's hardcoded CIDR
CILIUM_EXPECTED_CIDR="10.244.0.0/16"
if [[ "${POD_SUBNET}" != "${CILIUM_EXPECTED_CIDR}" ]]; then
    echo "WARNING: pod_subnet=${POD_SUBNET} does not match Cilium's hardcoded"
    echo "  clusterPoolIPv4PodCIDRList (${CILIUM_EXPECTED_CIDR}) in 00-cilium/10-values.yaml."
    echo "  Update the Cilium values file to match or pods will use the wrong CIDR."
fi

# Build InitConfiguration
cat > "${GENERATED_KUBEADM}" <<YAML
---
apiVersion: kubeadm.k8s.io/v1beta4
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: ${ADVERTISE_ADDR}
nodeRegistration:
  criSocket: ${CRI_SOCKET}
  name: ${NODE_NAME}
  kubeletExtraArgs:
    - name: volume-plugin-dir
      value: /opt/libexec/kubernetes/kubelet-plugins/volume/exec/
YAML

# Build ClusterConfiguration
cat >> "${GENERATED_KUBEADM}" <<YAML
---
apiVersion: kubeadm.k8s.io/v1beta4
kind: ClusterConfiguration
clusterName: ${CLUSTER_NAME}
controllerManager:
  extraArgs:
    - name: flex-volume-plugin-dir
      value: /opt/libexec/kubernetes/kubelet-plugins/volume/exec/
networking:
  podSubnet: ${POD_SUBNET}
  serviceSubnet: ${SVC_SUBNET}
  dnsDomain: ${DNS_DOMAIN}
YAML

# Patch controlPlaneEndpoint for HA topology (required for multi-master)
if [[ "${KUBERBLUE_TOPOLOGY}" == "ha" ]]; then
    VIP_ADDR="$(kuberblue_config_get cluster.yaml .cluster.ha.vip_address "")"
    if [[ -z "${VIP_ADDR}" ]] || [[ "${VIP_ADDR}" == "null" ]]; then
        echo "ERROR: topology=ha requires cluster.ha.vip_address to be set" >&2
        exit 1
    fi
    export VIP_VALUE="${VIP_ADDR}:6443"
    yq -i \
        '(select(.kind == "ClusterConfiguration") | .controlPlaneEndpoint) = strenv(VIP_VALUE)' \
        "${GENERATED_KUBEADM}"
fi

# Build KubeletConfiguration
cat >> "${GENERATED_KUBEADM}" <<YAML
---
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
cgroupDriver: systemd
YAML

echo "Generated kubeadm config: ${GENERATED_KUBEADM}"
echo "  clusterName:          ${CLUSTER_NAME}"
echo "  advertiseAddress:     ${ADVERTISE_ADDR}"
echo "  criSocket:            ${CRI_SOCKET}"
echo "  podSubnet:            ${POD_SUBNET}"
echo "  serviceSubnet:        ${SVC_SUBNET}"
echo "  dnsDomain:            ${DNS_DOMAIN}"
if [[ "${KUBERBLUE_TOPOLOGY}" == "ha" ]]; then
    echo "  controlPlaneEndpoint: ${VIP_ADDR}:6443"
fi
