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
- kind: tar
  url: github:aspiers/stow/releases/download/v2.4.1/stow-2.4.1.tar.gz
  # ref populated by `bst source track`
