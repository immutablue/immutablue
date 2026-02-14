#!/bin/bash
set -euxo pipefail
if [[ -f "${INSTALL_DIR}/build/99-common.sh" ]]; then source "${INSTALL_DIR}/build/99-common.sh"; fi
if [[ -f "./99-common.sh" ]]; then source "./99-common.sh"; fi

# -----------------------------------
# Distroless builds don't use dnf/yum repos
# -----------------------------------
if [[ "$(is_option_in_build_options distroless)" == "${TRUE}" ]]
then
    echo "=== Distroless build: skipping yum/dnf repository setup ==="
    exit 0
fi

repos=$(cat <(yq '.immutablue.repo_urls[].name' < ${INSTALL_DIR}/packages.yaml) <(yq ".immutablue.repo_urls_$(uname -m)[].name" < ${INSTALL_DIR}/packages.yaml))

while read -r option 
do 
    repos=$(cat <(echo "${repos}") <(yq ".immutablue.repo_urls_${option}[].name" < ${INSTALL_DIR}/packages.yaml) <(yq ".immutablue.repo_urls_${option}_$(uname -m)[].name" < ${INSTALL_DIR}/packages.yaml))
    echo "${repos}"
done < <(get_immutablue_build_options)


# iterate and download any that have appropriate urls for their base options
for repo in $repos
do 
    curl -Lo "/etc/yum.repos.d/$repo" "$(yq ".immutablue.repo_urls[] | select(.name == \"$repo\").url" < "${INSTALL_DIR}/packages.yaml")" || true
done

for repo in $repos
do 
    curl -Lo "/etc/yum.repos.d/$repo" "$(yq ".immutablue.repo_urls_$(uname -m)[] | select(.name == \"$repo\").url" < "${INSTALL_DIR}/packages.yaml")" || true 
done


# iterate and download any that have appropriate urls for build options
while read -r option 
do 
    for repo in $repos
    do 
        curl -Lo "/etc/yum.repos.d/$repo" "$(yq ".immutablue.repo_urls_${option}[] | select(.name == \"$repo\").url" < "${INSTALL_DIR}/packages.yaml")" || true
    done

    for repo in $repos
    do 
        curl -Lo "/etc/yum.repos.d/$repo" "$(yq ".immutablue.repo_urls_${option}_$(uname -m)[] | select(.name == \"$repo\").url" < "${INSTALL_DIR}/packages.yaml")" || true 
    done
done < <(get_immutablue_build_options)


