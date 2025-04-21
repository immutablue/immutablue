#!/bin/bash 
set -euxo pipefail 
if [[ -f "${INSTALL_DIR}/build/99-common.sh" ]]; then source "${INSTALL_DIR}/build/99-common.sh"; fi
if [[ -f "./99-common.sh" ]]; then source "./99-common.sh"; fi

repos=$(cat <(yq '.immutablue.repo_urls[].name' < ${INSTALL_DIR}/packages.yaml) <(yq ".immutablue.repo_urls_$(uname -m)[]" < ${INSTALL_DIR}/packages.yaml))


for repo in $repos
do 
    curl -Lo "/etc/yum.repos.d/$repo" "$(yq ".immutablue.repo_urls[] | select(.name == \"$repo\").url" < "${INSTALL_DIR}/packages.yaml")" || true
done


for repo in $repos
do 
    curl -Lo "/etc/yum.repos.d/$repo" "$(yq ".immutablue.repo_urls_$(uname -m)[] | select(.name == \"$repo\").url" < "${INSTALL_DIR}/packages.yaml")" || true 
done



