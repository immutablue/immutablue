ARG BASE_IMAGE=quay.io/fedora-ostree-desktops/silverblue
ARG FEDORA_VERSION=42

FROM scratch as ctx
COPY / /

FROM quay.io/zachpodbielniak/nautilusopenwithcode:${FEDORA_VERSION} AS nautilusopenwithcode
FROM quay.io/immutablue/immutablue:${FEDORA_VERSION}-deps as build-deps
FROM quay.io/immutablue/immutablue:${FEDORA_VERSION}-cyan-deps AS cyan-deps
FROM docker.io/mikefarah/yq AS yq

FROM ghcr.io/ublue-os/config:latest AS ublue-config
FROM ghcr.io/ublue-os/akmods:main-${FEDORA_VERSION} AS ublue-akmods
FROM ${BASE_IMAGE}:${FEDORA_VERSION}


ARG BASE_IMAGE=quay.io/fedora-ostree-desktops/silverblue
ARG FEDORA_VERSION=42
ARG IMAGE_TAG=${FEDORA_VERSION}
ARG INSTALL_DIR=/usr/immutablue
ARG DO_INSTALL_AKMODS=false
ARG DO_INSTALL_ZFS=false
ARG DO_INSTALL_LTS=false
ARG IMMUTABLUE_BUILD=true
ARG IMAGE_TAG=immutablue
ARG IMMUTABLUE_BUILD_OPTIONS=${IMMUTABLUE_BUILD_OPTIONS}


RUN --mount=type=cache,dst=/var/cache/rpm-ostree \
    --mount=type=bind,from=ctx,src=/,dst=/mnt-ctx \
    --mount=type=bind,from=nautilusopenwithcode,src=/usr/lib64/nautilus/extensions-4,dst=/mnt-nautilusopenwithcode \
    --mount=type=bind,from=yq,src=/usr/bin,dst=/mnt-yq \
    --mount=type=bind,from=ublue-config,src=/rpms,dst=/mnt-ublue-config \
    --mount=type=bind,from=ublue-akmods,src=/rpms,dst=/mnt-ublue-akmods \
    --mount=type=bind,from=cyan-deps,src=/rpms,dst=/mnt-cyan-deps \
    --mount=type=bind,from=build-deps,src=/build,dst=/mnt-build-deps \
    set -eux && \
    ls -l /mnt-ctx/build && \
    for script in /mnt-ctx/build/*.sh; do bash < "$script"; if [[ $? -ne 0 ]]; then echo "ERROR: $script failed" && exit 1; fi; done && \
    ostree container commit

