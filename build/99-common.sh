#!/bin/bash 
if [[ -f "/usr/libexec/immutablue/immutablue-header.sh" ]]; then source "/usr/libexec/immutablue/immutablue-header.sh"; fi
PACKAGES_YAML="${INSTALL_DIR}/packages.yaml"
MARCH="$(uname -m)"
VERSION="${VERSION:-${FEDORA_VERSION}}"

MODULES_CONF="/etc/modules-load.d/10-immutablue.conf"

LTS_VERSION=$(yq ".immutablue.lts_version.${VERSION}" < "${PACKAGES_YAML}")
ZFS_RPM_URL=$(yq ".immutablue.zfs_rpm_url.${VERSION}" < "${PACKAGES_YAML}")

# LTS_REPO_URL="https://copr.fedorainfracloud.org/coprs/kwizart/kernel-longterm-6.6/repo/fedora-42/kwizart-kernel-longterm-${LTS_VERSION}-fedora-42.repo"
LTS_REPO_URL="https://copr.fedorainfracloud.org/coprs/kwizart/kernel-longterm-${LTS_VERSION}/repo/fedora-${FEDORA_VERSION}/kwizart-kernel-longterm-${LTS_VERSION}-fedora-${FEDORA_VERSION}.repo"

HUGO_RELEASE_URL_x86_64="https://github.com/gohugoio/hugo/releases/download/v0.148.1/hugo_extended_withdeploy_0.148.1_linux-amd64.tar.gz"
HUGO_RELEASE_URL_aarch64="https://github.com/gohugoio/hugo/releases/download/v0.148.1/hugo_extended_withdeploy_0.148.1_linux-arm64.tar.gz"
HUGO_RELEASE_URL=""
FZF_GIT_URL="https://raw.githubusercontent.com/junegunn/fzf-git.sh/refs/heads/main/fzf-git.sh"
STARSHIP_URL="https://starship.rs/install.sh"
JUST_RELEASE_URL="https://github.com/casey/just/releases/download/1.42.3/just-1.42.3-$(uname -m)-unknown-linux-musl.tar.gz"
ZEROFS_RELEASE_URL="https://github.com/Barre/ZeroFS/releases/download/v0.0.2/zerofs-linux-multiarch.tar.gz"
CHAINSAW_RELEASE_URL_x86_64="https://github.com/kyverno/chainsaw/releases/download/v0.2.12/chainsaw_linux_amd64.tar.gz"
CHAINSAW_RELEASE_URL_aarch64="https://github.com/kyverno/chainsaw/releases/download/v0.2.12/chainsaw_linux_arm64.tar.gz"
CHAINSAW_RELEASE_URL=""

if [[ "${MARCH}" == "aarch64" ]]
then 
    HUGO_RELEASE_URL="${HUGO_RELEASE_URL_aarch64}"
    CHAINSAW_RELEASE_URL="${CHAINSAW_RELEASE_URL_aarch64}"
else 
    HUGO_RELEASE_URL="${HUGO_RELEASE_URL_x86_64}"
    CHAINSAW_RELEASE_URL="${CHAINSAW_RELEASE_URL_x86_64}"
fi


get_immutablue_build_options() {
    IFS=',' read -ra entry_array <<< "${IMMUTABLUE_BUILD_OPTIONS}" 
    for entry in "${entry_array[@]}"
    do
        echo -e "${entry}"
    done 
}

is_option_in_build_options() {
    local option="$1"
    IFS=',' read -ra entry_array <<< "${IMMUTABLUE_BUILD_OPTIONS}"
    for entry in "${entry_array[@]}"
    do
        if [[ "${option}" == "${entry}" ]]
        then
            echo "${TRUE}"
            return 0
        fi
    done
    echo "${FALSE}"
}

# Check if a specific item should be skipped during build
# Uses the SKIP environment variable which is a CSV list (e.g., SKIP=hugo,tests,docs)
# param $1: The item to check for (e.g., "hugo", "tests")
# returns: TRUE if the item should be skipped, FALSE otherwise
is_skipped() {
    local item="$1"
    if [[ -z "${SKIP:-}" ]]
    then
        echo "${FALSE}"
        return 0
    fi
    IFS=',' read -ra skip_array <<< "${SKIP}"
    for entry in "${skip_array[@]}"
    do
        if [[ "${item}" == "${entry}" ]]
        then
            echo "${TRUE}"
            return 0
        fi
    done
    echo "${FALSE}"
}

# looks up entries in packages.yaml
# takes into account the version, architecture and build options
get_yaml_array() {
    local key="$1"
    # Base all
    yq "${key}.all[]" < "${PACKAGES_YAML}" 2>/dev/null || true
    # Version specific
    if [[ -n "${VERSION}" ]]; then
        yq "${key}.${VERSION}[]" < "${PACKAGES_YAML}" 2>/dev/null || true
    fi
    # Architecture all
    yq "${key}.all_${MARCH}[]" < "${PACKAGES_YAML}" 2>/dev/null || true
    # Version + architecture
    if [[ -n "${VERSION}" ]]; then
        yq "${key}.${VERSION}_${MARCH}[]" < "${PACKAGES_YAML}" 2>/dev/null || true
    fi
    # Build options
    while read -r option
    do
        # Option all
        yq "${key}_${option}.all[]" < "${PACKAGES_YAML}" 2>/dev/null || true
        # Option version
        if [[ -n "${VERSION}" ]]; then
            yq "${key}_${option}.${VERSION}[]" < "${PACKAGES_YAML}" 2>/dev/null || true
        fi
        # Option architecture all
        yq "${key}_${option}.all_${MARCH}[]" < "${PACKAGES_YAML}" 2>/dev/null || true
        # Option version architecture
        if [[ -n "${VERSION}" ]]; then
            yq "${key}_${option}.${VERSION}_${MARCH}[]" < "${PACKAGES_YAML}" 2>/dev/null || true
        fi
    done < <(get_immutablue_build_options)
}


get_immutablue_packages() {
    get_yaml_array '.immutablue.rpm'
}


get_immutablue_pip_packages() {
    get_yaml_array '.immutablue.pip_packages'
}


get_immutablue_packages_to_remove() {
    get_yaml_array '.immutablue.rpm_rm'
}


get_immutablue_package_urls() {
    get_yaml_array '.immutablue.rpm_url'
}


get_immutablue_package_post_urls() {
    get_yaml_array '.immutablue.rpm_post_url'
}


get_immutablue_files_to_remove() {
    get_yaml_array '.immutablue.file_rm'
}


get_immutablue_system_services_to_unmask() {
    get_yaml_array '.immutablue.services_unmask_sys'
}


get_immutablue_system_services_to_disable() {
    get_yaml_array '.immutablue.services_disable_sys'
}


get_immutablue_system_services_to_enable() {
    get_yaml_array '.immutablue.services_enable_sys'
}


get_immutablue_system_services_to_mask() {
    get_yaml_array '.immutablue.services_mask_sys'
}


get_immutablue_user_services_to_unmask() {
    get_yaml_array '.immutablue.services_unmask_user'
}


get_immutablue_user_services_to_disable() {
    get_yaml_array '.immutablue.services_disable_user'
}


get_immutablue_user_services_to_enable() {
    get_yaml_array '.immutablue.services_enable_user'
}


get_immutablue_user_services_to_mask() {
    get_yaml_array '.immutablue.services_mask_user'
}

get_nix_install_packages() {
    get_yaml_array '.immutablue.nix.install'
}

