#!/bin/bash
# test-kuberblue.sh - Build and spin up a Lima VM for kuberblue testing
#
# Usage:
#   ./test-kuberblue.sh            # qcow2 → lima config → lima start
#   ./test-kuberblue.sh --build    # full build → qcow2 → lima config → lima start
#   ./test-kuberblue.sh --skip-qcow2  # skip qcow2 (reuse existing) → lima config → lima start

set -euo pipefail

MAKE_FLAGS=(NUCLEUS=1 KUBERBLUE=1)
LIMA_INSTANCE="immutablue-43-kuberblue-nucleus"
LIMA_YAML=".lima/${LIMA_INSTANCE}.yaml"

BUILD=0
SKIP_QCOW2=0

for arg in "$@"; do
    case "$arg" in
        --build)      BUILD=1 ;;
        --skip-qcow2) SKIP_QCOW2=1 ;;
        *) echo "Unknown option: $arg"; echo "Usage: $0 [--build] [--skip-qcow2]"; exit 1 ;;
    esac
done

cd "$(dirname "$0")"

if [[ "$BUILD" -eq 1 ]]; then
    echo "=== Step: Building container image ==="
    make "${MAKE_FLAGS[@]}" build
fi

if [[ "$SKIP_QCOW2" -eq 0 ]]; then
    echo "=== Step: Building qcow2 image ==="
    make "${MAKE_FLAGS[@]}" LIMA=1 qcow2
fi

echo "=== Step: Generating Lima config ==="
make "${MAKE_FLAGS[@]}" lima

echo "=== Step: Starting Lima VM (non-interactive) ==="
if limactl list --format '{{.Name}}' 2>/dev/null | grep -q "^${LIMA_INSTANCE}$"; then
    echo "Existing instance '${LIMA_INSTANCE}' found, deleting..."
    limactl delete "${LIMA_INSTANCE}" --force
fi
limactl start --tty=false "${LIMA_YAML}"

echo ""
echo "=== VM is up. Useful commands: ==="
echo "  limactl shell ${LIMA_INSTANCE}"
echo "  limactl stop  ${LIMA_INSTANCE}"
echo "  journalctl -u kuberblue-onboot.service -f   (inside VM)"
echo "  kubectl get nodes                            (inside VM)"
