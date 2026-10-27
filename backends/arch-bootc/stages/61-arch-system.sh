#!/bin/bash
set -euxo pipefail
if [[ -f "${INSTALL_DIR}/build/99-common.sh" ]]; then source "${INSTALL_DIR}/build/99-common.sh"; fi
if [[ -f "./99-common.sh" ]]; then source "./99-common.sh"; fi

# 61-arch-system.sh (arch-bootc)
#
# System defaults a Fedora Atomic base image ships preset and Arch's does not:
# networking, time sync, DNS, the display manager, and no interactive
# systemd-firstboot. Runs right after the neutral 60-services.sh.

# Networking: NetworkManager where the image has it (every GUI variant),
# systemd-networkd with DHCP on any wired interface otherwise.
if [[ -f /usr/lib/systemd/system/NetworkManager.service ]]
then
    backend_svc enable NetworkManager.service
else
    # Match by Type=ether rather than by name to catch every naming scheme
    # (ens3, enp0s3, eth0, ...); without a .network file networkd ignores
    # every NIC, including a VM's virtio NIC.
    printf '[Match]\nType=ether\n\n[Network]\nDHCP=yes\n' \
        > /usr/lib/systemd/network/20-wired.network
    backend_svc enable systemd-networkd.service
fi

backend_svc enable systemd-resolved.service
backend_svc enable systemd-timesyncd.service

# resolv.conf is bind-mounted by the container runtime during the build, so it
# is pointed at systemd-resolved's stub by tmpfiles on first boot instead.
printf 'L! /etc/resolv.conf - - - - /run/systemd/resolve/stub-resolv.conf\n' \
    > /usr/lib/tmpfiles.d/resolv-conf.conf

# The machine is configured by Immutablue's own first-boot setup.
backend_svc mask systemd-firstboot.service

# GNOME variants log in through GDM.
if [[ -f /usr/lib/systemd/system/gdm.service ]]
then
    backend_svc enable gdm.service
fi

# Fedora's /etc/localtime exists in the base image; Arch's does not, and a
# missing one makes timedatectl and friends report nothing useful.
if [[ ! -e /etc/localtime ]]
then
    ln -sf /usr/share/zoneinfo/UTC /etc/localtime
fi
