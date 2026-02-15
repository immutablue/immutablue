# Junction to freedesktop-sdk
# ============================
# This pulls in the entire freedesktop-sdk build definitions,
# giving us access to the base toolchain, glibc, systemd, mesa,
# and all the foundational libraries.
#
# We track the 24.08 branch (latest stable release train).
# The ref should be updated periodically with `bst source track`.

kind: junction

sources:
- kind: git
  url: freedesktop:freedesktop-sdk/freedesktop-sdk.git
  track: release/24.08
