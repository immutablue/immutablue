#!/bin/bash
# backends/arch-bootc/backend.sh
#
# The arch-bootc implementation of backends/lib/interface.sh: pacman for
# packages, systemd for services, and bootcrew's bootc root filesystem layout
# as the finalize step.


# Add a pacman repository section.
#
# Unused while backend.yaml sets no repo_key; implemented so a pacman_repos
# key can be introduced without touching the stages.
#
# param $1: repository name (the [section])
# param $2: Server URL
backend_repo_add() {
    local repo="$1"
    local url="$2"

    if grep -q "^\[${repo}\]" /etc/pacman.conf
    then
        echo "pacman repo [${repo}] already present"
        return 0
    fi
    printf '\n[%s]\nServer = %s\n' "${repo}" "${url}" >> /etc/pacman.conf
    pacman -Sy --noconfirm
}


# --needed keeps a package the base set already pulled in from being
# reinstalled, which would otherwise rerun its install hooks for nothing.
backend_pkg_install() {
    if [[ $# -eq 0 ]]
    then
        return 0
    fi
    pacman -S --needed --noconfirm "$@"
}


backend_pkg_install_files() {
    if [[ $# -eq 0 ]]
    then
        return 0
    fi
    pacman -U --needed --noconfirm "$@"
}


backend_pkg_remove() {
    if [[ $# -eq 0 ]]
    then
        return 0
    fi
    pacman -Rns --noconfirm "$@"
}


# 'pacman -T' resolves provides (so.virtual names, 'sh', ...) the same way a
# dependency would, and prints only what is NOT satisfied.
backend_pkg_installed() {
    local pkg="$1"

    if pacman -T "${pkg}" > /dev/null 2>&1
    then
        echo "${TRUE}"
    else
        echo "${FALSE}"
    fi
}


backend_svc() {
    local action="$1"
    shift
    systemctl "${action}" "$@"
}


backend_os_release_path() {
    echo "/etc/.os-release-arch"
}


# Prepare the deps container's package manager before build_deps install.
backend_deps_prepare() {
    pacman -Syu --noconfirm
}


# Turn the container filesystem into the layout bootc/ostree deploys.
#
# Follows bootcrew/mono's shared/bootc-rootfs.sh: state directories move under
# /var (which bootc mounts from the deployment's stateroot), the top-level
# names become symlinks into it, tmpfiles recreates them on first boot, and
# composefs plus a read-only sysroot are switched on.
backend_finalize() {
    local dir

    # A unique machine-id is generated on first boot.
    echo "uninitialized" > /etc/machine-id

    # Users are created under /var/home, as on Fedora Atomic.
    sed -i 's|^HOME=.*|HOME=/var/home|' /etc/default/useradd

    # pacman's state lives in /usr/lib/sysimage (see the Containerfile), so
    # removing /var loses nothing the image needs; the package cache and log
    # are dropped to keep the image small. Deleting these system directories
    # is the point: each is recreated below as a symlink into /var.
    # shellcheck disable=SC2114
    rm -rf /boot /home /root /usr/local /srv /opt /mnt /var \
        /usr/lib/sysimage/log /usr/lib/sysimage/cache/pacman/pkg

    mkdir -p /sysroot /boot /usr/lib/ostree /var

    ln -sT sysroot/ostree /ostree
    ln -sT var/roothome /root
    ln -sT var/srv /srv
    ln -sT var/opt /opt
    ln -sT var/mnt /mnt
    ln -sT var/home /home
    ln -sT ../var/usrlocal /usr/local

    {
        for dir in opt home srv mnt usrlocal
        do
            echo "d /var/${dir} 0755 root root -"
        done
        echo "d /var/roothome 0700 root root -"
        echo "d /run/media 0755 root root -"
    } >> /usr/lib/tmpfiles.d/bootc-base-dirs.conf

    printf '[composefs]\nenabled = yes\n[sysroot]\nreadonly = true\n' > /usr/lib/ostree/prepare-root.conf
}


# Last step of an image built FROM an Immutablue image. backend_finalize's
# layout work (deleting /var, /usr/local and friends, the symlinks into /var)
# is done once in the base image and must not run again: it deletes what the
# derived layers put under those paths and fails on the existing links. A
# derived build only drops pacman's package cache, which its installs filled,
# and lets bootc check the result.
backend_finalize_derived() {
    rm -rf /usr/lib/sysimage/cache/pacman/pkg/*
    bootc container lint
}
