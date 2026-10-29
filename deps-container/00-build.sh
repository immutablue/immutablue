#!/bin/bash
# deps-container/00-build.sh
#
# Build script for Immutablue dependency builder container.
# Builds all third-party tools and custom C projects that ship in the
# final image.
#
# This script is called from backends/<backend>/deps.Containerfile and runs
# inside that backend's build container. All output goes to /build/ which is later consumed
# by build/10-copy.sh via the /mnt-build-deps mount.
#
# Source trees for custom C projects (yaml-glib, crispy, gst, gsurf, gowl,
# mcp-glib, mcp-gdb-glib, ai-glib) are COPY'd into /build/ by the
# Containerfile from the git submodules at artifacts/overrides/usr/src/gitlab/.
#
# To add a new dependency:
#   1. Write a build_<name> function below
#   2. Add the name to the BUILDS array
#   3. If it has source in a submodule, add COPY to every
#      backends/<backend>/deps.Containerfile
#   4. Add corresponding cp section in build/10-copy.sh

set -euxo pipefail

BUILD_DIR="/build"

# ============================================================================
# PACKAGES
# ============================================================================
# The packages required to build the dependencies live in packages.yaml under
# 'build_deps', as logical entries resolved for the backend this container is
# built for (IMMUTABLUE_BACKEND). The Containerfile copies packages.yaml,
# build/99-common.sh and backends/ to IMMUTABLUE_SRC so the same library the
# image build uses resolves them here.
IMMUTABLUE_SRC="${IMMUTABLUE_SRC:-/tmp/immutablue}"


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
	gsurf
	gowl
	mcp_glib
	mcp_gdb_glib
	ai_glib
	podomation
	bacon
	mcp_kuberblue_glib
)


# ============================================================================
# NETWORK RETRY
# ============================================================================
# Every network fetch below goes through retry_with_backoff. A transient
# failure -- a DNS hiccup, a forge briefly refusing a clone, a CDN dropping a
# connection -- otherwise kills the whole dependency build, which is expensive:
# it compiles a dozen C projects from source.
#
# Unlike the image build (see build/99-common.sh, which wraps curl alone) this
# wraps arbitrary commands, because the fetches here are a mix of curl and
# git clone.
#
# DEPS_FETCH_RETRIES is the number of retries *after* the first attempt, so the
# default of 5 allows up to 6 attempts; 0 disables retrying. DEPS_FETCH_BASE_DELAY
# is the first backoff in seconds and doubles on each failure, giving
# 1, 2, 4, 8, 16. Both can be overridden from the environment.
DEPS_FETCH_RETRIES="${DEPS_FETCH_RETRIES:-5}"
DEPS_FETCH_BASE_DELAY="${DEPS_FETCH_BASE_DELAY:-1}"


# Run a command, retrying with exponential backoff on failure.
#
# The command is re-executed from scratch on each attempt rather than relying
# on whatever retry the tool has of its own. curl resolves a host once and
# reuses that result for the lifetime of the invocation, so its --retry keeps
# repeating the same answer when the failure IS the name resolution;
# re-executing forces a fresh lookup. git clone has no retry at all.
#
# The command must be safe to re-run -- see clone_repo() for the case where it
# is not.
#
# param $@: the command and its arguments
# returns: 0 on success, otherwise the command's status from the final attempt
retry_with_backoff () {
	local attempts=$(( DEPS_FETCH_RETRIES + 1 ))
	local attempt=1
	local delay="${DEPS_FETCH_BASE_DELAY}"
	local rc

	while true
	do
		# '|| rc=$?' rather than an if-condition: a failed 'if' with no else
		# yields status 0, which would swallow the real exit code.
		rc=0
		"$@" || rc=$?

		if [[ ${rc} -eq 0 ]]
		then
			return 0
		fi

		if [[ ${attempt} -ge ${attempts} ]]
		then
			echo "ERROR: '$*' failed after ${attempts} attempt(s), last exit ${rc}" >&2
			return "${rc}"
		fi

		echo "WARNING: '$*' attempt ${attempt}/${attempts} failed (exit ${rc}); retrying in ${delay}s" >&2
		sleep "${delay}"
		delay=$(( delay * 2 ))
		attempt=$(( attempt + 1 ))
	done
}


