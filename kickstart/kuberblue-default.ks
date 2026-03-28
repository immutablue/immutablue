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

# Reboot automatically after installation and eject install media.
reboot --eject
