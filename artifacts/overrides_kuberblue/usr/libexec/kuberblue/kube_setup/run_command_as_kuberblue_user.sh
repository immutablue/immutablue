#!/bin/bash
set -euxo pipefail

CMD="$1"
MSG="${2:-Running command as kuberblue user...}"
MAX_RETRIES=12
RETRY_INTERVAL=10

echo "${MSG}"

i=0
KUBECONFIG="${KUBECONFIG:-/etc/kubernetes/admin.conf}"
until su -l -c "KUBECONFIG=${KUBECONFIG} ${CMD}" kuberblue; do
    i=$((i + 1))
    if [[ ${i} -ge ${MAX_RETRIES} ]]; then
        echo "ERROR: Command failed after ${MAX_RETRIES} attempts: ${CMD}"
        exit 1
    fi
    echo "Attempt ${i}/${MAX_RETRIES} failed, retrying in ${RETRY_INTERVAL}s..."
    sleep "${RETRY_INTERVAL}"
done
