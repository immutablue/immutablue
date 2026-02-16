# GNU Stow
# ========
# Symlink farm manager. Used for dotfile management.

kind: autotools

build-depends:
- freedesktop-sdk.bst:public-stacks/buildsystem-autotools.bst
- freedesktop-sdk.bst:components/perl.bst

depends:
- freedesktop-sdk.bst:components/perl.bst

sources:
- kind: git
  url: github:aspiers/stow.git
  track: v2.4.1
  # ref populated by `bst source track`
  ref: 544aed007b9b26a73ca321c17d3f3b8f7172f9d4

variables:
  # Skip doc/info building (requires makeinfo/texinfo which is not in the sandbox)
  make: make MAKEINFO=true
  make-install: make -j1 install DESTDIR="%{install-root}" MAKEINFO=true
