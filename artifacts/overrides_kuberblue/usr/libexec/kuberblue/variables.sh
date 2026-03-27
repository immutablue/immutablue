#!/bin/bash
# Kuberblue runtime variables
#
# Config resolution order (per-key fallthrough):
#   /etc/kuberblue/<file>.yaml  — user runtime overrides (read-write, survives upgrades)
#   /usr/kuberblue/<file>.yaml  — vendor defaults (read-only, part of OS image)
#
# Each key is resolved independently: if a key exists and is non-null in
# /etc/, that value wins. If the key is missing or null in /etc/, the
# lookup falls through to /usr/ vendor defaults. Users override by copying
# the file to /etc/ and editing only the keys they need — unset keys
# inherit from the vendor defaults automatically.

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

# --- Lazy-loading accessors ---
# Each variable is resolved on first access via its function, then cached.
# This avoids 10+ yq subprocesses (and potential network calls) at source time.

# _kuberblue_lazy <VARNAME> <file> <yq_path> <default>
# On first call, runs kuberblue_config_get and caches in the named variable.
# Subsequent calls return the cached value.
_kuberblue_lazy () {
    local varname="$1" file="$2" path="$3" default="${4:-}"
    local current="${!varname-__KUBERBLUE_UNSET__}"
    if [[ "${current}" == "__KUBERBLUE_UNSET__" ]]; then
        printf -v "${varname}" '%s' "$(kuberblue_config_get "${file}" "${path}" "${default}")"
    fi
    echo "${!varname}"
}

kuberblue_install_dir ()       { _kuberblue_lazy INSTALL_DIR             settings.yaml .kuberblue.install_dir         "/usr/immutablue-build-kuberblue"; }
kuberblue_uid ()               { _kuberblue_lazy KUBERBLUE_UID           settings.yaml .kuberblue.uid                 "970"; }
kuberblue_topology ()          { _kuberblue_lazy KUBERBLUE_TOPOLOGY      cluster.yaml  .cluster.topology              "single"; }
kuberblue_node_role_raw ()     { _kuberblue_lazy KUBERBLUE_NODE_ROLE_RAW cluster.yaml  .cluster.node_role             "control-plane"; }
kuberblue_advertise_addr ()    { _kuberblue_lazy KUBERBLUE_ADVERTISE_ADDR cluster.yaml .cluster.advertise_address     "auto"; }
kuberblue_cni ()               { _kuberblue_lazy KUBERBLUE_CNI           cni.yaml      .networking.cni                "cilium"; }
kuberblue_tailscale_enabled () { _kuberblue_lazy KUBERBLUE_TAILSCALE_ENABLED cni.yaml  .networking.tailscale.enabled  "false"; }
kuberblue_gitops_enabled ()    { _kuberblue_lazy KUBERBLUE_GITOPS_ENABLED gitops.yaml  .gitops.enabled                "false"; }
kuberblue_sops_enabled ()      { _kuberblue_lazy KUBERBLUE_SOPS_ENABLED  security.yaml .security.sops.enabled         "false"; }
kuberblue_admin_user ()        { _kuberblue_lazy KUBERBLUE_ADMIN_USER    security.yaml .security.admin.user            "kuberblue"; }
kuberblue_admin_group ()       { _kuberblue_lazy KUBERBLUE_ADMIN_GROUP   security.yaml .security.admin.group           "kuberblue"; }
# NOTE: canonical UID is in settings.yaml (kuberblue.uid). This accessor
# is kept for backward compatibility; it falls through to the default "970".
kuberblue_admin_uid ()         { _kuberblue_lazy KUBERBLUE_ADMIN_UID     settings.yaml .kuberblue.uid                 "970"; }

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
    topology="$(kuberblue_topology)"

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
            # Validate ts_tag to prevent yq expression injection
            if ! [[ "${ts_tag}" =~ ^[a-zA-Z0-9_-]+$ ]]; then
                echo "ERROR: invalid Tailscale tag: ${ts_tag}" >&2
                return 1
            fi
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

# kuberblue_node_role — resolve node role with auto-detection support (lazy, cached)
kuberblue_node_role () {
    if [[ "${KUBERBLUE_NODE_ROLE:-__KUBERBLUE_UNSET__}" != "__KUBERBLUE_UNSET__" ]]; then
        echo "${KUBERBLUE_NODE_ROLE}"
        return 0
    fi
    local raw
    raw="$(kuberblue_node_role_raw)"
    if [[ "${raw}" == "auto" ]]; then
        KUBERBLUE_NODE_ROLE="$(kuberblue_detect_node_role)"
    else
        KUBERBLUE_NODE_ROLE="${raw}"
    fi
    echo "${KUBERBLUE_NODE_ROLE}"
}

# kuberblue_load_all — eagerly populate all KUBERBLUE_* variables.
# Call this in scripts that reference the variables directly (e.g. $KUBERBLUE_TOPOLOGY)
# rather than through accessor functions. This pays the yq cost once, up front.
kuberblue_load_all () {
    kuberblue_install_dir       >/dev/null
    kuberblue_uid               >/dev/null
    kuberblue_topology          >/dev/null
    kuberblue_advertise_addr    >/dev/null
    kuberblue_cni               >/dev/null
    kuberblue_tailscale_enabled >/dev/null
    kuberblue_gitops_enabled    >/dev/null
    kuberblue_sops_enabled      >/dev/null
    kuberblue_admin_user        >/dev/null
    kuberblue_admin_group       >/dev/null
    kuberblue_admin_uid         >/dev/null
    kuberblue_node_role         >/dev/null
}