# One clone attempt, clearing the destination first.
#
# git clone refuses to write into a directory that exists and is non-empty, so
# a retry after a partly-completed clone would fail permanently with "already
# exists" -- an error that has nothing to do with what actually went wrong.
#
# param $1: repository URL
# param $2: destination directory
clone_repo_attempt () {
	rm -rf "${2}"
	git clone "${1}" "${2}"
}


# Clone a repository, retrying with exponential backoff.
#
# param $1: repository URL
# param $2: destination directory
clone_repo () {
	retry_with_backoff clone_repo_attempt "${1}" "${2}"
}


# ============================================================================
# BUILD FUNCTIONS
# ============================================================================
# Each function is self-contained: clone/build/install and any post-processing.
# The function name MUST match the BUILDS entry: build_<name>

# blue2go -- Immutablue installer tool for bootc images (bash script)
build_blue2go () {
	clone_repo https://gitlab.com/immutablue/blue2go.git "${BUILD_DIR}/blue2go"
}

# cigar -- simple CI pipeline runner (bash script)
build_cigar () {
	clone_repo https://gitlab.com/immutablue/cigar.git "${BUILD_DIR}/cigar"
}

# zapper -- process argv/env cleaner (C project, compiled with make)
build_zapper () {
	clone_repo https://github.com/hackerschoice/zapper "${BUILD_DIR}/zapper"
	cd "${BUILD_DIR}/zapper" && make all
}

# nerd-fonts -- Nerd Font patched versions of FiraCode, FiraMono, and Hack
# Downloads .tar.xz archives from GitHub releases, extracts .ttf files
# Produces: /usr/share/fonts/nerd-fonts/{FiraCode,FiraMono,Hack}/*.ttf
build_nerd_fonts () {
	local stage_dir="${BUILD_DIR}/nerd_fonts${DEPS_PREFIX}/share/fonts/nerd-fonts"
	local base_url="https://github.com/ryanoasis/nerd-fonts/releases/latest/download"
	local fonts=(FiraCode FiraMono Hack)
	local archive

	mkdir -p "${stage_dir}"

	for font in "${fonts[@]}"
	do
		echo "--- Downloading ${font} Nerd Font ---"
		mkdir -p "${stage_dir}/${font}"

		# Downloaded to a file rather than piped into tar: a retry
		# part-way through a pipe would hand tar a second, overlapping
		# stream on top of the bytes it already read.
		archive="/tmp/${font}.tar.xz"
		retry_with_backoff curl -fsSLo "${archive}" "${base_url}/${font}.tar.xz"
		tar -xJf "${archive}" -C "${stage_dir}/${font}"
		rm -f "${archive}"

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
	local libdir
	libdir="$(immutablue_libdir)"

	make DEBUG=1 all PREFIX="${DEPS_PREFIX}"
	make DEBUG=1 install PREFIX="${DEPS_PREFIX}" LIBDIR="${DEPS_PREFIX}/${libdir}" DESTDIR="${stage_dir}"

	# Also install to the deps container itself so gst/gowl can link against it
	make DEBUG=1 install PREFIX="${DEPS_PREFIX}" LIBDIR="${DEPS_PREFIX}/${libdir}"
	deps_ldconfig
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
	make DEBUG=1 all PREFIX="${DEPS_PREFIX}"
	make DEBUG=1 install PREFIX="${DEPS_PREFIX}" DESTDIR="${stage_dir}"

	make DEBUG=1 install PREFIX="${DEPS_PREFIX}"
	deps_ldconfig
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

	# Build the vendored graylib + raylib static archives first (LRG backend).
	# graylib.h pulls in graylib's GENERATED grl-version.h, which only exists
	# once graylib is built, so it must be generated before the LRG sources
	# compile. Doing it explicitly here is also safe against parallel make
	# (-j) injected by the Forgejo runners.
	make DEBUG=1 -C deps/libregnum/deps/graylib lib ${DEPS_GRAYLIB_CFLAGS:+CUSTOM_CFLAGS="${DEPS_GRAYLIB_CFLAGS}"}

	# Generate version headers before the main build. Forgejo runners may
	# inject MAKEFLAGS with -j, causing parallel make to start compilation
	# before the generated headers exist.
	make DEBUG=1 LRG_BACKEND=1 src/gst-version.h deps/crispy/src/crispy-version.h

	# gst's config.mk picks lib64 whenever /usr/lib64 exists, which on Arch is
	# a symlink to lib; the module directory is compiled in, so LIBDIR is
	# passed to the build as well as the install.
	local libdir
	libdir="$(immutablue_libdir)"

	make DEBUG=1 LRG_BACKEND=1 MCP=1 WEBVIEW=1 all PREFIX="${DEPS_PREFIX}" LIBDIR="${DEPS_PREFIX}/${libdir}" BUILD_MODULES=1 BUILD_WAYLAND=1 BUILD_GIR=0
	make DEBUG=1 LRG_BACKEND=1 MCP=1 WEBVIEW=1 install PREFIX="${DEPS_PREFIX}" LIBDIR="${DEPS_PREFIX}/${libdir}" DESTDIR="${stage_dir}" BUILD_MODULES=1 BUILD_WAYLAND=1 BUILD_GIR=0
}

