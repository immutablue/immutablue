#!/bin/bash
set -euxo pipefail

CMD="$1"
MSG="${2:-Running command as kuberblue user...}"
MAX_RETRIES=12
RETRY_INTERVAL=10

echo "${MSG}"

# Use the kuberblue user's own kubeconfig copy — NOT /etc/kubernetes/admin.conf
# which is root:root 0600 and unreadable by the kuberblue user.
KUBERBLUE_KUBECONFIG="/var/home/kuberblue/.kube/config"

i=0
until su -l -s /bin/bash kuberblue -c "export KUBECONFIG='${KUBERBLUE_KUBECONFIG}'; ${CMD}"; do
    i=$((i + 1))
    if [[ ${i} -ge ${MAX_RETRIES} ]]; then
        echo "ERROR: Command failed after ${MAX_RETRIES} attempts: ${CMD}"
        exit 1
    fi
    echo "Attempt ${i}/${MAX_RETRIES} failed, retrying in ${RETRY_INTERVAL}s..."
    sleep "${RETRY_INTERVAL}"
done
