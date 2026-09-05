#!/bin/bash
# Package Presence Tests for Immutablue
#
# Asserts that every RPM packages.yaml asked for is actually present in the
# built image, for the variant that was actually built.
#
# Why this exists: the build installs packages in bulk and never verifies the
# result. If a COPR disappears, a package is renamed upstream, or a dependency
# resolution quietly drops something, the image still builds and still pushes.
# The absence is discovered later, by a user, on a system that has already been
# rebased onto it.
#
# This differs from the package list in tests/crispy/validate_container.c in
# two ways that matter:
#
#   1. That list is a hand-maintained copy of packages.yaml rpm.all, so it
#      drifts. At the time of writing it asserts 83 packages while a
#      silverblue+gui build actually requests 147 -- the remainder are
#      unverified.
#   2. It is one fixed list, so variant-specific packages (gui, kuberblue,
#      trueblue, cyan...) are never checked at all.
#
# Here the expected set is derived from packages.yaml at test time using the
# same get_yaml_array() the build itself uses, so the assertions cannot drift
# from what was requested, and they follow the variant automatically.
#
# It can be run directly or through the Makefile with 'make test'
#
# Usage: ./test_package_presence.sh [IMAGE_NAME:TAG]
#   where IMAGE_NAME:TAG is an optional container image reference
#
# Return codes:
# - 0: Every requested package is present (or the test was skipped)
# - 1: One or more requested packages are missing from the image

# Enable strict error handling
set -euo pipefail

echo "Testing Immutablue package presence"

TEST_DIR="$(dirname "$(realpath "$0")")"
ROOT_DIR="$(dirname "${TEST_DIR}")"

IMAGE="${1:-quay.io/immutablue/immutablue:42}"

IMAGE_INFO_PATH="/usr/share/immutablue/image-info.json"

# Read a flat string field out of the image's own image-info.json.
#
# The image is the authority on what it is: reading the variant list from the
# image under test means this works the same whether it is invoked straight
# after a build or against an image pulled from the registry, with no need for
# the caller to restate the build flags.
#
# param $1: field name
# returns: the value, or empty
function image_info_field() {
    local field="$1"

    # '|| true' matters under 'set -o pipefail': an image without
    # image-info.json makes sed (and therefore podman) exit non-zero, which
    # would otherwise abort this script inside the calling assignment rather
    # than falling through to the intended skip.
    { podman run --rm --entrypoint "" "${IMAGE}" \
        sed -n "s/.*\"${field}\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" \
        "${IMAGE_INFO_PATH}" 2>/dev/null || true; } | head -n 1
}

# Read the variants array out of image-info.json as a CSV list.
#
# Emitted by the build as ["silverblue","gui"]; converted back to the
# comma-separated form get_yaml_array() expects in IMMUTABLUE_BUILD_OPTIONS.
function image_info_variants() {
    # See image_info_field() for why the failure is swallowed here.
    { podman run --rm --entrypoint "" "${IMAGE}" \
        sed -n 's/.*"variants"[[:space:]]*:[[:space:]]*\[\([^]]*\)\].*/\1/p' \
        "${IMAGE_INFO_PATH}" 2>/dev/null || true; } \
        | head -n 1 \
        | tr -d '" '
}

# Verify the image is reachable before trying to interrogate it.
if ! podman image exists "${IMAGE}" 2>/dev/null; then
    if ! podman pull "${IMAGE}" >/dev/null 2>&1; then
        echo "WARN: image ${IMAGE} is not available locally and could not be pulled, test skipped"
        exit 0
    fi
fi

# Determine what the image claims to be.
#
# Falls back to the environment so the test still works when driven directly
# by the Makefile, which already knows these values.
BUILD_OPTIONS="${IMMUTABLUE_BUILD_OPTIONS:-$(image_info_variants)}"
IMAGE_VERSION="${VERSION:-$(image_info_field version)}"

if [[ -z "${BUILD_OPTIONS}" ]] || [[ -z "${IMAGE_VERSION}" ]]; then
    echo "WARN: ${IMAGE} has no ${IMAGE_INFO_PATH} and no build options were supplied"
    echo "WARN: (images built before image-info.json cannot be checked), test skipped"
    exit 0
fi

echo "Image variants: ${BUILD_OPTIONS}"
echo "Image version:  ${IMAGE_VERSION}"

# Compute the expected package set using the build's own lookup logic.
#
# 99-common.sh is sourced rather than reimplemented so that the variant,
# architecture and version fallthrough stays identical to what the build did;
# any divergence here would produce false failures.
TRUE="${TRUE:-1}"
FALSE="${FALSE:-0}"
export INSTALL_DIR="${ROOT_DIR}"
export VERSION="${IMAGE_VERSION}"
export IMMUTABLUE_BUILD_OPTIONS="${BUILD_OPTIONS}"
export FEDORA_VERSION="${IMAGE_VERSION}"

# shellcheck source=/dev/null
source "${ROOT_DIR}/build/99-common.sh"

mapfile -t EXPECTED_PACKAGES < <(get_immutablue_packages | sort -u | grep -v '^$')

if [[ ${#EXPECTED_PACKAGES[@]} -eq 0 ]]; then
    echo "FAIL: packages.yaml yielded no packages for ${BUILD_OPTIONS}"
    echo "      This almost certainly means the lookup is broken rather than"
    echo "      that the image genuinely requests nothing."
    exit 1
fi

echo "Checking ${#EXPECTED_PACKAGES[@]} requested packages"

# Query the whole set in a single container invocation.
#
# --whatprovides resolves both plain names and capabilities, matching how dnf5
# interpreted the same strings at install time; querying one package per
# podman run would be correct but far too slow for a list this size.
MISSING_OUTPUT="$(podman run --rm --entrypoint "" "${IMAGE}" \
    bash -c '
        missing=()
        for pkg in "$@"
        do
            if ! rpm --quiet -q --whatprovides "${pkg}"
            then
                missing+=("${pkg}")
            fi
        done
        printf "%s\n" "${missing[@]+"${missing[@]}"}"
    ' _ "${EXPECTED_PACKAGES[@]}" 2>/dev/null | grep -v '^$' || true)"

echo ""
echo "=== Package Presence Test Summary ==="

if [[ -n "${MISSING_OUTPUT}" ]]; then
    MISSING_COUNT="$(printf '%s\n' "${MISSING_OUTPUT}" | wc -l)"
    echo "Requested: ${#EXPECTED_PACKAGES[@]}"
    echo "Missing:   ${MISSING_COUNT}"
    echo ""
    echo "The following packages are listed in packages.yaml but are not in the image:"
    printf '%s\n' "${MISSING_OUTPUT}" | sed 's/^/  - /'
    echo ""
    echo "RESULT: FAILED"
    exit 1
fi

echo "Requested: ${#EXPECTED_PACKAGES[@]}"
echo "Missing:   0"
echo "RESULT: PASSED"
exit 0
