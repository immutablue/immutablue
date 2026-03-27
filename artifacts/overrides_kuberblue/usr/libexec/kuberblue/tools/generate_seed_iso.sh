#!/bin/bash
set -euo pipefail
# generate_seed_iso.sh — Generate a cloud-init NoCloud seed ISO
#
# Creates a minimal ISO containing cloud-init user-data and meta-data
# for injecting kuberblue bootstrap parameters at VM/bare-metal boot.
#
# Usage:
#   generate_seed_iso.sh --config-url URL [options] -o output.iso
#
# Options:
#   --config-url URL       Git repo URL for kuberblue-configs (required)
#   --config-ref REF       Git branch/tag (default: main)
#   --config-path PATH     Subdirectory in repo (default: .)
#   --config-token TOKEN   Deploy token for private repos
#   --age-key KEY          SOPS Age private key
#   --age-key-file FILE    Read Age key from file
#   --hostname NAME        VM hostname (default: kuberblue)
#   --instance-id ID       Cloud-init instance ID (default: kuberblue-default)
#   -o, --output FILE      Output ISO path (default: seed.iso)

CONFIG_URL=""
CONFIG_REF="main"
CONFIG_PATH="."
CONFIG_TOKEN=""
AGE_KEY=""
HOSTNAME_VAL="kuberblue"
INSTANCE_ID=""
OUTPUT="seed.iso"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --config-url)     CONFIG_URL="$2"; shift 2 ;;
        --config-ref)     CONFIG_REF="$2"; shift 2 ;;
        --config-path)    CONFIG_PATH="$2"; shift 2 ;;
        --config-token)   CONFIG_TOKEN="$2"; shift 2 ;;
        --age-key)        AGE_KEY="$2"; shift 2 ;;
        --age-key-file)   AGE_KEY="$(cat "$2")"; shift 2 ;;
        --hostname)       HOSTNAME_VAL="$2"; shift 2 ;;
        --instance-id)    INSTANCE_ID="$2"; shift 2 ;;
        -o|--output)      OUTPUT="$2"; shift 2 ;;
        -h|--help)
            sed -n '2,/^$/s/^# //p' "$0"
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

if [[ -z "$CONFIG_URL" ]]; then
    echo "ERROR: --config-url is required" >&2
    echo "Usage: $0 --config-url URL [options] -o output.iso" >&2
    exit 1
fi

# Default instance ID
if [[ -z "$INSTANCE_ID" ]]; then
    INSTANCE_ID="kuberblue-$(echo "$CONFIG_PATH" | tr '/' '-' | sed 's/^\.$/default/')"
fi

# Check for ISO generation tool
ISO_CMD=""
if command -v genisoimage &>/dev/null; then
    ISO_CMD="genisoimage"
elif command -v mkisofs &>/dev/null; then
    ISO_CMD="mkisofs"
elif command -v xorriso &>/dev/null; then
    ISO_CMD="xorriso"
else
    echo "ERROR: No ISO generation tool found. Install genisoimage, mkisofs, or xorriso." >&2
    exit 1
fi

# Create temp dir for ISO contents
TMPDIR="$(mktemp -d /tmp/kuberblue-seed-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

# Generate user-data
cat > "${TMPDIR}/user-data" <<USERDATA
#cloud-config
kuberblue:
  config: "${CONFIG_URL}"
  config_ref: "${CONFIG_REF}"
  config_path: "${CONFIG_PATH}"
USERDATA

# Add optional fields only if set (keeps the YAML clean)
if [[ -n "$CONFIG_TOKEN" ]]; then
    echo "  config_token: \"${CONFIG_TOKEN}\"" >> "${TMPDIR}/user-data"
fi
if [[ -n "$AGE_KEY" ]]; then
    echo "  age_key: \"${AGE_KEY}\"" >> "${TMPDIR}/user-data"
fi

# Generate meta-data
cat > "${TMPDIR}/meta-data" <<METADATA
instance-id: ${INSTANCE_ID}
local-hostname: ${HOSTNAME_VAL}
METADATA

# Generate ISO
case "$ISO_CMD" in
    genisoimage|mkisofs)
        "$ISO_CMD" -output "$OUTPUT" -volid cidata -joliet -rock \
            "${TMPDIR}/user-data" "${TMPDIR}/meta-data" 2>/dev/null
        ;;
    xorriso)
        xorriso -as mkisofs -output "$OUTPUT" -volid cidata -joliet -rock \
            "${TMPDIR}/user-data" "${TMPDIR}/meta-data" 2>/dev/null
        ;;
esac

echo "Seed ISO created: $OUTPUT"
echo "  Config URL:  $CONFIG_URL"
echo "  Config Ref:  $CONFIG_REF"
echo "  Config Path: $CONFIG_PATH"
echo "  Private:     $(if [[ -n "$CONFIG_TOKEN" ]]; then echo "yes"; else echo "no"; fi)"
echo "  SOPS:        $(if [[ -n "$AGE_KEY" ]]; then echo "yes (Age key included)"; else echo "no"; fi)"
echo "  Hostname:    $HOSTNAME_VAL"
echo ""
echo "Attach this ISO as a secondary drive when booting the kuberblue image."
echo "Cloud-init will read it automatically via the NoCloud datasource."
