#!/bin/bash
# Kuberblue Manifest Utilities
#
# Helper functions for validating and deploying Kubernetes manifests in Kuberblue tests
# Provides utilities for Helm charts, Kustomize, and raw YAML manifest validation
#
# Usage: source this file from test scripts to access utility functions

# Enable strict error handling
set -euo pipefail

# Constants
readonly MANIFEST_TIMEOUT=300

# Validate YAML syntax and Kubernetes schema
# Args: manifest_file_path
# Returns: 0 if valid, 1 if invalid
function test_manifest_syntax() {
    local manifest_file="$1"
    
    if [[ ! -f "$manifest_file" ]]; then
        echo "ERROR: Manifest file '$manifest_file' not found"
        return 1
    fi
    
    echo "Validating YAML syntax for '$manifest_file'"
    
    # Check YAML syntax using kubectl dry-run
    if ! kubectl apply --dry-run=client -f "$manifest_file" >/dev/null 2>&1; then
        echo "ERROR: YAML syntax validation failed for '$manifest_file'"
        kubectl apply --dry-run=client -f "$manifest_file" || true
        return 1
    fi
    
    # Check for Kubernetes schema validation
    if ! kubectl apply --dry-run=server -f "$manifest_file" >/dev/null 2>&1; then
        echo "ERROR: Kubernetes schema validation failed for '$manifest_file'"
        kubectl apply --dry-run=server -f "$manifest_file" || true
        return 1
    fi
    
    echo "YAML syntax and schema validation passed for '$manifest_file'"
    return 0
}

# Validate Helm chart deployment
# Args: chart_path namespace release_name values_file (optional)
# Returns: 0 if deployment succeeds, 1 if fails
function validate_helm_deployment() {
    local chart_path="$1"
    local namespace="$2"
    local release_name="$3"
    local values_file="${4:-}"
    
    echo "Validating Helm deployment: chart='$chart_path', namespace='$namespace', release='$release_name'"
    
    # Check if Helm is available
    if ! command -v helm >/dev/null; then
        echo "ERROR: helm command not found"
        return 1
    fi
    
    # Validate chart directory exists
    if [[ ! -d "$chart_path" ]]; then
        echo "ERROR: Chart directory '$chart_path' not found"
        return 1
    fi
    
    # Check if Chart.yaml exists
    if [[ ! -f "$chart_path/Chart.yaml" ]]; then
        echo "ERROR: Chart.yaml not found in '$chart_path'"
        return 1
    fi
    
    # Lint the chart
    echo "Linting Helm chart"
    if ! helm lint "$chart_path"; then
        echo "ERROR: Helm chart lint failed"
        return 1
    fi
    
    # Template the chart (dry-run)
    echo "Templating Helm chart"
    local helm_cmd="helm template $release_name $chart_path --namespace $namespace"
    
    if [[ -n "$values_file" && -f "$values_file" ]]; then
        helm_cmd="$helm_cmd --values $values_file"
    fi
    
    local templated_manifest
    if ! templated_manifest=$($helm_cmd 2>&1); then
        echo "ERROR: Helm template failed"
        echo "$templated_manifest"
        return 1
    fi
    
    # Validate templated manifest
    echo "Validating templated manifest"
    if ! echo "$templated_manifest" | kubectl apply --dry-run=server -f - >/dev/null 2>&1; then
        echo "ERROR: Templated manifest validation failed"
        echo "$templated_manifest" | kubectl apply --dry-run=server -f - || true
        return 1
    fi
    
    echo "Helm chart validation passed"
    return 0
}

