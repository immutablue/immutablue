#!/bin/bash
# build-live.sh - Turn an Immutablue fedora-bootc image into its live system
#
# Runs inside 'podman build' of backends/fedora-bootc/live/Containerfile, on
# top of the image the live ISO installs. Adds what a live desktop needs and
# an installed system must not have:
#
#   - livesys-scripts: the passwordless 'liveuser' and its auto-login session
#   - anaconda-live (+ WebUI, shown in Firefox): the installer, preconfigured by a kickstart to
#     install BASE_IMAGE from the OCI image layout on the ISO and then track
#     BASE_IMAGE's registry reference (so 'immutablue update' pulls from there)
#   - dracut-live and the CD boot loaders, used by assemble.sh
#   - immutablue-zfs-install and its launcher, when the image ships ZFS
#   - live-only tweaks: no update/first-boot services, a large /var/tmp
#
# Modelled on Bazzite's installer/ (ublue-os/bazzite, Apache-2.0), which does
# the same for its images.
#
# Environment:
#   BASE_IMAGE     the image reference the installed system tracks (required)
#   LIVE_SESSION   livesys session (gnome, kde, sway, ...; default gnome)
#   LIVE_NAME      product name shown by Anaconda and the ZFS installer
#                  (default Immutablue)
#
# Usage:
#   BASE_IMAGE=quay.io/immutablue/immutablue:44 bash build-live.sh
#
# Options:
#   -h, --help     Show this help message
#   --license      Show license information
#
# Exit codes:
#   0 - The live system is set up
#   1 - A step failed

set -euxo pipefail

SRC="$(CDPATH='' cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KS="/usr/share/anaconda/interactive-defaults.ks"

case "${1:-}" in
    -h|--help) sed -n '2,/^# Exit codes/p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    --license) echo 'build-live.sh - part of Immutablue. AGPL-3.0-or-later.'; exit 0 ;;
    *) ;;
esac

: "${BASE_IMAGE:?BASE_IMAGE must name the image the live ISO installs}"
LIVE_SESSION="${LIVE_SESSION:-gnome}"
LIVE_NAME="${LIVE_NAME:-Immutablue}"

# It ends up in sed replacements, a .desktop file and a shell assignment
if [[ ! "${LIVE_NAME}" =~ ^[A-Za-z0-9][A-Za-z0-9\ ._+-]*$ ]]
then
    echo "build-live.sh: LIVE_NAME may hold letters, digits, spaces and ._+- only" >&2
    exit 1
fi


# -----------------------------------
# Directories the image's top-level symlinks point into. On an installed
# system ostree/systemd-tmpfiles create them under /var; the live root is the
# image's plain filesystem, so they must already exist (livesys puts liveuser
# in /home -> /var/home).
# -----------------------------------
create_symlink_targets () {
    local link
    local target

    for link in /*
    do
        if [[ -L "${link}" ]]
        then
            target="$(readlink -f "${link}")"
            if [[ "${target}" == /var/* ]]
            then
            	mkdir -p "${target}"
            fi
        fi
    done

    # systemd-tmpfiles cannot label the install target when /mnt is a
    # symlink, and Anaconda mounts the target at /mnt/sysroot
    if [[ -L /mnt ]]
    then
        rm -f /mnt
        mkdir /mnt
    fi
}


# -----------------------------------
# Packages: the installer, the live session, the live initramfs module and
# the El Torito EFI GRUB (gcdx64.efi / gcdaa64.efi, which finds its config on
# ISO 9660). squashfs-tools, xorriso and mtools are for assemble.sh.
# -----------------------------------
install_packages () {
    local cdboot

    case "$(uname -m)" in
        x86_64)  cdboot="grub2-efi-x64-cdboot" ;;
        aarch64) cdboot="grub2-efi-aa64-cdboot" ;;
        *) echo "build-live: unsupported architecture $(uname -m)" >&2; exit 1 ;;
    esac

    dnf5 -y install --setopt=install_weak_deps=False \
        anaconda-live anaconda-webui firefox \
        livesys-scripts dracut-live \
        libblockdev-btrfs libblockdev-lvm libblockdev-dm \
        "${cdboot}" squashfs-tools xorriso mtools dosfstools
    dnf5 clean all

    # Anaconda's WebUI keeps state here
    mkdir -p /var/lib/rpm-state
}


# -----------------------------------
# livesys: which session liveuser logs into
# -----------------------------------
configure_livesys () {
    sed -i "s/^livesys_session=.*/livesys_session=${LIVE_SESSION}/" /etc/sysconfig/livesys
    systemctl enable livesys.service livesys-late.service
}


