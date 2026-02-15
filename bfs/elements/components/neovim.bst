# Neovim
# ======
# Hyperextensible Vim-based text editor.
# libuv and libvterm are not in freedesktop-sdk; neovim bundles
# its own copies when USE_BUNDLED=ON (the default for deps not found).

kind: cmake

build-depends:
- freedesktop-sdk.bst:public-stacks/buildsystem-cmake.bst
- freedesktop-sdk.bst:components/unzip.bst

sources:
- kind: git
  url: github:neovim/neovim.git
  track: stable
  # ref populated by `bst source track`

variables:
  cmake-local: >-
    -DCMAKE_BUILD_TYPE=Release
    -DCMAKE_INSTALL_PREFIX=%{prefix}
