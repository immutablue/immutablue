# GNU Stow
# ========
# Symlink farm manager. Used for dotfile management.
# Using manual kind to skip doc building which requires texinfo.

kind: manual

build-depends:
- freedesktop-sdk.bst:public-stacks/buildsystem-autotools.bst
- freedesktop-sdk.bst:components/perl.bst

depends:
- freedesktop-sdk.bst:components/perl.bst

sources:
- kind: git
  url: github:aspiers/stow.git
  track: v2.4.1
  ref: 544aed007b9b26a73ca321c17d3f3b8f7172f9d4

config:
  configure-commands:
  - |
    autoreconf --install
    ./configure --prefix=%{prefix}

  build-commands:
  - |
    touch doc/stow.info
    mkdir -p doc/manual-split
    make -j%{max-jobs}

  install-commands:
  - make -j1 install DESTDIR="%{install-root}"
