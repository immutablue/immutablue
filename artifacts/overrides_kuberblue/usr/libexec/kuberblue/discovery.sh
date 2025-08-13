#!/bin/bash
# /usr/libexec/kuberblue/discovery.sh

set -euo pipefail

discover_control_planes() {
    local timeout=${1:-10}
    
    timeout "$timeout" avahi-browse -rt _kuberblue-cp._tcp 2>/dev/null | \
    grep "address = \[" | \
    sed 's/.*address = \[\(.*\)\].*/\1/' | \
    grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | \
    sort -u
}

discover_workers() {
    local timeout=${1:-10}
    
    timeout "$timeout" avahi-browse -rt _kuberblue-worker._tcp 2>/dev/null | \
    grep "address = \[" | \
    sed 's/.*address = \[\(.*\)\].*/\1/' | \
    grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | \
    sort -u
}

wait_for_control_plane() {
    local max_wait=${1:-300}
    local elapsed=0
    
    echo "Waiting for control plane (max ${max_wait}s)..."
    
    while [[ $elapsed -lt $max_wait ]]; do
        local control_plane
        control_plane=$(discover_control_planes 3)
        if [[ -n "$control_plane" ]]; then
            echo "$control_plane"
            return 0
        fi
        
        sleep 5
        ((elapsed += 5))
        
        if [[ $((elapsed % 30)) -eq 0 ]]; then
            echo "Still waiting for control plane... (${elapsed}s elapsed)"
        fi
    done
    
    return 1
}