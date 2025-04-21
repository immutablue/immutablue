+++
date = '2025-04-17T23:01:00-05:00'
draft = false
title = 'Testing'
+++

# Testing Immutablue

Immutablue includes a comprehensive set of unit tests to ensure the integrity and functionality of the container image and its components. This document outlines the testing framework, available tests, and how to extend the testing infrastructure.

## Testing Framework Overview

The testing framework is designed to verify four key aspects of Immutablue:

1. **Container Tests**: Basic verification of the container image's functionality and structure
2. **QEMU Tests**: Ensuring the container image can boot properly in a virtualized environment
3. **Artifacts Tests**: Validating that all files in the `artifacts/overrides` directory are correctly included in the container image and haven't been modified
4. **Pre-Build ShellCheck Tests**: Static analysis of all shell scripts to ensure code quality and catch potential bugs

The tests are configured to run automatically as part of the build process and can also be executed manually during development. ShellCheck tests run as pre-build tests to ensure code quality before the build process begins, while the other tests run after building the container.

## Running Tests

### Running All Tests

To run all tests:

```bash
make test
```

To run a more detailed test suite with comprehensive reporting:

```bash
make run_all_tests
```

### Skipping Tests

You can skip all tests, including pre-build tests, using the SKIP_TEST option:

```bash
# Skip tests during build
make build SKIP_TEST=1

# Skip tests when running test targets
make test SKIP_TEST=1
make run_all_tests SKIP_TEST=1
```

### Running Individual Test Categories

You can run specific test categories:

```bash
# Run pre-build ShellCheck tests
make pre_test

# Run only container tests
make test_container

# Run only QEMU boot tests
make test_container_qemu

# Run only artifacts tests
make test_artifacts
```

### Running Tests with Alternative Container Images

By default, the tests use the `quay.io/immutablue/immutablue:42` image. You can specify a different image by setting the `IMAGE` and `TAG` variables:

```bash
# Run tests against a different tag
make TAG=41 test

# Run tests against a different image and tag
make IMAGE=quay.io/myorg/immutablue TAG=custom test
```

## Test Structure

### Container Tests

The container tests (`test_container.sh`) verify:

- Basic container functionality via `bootc container lint`
- Presence of essential packages (`bash`, `systemd`, `make`)
- Directory structure (checking for critical directories)
- Systemd services installation and configuration

These tests ensure the fundamental aspects of the container are working correctly.

### QEMU Container Tests

The QEMU tests (`test_container_qemu.sh`) directly verify container bootability by:

- Exporting the container to a tarball
- Creating a minimal initramfs with busybox
- Booting the container in QEMU with the host's kernel
- Verifying critical Immutablue components and services
- Checking for required directories and systemd units

This provides a comprehensive validation that the container can actually boot and function correctly in a virtualized environment, which is a good proxy for real-world deployment.

The QEMU tests include an intelligent fallback mechanism:
- If QEMU or busybox is not available, it falls back to bootc container lint checks
- If bootc is also not available, it falls back to basic container structure checks
- This ensures tests can still run in environments without all dependencies

### Artifacts Tests

The artifacts tests (`test_artifacts.sh`) verify:

- The directory structure in the `artifacts/overrides` directory
- The presence of required system directories and files
- File integrity validation between the repository and the container

#### File Integrity Checking

One of the most important tests is the file integrity check, which:

1. Finds all files in the `artifacts/overrides` directory
2. Calculates SHA256 checksums for each file
3. Retrieves the corresponding file from the container image
4. Calculates the SHA256 checksum of the container file
5. Compares the checksums to ensure files haven't been modified

This ensures that all files specified in the repository are correctly included in the container and haven't been tampered with during the build process.

### ShellCheck Tests

The ShellCheck tests (`test_shellcheck.sh`) perform static analysis of all shell scripts in the project using the ShellCheck tool. This helps identify:

- Syntax errors and potential bugs
- Common shell script pitfalls and mistakes
- Security vulnerabilities and unsafe practices
- Style inconsistencies and non-portable constructs

#### How ShellCheck Testing Works

The ShellCheck test script:

1. Automatically finds all shell scripts in the project by:
   - Searching for files with `.sh` extension
   - Finding executable files with a bash shebang (`#!/bin/bash`)
   
2. Runs ShellCheck on each script with carefully selected rules:
   - Uses bash as the shell dialect
   - Focuses on warnings and errors (ignores style/info by default)
   - Enables relevant optional checks
   - Excludes specific checks that aren't applicable to the project
   
3. Provides detailed output for any issues found:
   - Line numbers and code context
   - Clear explanation of the problem
   - Suggested fix or best practice reference
   
4. Summarizes test results:
   - Count of files checked
   - Number of files that passed/failed
   - Exit code based on overall success

#### Auto-Fix Mode

The ShellCheck tests include several useful modes:

```bash
# Run ShellCheck tests normally
./tests/test_shellcheck.sh

# Run ShellCheck tests with auto-fix attempts
./tests/test_shellcheck.sh --fix

# Run ShellCheck tests in report-only mode (always exits with success)
./tests/test_shellcheck.sh --report-only
```

The `--fix` mode provides detailed diagnostic information:
1. Identifies issues in a shell script
2. Displays specific information about each issue
3. Highlights the lines that need manual fixes
4. Shows error codes that can be looked up for more information

This mode helps address common issues like:
- Double vs. single bracket usage
- Quoting variables
- Removing unnecessary cat usage
- Fixing common command substitution issues

