#!/bin/bash
# deps/00-build.sh
#
# Build script for Immutablue dependency builder container.
# Clones and builds all third-party tools that ship in the final image.
#
# This script is called from deps/Containerfile and runs inside a
# Fedora container. All output goes to /build/ which is later consumed
# by build/10-copy.sh via the /mnt-build-deps mount.
#
# To add a new dependency:
#   1. Write a build_<name> function that clones, builds, etc.
#   2. Add the name to the BUILDS array
#   3. Add corresponding cp line in build/10-copy.sh

set -euxo pipefail

BUILD_DIR="/build"

# ============================================================================
# PACKAGES
# ============================================================================
# DNF packages required for building dependencies.
# golang is included for future use (cpak) even though current deps don't need it.
PACKAGES=(
	git
	golang
	gcc
	glibc-static
)


# ============================================================================
# BUILD REGISTRY
# ============================================================================
# Each entry corresponds to a build_<name> function below.
# cpak: add here when ready (Go project, https://github.com/Containerpak/cpak)
BUILDS=(
	blue2go
	cigar
	zapper
    crispy
)


# ============================================================================
# BUILD FUNCTIONS
# ============================================================================
# Each function is self-contained: clone, build, and any post-processing.
# The function name MUST match the BUILDS entry: build_<name>

# blue2go -- Immutablue installer tool for bootc images (bash script)
build_blue2go () {
	git clone https://gitlab.com/immutablue/blue2go.git "${BUILD_DIR}/blue2go"
}

# cigar -- simple CI pipeline runner (bash script)
build_cigar () {
	git clone https://gitlab.com/immutablue/cigar.git "${BUILD_DIR}/cigar"
}

# zapper -- process argv/env cleaner (C project, compiled with make)
build_zapper () {
	git clone https://github.com/hackerschoice/zapper "${BUILD_DIR}/zapper"
	cd "${BUILD_DIR}/zapper" && make all
}

# cripsy 
build_crispy () {
    git clone https://gitlab.com/zachpodbielniak/crispy "${BUILD_DIR}/crispy"
    cd "${BUILD_DIR}/crispy" && make install-deps && make all install
}

# ============================================================================
# INFRASTRUCTURE
# ============================================================================

configure_dnf () {
	echo "=== Configuring dnf ==="
	echo -e 'max_parallel_downloads=10\n' >> /etc/dnf/dnf.conf
}

install_build_deps () {
	echo "=== Installing build dependencies ==="
	dnf5 update -y
	dnf5 install -y "${PACKAGES[@]}"
}


# ============================================================================
# MAIN
# ============================================================================

main () {
	configure_dnf
	install_build_deps
	mkdir -p "${BUILD_DIR}"

	for name in "${BUILDS[@]}"
	do
		echo "=== Building: ${name} ==="
		"build_${name}"
	done

	echo "=== All dependencies built successfully ==="
}

main
