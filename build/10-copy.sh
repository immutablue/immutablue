#!/bin/bash
set -euxo pipefail

# Define TRUE/FALSE early (before immutablue-header.sh is available)
TRUE=1
FALSE=0

mkdir -p "${INSTALL_DIR}"
cp -a /mnt-ctx/. "${INSTALL_DIR}/"
ls -l "${INSTALL_DIR}"
cp -a /mnt-ctx/artifacts/overrides/. /
echo "${IMMUTABLUE_BUILD_OPTIONS}" > "${INSTALL_DIR}/build_options"

# things depend on 'yq' heavily for build, so copy it early
cp /mnt-yq/yq /usr/bin/yq

# -----------------------------------
# Distroless: Copy development tools from devel stage
# -----------------------------------
if [[ -d "/mnt-devel-rootfs" ]] && [[ -n "$(ls -A /mnt-devel-rootfs 2>/dev/null)" ]]; then
    echo "=== Copying distroless devel rootfs ==="
    cp -avn /mnt-devel-rootfs/. / 2>/dev/null || true
    echo "Devel rootfs copied"
fi

# -----------------------------------
# Copy build artifacts (skip some for distroless)
# -----------------------------------

# Check if this is a distroless build
IS_DISTROLESS_BUILD="${FALSE}"
if echo "${IMMUTABLUE_BUILD_OPTIONS}" | grep -q "distroless"; then
    IS_DISTROLESS_BUILD="${TRUE}"
fi

# Nautilus extension (skip for distroless - may not have nautilus)
if [[ "${IS_DISTROLESS_BUILD}" == "${FALSE}" ]] || [[ -d "/usr/lib64/nautilus" ]]; then
    mkdir -p /usr/lib64/nautilus/extensions-4
    cp /mnt-nautilusopenwithcode/libnautilus-open-with-code.so /usr/lib64/nautilus/extensions-4/libnautilus-open-with-code.so 2>/dev/null || true
fi

# Build tools (copy if available)
cp /mnt-build-deps/blue2go/blue2go /usr/bin/blue2go 2>/dev/null || true
cp /mnt-build-deps/cigar/src/cigar /usr/bin/cigar 2>/dev/null || true
# cp /mnt-build-deps/cpak/cpak /usr/bin/cpak
cp /mnt-build-deps/zapper/zapper /usr/bin/zapper 2>/dev/null || true

# the sourcing must come after we bootstrap the above
if [[ -f "${INSTALL_DIR}/build/99-common.sh" ]]; then source "${INSTALL_DIR}/build/99-common.sh"; fi
if [[ -f "./99-common.sh" ]]; then source "./99-common.sh"; fi


# -----------------------------------
# Custom C projects (yaml-glib, crispy, gst, gowl, mcp-glib, mcp-gdb-glib)
# Staged with DESTDIR in deps container, layout mirrors target filesystem.
# cp -a preserves symlinks (libfoo.so -> libfoo.so.0 -> libfoo.so.0.1.0)
# -----------------------------------

# yaml-glib: GObject YAML library (always install, foundational library)
if [[ -d "/mnt-build-deps/yaml-glib/usr" ]]; then
    echo "=== Installing yaml-glib from build deps ==="
    cp -a /mnt-build-deps/yaml-glib/usr/. /usr/
fi

# crispy: C script compiler/runner (always install, CLI-only, depends on glib2)
if [[ -d "/mnt-build-deps/crispy/usr" ]]; then
    echo "=== Installing crispy from build deps ==="
    cp -a /mnt-build-deps/crispy/usr/. /usr/
fi

# gst: terminal emulator (skip for nucleus -- no display server)
if [[ "$(is_option_in_build_options nucleus)" == "${FALSE}" ]] && \
   [[ -d "/mnt-build-deps/gst/usr" ]]; then
    echo "=== Installing gst from build deps ==="
    cp -a /mnt-build-deps/gst/usr/. /usr/
fi

# gowl: wayland compositor (skip for nucleus -- no display server)
if [[ "$(is_option_in_build_options nucleus)" == "${FALSE}" ]] && \
   [[ -d "/mnt-build-deps/gowl/usr" ]]; then
    echo "=== Installing gowl from build deps ==="
    cp -a /mnt-build-deps/gowl/usr/. /usr/
    # gowl installs config to /etc/gowl/
    if [[ -d "/mnt-build-deps/gowl/etc" ]]; then
        cp -a /mnt-build-deps/gowl/etc/. /etc/
    fi
