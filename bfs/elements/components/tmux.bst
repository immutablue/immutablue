# tmux
# ====
# Terminal multiplexer.

kind: autotools

build-depends:
- freedesktop-sdk.bst:public-stacks/buildsystem-autotools.bst
- freedesktop-sdk.bst:components/bison.bst

depends:
- freedesktop-sdk.bst:bootstrap/ncurses.bst
- freedesktop-sdk.bst:components/libevent.bst

sources:
- kind: git
  url: github:tmux/tmux.git
  track: master
  # ref populated by `bst source track`

  ref: d3522c328c5e338ee1b5ff35efbbd4081b62a236
config:
  configure-commands:
  - sh autogen.sh
  - "%{configure}"
