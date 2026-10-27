#!/bin/bash
# backends/fedora-bootc/backend.sh
#
# The fedora-bootc implementation of backends/lib/interface.sh.
#
# Every body here was lifted from the build stage that used to call dnf5,
# rpm or systemctl directly, so a Fedora image built through the backend
# interface is the same image as before. When changing one of these, read the
# comment that came with it: most of them document a failure that happened.


# Download a dnf .repo file into /etc/yum.repos.d and deprioritise it.
#
# Fedora's own repos carry the dnf default priority of 99, and a lower number
# wins. Every repo added here therefore competes with Fedora base on equal
# footing: whichever has the higher package version wins, regardless of which
# is the intended source. These are single-purpose repos (tailscale,
# podman-bootc, znapzend), so a COPR that happens to carry a newer build of
# some shared dependency can silently replace the Fedora package for the whole
# image, and nothing in the build would report it.
#
# Setting them to 200 keeps them usable for the packages they exist to provide
# while making Fedora authoritative for everything else.
#
# Deliberately NOT applied to:
#   RPM Fusion  -- installed from release RPMs via rpm_url, and the mesa /
#                  ffmpeg freeworld swaps in stages/35-* and 36-* depend on
#                  pulling replacements from it.
#   the ZFS repo -- installed from a release RPM for the same reason.
# Both are intentional overrides of Fedora packages, which is exactly what the
# priority is meant to prevent for everything else.
#
# param $1: the repo file name, e.g. 'tailscale.repo'
# param $2: the URL of the .repo file
# returns: 0 on success, 1 when the download fails
backend_repo_add() {
    local repo="$1"
    local repo_url="$2"
    local repo_file="/etc/yum.repos.d/${repo}"
    local repo_priority=200

    # A failed download is reported rather than silently swallowed -- a
    # missing repo means the packages it provides will be missing from the
    # image.
    if ! immutablue_curl -fLo "${repo_file}" "${repo_url}"
    then
        echo "ERROR: failed to download ${repo} from ${repo_url}" >&2
        return 1
    fi
    echo "Added ${repo} from ${repo_url}"

    # Only touch files that actually parsed as a repo definition.
    if [[ ! -s "${repo_file}" ]] || ! grep -q '^\[' "${repo_file}"
    then
        return 0
    fi

    # Respect an upstream repo that ships its own priority rather than
    # overriding a deliberate choice by whoever published it.
    if grep -qE '^[[:space:]]*priority[[:space:]]*=' "${repo_file}"
    then
        echo "Leaving ${repo_file} at its shipped priority"
        return 0
    fi

    # Insert the priority into every section; a .repo file routinely defines
    # several (a COPR ships its main repo plus debuginfo/source variants).
    awk -v prio="${repo_priority}" '
        /^\[/ { print; print "priority=" prio; next }
        { print }
    ' "${repo_file}" > "${repo_file}.tmp"
    mv "${repo_file}.tmp" "${repo_file}"
    echo "Set priority=${repo_priority} on ${repo_file}"
}


# Install packages by name from the configured repositories.
#
# param $@: package names (may be empty)
backend_pkg_install() {
    if [[ $# -eq 0 ]]
    then
        return 0
    fi
    dnf5 -y install "$@"
}


# Install package files: local paths or URLs to .rpm files.
#
# dnf5 accepts both in the same 'install' transaction as plain names, which is
# how rpm_url (RPM Fusion release packages) and the ublue udev rules have
# always been installed.
#
# param $@: paths or URLs (may be empty)
backend_pkg_install_files() {
    if [[ $# -eq 0 ]]
    then
        return 0
    fi
    dnf5 -y install "$@"
}


# Remove packages by name.
#
# Callers intersect with the installed set first (see 40-uninstall-packages.sh)
# because dnf5 fails the whole transaction on an absent package.
#
# param $@: package names (may be empty)
backend_pkg_remove() {
    if [[ $# -eq 0 ]]
    then
        return 0
    fi
    dnf5 -y remove "$@"
}


# Is a package (or a capability) installed?
#
# --whatprovides resolves plain package names and capabilities alike, matching
# what dnf5 itself accepts in a remove request.
#
# param $1: package name or capability
# returns: ${TRUE} or ${FALSE} on stdout
backend_pkg_installed() {
    local pkg="$1"

    if rpm --quiet -q --whatprovides "${pkg}"
    then
        echo "${TRUE}"
    else
        echo "${FALSE}"
    fi
}


# Change a systemd unit's state.
#
# param $1: enable | disable | mask | unmask
# param $2: optional '--global' to act on the user-unit presets for everyone
# param $@: the unit
backend_svc() {
    local action="$1"
    shift
    systemctl "${action}" "$@"
}


# The os-release file /etc/os-release is linked to.
#
# One file per supported Fedora release ships under etc/.os-release-<ver>.
#
# returns: the absolute path on stdout
backend_os_release_path() {
    echo "/etc/.os-release-${FEDORA_VERSION}"
}


# Last step of the build: turn the container filesystem into an ostree commit
# that bootc can deploy.
backend_finalize() {
    ostree container commit
}


# Prepare the deps container's package manager before build_deps install.
# (Optional hook; used by deps-container/00-build.sh only.)
backend_deps_prepare() {
    echo -e 'max_parallel_downloads=10\n' >> /etc/dnf/dnf.conf
    dnf5 update -y
}
