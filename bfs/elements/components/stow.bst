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