# gsurf -- GObject Surf (WebKit2GTK web browser)
# Produces: gsurf binary, libgsurf.so, module .so files, headers, pkg-config,
#           desktop file, hicolor SVG icon, man page
# Vendors its own yaml-glib/crispy/mcp-glib (compiled/linked statically), so it
# is self-contained and does not depend on the system builds above.
# Source: /build/gsurf (COPY'd from submodule)
build_gsurf () {
	local src_dir="${BUILD_DIR}/gsurf"
	local stage_dir="${BUILD_DIR}/gsurf"

	if [[ ! -d "${src_dir}/src" ]]; then
		echo "ERROR: gsurf source not found at ${src_dir}"
		echo "Ensure submodules are initialized: git submodule update --init --recursive"
		exit 1
	fi

	mkdir -p "${stage_dir}"
	cd "${src_dir}"

	# Build the vendored graylib + raylib static archives first (LRG backend).
	# gsurf's LRG sources #include <graylib.h>, which pulls in graylib's
	# GENERATED grl-version.h, so it must exist before they compile. Only
	# graylib is needed -- gsurf links the graylib/raylib archives, not
	# liblibregnum.a -- so this stays self-contained (no libregnum deps) and
	# is also safe against parallel make (-j) injected by the Forgejo runners.
	make DEBUG=1 -C deps/libregnum/deps/graylib lib ${DEPS_GRAYLIB_CFLAGS:+CUSTOM_CFLAGS="${DEPS_GRAYLIB_CFLAGS}"}

	# Generate version headers before the main build. Forgejo runners may
	# inject MAKEFLAGS with -j, causing parallel make to start compilation
	# before the generated headers exist.
	make DEBUG=1 LRG_BACKEND=1 src/gsurf-version.h deps/crispy/src/crispy-version.h

	make DEBUG=1 LRG_BACKEND=1 MCP=1 all PREFIX="${DEPS_PREFIX}" BUILD_MODULES=1 BUILD_GIR=0
	make DEBUG=1 LRG_BACKEND=1 MCP=1 install PREFIX="${DEPS_PREFIX}" DESTDIR="${stage_dir}" BUILD_MODULES=1 BUILD_GIR=0
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

	# Generate version headers before the main build (parallel make race guard)
	make DEBUG=1 src/gowl-version.h deps/crispy/src/crispy-version.h

	# BUILD_GIR=1 produces Gowl-0.5.{gir,typelib} and install-gir places them in
	# the standard introspection paths. Without it the GI scripting surface
	# gowl documents -- driving the compositor from Python, or from cmacs via
	# gi -- simply is not there on the image, because nothing else generates a
	# typelib for it. gobject-introspection-devel is already a build dependency
	# here for ai-glib, which uses the same mechanism.
	make DEBUG=1 MCP=1 all PREFIX="${DEPS_PREFIX}" BUILD_MODULES=1 BUILD_GIR=1 BUILD_XWAYLAND=1
	make DEBUG=1 MCP=1 install PREFIX="${DEPS_PREFIX}" DESTDIR="${stage_dir}" BUILD_MODULES=1 BUILD_GIR=1 BUILD_XWAYLAND=1

	make DEBUG=1 MCP=1 install PREFIX="${DEPS_PREFIX}" BUILD_MODULES=1 BUILD_GIR=1 BUILD_XWAYLAND=1
	deps_ldconfig

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
	local libdir
	libdir="$(immutablue_libdir)"

	make DEBUG=1 all PREFIX="${DEPS_PREFIX}" LIBDIR="${DEPS_PREFIX}/${libdir}"
	make DEBUG=1 install PREFIX="${DEPS_PREFIX}" LIBDIR="${DEPS_PREFIX}/${libdir}" DESTDIR="${stage_dir}"

	# Also install to the deps container itself so mcp-gdb-glib can link against it
	make DEBUG=1 install PREFIX="${DEPS_PREFIX}" LIBDIR="${DEPS_PREFIX}/${libdir}"
	deps_ldconfig
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

	# Manual install to ${DEPS_PREFIX}/bin (Makefile hardcodes /usr/local/bin)
	install -d "${stage_dir}${DEPS_PREFIX}/bin"
	install -m 755 build/gdb-mcp-server "${stage_dir}${DEPS_PREFIX}/bin/"
}


