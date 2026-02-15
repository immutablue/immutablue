# Distrobox
# =========
# Use any Linux distribution inside your terminal.
# Pure shell script, no compilation needed.

kind: manual

depends:
- components/podman.bst
- freedesktop-sdk.bst:bootstrap/bash.bst
- freedesktop-sdk.bst:components/curl.bst
# wget is not in freedesktop-sdk; curl is sufficient for distrobox

sources:
- kind: git
  url: github:89luca89/distrobox.git
  track: main
  # ref populated by `bst source track`

config:
  install-commands:
  - ./install --prefix "%{install-root}%{prefix}"
