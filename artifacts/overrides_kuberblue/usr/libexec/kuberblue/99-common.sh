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

wait_for_node_ready_state() {
    until [[ "$(kubectl get nodes | grep -i $(hostname))" =~ \ Ready\  ]]; do sleep 5 && echo not-ready; done
}
