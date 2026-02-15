# GNOME Desktop Stack
# ===================
# Aggregates the GNOME desktop components needed for Immutablue.
# Rather than building GNOME from source (which gnome-build-meta does),
# we junction gnome-build-meta and pull in the pre-defined elements.
#
# This is the "option 3" hybrid approach: use freedesktop-sdk for
# the base, gnome-build-meta for the desktop, and our own elements
# for Immutablue-specific pieces.

kind: stack

depends:
# Core desktop
- freedesktop-sdk.bst:components/glib.bst
- freedesktop-sdk.bst:components/gtk3.bst
- freedesktop-sdk.bst:components/dbus.bst
- freedesktop-sdk.bst:components/polkit.bst

# Display server and compositor
- freedesktop-sdk.bst:components/wayland.bst
- freedesktop-sdk.bst:components/wayland-protocols.bst
# Mesa is in extensions/, not components/
- freedesktop-sdk.bst:extensions/mesa/mesa.bst

# Audio
- freedesktop-sdk.bst:components/pipewire.bst

# accountsservice, NetworkManager, GDM, GNOME Shell, mutter, etc.
# are NOT in freedesktop-sdk -- they come from gnome-build-meta.
#
# TODO: Add gnome-build-meta junction for:
# - accountsservice
# - NetworkManager
# - mutter
# - gnome-shell
# - gdm
# - gnome-settings-daemon
# - gnome-control-center
# - nautilus
#
# For the initial scaffold, we document the dependency chain.
# The actual GNOME elements will be added as we bring in gnome-build-meta.
