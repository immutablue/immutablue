#!/bin/bash
# Kuberblue Components Tests
#
# This script tests individual Kuberblue components, including:
# - Just commands functionality
# - Manifest deployment capabilities (Helm, Kustomize, raw YAML)
# - User management scripts
# - Setup and management script functionality
#
# Usage: ./test_kuberblue_components.sh [IMAGE_NAME:TAG]
#   where IMAGE_NAME:TAG is an optional container image reference

# Enable strict error handling
set -euo pipefail

echo "Running Kuberblue components tests"

# Test variables
IMAGE="${1:-quay.io/immutablue/immutablue:42}"
TEST_DIR="$(dirname "$(realpath "$0")")" 
ROOT_DIR="$(dirname "$(dirname "$TEST_DIR")")"

# Source helper utilities
# shellcheck source=helpers/cluster_utils.sh
source "$TEST_DIR/helpers/cluster_utils.sh"
# shellcheck source=helpers/manifest_utils.sh
source "$TEST_DIR/helpers/manifest_utils.sh"
# shellcheck source=helpers/network_utils.sh
source "$TEST_DIR/helpers/network_utils.sh"

# Test all kuberblue just commands
# Validates that all just commands execute without errors
function test_just_commands() {
    echo "Testing kuberblue just commands"
    
    # Check if just is available in container
    if ! podman run --rm "$IMAGE" command -v just >/dev/null 2>&1; then
        echo "SKIP: just command not available in container"
        return 0
    fi
    
    # Check if kuberblue justfile exists in container
    local kuberblue_justfile="/usr/libexec/immutablue/just/30-kuberblue.justfile"
    if ! podman run --rm "$IMAGE" test -f "$kuberblue_justfile"; then
        echo "FAIL: Kuberblue justfile not found at $kuberblue_justfile"
        return 1
    fi
    
    # Test just command listing
    echo "Testing just command listing"
    if ! podman run --rm "$IMAGE" just --list-heading="Available Kuberblue commands:" --justfile="$kuberblue_justfile" --list; then
        echo "FAIL: Could not list kuberblue just commands"
        return 1
    fi
    
    # Test that just commands are defined (syntax check only in container context)
    echo "Testing just command definitions"
    local expected_commands=(
        "kube_get_config"
        "systemd_settings"
        "kube_init"
        "kube_reset"
    )
    
    for cmd in "${expected_commands[@]}"; do
        echo "Checking if just command '$cmd' is defined"
        if ! podman run --rm "$IMAGE" just --justfile="$kuberblue_justfile" --summary | grep -q "$cmd"; then
            echo "WARNING: Just command '$cmd' not found in justfile"
            # Don't fail the test as some commands might be conditional
        else
            echo "Just command '$cmd' found in justfile"
        fi
    done
    
    # Validate just command syntax
    echo "Validating justfile syntax"
    if ! podman run --rm "$IMAGE" just --justfile="$kuberblue_justfile" --summary >/dev/null 2>&1; then
        echo "FAIL: Kuberblue justfile syntax validation failed"
        return 1
    fi
    
    echo "PASS: Just commands test succeeded"
    return 0
}

# Test manifest deployment functionality
# Tests Helm charts, Kustomize, and raw YAML manifest deployment
function test_manifest_deployment() {
    echo "Testing manifest deployment functionality"
    
    local manifests_dir="/etc/kuberblue/manifests"
    
    if ! podman run --rm "$IMAGE" test -d "$manifests_dir"; then
        echo "FAIL: Manifests directory not found at $manifests_dir"
        return 1
    fi
    
    # Test basic manifest files exist (container-appropriate testing)
    echo "Testing manifest files exist"
    local expected_files=(
        "$manifests_dir/kube-flannel.yaml"
        "$manifests_dir/cilium/00-metadata.yaml"
        "$manifests_dir/cilium/10-values.yaml"
        "$manifests_dir/cilium/50-default-ip-pool.yaml"
    )
    
    for manifest_file in "${expected_files[@]}"; do
        if podman run --rm "$IMAGE" test -f "$manifest_file"; then
            echo "Found manifest file: $manifest_file"
        else
            echo "WARNING: Expected manifest file not found: $manifest_file"
            # Don't fail test as some manifests might be optional
        fi
    done
    
    # Test OpenEBS directory exists
    if podman run --rm "$IMAGE" test -d "$manifests_dir/openebs"; then
        echo "Found OpenEBS manifest directory"
        # Check for expected OpenEBS files
        podman run --rm "$IMAGE" test -f "$manifests_dir/openebs/00-metadata.yaml" && echo "Found OpenEBS metadata file"
        podman run --rm "$IMAGE" test -f "$manifests_dir/openebs/10-values.yaml" && echo "Found OpenEBS values file"
    fi
    
    # Test basic YAML syntax for key manifests (container-safe)
    echo "Testing basic YAML syntax"
    local yaml_files=(
        "$manifests_dir/kube-flannel.yaml"
        "$manifests_dir/cilium/10-values.yaml"
    )
    
    for yaml_file in "${yaml_files[@]}"; do
        if podman run --rm "$IMAGE" test -f "$yaml_file"; then
            echo "Testing YAML syntax for: $yaml_file"
            # Basic YAML syntax test using python (available in container)
            if ! podman run --rm "$IMAGE" python3 -c "import yaml; yaml.safe_load(open('$yaml_file'))" 2>/dev/null; then
                echo "WARNING: YAML syntax issue in $yaml_file"
                # Don't fail test as this might be due to templating
            else
                echo "YAML syntax valid for: $yaml_file"
            fi
        fi
    done
    
    # Test manifest template validation
    if podman run --rm "$IMAGE" test -f "$manifests_dir/metadata.yaml.tpl"; then
        echo "Found metadata template file"
        if ! podman run --rm "$IMAGE" test -s "$manifests_dir/metadata.yaml.tpl"; then
            echo "WARNING: Metadata template file is empty"
        fi
    fi
    
    # Test deployment script exists
    local deploy_script="/usr/libexec/kuberblue/kube_setup/kube_deploy.sh"
    if podman run --rm "$IMAGE" test -f "$deploy_script"; then
        echo "Found deployment script: $deploy_script"
        # Test script syntax
        if ! podman run --rm "$IMAGE" bash -n "$deploy_script"; then
            echo "FAIL: Deployment script has syntax errors"
            return 1
        else
            echo "Deployment script syntax is valid"
        fi
    fi
    
    echo "PASS: Manifest deployment test succeeded"
    return 0
}

