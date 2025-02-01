#!/bin/bash 
set -euxo pipefail 
if [ -f "${INSTALL_DIR}/build/99-common.sh" ]; then source "${INSTALL_DIR}/build/99-common.sh"; fi
if [ -f "./99-common.sh" ]; then source "./99-common.sh"; fi

mkdir -p /usr/lib64/nautilus/extensions-4
cp /mnt-nautilusopenwithcode/libnautilus-open-with-code.so /usr/lib64/nautilus/extensions-4/libnautilus-open-with-code.so
cp /mnt-yq/yq /usr/bin/yq
cp /mnt-dep-builder/blue2go/blue2go /usr/bin/blue2go
# cp /mnt-dep-builder/cpak/cpak /usr/bin/cpak
cp /mnt-dep-builder/zapper/zapper /usr/bin/zapper

