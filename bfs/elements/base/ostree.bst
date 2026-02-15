# OSTree
# ======
# Content-addressed filesystem for atomic OS updates.
# Required for bootc's update mechanism.

kind: meson

build-depends:
- freedesktop-sdk.bst:public-stacks/buildsystem-meson.bst

depends:
- freedesktop-sdk.bst:components/glib.bst
- freedesktop-sdk.bst:components/gpgme.bst
- freedesktop-sdk.bst:components/libarchive.bst
- freedesktop-sdk.bst:components/curl.bst
- freedesktop-sdk.bst:components/fuse3.bst
- freedesktop-sdk.bst:bootstrap/xz.bst
- freedesktop-sdk.bst:components/e2fsprogs.bst
- freedesktop-sdk.bst:components/systemd.bst
- freedesktop-sdk.bst:components/openssl.bst
- freedesktop-sdk.bst:components/gobject-introspection.bst

sources:
- kind: git
  url: github:ostreedev/ostree.git
  track: main
  # ref populated by `bst source track`

variables:
  meson-local: >-
    -Dman=false
    -Dgjs=disabled
    -Ddracut=true
    -Dcomposefs=true
    -Drust=disabled
