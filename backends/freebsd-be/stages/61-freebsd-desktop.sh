#!/bin/bash
set -euxo pipefail
if [[ -f "${INSTALL_DIR}/build/99-common.sh" ]]; then source "${INSTALL_DIR}/build/99-common.sh"; fi
if [[ -f "./99-common.sh" ]]; then source "./99-common.sh"; fi

# 61-freebsd-desktop.sh (freebsd-be)
#
# GNOME variants: the display manager and the system bus it needs, which a
# Fedora or Arch base enables through systemd presets and FreeBSD leaves off.
# Runs after 60-services.sh, once 30-install-packages.sh has installed gdm.
if [[ -x /usr/local/etc/rc.d/gdm ]]
then
    sysrc dbus_enable=YES gdm_enable=YES
fi
