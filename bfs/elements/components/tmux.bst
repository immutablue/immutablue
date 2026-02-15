# tmux
# ====
# Terminal multiplexer.

kind: autotools

build-depends:
- freedesktop-sdk.bst:public-stacks/buildsystem-autotools.bst
- freedesktop-sdk.bst:components/bison.bst

depends:
- freedesktop-sdk.bst:components/ncurses.bst
- freedesktop-sdk.bst:components/libevent.bst

sources:
- kind: git
  url: github:tmux/tmux.git
  track: master
  # ref populated by `bst source track`

config:
  configure-commands:
  - sh autogen.sh
  - "%{configure}"
