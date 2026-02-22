#!/bin/bash
# ==============================================================================
# Immutablue Image Builder Wrapper
# ==============================================================================
# Wraps bootc-image-builder with common options and handles post-processing.
#
# Usage: build-image.sh <type> <image:tag> <build_dir> <config_file> [options]
#
# Types: iso, raw, ami, gce, vhd, vmdk, qcow2, anaconda-iso
#
# Environment Variables:
#   BOOTC_IMAGE_BUILDER  - Image to use (default: quay.io/centos-bootc/bootc-image-builder:latest)
#   ROOTFS               - Filesystem type (default: btrfs)
#
# Exit Codes:
#   0 - Success
#   1 - Invalid arguments
#   2 - Build failed
# ==============================================================================

set -euo pipefail

TYPE="${1:-}"
IMAGE_TAG="${2:-}"
BUILD_DIR="${3:-}"
CONFIG_FILE="${4:-}"
shift 4 2>/dev/null || true

if [[ -z "$TYPE" ]] || [[ -z "$IMAGE_TAG" ]] || [[ -z "$BUILD_DIR" ]]; then
    echo "Usage: $0 <type> <image:tag> <build_dir> <config_file> [options]"
    echo "Types: iso, raw, ami, gce, vhd, vmdk, qcow2, anaconda-iso"
    exit 1
fi

BOOTC_IMAGE_BUILDER="${BOOTC_IMAGE_BUILDER:-quay.io/centos-bootc/bootc-image-builder:latest}"
ROOTFS="${ROOTFS:-btrfs}"

echo "Building ${TYPE} image for ${IMAGE_TAG}..."
echo "Build directory: ${BUILD_DIR}"
echo "Config file: ${CONFIG_FILE}"

mkdir -p "$BUILD_DIR"

if [[ ! -f "$CONFIG_FILE" ]]; then
    CONFIG_FILE="${BUILD_DIR}/config.toml"
    echo "No config found - creating minimal config"
    echo "# Immutablue ${TYPE} config - no users configured" > "$CONFIG_FILE"
fi

cp "$CONFIG_FILE" "${BUILD_DIR}/config.toml"

sudo podman pull "$IMAGE_TAG"

sudo podman run \
    --rm \
    -it \
    --privileged \
    --security-opt label=type:unconfined_t \
    -v "${BUILD_DIR}:/output:z" \
    -v /var/lib/containers/storage:/var/lib/containers/storage \
    -v "${BUILD_DIR}/config.toml:/config.toml:ro" \
    "${BOOTC_IMAGE_BUILDER}" \
    --type "$TYPE" \
    --rootfs "$ROOTFS" \
    --config /config.toml \
    "$IMAGE_TAG"

sudo chown -R "$(id -u):$(id -g)" "$BUILD_DIR"

echo "Build completed successfully"
echo "Output directory: ${BUILD_DIR}"
