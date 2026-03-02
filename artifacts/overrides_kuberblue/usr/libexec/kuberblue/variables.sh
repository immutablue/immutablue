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
KUBERBLUE_NODE_ROLE="$(kuberblue_config_get cluster.yaml .cluster.node_role "control-plane")"
KUBERBLUE_ADVERTISE_ADDR="$(kuberblue_config_get cluster.yaml .cluster.advertise_address "auto")"

# Networking shortcuts
KUBERBLUE_CNI="$(kuberblue_config_get networking.yaml .networking.cni "cilium")"
KUBERBLUE_TAILSCALE_ENABLED="$(kuberblue_config_get networking.yaml .networking.tailscale.enabled "false")"

# GitOps shortcuts
KUBERBLUE_GITOPS_ENABLED="$(kuberblue_config_get gitops.yaml .gitops.enabled "false")"

# Secrets shortcuts
KUBERBLUE_SECRETS_ENABLED="$(kuberblue_config_get secrets.yaml .secrets.enabled "false")"
