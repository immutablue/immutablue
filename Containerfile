ARG FEDORA_VERSION=41


FROM quay.io/zachpodbielniak/nautilusopenwithcode:${FEDORA_VERSION} AS nautilusopenwithcode
FROM docker.io/mikefarah/yq AS yq
FROM ghcr.io/ublue-os/config:latest AS ublue-config
FROM ghcr.io/ublue-os/akmods:main-${FEDORA_VERSION} AS ublue-akmods
FROM registry.fedoraproject.org/fedora:${FEDORA_VERSION} as dep-builder

RUN set -eux && \
    echo -e 'max_parallel_downloads=10\n' >> /etc/dnf/dnf.conf && \
    dnf5 update -y && \
    dnf5 install -y git golang && \
    mkdir -p /build && \
    git clone https://github.com/Containerpak/cpak /build/cpak && \
    bash -c "cd /build/cpak && make all"


FROM quay.io/fedora/fedora-silverblue:${FEDORA_VERSION}


ARG FEDORA_VERSION=41
ARG IMAGE_TAG=${FEDORA_VERSION}
ARG INSTALL_DIR=/usr/immutablue
ARG DO_INSTALL_AKMODS=false
ARG DO_INSTALL_ZFS=false
ARG DO_INSTALL_LTS=false
ARG IMMUTABLUE_BUILD=true
ARG IMAGE_TAG=immutablue


# Copy in files for build
COPY . ${INSTALL_DIR}
COPY ./artifacts/overrides/ /


RUN --mount=type=cache,dst=/var/cache/rpm-ostree \
    --mount=type=bind,from=nautilusopenwithcode,src=/usr/lib64/nautilus/extensions-4,dst=/mnt-nautilusopenwithcode \
    --mount=type=bind,from=yq,src=/usr/bin,dst=/mnt-yq \
    --mount=type=bind,from=ublue-config,src=/rpms,dst=/mnt-ublue-config \
    --mount=type=bind,from=ublue-akmods,src=/rpms,dst=/mnt-ublue-akmods \
    --mount=type=bind,from=dep-builder,src=/build,dst=/mnt-dep-builder \
    set -eux && \
    ls -l ${INSTALL_DIR}/build && \
    chmod +x ${INSTALL_DIR}/build/*.sh && \
    for script in ${INSTALL_DIR}/build/*.sh; do "$script"; if [[ $? -ne 0 ]]; then echo "ERROR: $script failed" && exit 1; fi; done && \
    ostree container commit

