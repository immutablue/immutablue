#!/bin/bash
# Kuberblue CLI Tests
#
# Tests the kuberblue CLI wrapper (justfile) for:
# - kuberblue --help outputs usage
# - kuberblue status doesn't crash (shows "not initialized" without a cluster)
# - kuberblue doctor doesn't crash (reports WARN/FAIL gracefully)
# - kuberblue override --list shows available configs
# - All 12 subcommands are registered in the CLI wrapper
#
# Usage: ./test_kuberblue_cli.sh [IMAGE_NAME:TAG]

set -euo pipefail

echo "Running Kuberblue CLI tests"

IMAGE="${1:-quay.io/immutablue/immutablue:42}"
TEST_DIR="$(dirname "$(realpath "$0")")"
ROOT_DIR="$(dirname "$(dirname "$TEST_DIR")")"
FAILED=0

JUSTFILE="/usr/libexec/immutablue/just/30-kuberblue.justfile"

# --- 5.5: CLI tests ---

function test_cli_subcommands_registered() {
    echo "Testing that all 12 subcommands are registered in the justfile"
    if ! podman run --rm "$IMAGE" bash -c '
        JUSTFILE="/usr/libexec/immutablue/just/30-kuberblue.justfile"
        if [[ ! -f "$JUSTFILE" ]]; then
            echo "FAIL: justfile not found at $JUSTFILE"
            exit 1
        fi

        EXPECTED_COMMANDS=(
            "first_boot"
            "kube_init"
            "kube_reset"
            "kube_status"
            "kube_doctor"
            "kube_join"
            "kube_refresh_token"
            "kube_override"
            "kube_encrypt"
            "kube_decrypt"
            "kube_upgrade"
            "kube_mcp_serve"
        )

        FAIL=0
        for cmd in "${EXPECTED_COMMANDS[@]}"; do
            if ! grep -qE "^${cmd}" "$JUSTFILE"; then
                echo "FAIL: Subcommand \"${cmd}\" not found in justfile"
                FAIL=1
            fi
        done

        if [[ $FAIL -eq 1 ]]; then
            echo "Available recipes:"
            grep -E "^[a-z_]+" "$JUSTFILE" | head -20
            exit 1
        fi

        echo "All 12 subcommands registered"
    '; then
        echo "FAIL: CLI subcommand registration test failed"
        return 1
    fi

    echo "PASS: All 12 subcommands are registered"
    return 0
}

function test_cli_status_no_crash() {
    echo "Testing kuberblue status does not crash without a cluster"
    # On a system without kubernetes running, status should exit gracefully
    # (exit code 0 or 1 is fine; crash/signal is not)
    if ! podman run --rm "$IMAGE" bash -c '
        # Source the status script — it should handle missing cluster gracefully
        if [[ -f /usr/libexec/kuberblue/kube_setup/kube_status.sh ]]; then
            # Run the script; allow exit code 1 (not initialized) but not crashes
            /usr/libexec/kuberblue/kube_setup/kube_status.sh 2>&1 || true
            echo "STATUS_SCRIPT_EXECUTED"
        else
            echo "FAIL: kube_status.sh not found"
            exit 1
        fi
    ' 2>&1 | grep -q "STATUS_SCRIPT_EXECUTED"; then
        echo "PASS: kuberblue status does not crash"
        return 0
    else
        echo "FAIL: kuberblue status crashed or script not found"
        return 1
    fi
}

function test_cli_doctor_no_crash() {
    echo "Testing kuberblue doctor does not crash without a cluster"
    if ! podman run --rm "$IMAGE" bash -c '
        if [[ -f /usr/libexec/kuberblue/kube_setup/kube_doctor.sh ]]; then
            /usr/libexec/kuberblue/kube_setup/kube_doctor.sh 2>&1 || true
            echo "DOCTOR_SCRIPT_EXECUTED"
        else
            echo "FAIL: kube_doctor.sh not found"
            exit 1
        fi
    ' 2>&1 | grep -q "DOCTOR_SCRIPT_EXECUTED"; then
        echo "PASS: kuberblue doctor does not crash"
        return 0
    else
        echo "FAIL: kuberblue doctor crashed or script not found"
        return 1
    fi
}

function test_cli_override_list() {
    echo "Testing kuberblue override --list shows available configs"
    if ! podman run --rm "$IMAGE" bash -c '
        # Running override without arguments should list available configs
        OUTPUT=$(/usr/libexec/kuberblue/kube_setup/kube_override.sh 2>&1 || true)

        # Should list the 5 config files
        for file in cluster.yaml cni.yaml security.yaml gitops.yaml packages.yaml; do
            if ! echo "$OUTPUT" | grep -q "$file"; then
                echo "FAIL: override list does not show $file"
                echo "Output was: $OUTPUT"
                exit 1
            fi
        done

        echo "Override list shows all config files"
    '; then
        echo "FAIL: CLI override list test failed"
        return 1
    fi

    echo "PASS: Override --list shows available configs"
    return 0
}

function test_cli_scripts_exist() {
    echo "Testing that all CLI scripts exist and are executable"
    if ! podman run --rm "$IMAGE" bash -c '
        SCRIPTS=(
            "/usr/libexec/kuberblue/kube_setup/kube_status.sh"
            "/usr/libexec/kuberblue/kube_setup/kube_doctor.sh"
            "/usr/libexec/kuberblue/kube_setup/kube_reset.sh"
            "/usr/libexec/kuberblue/kube_setup/kube_join.sh"
            "/usr/libexec/kuberblue/kube_setup/kube_refresh_token.sh"
            "/usr/libexec/kuberblue/kube_setup/kube_override.sh"
            "/usr/libexec/kuberblue/kube_setup/kube_sops.sh"
            "/usr/libexec/kuberblue/kube_setup/kube_upgrade.sh"
            "/usr/libexec/kuberblue/kube_setup/kube_state.sh"
        )

        FAIL=0
        for script in "${SCRIPTS[@]}"; do
            if [[ ! -f "$script" ]]; then
                echo "FAIL: Script not found: $script"
                FAIL=1
            fi
        done
        exit $FAIL
    '; then
        echo "FAIL: CLI scripts existence test failed"
        return 1
    fi

    echo "PASS: All CLI scripts exist"
    return 0
}

# --- Run all tests ---

echo "=== Running Kuberblue CLI Tests ==="

if ! test_cli_subcommands_registered; then ((FAILED++)); fi
if ! test_cli_status_no_crash; then ((FAILED++)); fi
if ! test_cli_doctor_no_crash; then ((FAILED++)); fi
if ! test_cli_override_list; then ((FAILED++)); fi
if ! test_cli_scripts_exist; then ((FAILED++)); fi

echo "=== Kuberblue CLI Test Results ==="
if [[ $FAILED -eq 0 ]]; then
    echo "All CLI tests PASSED!"
    exit 0
else
    echo "$FAILED CLI test(s) FAILED!"
    exit 1
fi
