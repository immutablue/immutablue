# Immutablue Testing

This directory contains tests for the Immutablue container image and related artifacts.

## Test Structure

The tests are organized into the following categories:

1. **Container Tests** (`test_container.sh`): Basic tests for the container image, including:
   - bootc lint functionality
   - Essential packages verification
   - Directory structure validation
   - Systemd services verification

2. **QEMU Container Tests** (`test_container_qemu.sh`): Advanced tests that use QEMU to boot the container image and verify its functionality.

3. **Artifacts Tests** (`test_artifacts.sh`): Tests to verify the structure and presence of essential files in the artifacts directory. This includes:
   - Directory structure validation
   - Verification that files in artifacts/overrides exist in the container
   - SHA256 checksum comparison between repo files and container files
   - Detailed reporting of file integrity

4. **ShellCheck Tests** (`test_shellcheck.sh`): Static analysis of shell scripts using ShellCheck to identify:
   - Common shell script bugs and issues
   - Best practices violations
   - Potential security vulnerabilities
   - Style inconsistencies

## Running Tests

You can run individual tests or all tests together using the Makefile targets:

```bash
# Run all tests
make test

# Run individual test categories
make test_container
make test_container_qemu
make test_artifacts
make test_shellcheck

# Run just the shell script linting
make lint_shell

# Run the shell script linting with auto-fix attempts
./tests/test_shellcheck.sh --fix

# Run the full test suite with detailed output
make run_all_tests
```

## Requirements

To run these tests, you need:

- bootc
- podman
- qemu (for the QEMU tests)
- KVM access (for the QEMU tests)
- shellcheck (for the shell script tests)

## Adding New Tests

When adding new tests:

1. Create a new test script in the `tests` directory
2. Add a corresponding target in the Makefile
3. Update the `run_tests.sh` script to include your new test
4. Add your test to the `test` target dependency list