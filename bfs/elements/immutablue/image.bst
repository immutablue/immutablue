# Immutablue BFS Image
# ====================
# Top-level composition element that aggregates all components
# into a single filesystem tree. This is what gets turned into
# an OCI image or ostree commit.

kind: stack

# Runtime dependencies form the complete OS
depends:
# Base boot infrastructure
- base/kernel.bst
- base/systemd.bst
- base/ostree.bst
- base/composefs.bst
- base/dracut.bst
- base/bootc.bst

# Filesystem layout (symlinks, directories)
- immutablue/filesystem.bst

# OS identity
- immutablue/os-release.bst

# Immutablue configuration and scripts
- immutablue/overrides.bst

# Desktop environment
- components/gnome-desktop.bst

# Container tools
- components/podman.bst
- components/distrobox.bst

# CLI tools
- components/cli-tools.bst
