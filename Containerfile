ARG BASE_IMAGE=quay.io/fedora-ostree-desktops/silverblue
# BASE_IMAGE_TAG is separate from FEDORA_VERSION because GNOME OS uses different tags
# For Fedora: BASE_IMAGE_TAG=43 -> silverblue:43
# For GNOME OS: BASE_IMAGE_TAG=gnomeos-nightly -> gnome-build-meta:gnomeos-nightly
ARG BASE_IMAGE_TAG=43
# For non-distroless builds, use fedora:latest (has bash, minimal overhead since
# silverblue base already pulls fedora layers)
# For distroless builds, this is set to gnomeos-devel-nightly
ARG BASE_IMAGE_DEVEL=registry.fedoraproject.org/fedora:latest
ARG FEDORA_VERSION=43
ARG IS_DISTROLESS=false

FROM scratch as ctx
COPY / /

FROM quay.io/zachpodbielniak/nautilusopenwithcode:${FEDORA_VERSION} AS nautilusopenwithcode
FROM quay.io/immutablue/immutablue:${FEDORA_VERSION}-deps as build-deps
FROM quay.io/immutablue/immutablue:${FEDORA_VERSION}-cyan-deps AS cyan-deps
FROM quay.io/immutablue/linuxbrew:latest AS linuxbrew
FROM docker.io/mikefarah/yq AS yq

FROM ghcr.io/ublue-os/config:latest AS ublue-config


# -----------------------------------
# Distroless devel stage (only used when DISTROLESS=1)
# Copies development tools (gcc, etc.) from GNOME OS devel image
# For non-distroless builds, uses busybox to just create empty /rootfs
# -----------------------------------
ARG BASE_IMAGE_DEVEL
ARG IS_DISTROLESS

FROM ${BASE_IMAGE_DEVEL} AS devel-stage
ARG IS_DISTROLESS

# For distroless: run full devel-build.sh to extract tools
# For non-distroless: just create empty /rootfs directory
RUN --mount=type=bind,from=ctx,src=/,dst=/tmp/ctx \
    mkdir -p /rootfs && \
    if [ "${IS_DISTROLESS}" = "true" ] && [ -x /tmp/ctx/build/distroless/devel-build.sh ]; then \
        /tmp/ctx/build/distroless/devel-build.sh; \
    else \
        echo "Devel stage: creating empty /rootfs (non-distroless build)"; \
    fi


# -----------------------------------
# Main image stage
# -----------------------------------
ARG BASE_IMAGE
ARG BASE_IMAGE_TAG
FROM ${BASE_IMAGE}:${BASE_IMAGE_TAG}

ARG BASE_IMAGE=quay.io/fedora-ostree-desktops/silverblue
ARG FEDORA_VERSION=43
ARG IMAGE_TAG=${FEDORA_VERSION}
ARG INSTALL_DIR=/usr/immutablue
ARG DO_INSTALL_AKMODS=false
ARG DO_INSTALL_ZFS=false
ARG DO_INSTALL_LTS=false
ARG IMMUTABLUE_BUILD=true
ARG IMAGE_TAG=immutablue
ARG IMMUTABLUE_BUILD_OPTIONS=${IMMUTABLUE_BUILD_OPTIONS}
ARG IS_DISTROLESS=false
ARG SKIP=


RUN --mount=type=cache,dst=/var/cache/rpm-ostree \
    --mount=type=bind,from=ctx,src=/,dst=/mnt-ctx \
    --mount=type=bind,from=nautilusopenwithcode,src=/usr/lib64/nautilus/extensions-4,dst=/mnt-nautilusopenwithcode \
    --mount=type=bind,from=yq,src=/usr/bin,dst=/mnt-yq \
    --mount=type=bind,from=ublue-config,src=/rpms,dst=/mnt-ublue-config \
    --mount=type=bind,from=cyan-deps,src=/rpms,dst=/mnt-cyan-deps \
    --mount=type=bind,from=build-deps,src=/build,dst=/mnt-build-deps \
    --mount=type=bind,from=linuxbrew,src=/,dst=/mnt-linuxbrew \
    --mount=type=bind,from=devel-stage,src=/rootfs,dst=/mnt-devel-rootfs \
    set -eux && \
    ls -l /mnt-ctx/build && \
    for script in /mnt-ctx/build/*.sh; do bash < "$script"; if [[ $? -ne 0 ]]; then echo "ERROR: $script failed" && exit 1; fi; done && \
    if [ "${IS_DISTROLESS}" != "true" ]; then ostree container commit; fi

# Bootc container lint for distroless builds
ARG IS_DISTROLESS
RUN if [ "${IS_DISTROLESS}" = "true" ]; then bootc container lint || true; fi

LABEL containers.bootc=1
