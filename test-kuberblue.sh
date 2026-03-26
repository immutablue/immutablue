#!/bin/bash
# test-kuberblue.sh - Full zero-touch kuberblue test pipeline
#
# Builds, provisions, and drops you into a running Lima VM with a
# fully bootstrapped single-node Kubernetes cluster. No manual steps.
#
# Usage:
#   ./test-kuberblue.sh            # qcow2 -> lima -> wait -> shell
#   ./test-kuberblue.sh --build    # build image -> qcow2 -> lima -> wait -> shell
#   ./test-kuberblue.sh --skip-qcow2  # reuse existing qcow2 -> lima -> wait -> shell
#   ./test-kuberblue.sh --no-wait  # skip waiting for provisioning

set -euo pipefail

MAKE_FLAGS=(NUCLEUS=1 KUBERBLUE=1)
LIMA_INSTANCE="immutablue-43-kuberblue-nucleus"
LIMA_YAML=".lima/${LIMA_INSTANCE}.yaml"
IMAGE="quay.io/immutablue/immutablue:43-kuberblue-nucleus"

BUILD=0
SKIP_QCOW2=0
NO_WAIT=0

for arg in "$@"; do
    case "$arg" in
        --build)      BUILD=1 ;;
        --skip-qcow2) SKIP_QCOW2=1 ;;
        --no-wait)    NO_WAIT=1 ;;
        -h|--help)
            echo "Usage: $0 [--build] [--skip-qcow2] [--no-wait]"
            echo ""
            echo "  --build       Build container image before qcow2"
            echo "  --skip-qcow2  Reuse existing qcow2 disk image"
            echo "  --no-wait     Skip waiting for provisioning, go straight to shell"
            exit 0
            ;;
        *) echo "Unknown option: $arg"; echo "Usage: $0 [--build] [--skip-qcow2] [--no-wait]"; exit 1 ;;
    esac
done

cd "$(dirname "$0")"

# -- Build container image ---------------------------------------------------
if [[ "$BUILD" -eq 1 ]]; then
    echo "=== Step 1/5: Building container image ==="
    make "${MAKE_FLAGS[@]}" build

    # Force-refresh root storage so qcow2 step doesn't use a stale image.
    echo "=== Step 1b: Syncing image to root storage ==="
    if sudo podman image exists "$IMAGE" 2>/dev/null; then
        echo "Removing stale image from root storage..."
        sudo podman rmi "$IMAGE" 2>/dev/null || true
    fi
    echo "Transferring fresh build to root storage..."
    podman save "$IMAGE" | sudo podman load
fi

# -- Build qcow2 -------------------------------------------------------------
if [[ "$SKIP_QCOW2" -eq 0 ]]; then
    echo "=== Step 2/5: Building qcow2 disk image ==="
    make "${MAKE_FLAGS[@]}" LIMA=1 qcow2
fi

# -- Generate Lima config -----------------------------------------------------
echo "=== Step 3/5: Generating Lima config ==="
make "${MAKE_FLAGS[@]}" lima

# -- Start Lima VM ------------------------------------------------------------
echo "=== Step 4/5: Starting Lima VM ==="
if limactl list --format '{{.Name}}' 2>/dev/null | grep -q "^${LIMA_INSTANCE}$"; then
    echo "Deleting existing instance '${LIMA_INSTANCE}'..."
    limactl delete "${LIMA_INSTANCE}" --force
fi

# In plain mode, Lima can't detect the "running" state because there's no guest
# agent. limactl start will timeout — but the hostagent daemon + QEMU keep
# running in the background. We use a short timeout and then verify SSH directly.
echo "Starting VM (plain mode — timeout is expected, VM keeps running)..."
set +e
limactl start --tty=false --timeout 90s "${LIMA_YAML}" 2>&1
LIMA_RC=$?
set -e

# Verify the VM is actually running by checking SSH
echo ""
echo "Verifying SSH connectivity..."
SSH_OK=0
for i in $(seq 1 30); do
    if limactl shell "$LIMA_INSTANCE" -- true 2>/dev/null; then
        SSH_OK=1
        echo "SSH is up!"
        break
    fi
    sleep 2
done

if [[ "$SSH_OK" -eq 0 ]]; then
    echo "ERROR: VM did not become SSH-accessible after start."
    echo "Lima exit code was: $LIMA_RC"
    echo "Check: limactl list"
    echo "Logs: ~/.lima/${LIMA_INSTANCE}/serial.log"
    exit 1
fi

# -- Wait for provisioning ----------------------------------------------------
if [[ "$NO_WAIT" -eq 0 ]]; then
    echo ""
    echo "=== Step 5/5: Waiting for kuberblue provisioning ==="
    echo "(watching kuberblue-onboot.service — this takes 10-15 minutes)"
    echo ""

    MAX_WAIT=1200  # 20 minutes
    ELAPSED=0
    INTERVAL=10

    while [[ $ELAPSED -lt $MAX_WAIT ]]; do
        STATE=$(limactl shell "$LIMA_INSTANCE" -- \
            systemctl show kuberblue-onboot.service --property=ActiveState --value 2>/dev/null || echo "unknown")

        case "$STATE" in
            inactive)
                EXIT_CODE=$(limactl shell "$LIMA_INSTANCE" -- \
                    systemctl show kuberblue-onboot.service --property=ExecMainStatus --value 2>/dev/null || echo "?")
                if [[ "$EXIT_CODE" == "0" ]]; then
                    echo ""
                    echo "=== Provisioning complete! ==="
                    break
                else
                    echo ""
                    echo "=== Provisioning FAILED (exit code: $EXIT_CODE) ==="
                    echo "Check logs: limactl shell $LIMA_INSTANCE -- journalctl -u kuberblue-onboot.service --no-pager"
                    break
                fi
                ;;
            failed)
                echo ""
                echo "=== Provisioning FAILED ==="
                echo "Check logs: limactl shell $LIMA_INSTANCE -- journalctl -u kuberblue-onboot.service --no-pager"
                break
                ;;
            activating|active)
                LAST_LOG=$(limactl shell "$LIMA_INSTANCE" -- \
                    journalctl -u kuberblue-onboot.service --no-pager -n 1 -o cat 2>/dev/null || echo "...")
                printf "\r\033[K[%3ds] %s" "$ELAPSED" "${LAST_LOG:0:80}"
                ;;
            *)
                printf "\r\033[K[%3ds] waiting for service to start..." "$ELAPSED"
                ;;
        esac

        sleep "$INTERVAL"
        ELAPSED=$((ELAPSED + INTERVAL))
    done

    if [[ $ELAPSED -ge $MAX_WAIT ]]; then
        echo ""
        echo "=== TIMEOUT: Provisioning did not complete within ${MAX_WAIT}s ==="
    fi

    # Show cluster status
    echo ""
    echo "=== Cluster status ==="
    limactl shell "$LIMA_INSTANCE" -- sudo kubectl --kubeconfig /etc/kubernetes/admin.conf get nodes 2>/dev/null || true
    echo ""
    limactl shell "$LIMA_INSTANCE" -- sudo kubectl --kubeconfig /etc/kubernetes/admin.conf get pods -A --no-headers 2>/dev/null | \
        awk '{printf "  %-50s %s\n", $2, $4}' || true
    echo ""
fi

# -- Drop into shell -----------------------------------------------------------
echo "=== Entering Lima shell (exit with 'exit' or Ctrl-D) ==="
echo ""
exec limactl shell "$LIMA_INSTANCE"
