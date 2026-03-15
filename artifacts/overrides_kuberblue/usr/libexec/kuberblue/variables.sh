#!/bin/bash
# Kuberblue runtime variables
#
# Config resolution order (per-file precedence, no key merging):
#   /etc/kuberblue/<file>.yaml  — user runtime overrides (read-write, survives upgrades)
#   /usr/kuberblue/<file>.yaml  — vendor defaults (read-only, part of OS image)
#
# Each config file is read atomically. If the file exists in /etc/, it wins
# entirely over the /usr/ copy. Users override by copying the file to /etc/
# and editing only what they need.

VENDOR_CONFIG_DIR="/usr/kuberblue"
SYSTEM_CONFIG_DIR="/etc/kuberblue"
STATE_DIR="/var/lib/kuberblue"

# kuberblue_config_get <file> <yq_path> <default>
# Reads a value from a config file, checking /etc/ before /usr/.
kuberblue_config_get () {
    local file="$1"
    local path="$2"
    local default="${3:-}"
    local value=""

    for dir in "${SYSTEM_CONFIG_DIR}" "${VENDOR_CONFIG_DIR}"; do
        local cfg="${dir}/${file}"
        if [[ -f "${cfg}" ]]; then
            if ! command -v yq &>/dev/null; then
                echo "ERROR: yq not found — cannot read config" >&2
                echo "${default}"
                return 1
            fi
            value="$(yq "${path}" "${cfg}" 2>/dev/null)"
            if [[ -n "${value}" ]] && [[ "${value}" != "null" ]]; then
                echo "${value}"
                return 0
            fi
            # File exists but key is missing/null — fall through to next dir
        fi
    done

    echo "${default}"
}

INSTALL_DIR="$(kuberblue_config_get settings.yaml .kuberblue.install_dir "/usr/immutablue-build-kuberblue")"
KUBERBLUE_UID="$(kuberblue_config_get settings.yaml .kuberblue.uid "970")"

# Cluster config shortcuts (from /usr/kuberblue/cluster.yaml or /etc/ override)
KUBERBLUE_TOPOLOGY="$(kuberblue_config_get cluster.yaml .cluster.topology "single")"
KUBERBLUE_NODE_ROLE_RAW="$(kuberblue_config_get cluster.yaml .cluster.node_role "control-plane")"
KUBERBLUE_ADVERTISE_ADDR="$(kuberblue_config_get cluster.yaml .cluster.advertise_address "auto")"

# kuberblue_detect_node_role — auto-detect the node role when configured as 'auto'
#
# Detection order:
#   1. If cluster-initialized state exists → use stored node-role
#   2. If /etc/kubernetes/admin.conf exists → control-plane
#   3. If Tailscale available and a CP node is already tagged → worker
#   4. Default: worker (multi/ha) or control-plane (single)
#
# Returns the detected role on stdout.
kuberblue_detect_node_role () {
    local topology
    topology="$(kuberblue_config_get cluster.yaml .cluster.topology "single")"

    # 1. Check persistent state from a previous boot
    local state_dir="${STATE_DIR:-/var/lib/kuberblue}"
    local state_file="${state_dir}/state/node-role"
    if [[ -f "${state_file}" ]]; then
        cat "${state_file}"
        return 0
    fi

    # 2. If admin.conf exists, this node was previously a control-plane
    if [[ -f /etc/kubernetes/admin.conf ]]; then
        echo "control-plane"
        return 0
    fi

    # 3. If Tailscale is available, check for an existing CP in the tailnet
    if command -v tailscale &>/dev/null && tailscale ip -4 &>/dev/null 2>&1; then
        local ts_tag
        ts_tag="$(kuberblue_config_get cni.yaml .networking.tailscale.tag "")"
        if [[ -n "${ts_tag}" ]] && [[ "${ts_tag}" != "null" ]]; then
            # If we can see a peer with the CP tag, we are a worker
            if tailscale status --json 2>/dev/null \
                | yq -e '.Peer[] | select(.Tags // [] | .[] == "tag:'"${ts_tag}"'")' &>/dev/null; then
                echo "worker"
                return 0
            fi
        fi
    fi

    # 4. Default based on topology
    if [[ "${topology}" == "single" ]]; then
        echo "control-plane"
    else
        echo "worker"
    fi
}

# Resolve node role — use auto-detection if configured as 'auto'
if [[ "${KUBERBLUE_NODE_ROLE_RAW}" == "auto" ]]; then
    KUBERBLUE_NODE_ROLE="$(kuberblue_detect_node_role)"
else
    KUBERBLUE_NODE_ROLE="${KUBERBLUE_NODE_ROLE_RAW}"
fi

# Networking shortcuts
KUBERBLUE_CNI="$(kuberblue_config_get cni.yaml .networking.cni "cilium")"
KUBERBLUE_TAILSCALE_ENABLED="$(kuberblue_config_get cni.yaml .networking.tailscale.enabled "false")"

# GitOps shortcuts
KUBERBLUE_GITOPS_ENABLED="$(kuberblue_config_get gitops.yaml .gitops.enabled "false")"

# Security shortcuts
KUBERBLUE_SOPS_ENABLED="$(kuberblue_config_get security.yaml .security.sops.enabled "false")"
KUBERBLUE_ADMIN_USER="$(kuberblue_config_get security.yaml .security.admin.user "kuberblue")"
KUBERBLUE_ADMIN_GROUP="$(kuberblue_config_get security.yaml .security.admin.group "kuberblue")"
KUBERBLUE_ADMIN_UID="$(kuberblue_config_get security.yaml .security.admin.uid "970")"
