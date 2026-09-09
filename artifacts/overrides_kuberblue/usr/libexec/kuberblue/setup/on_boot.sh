#!/bin/bash
set -uxo pipefail
# NOTE: -e is intentionally NOT set. This script is the top-level boot
# entrypoint for zero-touch provisioning. Individual commands handle their
# own errors; retry required steps because the systemd oneshot service won't
# auto-retry. Exhausted config retries must stop before any provisioning.

echo "invoking kuberblue boot script..."

MAX_RETRIES=5
RETRY_WAIT=30

# Run each required boot step with bounded retries. A remote configuration
# failure must never fall through to vendor defaults and initialize a cluster
# with the wrong role. A fetch with no remote URL is already a successful no-op.
run_with_retries () {
    local script="$1"
    local attempt

    for ((attempt = 1; attempt <= MAX_RETRIES; attempt++)); do
        if "$script"; then
            return 0
        fi
        if [[ "$attempt" -lt "$MAX_RETRIES" ]]; then
            echo "${script} attempt ${attempt}/${MAX_RETRIES} failed, retrying in ${RETRY_WAIT}s..."
            sleep "$RETRY_WAIT"
        fi
    done

    echo "ERROR: ${script} failed after ${MAX_RETRIES} attempts. Provisioning stopped." >&2
    echo "Check journal: journalctl -u kuberblue-onboot.service" >&2
    return 1
}

# --- Phase 0: Config fetch (required before provisioning) ---
# If kuberblue.config is set (kernel cmdline or cloud-init), fetch cluster
# configuration from the remote git repo before anything else runs.
# This is a no-op when no config source is specified (local-only deploys).
run_with_retries /usr/libexec/kuberblue/setup/config_fetch.sh || exit 1

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
        zramctl --reset "$dev" 2>/dev/null || true
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
run_with_retries /usr/libexec/kuberblue/setup/first_boot.sh || exit 1
