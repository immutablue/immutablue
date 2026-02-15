# OS Release
# ==========
# Immutablue BFS identification files.
# Installs /etc/os-release and /usr/share/immutablue/image-info.json

kind: import

sources:
- kind: local
  path: files/os-release

config:
  target: /
