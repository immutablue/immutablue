#!/bin/bash
set -euxo pipefail
if [[ -f "${INSTALL_DIR}/build/99-common.sh" ]]; then source "${INSTALL_DIR}/build/99-common.sh"; fi
if [[ -f "./99-common.sh" ]]; then source "./99-common.sh"; fi

# 11-freebsd-system.sh (freebsd-be)
#
# Bridges Immutablue's Linux-shaped paths onto FreeBSD right after
# 10-copy.sh has laid the overrides down:
#
#   - bash is a package on FreeBSD (/usr/local/bin/bash), but every Immutablue
#     script, unit and justfile names /bin/bash or /usr/bin/bash.
#   - ZFS is required: updates are boot environments.

for link in /bin/bash /usr/bin/bash
do
    if [[ ! -e "${link}" ]]
    then
        ln -s /usr/local/bin/bash "${link}"
    fi
done

sysrc zfs_enable=YES

# The rc.d scripts and cron table shipped in overrides/ must be executable /
# root-owned for rc(8) and cron(8) to accept them.
chmod 0555 /usr/local/etc/rc.d/immutablue_first_boot /usr/local/etc/rc.d/immutablue_onboot
chmod 0644 /etc/cron.d/immutablue
