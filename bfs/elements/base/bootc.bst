# bootc
# =====
# Boot and upgrade via container images.
# bootc is a Rust project that provides the bootc CLI for managing
# bootable container deployments.
#
# NOTE: bootc is written in Rust and requires cargo. This is a
# placeholder element -- building from source needs a Rust toolchain
# element. For now it just creates the directory structure.

kind: manual

depends:
- base/ostree.bst
- base/systemd.bst

sources:
- kind: git
  url: github:containers/bootc.git
  track: main
  # ref populated by `bst source track`

  ref: 6ac06b772d77c2743b016852cf364be46462aae8
config:
  build-commands:
  - |
    echo "bootc build requires Rust toolchain -- placeholder only"

  install-commands:
  - |
    mkdir -p "%{install-root}%{prefix}/bin"
    mkdir -p "%{install-root}%{prefix}/lib/bootc"
    mkdir -p "%{install-root}%{prefix}/lib/systemd/system"