# ai-glib -- GObject AI provider library (Claude, OpenAI, Gemini, Grok, Ollama)
# Produces: libai-glib-1.0.so, headers, pkg-config, ai-gui and
#           org.copyleft.AiGlib.Gui.desktop
# Source: /build/ai-glib (COPY'd from submodule)
#
# gtk4-devel and libadwaita-devel are in packages.yaml build_deps so `make all` builds
# ai-gui. `make install` then copies data/org.copyleft.AiGlib.Gui.desktop
# into ${stage_dir}/usr/share/applications/ because the built binary
# exists. build/10-copy.sh copies that whole usr/ tree into the image,
# which is how the launcher reaches a desktop session.
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
	local libdir
	libdir="$(immutablue_libdir)"

	# GIR=1 builds and installs AiGlib-1.0.{gir,typelib} into standard GI
	# search paths so the final image's introspection consumers (cmacs,
	# python-gi, gjs) can `(gi-require "AiGlib" "1.0")` out of the box.
	make DEBUG=1 GIR=1 all PREFIX="${DEPS_PREFIX}" LIBDIR="${DEPS_PREFIX}/${libdir}"
	make DEBUG=1 GIR=1 install PREFIX="${DEPS_PREFIX}" LIBDIR="${DEPS_PREFIX}/${libdir}" DESTDIR="${stage_dir}"

	make DEBUG=1 GIR=1 install PREFIX="${DEPS_PREFIX}" LIBDIR="${DEPS_PREFIX}/${libdir}"
	deps_ldconfig
}


# podomation -- Podman automation DSL engine (GLib/GObject project)
# Produces: podomation binary, libpodomation-1.0.so.1.0.0, module .so files,
#           headers, pkg-config
# Bundles its own deps (yaml-glib, crispy, mcp-glib, ai-glib) as static libs.
# Source: /build/podomation (COPY'd from submodule)
build_podomation () {
	local src_dir="${BUILD_DIR}/podomation"
	local stage_dir="${BUILD_DIR}/podomation"

	if [[ ! -d "${src_dir}/src" ]]; then
		echo "ERROR: podomation source not found at ${src_dir}"
		echo "Ensure submodules are initialized: git submodule update --init --recursive"
		exit 1
	fi

	mkdir -p "${stage_dir}"
	cd "${src_dir}"

	# Generate version header and build deps before the main build (parallel make race guard)
	make DEBUG=1 version deps

	make DEBUG=1 all PREFIX="${DEPS_PREFIX}"
	make DEBUG=1 install PREFIX="${DEPS_PREFIX}" DESTDIR="${stage_dir}"

	make DEBUG=1 install PREFIX="${DEPS_PREFIX}"
	deps_ldconfig
}


