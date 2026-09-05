#!/bin/bash 
set -euxo pipefail 
if [[ -f "${INSTALL_DIR}/build/99-common.sh" ]]; then source "${INSTALL_DIR}/build/99-common.sh"; fi
if [[ -f "./99-common.sh" ]]; then source "./99-common.sh"; fi


# Syncthing overrides
SYNCTHING_SVC_FILE="/usr/lib/systemd/user/syncthing.service"
SYNCTHING_WRAPPED_FILE="/usr/lib/systemd/user/syncthing-override.service"

if [[ -f "${SYNCTHING_SVC_FILE}" ]]
then 
    rm "${SYNCTHING_SVC_FILE}"
    ln -s "${SYNCTHING_WRAPPED_FILE}" "${SYNCTHING_SVC_FILE}"
fi


# add cyan justfile
if [[ "$(is_option_in_build_options cyan)" == "${TRUE}" ]]
then 
    echo -e 'import "./10-cyan.justfile"\n' >> /usr/libexec/immutablue/just/Justfile
fi

# add asahi justfile
if [[ "$(is_option_in_build_options asahi)" == "${TRUE}" ]]
then 
    echo -e 'import "./25-asahi.justfile"\n' >> /usr/libexec/immutablue/just/Justfile
fi

# add kuberblue justfile
if [[ "$(is_option_in_build_options kuberblue)" == "${TRUE}" ]]
then
    echo -e 'import "./30-kuberblue.justfile"\n' >> /usr/libexec/immutablue/just/Justfile

    # BIB (bootc-image-builder) reads /usr/lib/os-release and detects distro as
    # kuberblue-42 (the base Silverblue layer). It then resolves $releasever=42 for
    # repo GPG key lookups. The rpmfusion package was installed in the Fedora 43
    # context so only RPM-GPG-KEY-rpmfusion-free-fedora-43 exists. Symlink the 2020
    # key (used for F33-F42) as the fedora-42 entry so BIB can depsolve the installer.
    #
    # Scope: kuberblue-only is correct. Other variants use ID=fedora (not ID=kuberblue)
    # in os-release, so BIB uses its built-in fedora-42 distro def which already has
    # correct GPG key paths. Only kuberblue overrides ID to trigger the custom def.
    if [[ -f /etc/pki/rpm-gpg/RPM-GPG-KEY-rpmfusion-free-fedora-2020 ]] && \
       [[ ! -f /etc/pki/rpm-gpg/RPM-GPG-KEY-rpmfusion-free-fedora-42 ]]; then
        ln -s RPM-GPG-KEY-rpmfusion-free-fedora-2020 \
              /etc/pki/rpm-gpg/RPM-GPG-KEY-rpmfusion-free-fedora-42
    fi
    if [[ -f /etc/pki/rpm-gpg/RPM-GPG-KEY-rpmfusion-nonfree-fedora-2020 ]] && \
       [[ ! -f /etc/pki/rpm-gpg/RPM-GPG-KEY-rpmfusion-nonfree-fedora-42 ]]; then
        ln -s RPM-GPG-KEY-rpmfusion-nonfree-fedora-2020 \
              /etc/pki/rpm-gpg/RPM-GPG-KEY-rpmfusion-nonfree-fedora-42
    fi
fi


# -----------------------------------
# Setup-marker directory permissions.
#
# This directory holds the "already ran" markers that gate first-boot setup
# (did_first_boot, did_first_boot_graphical, did_first_boot_setup). It used to
# be chmod 777, which let ANY local user -- including one with no
# administrative rights -- suppress first-boot setup for the whole machine by
# pre-creating a marker, or force it to re-run by deleting one.
#
# The markers do have to be writable by a logged-in human, because
# first_boot_graphical.sh runs in the user's session rather than as root. So
# the directory is group-writable by 'wheel' instead of world-writable: an
# administrator can still write a marker without sudo, and an unprivileged
# user can no longer tamper with the setup state. Anyone in wheel could
# already obtain root, so this grants them nothing new.
# -----------------------------------
chown -R root:wheel /etc/immutablue/setup
chmod 0775 /etc/immutablue/setup
find /etc/immutablue/setup -type f -exec chmod 0664 {} +

