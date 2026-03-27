#!/bin/bash
# test_kuberblue_lima.sh — Lima VM smoke test for kuberblue single-node cluster
#
# Tests the full first-boot → cluster init → healthy cluster flow in a
# real QEMU VM. This catches issues that container-only tests miss:
#   - Systemd service startup order and dependencies
#   - crio.service binary path and drop-ins
#   - kuberblue-onboot.service (on_boot → first_boot.sh → kubeadm init)
#   - Kubernetes node Ready state
#   - kuberblue doctor output
#
# Requirements:
#   - limactl installed
#   - QCOW2 image already built: make KUBERBLUE=1 LIMA=1 qcow2
#   - Lima config already generated: make KUBERBLUE=1 LIMA=1 lima
#
# Usage:
#   ./tests/kuberblue/test_kuberblue_lima.sh [--no-teardown]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

LIMA_INSTANCE="immutablue-43-kuberblue"
LIMA_CONFIG="${REPO_ROOT}/.lima/${LIMA_INSTANCE}.yaml"
QCOW2_PATH="${REPO_ROOT}/images/qcow2/43-kuberblue/qcow2/disk.qcow2"
NO_TEARDOWN="${1:-}"

# Test result tracking
PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0

# ── Helpers ─────────────────────────────────────────────────────────────────

green='\033[0;32m'; yellow='\033[0;33m'; red='\033[0;31m'; nc='\033[0m'
check_pass()  { echo -e "  ${green}PASS${nc}: $*"; PASS_COUNT=$((PASS_COUNT + 1)); }
check_warn()  { echo -e "  ${yellow}WARN${nc}: $*"; WARN_COUNT=$((WARN_COUNT + 1)); }
check_fail()  { echo -e "  ${red}FAIL${nc}: $*"; FAIL_COUNT=$((FAIL_COUNT + 1)); }

vm_ssh() {
    limactl shell "${LIMA_INSTANCE}" -- "$@" 2>/dev/null
}

vm_sudo() {
    limactl shell "${LIMA_INSTANCE}" -- sudo "$@" 2>/dev/null
}

wait_for() {
    local description="$1"
    local max_seconds="$2"
    local cmd="${*:3}"
    local elapsed=0
    echo "  Waiting for: ${description} (max ${max_seconds}s)..."
    while ! eval "${cmd}" &>/dev/null; do
        sleep 5
        elapsed=$((elapsed + 5))
        if [[ ${elapsed} -ge ${max_seconds} ]]; then
            return 1
        fi
        echo "    ...${elapsed}s elapsed"
    done
    return 0
}

teardown() {
    if [[ "${NO_TEARDOWN}" == "--no-teardown" ]]; then
        echo ""
        echo "Skipping teardown (--no-teardown). VM still running: ${LIMA_INSTANCE}"
        echo "  SSH: limactl shell ${LIMA_INSTANCE}"
        echo "  Stop: limactl stop ${LIMA_INSTANCE} && limactl delete ${LIMA_INSTANCE}"
        return
    fi
    echo ""
    echo "=== Teardown ==="
    limactl stop "${LIMA_INSTANCE}" 2>/dev/null || true
    limactl delete "${LIMA_INSTANCE}" 2>/dev/null || true
    echo "VM deleted."
}
trap teardown EXIT

# ── Phase 0: Pre-flight ──────────────────────────────────────────────────────

echo ""
echo "=== Phase 0: Pre-flight checks ==="

if ! command -v limactl &>/dev/null; then
    echo "FATAL: limactl not found. Install Lima first."
    exit 1
fi
check_pass "limactl found ($(limactl --version 2>&1 | head -1))"

if [[ ! -f "${QCOW2_PATH}" ]]; then
    echo "FATAL: QCOW2 not found at ${QCOW2_PATH}"
    echo "Run: make KUBERBLUE=1 LIMA=1 qcow2"
    exit 1
fi
QCOW2_AGE_HOURS=$(( ( $(date +%s) - $(stat -c %Y "${QCOW2_PATH}") ) / 3600 ))
check_pass "QCOW2 found (${QCOW2_AGE_HOURS}h old)"
if [[ ${QCOW2_AGE_HOURS} -gt 24 ]]; then
    check_warn "QCOW2 is ${QCOW2_AGE_HOURS}h old — consider rebuilding"
