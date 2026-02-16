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
- freedesktop-sdk.bst:bootstrap/bash.bst

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

  ref: 09faf7844105459a37ec74e8e92aca925456e040
config:
  build-commands:
  - make -j%{max-jobs} PREFIX=%{prefix}

  install-commands:
  - make install PREFIX=%{prefix} DESTDIR="%{install-root}"
