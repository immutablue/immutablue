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



