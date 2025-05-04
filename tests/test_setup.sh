#!/bin/bash
# test_setup.sh
#
# Run tests for the enhanced first-boot setup modules
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

print_header() {
    echo -e "\n==========================================="
    echo "  $1"
    echo -e "===========================================\n"
}

# Run tests for TUI setup
run_tui_tests() {
    print_header "Running TUI Setup Tests"
    python3 "${SCRIPT_DIR}/setup/test_immutablue_setup_tui.py" -v
    return $?
}

# Run tests for GUI setup
run_gui_tests() {
    print_header "Running GUI Setup Tests"
    python3 "${SCRIPT_DIR}/setup/test_immutablue_setup_gui.py" -v
    return $?
}

# Main function to run all tests
main() {
    local failed=0
    
    # Ensure Python dependencies are available
    if ! python3 -c "import yaml" &>/dev/null; then
        echo "Error: Python yaml module not found. Please install with: pip install pyyaml"
        return 1
    fi
    
    # Run TUI tests
    if ! run_tui_tests; then
        echo "TUI tests failed"
        failed=1
    fi
    
    # Run GUI tests
    if ! run_gui_tests; then
        echo "GUI tests failed"
        failed=1
    fi
    
    if [ $failed -eq 0 ]; then
        print_header "All setup tests passed!"
        return 0
    else
        print_header "Some setup tests failed"
        return 1
    fi
}

# Run main function
main "$@"