# Filesystem Layout
# =================
# Creates the ostree/bootc-compatible filesystem structure.
# bootc expects:
#   /usr     - read-only OS content
#   /etc     - mutable config (3-way merge on upgrades)
#   /var     - persistent data
#   /sysroot - ostree deployment root

kind: script

build-depends:
- freedesktop-sdk.bst:bootstrap/bash.bst
- freedesktop-sdk.bst:bootstrap/coreutils.bst

config:
  commands:
  - |
    # Create the base directory structure for an ostree-native system
    mkdir -p "%{install-root}/usr/bin"
    mkdir -p "%{install-root}/usr/sbin"
    mkdir -p "%{install-root}/usr/lib"
    mkdir -p "%{install-root}/usr/lib64"
    mkdir -p "%{install-root}/usr/libexec"
    mkdir -p "%{install-root}/usr/share"
    mkdir -p "%{install-root}/usr/etc"
    mkdir -p "%{install-root}/etc"
    mkdir -p "%{install-root}/var"
    mkdir -p "%{install-root}/var/log"
    mkdir -p "%{install-root}/var/tmp"
    mkdir -p "%{install-root}/var/home"
    mkdir -p "%{install-root}/var/roothome"
    mkdir -p "%{install-root}/sysroot"
    mkdir -p "%{install-root}/boot"
    mkdir -p "%{install-root}/run"
    mkdir -p "%{install-root}/tmp"
    mkdir -p "%{install-root}/dev"
    mkdir -p "%{install-root}/proc"
    mkdir -p "%{install-root}/sys"

    # ostree-compatible symlinks
    # /home -> /var/home
    ln -sf var/home "%{install-root}/home"
    # /root -> /var/roothome
    ln -sf var/roothome "%{install-root}/root"
    # /opt -> /var/opt
    mkdir -p "%{install-root}/var/opt"
    ln -sf var/opt "%{install-root}/opt"
    # /mnt -> /var/mnt
    mkdir -p "%{install-root}/var/mnt"
    ln -sf var/mnt "%{install-root}/mnt"
    # /media -> /run/media
    ln -sf run/media "%{install-root}/media"

    # /bin, /sbin, /lib, /lib64 -> /usr/*
    ln -sf usr/bin "%{install-root}/bin"
    ln -sf usr/sbin "%{install-root}/sbin"
    ln -sf usr/lib "%{install-root}/lib"
    ln -sf usr/lib64 "%{install-root}/lib64"
