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

# /usr read-only at runtime, as ostree makes it on the Linux backends
# (rc.d/immutablue_readonly_usr; /usr/local/etc stays writable).
sysrc immutablue_readonly_usr_enable=YES

# Linux binary compatibility: the Linuxulator at boot (rc.d/linux, which also
# mounts Linux's /proc, /sys and /dev under /compat/linux), and
# rc.d/immutablue_linux_compat, which shares /home and /tmp into the Linux
# userland -- or creates it on first boot (immutablue-linux setup; settings
# .immutablue.linux_compat.*). The userland is a ZFS dataset of its own,
# kept across updates by deliver.sh.
sysrc linux_enable=YES immutablue_linux_compat_enable=YES

# podman's default bridge network needs pf NAT: rc.d/immutablue_podman_pf
# writes /etc/pf.conf (one NAT rule per interface, from podman's sample) on
# each boot before pf starts -- unless the machine has a pf.conf of its own --
# and mounts fdescfs on /dev/fd, which podman also needs.
sysrc pf_enable=YES immutablue_podman_pf_enable=YES

# The rc.d scripts and cron table shipped in overrides/ must be executable /
# root-owned for rc(8) and cron(8) to accept them.
chmod 0555 /usr/local/etc/rc.d/immutablue_first_boot /usr/local/etc/rc.d/immutablue_onboot /usr/local/etc/rc.d/immutablue_procfs /usr/local/etc/rc.d/immutablue_readonly_usr /usr/local/etc/rc.d/immutablue_xorg /usr/local/etc/rc.d/immutablue_linux_compat /usr/local/etc/rc.d/immutablue_podman_pf
chmod 0755 /usr/bin/immutablue-linux /usr/local/bin/brew
chmod 0644 /etc/cron.d/immutablue /etc/profile.d/30-immutablue-linux.sh

# sudo on FreeBSD reads /usr/local/etc/sudoers.d only; the backend overrides
# carry the FreeBSD versions of the shared /etc/sudoers.d drop-ins, which are
# removed so nothing suggests they are in effect. sudo ignores drop-ins that
# are group- or world-writable, so the modes are set explicitly.
rm -rf /etc/sudoers.d
chown root:wheel /usr/local/etc/sudoers.d /usr/local/etc/sudoers.d/immutablue-*
chmod 0440 /usr/local/etc/sudoers.d/immutablue-*
