#!/bin/bash 
set -euxo pipefail 


mkdir -p "${INSTALL_DIR}"
cp -a /mnt-ctx/. "${INSTALL_DIR}/"
ls -l "${INSTALL_DIR}"
cp -a /mnt-ctx/artifacts/overrides/. /
echo "${IMMUTABLUE_BUILD_OPTIONS}" > "${INSTALL_DIR}/build_options"

# things depend on 'yq' heavily for build, so copy it early
cp /mnt-yq/yq /usr/bin/yq

mkdir -p /usr/lib64/nautilus/extensions-4
cp /mnt-nautilusopenwithcode/libnautilus-open-with-code.so /usr/lib64/nautilus/extensions-4/libnautilus-open-with-code.so
cp /mnt-build-deps/blue2go/blue2go /usr/bin/blue2go
cp /mnt-build-deps/cigar/src/cigar /usr/bin/cigar
# cp /mnt-build-deps/cpak/cpak /usr/bin/cpak
cp /mnt-build-deps/zapper/zapper /usr/bin/zapper

# the sourcing must come after we bootstrap the above
if [[ -f "${INSTALL_DIR}/build/99-common.sh" ]]; then source "${INSTALL_DIR}/build/99-common.sh"; fi
if [[ -f "./99-common.sh" ]]; then source "./99-common.sh"; fi


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
