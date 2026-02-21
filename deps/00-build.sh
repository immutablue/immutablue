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
# Source trees for custom C projects (yaml-glib, crispy, gst, gowl,
# mcp-glib, mcp-gdb-glib, ai-glib) are COPY'd into /build/ by the
# Containerfile from the git submodules at artifacts/overrides/usr/src/gitlab/.
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

	# build tools (yaml-glib/crispy/g/st/gowl)
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
	gdk-pixbuf2-devel
	pam-devel

	# mcp-glib: MCP protocol library
	libsoup3-devel
	libdex-devel
	readline-devel

	# nerd-fonts: extraction
	xz
)


# ============================================================================
# BUILD REGISTRY
# ============================================================================
# Each entry corresponds to a build_<name> function below.
# Order matters: yaml_glib must come before gst/gowl (they link against it).
# mcp_glib must come before mcp_gdb_glib (it links against it).
# cpak: add here when ready (Go project, https://github.com/Containerpak/cpak)
BUILDS=(
	blue2go
	cigar
	zapper
	nerd_fonts
	yaml_glib
	crispy
	gst
	gowl
	mcp_glib
	mcp_gdb_glib
	ai_glib
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

# nerd-fonts -- Nerd Font patched versions of FiraCode, FiraMono, and Hack
# Downloads .tar.xz archives from GitHub releases, extracts .ttf files
# Produces: /usr/share/fonts/nerd-fonts/{FiraCode,FiraMono,Hack}/*.ttf
build_nerd_fonts () {
	local stage_dir="${BUILD_DIR}/nerd_fonts/usr/share/fonts/nerd-fonts"
	local base_url="https://github.com/ryanoasis/nerd-fonts/releases/latest/download"
	local fonts=(FiraCode FiraMono Hack)

	mkdir -p "${stage_dir}"

	for font in "${fonts[@]}"
	do
		echo "--- Downloading ${font} Nerd Font ---"
		mkdir -p "${stage_dir}/${font}"
		curl -fsSL "${base_url}/${font}.tar.xz" | tar -xJ -C "${stage_dir}/${font}"

		# Keep only .ttf files, remove READMEs/licenses
		find "${stage_dir}/${font}" -type f ! -name '*.ttf' -delete
	done
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
	make DEBUG=1 MCP=1 all PREFIX=/usr BUILD_MODULES=1 BUILD_WAYLAND=1 BUILD_GIR=0
	make DEBUG=1 MCP=1 install PREFIX=/usr DESTDIR="${stage_dir}" BUILD_MODULES=1 BUILD_WAYLAND=1 BUILD_GIR=0
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
	make DEBUG=1 MCP=1 all PREFIX=/usr BUILD_MODULES=1 BUILD_GIR=0 BUILD_XWAYLAND=1
	make DEBUG=1 MCP=1 install PREFIX=/usr DESTDIR="${stage_dir}" BUILD_MODULES=1 BUILD_GIR=0 BUILD_XWAYLAND=1

	# Install PAM config for screenlock module (/etc/pam.d/gowl)
	if [[ -f "${src_dir}/data/gowl-screenlock.pam" ]]; then
		install -d "${stage_dir}/etc/pam.d"
		install -m 644 "${src_dir}/data/gowl-screenlock.pam" "${stage_dir}/etc/pam.d/gowl"
	fi
}


# mcp-glib -- GObject MCP (Model Context Protocol) library
# Produces: libmcp-glib-1.0.so, headers, pkg-config, CLI tools
#           (mcp-inspect, mcp-call, mcp-read, mcp-prompt, mcp-shell)
# Dependency for: mcp-gdb-glib
# Source: /build/mcp-glib (COPY'd from submodule)
build_mcp_glib () {
	local src_dir="${BUILD_DIR}/mcp-glib"
	local stage_dir="${BUILD_DIR}/mcp-glib"

	if [[ ! -d "${src_dir}/src" ]]; then
		echo "ERROR: mcp-glib source not found at ${src_dir}"
		echo "Ensure submodules are initialized: git submodule update --init --recursive"
		exit 1
	fi

	mkdir -p "${stage_dir}"
	cd "${src_dir}"

	# Fedora uses lib64 for 64-bit libs; mcp-glib defaults to lib
	local libdir="lib"
	if [[ -d /usr/lib64 ]]; then
		libdir="lib64"
	fi

	make DEBUG=1 all PREFIX=/usr LIBDIR="/usr/${libdir}"
	make DEBUG=1 install PREFIX=/usr LIBDIR="/usr/${libdir}" DESTDIR="${stage_dir}"

	# Also install to the deps container itself so mcp-gdb-glib can link against it
	make DEBUG=1 install PREFIX=/usr LIBDIR="/usr/${libdir}"
	ldconfig
}

# mcp-gdb-glib -- GDB MCP server (uses mcp-glib for protocol handling)
# Produces: gdb-mcp-server binary
# Source: /build/mcp-gdb-glib (COPY'd from submodule)
build_mcp_gdb_glib () {
	local src_dir="${BUILD_DIR}/mcp-gdb-glib"
	local stage_dir="${BUILD_DIR}/mcp-gdb-glib"

	if [[ ! -d "${src_dir}/src" ]]; then
		echo "ERROR: mcp-gdb-glib source not found at ${src_dir}"
		echo "Ensure submodules are initialized: git submodule update --init --recursive"
		exit 1
	fi

	mkdir -p "${stage_dir}"
	cd "${src_dir}"

	# mcp-glib is already built and installed to the container root
	# by build_mcp_glib(). Use pkg-config to link against the system-installed
	# version instead of rebuilding the nested submodule.
	make DEBUG=1 build/gdb-mcp-server \
		MCP_GLIB_CFLAGS="$(pkg-config --cflags mcp-glib-1.0)" \
		MCP_GLIB_LIBS="$(pkg-config --libs mcp-glib-1.0)"

	# Manual install to /usr/bin (Makefile hardcodes /usr/local/bin)
	install -d "${stage_dir}/usr/bin"
	install -m 755 build/gdb-mcp-server "${stage_dir}/usr/bin/"
}


# ai-glib -- GObject AI provider library (Claude, OpenAI, Gemini, Grok, Ollama)
# Produces: libai-glib-1.0.so, headers, pkg-config
# Source: /build/ai-glib (COPY'd from submodule)
build_ai_glib () {
	local src_dir="${BUILD_DIR}/ai-glib"
	local stage_dir="${BUILD_DIR}/ai-glib"

	if [[ ! -d "${src_dir}/src" ]]; then
		echo "ERROR: ai-glib source not found at ${src_dir}"
		echo "Ensure submodules are initialized: git submodule update --init --recursive"
		exit 1
	fi

	mkdir -p "${stage_dir}"
	cd "${src_dir}"

	# Fedora uses lib64 for 64-bit libs; ai-glib defaults to lib
	local libdir="lib"
	if [[ -d /usr/lib64 ]]; then
		libdir="lib64"
	fi

	make DEBUG=1 all PREFIX=/usr LIBDIR="/usr/${libdir}"
	make DEBUG=1 install PREFIX=/usr LIBDIR="/usr/${libdir}" DESTDIR="${stage_dir}"
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
