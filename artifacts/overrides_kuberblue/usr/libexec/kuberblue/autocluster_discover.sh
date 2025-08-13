#!/bin/bash
# Discover control planes and workers via mDNS

set -euo pipefail
source /usr/libexec/kuberblue/discovery.sh

discover_type="${1:-all}"
timeout="${2:-10}"

case "$discover_type" in
    "control-planes"|"cp")
        echo "[INFO] Discovering control planes (timeout: ${timeout}s)..."
        if control_planes=$(discover_control_planes "$timeout"); then
            if [[ -n "$control_planes" ]]; then
                echo "[SUCCESS] Found control planes:"
                echo "$control_planes"
            else
                echo "[INFO] No control planes found"
            fi
        else
            echo "[ERROR] Discovery failed"
            exit 1
        fi
        ;;
    "workers")
        echo "[INFO] Discovering workers (timeout: ${timeout}s)..."
        if workers=$(discover_workers "$timeout"); then
            if [[ -n "$workers" ]]; then
                echo "[SUCCESS] Found workers:"
                echo "$workers"
            else
                echo "[INFO] No workers found"
            fi
        else
            echo "[ERROR] Discovery failed"
            exit 1
        fi
        ;;
    "all")
        echo "[INFO] Discovering all kuberblue nodes (timeout: ${timeout}s)..."
        
        echo "Control Planes:"
        if control_planes=$(discover_control_planes "$timeout"); then
            if [[ -n "$control_planes" ]]; then
                echo "$control_planes"
            else
                echo "  None found"
            fi
        else
            echo "  Discovery failed"
        fi
        
        echo
        echo "Workers:"
        if workers=$(discover_workers "$timeout"); then
            if [[ -n "$workers" ]]; then
                echo "$workers"
            else
                echo "  None found"
            fi
        else
            echo "  Discovery failed"
        fi
        ;;
    *)
        echo "Usage: $0 [all|control-planes|workers] [timeout]"
        echo "  all (default): Discover both control planes and workers"
        echo "  control-planes: Discover only control planes"
        echo "  workers: Discover only workers"
        echo "  timeout: Discovery timeout in seconds (default: 10)"
        exit 1
        ;;
esac