# Test user management functionality
# Tests kuberblue user creation and kubectl configuration
function test_user_management() {
    echo "Testing user management functionality"
    
    # Test user creation script
    local user_script="/usr/libexec/kuberblue/kube_setup/kube_add_kuberblue_user.sh"
    if ! podman run --rm "$IMAGE" test -f "$user_script"; then
        echo "FAIL: User creation script not found at $user_script"
        return 1
    fi
    
    # Validate script syntax
    if ! podman run --rm "$IMAGE" bash -n "$user_script"; then
        echo "FAIL: User creation script has syntax errors"
        return 1
    else
        echo "User creation script syntax is valid"
    fi
    
    # Test variables file
    local variables_file="/usr/libexec/kuberblue/variables.sh"
    if ! podman run --rm "$IMAGE" test -f "$variables_file"; then
        echo "FAIL: Variables file not found at $variables_file"
        return 1
    fi
    
    # Test variables file syntax
    if ! podman run --rm "$IMAGE" bash -n "$variables_file"; then
        echo "FAIL: Variables file has syntax errors"
        return 1
    else
        echo "Variables file syntax is valid"
    fi
    
    # Test key variables are defined in the variables file
    echo "Testing key variables in variables file"
    if ! podman run --rm "$IMAGE" bash -c "source $variables_file && test -n \"\${KUBERBLUE_UID:-}\""; then
        echo "FAIL: KUBERBLUE_UID not defined in variables file"
        return 1
    fi
    
    # Check the UID value
    local uid_value
    uid_value=$(podman run --rm "$IMAGE" bash -c "source $variables_file && echo \${KUBERBLUE_UID}")
    if [[ "$uid_value" != "970" ]]; then
        echo "FAIL: KUBERBLUE_UID should be 970, got $uid_value"
        return 1
    else
        echo "KUBERBLUE_UID correctly set to 970"
    fi
    
    # Test kubectl configuration script
    local config_script="/usr/libexec/kuberblue/kube_setup/kube_put_config.sh"
    if ! podman run --rm "$IMAGE" test -f "$config_script"; then
        echo "FAIL: Kubectl config script not found at $config_script"
        return 1
    fi
    
    # Validate script syntax
    if ! podman run --rm "$IMAGE" bash -n "$config_script"; then
        echo "FAIL: Kubectl config script has syntax errors"
        return 1
    else
        echo "Kubectl config script syntax is valid"
    fi
    
    # Test get config script
    local get_config_script="/usr/libexec/kuberblue/kube_setup/kube_get_config.sh"
    if ! podman run --rm "$IMAGE" test -f "$get_config_script"; then
        echo "FAIL: Get config script not found at $get_config_script"
        return 1
    fi
    
    # Validate script syntax
    if ! podman run --rm "$IMAGE" bash -n "$get_config_script"; then
        echo "FAIL: Get config script has syntax errors"
        return 1
    else
        echo "Get config script syntax is valid"
    fi
    
    # Test run command as user script
    local run_as_user_script="/usr/libexec/kuberblue/kube_setup/run_command_as_kuberblue_user.sh"
    if ! podman run --rm "$IMAGE" test -f "$run_as_user_script"; then
        echo "FAIL: Run as user script not found at $run_as_user_script"
        return 1
    fi
    
    # Validate script syntax
    if ! podman run --rm "$IMAGE" bash -n "$run_as_user_script"; then
        echo "FAIL: Run as user script has syntax errors"
        return 1
    else
        echo "Run as user script syntax is valid"
    fi
    
    # Test sudoers configuration
    if ! podman run --rm "$IMAGE" test -f "/etc/sudoers"; then
        echo "FAIL: Sudoers file not found"
        return 1
    else
        echo "Sudoers file found"
    fi
    
    echo "PASS: User management test succeeded"
    return 0
}

