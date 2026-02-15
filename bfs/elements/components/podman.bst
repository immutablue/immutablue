# Podman
# ======
# Daemonless container engine. Essential for Immutablue's
# container-first workflow (distrobox, quadlets, etc.).
#
# Podman is written in Go. For the initial scaffold, we
# document the build path. Full Go toolchain integration
# will come later.

kind: manual

build-depends:
- freedesktop-sdk.bst:components/go.bst
- freedesktop-sdk.bst:components/gpgme.bst
- freedesktop-sdk.bst:components/bash.bst

depends:
- freedesktop-sdk.bst:components/systemd.bst
- freedesktop-sdk.bst:components/iptables.bst
- freedesktop-sdk.bst:components/fuse3.bst
- base/ostree.bst

sources:
- kind: git
  url: github:containers/podman.git
  track: main
  # ref populated by `bst source track`

config:
  build-commands:
  - make -j%{max-jobs} PREFIX=%{prefix}

  install-commands:
  - make install PREFIX=%{prefix} DESTDIR="%{install-root}"
