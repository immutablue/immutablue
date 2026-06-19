#!/bin/bash
set -euxo pipefail

# Define TRUE/FALSE early (before immutablue-header.sh is available)
TRUE=1
FALSE=0

mkdir -p "${INSTALL_DIR}"
cp -a /mnt-ctx/. "${INSTALL_DIR}/"
ls -l "${INSTALL_DIR}"

# -----------------------------------
# Shrink the shipped source tree's git history to just the built commit.
#
# We intentionally ship the full immutablue source (and its submodules: gst,
# gsurf, and their deep transitive submodules -- libregnum, cad-glib, solvespace,
# steamworks_sdk, raylib, ...) under ${INSTALL_DIR} for build provenance. The
# working trees are modest, but the submodule *histories* under
# ${INSTALL_DIR}/.git/modules add ~2.7G (e.g. steamworks_sdk and raylib carry
# ~400M of history each, vendored by BOTH gst and gsurf). Reduce every repo --
# the superproject and every nested submodule -- to a single commit: the exact
# one that was checked out. This preserves the commit SHA / author / date /
# message (git log -1, git show, git describe all still work) while dropping the
# ancestry. ostree later mirrors the rootfs into /sysroot, so bytes saved here
# are saved roughly twice in the final image.
#
# Three things make a naive "write .git/shallow + repack" a no-op here, all
# handled below:
#   1. Each submodule's config has a core.worktree pointing at a build-time
#      relative path that does not resolve in this container, so plain git
#      commands abort with "cannot chdir". Passing --work-tree="${gitdir}"
#      (an existing dir) overrides it.
#   2. repack keeps everything reachable from ALL refs. Submodules ship with
#      refs/heads/* and refs/remotes/origin/* pointing at full history while
#      HEAD is detached at the pinned commit -- so we detach HEAD to its SHA and
#      delete the other refs, leaving only the built commit reachable.
#   3. git 2.5x defaults to cruft packs: repack -ad moves unreachable objects
#      into a .mtimes cruft pack instead of deleting them. gc.cruftPacks=false
#      forces them to be dropped so the space is actually reclaimed.
# -----------------------------------
strip_git_to_shallow() {
    local top="$1"
    [[ -d "${top}" ]] || return 0
    command -v git >/dev/null 2>&1 || { echo "git not available; skipping git history strip"; return 0; }

    local objects gitdir head
    # A gitdir is the parent of an 'objects' directory that also holds a HEAD.
    # Searching only under the .git tree avoids matching source dirs named
    # "objects". This catches the superproject (.git/objects) and every
    # submodule, including deeply nested ones (.git/modules/.../objects).
    while IFS= read -r -d '' objects; do
        gitdir="$(dirname "${objects}")"
        [[ -e "${gitdir}/HEAD" ]] || continue
        # --work-tree overrides the broken core.worktree (see note 1 above).
        head="$(git --git-dir="${gitdir}" --work-tree="${gitdir}" rev-parse HEAD 2>/dev/null)" || continue
        [[ -n "${head}" ]] || continue

        echo "=== Shallowing ${gitdir} @ ${head} ==="
        # Detach HEAD at the built commit, then drop every other ref so only
        # this commit is reachable (see note 2 above).
        git --git-dir="${gitdir}" --work-tree="${gitdir}" update-ref --no-deref HEAD "${head}" 2>/dev/null || true
        rm -f "${gitdir}/packed-refs"
        find "${gitdir}/refs" -type f -delete 2>/dev/null || true
        # Graft away this commit's parents so the snapshot is self-contained.
        echo "${head}" > "${gitdir}/shallow"
        git --git-dir="${gitdir}" --work-tree="${gitdir}" reflog expire --expire=now --all 2>/dev/null || true
        # cruftPacks=false so unreachable history is deleted, not cruft-packed.
        git --git-dir="${gitdir}" --work-tree="${gitdir}" -c gc.cruftPacks=false repack -ad 2>/dev/null || true
        git --git-dir="${gitdir}" --work-tree="${gitdir}" prune --expire=now 2>/dev/null || true
    done < <(find "${top}" -type d -name objects -print0)
}

strip_git_to_shallow "${INSTALL_DIR}/.git"

# The bundled tool source (gst, gsurf, ...) is deployed to its canonical home
# at /usr/src/gitlab via the overrides copy below. The same tree is also a
# verbatim member of the immutablue repo we just copied into ${INSTALL_DIR}
# (under artifacts/overrides/usr/src), so it currently ships twice (~890M).
# Drop the in-${INSTALL_DIR} mirror; /usr/src/gitlab remains the shipped copy.
if [[ -d "${INSTALL_DIR}/artifacts/overrides/usr/src" ]]; then
    echo "=== Removing duplicate source mirror from ${INSTALL_DIR} ==="
    rm -rf "${INSTALL_DIR}/artifacts/overrides/usr/src"