The `--report-only` mode is useful for CI/CD integration:
1. Runs all checks and reports issues
2. Always exits with success (0) even if issues are found
3. Allows gradual adoption of ShellCheck without breaking existing builds

#### ShellCheck Configuration

The project includes a `.shellcheckrc` configuration file in the root directory that:

- Specifies bash as the primary shell dialect
- Sets search paths for sourced files
- Disables certain checks that aren't appropriate for this project
- Configures external source handling

This configuration ensures that ShellCheck validates scripts according to project-specific standards and requirements.

## Extending the Test Suite

### Adding New Container Tests

To add new container tests:

1. Open `tests/test_container.sh`
2. Add a new test function following the existing pattern:
   ```bash
   function test_new_feature() {
     echo "Testing new feature"
     
     # Run test command
     if ! podman run --rm "$IMAGE" command_to_test; then
       echo "FAIL: New feature test failed"
       return 1
     fi
     
     echo "PASS: New feature test passed"
     return 0
   }
   ```
3. Add your test function to the test runner section:
   ```bash
   if ! test_new_feature; then
     ((FAILED++))
   fi
   ```

### Adding New QEMU Tests

To add new QEMU-based tests:

1. Open `tests/test_container_qemu.sh`
2. Add a new test function that verifies boot-related or hardware-related functionality
3. Add your test to the runner section like with container tests

### Adding New Artifacts Tests

To add new artifact validation tests:

1. Open `tests/test_artifacts.sh`
2. Add a new test function that verifies specific directory structures or file content
3. Add your test to the runner section

### Adding Test Documentation

When adding new tests, be sure to:

1. Update this documentation page with details about the new tests
2. Add comprehensive comments to your test functions
3. Update the README.md in the tests directory

## Continuous Integration

The test suite is designed to be integrated into CI/CD pipelines. When setting up CI for Immutablue, make sure to:

1. Run `make test` as part of your pipeline
2. Ensure the build environment has access to podman and bootc
3. Set up appropriate error handling for test failures

## Test File Organization

The test files are organized as follows:

- `tests/test_container.sh`: Container tests
- `tests/test_container_qemu.sh`: QEMU-based tests
- `tests/test_artifacts.sh`: Artifacts and file integrity tests
- `tests/test_shellcheck.sh`: ShellCheck static analysis tests
- `tests/run_tests.sh`: Master test runner script
- `tests/README.md`: Test documentation for developers
- `.shellcheckrc`: ShellCheck configuration file (in project root)

## Future Improvements

Future improvements to the testing framework could include:

1. **Integration Testing**: Testing the interaction between multiple components
2. **Performance Testing**: Benchmarking container startup times and resource usage
3. **Security Testing**: Scanning for CVEs and security vulnerabilities
4. **Automated UI Testing**: For desktop environments included in the container
5. **Extended QEMU Testing**: Further enhance the QEMU tests to:
   - Boot with UEFI instead of direct kernel boot
   - Test with multiple architectures (aarch64, etc.)
   - Validate more specific functionality after boot
6. **Enhanced Shell Script Testing**:
   - Integration with pre-commit hooks for git
   - Expanded coverage for more script types
   - Custom rules for Immutablue-specific conventions

## Troubleshooting

### Common Issues

- **Image Not Found**: Ensure the container image exists and is properly tagged
- **Missing bootc**: Install bootc with `dnf install bootc`
- **Permission Issues**: Ensure podman can be run without sudo
- **Missing KVM**: For full QEMU tests, KVM needs to be available
- **QEMU Test Failures**: The QEMU tests require:
  - QEMU installed with `dnf install qemu-system-x86`
  - Busybox installed with `dnf install busybox`
  - A working kernel with appropriate modules
  - Access to create temporary files and launch QEMU processes
- **ShellCheck Not Found**: Install ShellCheck with `dnf install ShellCheck`
- **ShellCheck Failures**: Common causes of ShellCheck failures:
  - Single brackets `[ ]` instead of double brackets `[[ ]]`
  - Unquoted variables that should be quoted
  - Unsafe command substitution without quoting
  - Missing error handling in scripts

### Debugging Tests

To debug test failures:

1. Run individual test scripts directly
2. Add `set -x` to the test scripts to enable verbose output
3. Check container logs with `podman logs`
4. Inspect the container interactively with `podman run --rm -it $IMAGE /bin/bash`
5. For QEMU test failures:
   - Modify the QEMU test script to preserve temporary files (`rm -rf "$TEMP_DIR"` → `echo "Temp files at: $TEMP_DIR"`)
   - Examine the QEMU log and container tar file in the temporary directory
   - Try running QEMU manually with the generated files
   - Adjust timeouts and memory settings if needed
6. For ShellCheck failures:
   - Run ShellCheck directly on the failing script: `shellcheck scripts/failing_script.sh`
   - Use the `--format=json` option to get detailed information: `shellcheck --format=json scripts/failing_script.sh`
   - Try the auto-fix mode: `./tests/test_shellcheck.sh --fix`
   - Check the ShellCheck wiki for information on specific error codes: `https://github.com/koalaman/shellcheck/wiki/SC####` (replace #### with the error code)

## Conclusion

The Immutablue testing framework provides a robust mechanism for ensuring the quality and integrity of the container image. By following the patterns established in the existing tests, developers can extend the test suite to cover new functionality and edge cases, ensuring that Immutablue remains stable and reliable for users.