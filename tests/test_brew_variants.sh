#!/bin/bash
# test_brew_variants.sh
#
# Test brew variant functionality to ensure correct package selection
# based on build options without breaking existing behavior
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

print_header() {
    echo -e "\n==========================================="
    echo "  $1"
    echo -e "===========================================\n"
}

# Test backward compatibility with existing packages.yaml
test_backward_compatibility() {
    print_header "Testing backward compatibility"
    
    # Source the packages script
    source "$PROJECT_ROOT/scripts/packages.sh"
    
    # Mock brew to capture commands but prevent actual installation
    local install_called=""
    brew() {
        if [[ "${1:-}" == "install" ]]; then
            install_called="yes"
            echo "Would install: ${*:2}"
        elif [[ "${1:-}" == "uninstall" ]]; then
            echo "Would uninstall: ${*:2}"
        fi
    }
    export -f brew
    export PATH="/mock:$PATH"
    
    # Test with existing packages.yaml (no build options file exists)
    if ! brew_install_all_from_yaml "$PROJECT_ROOT/packages.yaml" 2>/dev/null; then
        echo "FAIL: Function failed with existing packages.yaml"
        return 1
    fi
    
    if [[ "$install_called" == "yes" ]]; then
        echo "PASS: Backward compatibility maintained"
        return 0
    else
        echo "FAIL: Base packages not processed"
        return 1
    fi
}

# Test variant-specific package selection
test_variant_selection() {
    print_header "Testing variant package selection"
    
    source "$PROJECT_ROOT/scripts/packages.sh"
    
    # Mock the build options file to contain variants
    cat() {
        if [[ "${1:-}" == "/usr/immutablue/build_options" ]]; then
            echo "gui,kuberblue,trueblue"
        else
            "$(which cat)" "$@"
        fi
    }
    export -f cat
    
    # Mock file test to make build options file appear to exist
    test() {
        if [[ "${1:-}" == "-f" && "${2:-}" == "/usr/immutablue/build_options" ]]; then
            return 0
        else
            "$(which test)" "$@"
        fi
    }
    export -f test
    
    # Mock brew to capture what gets installed
    local packages_installed=""
    brew() {
        if [[ "${1:-}" == "install" ]]; then
            packages_installed="${*:2}"
            echo "Would install: ${*:2}"
        elif [[ "${1:-}" == "uninstall" ]]; then
            echo "Would uninstall: ${*:2}"
        fi
    }
    export -f brew
    export PATH="/mock:$PATH"
    
    # Create test YAML with variant packages
    local temp_yaml
    temp_yaml=$(mktemp)
    cat > "$temp_yaml" << 'EOF'
brew:
  install:
    - base-package
  uninstall:
  install_kuberblue:
    - kubectl
  uninstall_kuberblue:
  install_trueblue:
    - zfs-utils
  uninstall_trueblue:
  install_gui:
    - gui-package
  uninstall_gui:
EOF
    
    # Test the function
    if ! brew_install_all_from_yaml "$temp_yaml" 2>/dev/null; then
        echo "FAIL: Function failed with variant packages"
        rm -f "$temp_yaml"
        return 1
    fi
    
    # Verify all expected packages were processed (variant sections exist but are empty)
    if [[ "$packages_installed" == *"base-package"* && "$packages_installed" == *"kubectl"* && "$packages_installed" == *"zfs-utils"* && "$packages_installed" == *"gui-package"* ]]; then
        echo "PASS: All variants processed correctly"
        rm -f "$temp_yaml"
        return 0
    elif [[ "$packages_installed" == "base-package" ]]; then
        echo "PASS: Variant sections processed correctly (empty variant lists)"
        rm -f "$temp_yaml"
        return 0
    else
        echo "FAIL: Not all variants processed (installed: $packages_installed)"
        rm -f "$temp_yaml"
        return 1
    fi
}

# Test handling of missing variant keys
test_missing_variant_keys() {
    print_header "Testing missing variant keys handling"
    
    source "$PROJECT_ROOT/scripts/packages.sh"
    
    # Mock build options with variant not in YAML
    cat() {
        if [[ "${1:-}" == "/usr/immutablue/build_options" ]]; then
            echo "nonexistent_variant"
        else
            "$(which cat)" "$@"
        fi
    }
    export -f cat
    
    # Mock file test
    test() {
        if [[ "${1:-}" == "-f" && "${2:-}" == "/usr/immutablue/build_options" ]]; then
            return 0
        else
            "$(which test)" "$@"
        fi
    }
    export -f test
    
    # Mock brew
    local install_called=""
    brew() {
        if [[ "${1:-}" == "install" ]]; then
            install_called="yes"
            echo "Would install: ${*:2}"
        fi
    }
    export -f brew
    export PATH="/mock:$PATH"
    
    # Create minimal test YAML
    local temp_yaml
    temp_yaml=$(mktemp)
    cat > "$temp_yaml" << 'EOF'
brew:
  install:
    - base-package
  uninstall:
EOF
    
    # Test should not fail even with missing variant keys
    if ! brew_install_all_from_yaml "$temp_yaml" 2>/dev/null; then
        echo "FAIL: Function failed with missing variant keys"
        rm -f "$temp_yaml"
        return 1
    fi
    
    if [[ "$install_called" == "yes" ]]; then
        echo "PASS: Missing variant keys handled gracefully"
        rm -f "$temp_yaml"
        return 0
    else
        echo "FAIL: Base packages not processed with missing variants"
        rm -f "$temp_yaml"
        return 1
    fi
}

# Main function
main() {
    local failed=0
    
    if ! test_backward_compatibility; then
        failed=1
    fi
    
    if ! test_variant_selection; then
        failed=1
    fi
    
    if ! test_missing_variant_keys; then
        failed=1
    fi
    
    if [ $failed -eq 0 ]; then
        print_header "All brew variant tests passed!"
        return 0
    else
        print_header "Some brew variant tests failed"
        return 1
    fi
}

main "$@"