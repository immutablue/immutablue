#!/bin/bash 
set -euxo pipefail 
if [ -f "${INSTALL_DIR}/build/99-common.sh" ]; then source "${INSTALL_DIR}/build/99-common.sh"; fi
if [ -f "./99-common.sh" ]; then source "./99-common.sh"; fi

cp /mnt-nautilusopenwithcode/libnautilus-open-with-code.so /usr/lib64/nautilus/extensions-4/libnautilus-open-with-code.so
cp /mnt-yq/yq /usr/bin/yq

