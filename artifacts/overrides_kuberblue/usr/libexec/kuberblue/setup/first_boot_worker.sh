#!/bin/bash
set -euo pipefail

source /usr/libexec/kuberblue/99-common.sh

mkdir -p /etc/kuberblue

if [[ ! -f /etc/kuberblue/did_first_boot ]]; then
    echo "First boot: joining as worker..."
    /usr/libexec/kuberblue/worker_boot.sh
    touch /etc/kuberblue/did_first_boot
else
    echo "Subsequent boot: resuming worker role..."
    /usr/libexec/kuberblue/worker_boot.sh
fi