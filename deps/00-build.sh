#!/bin/bash
# deps/00-build.sh
#
# Build script for Immutablue dependency builder container.
# Builds all third-party tools and custom C projects that ship in the
# final image.
#
# This script is called from deps/Containerfile and runs inside a
# Fedora container. All output goes to /build/ which is later consumed
# by build/10-copy.sh via the /mnt-build-deps mount.
#
# Source trees for custom C projects (yaml-glib, crispy, gst, gowl)
# are COPY'd into /build/ by the Containerfile from the git submodules
# at artifacts/overrides/usr/src/gitlab/.
#
# To add a new dependency:
#   1. Write a build_<name> function below
#   2. Add the name to the BUILDS array
#   3. If it has source in a submodule, add COPY to deps/Containerfile
#   4. Add corresponding cp section in build/10-copy.sh

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

	# build tools (yaml-glib/crispy/gst/gowl)
	make
	pkgconf-pkg-config

	# glib/gobject (all four C projects)
	glib2-devel

	# yaml-glib + gst: YAML + JSON
	libyaml-devel
	json-glib-devel

	# gst: X11 rendering
	libX11-devel
	libXft-devel
	fontconfig-devel

	# gst: wayland backend
	wayland-devel
	libxkbcommon-devel
	cairo-devel
	libdecor-devel

	# gowl: wayland compositor
	wayland-protocols-devel
	wlroots-devel
	libinput-devel
	libxcb-devel
	xcb-util-wm-devel
	libdrm-devel
	pixman-devel
	pango-devel
)


# ============================================================================
# BUILD REGISTRY
# ============================================================================
# Each entry corresponds to a build_<name> function below.
# Order matters: yaml_glib must come before gst/gowl (they link against it).
# cpak: add here when ready (Go project, https://github.com/Containerpak/cpak)
BUILDS=(
	blue2go
	cigar
	zapper
	yaml_glib
	crispy
	gst
	gowl
)


# ============================================================================
# BUILD FUNCTIONS
# ============================================================================
# Each function is self-contained: clone/build/install and any post-processing.
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

# yaml-glib -- GObject YAML parser/builder library
# Produces: libyaml-glib.so.1.0.0, headers
# Dependency for: gst, gowl, and future tools
# Source: /build/yaml-glib (COPY'd from submodule)
build_yaml_glib () {
	local src_dir="${BUILD_DIR}/yaml-glib"
	local stage_dir="${BUILD_DIR}/yaml-glib"

	if [[ ! -d "${src_dir}/src" ]]; then
		echo "ERROR: yaml-glib source not found at ${src_dir}"
		echo "Ensure submodules are initialized: git submodule update --init --recursive"
		exit 1
	fi

	mkdir -p "${stage_dir}"
	cd "${src_dir}"

	# Fedora uses lib64 for 64-bit libs; yaml-glib defaults to lib
	local libdir="lib"
	if [[ -d /usr/lib64 ]]; then
		libdir="lib64"
	fi

	make all PREFIX=/usr
	make install PREFIX=/usr LIBDIR="/usr/${libdir}" DESTDIR="${stage_dir}"

	# Also install to the deps container itself so gst/gowl can link against it
	make install PREFIX=/usr LIBDIR="/usr/${libdir}"
	ldconfig
}

# crispy -- C script compiler/runner (GLib/GObject project)
# Produces: crispy binary, libcrispy.so.0.1.0, headers, pkg-config
# Source: /build/crispy (COPY'd from submodule)
build_crispy () {
	local src_dir="${BUILD_DIR}/crispy"
	local stage_dir="${BUILD_DIR}/crispy"

	if [[ ! -d "${src_dir}/src" ]]; then
		echo "ERROR: crispy source not found at ${src_dir}"
		echo "Ensure submodules are initialized: git submodule update --init --recursive"
		exit 1
	fi

	mkdir -p "${stage_dir}"
	cd "${src_dir}"
	make DEBUG=1 all PREFIX=/usr
	make DEBUG=1 install PREFIX=/usr DESTDIR="${stage_dir}"
}

# gst -- GObject Simple Terminal (terminal emulator)
# Produces: gst binary, libgst.so.0.1.0, module .so files, headers, pkg-config
# Source: /build/gst (COPY'd from submodule)
build_gst () {
	local src_dir="${BUILD_DIR}/gst"
	local stage_dir="${BUILD_DIR}/gst"

	if [[ ! -d "${src_dir}/src" ]]; then
		echo "ERROR: gst source not found at ${src_dir}"
		echo "Ensure submodules are initialized: git submodule update --init --recursive"
		exit 1
	fi

	mkdir -p "${stage_dir}"
	cd "${src_dir}"
	make DEBUG=1 all PREFIX=/usr BUILD_MODULES=1 BUILD_WAYLAND=1 BUILD_GIR=0
	make DEBUG=1 install PREFIX=/usr DESTDIR="${stage_dir}" BUILD_MODULES=1 BUILD_WAYLAND=1 BUILD_GIR=0
}

# gowl -- GObject Wayland Compositor
# Produces: gowl binary, gowlbar binary, libgowl.so.0.1.0, module .so files,
#           headers, pkg-config, desktop session file, icons, configs
# Source: /build/gowl (COPY'd from submodule)
build_gowl () {
	local src_dir="${BUILD_DIR}/gowl"
	local stage_dir="${BUILD_DIR}/gowl"

	if [[ ! -d "${src_dir}/src" ]]; then
		echo "ERROR: gowl source not found at ${src_dir}"
		echo "Ensure submodules are initialized: git submodule update --init --recursive"
		exit 1
	fi

	mkdir -p "${stage_dir}"
	cd "${src_dir}"
	make DEBUG=1 all PREFIX=/usr BUILD_MODULES=1 BUILD_GIR=0 BUILD_XWAYLAND=1
	make DEBUG=1 install PREFIX=/usr DESTDIR="${stage_dir}" BUILD_MODULES=1 BUILD_GIR=0 BUILD_XWAYLAND=1
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
