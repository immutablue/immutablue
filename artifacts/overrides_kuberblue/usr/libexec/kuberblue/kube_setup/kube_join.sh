#!/bin/bash
# kube_join.sh — join a worker node to an existing kuberblue cluster
#
# Usage: kube_join.sh [<join-command>]
#   If no argument, reads from ${STATE_DIR}/worker-join-command
set -euo pipefail

source /usr/libexec/kuberblue/99-common.sh
source /usr/libexec/kuberblue/variables.sh
source /usr/libexec/kuberblue/kube_setup/kube_state.sh

JOIN_CMD_FILE="${STATE_DIR}/worker-join-command"

# Check if already joined
if kuberblue_state_check "cluster-initialized"; then
    echo "ERROR: This node is already joined to a cluster."
    echo "Run 'kuberblue reset' first to leave the cluster."
    exit 1
fi

# Validate CRI-O is running
if ! systemctl is-active --quiet crio 2>/dev/null; then
    echo "ERROR: CRI-O is not running. Start it first: systemctl start crio"
    exit 1
fi

# Determine join command
join_cmd=""
if [[ $# -gt 0 ]]; then
    join_cmd="$*"
elif [[ -f "${JOIN_CMD_FILE}" ]]; then
    if [[ ! -s "${JOIN_CMD_FILE}" ]]; then
        echo "ERROR: ${JOIN_CMD_FILE} exists but is empty"
        exit 1
    fi
    join_cmd="$(<"${JOIN_CMD_FILE}")"
else
    echo "ERROR: No join command provided and ${JOIN_CMD_FILE} not found."
    echo ""
    echo "Usage:"
    echo "  kuberblue join <kubeadm join command...>"
    echo "  kuberblue join  (reads from ${JOIN_CMD_FILE})"
    echo ""
    echo "On the control-plane node, run: kuberblue refresh-token"
    exit 1
fi

echo "=== Joining cluster as worker node ==="
echo "Join command: ${join_cmd}"

# Run kubeadm join (safe parse — no eval on untrusted data)
kubeadm_join_safe "${join_cmd}"

# Write state markers
kuberblue_state_set "node-role" "worker"
kuberblue_state_set "cluster-initialized" "true"

echo ""
echo "=== Successfully joined cluster as worker ==="
