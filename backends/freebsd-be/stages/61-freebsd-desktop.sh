#!/bin/bash
set -euxo pipefail
if [[ -f "${INSTALL_DIR}/build/99-common.sh" ]]; then source "${INSTALL_DIR}/build/99-common.sh"; fi
if [[ -f "./99-common.sh" ]]; then source "./99-common.sh"; fi

# 61-freebsd-desktop.sh (freebsd-be)
#
# GNOME variants: the display manager (LightDM, configured in
# overrides/usr/local/etc/lightdm/lightdm.conf.d/) and the system bus it
# needs, which a Fedora or Arch base enables through systemd presets and
# FreeBSD leaves off,
# and the scfb framebuffer driver where no DRM device exists
# (rc.d/immutablue_xorg). procfs on /proc, which GNOME also requires, is
# mounted on every image (stage 11).
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
# The display manager is chosen per machine: gdm (GNOME's lock screen works;
# FreeBSD's gdm is X11-only, so it never lists wayland-sessions) or LightDM
# (gowl and CMacs at login; GNOME sessions cannot lock under it). The setting is
# .immutablue.freebsd.display_manager, and rc.d/immutablue_dm turns it into
# /etc/rc.conf.d/{gdm,lightdm} at each boot. rc.conf itself keeps both at NO:
# deliver.sh applies the image's rc.conf keys over a machine's on every
# update, which would undo any choice written there.
if [[ -x /usr/local/etc/rc.d/lightdm ]] && [[ -x /usr/local/etc/rc.d/gdm ]]
then
    sysrc dbus_enable=YES gdm_enable=NO lightdm_enable=NO immutablue_dm_enable=YES \
        immutablue_xorg_enable=YES immutablue_drm_enable=YES
fi

# The FreeBSD recipes (display_manager, ...), imported the way 90-post.sh
# imports the variant justfiles.
if [[ -f /usr/libexec/immutablue/just/12-freebsd.justfile ]] && \
   ! grep -q '12-freebsd.justfile' /usr/libexec/immutablue/just/Justfile
then
    echo -e 'import "./12-freebsd.justfile"\n' >> /usr/libexec/immutablue/just/Justfile
fi

# LightDM runs every session through its session-wrapper, Xsession, handing it
# the session's whole Exec line as ONE argument; the port's wrapper ends in
# 'exec $@', whose word splitting breaks any Exec with quotes in it -- gowl's
# and CMacs's ('/bin/sh -c '\''gowl; ...'\''') died with "Unterminated quoted
# string". 'eval exec "$@"' parses the line once, as a shell would.
xsession=/usr/local/etc/lightdm/Xsession
if [[ -f "${xsession}" ]] && grep -q '^exec \$@$' "${xsession}"
then
    sed 's/^exec \$@$/eval exec "$@"/' "${xsession}" > "${xsession}.tmp"
    cat "${xsession}.tmp" > "${xsession}"
    rm -f "${xsession}.tmp"
fi

# wlroots compositors (gowl, cmacs --gowl) open the display and input devices
# through libseat, which on FreeBSD talks to seatd; users reach its socket
# through the video group (the installer adds its user there). Here rather
# than in stage 11, which runs before 30-install-packages.sh installs seatd.
if [[ -x /usr/local/etc/rc.d/seatd ]]
then
    sysrc seatd_enable=YES
fi

# GNOME on Wayland needs logind and does not run on FreeBSD; its
# wayland-sessions entries would sit in the greeter's list beside the
# working X11 GNOME, under the same names. Only GNOME's are removed: gowl's
# and CMacs's are the reason LightDM is here.
rm -f /usr/local/share/wayland-sessions/gnome.desktop \
    /usr/local/share/wayland-sessions/gnome-wayland.desktop \
    /usr/local/share/wayland-sessions/gnome-classic.desktop \
    /usr/local/share/wayland-sessions/gnome-classic-wayland.desktop

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