# build hugo files (skip if is_skipped hugo or if docs submodule is not initialized)
if [[ "$(is_skipped hugo)" == "${FALSE}" ]] && [[ -d "/usr/immutablue/docs/content" ]]
then
    bash -c "cd /usr/immutablue/docs && hugo build"
else
    echo "Skipping Hugo build (SKIP=${SKIP:-} or docs not initialized)"
fi

# remove debug modules
 rm -rf /usr/lib/modules/*+debug

# Clear /boot — bootc manages the boot partition externally from the container
# image. Kernel RPM %posttrans (dracut) and grub2 scriptlets that ran during
# dnf5 transactions can pollute /boot with initramfs, symvers, and bootloader
# config (e.g. extlinux), which trips the bootc nonempty-boot lint and may
# conflict with bootupd at install time. The kernel/modules live in
# /usr/lib/modules/$kver and bootc regenerates initramfs at deploy.
find /boot -mindepth 1 -delete 2>/dev/null || true

# -----------------------------------
# Record the image's identity for the installed system.
#
# Runtime code previously had to recover this by scraping rpm-ostree:
#
#     rpm-ostree status | grep -i quay | head -n 1 | awk -F/ '{ print $3 }'
#
# which silently returns the wrong answer, or nothing, if the image is hosted
# anywhere other than quay.io, if a second quay-hosted deployment is present
# (the common case immediately after a rebase, when the previous deployment is
# still listed), or if rpm-ostree's output format shifts. The variant was then
# inferred by splitting the tag on '-'.
#
# The build already knows all of this exactly, so write it down once here and
# let the runtime read a fact instead of re-deriving a guess. The getters in
# immutablue-header.sh prefer this file and keep the scrape as a fallback for
# images built before it existed.
# -----------------------------------
IMAGE_INFO_DIR="/usr/share/immutablue"
IMAGE_INFO_FILE="${IMAGE_INFO_DIR}/image-info.json"

mkdir -p "${IMAGE_INFO_DIR}"

# IMAGE_TAG is passed by the Makefile as '<name>:<tag>' (e.g. immutablue:43-lts).
image_info_base="${IMAGE_TAG%%:*}"
image_info_tag="${IMAGE_TAG#*:}"

# The source commit is genuinely useful provenance: it ties a running system
# back to the tree that produced it. 10-copy.sh shrinks the shipped history but
# keeps the built commit, so this resolves in a normal build and is left empty
# when the source tree is unavailable.
image_info_commit="$(git -C "${INSTALL_DIR}" rev-parse HEAD 2>/dev/null || echo "")"

# Build options are a CSV list (e.g. "silverblue,gui"); emit them as a JSON
# array so consumers do not have to re-split a string.
image_info_variants="$(
    printf '%s' "${IMMUTABLUE_BUILD_OPTIONS:-}" \
        | tr ',' '\n' \
        | grep -v '^$' \
        | sed 's/.*/"&"/' \
        | paste -sd ',' -
)"

cat > "${IMAGE_INFO_FILE}" <<EOF
{
  "image": "${image_info_base}",
  "tag": "${image_info_tag}",
  "version": "${FEDORA_VERSION}",
  "base_image": "${BASE_IMAGE:-}",
  "variants": [${image_info_variants}],
  "source_commit": "${image_info_commit}",
  "built": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

chmod 0644 "${IMAGE_INFO_FILE}"
cat "${IMAGE_INFO_FILE}"

# rebuild font cache (picks up nerd-fonts and any other new fonts)
fc-cache -fv

# Release the build-time kernel versionlock set in 30-install-packages.sh.
#
# The lock exists only to stop a later dnf5 transaction from pulling a kernel
# newer than the one the ZFS DKMS and NVIDIA kmod builds compiled against. It
# must not ship: on the installed system it would silently constrain
# rpm-ostree layering. 'clear' leaves an empty stanza behind, so the file
# itself is removed.
if command -v dnf5 >/dev/null 2>&1
then
    dnf5 -y versionlock clear || true
    rm -f /etc/dnf/versionlock.toml
fi
