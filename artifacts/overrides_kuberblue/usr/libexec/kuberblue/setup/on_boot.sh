#!/bin/bash
set -uxo pipefail
# NOTE: -e is intentionally NOT set. This script is the top-level boot
# entrypoint for zero-touch provisioning. Individual commands handle their
# own errors; the script must NEVER die from a single transient failure
# because the systemd oneshot service won't auto-retry.

echo "invoking kuberblue boot script..."

# --- Phase 1: Environment prep (non-fatal) ---

# Disable swap — kubelet requires it off.
swapoff -a || echo "WARNING: swapoff -a failed (may be no swap to disable)"

# Fix DNS and NetworkManager config
/usr/libexec/kuberblue/setup/systemd_settings.sh || echo "WARNING: systemd_settings.sh failed"

# --- Phase 2: Provisioning (retried) ---
# first_boot.sh is idempotent — safe to retry. Each retry picks up where
# the previous attempt left off (kubeadm init gated on state, helm upgrade -i
# is idempotent, marker prevents re-running after success).
MAX_RETRIES=5
RETRY_WAIT=30

i=0
until /usr/libexec/kuberblue/setup/first_boot.sh; do
    i=$((i + 1))
    if [[ ${i} -ge ${MAX_RETRIES} ]]; then
        echo "ERROR: first_boot.sh failed after ${MAX_RETRIES} attempts. Manual intervention required."
        echo "Check journal: journalctl -u kuberblue-onboot.service"
        exit 1
    fi
    echo "first_boot.sh attempt ${i}/${MAX_RETRIES} failed, retrying in ${RETRY_WAIT}s..."
    sleep "${RETRY_WAIT}"
done
