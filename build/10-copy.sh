#!/bin/bash 
set -euxo pipefail 


mkdir -p "${INSTALL_DIR}"
cp -a /mnt-ctx/. "${INSTALL_DIR}/"
ls -l "${INSTALL_DIR}"
cp -a /mnt-ctx/artifacts/overrides/. /
echo "${IMMUTABLUE_BUILD_OPTIONS}" > "${INSTALL_DIR}/build_options"

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


mkdir -p /usr/lib64/nautilus/extensions-4
cp /mnt-nautilusopenwithcode/libnautilus-open-with-code.so /usr/lib64/nautilus/extensions-4/libnautilus-open-with-code.so
cp /mnt-yq/yq /usr/bin/yq
cp /mnt-dep-builder/blue2go/blue2go /usr/bin/blue2go
cp /mnt-dep-builder/cpak/cpak /usr/bin/cpak
cp /mnt-dep-builder/zapper/zapper /usr/bin/zapper

