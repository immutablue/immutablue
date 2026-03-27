#!/bin/bash
# Kuberblue Config Validation Tests
#
# Tests for the kuberblue configuration system:
# - All YAML config files are valid (parseable by yq)
# - kuberblue_config_get returns expected defaults for key fields
# - Override precedence: /etc/kuberblue/ wins over /usr/kuberblue/
# - All expected config files exist
# - State system (kuberblue_state_set / _get / _check)
#
# Usage: ./test_kuberblue_config.sh [IMAGE_NAME:TAG]

set -euo pipefail

echo "Running Kuberblue config validation tests"

IMAGE="${1:-quay.io/immutablue/immutablue:42}"
TEST_DIR="$(dirname "$(realpath "$0")")"
ROOT_DIR="$(dirname "$(dirname "$TEST_DIR")")"
FAILED=0

# --- 5.1: Config file validation ---

function test_config_files_exist() {
    echo "Testing that all config files exist in /usr/kuberblue/"
    local expected_files=(
        "cluster.yaml"
        "cni.yaml"
        "security.yaml"
        "gitops.yaml"
        "packages.yaml"
        "provision.yaml"
        "settings.yaml"
    )

    for file in "${expected_files[@]}"; do
        if ! podman run --rm "$IMAGE" test -f "/usr/kuberblue/${file}"; then
            echo "FAIL: Config file /usr/kuberblue/${file} not found"
            return 1
        fi
    done

    echo "PASS: All config files exist"
    return 0
}

