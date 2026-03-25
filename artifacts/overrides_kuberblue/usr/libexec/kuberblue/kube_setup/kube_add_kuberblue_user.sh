#!/bin/bash
set -euxo pipefail

source /usr/libexec/kuberblue/variables.sh

# Create 'kuberblue' system user with no sudo access.
# Uses its own kuberblue group — not wheel — to avoid privilege escalation.
if ! id kuberblue &>/dev/null; then
    local_uid="$(kuberblue_uid)"
    # If the desired UID is already taken by another user, let the system
    # assign the next available UID instead of failing the entire provisioning.
    if getent passwd "${local_uid}" &>/dev/null; then
        echo "WARNING: UID ${local_uid} already in use by $(getent passwd "${local_uid}" | cut -d: -f1), using auto-assigned UID"
        useradd \
            --system \
            --user-group \
            --shell /bin/bash \
            --home-dir /var/home/kuberblue \
            --create-home \
            kuberblue
    else
        useradd \
            --system \
            --user-group \
            --uid "${local_uid}" \
            --shell /bin/bash \
            --home-dir /var/home/kuberblue \
            --create-home \
            kuberblue
    fi
fi

# Ensure state directory is accessible to the kuberblue user
mkdir -p "${STATE_DIR}"
chmod 0750 "${STATE_DIR}"
chown root:kuberblue "${STATE_DIR}"
