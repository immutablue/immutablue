# composefs
# =========
# Read-only filesystem for composing filesystem images.
# Used by bootc for its composefs backend which provides
# verified boot and efficient storage.

kind: meson

build-depends:
- freedesktop-sdk.bst:public-stacks/buildsystem-meson.bst

depends:
- freedesktop-sdk.bst:components/openssl.bst
- freedesktop-sdk.bst:components/fuse3.bst

sources:
- kind: git
  url: github:containers/composefs.git
  track: main
  # ref populated by `bst source track`

variables:
  meson-local: >-
    -Dman=disabled
