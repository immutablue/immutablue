#!/bin/bash
# Justfile Syntax Tests for Immutablue
#
# This script validates every justfile shipped in the image, the same way that
# test_shellcheck.sh validates every shell script.
#
# Why this exists: the justfiles are the entire user-facing command surface
# (`immutablue <verb>`), but nothing in the build parses them. `just` is not
# invoked at image build time, so a syntax error -- an unclosed interpolation,
# a bad import path, a recipe with inconsistent indentation -- does not fail
# the build. It fails on the installed system, the first time a user types the
# command, on an image that has already shipped.
#
# The check is a parse, not a format check: `just --summary` loads and
# evaluates the justfile's structure without running any recipe. Formatting
# (`just --fmt`) is deliberately not enforced, since that would flag existing
# style rather than real defects.
#
# It can be run directly or through the Makefile with 'make pre_test'.
#
# Usage: ./test_justfile_syntax.sh
#
# Return codes:
# - 0: All justfiles parsed (or just is unavailable and the test was skipped)
# - 1: One or more justfiles failed to parse

# Enable strict error handling
set -euo pipefail

echo "Testing Immutablue justfile syntax"

TEST_DIR="$(dirname "$(realpath "$0")")"
ROOT_DIR="$(dirname "$TEST_DIR")"
ARTIFACTS_DIR="${ROOT_DIR}/artifacts"

EXIT_CODE=0
PASS_COUNT=0
FAIL_COUNT=0

# Check that just is installed.
#
# Treated as a skip rather than a failure so the suite still runs on a machine
# that has not layered just; the CI image does have it.
function check_just_installed() {
    if ! command -v just &> /dev/null; then
        echo "WARN: 'just' is not installed, justfile syntax tests skipped"
        return 1
    fi

    echo "Using $(just --version)"
    return 0
}

# Parse a single justfile.
#
# --summary lists the recipes, which requires just to fully parse the file
# (and resolve any imports) but never executes a recipe body.
#
# --working-directory is pinned to the file's own directory so that relative
# `import` paths resolve exactly as they will on the installed system, where
# /usr/bin/immutablue cd's into /usr/libexec/immutablue/just before exec'ing
# just.
#
# param $1: path to the justfile to check
function check_justfile() {
    local justfile="$1"
    local justfile_dir
    local output

    justfile_dir="$(dirname "$(realpath "${justfile}")")"

    if output="$(just --justfile "${justfile}" \
                      --working-directory "${justfile_dir}" \
                      --summary 2>&1)"
    then
        echo "PASS: ${justfile#"${ROOT_DIR}"/}"
        PASS_COUNT=$((PASS_COUNT + 1))
        return 0
    fi

    echo "FAIL: ${justfile#"${ROOT_DIR}"/}"
    echo "${output}" | sed 's/^/      /'
    FAIL_COUNT=$((FAIL_COUNT + 1))
    return 1
}

if ! check_just_installed; then
    exit 0
fi

if [[ ! -d "${ARTIFACTS_DIR}" ]]; then
    echo "WARN: Missing artifacts directory, test skipped"
    exit 0
fi

# Collect every justfile under artifacts/, excluding the vendored source trees
# under /usr/src/gitlab -- those belong to the submodules and are their own
# projects' responsibility.
JUSTFILES=()
while IFS= read -r -d '' justfile
do
    JUSTFILES+=("${justfile}")
done < <(find "${ARTIFACTS_DIR}" \
              -path '*/usr/src/gitlab' -prune -o \
              \( -name '*.justfile' -o -name 'Justfile' -o -name 'justfile' \) \
              -type f -print0 | sort -z)

if [[ ${#JUSTFILES[@]} -eq 0 ]]; then
    echo "WARN: No justfiles found, test skipped"
    exit 0
fi

echo "Checking ${#JUSTFILES[@]} justfiles"

for justfile in "${JUSTFILES[@]}"
do
    # A root Justfile pulls in its siblings via `import`, so a failure in an
    # imported file is reported against both -- that is intentional, since it
    # shows whether the composed command surface is broken as well as which
    # file caused it.
    check_justfile "${justfile}" || EXIT_CODE=1
done

echo ""
echo "=== Justfile Syntax Test Summary ==="
echo "Passed: ${PASS_COUNT}"
echo "Failed: ${FAIL_COUNT}"

if [[ ${EXIT_CODE} -ne 0 ]]; then
    echo "RESULT: FAILED"
else
    echo "RESULT: PASSED"
fi

exit ${EXIT_CODE}