# Deploy Helm chart and validate it's working
# Args: chart_path namespace release_name values_file (optional) timeout (optional)
# Returns: 0 if deployment succeeds and is healthy, 1 if fails
function deploy_and_validate_helm_chart() {
    local chart_path="$1"
    local namespace="$2"
    local release_name="$3"
    local values_file="${4:-}"
    local timeout="${5:-$MANIFEST_TIMEOUT}"
    
    echo "Deploying and validating Helm chart: '$release_name' in namespace '$namespace'"
    
    # Ensure namespace exists
    kubectl create namespace "$namespace" --dry-run=client -o yaml | kubectl apply -f - || true
    
    # Install/upgrade the chart
    local helm_cmd="helm upgrade --install $release_name $chart_path --namespace $namespace --wait --timeout ${timeout}s"
    
    if [[ -n "$values_file" && -f "$values_file" ]]; then
        helm_cmd="$helm_cmd --values $values_file"
    fi
    
    if ! $helm_cmd; then
        echo "ERROR: Helm deployment failed"
        helm status "$release_name" -n "$namespace" || true
        return 1
    fi
    
    # Validate deployment status
    if ! helm status "$release_name" -n "$namespace" | grep -q "STATUS: deployed"; then
        echo "ERROR: Helm release is not in deployed state"
        helm status "$release_name" -n "$namespace"
        return 1
    fi
    
    echo "Helm chart deployed and validated successfully"
    return 0
}

# Validate Kustomize deployment
# Args: kustomize_dir namespace
# Returns: 0 if deployment validation succeeds, 1 if fails
function validate_kustomize_deployment() {
    local kustomize_dir="$1"
    local namespace="$2"
    
    echo "Validating Kustomize deployment in '$kustomize_dir' for namespace '$namespace'"
    
    # Check if kustomization.yaml exists
    if [[ ! -f "$kustomize_dir/kustomization.yaml" ]]; then
        echo "ERROR: kustomization.yaml not found in '$kustomize_dir'"
        return 1
    fi
    
    # Build and validate the kustomization
    echo "Building Kustomize configuration"
    local kustomized_manifest
    if ! kustomized_manifest=$(kubectl kustomize "$kustomize_dir" 2>&1); then
        echo "ERROR: Kustomize build failed"
        echo "$kustomized_manifest"
        return 1
    fi
    
    # Validate the generated manifest
    echo "Validating Kustomize manifest"
    if ! echo "$kustomized_manifest" | kubectl apply --dry-run=server -f - >/dev/null 2>&1; then
        echo "ERROR: Kustomize manifest validation failed"
        echo "$kustomized_manifest" | kubectl apply --dry-run=server -f - || true
        return 1
    fi
    
    echo "Kustomize deployment validation passed"
    return 0
}

# Deploy and validate Kustomize configuration
# Args: kustomize_dir namespace timeout (optional)
# Returns: 0 if deployment succeeds, 1 if fails
function deploy_and_validate_kustomize() {
    local kustomize_dir="$1"
    local namespace="$2"
    local timeout="${3:-$MANIFEST_TIMEOUT}"
    
    echo "Deploying and validating Kustomize configuration from '$kustomize_dir'"
    
    # Ensure namespace exists
    kubectl create namespace "$namespace" --dry-run=client -o yaml | kubectl apply -f - || true
    
    # Apply the kustomization
    if ! kubectl apply -k "$kustomize_dir"; then
        echo "ERROR: Kustomize deployment failed"
        return 1
    fi
    
    # Wait for resources to be ready
    local start_time
    start_time=$(date +%s)
    
    while true; do
        local current_time
        current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        
        if [[ $elapsed -gt $timeout ]]; then
            echo "ERROR: Kustomize deployment timeout after ${timeout}s"
            return 1
        fi
        
        # Check if all resources are ready
        local pending_resources
        pending_resources=$(kubectl get all -n "$namespace" --no-headers | grep -E "(Pending|Creating|ContainerCreating)" | wc -l || echo "0")
        
        if [[ $pending_resources -eq 0 ]]; then
            echo "Kustomize deployment completed successfully"
            return 0
        fi
        
        echo "Waiting for ${pending_resources} resources to be ready..."
        sleep 10
    done
}

