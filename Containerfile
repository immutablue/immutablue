ARG FEDORA_VERSION=41

FROM quay.io/zachpodbielniak/nautilusopenwithcode:${FEDORA_VERSION} AS nautilusopenwithcode
FROM docker.io/mikefarah/yq AS yq
FROM ghcr.io/ublue-os/config:latest AS ublue-config
FROM ghcr.io/ublue-os/akmods:main-${FEDORA_VERSION} AS ublue-akmods


FROM quay.io/fedora/fedora-silverblue:${FEDORA_VERSION}
ARG FEDORA_VERSION=41
ARG INSTALL_DIR=/usr/immutablue
ARG DO_INSTALL_AKMODS=false
ARG DO_INSTALL_ZFS=false
ARG DO_INSTALL_LTS=false

# Copy in files for build
COPY . ${INSTALL_DIR}
COPY ./artifacts/overrides/ /


RUN --mount=type=cache,dst=/var/cache/rpm-ostree \
    --mount=type=bind,from=nautilusopenwithcode,src=/usr/lib64/nautilus/extensions-4,dst=/mnt-nautilusopenwithcode \
    --mount=type=bind,from=yq,src=/usr/bin,dst=/mnt-yq \
    --mount=type=bind,from=ublue-config,src=/rpms,dst=/mnt-ublue-config \
    --mount=type=bind,from=ublue-akmods,src=/rpms,dst=/mnt-ublue-akmods \
    set -x && \
    ls -l ${INSTALL_DIR} && \
    chmod +x ${INSTALL_DIR}/build/*.sh && \
    for script in ${INSTALL_DIR}/build/*.sh; do "$script"; done && \
    ostree container commit

