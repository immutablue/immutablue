# fzf
# ===
# Command-line fuzzy finder. Written in Go.

kind: manual

build-depends:
- freedesktop-sdk.bst:components/go.bst

depends:
- freedesktop-sdk.bst:bootstrap/bash.bst

sources:
- kind: git
  url: github:junegunn/fzf.git
  track: master
  # ref populated by `bst source track`

config:
  build-commands:
  - make -j%{max-jobs} bin/fzf

  install-commands:
  - install -Dm755 bin/fzf "%{install-root}%{prefix}/bin/fzf"
  - install -Dm644 shell/completion.bash "%{install-root}%{prefix}/share/bash-completion/completions/fzf"
  - install -Dm644 shell/key-bindings.bash "%{install-root}%{prefix}/share/fzf/key-bindings.bash"
  - install -Dm755 bin/fzf-tmux "%{install-root}%{prefix}/bin/fzf-tmux"
