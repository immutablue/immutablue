# dracut
# ======
# Initramfs generator. Produces the initramfs image that bootc
# expects at /usr/lib/modules/$kver/initramfs.img

kind: manual

build-depends:
- freedesktop-sdk.bst:bootstrap/bash.bst
- freedesktop-sdk.bst:bootstrap/coreutils.bst

depends:
- base/systemd.bst
- freedesktop-sdk.bst:components/kmod.bst
- freedesktop-sdk.bst:components/util-linux.bst
- freedesktop-sdk.bst:bootstrap/bash.bst
- freedesktop-sdk.bst:bootstrap/coreutils.bst

sources:
- kind: git
  url: github:dracut-ng/dracut-ng.git
  track: main
  # ref populated by `bst source track`

config:
  configure-commands:
  - ./configure --prefix=%{prefix} --sysconfdir=%{sysconfdir}

  build-commands:
  - make -j%{max-jobs}

  install-commands:
  - make install DESTDIR="%{install-root}"
