#!/bin/bash
# Immutablue Shell Script Validation
#
# This script uses shellcheck to validate all shell scripts in the Immutablue project.
# It checks for common shell script issues, best practices, and potential bugs.
#
# Usage: ./test_shellcheck.sh [--fix] [--report-only]
#
# Options:
#   --fix          Highlight issues that need manual fixing and provide detailed diagnostics
#                  This does NOT automatically fix issues, but provides guidance for manual fixes
#   --report-only  Report issues but always exit with success code (useful for CI/CD integration)
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
            echo "  --fix          Display detailed information about issues that need manual fixes"
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

# Function to find all shell scripts in the project
find_shell_scripts() {
    local all_scripts=()
    
    # Find all .sh files
    while IFS= read -r -d '' file; do
        all_scripts+=("$file")
    done < <(find "$PROJECT_ROOT" -type f -name "*.sh" -not -path "*/\.*" -not -path "*/usr/src/*" -print0)

    # Find files with bash shebang but no .sh extension
    while IFS= read -r -d '' file; do
        # Check for bash shebang
        if head -n1 "$file" | grep -q "^#!/bin/\(ba\)\?sh"; then
            # Don't duplicate .sh files
            if [[ "${file}" != *".sh" ]]; then
                all_scripts+=("$file")
            fi
        fi
    done < <(find "$PROJECT_ROOT" -type f -executable -not -path "*/\.*" -not -path "*/usr/src/*" -print0)
    
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
    
    # Detect which parallel is available (if any) for concurrent checking
    # GNU parallel: `parallel cmd {} ::: args`
    # moreutils parallel: `parallel cmd -- args`
    local parallel_mode="none"
    if command -v parallel &>/dev/null; then
        if parallel --version 2>&1 | grep -q "GNU parallel"; then
            parallel_mode="gnu"
        else
            parallel_mode="moreutils"
        fi
    fi

    # Run shellcheck: parallel if available, batch mode as fallback
    # All modes are faster than per-file sequential invocation
    if [[ "$parallel_mode" == "gnu" ]]; then
        echo "Running shellcheck on ${file_count} files (GNU parallel)..."
        echo
        if printf '%s\n' "${SHELL_SCRIPTS[@]}" | \
            parallel --halt soon,fail=1 shellcheck "${SHELLCHECK_OPTS[@]}" {}; then
            SUCCESS_COUNT="${file_count}"
        else
            check_failed=true
            EXIT_CODE=1
        fi
    elif [[ "$parallel_mode" == "moreutils" ]]; then
        echo "Running shellcheck on ${file_count} files (moreutils parallel)..."
        echo
        if parallel shellcheck "${SHELLCHECK_OPTS[@]}" -- "${SHELL_SCRIPTS[@]}"; then
            SUCCESS_COUNT="${file_count}"
        else
            check_failed=true
            EXIT_CODE=1
        fi
    else
        echo "Running shellcheck on ${file_count} files (batch mode)..."
        echo
        if shellcheck "${SHELLCHECK_OPTS[@]}" "${SHELL_SCRIPTS[@]}"; then
            SUCCESS_COUNT="${file_count}"
        else
            check_failed=true
            EXIT_CODE=1
        fi
    fi

    # In fix mode with failures, re-run per-file to identify which ones failed
    if [[ "$check_failed" == true && "$FIX_MODE" == true ]]; then
        echo
        echo "Re-checking individually to identify failing files..."
        for file in "${SHELL_SCRIPTS[@]}"; do
            local relative_path="${file#"$PROJECT_ROOT"/}"
            if shellcheck "${SHELLCHECK_OPTS[@]}" "$file" >/dev/null 2>&1; then
                ((SUCCESS_COUNT++))
            else
                ((FAIL_COUNT++))
                echo "FAIL: ${relative_path}"
                shellcheck --severity=warning "$file" | grep -E "^In.*line" | sed 's/^/  - /'
            fi
        done
    fi

    # Report results
    echo
    echo "=== ShellCheck Validation Results ==="
    echo "Files checked:    ${file_count}"
    if [[ "$check_failed" == true && "$FIX_MODE" == true ]]; then
        echo "Files passed:     ${SUCCESS_COUNT}"
        echo "Files failed:     ${FAIL_COUNT}"
    fi
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
