#!/bin/bash
# Kuberblue configuration variables
# Values can be overridden via immutablue-settings

# Helper function to get setting with fallback
_get_kuberblue_setting() {
    local key="$1"
    local default="$2"
    local value
    if command -v immutablue-settings &>/dev/null; then
        value="$(immutablue-settings "${key}" 2>/dev/null)"
    fi
    if [[ -z "${value}" ]] || [[ "${value}" == "null" ]]; then
        echo "${default}"
    else
        echo "${value}"
    fi
}

INSTALL_DIR="$(_get_kuberblue_setting .kuberblue.install_dir "/usr/immutablue-build-kuberblue")"
CONFIG_DIR="$(_get_kuberblue_setting .kuberblue.config_dir "/etc/kuberblue")"
KUBERBLUE_UID="$(_get_kuberblue_setting .kuberblue.uid "970")"

# Clean up helper function
unset -f _get_kuberblue_setting