fi

# mcp-glib: GObject MCP protocol library (always install, foundational library)
if [[ -d "/mnt-build-deps/mcp-glib/usr" ]]; then
    echo "=== Installing mcp-glib from build deps ==="
    cp -a /mnt-build-deps/mcp-glib/usr/. /usr/
fi

# mcp-gdb-glib: GDB MCP server (always install, depends on mcp-glib)
if [[ -d "/mnt-build-deps/mcp-gdb-glib/usr" ]]; then
    echo "=== Installing mcp-gdb-glib from build deps ==="
    cp -a /mnt-build-deps/mcp-gdb-glib/usr/. /usr/
fi

# ai-glib: GObject AI provider library (always install)
if [[ -d "/mnt-build-deps/ai-glib/usr" ]]; then
    echo "=== Installing ai-glib from build deps ==="
    cp -a /mnt-build-deps/ai-glib/usr/. /usr/
fi

# Update shared library cache for new .so files
ldconfig 2>/dev/null || true


# Install overrides for all build options
while read -r option 
do 
    echo "installing overries for ${option}"
    build_overrides="/mnt-ctx/artifacts/overrides_${option}"

    if [[ -d "${build_overrides}" ]]
    then
        cp -a "${build_overrides}/." /
    else 
        echo "no overrides for ${option}"
    fi
done < <(get_immutablue_build_options)


# Put in place the correct `/etc/os-release`
if [[ -f "/etc/os-release" ]]
then 
    unlink "/etc/os-release"
fi

ln -s "/etc/.os-release-${FEDORA_VERSION}" "/etc/os-release" 


# The linuxbrew container is mounted at /mnt-linuxbrew
LINUXBREW_MNT="/mnt-linuxbrew"

if [[ ! -d "${LINUXBREW_MNT}" ]]; then
    echo "Warning: linuxbrew mount not found at ${LINUXBREW_MNT}, skipping"
    exit 0
fi

# Copy the compressed homebrew tarball
if [[ -f "${LINUXBREW_MNT}/usr/share/homebrew.tar.zst" ]]; then
    mkdir -p /usr/share
    cp "${LINUXBREW_MNT}/usr/share/homebrew.tar.zst" /usr/share/homebrew.tar.zst
    echo "Copied homebrew.tar.zst to /usr/share/"
else
    echo "Warning: homebrew.tar.zst not found in linuxbrew container"
fi

# Copy systemd services and timers
if [[ -d "${LINUXBREW_MNT}/usr/lib/systemd/system" ]]; then
    mkdir -p /usr/lib/systemd/system
    cp -a "${LINUXBREW_MNT}/usr/lib/systemd/system/"linuxbrew-*.service /usr/lib/systemd/system/ 2>/dev/null || true
    cp -a "${LINUXBREW_MNT}/usr/lib/systemd/system/"linuxbrew-*.timer /usr/lib/systemd/system/ 2>/dev/null || true
    echo "Copied linuxbrew systemd services and timers"
fi

# Copy tmpfiles.d configuration
if [[ -f "${LINUXBREW_MNT}/usr/lib/tmpfiles.d/homebrew.conf" ]]; then
    mkdir -p /usr/lib/tmpfiles.d
    cp "${LINUXBREW_MNT}/usr/lib/tmpfiles.d/homebrew.conf" /usr/lib/tmpfiles.d/
    echo "Copied homebrew tmpfiles.d configuration"
fi

# Copy shell integration scripts
if [[ -d "${LINUXBREW_MNT}/etc/profile.d" ]]; then
    mkdir -p /etc/profile.d
    cp -a "${LINUXBREW_MNT}/etc/profile.d/"linuxbrew*.sh /etc/profile.d/ 2>/dev/null || true
    echo "Copied linuxbrew shell integration scripts"
fi

# Copy security limits configuration
if [[ -f "${LINUXBREW_MNT}/etc/security/limits.d/30-brew-limits.conf" ]]; then
    mkdir -p /etc/security/limits.d
    cp "${LINUXBREW_MNT}/etc/security/limits.d/30-brew-limits.conf" /etc/security/limits.d/
    echo "Copied brew limits configuration"
fi

echo "Linuxbrew files copied successfully"
