#!/bin/bash
# Immutablue Shell Script Validation
#
# This script uses shellcheck to validate all shell scripts in the Immutablue project.
# It checks for common shell script issues, best practices, and potential bugs.
#
# Usage: ./test_shellcheck.sh [--fix]
#
# Options:
#   --fix    Attempt to automatically fix some shell script issues (experimental)
#
# Return codes:
#   0: All shell scripts passed validation
#   1: One or more shell scripts failed validation

# Enable strict error handling
set -eo pipefail

# Initialize variables
EXIT_CODE=0
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
PROJECT_ROOT="$(realpath "${SCRIPT_DIR}/..")"
FIX_MODE=false
SHELLCHECK_OPTS=()
SUCCESS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

# Process command line arguments
REPORT_ONLY=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --fix)
            FIX_MODE=true
            echo "Running in fix mode (will highlight issues that need manual fixes)"
            shift
            ;;
        --report-only)
            REPORT_ONLY=true
            echo "Running in report-only mode (will not fail even if issues are found)"
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [--fix] [--report-only]"
            echo ""
            echo "Options:"
            echo "  --fix          Display detailed information about issues that need manual fixes (experimental)"
            echo "  --report-only  Report issues but always exit with success (for CI integration)"
            echo "  --help         Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Configure ShellCheck options
# --shell=bash: Specify bash as the shell dialect
# --severity=warning: Only report warnings and errors (ignore style/info)
# --enable=all: Enable all optional checks
# --exclude: Disable specific checks that are not relevant or too strict
SHELLCHECK_OPTS=(
    "--shell=bash"
    "--severity=warning"
    "--enable=all"
    "--external-sources"
    "--exclude=SC1090,SC1091"  # Don't complain about non-constant source
    "--exclude=SC2034"  # Allow unused variables as they might be used by sourced scripts
)

# Add color if terminal supports it
if [[ -t 1 ]]; then
    SHELLCHECK_OPTS+=("--color=always")
else
    SHELLCHECK_OPTS+=("--color=never")
fi

# Function to check if shellcheck is installed
check_shellcheck_installed() {
    if ! command -v shellcheck &> /dev/null; then
        echo "Error: ShellCheck not found. Please install ShellCheck before running this test."
        echo "Installation instructions: https://github.com/koalaman/shellcheck#installing"
        exit 1
    fi
}

# Function to run shellcheck on a file
run_shellcheck() {
    local file="$1"
    local relative_path="${file#$PROJECT_ROOT/}"
    
    echo -n "Checking ${relative_path}... "
    
    # Run shellcheck with configured options
    if shellcheck "${SHELLCHECK_OPTS[@]}" "$file"; then
        echo "PASS"
        ((SUCCESS_COUNT++))
        return 0
    else
        echo "FAIL"
        ((FAIL_COUNT++))
        return 1
    fi
}

# Function to find all shell scripts in the project
find_shell_scripts() {
    local all_scripts=()
    
    # Find all .sh files
    while IFS= read -r -d '' file; do
        all_scripts+=("$file")
    done < <(find "$PROJECT_ROOT" -type f -name "*.sh" -not -path "*/\.*" -print0)
    
    # Find files with bash shebang but no .sh extension
    while IFS= read -r -d '' file; do
        # Check for bash shebang
        if head -n1 "$file" | grep -q "^#!/bin/\(ba\)\?sh"; then
            # Don't duplicate .sh files
            if [[ "${file}" != *".sh" ]]; then
                all_scripts+=("$file")
            fi
        fi
    done < <(find "$PROJECT_ROOT" -type f -executable -not -path "*/\.*" -print0)
    
    # Return the array of scripts
    printf '%s\n' "${all_scripts[@]}"
}

# Main function
main() {
    local file_count=0
    local check_failed=false
    
    echo "=== Running ShellCheck Validation ==="
    echo "Immutablue Shell Script Linter"
    echo
    
    # Check if ShellCheck is installed
    check_shellcheck_installed
    
    # Get ShellCheck version
    SHELLCHECK_VERSION=$(shellcheck --version | grep version | awk '{print $3}')
    echo "Using ShellCheck version ${SHELLCHECK_VERSION}"
    echo
    
    # Find all shell scripts and run shellcheck on them
    echo "Scanning for shell scripts..."
    mapfile -t SHELL_SCRIPTS < <(find_shell_scripts)
    
    # Count files
    file_count=${#SHELL_SCRIPTS[@]}
    echo "Found ${file_count} shell scripts to check"
    echo
    
    # Loop through all shell scripts and check them
    for file in "${SHELL_SCRIPTS[@]}"; do
        if ! run_shellcheck "$file"; then
            check_failed=true
            EXIT_CODE=1
            
            # Try to fix if in fix mode
            if [[ "$FIX_MODE" == true ]]; then
                echo "Attempting to fix issues in ${file}..."
                # Simplify by just showing the issues that need manual fixes
                echo "ℹ The following issues need manual fixes:"
                shellcheck --severity=warning "${file}" | grep -E "^In.*line" | sed 's/^/  - /'
            fi
        fi
    done
    
    # Report results
    echo
    echo "=== ShellCheck Validation Results ==="
    echo "Files checked:    ${file_count}"
    echo "Files passed:     ${SUCCESS_COUNT}"
    echo "Files failed:     ${FAIL_COUNT}"
    echo "Files skipped:    ${SKIP_COUNT}"
    echo
    
    if [[ "$check_failed" == true ]]; then
        echo "❌ SOME CHECKS FAILED"
        echo
        echo "To see detailed information about these issues, run:"
        echo "  shellcheck --severity=warning path/to/failing/script.sh"
        echo
        echo "To learn more about specific error codes, visit:"
        echo "  https://github.com/koalaman/shellcheck/wiki/Checks"
        echo
        echo "To automatically fix some issues, run this test with --fix:"
        echo "  ./test_shellcheck.sh --fix"
        
        # If in report-only mode, always return success
        if [[ "$REPORT_ONLY" == true ]]; then
            echo
            echo "Running in report-only mode, exiting with success despite failures"
            EXIT_CODE=0
        fi
    else
        echo "✅ ALL CHECKS PASSED"
    fi
    
    return $EXIT_CODE
}

# Run the main function
main
