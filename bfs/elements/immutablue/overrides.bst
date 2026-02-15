# Immutablue Overrides
# ====================
# Copies the Immutablue-specific configuration files, scripts,
# systemd units, and justfiles from the main artifacts/overrides/
# directory into the image.
#
# This reuses the existing Immutablue override tree so that BFS
# gets the same runtime experience as the standard build.

kind: import

sources:
- kind: local
  path: ../artifacts/overrides

config:
  target: /
