#!/bin/bash
# kube_token_distribute.sh — Tailscale-based join token distribution
#
# Provides functions for serving and fetching Kubernetes join tokens
# over the Tailscale mesh network. Used when cluster.multi.token_distribution
# is set to 'tailscale'.
#
# Functions:
#   kuberblue_token_serve       — CP: serve join token via tailscale serve
#   kuberblue_token_fetch       — Worker: discover CP and fetch join token
#   kuberblue_token_stop_serve  — CP: stop serving the join token
#   kuberblue_token_discover_cp — Find the control-plane's Tailscale IP
#
# Usage: source this file, then call functions as needed.
#   source /usr/libexec/kuberblue/kube_setup/kube_token_distribute.sh

set -euo pipefail

# Ensure variables.sh is loaded (provides kuberblue_config_get, STATE_DIR, etc.)
if [[ -z "${STATE_DIR:-}" ]]; then
    source /usr/libexec/kuberblue/variables.sh
fi

KUBERBLUE_TOKEN_SERVE_PATH="/kuberblue/join-token"
KUBERBLUE_TOKEN_SERVE_PORT="443"

# kuberblue_token_serve [token_file]
# Serve the join token via Tailscale HTTPS serve.
# The token file defaults to ${STATE_DIR}/worker-join-command (where first_boot.sh writes it).
kuberblue_token_serve () {
    local token_file="${1:-${STATE_DIR}/worker-join-command}"

    if [[ ! -f "${token_file}" ]]; then
        echo "ERROR: Token file not found: ${token_file}" >&2
        echo "Generate a join token first with: kubeadm token create --print-join-command" >&2
        return 1
    fi

    if [[ ! -s "${token_file}" ]]; then
        echo "ERROR: Token file is empty: ${token_file}" >&2
        return 1
    fi

    if ! command -v tailscale &>/dev/null; then
        echo "ERROR: tailscale binary not found" >&2
        return 1
    fi

    # Verify Tailscale is connected
    if ! tailscale ip -4 &>/dev/null; then
        echo "ERROR: Tailscale is not connected. Cannot serve token." >&2
        return 1
    fi

    echo "Serving join token via Tailscale HTTPS..."
    # tailscale serve serves a local file over HTTPS on the Tailscale IP
    # --bg runs it in the background
    # --set-path sets the URL path
    tailscale serve --bg \
        --https="${KUBERBLUE_TOKEN_SERVE_PORT}" \
        --set-path="${KUBERBLUE_TOKEN_SERVE_PATH}" \
        "${token_file}"

    local ts_ip
    ts_ip="$(tailscale ip -4 2>/dev/null | head -1)"
    echo "Join token available at: https://${ts_ip}${KUBERBLUE_TOKEN_SERVE_PATH}"
    echo "Workers with Tailscale access can now auto-join."
}

# kuberblue_token_stop_serve
# Stop serving the join token via Tailscale.
kuberblue_token_stop_serve () {
    if ! command -v tailscale &>/dev/null; then
        echo "WARN: tailscale binary not found, nothing to stop" >&2
        return 0
    fi

    echo "Stopping Tailscale token serve..."
    tailscale serve --https="${KUBERBLUE_TOKEN_SERVE_PORT}" \
        --set-path="${KUBERBLUE_TOKEN_SERVE_PATH}" off 2>/dev/null || true
    echo "Token serving stopped."
}

# kuberblue_token_discover_cp
# Discover the control-plane node's Tailscale IP by filtering peers by tag.
# Prints the Tailscale IPv4 address of the first matching CP.
# Returns 1 if no CP is found.
kuberblue_token_discover_cp () {
    local ts_tag
    ts_tag="$(kuberblue_config_get cni.yaml .networking.tailscale.tag "")"

    if [[ -z "${ts_tag}" ]] || [[ "${ts_tag}" == "null" ]]; then
        echo "ERROR: networking.tailscale.tag is not set in cni.yaml" >&2
        echo "Cannot discover control-plane node without a Tailscale tag." >&2
        return 1
    fi

    if ! command -v tailscale &>/dev/null; then
        echo "ERROR: tailscale binary not found" >&2
        return 1
    fi

    if ! tailscale ip -4 &>/dev/null; then
        echo "ERROR: Tailscale is not connected" >&2
        return 1
    fi

    # Find peer(s) with the CP tag and extract their Tailscale IP
    local cp_ip
    cp_ip="$(tailscale status --json 2>/dev/null \
        | yq -r '[.Peer[] | select(.Tags // [] | .[] == "tag:'"${ts_tag}"'")] | .[0].TailscaleIPs[0] // ""')"

    if [[ -z "${cp_ip}" ]] || [[ "${cp_ip}" == "null" ]]; then
        echo "ERROR: No control-plane peer found with tag 'tag:${ts_tag}'" >&2
        echo "Ensure the CP node is tagged in Tailscale ACLs." >&2
        return 1
    fi

    echo "${cp_ip}"
}

# kuberblue_token_fetch [output_file]
# Discover the CP via Tailscale and fetch the join token.
# Writes the join command to output_file (default: ${STATE_DIR}/worker-join-command).
kuberblue_token_fetch () {
    local output_file="${1:-${STATE_DIR}/worker-join-command}"
    local max_retries=12
    local retry_interval=10

    echo "Discovering control-plane node via Tailscale..."

    local cp_ip=""
    local attempt=0
    while [[ -z "${cp_ip}" ]]; do
        attempt=$((attempt + 1))
        if [[ ${attempt} -gt ${max_retries} ]]; then
            echo "ERROR: Could not discover control-plane after ${max_retries} attempts" >&2
            return 1
        fi

        cp_ip="$(kuberblue_token_discover_cp 2>/dev/null)" || true
        if [[ -z "${cp_ip}" ]]; then
            echo "Waiting for control-plane to appear in tailnet... (${attempt}/${max_retries})"
            sleep "${retry_interval}"
        fi
    done

    echo "Found control-plane at Tailscale IP: ${cp_ip}"
    echo "Fetching join token..."

    local token_url="https://${cp_ip}${KUBERBLUE_TOKEN_SERVE_PATH}"
    local join_cmd=""

    attempt=0
    while [[ -z "${join_cmd}" ]]; do
        attempt=$((attempt + 1))
        if [[ ${attempt} -gt ${max_retries} ]]; then
            echo "ERROR: Could not fetch join token from ${token_url} after ${max_retries} attempts" >&2
            return 1
        fi

        # --insecure: Tailscale serve uses a self-signed cert by default
        # --connect-timeout: don't hang forever if CP isn't ready yet
        join_cmd="$(curl --silent --fail --connect-timeout 10 "${token_url}" 2>/dev/null)" || true

        if [[ -z "${join_cmd}" ]]; then
            echo "Waiting for token to be available at ${token_url}... (${attempt}/${max_retries})"
            sleep "${retry_interval}"
        fi
    done

    # Validate: join command should start with 'kubeadm join'
    if [[ "${join_cmd}" != kubeadm\ join* ]]; then
        echo "ERROR: Fetched data does not look like a kubeadm join command" >&2
        echo "Received: ${join_cmd:0:100}" >&2
        return 1
    fi

    # Write to file
    mkdir -p "$(dirname "${output_file}")"
    printf '%s\n' "${join_cmd}" > "${output_file}"
    chmod 0640 "${output_file}"
    chown root:kuberblue "${output_file}" 2>/dev/null || true

    echo "Join token fetched and stored at: ${output_file}"
}
