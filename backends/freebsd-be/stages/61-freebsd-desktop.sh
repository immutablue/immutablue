#!/bin/bash
set -euxo pipefail
if [[ -f "${INSTALL_DIR}/build/99-common.sh" ]]; then source "${INSTALL_DIR}/build/99-common.sh"; fi
if [[ -f "./99-common.sh" ]]; then source "./99-common.sh"; fi

# 61-freebsd-desktop.sh (freebsd-be)
#
# GNOME variants: the display manager and the system bus it needs, which a
# Fedora or Arch base enables through systemd presets and FreeBSD leaves off,
# procfs on /proc (rc.d/immutablue_procfs), which GNOME requires, and the
# scfb framebuffer driver where no DRM device exists (rc.d/immutablue_xorg).
# gdm runs the first-login setup as the gnome-initial-setup user, which
# Linux creates through sysusers.d and the FreeBSD port does not create at
# all: without it gdm logs "couldn't look up username gnome-initial-setup"
# and never shows a greeter on a machine with no users.
# The gnome-session port's xsessions/gnome.desktop has arguments in TryExec
# (TryExec=/usr/local/bin/gnome-session --disable-acceleration-check). TryExec
# names a program, so gdm finds no such file and hides "GNOME"; it also hides
# the -xorg duplicates of sessions that exist, which leaves only GNOME
# Classic in the session menu. The arguments are dropped from TryExec (Exec
# keeps them).
# Runs after 60-services.sh, once 30-install-packages.sh has installed gdm.
if [[ -x /usr/local/etc/rc.d/gdm ]]
then
    sysrc dbus_enable=YES gdm_enable=YES immutablue_procfs_enable=YES immutablue_xorg_enable=YES
fi

if [[ -x /usr/local/libexec/gnome-initial-setup ]] && ! pw usershow gnome-initial-setup > /dev/null 2>&1
then
    pw groupadd gnome-initial-setup
    pw useradd gnome-initial-setup -g gnome-initial-setup -c "GNOME Initial Setup" \
        -d /var/lib/gnome-initial-setup -s /usr/sbin/nologin
    mkdir -p /var/lib/gnome-initial-setup
    chown gnome-initial-setup:gnome-initial-setup /var/lib/gnome-initial-setup
fi

for session in /usr/local/share/xsessions/*.desktop
do
    [[ -f "${session}" ]] || continue
    if grep -q '^TryExec=[^ ]* ' "${session}"
    then
        sed 's|^TryExec=\([^ ]*\) .*|TryExec=\1|' "${session}" > "${session}.tmp"
        cat "${session}.tmp" > "${session}"
        rm -f "${session}.tmp"
    fi
done