# bacon -- GLib/GObject-native login shell with modular extensibility
# Produces: bacon binary, libbacon-1.0.so, module .so files, headers, pkg-config
# Bundles its own deps (crispy, yaml-glib) as submodules in deps/
# Source: /build/bacon (COPY'd from submodule)
build_bacon () {
	local src_dir="${BUILD_DIR}/bacon"
	local stage_dir="${BUILD_DIR}/bacon"

	if [[ ! -d "${src_dir}/src" ]]; then
		echo "ERROR: bacon source not found at ${src_dir}"
		echo "Ensure submodules are initialized: git submodule update --init --recursive"
		exit 1
	fi

	mkdir -p "${stage_dir}"
	cd "${src_dir}"

	# Generate version headers before the main build (parallel make race guard)
	make DEBUG=1 src/bacon-version.h deps/crispy/src/crispy-version.h

	make DEBUG=1 all PREFIX="${DEPS_PREFIX}" BUILD_MODULES=1 BUILD_GIR=0
	make DEBUG=1 install install-lsp PREFIX="${DEPS_PREFIX}" DESTDIR="${stage_dir}" BUILD_MODULES=1 BUILD_GIR=0

	make DEBUG=1 install install-lsp PREFIX="${DEPS_PREFIX}" BUILD_MODULES=1 BUILD_GIR=0
	deps_ldconfig
}


# mcp-kuberblue-glib -- MCP server for kuberblue Kubernetes cluster management
# Produces: mcp-kuberblue-glib binary at /usr/bin/mcp-kuberblue-glib
# Depends on: mcp-glib (system), yaml-glib (system), glib2, json-glib
# Uses SYSTEM_DEPS=1 so it links against system-installed mcp-glib/yaml-glib
# instead of the submodules in deps/ (which are empty in the COPY'd source tree).
# Source: /build/mcp-kuberblue-glib (COPY'd from overrides_kuberblue submodule)
build_mcp_kuberblue_glib () {
	local src_dir="${BUILD_DIR}/mcp-kuberblue-glib"
	local stage_dir="${BUILD_DIR}/mcp-kuberblue-glib"

	if [[ ! -d "${src_dir}/src" ]]; then
		echo "ERROR: mcp-kuberblue-glib source not found at ${src_dir}"
		echo "Ensure the submodule is initialized in immutablue:"
		echo "  git submodule update --init artifacts/overrides_kuberblue/usr/src/gitlab/mcp-kuberblue-glib"
		exit 1
	fi

	mkdir -p "${stage_dir}"
	cd "${src_dir}"

	# SYSTEM_DEPS=1: use system-installed mcp-glib and yaml-glib (already built above)
	if ! make DEBUG=1 SYSTEM_DEPS=1 all PREFIX="${DEPS_PREFIX}"; then
		echo "ERROR: mcp-kuberblue-glib build failed"
		echo "Verify mcp-glib-1.0 and yaml-glib-1.0 are findable via pkg-config"
		exit 1
	fi
	make DEBUG=1 SYSTEM_DEPS=1 install PREFIX="${DEPS_PREFIX}" DESTDIR="${stage_dir}"
}


# ============================================================================
# INFRASTRUCTURE
# ============================================================================

# Load the shared library and the selected backend (backend_pkg_install,
# backend_deps_prepare, backend_get). INSTALL_DIR points it at the copied
# packages.yaml; the runtime header that normally defines TRUE/FALSE is not in
# this container, so they are defined first.
load_immutablue_library () {
	TRUE=1
	FALSE=0
	export INSTALL_DIR="${IMMUTABLUE_SRC}"
	export VERSION="${VERSION:-${FEDORA_VERSION:-}}"
	# shellcheck source=build/99-common.sh
	source "${IMMUTABLUE_SRC}/build/99-common.sh"
}

