# backends/fedora-bootc/deps.Containerfile
#
# The dependency builder for fedora-bootc images: compiles the in-house C
# projects (deps/*) against the Fedora release the image is built from. The
# build itself is the shared deps-container/00-build.sh; this file only picks
# the base and stages the sources.
ARG FEDORA_VERSION=42
FROM docker.io/mikefarah/yq AS yq
FROM registry.fedoraproject.org/fedora:${FEDORA_VERSION} as dep-builder

# Re-declare after FROM so it's visible in the build stage, and export as ENV
# so deps-container/00-build.sh can branch on the Fedora release where a package name or
# a build flag differs between releases.
ARG FEDORA_VERSION
ENV FEDORA_VERSION=${FEDORA_VERSION}

# The shared library, backend and packages.yaml resolve build_deps for this
# backend (see load_immutablue_library in 00-build.sh).
ENV IMMUTABLUE_BACKEND=fedora-bootc
ENV IMMUTABLUE_SRC=/tmp/immutablue
COPY --from=yq /usr/bin/yq /usr/bin/yq
COPY packages.yaml /tmp/immutablue/packages.yaml
COPY build/99-common.sh /tmp/immutablue/build/99-common.sh
COPY backends/lib /tmp/immutablue/backends/lib
COPY backends/fedora-bootc /tmp/immutablue/backends/fedora-bootc
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
# This manifest was captured from the same source context before compilation.
COPY deps-container/dep_info.json /build/dep_info.json
