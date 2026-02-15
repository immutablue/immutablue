#!/bin/bash
# =============================================================================
# Blue From Scratch (BFS) Build Script
# =============================================================================
# Orchestrates the BuildStream-based build of Immutablue from source.
#
# This script:
# 1. Checks prerequisites (BuildStream, buildbox, etc.)
# 2. Tracks source refs if needed
# 3. Builds the complete OS tree
# 4. Produces an OCI image compatible with bootc
#
# Usage:
#   ./bfs/build.sh                    # Full build
#   ./bfs/build.sh --track            # Track latest upstream refs first
#   ./bfs/build.sh --shell kernel     # Open shell in kernel build sandbox
#   ./bfs/build.sh --export-oci       # Build and export OCI image
#   ./bfs/build.sh --status           # Show build status of all elements
#
# Environment Variables:
#   BFS_CACHE_DIR     Cache directory (default: ~/.cache/bfs)
#   BFS_REGISTRY      OCI registry (default: quay.io/immutablue)
#   BFS_TAG           Image tag (default: bfs)
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"
BFS_DIR="${SCRIPT_DIR}"

# Defaults
BFS_CACHE_DIR="${BFS_CACHE_DIR:-${HOME}/.cache/bfs}"
BFS_REGISTRY="${BFS_REGISTRY:-quay.io/immutablue}"
BFS_TAG="${BFS_TAG:-bfs}"
ACTION="${1:-build}"

# =============================================================================
# Helper functions
# =============================================================================

_log () {
    echo "[BFS] $*"
}

_err () {
    echo "[BFS] ERROR: $*" >&2
    exit 1
}

_check_prereq () {
    local cmd="${1}"
    local pkg="${2:-${1}}"

    if ! command -v "${cmd}" &>/dev/null
    then
        _err "${cmd} not found. Install it with: dnf install ${pkg} (or pip install ${pkg})"
    fi
}

# =============================================================================
# Prerequisites check
# =============================================================================

check_prerequisites () {
    _log "Checking prerequisites..."

    _check_prereq bst "buildstream"
    _check_prereq bwrap "bubblewrap"
    _check_prereq fusermount3 "fuse3"
    _check_prereq git "git"

    # Check for buildbox components
    for tool in buildbox-casd buildbox-fuse buildbox-run-bubblewrap
    do
        if ! command -v "${tool}" &>/dev/null
        then
            _log "WARNING: ${tool} not found. BuildStream may not work correctly."
            _log "Install buildbox from: https://buildstream.build/install.html"
        fi
    done

    # Check for buildstream-plugins-community (OCI plugin)
    if ! python3 -c "import bst_plugins_community" 2>/dev/null
    then
        _log "WARNING: buildstream-plugins-community not found."
        _log "Install with: pip install buildstream-plugins-community"
        _log "OCI image output will not be available without it."
    fi

    _log "Prerequisites OK"
}

# =============================================================================
# Build actions
# =============================================================================

# Track latest upstream source refs
track_sources () {
    _log "Tracking latest upstream source refs..."
    cd "${BFS_DIR}"

    # Junction must be tracked first -- other elements depend on it
    _log "Tracking freedesktop-sdk junction..."
    bst source track freedesktop-sdk.bst

    # Now track all remaining elements
    _log "Tracking all elements..."
    bst source track --deps all immutablue/image.bst

    _log "Source tracking complete. Review and commit the updated refs."
}

# Show build status of all elements
show_status () {
    _log "Element status:"
    cd "${BFS_DIR}"
    bst show immutablue/image.bst
}

# Build the full OS tree
build_image () {
    _log "Building Immutablue BFS..."
    cd "${BFS_DIR}"

    bst build immutablue/image.bst

    _log "Build complete."
}

# Export the OCI image
export_oci () {
    _log "Building and exporting OCI image..."
    cd "${BFS_DIR}"

    # Build the OCI element
    bst build oci/immutablue-bfs.bst

    # Export as OCI tarball
    local oci_tar="${PROJECT_ROOT}/bfs-output/immutablue-bfs.oci.tar"
    mkdir -p "$(dirname "${oci_tar}")"

    _log "Exporting OCI image to ${oci_tar}..."
    bst artifact checkout --tar "${oci_tar}" oci/immutablue-bfs.bst

    _log "OCI image exported: ${oci_tar}"
    _log ""
    _log "Load into podman with:"
    _log "  podman load < ${oci_tar}"
    _log ""
    _log "Or push to registry:"
    _log "  podman push localhost/immutablue-bfs:latest ${BFS_REGISTRY}/immutablue:${BFS_TAG}"
}

# Export as filesystem tree (for inspection or manual ostree commit)
export_tree () {
    _log "Exporting filesystem tree..."
    cd "${BFS_DIR}"

    local tree_dir="${PROJECT_ROOT}/bfs-output/rootfs"
    rm -rf "${tree_dir}"
    mkdir -p "${tree_dir}"

    bst artifact checkout --directory "${tree_dir}" immutablue/image.bst

    _log "Filesystem tree exported to: ${tree_dir}"
    _log ""
    _log "To create an ostree commit:"
    _log "  ostree --repo=repo init --mode=bare-user"
    _log "  ostree commit --repo=repo --branch=immutablue/bfs/x86_64 ${tree_dir}"
    _log ""
    _log "To encapsulate as OCI for bootc:"
    _log "  ostree container encapsulate --repo=repo immutablue/bfs/x86_64 docker://registry/immutablue:bfs"
}

# Open a build shell for debugging
open_shell () {
    local element="${2:-immutablue/image.bst}"
    _log "Opening shell for ${element}..."
    cd "${BFS_DIR}"
    bst shell "${element}"
}

# =============================================================================
# Main
# =============================================================================

check_prerequisites

case "${ACTION}" in
    build)
        build_image
        ;;
    --track)
        track_sources
        ;;
    --status)
        show_status
        ;;
    --export-oci)
        build_image
        export_oci
        ;;
    --export-tree)
        build_image
        export_tree
        ;;
    --shell)
        open_shell "$@"
        ;;
    -h|--help)
        echo "Usage: $0 [action]"
        echo ""
        echo "Actions:"
        echo "  build          Build the full OS tree (default)"
        echo "  --track        Track latest upstream source refs"
        echo "  --status       Show build status of all elements"
        echo "  --export-oci   Build and export OCI image"
        echo "  --export-tree  Build and export filesystem tree"
        echo "  --shell [elem] Open shell in element sandbox"
        echo "  -h, --help     Show this help"
        echo ""
        echo "Environment:"
        echo "  BFS_CACHE_DIR  Cache directory (default: ~/.cache/bfs)"
        echo "  BFS_REGISTRY   OCI registry (default: quay.io/immutablue)"
        echo "  BFS_TAG        Image tag (default: bfs)"
        ;;
    *)
        _err "Unknown action: ${ACTION}. Use --help for usage."
        ;;
esac
