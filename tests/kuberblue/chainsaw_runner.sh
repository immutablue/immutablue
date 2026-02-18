#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
readonly ROOT_DIR
readonly MANIFEST_BASE_DIR="/etc/kuberblue/manifests"

# Common constants
readonly TRUE=1
readonly FALSE=0

# Import common utilities from cluster_utils
# shellcheck source=./helpers/cluster_utils.sh
source "$SCRIPT_DIR/helpers/cluster_utils.sh"

# Logging functions
function info() {
    echo "[INFO] $*"
}

function warn() {
    echo "[WARN] $*" >&2
}

function error() {
    echo "[ERROR] $*" >&2
}

function success() {
    echo "[SUCCESS] $*"
}

function discover_chainsaw_tests() {
    local manifest_dir="$1"
    local test_files=()
    
    info "Discovering Chainsaw tests in $manifest_dir"
    
    # Find all *_test.yaml files recursively
    while IFS= read -r -d '' file; do
        test_files+=("$file")
    done < <(find "$manifest_dir" -name "*_test.yaml" -type f -print0 2>/dev/null || true)
    
    if [[ ${#test_files[@]} -eq 0 ]]; then
        warn "No Chainsaw tests found in $manifest_dir"
        return 1
    fi
    
    info "Found ${#test_files[@]} Chainsaw test files:"
    printf '  %s\n' "${test_files[@]}"
    
    printf '%s\n' "${test_files[@]}"
}

function validate_test_metadata() {
    local test_file="$1"
    
    # Check required metadata
    if ! grep -q "kuberblue.test/component" "$test_file"; then
        error "Test $test_file missing required annotation: kuberblue.test/component"
        return 1
    fi
    
    if ! grep -q "kuberblue.test/category" "$test_file"; then
        error "Test $test_file missing required annotation: kuberblue.test/category"
        return 1
    fi
    
    return 0
}


function run_chainsaw_tests() {
    local manifest_dir="$1"
    local test_files=()
    local failed_tests=0
    
    # Verify chainsaw is available
    if ! command -v chainsaw >/dev/null 2>&1; then
        error "chainsaw command not found. Please install Chainsaw."
        return 1
    fi
    
    # Verify cluster is accessible
    if ! kubectl cluster-info >/dev/null 2>&1; then
        error "Cannot access Kubernetes cluster. Please ensure cluster is running and kubectl is configured."
        return 1
    fi
    
    
    # Discover tests
    if ! readarray -t test_files < <(discover_chainsaw_tests "$manifest_dir"); then
        warn "No tests to run"
        return 0
    fi
    
    # Validate test metadata
    for test_file in "${test_files[@]}"; do
        if ! validate_test_metadata "$test_file"; then
            ((failed_tests++))
        fi
    done
    
    if [[ $failed_tests -gt 0 ]]; then
        error "$failed_tests tests have invalid metadata"
        return 1
    fi
    
    # Execute tests with Chainsaw
    info "Running Chainsaw tests..."
    
    local chainsaw_config="/etc/kuberblue/chainsaw.yaml"
    local chainsaw_args=(
        "test"
        "--test-dir=$manifest_dir"
    )
    
    # Add config if it exists
    if [[ -f "$chainsaw_config" ]]; then
        chainsaw_args+=("--config=$chainsaw_config")
    fi
    
    # Add parallel execution if supported
    if [[ "${CHAINSAW_PARALLEL:-1}" == "1" ]]; then
        chainsaw_args+=("--parallel=4")
    fi
    
    # Execute tests
    if chainsaw "${chainsaw_args[@]}"; then
        success "All Chainsaw tests passed"
        return 0
    else
        error "Some Chainsaw tests failed"
        return 1
    fi
}

function main() {
    local manifest_dir="${1:-$MANIFEST_BASE_DIR}"
    
    info "Starting Chainsaw test execution"
    info "Manifest directory: $manifest_dir"
    
    if [[ ! -d "$manifest_dir" ]]; then
        error "Manifest directory does not exist: $manifest_dir"
        return 1
    fi
    
    run_chainsaw_tests "$manifest_dir"
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
