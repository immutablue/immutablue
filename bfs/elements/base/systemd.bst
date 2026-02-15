# systemd
# =======
# The init system. Required by bootc and ostree.
# We pull systemd from freedesktop-sdk which already builds it.
# This element just re-exports the freedesktop-sdk systemd with
# any Immutablue-specific configuration overlaid.

kind: stack

# freedesktop-sdk already builds systemd -- we depend on it
# directly rather than rebuilding from source
depends:
- freedesktop-sdk.bst:components/systemd.bst
- freedesktop-sdk.bst:components/systemd-libs.bst
