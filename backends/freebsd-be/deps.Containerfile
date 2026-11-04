# backends/freebsd-be/deps.Containerfile
#
# The dependency builder for freebsd-be images: compiles the in-house C
# projects (deps/*) on FreeBSD 15.1 with the shared deps-container/00-build.sh,
# which resolves packages.yaml 'build_deps' to pkg names and builds under
# /usr/local with gmake and gcc (backend.yaml 'deps_build').
#
# Built on a FreeBSD host like the image itself:
#   backends/freebsd-be/builder-vm.sh make BACKEND=freebsd-be build-deps
ARG BASE_IMAGE=ghcr.io/freebsd/freebsd-runtime
ARG FEDORA_VERSION=15.1

FROM ${BASE_IMAGE}:${FEDORA_VERSION} AS dep-builder

ARG FEDORA_VERSION
ENV FEDORA_VERSION=${FEDORA_VERSION}

ENV IMMUTABLUE_BACKEND=freebsd-be
ENV IMMUTABLUE_SRC=/tmp/immutablue

# The runtime image is only sh, rc and pkg. The projects need the base
# toolchain support files (crt objects, libc headers: FreeBSD-set-devel), the
# base userland, bash for 00-build.sh and Go yq for packages.yaml.
COPY backends/freebsd-be/overrides/usr/local/etc/pkg/repos/FreeBSD-base.conf /usr/local/etc/pkg/repos/FreeBSD-base.conf
RUN env ASSUME_ALWAYS_YES=yes pkg bootstrap -f && \
    pkg update -f && \
    pkg install -y FreeBSD-set-base FreeBSD-set-devel bash go-yq && \
    { command -v yq > /dev/null || ln -s "$(command -v go-yq)" /usr/local/bin/yq; }

COPY packages.yaml /tmp/immutablue/packages.yaml
COPY build/99-common.sh /tmp/immutablue/build/99-common.sh
COPY backends/lib /tmp/immutablue/backends/lib
COPY backends/freebsd-be /tmp/immutablue/backends/freebsd-be
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
RUN /usr/local/bin/bash /tmp/00-build.sh
COPY deps-container/dep_info.json /build/dep_info.json
