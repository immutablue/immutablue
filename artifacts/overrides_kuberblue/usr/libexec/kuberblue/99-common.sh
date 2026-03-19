#!/bin/bash

set -euo pipefail

is_empty() {
    [[ -z "$1" ]]
}

is_not_empty() {
   [[ -n "$1" ]]
}

is_file() {
    [[ -f "$1" ]]
}

is_dir() {
    [[ -d "$1" ]]
}

do_op_on_all_array_items() {
    local op="$1"
    shift

    for item in "$@"
    do
        $op "$item"
    done
}

# -----------------------------------------------------------------------
# Safe kubeadm join command parser — replaces eval on network-fetched data
# -----------------------------------------------------------------------
# Parses a kubeadm join command string, validates every field, and executes
# kubeadm join directly with validated arguments. Rejects anything that
# doesn't match the expected pattern.
#
# Usage:
#   kubeadm_join_safe <join_command_string> [--control-plane --certificate-key <key>]
#
# The join_command_string is the output of `kubeadm token create --print-join-command`.
# Optional extra args (--control-plane, --certificate-key) can be appended.
# -----------------------------------------------------------------------
kubeadm_join_safe () {
    local raw_cmd="$*"

    # Strip leading "kubeadm join " if present (the print-join-command output includes it)
    local args_str="${raw_cmd}"
    if [[ "${args_str}" =~ ^[[:space:]]*kubeadm[[:space:]]+join[[:space:]]+ ]]; then
        args_str="${args_str#*kubeadm}"
        args_str="${args_str#*join}"
        args_str="${args_str#"${args_str%%[![:space:]]*}"}"  # trim leading whitespace
    fi

    # Parse into an array, respecting whitespace splitting (no quotes/escapes expected)
    local -a tokens
    read -ra tokens <<< "${args_str}"

    local endpoint=""
    local token=""
    local ca_cert_hash=""
    local control_plane="false"
    local certificate_key=""
    local i=0

    while [[ ${i} -lt ${#tokens[@]} ]]; do
        local t="${tokens[${i}]}"
        case "${t}" in
            --token)
                i=$((i + 1))
                token="${tokens[${i}]:-}"
                ;;
            --discovery-token-ca-cert-hash)
                i=$((i + 1))
                ca_cert_hash="${tokens[${i}]:-}"
                ;;
            --control-plane)
                control_plane="true"
                ;;
            --certificate-key)
                i=$((i + 1))
                certificate_key="${tokens[${i}]:-}"
                ;;
            --*)
                echo "ERROR: kubeadm_join_safe: unexpected flag '${t}'" >&2
                echo "Only --token, --discovery-token-ca-cert-hash, --control-plane, and --certificate-key are allowed." >&2
                return 1
                ;;
            *)
                # Positional arg — must be the endpoint (first positional only)
                if [[ -z "${endpoint}" ]]; then
                    endpoint="${t}"
                else
                    echo "ERROR: kubeadm_join_safe: unexpected positional argument '${t}'" >&2
                    return 1
                fi
                ;;
        esac
        i=$((i + 1))
    done

    # --- Validate endpoint: hostname:port or ip:port ---
    if [[ -z "${endpoint}" ]]; then
        echo "ERROR: kubeadm_join_safe: no endpoint found in join command" >&2
        return 1
    fi
    # Must contain exactly one colon separating host from port
    if ! [[ "${endpoint}" =~ ^[a-zA-Z0-9._-]+:[0-9]+$ ]]; then
        echo "ERROR: kubeadm_join_safe: invalid endpoint '${endpoint}'" >&2
        echo "Expected format: hostname:port or ip:port" >&2
        return 1
    fi

    # --- Validate token: kubeadm format [a-z0-9]{6}.[a-z0-9]{16} ---
    if [[ -z "${token}" ]]; then
        echo "ERROR: kubeadm_join_safe: no --token found in join command" >&2
        return 1
    fi
    if ! [[ "${token}" =~ ^[a-z0-9]{6}\.[a-z0-9]{16}$ ]]; then
        echo "ERROR: kubeadm_join_safe: invalid token format '${token}'" >&2
        echo "Expected format: [a-z0-9]{6}.[a-z0-9]{16}" >&2
        return 1
    fi

    # --- Validate CA cert hash: sha256:<64 hex chars> ---
    if [[ -z "${ca_cert_hash}" ]]; then
        echo "ERROR: kubeadm_join_safe: no --discovery-token-ca-cert-hash found in join command" >&2
        return 1
    fi
    if ! [[ "${ca_cert_hash}" =~ ^sha256:[0-9a-f]{64}$ ]]; then
        echo "ERROR: kubeadm_join_safe: invalid CA cert hash '${ca_cert_hash}'" >&2
        echo "Expected format: sha256:<64 hex chars>" >&2
        return 1
    fi

    # --- Validate certificate-key if present: 64 hex chars ---
    if [[ -n "${certificate_key}" ]]; then
        if ! [[ "${certificate_key}" =~ ^[0-9a-f]{64}$ ]]; then
            echo "ERROR: kubeadm_join_safe: invalid certificate-key '${certificate_key}'" >&2
            echo "Expected format: 64 hex chars" >&2
            return 1
        fi
    fi

    # --- Build and execute validated kubeadm join ---
    local -a cmd=(kubeadm join "${endpoint}"
        --token "${token}"
        --discovery-token-ca-cert-hash "${ca_cert_hash}")

    if [[ "${control_plane}" == "true" ]]; then
        cmd+=(--control-plane)
        if [[ -n "${certificate_key}" ]]; then
            cmd+=(--certificate-key "${certificate_key}")
        fi
    fi

    echo "Executing: ${cmd[*]}"
    "${cmd[@]}"
}

wait_for_node_ready_state () {
    local timeout="${1:-300}"
    local elapsed=0
    local node_name
    node_name="$(hostname)"

    until kubectl get nodes --no-headers 2>/dev/null | grep "^${node_name} " | grep -q " Ready "; do
        elapsed=$((elapsed + 5))
        if [[ ${elapsed} -ge ${timeout} ]]; then
            echo "ERROR: Node ${node_name} did not become Ready within ${timeout}s"
            kubectl get nodes 2>/dev/null || true
            return 1
        fi
        echo "Waiting for node ${node_name} to become Ready (${elapsed}/${timeout}s)..."
        sleep 5
    done
    echo "Node ${node_name} is Ready"
}
