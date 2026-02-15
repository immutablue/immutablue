# Linux Kernel
# ============
# Builds the Linux kernel from source with a config suitable for
# a bootc-based desktop system. The kernel is installed to
# /usr/lib/modules/$kver/vmlinuz as required by bootc.

kind: manual

build-depends:
- freedesktop-sdk.bst:bootstrap/linux-headers.bst
- freedesktop-sdk.bst:components/bison.bst
- freedesktop-sdk.bst:components/flex.bst
- freedesktop-sdk.bst:components/perl.bst
- freedesktop-sdk.bst:components/openssl.bst
- freedesktop-sdk.bst:components/kmod.bst
- freedesktop-sdk.bst:bootstrap/elfutils.bst

runtime-depends:
- freedesktop-sdk.bst:components/kmod.bst

sources:
- kind: tar
  url: kernel:v%{kernel-major}.x/linux-%{kernel-version}.tar.xz
  # ref will be populated by `bst source track`

variables:
  kernel-arch: x86_64

config:
  configure-commands:
  # Start from a distribution-quality defconfig
  - make defconfig

  # Enable key features for bootc/ostree desktop
  - ./scripts/config --enable CONFIG_OVERLAY_FS
  - ./scripts/config --enable CONFIG_SQUASHFS
  - ./scripts/config --enable CONFIG_EROFS_FS
  - ./scripts/config --enable CONFIG_BLK_DEV_LOOP
  - ./scripts/config --enable CONFIG_FUSE_FS
  - ./scripts/config --enable CONFIG_VIRTIO
  - ./scripts/config --enable CONFIG_VIRTIO_PCI
  - ./scripts/config --enable CONFIG_VIRTIO_BLK
  - ./scripts/config --enable CONFIG_VIRTIO_NET
  - ./scripts/config --enable CONFIG_DRM
  - ./scripts/config --enable CONFIG_DRM_AMDGPU
  - ./scripts/config --enable CONFIG_DRM_I915
  - ./scripts/config --enable CONFIG_DRM_NOUVEAU
  - ./scripts/config --enable CONFIG_DRM_VIRTIO_GPU
  - ./scripts/config --enable CONFIG_USB_STORAGE
  - ./scripts/config --enable CONFIG_EXT4_FS
  - ./scripts/config --enable CONFIG_BTRFS_FS
  - ./scripts/config --enable CONFIG_XFS_FS
  - ./scripts/config --enable CONFIG_VFAT_FS
  - ./scripts/config --enable CONFIG_NLS_CODEPAGE_437
  - ./scripts/config --enable CONFIG_NLS_ISO8859_1
  - ./scripts/config --enable CONFIG_SECURITY_SELINUX
  - ./scripts/config --enable CONFIG_SECURITY_SELINUX_BOOTPARAM

  # Composefs support (required for bootc composefs backend)
  - ./scripts/config --enable CONFIG_EROFS_FS_COMPOSEFS

  # Cgroups v2 (required for modern container runtimes)
  - ./scripts/config --enable CONFIG_CGROUP_BPF
  - ./scripts/config --enable CONFIG_BPF_SYSCALL

  # Refresh config after enabling options
  - make olddefconfig

  build-commands:
  - make -j%{max-jobs} bzImage
  - make -j%{max-jobs} modules

  install-commands:
  - |
    KVER=$(make kernelrelease)
    make modules_install INSTALL_MOD_PATH="%{install-root}/usr"
    install -Dm644 arch/x86/boot/bzImage \
      "%{install-root}/usr/lib/modules/${KVER}/vmlinuz"
    # depmod for module dependency resolution
    depmod -b "%{install-root}/usr" "${KVER}"
