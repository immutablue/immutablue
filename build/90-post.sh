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


# set /etc/immutablue/setup to world-writable
chmod -R 777 /etc/immutablue/setup

# build hugo files (skip if is_skipped hugo or if docs submodule is not initialized)
if [[ "$(is_skipped hugo)" == "${FALSE}" ]] && [[ -d "/usr/immutablue/docs/content" ]]
then
    bash -c "cd /usr/immutablue/docs && hugo build"
else
    echo "Skipping Hugo build (SKIP=${SKIP:-} or docs not initialized)"
fi

# remove debug modules
 rm -rf /usr/lib/modules/*+debug

# rebuild font cache (picks up nerd-fonts and any other new fonts)
fc-cache -fv
