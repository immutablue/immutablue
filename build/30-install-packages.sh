#!/bin/bash 
set -euxo pipefail
if [ -f "${INSTALL_DIR}/build/99-common.sh" ]; then source "${INSTALL_DIR}/build/99-common.sh"; fi
if [ -f "./99-common.sh" ]; then source "./99-common.sh"; fi


pkgs=$(get_immutablue_packages)
pkg_urls=$(get_immutablue_package_urls)
pip_pkgs=$(get_immutablue_pip_packages)


# Add ublue udev rules
rpm-ostree install /mnt-ublue-config/ublue-os-udev-rules*.rpm 
if [[ "$DO_INSTALL_AKMODS" == "true" ]]
then 
    rpm-ostree install /mnt-ublue-akmods/ublue-os/ublue-os-akmods-addons*.rpm
    rpm-ostree install /mnt-ublue-akmods/kmods/kmod-{framework,openrazer,xone}-*.rpm
fi


# Install rpm_urls
if [[ "$pkg_urls" != "" ]]
then
    rpm-ostree install $(for pkg in $pkg_urls; do printf '%s ' $pkg; done)
fi


# Install immutablue packages
if [[ "$pkgs" != "" ]]
then 
    rpm-ostree install $(for pkg in $pkgs; do printf '%s ' $pkg; done)
fi


# LTS Kernel
if [[ "$DO_INSTALL_LTS" == "true" ]]
then 
    curl -Lo "/etc/yum.repos.d/kwizart-kernel-longterm-${LTS_VERSION}-fedora-41.repo" "${LTS_REPO_URL}"
    # ------------------------------------------------------------------------------|
    # rpm-ostree override replace \
    #     --from repo="copr:copr.fedorainfracloud.org:kwizart:kernel-longterm-${LTS_VERSION}" \
    #     --experimental \
    #     --remove=kernel \
    #     --remove=kernel-core \
    #     --remove=kernel-modules \
    #     --remove=kernel-modules-extra \
    #     kernel-longterm{,-core,-modules,-modules-extra,-devel}
    # ------------------------------------------------------------------------------|
    # Hacky -- but the above seems to sometimes fail because kernel-core gets
    # flagged sometimes as protected but is not under /etc/dnf/protected.d/
    # - https://github.com/rpm-software-management/dnf5/issues/1909
    dnf5 remove -y --setopt protect_running_kernel=false kernel{,-core,-modules,-modules-extra}
    rpm-ostree install kernel-longterm{,-core,-modules,-modules-extra,-devel}
fi

# ZFS handling
# do zfs install with LTS by default
if [[ "$DO_INSTALL_ZFS" == "true" ]] || [[ "$DO_INSTALL_LTS" == "true" ]]
then 
    rpm-ostree install "${ZFS_RPM_URL}"
    rpm-ostree override replace \
        --from repo='zfs' \
        --experimental \
        --remove=zfs-fuse \
        zfs{,-dracut}

    ZFS_VERSION=$(dkms status | grep -i zfs | awk '{ printf "%s\n", $1 }' | awk -F/ '{ printf "%s\n", $2 }')
    KERNEL_SUFFIX=""
    if [[ "$DO_INSTALL_LTS" == "true" ]]; then KERNEL_SUFFIX="longterm"; fi
    KERNEL_VERSION=$(rpm -qa | grep -P 'kernel-(|'"$KERNEL_SUFFIX"'-)(\d+\.\d+\.\d+)' | sed -E 's/kernel-(|'"$KERNEL_SUFFIX"'-)//')

    # Since we replaced the kernel, force a rebuild of the zfs dkms
    dkms build -m zfs -v ${ZFS_VERSION:0:-1} -k ${KERNEL_VERSION} --force
    dkms install -m zfs -v ${ZFS_VERSION:0:-1} -k ${KERNEL_VERSION} --force
    echo 'zfs' >> "${MODULES_CONF}"
fi


# pip package handling
if [[ "$pip_pkgs" != "" ]]
then 
    pip3 install --prefix=/usr $(for pkg in $pip_pkgs; do printf '%s ' $pkg; done)
fi


# Install modern build of hugo
# (fedora has ancient version in its repos)
curl -Lo /tmp/hugo.tar.gz "${HUGO_RELEASE_URL}"
tar -xzf /tmp/hugo.tar.gz -C /usr/bin/ hugo
rm /tmp/hugo.tar.gz
hugo version

