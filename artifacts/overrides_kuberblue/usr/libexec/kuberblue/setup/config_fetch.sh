#!/bin/bash
set -uxo pipefail
# config_fetch.sh — Fetch cluster configuration from a remote git repo
#
# Reads bootstrap parameters from two sources (in priority order):
#   1. Kernel command line (/proc/cmdline) — kuberblue.* params
#   2. Cloud-init user-data — if cloud-init is available
#
# Parameters:
#   kuberblue.config       — Git repo URL (required to activate config fetch)
#   kuberblue.config.ref   — Git branch/tag (default: main)
#   kuberblue.config.path  — Subdirectory within repo (default: .)
#   kuberblue.config.token — Deploy token for private repos (optional)
#   kuberblue.age-key      — SOPS Age private key (optional)
#
# When kuberblue.config is set:
#   1. Clone the repo (with token if private)
#   2. Copy config files from repo path to /etc/kuberblue/
#   3. If age-key provided, write it to /var/lib/kuberblue/secrets/age.key
#   4. Decrypt any .sops.yaml files in the config using the age key
#
# When kuberblue.config is NOT set, this script is a no-op (exit 0).
# This preserves backward compatibility with the existing local-config flow.

CONFIG_MARKER="/var/lib/kuberblue/state/config-fetched"
SYSTEM_CONFIG_DIR="/etc/kuberblue"
SECRETS_DIR="/var/lib/kuberblue/secrets"
STATE_DIR="/var/lib/kuberblue/state"
CLONE_DIR="/var/lib/kuberblue/config-repo"

# -----------------------------------------------------------------------
# Parse a kuberblue.* parameter from /proc/cmdline
# Supports: kuberblue.key=value (no spaces in value)
# -----------------------------------------------------------------------
cmdline_get() {
    local key="$1"
    local default="${2:-}"
    local val=""

    if [[ -r /proc/cmdline ]]; then
        local cmdline
        cmdline="$(</proc/cmdline)"
        # Match kuberblue.key=value — value is everything until next space
        if [[ "$cmdline" =~ kuberblue\.${key}=([^[:space:]]+) ]]; then
            val="${BASH_REMATCH[1]}"
        fi
    fi

    if [[ -n "$val" ]]; then
        echo "$val"
    else
        echo "$default"
    fi
}

# -----------------------------------------------------------------------
# Parse a kuberblue parameter from cloud-init instance-data (JSON)
# Falls back to cmdline if cloud-init data unavailable
# -----------------------------------------------------------------------
cloudinit_get() {
    local key="$1"
    local default="${2:-}"
    local ci_data="/run/cloud-init/instance-data.json"

    # Try cloud-init instance data first
    if [[ -f "$ci_data" ]] && command -v python3 &>/dev/null; then
        local val
        val="$(python3 -c "
import json, sys
try:
    with open('$ci_data') as f:
        data = json.load(f)
    # Check userdata merged config
    ud = data.get('merged_cfg', {}).get('kuberblue', {})
    v = ud.get('${key}', '')
    if v:
        print(v)
        sys.exit(0)
    # Check ds/user-data vendordata
    for section in ['ds', 'userdata']:
        sd = data.get(section, {})
        if isinstance(sd, dict):
            kb = sd.get('kuberblue', {})
            if isinstance(kb, dict):
                v = kb.get('${key}', '')
                if v:
                    print(v)
                    sys.exit(0)
except Exception:
    pass
" 2>/dev/null)"
        if [[ -n "$val" ]]; then
            echo "$val"
            return 0
        fi
    fi

    # Also check cloud-init's /etc/cloud/cloud.cfg.d/ for kuberblue config
    local ci_kuberblue="/etc/cloud/cloud.cfg.d/99-kuberblue.cfg"
    if [[ -f "$ci_kuberblue" ]] && command -v yq &>/dev/null; then
        local val
        val="$(yq ".kuberblue.${key} // \"\"" "$ci_kuberblue" 2>/dev/null)"
        if [[ -n "$val" ]] && [[ "$val" != "null" ]]; then
            echo "$val"
            return 0
        fi
    fi

    # Fall back to kernel cmdline
    cmdline_get "$key" "$default"
}

