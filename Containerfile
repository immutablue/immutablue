ARG FEDORA_VERSION=40
FROM quay.io/fedora-ostree-desktops/silverblue:${FEDORA_VERSION}
ARG FEDORA_VERSION=40
ARG INSTALL_DIR=/opt/immutablue


COPY --from=docker.io/mikefarah/yq /usr/bin/yq /usr/bin/yq
COPY --from=quay.io/zachpodbielniak/nautilusopenwithcode:${FEDORA_VERSION} \
	/usr/lib64/nautilus/extensions-4/libnautilus-open-with-code.so \
	/usr/lib64/nautilus/extensions-4/libnautilus-open-with-code.so
COPY . ${INSTALL_DIR}


RUN \
    curl -Lo /etc/yum.repos.d/tailscale.repo https://pkgs.tailscale.com/stable/fedora/tailscale.repo && \
    ostree container commit


#RUN pkg_urls=$(yq '.rpm_url[]' < ${INSTALL_DIR}/packages.yml) && \
#    for pkg_url in $pkg_urls; do wget -P /tmp/ "$pkg_url"; done && \
#    rpm-ostree install /tmp/*.rpm && \
#    rm /tmp/*.rpm & \
#    ostree container commit


RUN pkgs=$(yq '.rpm[]' < ${INSTALL_DIR}/packages.yml) && \
    rpm-ostree install $(for pkg in $pkgs; do printf '%s ' $pkg; done) && \
    ostree container commit

RUN pkgs=$(yq '.rpm_rm[]' < ${INSTALL_DIR}/packages.yml) && \
    rpm-ostree uninstall $(for pkg in $pkgs; do printf '%s ' $pkg; done) && \
    ostree container commit

RUN files=$(yq '.file_rm[]' < ${INSTALL_DIR}/packages.yml) && \
    for f in $files; do rm "$f"; done && \
    ostree container commit

