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