# -----------------------------------------------------------------------
# Resolve all bootstrap parameters
# Priority: cloud-init > kernel cmdline > empty (no-op)
# -----------------------------------------------------------------------
resolve_params() {
    KB_CONFIG_URL="$(cloudinit_get "config" "")"
    KB_CONFIG_REF="$(cloudinit_get "config_ref" "main")"
    KB_CONFIG_PATH="$(cloudinit_get "config_path" ".")"
    KB_CONFIG_TOKEN="$(cloudinit_get "config_token" "")"
    KB_AGE_KEY="$(cloudinit_get "age_key" "")"
}

# -----------------------------------------------------------------------
# Clone or update the config repo
# -----------------------------------------------------------------------
clone_config_repo() {
    local url="$KB_CONFIG_URL"
    local ref="$KB_CONFIG_REF"
    local token="$KB_CONFIG_TOKEN"

    # Construct authenticated URL for private repos
    if [[ -n "$token" ]]; then
        # Support both HTTPS and SSH URLs
        if [[ "$url" == https://* ]]; then
            # Insert token: https://token@host/path -> https://oauth2:token@host/path
            url="$(echo "$url" | sed "s|https://|https://oauth2:${token}@|")"
        else
            echo "WARNING: Deploy token provided but URL is not HTTPS. Token ignored."
            echo "Private repos via SSH should use a deploy key instead."
        fi
    fi

    # Clean clone dir if it exists (ensure fresh state)
    if [[ -d "$CLONE_DIR" ]]; then
        rm -rf "$CLONE_DIR"
    fi

    echo "Cloning config repo: $KB_CONFIG_URL (ref: $ref)"
    if ! git clone --depth 1 --branch "$ref" --single-branch "$url" "$CLONE_DIR" 2>&1; then
        echo "ERROR: Failed to clone config repo: $KB_CONFIG_URL"
        echo "Check URL, branch, and network connectivity."
        return 1
    fi

    # Verify the config path exists
    local src="${CLONE_DIR}/${KB_CONFIG_PATH}"
    if [[ ! -d "$src" ]]; then
        echo "ERROR: Config path '$KB_CONFIG_PATH' not found in repo"
        echo "Available directories:"
        ls -la "$CLONE_DIR/" 2>/dev/null || true
        return 1
    fi

    echo "Config repo cloned successfully."
}

# -----------------------------------------------------------------------
# Install the Age key for SOPS decryption
# -----------------------------------------------------------------------
install_age_key() {
    local age_key="$KB_AGE_KEY"

    if [[ -z "$age_key" ]]; then
        return 0
    fi

    mkdir -p "$SECRETS_DIR"
    chmod 0750 "$SECRETS_DIR"

    local key_file="${SECRETS_DIR}/age.key"

    # Write the key (umask ensures it's never world-readable)
    (
        umask 0077
        printf '%s\n' "$age_key" > "$key_file"
    )

    chmod 0640 "$key_file"
    chown root:kuberblue "$key_file" 2>/dev/null || true

    echo "Age key installed at $key_file"
}

# -----------------------------------------------------------------------
# Decrypt SOPS files in the fetched config
# -----------------------------------------------------------------------
decrypt_sops_files() {
    local src="${CLONE_DIR}/${KB_CONFIG_PATH}"
    local age_key_file="${SECRETS_DIR}/age.key"

    if [[ ! -f "$age_key_file" ]]; then
        echo "No Age key available — skipping SOPS decryption"
        echo "SOPS-encrypted files will remain encrypted in /etc/kuberblue/"
        return 0
    fi

    if ! command -v sops &>/dev/null; then
        echo "WARNING: sops not found — cannot decrypt SOPS files"
        return 0
    fi

    local count=0
    while IFS= read -r -d '' sops_file; do
        local basename
        basename="$(basename "$sops_file")"
        # Decrypt in place: foo.sops.yaml -> foo.yaml
        local decrypted_name="${basename/.sops/}"
        local decrypted_path="$(dirname "$sops_file")/${decrypted_name}"

        echo "Decrypting: $basename -> $decrypted_name"
        if SOPS_AGE_KEY_FILE="$age_key_file" sops --decrypt "$sops_file" > "$decrypted_path"; then
            # Remove the encrypted version (decrypted version replaces it)
            rm -f "$sops_file"
            count=$((count + 1))
        else
            echo "WARNING: Failed to decrypt $basename — keeping encrypted version"
        fi
    done < <(find "$src" -type f \( -name "*.sops.yaml" -o -name "*.sops.json" \) -print0)

    echo "Decrypted $count SOPS files"
}

# -----------------------------------------------------------------------
# Copy config files from the cloned repo to /etc/kuberblue/
# -----------------------------------------------------------------------
install_config() {
    local src="${CLONE_DIR}/${KB_CONFIG_PATH}"

    mkdir -p "$SYSTEM_CONFIG_DIR"

    echo "Installing config from $src to $SYSTEM_CONFIG_DIR"

    # Copy all YAML/JSON config files, preserving directory structure
    # This handles: cluster.yaml, gitops.yaml, settings.yaml, security.yaml,
    # cni.yaml, packages.yaml, and any custom configs
    local count=0
    while IFS= read -r -d '' config_file; do
        local rel_path="${config_file#"$src"/}"
        local dest="${SYSTEM_CONFIG_DIR}/${rel_path}"
        local dest_dir
        dest_dir="$(dirname "$dest")"

        mkdir -p "$dest_dir"
        cp -v "$config_file" "$dest"
        count=$((count + 1))
    done < <(find "$src" -type f \( -name "*.yaml" -o -name "*.json" -o -name "*.conf" \) -print0)

    echo "Installed $count config files to $SYSTEM_CONFIG_DIR"

    # Also install manifests if present in the config repo
    local manifests_src="${src}/manifests"
    if [[ -d "$manifests_src" ]]; then
        echo "Installing custom manifests..."
        cp -rv "$manifests_src/." "${SYSTEM_CONFIG_DIR}/manifests/" 2>/dev/null || true
    fi
}

# -----------------------------------------------------------------------
# Clean up sensitive data from the clone dir
# -----------------------------------------------------------------------
cleanup() {
    # Remove the token from memory/environment
    KB_CONFIG_TOKEN=""
    KB_AGE_KEY=""

    # Remove the clone dir (config is now in /etc/kuberblue/)
    if [[ -d "$CLONE_DIR" ]]; then
        rm -rf "$CLONE_DIR"
        echo "Cleaned up config repo clone"
    fi
}

# =======================================================================
# MAIN
# =======================================================================

# Idempotency: skip if already fetched
if [[ -f "$CONFIG_MARKER" ]]; then
    echo "Config already fetched (marker: $CONFIG_MARKER). Skipping."
    exit 0
fi

# Resolve bootstrap parameters
resolve_params

# No config URL = no remote config fetch. This is the normal path for
# local-only deployments where config is baked into the image.
if [[ -z "$KB_CONFIG_URL" ]]; then
    echo "No kuberblue.config specified — using local config (no remote fetch)"
    exit 0
fi

echo "=== kuberblue config fetch ==="
echo "  config:      $KB_CONFIG_URL"
echo "  ref:         $KB_CONFIG_REF"
echo "  path:        $KB_CONFIG_PATH"
echo "  private:     $(if [[ -n "$KB_CONFIG_TOKEN" ]]; then echo "yes (deploy token)"; else echo "no (public)"; fi)"
echo "  age-key:     $(if [[ -n "$KB_AGE_KEY" ]]; then echo "provided"; else echo "not provided"; fi)"

# Ensure git is available
if ! command -v git &>/dev/null; then
    echo "ERROR: git not found. Cannot fetch config repo."
    exit 1
fi

mkdir -p "$STATE_DIR"

# Step 1: Install Age key first (needed for SOPS decryption)
install_age_key

# Step 2: Clone the config repo
if ! clone_config_repo; then
    cleanup
    exit 1
fi

# Step 3: Decrypt SOPS files in the cloned config
decrypt_sops_files

# Step 4: Install config to /etc/kuberblue/
install_config

# Step 5: Mark config as fetched
echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) fetched from $KB_CONFIG_URL ref=$KB_CONFIG_REF path=$KB_CONFIG_PATH" > "$CONFIG_MARKER"

# Step 6: Clean up
cleanup

echo "=== Config fetch complete ==="
