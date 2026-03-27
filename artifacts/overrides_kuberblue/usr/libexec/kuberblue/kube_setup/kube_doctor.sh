#!/bin/bash
# kube_doctor.sh — health checks for kuberblue cluster
#
# Runs a series of checks and reports PASS/WARN/FAIL for each.
set -euo pipefail

source /usr/libexec/kuberblue/99-common.sh
source /usr/libexec/kuberblue/variables.sh
source /usr/libexec/kuberblue/kube_setup/kube_state.sh

pass_count=0
warn_count=0
fail_count=0

check_pass () {
    echo "  PASS: $1"
    pass_count=$((pass_count + 1))
}

check_warn () {
    echo "  WARN: $1"
    warn_count=$((warn_count + 1))
}

check_fail () {
    echo "  FAIL: $1"
    fail_count=$((fail_count + 1))
}

echo "=== Kuberblue Doctor ==="
echo ""

# 1. kubelet running
if systemctl is-active --quiet kubelet 2>/dev/null; then
    check_pass "kubelet is running"
else
    check_fail "kubelet is not running (systemctl start kubelet)"
fi

# 2. CRI-O running
if systemctl is-active --quiet crio 2>/dev/null; then
    check_pass "CRI-O is running"
else
    check_fail "CRI-O is not running (systemctl start crio)"
fi

# 3. Cilium health
if command -v cilium &>/dev/null; then
    if cilium status --brief &>/dev/null; then
        check_pass "Cilium is healthy"
    else
        check_warn "Cilium status check failed (cilium status --brief)"
    fi
else
    check_warn "Cilium CLI not found — cannot check CNI health"
fi

# 4. CoreDNS running
if command -v kubectl &>/dev/null; then
    coredns_pods="$(kubectl get pods -n kube-system -l k8s-app=kube-dns --no-headers 2>/dev/null || true)"
    if [[ -n "${coredns_pods}" ]]; then
        not_running="$(echo "${coredns_pods}" | grep -v "Running" || true)"
        if [[ -z "${not_running}" ]]; then
            check_pass "CoreDNS pods are running"
        else
            check_warn "Some CoreDNS pods are not Running"
        fi
    else
        check_fail "No CoreDNS pods found in kube-system"
    fi
else
    check_warn "kubectl not available — cannot check CoreDNS"
fi

# 5. StorageClass exists
if command -v kubectl &>/dev/null; then
    sc_count="$(kubectl get sc --no-headers 2>/dev/null | wc -l 2>/dev/null)" || sc_count=0
    sc_count="${sc_count//[[:space:]]/}"
    if [[ "${sc_count:-0}" -gt 0 ]]; then
        check_pass "StorageClass exists (${sc_count} found)"
    else
        check_warn "No StorageClass found — persistent storage unavailable"
    fi
else
    check_warn "kubectl not available — cannot check StorageClass"
fi

# 6. Flux controllers healthy
if kuberblue_state_check "flux-bootstrapped"; then
    if command -v flux &>/dev/null; then
        if flux check 2>/dev/null; then
            check_pass "Flux controllers are healthy"
        else
            check_warn "Flux health check returned warnings"
        fi
    else
        check_warn "Flux CLI not found — cannot check Flux health"
    fi
fi

# 7. Tailscale connected
if kuberblue_state_check "tailscale-configured"; then
    if command -v tailscale &>/dev/null; then
        ts_status="$(tailscale status --self --json 2>/dev/null | yq -r '.Self.Online // "false"' 2>/dev/null || echo "false")"
        if [[ "${ts_status}" == "true" ]]; then
            check_pass "Tailscale is connected"
        else
            check_warn "Tailscale is configured but not connected"
        fi
    else
        check_warn "Tailscale CLI not found"
    fi
fi

# 8. Disk space on /var/lib
if command -v df &>/dev/null; then
    usage="$(df /var/lib --output=pcent 2>/dev/null | tail -1 | tr -d ' %' || echo "0")"
    if [[ "${usage}" -gt 90 ]]; then
        check_fail "Disk usage on /var/lib is ${usage}% (critical, >90%)"
    elif [[ "${usage}" -gt 80 ]]; then
        check_warn "Disk usage on /var/lib is ${usage}% (>80%)"
    else
        check_pass "Disk usage on /var/lib is ${usage}%"
    fi
fi

# 9. Required binaries present
required_bins=(kubeadm kubectl helm yq flux age-keygen)
missing_bins=()
for bin in "${required_bins[@]}"; do
    if ! command -v "${bin}" &>/dev/null; then
        missing_bins+=("${bin}")
    fi
done
if [[ ${#missing_bins[@]} -eq 0 ]]; then
    check_pass "All required binaries present"
else
    check_warn "Missing binaries: ${missing_bins[*]}"
fi

# 10. Stale config overrides
stale_overrides=()
for override_file in /etc/kuberblue/*.yaml; do
    [[ -f "${override_file}" ]] || continue
    base="$(basename "${override_file}")"
    vendor_file="/usr/kuberblue/${base}"
    if [[ -f "${vendor_file}" ]]; then
        if [[ "${override_file}" -ot "${vendor_file}" ]]; then
            stale_overrides+=("${base}")
        fi
    fi
done
if [[ ${#stale_overrides[@]} -gt 0 ]]; then
    check_warn "Stale config overrides (older than vendor defaults): ${stale_overrides[*]}"
else
    check_pass "No stale config overrides"
fi

echo ""
echo "--- Summary ---"
echo "  PASS: ${pass_count}  WARN: ${warn_count}  FAIL: ${fail_count}"

if [[ ${fail_count} -gt 0 ]]; then
    exit 1
fi