function test_config_files_valid_yaml() {
    echo "Testing that all YAML config files are valid"
    if ! podman run --rm "$IMAGE" bash -c '
        FAIL=0
        for f in /usr/kuberblue/*.yaml; do
            if ! yq "." "$f" > /dev/null 2>&1; then
                echo "FAIL: $f is not valid YAML"
                FAIL=1
            fi
        done
        exit $FAIL
    '; then
        echo "FAIL: One or more config files are not valid YAML"
        return 1
    fi

    echo "PASS: All config files are valid YAML"
    return 0
}

function test_config_get_defaults() {
    echo "Testing kuberblue_config_get returns expected defaults"
    if ! podman run --rm "$IMAGE" bash -c '
        source /usr/libexec/kuberblue/variables.sh

        FAIL=0
        # Test cluster.yaml defaults
        val="$(kuberblue_config_get cluster.yaml .cluster.topology "MISSING")"
        if [[ "$val" != "single" ]]; then
            echo "FAIL: cluster.topology expected=single got=$val"
            FAIL=1
        fi

        val="$(kuberblue_config_get cluster.yaml .cluster.node_role "MISSING")"
        if [[ "$val" != "control-plane" ]]; then
            echo "FAIL: cluster.node_role expected=control-plane got=$val"
            FAIL=1
        fi

        val="$(kuberblue_config_get cluster.yaml .cluster.container_runtime "MISSING")"
        if [[ "$val" != "crio" ]]; then
            echo "FAIL: cluster.container_runtime expected=crio got=$val"
            FAIL=1
        fi

        # cluster.auto_init removed (dead key — auto-init is always enabled)

        # Test cni.yaml defaults
        val="$(kuberblue_config_get cni.yaml .networking.cni "MISSING")"
        if [[ "$val" != "cilium" ]]; then
            echo "FAIL: networking.cni expected=cilium got=$val"
            FAIL=1
        fi

        val="$(kuberblue_config_get cni.yaml .networking.tailscale.enabled "MISSING")"
        if [[ "$val" != "false" ]]; then
            echo "FAIL: networking.tailscale.enabled expected=false got=$val"
            FAIL=1
        fi

        # Test security.yaml defaults
        val="$(kuberblue_config_get security.yaml .security.sops.enabled "MISSING")"
        if [[ "$val" != "false" ]]; then
            echo "FAIL: security.sops.enabled expected=false got=$val"
            FAIL=1
        fi

        val="$(kuberblue_config_get security.yaml .security.admin.user "MISSING")"
        if [[ "$val" != "kuberblue" ]]; then
            echo "FAIL: security.admin.user expected=kuberblue got=$val"
            FAIL=1
        fi

        # Test gitops.yaml defaults
        val="$(kuberblue_config_get gitops.yaml .gitops.enabled "MISSING")"
        if [[ "$val" != "false" ]]; then
            echo "FAIL: gitops.enabled expected=false got=$val"
            FAIL=1
        fi

        # Test default value for missing key
        val="$(kuberblue_config_get cluster.yaml .nonexistent.key "fallback")"
        if [[ "$val" != "fallback" ]]; then
            echo "FAIL: missing key default expected=fallback got=$val"
            FAIL=1
        fi

        exit $FAIL
    '; then
        echo "FAIL: Config default values test failed"
        return 1
    fi

    echo "PASS: kuberblue_config_get returns expected defaults"
    return 0
}

function test_config_override_precedence() {
    echo "Testing override precedence: /etc/kuberblue/ wins over /usr/kuberblue/"
    if ! podman run --rm "$IMAGE" bash -c '
        source /usr/libexec/kuberblue/variables.sh

        # Create an /etc/kuberblue/ override with a different topology
        mkdir -p /etc/kuberblue
        cat > /etc/kuberblue/cluster.yaml <<OVERRIDE
cluster:
  topology: ha
  node_role: worker
OVERRIDE

        # Re-read config — /etc/ should win
        val="$(kuberblue_config_get cluster.yaml .cluster.topology "MISSING")"
        if [[ "$val" != "ha" ]]; then
            echo "FAIL: override precedence expected=ha got=$val"
            exit 1
        fi

        val="$(kuberblue_config_get cluster.yaml .cluster.node_role "MISSING")"
        if [[ "$val" != "worker" ]]; then
            echo "FAIL: override precedence expected=worker got=$val"
            exit 1
        fi

        # Vendor default should not be visible
        # (file-level replacement: /etc/ file wins entirely)
        echo "Override precedence verified"
    '; then
        echo "FAIL: Override precedence test failed"
        return 1
    fi

    echo "PASS: Override precedence works correctly"
    return 0
}

# --- 5.6: State system tests ---

function test_state_set_and_get() {
    echo "Testing kuberblue_state_set and kuberblue_state_get"
    if ! podman run --rm "$IMAGE" bash -c '
        export STATE_DIR="$(mktemp -d)"
        source /usr/libexec/kuberblue/kube_setup/kube_state.sh

        # Test set + get
        kuberblue_state_set "node-role" "control-plane"
        val="$(kuberblue_state_get "node-role")"
        if [[ "$val" != "control-plane" ]]; then
            echo "FAIL: state_get expected=control-plane got=$val"
            exit 1
        fi

        # Test overwrite
        kuberblue_state_set "node-role" "worker"
        val="$(kuberblue_state_get "node-role")"
        if [[ "$val" != "worker" ]]; then
            echo "FAIL: state overwrite expected=worker got=$val"
            exit 1
        fi

        # Test default for missing key
        val="$(kuberblue_state_get "nonexistent" "my-default")"
        if [[ "$val" != "my-default" ]]; then
            echo "FAIL: missing key default expected=my-default got=$val"
            exit 1
        fi

        # Clean up
        rm -rf "$STATE_DIR"
    '; then
        echo "FAIL: State set/get test failed"
        return 1
    fi

    echo "PASS: State set/get works correctly"
    return 0
}

function test_state_check() {
    echo "Testing kuberblue_state_check"
    if ! podman run --rm "$IMAGE" bash -c '
        export STATE_DIR="$(mktemp -d)"
        source /usr/libexec/kuberblue/kube_setup/kube_state.sh

        # Check should fail for missing key
        if kuberblue_state_check "cluster-initialized"; then
            echo "FAIL: state_check should return 1 for missing key"
            exit 1
        fi

        # Set and check should succeed
        kuberblue_state_set "cluster-initialized" "true"
        if ! kuberblue_state_check "cluster-initialized"; then
            echo "FAIL: state_check should return 0 for existing key"
            exit 1
        fi

        # Clean up
        rm -rf "$STATE_DIR"
    '; then
        echo "FAIL: State check test failed"
        return 1
    fi

    echo "PASS: State check works correctly"
    return 0
}

function test_state_set_requires_key() {
    echo "Testing kuberblue_state_set requires a key argument"
    if ! podman run --rm "$IMAGE" bash -c '
        export STATE_DIR="$(mktemp -d)"
        source /usr/libexec/kuberblue/kube_setup/kube_state.sh

        # Calling state_set without a key should fail
        if kuberblue_state_set "" 2>/dev/null; then
            echo "FAIL: state_set should fail with empty key"
            exit 1
        fi

        # Clean up
        rm -rf "$STATE_DIR"
    '; then
        echo "FAIL: State set key validation test failed"
        return 1
    fi

    echo "PASS: State set key validation works"
    return 0
}

function test_state_file_written_correctly() {
    echo "Testing kuberblue_state_set writes file to correct location"
    if ! podman run --rm "$IMAGE" bash -c '
        export STATE_DIR="$(mktemp -d)"
        source /usr/libexec/kuberblue/kube_setup/kube_state.sh

        kuberblue_state_set "flux-bootstrapped" "done"

        # Verify file exists at expected path
        if [[ ! -f "${STATE_DIR}/state/flux-bootstrapped" ]]; then
            echo "FAIL: state file not written at expected path"
            exit 1
        fi

        # Verify file contents
        content="$(cat "${STATE_DIR}/state/flux-bootstrapped")"
        if [[ "$content" != "done" ]]; then
            echo "FAIL: state file contents expected=done got=$content"
            exit 1
        fi

        # Clean up
        rm -rf "$STATE_DIR"
    '; then
        echo "FAIL: State file write test failed"
        return 1
    fi

    echo "PASS: State file written correctly"
    return 0
}

# --- Run all tests ---

echo "=== Running Kuberblue Config Validation Tests ==="

if ! test_config_files_exist; then ((FAILED++)); fi
if ! test_config_files_valid_yaml; then ((FAILED++)); fi
if ! test_config_get_defaults; then ((FAILED++)); fi
if ! test_config_override_precedence; then ((FAILED++)); fi
if ! test_state_set_and_get; then ((FAILED++)); fi
if ! test_state_check; then ((FAILED++)); fi
if ! test_state_set_requires_key; then ((FAILED++)); fi
if ! test_state_file_written_correctly; then ((FAILED++)); fi

echo "=== Kuberblue Config Validation Test Results ==="
if [[ $FAILED -eq 0 ]]; then
    echo "All config validation tests PASSED!"
    exit 0
else
    echo "$FAILED config validation test(s) FAILED!"
    exit 1
fi
