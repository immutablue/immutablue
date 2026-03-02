#!/bin/bash
set -euxo pipefail

source /usr/libexec/kuberblue/variables.sh

# Create 'kuberblue' system user with no sudo access.
# Uses its own kuberblue group — not wheel — to avoid privilege escalation.
if ! id kuberblue &>/dev/null; then
    useradd \
        --system \
        --user-group \
        --uid "${KUBERBLUE_UID}" \
        --shell /bin/bash \
        --home-dir /var/home/kuberblue \
        --create-home \
        kuberblue
fi

# Ensure state directory is accessible to the kuberblue user
mkdir -p "${STATE_DIR}"
chmod 0750 "${STATE_DIR}"
chown root:kuberblue "${STATE_DIR}"
