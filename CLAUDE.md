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

## Kuberblue Variant
- **Building**: Kuberblue must be built with `KUBERBLUE=1` flag to include Kubernetes packages
- `make KUBERBLUE=1 build`: Build Kuberblue container image with Kubernetes packages
- **Testing**: Kuberblue test targets automatically default to `KUBERBLUE=1`
- `make test_kuberblue_container`: Test Kuberblue container image validation
- `make test_kuberblue_components`: Test Kuberblue components and scripts
- `make test_kuberblue_security`: Test Kuberblue security configurations
- `make test_kuberblue_cluster`: Test Kubernetes cluster functionality (requires VM)
- `make test_kuberblue_integration`: Test end-to-end integration scenarios (requires cluster)
- `make test_kuberblue_chainsaw`: Run declarative Chainsaw tests for Kuberblue
- `make test_kuberblue`: Run complete Kuberblue test suite
- `KUBERBLUE_CLUSTER_TEST=1 make test_kuberblue`: Enable cluster testing
- `KUBERBLUE_INTEGRATION_TEST=1 make test_kuberblue`: Enable integration testing
- Image name pattern: `quay.io/immutablue/immutablue:42-kuberblue` (when KUBERBLUE=1)

## Chainsaw Testing
- **Declarative tests**: Co-located YAML tests alongside manifests
- `make test_kuberblue_chainsaw`: Run all Chainsaw tests
- `make test_chainsaw`: Convenience target for Chainsaw-only testing
- Test naming: `{component}_test.yaml` (e.g., `cilium_test.yaml`)
- Test discovery: Automatic discovery of `*_test.yaml` files
- Required annotations: `kuberblue.test/component`, `kuberblue.test/category`
- Categories: networking, storage, compute, security
- Location: Tests co-located with manifests in `/etc/kuberblue/manifests/`

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