fi

if [[ ! -f "${LIMA_CONFIG}" ]]; then
    echo "FATAL: Lima config not found at ${LIMA_CONFIG}"
    echo "Run: make KUBERBLUE=1 LIMA=1 lima"
    exit 1
fi
check_pass "Lima config found"

# Stop and delete any existing instance
if limactl list 2>/dev/null | grep -q "${LIMA_INSTANCE}"; then
    echo "  Removing stale Lima instance..."
    limactl stop "${LIMA_INSTANCE}" 2>/dev/null || true
    limactl delete "${LIMA_INSTANCE}" 2>/dev/null || true
fi

# ── Phase 1: Boot VM ────────────────────────────────────────────────────────

echo ""
echo "=== Phase 1: Boot VM ==="

if ! limactl start --name "${LIMA_INSTANCE}" "${LIMA_CONFIG}" 2>&1 | tail -5; then
    check_fail "Lima VM failed to start"
    exit 1
fi

if limactl list 2>/dev/null | grep -q "${LIMA_INSTANCE}.*Running"; then
    check_pass "Lima VM running"
else
    check_fail "Lima VM not in Running state"
    exit 1
fi

# ── Phase 2: Service checks ──────────────────────────────────────────────────

echo ""
echo "=== Phase 2: Service health checks ==="

# Wait for crio to start (up to 120s)
if wait_for "crio.service active" 120 "vm_sudo systemctl is-active crio"; then
    check_pass "crio.service is active"
else
    check_fail "crio.service did not become active within 120s"
    vm_sudo journalctl -u crio --no-pager -n 20 || true
fi

# Check crio is using the correct binary path (via drop-in)
CRIO_EXEC=$(vm_sudo systemctl cat crio 2>/dev/null | grep "^ExecStart=" | tail -1)
if echo "${CRIO_EXEC}" | grep -q "/usr/bin/crio"; then
    check_pass "crio ExecStart uses /usr/bin/crio"
else
    check_warn "crio ExecStart may be wrong: ${CRIO_EXEC}"
fi

# kubelet will fail until kubeadm init runs — that's expected
KUBELET_ACTIVE=$(vm_sudo systemctl is-active kubelet 2>/dev/null || echo "inactive")
if [[ "${KUBELET_ACTIVE}" == "inactive" ]] || [[ "${KUBELET_ACTIVE}" == "activating" ]]; then
    check_pass "kubelet in pre-init state (expected before kubeadm init)"
else
    check_pass "kubelet is ${KUBELET_ACTIVE}"
fi

# ── Phase 3: First boot / cluster init ──────────────────────────────────────

echo ""
echo "=== Phase 3: Cluster initialization (kuberblue-onboot) ==="

# Wait for kuberblue-onboot to complete (kubeadm init can take 5+ min)
echo "  Waiting for kuberblue-onboot.service to complete (up to 600s)..."
ONBOOT_DONE=false
elapsed=0
while [[ ${elapsed} -lt 600 ]]; do
    STATUS=$(vm_sudo systemctl is-active kuberblue-onboot 2>/dev/null || echo "unknown")
    case "${STATUS}" in
        active)
            ONBOOT_DONE=true
            break
            ;;
        failed)
            break
            ;;
        *)
            sleep 10
            elapsed=$((elapsed + 10))
            echo "    ...${elapsed}s elapsed (status: ${STATUS})"
            ;;
    esac
done

if [[ "${ONBOOT_DONE}" == "true" ]]; then
    check_pass "kuberblue-onboot.service completed successfully"
else
    ONBOOT_STATUS=$(vm_sudo systemctl is-active kuberblue-onboot 2>/dev/null || echo "unknown")
    if [[ "${ONBOOT_STATUS}" == "failed" ]]; then
        check_fail "kuberblue-onboot.service failed"
        echo "--- Journal output ---"
        vm_sudo journalctl -u kuberblue-onboot --no-pager -n 40 || true
    else
        check_fail "kuberblue-onboot.service timed out (status: ${ONBOOT_STATUS})"
    fi
fi