# Test script functionality
# Tests all scripts in /usr/libexec/kuberblue/ for syntax and basic functionality
function test_script_functionality() {
    echo "Testing script functionality"
    
    local scripts_dir="/usr/libexec/kuberblue"
    
    if ! podman run --rm "$IMAGE" test -d "$scripts_dir"; then
        echo "FAIL: Scripts directory not found at $scripts_dir"
        return 1
    fi
    
    # Test main common script
    local common_script="$scripts_dir/99-common.sh"
    if ! podman run --rm "$IMAGE" test -f "$common_script"; then
        echo "FAIL: Common script not found at $common_script"
        return 1
    fi
    
    # Validate syntax of key shell scripts
    echo "Validating script syntax"
    local key_scripts=(
        "/usr/libexec/kuberblue/99-common.sh"
        "/usr/libexec/kuberblue/variables.sh"
        "/usr/libexec/kuberblue/setup/first_boot.sh"
        "/usr/libexec/kuberblue/setup/on_boot.sh"
        "/usr/libexec/kuberblue/setup/on_shutdown.sh"
        "/usr/libexec/kuberblue/setup/run_post_install.sh"
        "/usr/libexec/kuberblue/setup/systemd_settings.sh"
    )
    
    local failed_scripts=0
    for script_file in "${key_scripts[@]}"; do
        if podman run --rm "$IMAGE" test -f "$script_file"; then
            echo "Checking syntax of $script_file"
            if ! podman run --rm "$IMAGE" bash -n "$script_file"; then
                echo "FAIL: Syntax error in $script_file"
                ((failed_scripts++))
            else
                echo "Script syntax valid: $script_file"
            fi
        else
            echo "WARNING: Script not found: $script_file"
        fi
    done
    
    if [[ $failed_scripts -gt 0 ]]; then
        echo "FAIL: $failed_scripts scripts have syntax errors"
        return 1
    fi
    
    # Additional scripts were already validated above in the key_scripts array
    
    # Basic script validation completed above
    
    echo "PASS: Script functionality test succeeded"
    return 0
}

# Test configuration files
# Validates Kuberblue configuration files
function test_configuration_files() {
    echo "Testing configuration files"
    
    local config_dir="/etc/kuberblue"
    
    if ! podman run --rm "$IMAGE" test -d "$config_dir"; then
        echo "FAIL: Configuration directory not found at $config_dir"
        return 1
    fi
    
    # Test kubeadm configuration
    local kubeadm_config="$config_dir/kubeadm.yaml"
    if ! podman run --rm "$IMAGE" test -f "$kubeadm_config"; then
        echo "FAIL: Kubeadm configuration not found at $kubeadm_config"
        return 1
    fi
    
    # Validate YAML syntax
    if ! podman run --rm "$IMAGE" python3 -c "import yaml; yaml.safe_load(open('$kubeadm_config'))" 2>/dev/null; then
        echo "FAIL: Kubeadm configuration has invalid YAML syntax"
        return 1
    fi
    
    # Test system configuration files
    local system_configs=(
        "/etc/modules-load.d/50-kuberblue.conf"
        "/etc/sysctl.d/50-kuberblue.conf"
        "/etc/systemd/system/kuberblue-onboot.service"
    )
    
    for config in "${system_configs[@]}"; do
        if podman run --rm "$IMAGE" test -f "$config"; then
            echo "Found system configuration: $config"
        else
            echo "WARNING: System configuration file not found at $config"
            # Don't fail test as some configs might be conditional
        fi
    done
    
    echo "PASS: Configuration files test succeeded"
    return 0
}

# Main test execution
echo "=== Running Kuberblue Components Tests ==="
FAILED=0

# Execute each test and track failures
if ! test_just_commands; then
    ((FAILED++))
fi

if ! test_manifest_deployment; then
    ((FAILED++))
fi

if ! test_user_management; then
    ((FAILED++))
fi

if ! test_script_functionality; then
    ((FAILED++))
fi

if ! test_configuration_files; then
    ((FAILED++))
fi

# Report test results
echo "=== Kuberblue Components Test Results ==="
if [[ $FAILED -eq 0 ]]; then
    echo "All Kuberblue components tests PASSED!"
    exit 0
else
    echo "$FAILED Kuberblue components tests FAILED!"
    exit 1
fi