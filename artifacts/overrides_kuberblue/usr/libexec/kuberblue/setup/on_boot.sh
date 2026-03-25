#!/bin/bash
set -uxo pipefail
# NOTE: -e is intentionally NOT set. This script is the top-level boot
# entrypoint for zero-touch provisioning. Individual commands handle their
# own errors; the script must NEVER die from a single transient failure
# because the systemd oneshot service won't auto-retry.

echo "invoking kuberblue boot script..."

# --- Debug: show kubelet state at boot ---
echo "=== kubelet status at boot ==="
ls -la /etc/systemd/system/kubelet.service 2>&1 || echo "(no override in /etc)"
systemctl is-enabled kubelet.service 2>&1 || true
systemctl is-active kubelet.service 2>&1 || true
echo "=== end kubelet debug ==="

# --- Phase 1: Environment prep (non-fatal) ---

# Kill zram devices and disable ALL swap — kubelet refuses to start with swap on.
# Belt-and-suspenders: even if build-time removal worked, nuke it at runtime too.
if command -v zramctl &>/dev/null; then
    for dev in /dev/zram*; do
        [ -e "$dev" ] || continue
        swapoff "$dev" 2>/dev/null || true
        zramctl --reset "$(basename "$dev")" 2>/dev/null || true
        echo "Disabled zram device: $dev"
    done
fi
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
