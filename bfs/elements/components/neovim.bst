# Neovim
# ======
# Hyperextensible Vim-based text editor.

kind: cmake

build-depends:
- freedesktop-sdk.bst:public-stacks/buildsystem-cmake.bst
- freedesktop-sdk.bst:components/unzip.bst

depends:
- freedesktop-sdk.bst:components/libuv.bst
- freedesktop-sdk.bst:components/libvterm.bst

sources:
- kind: git
  url: github:neovim/neovim.git
  track: stable
  # ref populated by `bst source track`

variables:
  cmake-local: >-
    -DCMAKE_BUILD_TYPE=Release
    -DCMAKE_INSTALL_PREFIX=%{prefix}
