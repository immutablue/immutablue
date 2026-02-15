# CLI Tools Stack
# ================
# Core command-line tools that Immutablue bundles into the base image.
# These are the tools that come from freedesktop-sdk or are simple
# enough to build from source.

kind: stack

depends:
# From freedesktop-sdk bootstrap
- freedesktop-sdk.bst:bootstrap/bash.bst
- freedesktop-sdk.bst:bootstrap/coreutils.bst
- freedesktop-sdk.bst:bootstrap/findutils.bst
- freedesktop-sdk.bst:bootstrap/gawk.bst
- freedesktop-sdk.bst:bootstrap/grep.bst
- freedesktop-sdk.bst:bootstrap/sed.bst
- freedesktop-sdk.bst:bootstrap/xz.bst

# From freedesktop-sdk components
- freedesktop-sdk.bst:components/tar.bst
- freedesktop-sdk.bst:components/gzip.bst
- freedesktop-sdk.bst:components/git.bst
- freedesktop-sdk.bst:components/curl.bst
- freedesktop-sdk.bst:components/openssh.bst
- freedesktop-sdk.bst:components/less.bst
- freedesktop-sdk.bst:components/util-linux.bst
- freedesktop-sdk.bst:components/procps.bst
- freedesktop-sdk.bst:components/which.bst
- freedesktop-sdk.bst:components/strace.bst
- freedesktop-sdk.bst:components/e2fsprogs.bst
- freedesktop-sdk.bst:components/iproute2.bst

# Additional tools we build ourselves
- components/neovim.bst
- components/fzf.bst
- components/tmux.bst
- components/stow.bst