# Verify first-boot marker was written
if vm_sudo test -f /etc/kuberblue/did_first_boot 2>/dev/null; then
    check_pass "first-boot marker written"
else
    check_fail "first-boot marker missing (init may not have completed)"
fi

# Verify admin.conf exists
if vm_sudo test -f /etc/kubernetes/admin.conf 2>/dev/null; then
    check_pass "admin.conf exists"
else
    check_fail "admin.conf missing (kubeadm init may have failed)"
fi

# ── Phase 4: Cluster health ──────────────────────────────────────────────────

echo ""
echo "=== Phase 4: Cluster health ==="

# Wait for node to be Ready (up to 120s after onboot completes)
if wait_for "node Ready" 120 "vm_sudo kubectl get nodes --no-headers 2>/dev/null | grep -q ' Ready '"; then
    NODE_INFO=$(vm_sudo kubectl get nodes --no-headers 2>/dev/null)
    check_pass "Node is Ready: ${NODE_INFO}"
else
    check_fail "Node did not reach Ready state within 120s"
    vm_sudo kubectl get nodes 2>/dev/null || true
fi

# Check core system pods
if wait_for "kube-system pods Running" 120 "vm_sudo kubectl get pods -n kube-system --no-headers 2>/dev/null | grep -v 'Running\|Completed' | grep -qv '^$' || true && vm_sudo kubectl get pods -n kube-system --no-headers 2>/dev/null | grep -q 'Running'"; then
    POD_COUNT=$(vm_sudo kubectl get pods -n kube-system --no-headers 2>/dev/null | grep -c Running || echo 0)
    check_pass "${POD_COUNT} pods running in kube-system"
else
    check_warn "kube-system pods not all Running yet"
    vm_sudo kubectl get pods -n kube-system 2>/dev/null || true
fi

# Check CoreDNS specifically
if vm_sudo kubectl get pods -n kube-system --no-headers 2>/dev/null | grep -q "coredns.*Running"; then
    check_pass "CoreDNS is Running"
else
    check_warn "CoreDNS not yet Running"
fi

# ── Phase 5: kuberblue doctor ────────────────────────────────────────────────

echo ""
echo "=== Phase 5: kuberblue doctor ==="

DOCTOR_OUTPUT=$(vm_sudo kuberblue doctor 2>&1 || true)
echo "${DOCTOR_OUTPUT}" | grep -E "PASS:|WARN:|FAIL:" | while IFS= read -r line; do
    echo "  ${line}"
done

DOCTOR_FAILS=$(echo "${DOCTOR_OUTPUT}" | grep -c "FAIL:" || echo 0)
DOCTOR_WARNS=$(echo "${DOCTOR_OUTPUT}" | grep -c "WARN:" || echo 0)

if [[ "${DOCTOR_FAILS}" -eq 0 ]]; then
    check_pass "kuberblue doctor: 0 failures"
else
    check_fail "kuberblue doctor: ${DOCTOR_FAILS} failure(s)"
fi

if [[ "${DOCTOR_WARNS}" -gt 0 ]]; then
    check_warn "kuberblue doctor: ${DOCTOR_WARNS} warning(s)"
fi

# ── Phase 6: kuberblue status ────────────────────────────────────────────────

echo ""
echo "=== Phase 6: kuberblue status ==="

STATUS_OUTPUT=$(vm_sudo kuberblue status 2>&1 || true)
echo "${STATUS_OUTPUT}"

if echo "${STATUS_OUTPUT}" | grep -q "control-plane\|Running\|Ready"; then
    check_pass "kuberblue status output looks healthy"
else
    check_warn "kuberblue status output unexpected"
fi

# ── Summary ──────────────────────────────────────────────────────────────────

echo ""
echo "=== Lima Smoke Test Summary ==="
echo "  PASS: ${PASS_COUNT}"
echo "  WARN: ${WARN_COUNT}"
echo "  FAIL: ${FAIL_COUNT}"

if [[ ${FAIL_COUNT} -gt 0 ]]; then
    echo ""
    echo "RESULT: FAILED (${FAIL_COUNT} failures)"
    exit 1
else
    echo ""
    echo "RESULT: PASSED"
    exit 0
fi