# Apply raw YAML manifest and validate
# Args: manifest_file namespace timeout (optional)
# Returns: 0 if successful, 1 if fails
function deploy_and_validate_manifest() {
    local manifest_file="$1"
    local namespace="$2"
    local timeout="${3:-$MANIFEST_TIMEOUT}"
    
    echo "Deploying and validating manifest '$manifest_file' in namespace '$namespace'"
    
    # Validate syntax first
    if ! test_manifest_syntax "$manifest_file"; then
        return 1
    fi
    
    # Ensure namespace exists
    kubectl create namespace "$namespace" --dry-run=client -o yaml | kubectl apply -f - || true
    
    # Apply the manifest
    if ! kubectl apply -f "$manifest_file" -n "$namespace"; then
        echo "ERROR: Failed to apply manifest '$manifest_file'"
        return 1
    fi
    
    # Wait for deployment to be ready (if it contains deployments)
    local deployments
    deployments=$(kubectl get -f "$manifest_file" -o jsonpath='{.items[?(@.kind=="Deployment")].metadata.name}' 2>/dev/null || echo "")
    
    if [[ -n "$deployments" ]]; then
        for deployment in $deployments; do
            echo "Waiting for deployment '$deployment' to be ready"
            if ! kubectl wait --for=condition=available deployment/"$deployment" -n "$namespace" --timeout="${timeout}s"; then
                echo "ERROR: Deployment '$deployment' failed to become ready"
                return 1
            fi
        done
    fi
    
    echo "Manifest deployed and validated successfully"
    return 0
}

# Validate all manifests in a directory
# Args: manifest_dir
# Returns: 0 if all valid, 1 if any invalid
function validate_manifest_directory() {
    local manifest_dir="$1"
    local failed=0
    
    echo "Validating all manifests in directory '$manifest_dir'"
    
    if [[ ! -d "$manifest_dir" ]]; then
        echo "ERROR: Directory '$manifest_dir' not found"
        return 1
    fi
    
    # Find all YAML files
    local yaml_files
    mapfile -t yaml_files < <(find "$manifest_dir" -name "*.yaml" -o -name "*.yml" 2>/dev/null || true)
    
    if [[ ${#yaml_files[@]} -eq 0 ]]; then
        echo "WARNING: No YAML files found in '$manifest_dir'"
        return 0
    fi
    
    for yaml_file in "${yaml_files[@]}"; do
        if ! test_manifest_syntax "$yaml_file"; then
            ((failed++))
        fi
    done
    
    if [[ $failed -eq 0 ]]; then
        echo "All manifests in '$manifest_dir' are valid"
        return 0
    else
        echo "$failed manifests failed validation in '$manifest_dir'"
        return 1
    fi
}

# Clean up Helm release
# Args: release_name namespace
# Returns: 0 on success, 1 on error
function cleanup_helm_release() {
    local release_name="$1"
    local namespace="$2"
    
    echo "Cleaning up Helm release '$release_name' in namespace '$namespace'"
    
    if helm list -n "$namespace" | grep -q "$release_name"; then
        if ! helm uninstall "$release_name" -n "$namespace"; then
            echo "ERROR: Failed to uninstall Helm release '$release_name'"
            return 1
        fi
        echo "Helm release '$release_name' uninstalled successfully"
    else
        echo "Helm release '$release_name' not found in namespace '$namespace'"
    fi
    
    return 0
}

# Get detailed information about failed resources
# Args: namespace
# Returns: always 0 (best effort)
function get_manifest_debug_info() {
    local namespace="$1"
    
    echo "=== Manifest Debug Information for namespace '$namespace' ==="
    
    echo "--- All Resources ---"
    kubectl get all -n "$namespace" -o wide || true
    
    echo "--- Failed Pods ---"
    kubectl get pods -n "$namespace" --field-selector=status.phase=Failed -o wide || true
    
    echo "--- Pending Pods ---"
    kubectl get pods -n "$namespace" --field-selector=status.phase=Pending -o wide || true
    
    echo "--- Events ---"
    kubectl get events -n "$namespace" --sort-by='.lastTimestamp' | tail -20 || true
    
    echo "--- Pod Descriptions (if any failed) ---"
    local failed_pods
    failed_pods=$(kubectl get pods -n "$namespace" --field-selector=status.phase=Failed --no-headers -o custom-columns=":metadata.name" 2>/dev/null || echo "")
    
    for pod in $failed_pods; do
        echo "--- Pod $pod ---"
        kubectl describe pod "$pod" -n "$namespace" || true
    done
    
    return 0
}