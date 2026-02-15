# Immutablue BFS OCI Image
# ========================
# Produces a bootc-compatible OCI container image from the
# composed Immutablue BFS filesystem tree.
#
# The output can be loaded into podman/docker and pushed to
# a container registry, or consumed by `bootc install` to
# deploy to bare metal.

kind: oci

build-depends:
- immutablue/image.bst

config:
  mode: oci
  images:
  - os: linux
    architecture: "%{go-arch}"
    layer:
    - immutablue/image.bst
    comment: "Immutablue BFS - Blue From Scratch"
    config:
      Cmd: ["/usr/sbin/init"]
      Env:
      - "PATH=/usr/bin:/usr/sbin:/bin:/sbin"
      Labels:
        containers.bootc: "1"
        ostree.bootable: "1"
        org.opencontainers.image.title: "Immutablue BFS"
        org.opencontainers.image.description: "Immutablue built from source using freedesktop-sdk"
        org.opencontainers.image.vendor: "Immutablue"
        org.opencontainers.image.source: "https://gitlab.com/immutablue/immutablue"
    annotations:
      org.opencontainers.image.ref.name: "quay.io/immutablue/immutablue:bfs"