# The libdir the C projects install into: backend.yaml 'libdir' (lib64 on
# Fedora, lib on Arch). Falls back to probing /usr/lib64, which is what this
# script always did -- but that probe is wrong on Arch, where /usr/lib64 is a
# symlink to lib and installing into it would create a real lib64 directory
# that then cannot be copied over the image's symlink.
immutablue_libdir () {
	local libdir

	libdir="$(backend_get libdir)"
	if [[ -n "${libdir}" ]]; then
		echo "${libdir}"
	elif [[ -d /usr/lib64 ]]; then
		echo "lib64"
	else
		echo "lib"
	fi
}

# How the C projects are built on this backend: backend.yaml 'deps_build'.
# Fedora and Arch set none of it and get exactly what this script always did
# (PREFIX=/usr, make, the projects' default compiler, ldconfig). FreeBSD
# builds under /usr/local with gmake and gcc.
#
# Sets DEPS_PREFIX, DEPS_MAKE, DEPS_GRAYLIB_CFLAGS and DEPS_SKIP (build names
# to leave out), and exports CC and PKG_CONFIG_PATH when the backend asks.
deps_build_env () {
	local cc
	local libdir

	DEPS_PREFIX="$(backend_get deps_build.prefix)"
	DEPS_PREFIX="${DEPS_PREFIX:-/usr}"
	DEPS_MAKE="$(backend_get deps_build.make)"
	DEPS_MAKE="${DEPS_MAKE:-make}"
	DEPS_GRAYLIB_CFLAGS="$(backend_get deps_build.graylib_cflags)"
	mapfile -t DEPS_SKIP < <(backend_get 'deps_build.skip // [] | .[]')

	cc="$(backend_get deps_build.cc)"
	if [[ -n "${cc}" ]]; then
		export CC="${cc}"
	fi

	# pkg-config already searches /usr; a prefix elsewhere is added in
	# front of (not instead of) its default path.
	if [[ "${DEPS_PREFIX}" != "/usr" ]]; then
		libdir="$(immutablue_libdir)"
		export PKG_CONFIG_PATH="${DEPS_PREFIX}/${libdir}/pkgconfig${PKG_CONFIG_PATH:+:${PKG_CONFIG_PATH}}"
	fi
}

# Every 'make' below runs the backend's GNU make (gmake on FreeBSD, where
# make is bmake).
make () {
	command "${DEPS_MAKE}" "$@"
}

# Refresh the linker cache after an install, so the next project links and
# runs against what was just installed. backend_ldconfig when the backend has
# one (FreeBSD's ldconfig must merge, not replace), plain ldconfig otherwise.
deps_ldconfig () {
	if declare -F backend_ldconfig > /dev/null; then
		backend_ldconfig
	else
		ldconfig
	fi
}

# Is a build name listed in backend.yaml deps_build.skip?
#
# param $1: build name, e.g. 'zapper'
# returns: 0 when skipped, 1 otherwise
deps_build_skipped () {
	local skip

	for skip in "${DEPS_SKIP[@]}"
	do
		if [[ "${skip}" == "${1}" ]]; then
			return 0
		fi
	done
	return 1
}

install_build_deps () {
	local deps=()

	echo "=== Installing build dependencies for ${IMMUTABLUE_BACKEND} ==="

	if declare -F backend_deps_prepare > /dev/null; then
		backend_deps_prepare
	fi

	mapfile -t deps < <(get_yaml_array '.immutablue.build_deps' "$(backend_get pkg_key)" | dedupe_lines)
	if [[ ${#deps[@]} -eq 0 ]]; then
		echo "ERROR: packages.yaml build_deps resolved to nothing for ${IMMUTABLUE_BACKEND}" >&2
		exit 1
	fi
	backend_pkg_install "${deps[@]}"
}


# ============================================================================
# MAIN
# ============================================================================

main () {
	load_immutablue_library
	deps_build_env
	install_build_deps
	deps_ldconfig
	mkdir -p "${BUILD_DIR}"

	for name in "${BUILDS[@]}"
	do
		if deps_build_skipped "${name}"; then
			echo "=== Skipping: ${name} (not built on ${IMMUTABLUE_BACKEND}) ==="
			continue
		fi
		echo "=== Building: ${name} ==="
		"build_${name}"
	done

	echo "=== All dependencies built successfully ==="
}

main
