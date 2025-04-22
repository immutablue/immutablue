# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands
- `make build`: Build the Immutablue container image
- `make test`: Run all post-build tests
- `make pre_test`: Run shellcheck validation on shell scripts
- `./tests/test_shellcheck.sh`: Validate shell scripts with detailed output
- `./tests/test_shellcheck.sh --fix`: Show detailed diagnostics for issues
- `./tests/run_tests.sh`: Run all tests with detailed output
- Run a single test: `./tests/test_shellcheck.sh`, `./tests/test_container.sh`
- Skip tests: Add `SKIP_TEST=1` parameter (e.g., `make build SKIP_TEST=1`)

## Code Style Guidelines
- **Shell Scripts**:
  - Use `#!/bin/bash` shebang line
  - Follow strict error handling with `set -euo pipefail`
  - Use shellcheck with strict settings (`--severity=warning --enable=all`)
  - Use proper function documentation and meaningful variable names
  - Explicitly declare local variables in functions
  - Boolean returns use `TRUE=1` and `FALSE=0` constants
  - Follow existing file and directory structure conventions
  - Ensure proper error reporting and exit codes