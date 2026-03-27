#!/bin/bash
# kube_state.sh — runtime state management for kuberblue
#
# Provides functions to read/write persistent state markers in
# /var/lib/kuberblue/state/. State survives reboots and OS upgrades.
#
# Supported state markers:
#   node-role            — control-plane | worker
#   cluster-initialized  — set after successful kubeadm init/join
#   flux-bootstrapped    — set after Flux CD bootstrap completes
#   sops-configured      — set after SOPS+Age key generation
#   tailscale-configured — set after Tailscale setup completes
#
# Usage: source this file, then call kuberblue_state_* functions.
#   source /usr/libexec/kuberblue/kube_setup/kube_state.sh

KUBERBLUE_STATE_DIR="${STATE_DIR:-/var/lib/kuberblue}/state"

# Ensure state directory exists
kuberblue_state_init () {
    mkdir -p "${KUBERBLUE_STATE_DIR}"
}

# kuberblue_state_set <key> <value>
# Write a state marker. Creates the state directory if needed.
kuberblue_state_set () {
    local key="$1"
    local value="${2:-}"

    if [[ -z "${key}" ]]; then
        echo "ERROR: kuberblue_state_set requires a key" >&2
        return 1
    fi

    kuberblue_state_init
    printf '%s\n' "${value}" > "${KUBERBLUE_STATE_DIR}/${key}"
}

# kuberblue_state_get <key> [default]
# Read a state marker. Returns default (or empty) if not set.
kuberblue_state_get () {
    local key="$1"
    local default="${2:-}"
    local state_file="${KUBERBLUE_STATE_DIR}/${key}"

    if [[ -f "${state_file}" ]]; then
        cat "${state_file}"
    else
        echo "${default}"
    fi
}

# kuberblue_state_check <key>
# Returns 0 if the state marker exists, 1 if not.
kuberblue_state_check () {
    local key="$1"

    [[ -f "${KUBERBLUE_STATE_DIR}/${key}" ]]
}