# -----------------------------------
# Anaconda: an Immutablue configuration on top of whatever product profile
# os-release selects (fedora-silverblue for the GNOME images), and a default
# kickstart that installs the image on the ISO.
# -----------------------------------
configure_anaconda () {
    local version_id

    mkdir -p /etc/anaconda/conf.d
    cp "${SRC}/anaconda/90-immutablue.conf" /etc/anaconda/conf.d/90-immutablue.conf

    # Product identity, as lorax writes it on Fedora's own media. Without it
    # Anaconda calls itself "anaconda bluesky (pre-release)" and treats the
    # install as a pre-release.
    version_id="$(. /etc/os-release && echo "${VERSION_ID}")"
    {
        echo "[Main]"
        echo "Product=${LIVE_NAME}"
        echo "Version=${version_id}"
        echo "BugURL=https://gitlab.com/immutablue/immutablue/-/issues"
        echo "IsFinal=True"
        echo "UUID=$(date -u +%Y%m%d%H%M).$(uname -m)"
    } > /.buildstamp

    # The image on the ISO, an OCI image layout that dmsquash-live has the
    # ISO mounted under; and, once installed, the reference updates come from
    {
        echo ""
        echo "# --- Immutablue live ISO (backends/fedora-bootc/live/build-live.sh) ---"
        echo "ostreecontainer --url=/run/initramfs/live/image --transport=oci --no-signature-verification"
        echo ""
        sed "s|@BASE_IMAGE@|${BASE_IMAGE}|g" "${SRC}/anaconda/immutablue-live.ks"
    } >> "${KS}"
}


# -----------------------------------
# Live-only services: the unattended installer (tests) and a large /var/tmp.
# In a live boot / is an overlay whose upper layer lives under /run, a small
# tmpfs, so /var/tmp is too -- and ostree stages container layers there.
# -----------------------------------
configure_live_units () {
    install -Dm0755 "${SRC}/immutablue-live-autoinstall.sh" /usr/libexec/immutablue-live/autoinstall
    install -Dm0644 "${SRC}/units/immutablue-live-autoinstall.service" \
        /usr/lib/systemd/system/immutablue-live-autoinstall.service
    install -Dm0644 "${SRC}/units/var-tmp.mount" /usr/lib/systemd/system/var-tmp.mount
    systemctl enable var-tmp.mount
    rm -rf /var/tmp
    mkdir -m 1777 /var/tmp
}


# -----------------------------------
# Root on ZFS (images with ZFS only): the installer, its desktop front end
# and launcher, pinned to the dash next to Anaconda's. Anaconda cannot
# create ZFS pools, so this is a separate path.
# -----------------------------------
configure_zfs_installer () {
    if ! command -v zpool > /dev/null
    then
        return 0
    fi
    install -Dm0755 "${SRC}/immutablue-zfs-install.sh" /usr/bin/immutablue-zfs-install
    install -Dm0755 "${SRC}/immutablue-zfs-install-gui.sh" /usr/bin/immutablue-zfs-install-gui
    install -Dm0644 "${SRC}/units/immutablue-zfs-install.desktop" \
        /usr/share/applications/immutablue-zfs-install.desktop

    # Branding: the launcher and the dialogs name the product being installed
    sed -i "s|^PRODUCT=.*|PRODUCT=\"${LIVE_NAME}\"|" /usr/bin/immutablue-zfs-install-gui
    sed -i -e "s|^Name=.*|Name=Install ${LIVE_NAME} on ZFS|" \
        -e "s|^Comment=Install Immutablue |Comment=Install ${LIVE_NAME} |" \
        /usr/share/applications/immutablue-zfs-install.desktop

    # The launcher runs the installer with 'sudo -n' as liveuser (who has no
    # password); allow exactly that, rather than relying on the image's wheel
    # policy
    echo 'liveuser ALL=(root) NOPASSWD: /usr/bin/immutablue-zfs-install' \
        > /etc/sudoers.d/90-immutablue-live-zfs-install
    chmod 0440 /etc/sudoers.d/90-immutablue-live-zfs-install
    visudo -cf /etc/sudoers.d/90-immutablue-live-zfs-install
}


# -----------------------------------
# Services that make sense on an installed system only: updates, first-boot
# provisioning, scheduled scripts, and ZFS pool import/mount (the live
# session must not claim a machine's pools; immutablue-zfs-install creates
# and imports its own). Disabled for the live session; the installed system
# gets the image's own presets.
# -----------------------------------
disable_installed_only_services () {
    local unit

    for unit in \
        immutablue-first-boot.service \
        immutablue-onboot.service \
        immutablue-hourly.timer \
        immutablue-daily.timer \
        immutablue-weekly.timer \
        immutablue-monthly.timer \
        rpm-ostreed-automatic.timer \
        rpm-ostree-countme.timer \
        bootloader-update.service \
        bootc-fetch-apply-updates.timer \
        flatpak-add-fedora-repos.service \
        greenboot-healthcheck.service \
        greenboot-set-rollback-trigger.service \
        zfs-import-cache.service \
        zfs-import-scan.service \
        zfs-mount.service \
        zfs-share.service \
        zfs-zed.service \
        zfs-load-keys.service
    do
        if systemctl list-unit-files "${unit}" > /dev/null 2>&1
        then
            systemctl disable "${unit}" || true
        fi
    done

    for unit in \
        immutablue-first-login.service \
        immutablue-onboot.service \
        immutablue-hourly.timer \
        immutablue-daily.timer \
        immutablue-weekly.timer \
        immutablue-monthly.timer \
        podman-auto-update.timer
    do
        if systemctl --global list-unit-files "${unit}" > /dev/null 2>&1
        then
            systemctl --global disable "${unit}" || true
        fi
    done
}


main () {
    create_symlink_targets
    install_packages
    configure_livesys
    configure_anaconda
    configure_live_units
    configure_zfs_installer
    disable_installed_only_services

    # The live session runs in UTC until the installer sets a timezone
    rm -f /etc/localtime
    systemd-firstboot --timezone UTC
}


main
