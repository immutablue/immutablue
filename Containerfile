ARG FEDORA_VERSION=40
FROM quay.io/fedora-ostree-desktops/silverblue:${FEDORA_VERSION}
ARG FEDORA_VERSION=40
ARG INSTALL_DIR=/etc/immutablue


COPY --from=docker.io/mikefarah/yq /usr/bin/yq /usr/bin/yq
COPY --from=quay.io/zachpodbielniak/nautilusopenwithcode:${FEDORA_VERSION} \
	/usr/lib64/nautilus/extensions-4/libnautilus-open-with-code.so \
	/usr/lib64/nautilus/extensions-4/libnautilus-open-with-code.so
COPY . ${INSTALL_DIR}
COPY ./scripts/immutablue /usr/bin/immutablue

# Install branding and backup existing branding
COPY ./artifacts/branding/* /usr/share/pixmaps/

# Handle .immutablue.repo_urls[]
RUN set -x && \
    repos=$(yq '.immutablue.repo_urls[].name' < ${INSTALL_DIR}/packages.yaml) && \
    for repo in $repos; do curl -Lo "/etc/yum.repos.d/$repo" $(yq ".immutablue.repo_urls[] | select(.name == \"$repo\").url" < ${INSTALL_DIR}/packages.yaml); done && \
    ostree container commit


# Handle .immutablue.rpm[]
RUN set -x && \
    pkgs=$(yq '.immutablue.rpm[]' < ${INSTALL_DIR}/packages.yaml) && \
    rpm-ostree install $(for pkg in $pkgs; do printf '%s ' $pkg; done) && \
    ostree container commit


# Handle .immutablue.rpm_url[]
RUN set -x && \
    pkgs=$(yq '.immutablue.rpm_url[]' < ${INSTALL_DIR}/packages.yaml) && \
    for pkg in $pkgs; do curl -Lo /tmp/$(basename "$pkg") "$pkg"; done && \
    if [ "$pkgs" != "" ]; then rpm-ostree install $(for pkg in $pkgs; do printf '/tmp/%s ' $(basename "$pkg"); done); fi && \
    ostree container commit


# Handle .immutablue.rpm_rm[]
RUN set -x && \
    pkgs=$(yq '.immutablue.rpm_rm[]' < ${INSTALL_DIR}/packages.yaml) && \
    if [ "$pkgs" != "" ]; then rpm-ostree uninstall $(for pkg in $pkgs; do printf '%s ' $pkg; done); fi && \
    ostree container commit


# Handle .immutablue.file_rm[]
RUN set -x && \
    files=$(yq '.immutablue.file_rm[]' < ${INSTALL_DIR}/packages.yaml) && \
    for f in $files; do rm "$f"; done && \
    ostree container commit