fi

cp -a /mnt-ctx/artifacts/overrides/. /

# The deployed /usr/src/gitlab worktrees still carry their submodule .git
# pointer files, which reference the build-time /mnt-ctx gitdir and are dangling
# at runtime. Strip them so /usr/src/gitlab is clean, self-contained source
# (provenance lives in the shallow ${INSTALL_DIR}/.git).
if [[ -d "/usr/src/gitlab" ]]; then
    echo "=== Removing dangling submodule .git pointers under /usr/src/gitlab ==="
    find /usr/src/gitlab -name .git \( -type f -o -type l \) -delete 2>/dev/null || true
fi
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

# gsurf: WebKit web browser (skip for nucleus -- no display server)
if [[ "$(is_option_in_build_options nucleus)" == "${FALSE}" ]] && \
   [[ -d "/mnt-build-deps/gsurf/usr" ]]; then
    echo "=== Installing gsurf from build deps ==="
    cp -a /mnt-build-deps/gsurf/usr/. /usr/
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

# cmacs: GNU Emacs with GLib/GObject/Wayland integration (skip for nucleus -- no GUI)
# Built externally at quay.io/zachpodbielniak/cmacs, mounted at /mnt-cmacs
if [[ "$(is_option_in_build_options nucleus)" == "${FALSE}" ]] && \
   [[ -d "/mnt-cmacs/usr" ]]; then
    echo "=== Installing cmacs from cmacs container ==="
    cp -a /mnt-cmacs/usr/. /usr/
    # Copy ldconfig snippets (e.g. /etc/ld.so.conf.d/cmacs.conf)
    if [[ -d "/mnt-cmacs/etc" ]]; then
        cp -a /mnt-cmacs/etc/. /etc/
    fi
    ldconfig
fi

# podomation: Podman automation DSL engine (always install)
# Must come AFTER cmacs: the cmacs image bundles its own podomation build
# (from its deps/ submodule pin) under /usr/lib64/podomation/modules, which
# would otherwise overwrite the canonical build-deps version.
if [[ -d "/mnt-build-deps/podomation/usr" ]]; then
    echo "=== Installing podomation from build deps ==="
    cp -a /mnt-build-deps/podomation/usr/. /usr/
fi

# bacon: GLib/GObject login shell (always install)
# Must come AFTER cmacs for the same reason as podomation: cmacs bundles
# its own bacon build under /usr/lib64/bacon.
if [[ -d "/mnt-build-deps/bacon/usr" ]]; then
    echo "=== Installing bacon from build deps ==="
    cp -a /mnt-build-deps/bacon/usr/. /usr/
fi

# nerd-fonts: FiraCode, FiraMono, Hack (always install)
if [[ -d "/mnt-build-deps/nerd_fonts/usr" ]]; then
    echo "=== Installing nerd-fonts from build deps ==="
    cp -a /mnt-build-deps/nerd_fonts/usr/. /usr/
fi

# mcp-kuberblue-glib: MCP server for kuberblue cluster management
# Only installed in kuberblue variant builds
if [[ "$(is_option_in_build_options kuberblue)" == "${TRUE}" ]] && \
   [[ -d "/mnt-build-deps/mcp-kuberblue-glib/usr" ]]; then
    echo "=== Installing mcp-kuberblue-glib from build deps ==="
    cp -a /mnt-build-deps/mcp-kuberblue-glib/usr/. /usr/
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
        # Ensure all .sh files retain execute permission after copy
        # (rootless buildah bind mounts can strip execute bits)
        find /usr/libexec/kuberblue -name '*.sh' -exec chmod +x {} + 2>/dev/null || true
    else
        echo "no overrides for ${option}"
    fi
done < <(get_immutablue_build_options)


# Remove test YAML files from production kuberblue images.
# chainsaw.yaml and *_test.yaml manifests are only needed in dev/staging builds.
# When KUBERBLUE=1 but KUBERBLUE_DEV=1 is not set, strip them from the image.
if [[ "$(is_option_in_build_options kuberblue)" == "${TRUE}" ]] && \
   [[ "$(is_option_in_build_options kuberblue_dev)" != "${TRUE}" ]]; then
    find /etc/kuberblue/manifests/ -name "*_test.yaml" -delete 2>/dev/null || true
    find /etc/kuberblue/ -name "chainsaw.yaml" -delete 2>/dev/null || true
fi


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
