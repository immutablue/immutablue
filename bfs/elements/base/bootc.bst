# bootc
# =====
# Boot and upgrade via container images.
# bootc is a Rust project that provides the bootc CLI for managing
# bootable container deployments.
#
# NOTE: bootc is written in Rust and requires cargo. We download
# a pre-built static binary for now. Once we have a Rust toolchain
# element, we can build from source.

kind: manual

depends:
- base/ostree.bst
- base/systemd.bst

sources:
# TODO: Build from source once Rust toolchain element exists.
# For now, we use a script element to fetch the latest release binary.
# This is a placeholder -- the actual binary will be fetched during build.
- kind: git
  url: github:containers/bootc.git
  track: main
  # ref populated by `bst source track`

config:
  # bootc is Rust -- we need cargo to build it
  # For the initial scaffold, document the build steps
  # but note this requires the Rust toolchain
  build-commands:
  - echo "bootc build requires Rust toolchain"
  - echo "TODO: Add Rust toolchain element or use pre-built binary"

  install-commands:
  # Placeholder: in production, this would install the bootc binary
  - mkdir -p "%{install-root}%{prefix}/bin"
  - mkdir -p "%{install-root}%{prefix}/lib/bootc"
  # bootc systemd units
  - mkdir -p "%{install-root}%{prefix}/lib/systemd/system"
