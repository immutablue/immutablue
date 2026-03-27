#!/bin/bash
# kube_vip_setup.sh — generate kube-vip static pod manifest for HA VIP
#
# CRITICAL: This must run BEFORE kubeadm init in the HA flow.
# The VIP must be reachable for the control plane endpoint to work.
#
# Generates /etc/kubernetes/manifests/kube-vip.yaml as a static pod.
# Reads ha.vip_address and ha.vip_interface from cluster.yaml.
#
# Usage:
#   /usr/libexec/kuberblue/kube_setup/kube_vip_setup.sh
# Or source and call:
#   source kube_vip_setup.sh
#   kuberblue_vip_setup

set -euo pipefail

# Ensure variables.sh is loaded
if [[ -z "${STATE_DIR:-}" ]]; then
    source /usr/libexec/kuberblue/variables.sh
fi

# kube-vip image version — configurable via cluster.yaml (.cluster.ha.kube_vip_version)
# Keep the default fallback up to date when bumping versions.
_kube_vip_version="$(kuberblue_config_get cluster.yaml .cluster.ha.kube_vip_version "v0.8.7")"
KUBE_VIP_IMAGE="${KUBE_VIP_IMAGE:-ghcr.io/kube-vip/kube-vip:${_kube_vip_version}}"
KUBE_VIP_MANIFEST="/etc/kubernetes/manifests/kube-vip.yaml"

# kuberblue_vip_detect_interface
# Auto-detect the primary network interface (the one with the default route).
kuberblue_vip_detect_interface () {
    local iface
    iface="$(ip -4 route show default 2>/dev/null | awk '{print $5; exit}')"
    if [[ -z "${iface}" ]]; then
        echo "ERROR: Could not auto-detect primary network interface" >&2
        return 1
    fi
    echo "${iface}"
}

# validate_input — reject values with characters unsafe for heredoc YAML
validate_input() {
    local name="$1" value="$2" pattern="$3"
    if ! [[ "$value" =~ $pattern ]]; then
        echo "ERROR: ${name} contains invalid characters: ${value}" >&2
        exit 1
    fi
}

# kuberblue_vip_setup
# Generate the kube-vip static pod manifest for ARP-based L2 VIP.
kuberblue_vip_setup () {
    local vip_address
    local vip_interface

    vip_address="$(kuberblue_config_get cluster.yaml .cluster.ha.vip_address "")"
    vip_interface="$(kuberblue_config_get cluster.yaml .cluster.ha.vip_interface "")"

    # Validate VIP address
    if [[ -z "${vip_address}" ]] || [[ "${vip_address}" == "null" ]]; then
        echo "ERROR: cluster.ha.vip_address must be set for HA topology" >&2
        echo "Set it in /etc/kuberblue/cluster.yaml under cluster.ha.vip_address" >&2
        return 1
    fi

    # Validate VIP address looks like an IP
    if ! [[ "${vip_address}" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "ERROR: cluster.ha.vip_address '${vip_address}' does not look like a valid IPv4 address" >&2
        return 1
    fi

    # Auto-detect interface if not configured
    if [[ -z "${vip_interface}" ]] || [[ "${vip_interface}" == "null" ]]; then
        echo "No vip_interface configured — auto-detecting..."
        vip_interface="$(kuberblue_vip_detect_interface)"
        echo "Detected primary interface: ${vip_interface}"
    fi

    # Validate all inputs before heredoc YAML generation to prevent injection
    validate_input "KUBE_VIP_IMAGE" "${KUBE_VIP_IMAGE}" '^[a-zA-Z0-9._/-]+:[a-zA-Z0-9._-]+$'
    validate_input "vip_interface" "${vip_interface}" '^[a-zA-Z0-9._-]+$'
    validate_input "vip_address" "${vip_address}" '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'

    # Ensure manifests directory exists (kubeadm may not have created it yet)
    mkdir -p "$(dirname "${KUBE_VIP_MANIFEST}")"

    echo "Generating kube-vip static pod manifest..."
    echo "  VIP address:   ${vip_address}"
    echo "  VIP interface: ${vip_interface}"
    echo "  Image:         ${KUBE_VIP_IMAGE}"

    cat > "${KUBE_VIP_MANIFEST}" <<MANIFEST
apiVersion: v1
kind: Pod
metadata:
  name: kube-vip
  namespace: kube-system
spec:
  containers:
  - name: kube-vip
    image: ${KUBE_VIP_IMAGE}
    imagePullPolicy: IfNotPresent
    args:
    - manager
    env:
    - name: vip_arp
      value: "true"
    - name: port
      value: "6443"
    - name: vip_interface
      value: "${vip_interface}"
    - name: vip_cidr
      value: "32"
    - name: cp_enable
      value: "true"
    - name: cp_namespace
      value: kube-system
    - name: vip_ddns
      value: "false"
    - name: svc_enable
      value: "false"
    - name: vip_leaderelection
      value: "true"
    - name: vip_leasename
      value: plndr-cp-lock
    - name: vip_leaseduration
      value: "5"
    - name: vip_renewdeadline
      value: "3"
    - name: vip_retryperiod
      value: "1"
    - name: address
      value: "${vip_address}"
    - name: prometheus_server
      value: :2112
    securityContext:
      capabilities:
        add:
        - NET_ADMIN
        - NET_RAW
    volumeMounts:
    - mountPath: /etc/kubernetes/admin.conf
      name: kubeconfig
  hostAliases:
  - hostnames:
    - kubernetes
    ip: 127.0.0.1
  hostNetwork: true
  volumes:
  - hostPath:
      path: /etc/kubernetes/admin.conf
    name: kubeconfig
MANIFEST

    echo "kube-vip manifest written to ${KUBE_VIP_MANIFEST}"
}

# If run directly (not sourced), execute setup
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    kuberblue_vip_setup
fi
