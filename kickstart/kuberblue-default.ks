# ==============================================================================
# Kuberblue Default Kickstart Configuration
# ==============================================================================
# Automates the Anaconda installer for kuberblue ISO builds so the install
# does not stall at disk selection, user creation, or locale prompts.
#
# This file is auto-selected when the build tag contains "kuberblue" and no
# higher-priority override is present. See makefiles/40-images.mk for the
# full kickstart override priority chain.
# ==============================================================================

# Text mode install — inst.noninteractive (injected into ISO boot args by
# osbuild stage patches) requires text or graphical mode to take effect.
# cmdline mode ignores inst.noninteractive, causing Anaconda to hang at
# "Installation complete. Press ENTER to quit:" instead of auto-rebooting.
text

# ------------------------------------------------------------------------------
# Locale and Keyboard
# ------------------------------------------------------------------------------
lang en_US.UTF-8
keyboard us
timezone UTC --utc

# ------------------------------------------------------------------------------
# Network
# ------------------------------------------------------------------------------
network --bootproto=dhcp --activate --onboot=yes

# ------------------------------------------------------------------------------
# Disk / Partitioning
# ------------------------------------------------------------------------------
# Use the first available disk. clearpart wipes existing partitions.
# autopart with btrfs matches the bootc-image-builder --rootfs btrfs flag.
zerombr
clearpart --all --initlabel
autopart --type=btrfs

# ------------------------------------------------------------------------------
# Bootloader
# ------------------------------------------------------------------------------
bootloader

# ------------------------------------------------------------------------------
# Security
# ------------------------------------------------------------------------------
firewall --enabled --service=ssh
selinux --enforcing

# ------------------------------------------------------------------------------
# User Configuration
# ------------------------------------------------------------------------------
# Root is locked. The kuberblue user account is locked — SSH key injection
# during bootstrapping is the only access path. No password backdoor.
rootpw --lock
user --name=kuberblue --groups=wheel --lock

# ------------------------------------------------------------------------------
# Post-install behavior
# ------------------------------------------------------------------------------
# Disable firstboot and accept EULA for headless/RHEL-derivative compatibility.
firstboot --disable
eula --agreed

# Power off after installation.
# NOTE: reboot --eject is the desired final form, but Fedora 43 Anaconda has a
# regression where RUNTIME.Reboot.action always defaults to -1 regardless of the
# kickstart command. installation_progress.py checks this value to decide whether
# to auto-exit post-install; without the %post fix below it would stall at
# "Installation complete. Press ENTER to quit:".
reboot --eject

# ------------------------------------------------------------------------------
# Post-install workaround: force RUNTIME.Reboot.action via D-Bus
# ------------------------------------------------------------------------------
# Fedora 43 Anaconda regression: RuntimeService.process_kickstart receives
# data.reboot.action=None from pykickstart, so RUNTIME.Reboot stays at -1.
# installation_progress.py checks `reboot_data.action in [KS_REBOOT, KS_SHUTDOWN]`
# and won't auto-exit if the value is -1. We fix this by setting the property
# directly over the Anaconda private D-Bus during %post (before the TUI check).
#
# Verified fix: busctl set-property with a{sv} correctly sets action=1 (KS_REBOOT).
# The D-Bus socket is at /tmp/dbus-* (single socket in the installer environment).
%post --nochroot
#!/bin/bash
set -euo pipefail

# Find the Anaconda private D-Bus socket — must be a socket file (type s),
# not a regular file or directory. -print -quit returns the first match only.
DBUS_SOCK=$(find /tmp -maxdepth 1 -name 'dbus-*' -type s -print -quit 2>/dev/null)
if [ -z "$DBUS_SOCK" ]; then
    echo "WARNING: Anaconda D-Bus socket not found in /tmp/dbus-*" >&2
    exit 0
fi

export DBUS_SESSION_BUS_ADDRESS="unix:path=${DBUS_SOCK}"

# Set RUNTIME.Reboot to KS_REBOOT=1 (matches 'reboot --eject' above)
# action=1, eject=true (for ISO ejection on reboot), kexec=false
if busctl --user set-property \
    org.fedoraproject.Anaconda.Modules.Runtime \
    /org/fedoraproject/Anaconda/Modules/Runtime \
    org.fedoraproject.Anaconda.Modules.Runtime \
    Reboot a{sv} 3 action i 1 eject b true kexec b false; then
    echo "kickstart: RUNTIME.Reboot.action set to KS_REBOOT (1)"
    # Verify the property was actually set — busctl can return 0 on type mismatch
    echo "kickstart: readback verification:"
    busctl --user get-property \
        org.fedoraproject.Anaconda.Modules.Runtime \
        /org/fedoraproject/Anaconda/Modules/Runtime \
        org.fedoraproject.Anaconda.Modules.Runtime \
        Reboot || echo "WARNING: get-property readback failed" >&2
else
    echo "WARNING: Failed to set RUNTIME.Reboot.action" >&2
fi
%end
