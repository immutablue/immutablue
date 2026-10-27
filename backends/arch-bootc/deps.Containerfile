# backends/arch-bootc/deps.Containerfile
#
# The dependency builder for arch-bootc images: compiles the in-house C
# projects (deps/*) on Arch with the shared deps-container/00-build.sh, which
# resolves packages.yaml 'build_deps' to pacman names.
ARG FEDORA_VERSION=arch
FROM docker.io/mikefarah/yq AS yq
FROM docker.io/archlinux/archlinux:latest as dep-builder

ARG FEDORA_VERSION
ENV FEDORA_VERSION=${FEDORA_VERSION}

ENV IMMUTABLUE_BACKEND=arch-bootc
ENV IMMUTABLUE_SRC=/tmp/immutablue
COPY --from=yq /usr/bin/yq /usr/bin/yq
COPY packages.yaml /tmp/immutablue/packages.yaml
COPY build/99-common.sh /tmp/immutablue/build/99-common.sh
COPY backends/lib /tmp/immutablue/backends/lib
COPY backends/arch-bootc /tmp/immutablue/backends/arch-bootc
COPY deps-container/00-build.sh /tmp/00-build.sh
COPY deps/yaml-glib /build/yaml-glib
COPY deps/crispy /build/crispy
COPY deps/gst /build/gst
COPY deps/gsurf /build/gsurf
COPY deps/gowl /build/gowl
COPY deps/mcp-glib /build/mcp-glib
COPY deps/mcp-gdb-glib /build/mcp-gdb-glib
COPY deps/ai-glib /build/ai-glib
COPY deps/podomation /build/podomation
COPY deps/bacon /build/bacon
COPY deps/mcp-kuberblue-glib /build/mcp-kuberblue-glib
RUN bash /tmp/00-build.sh
COPY deps-container/dep_info.json /build/dep_info.json
