#!/usr/bin/env bash
# -----------------------------------
# Distroless Development Tools Builder
# -----------------------------------
# This script runs in the GNOME OS devel stage to extract
# development tools (gcc, build essentials) that will be
# copied into the final distroless image.
#
# Inspired by ublue's Dakota project but adapted for Immutablue.
# -----------------------------------

set -xeuo pipefail

mkdir -p /rootfs

# -----------------------------------
# Helper functions
# -----------------------------------

# Copy a binary and all its shared library dependencies
copy_binary () {
    local file="$1"
    local rootfs="$2"

    if [[ ! -f "${file}" ]]; then
        echo "Warning: ${file} not found, skipping"
        return 0
    fi

    cp --parents -a -n -v "$file" "$rootfs" && \
    ldd "$file" 2>/dev/null | grep -o '/[^ ]*' | xargs -I '{}' cp -P --parents -n -v '{}' "$rootfs" || true
}

# Copy a directory recursively
copy_recursively () {
    local file="$1"
    local rootfs="$2"

    if [[ ! -e "${file}" ]]; then
        echo "Warning: ${file} not found, skipping"
        return 0
    fi

    cp --parents -a -n -v -r "$file" "$rootfs"
}

# -----------------------------------
# Copy essential development tools
# -----------------------------------

echo "=== Copying essential binaries ==="

# Clipboard utilities (useful for desktop)
copy_binary /usr/bin/wl-copy /rootfs
copy_binary /usr/bin/wl-paste /rootfs

# GCC toolchain
if [[ -f /usr/bin/gcc ]]; then
    echo "=== Copying GCC toolchain ==="
    copy_binary /usr/bin/gcc /rootfs
    copy_binary /usr/bin/c++ /rootfs
    copy_binary /usr/bin/cc /rootfs
    copy_binary /usr/bin/cpp /rootfs
    copy_binary /usr/bin/gcc-ar /rootfs
    copy_binary /usr/bin/gcc-nm /rootfs
    copy_binary /usr/bin/gcc-ranlib /rootfs
    copy_binary /usr/bin/gcov /rootfs
    copy_binary /usr/bin/gcov-tool /rootfs

    # Cross-compiler binaries if present
    for f in $(find /usr/bin -name 'x86_64-*-linux-gnu-*' 2>/dev/null || true); do
        copy_binary "$f" /rootfs
    done
fi

# Just command runner (if present)
copy_binary /usr/bin/just /rootfs

# Git (essential for development)
copy_binary /usr/bin/git /rootfs

# Make
copy_binary /usr/bin/make /rootfs

# -----------------------------------
# Copy supporting files
# -----------------------------------

echo "=== Copying supporting files ==="

# Man pages (GNOME OS production images don't include these)
if [[ -d /usr/share/man ]]; then
    copy_recursively /usr/share/man /rootfs
fi

# Shell completions for wl-copy/wl-paste
copy_recursively /usr/share/bash-completion/completions/wl-copy /rootfs 2>/dev/null || true
copy_recursively /usr/share/bash-completion/completions/wl-paste /rootfs 2>/dev/null || true
copy_recursively /usr/share/fish/vendor_completions.d/wl-copy.fish /rootfs 2>/dev/null || true
copy_recursively /usr/share/fish/vendor_completions.d/wl-paste.fish /rootfs 2>/dev/null || true
copy_recursively /usr/share/zsh/site-functions/_wl-copy /rootfs 2>/dev/null || true
copy_recursively /usr/share/zsh/site-functions/_wl-paste /rootfs 2>/dev/null || true

# GCC support files
for gcc_dir in /usr/share/gcc-*; do
    if [[ -d "$gcc_dir" ]]; then
        copy_recursively "$gcc_dir" /rootfs 2>/dev/null || true
    fi
done
if [[ -d /usr/include/c++ ]]; then
    copy_recursively /usr/include/c++ /rootfs
fi
if [[ -d /usr/lib/gcc ]]; then
    copy_recursively /usr/lib/gcc /rootfs
fi
if [[ -d /usr/libexec/gcc ]]; then
    copy_recursively /usr/libexec/gcc /rootfs
fi

# GDB auto-load scripts for debugging
copy_recursively /usr/share/gdb/auto-load/usr/lib/x86_64-linux-gnu/libstdc++.so.*.py /rootfs 2>/dev/null || true

# -----------------------------------
# Fix library paths
# -----------------------------------

echo "=== Fixing library paths ==="

# Move lib64 to usr/lib64 if needed (GNOME OS uses different layout)
if [[ -d /rootfs/lib64 ]] && [[ ! -L /rootfs/lib64 ]]; then
    mkdir -p /rootfs/usr/lib64
    cp -an /rootfs/lib64/. /rootfs/usr/lib64/ 2>/dev/null || true
    rm -rf /rootfs/lib64
    ln -sf usr/lib64 /rootfs/lib64
fi

# -----------------------------------
# Summary
# -----------------------------------

echo "=== Devel stage complete ==="
echo "Rootfs contents:"
find /rootfs -type f | head -50
echo "..."
du -sh /rootfs
