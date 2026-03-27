#!/bin/bash
# Kuberblue SOPS Encrypt/Decrypt Round-Trip Test
#
# Tests SOPS+Age encryption and decryption:
# - Generate a temporary Age key via age-keygen
# - Create a test YAML file with sensitive data
# - Encrypt with sops --encrypt --age <pubkey>
# - Decrypt with sops --decrypt
# - Verify decrypted output matches original
# - Clean up temp files
#
# Requires: sops, age-keygen binaries (skips with warning if not available)
#
# Usage: ./test_kuberblue_sops.sh

set -euo pipefail

echo "Running Kuberblue SOPS round-trip test"

FAILED=0
TMPDIR_SOPS=""

function cleanup() {
    if [[ -n "${TMPDIR_SOPS}" ]] && [[ -d "${TMPDIR_SOPS}" ]]; then
        rm -rf "${TMPDIR_SOPS}"
    fi
}
trap cleanup EXIT

function test_sops_roundtrip() {
    echo "Testing SOPS encrypt/decrypt round-trip with Age"

    # Check for required binaries
    if ! command -v sops &>/dev/null; then
        echo "SKIP: sops binary not found — install sops to run this test"
        return 0
    fi
    if ! command -v age-keygen &>/dev/null; then
        echo "SKIP: age-keygen binary not found — install age to run this test"
        return 0
    fi

    TMPDIR_SOPS="$(mktemp -d)"

    # Generate a temporary Age key pair
    age-keygen -o "${TMPDIR_SOPS}/age.key" 2>"${TMPDIR_SOPS}/age.pub.raw"
    AGE_PUBKEY="$(grep '^age1' "${TMPDIR_SOPS}/age.pub.raw")"
    if [[ -z "${AGE_PUBKEY}" ]]; then
        # age-keygen may also print the public key in the key file as a comment
        AGE_PUBKEY="$(grep '^# public key:' "${TMPDIR_SOPS}/age.key" | awk '{print $NF}')"
    fi

    if [[ -z "${AGE_PUBKEY}" ]]; then
        echo "FAIL: Could not extract Age public key"
        return 1
    fi

    echo "Generated Age key pair (pubkey: ${AGE_PUBKEY:0:20}...)"

    # Create a test YAML file with sensitive data
    cat > "${TMPDIR_SOPS}/secret.yaml" <<'TESTYAML'
apiVersion: v1
kind: Secret
metadata:
  name: test-secret
  namespace: default
stringData:
  password: "super-secret-password-12345"
  api-key: "sk-test-abcdef0123456789"
  database-url: "postgres://admin:secret@db.example.com:5432/mydb"
TESTYAML

    # Save original for comparison
    cp "${TMPDIR_SOPS}/secret.yaml" "${TMPDIR_SOPS}/secret-original.yaml"

    # Encrypt with sops + Age
    export SOPS_AGE_KEY_FILE="${TMPDIR_SOPS}/age.key"
    if ! sops --encrypt --age "${AGE_PUBKEY}" \
        --encrypted-regex '^(stringData|data)$' \
        "${TMPDIR_SOPS}/secret.yaml" > "${TMPDIR_SOPS}/secret-encrypted.yaml" 2>/dev/null; then
        echo "FAIL: sops --encrypt failed"
        return 1
    fi

    # Verify encrypted file is different from original
    if diff -q "${TMPDIR_SOPS}/secret-original.yaml" "${TMPDIR_SOPS}/secret-encrypted.yaml" &>/dev/null; then
        echo "FAIL: Encrypted file is identical to original (encryption may not have worked)"
        return 1
    fi

    # Verify encrypted file contains sops metadata
    if ! grep -q "sops:" "${TMPDIR_SOPS}/secret-encrypted.yaml"; then
        echo "FAIL: Encrypted file does not contain sops metadata"
        return 1
    fi

    echo "Encryption succeeded — file contains sops metadata"

    # Decrypt with sops
    if ! sops --decrypt "${TMPDIR_SOPS}/secret-encrypted.yaml" > "${TMPDIR_SOPS}/secret-decrypted.yaml" 2>/dev/null; then
        echo "FAIL: sops --decrypt failed"
        return 1
    fi

    # Verify decrypted output matches original
    if ! diff -q "${TMPDIR_SOPS}/secret-original.yaml" "${TMPDIR_SOPS}/secret-decrypted.yaml" &>/dev/null; then
        echo "FAIL: Decrypted file does not match original"
        echo "--- original ---"
        cat "${TMPDIR_SOPS}/secret-original.yaml"
        echo "--- decrypted ---"
        cat "${TMPDIR_SOPS}/secret-decrypted.yaml"
        return 1
    fi

    echo "PASS: SOPS encrypt/decrypt round-trip succeeded"
    return 0
}

function test_sops_wrong_key_fails() {
    echo "Testing SOPS decrypt with wrong key fails"

    # Check for required binaries
    if ! command -v sops &>/dev/null || ! command -v age-keygen &>/dev/null; then
        echo "SKIP: sops or age-keygen not available"
        return 0
    fi

    TMPDIR_SOPS="$(mktemp -d)"

    # Generate two different Age key pairs
    age-keygen -o "${TMPDIR_SOPS}/key1.key" 2>"${TMPDIR_SOPS}/key1.pub.raw"
    PUBKEY1="$(grep '^# public key:' "${TMPDIR_SOPS}/key1.key" | awk '{print $NF}')"

    age-keygen -o "${TMPDIR_SOPS}/key2.key" 2>/dev/null

    # Create and encrypt a test file with key1
    echo "secret: mysecretvalue" > "${TMPDIR_SOPS}/test.yaml"
    export SOPS_AGE_KEY_FILE="${TMPDIR_SOPS}/key1.key"
    sops --encrypt --age "${PUBKEY1}" "${TMPDIR_SOPS}/test.yaml" > "${TMPDIR_SOPS}/test-enc.yaml" 2>/dev/null

    # Try to decrypt with key2 — should fail
    export SOPS_AGE_KEY_FILE="${TMPDIR_SOPS}/key2.key"
    if sops --decrypt "${TMPDIR_SOPS}/test-enc.yaml" &>/dev/null; then
        echo "FAIL: Decryption with wrong key should have failed"
        return 1
    fi

    echo "PASS: Decrypt with wrong key correctly fails"
    return 0
}

# --- Run all tests ---

echo "=== Running Kuberblue SOPS Tests ==="

if ! test_sops_roundtrip; then ((FAILED++)); fi
if ! test_sops_wrong_key_fails; then ((FAILED++)); fi

echo "=== Kuberblue SOPS Test Results ==="
if [[ $FAILED -eq 0 ]]; then
    echo "All SOPS tests PASSED!"
    exit 0
else
    echo "$FAILED SOPS test(s) FAILED!"
    exit 1
fi
