#!/bin/bash
set -euxo pipefail

# Disable swap (required by kubelet)
swapoff -a || true

# CoreDNS manages cluster DNS; systemd-resolved conflicts with pod DNS resolution.
# It is masked via packages.yaml. Tell NetworkManager to write /etc/resolv.conf
# directly (dns=default) so pods can reach the upstream DNS.
NM_CONF="/etc/NetworkManager/NetworkManager.conf"
if [[ -f "${NM_CONF}" ]]; then
    if ! grep -q '^dns=' "${NM_CONF}"; then
        # Check if [main] section exists; if so, add under it
        if grep -q '^\[main\]' "${NM_CONF}"; then
            sed -i '/^\[main\]/a dns=default' "${NM_CONF}"
        else
            printf '\n[main]\ndns=default\n' >> "${NM_CONF}"
        fi
    fi
fi

if systemctl is-active --quiet NetworkManager; then
    systemctl restart NetworkManager || echo "WARNING: Failed to restart NetworkManager"
fi
