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
    # Wait for NM to write the resolv.conf and fix the symlink.
    # systemd-resolved is masked, so /etc/resolv.conf -> stub-resolv.conf is a dead
    # symlink. Point it at the NM-managed file instead.
    retries=10
    while [[ ${retries} -gt 0 ]] && [[ ! -s /run/NetworkManager/resolv.conf ]]; do
        sleep 1
        retries=$(( retries - 1 ))
    done
    if [[ -s /run/NetworkManager/resolv.conf ]]; then
        ln -sf /run/NetworkManager/resolv.conf /etc/resolv.conf
    else
        echo "WARNING: NetworkManager did not write resolv.conf — DNS may not work"
    fi
fi
