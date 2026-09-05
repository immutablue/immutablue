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
FLUX_RELEASE_URL_x86_64="https://github.com/fluxcd/flux2/releases/download/v2.5.1/flux_2.5.1_linux_amd64.tar.gz"
FLUX_RELEASE_URL_aarch64="https://github.com/fluxcd/flux2/releases/download/v2.5.1/flux_2.5.1_linux_arm64.tar.gz"
FLUX_RELEASE_URL=""
SOPS_RELEASE_URL_x86_64="https://github.com/getsops/sops/releases/download/v3.9.4/sops-v3.9.4.linux.amd64"
SOPS_RELEASE_URL_aarch64="https://github.com/getsops/sops/releases/download/v3.9.4/sops-v3.9.4.linux.arm64"
SOPS_RELEASE_URL=""
CRIO_RELEASE_URL_x86_64="https://storage.googleapis.com/cri-o/artifacts/cri-o.amd64.v1.32.13.tar.gz"
CRIO_RELEASE_URL_aarch64="https://storage.googleapis.com/cri-o/artifacts/cri-o.arm64.v1.32.13.tar.gz"
CRIO_RELEASE_URL=""

if [[ "${MARCH}" == "aarch64" ]]
then
    HUGO_RELEASE_URL="${HUGO_RELEASE_URL_aarch64}"
    CHAINSAW_RELEASE_URL="${CHAINSAW_RELEASE_URL_aarch64}"
    FLUX_RELEASE_URL="${FLUX_RELEASE_URL_aarch64}"
    SOPS_RELEASE_URL="${SOPS_RELEASE_URL_aarch64}"
    CRIO_RELEASE_URL="${CRIO_RELEASE_URL_aarch64}"
else
    HUGO_RELEASE_URL="${HUGO_RELEASE_URL_x86_64}"
    CHAINSAW_RELEASE_URL="${CHAINSAW_RELEASE_URL_x86_64}"
    FLUX_RELEASE_URL="${FLUX_RELEASE_URL_x86_64}"
    SOPS_RELEASE_URL="${SOPS_RELEASE_URL_x86_64}"
    CRIO_RELEASE_URL="${CRIO_RELEASE_URL_x86_64}"
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

# Validates that packages.yaml is parseable before anything tries to read
# keys out of it.
#
# get_yaml_array() probes a large number of keys that are legitimately absent
# (every variant/architecture permutation), so it cannot treat "no output" as
# an error. That means a malformed packages.yaml would otherwise surface as
# every lookup returning nothing -- an image built from empty package lists
# rather than a failed build. Catching the parse error once, up front, is what
# makes the per-key leniency below safe.
validate_packages_yaml() {
    local yq_stderr

    if [[ ! -f "${PACKAGES_YAML}" ]]
    then
        echo "ERROR: packages.yaml not found at ${PACKAGES_YAML}" >&2
        return 1
    fi

    # A no-op expression forces yq to parse the whole document without
    # emitting it, which is the cheapest way to force a syntax check.
    if ! yq_stderr="$(yq 'true' < "${PACKAGES_YAML}" 2>&1 >/dev/null)"
    then
        echo "ERROR: ${PACKAGES_YAML} is not valid YAML" >&2
        echo "${yq_stderr}" >&2
        return 1
    fi

    return 0
}


# Emits the elements of a packages.yaml sequence, one per line.
#
# get_yaml_array() probes many keys that will not exist for a given build, so
# an absent key must stay silent. What must NOT stay silent is a key that
# exists with the wrong shape -- a string or a map where a list was meant,
# which is what a hand-edit typo in packages.yaml actually produces. yq exits
# 0 in that case and simply prints nothing, so the shape is checked explicitly
# via the node's tag rather than inferred from yq's status.
#
# param $1: the path to a sequence node, e.g. '.immutablue.rpm.all'
# returns: 0 on success (including an absent key), non-zero on a bad shape or
#          a yq failure
yq_query() {
    local path="$1"
    local node_tag

    # Determine what is actually at this path. '| tag' reports '!!null' for an
    # absent key, so this single call separates "not present" from "present
    # but wrong".
    if ! node_tag="$(yq "${path} | tag" < "${PACKAGES_YAML}" 2>&1)"
    then
        echo "ERROR: yq failed reading '${path}' from ${PACKAGES_YAML}" >&2
        echo "${node_tag}" >&2
        return 1
    fi

    case "${node_tag}" in
        '!!null')
            # Key is absent for this variant/architecture/version. Expected.
            return 0
            ;;
        '!!seq')
            ;;
        *)
            echo "ERROR: ${PACKAGES_YAML}: '${path}' is ${node_tag}, expected a list (!!seq)" >&2
            echo "       A scalar or mapping here is silently ignored by yq and would" >&2
            echo "       produce an image built from an incomplete package list." >&2
            return 1
            ;;
    esac

    # The tag check above already proved this is a sequence, so the expansion
    # cannot fail on shape; a failure here would be an unreadable file, which
    # the caller's 'set -e' should surface.
    yq "${path}[]" < "${PACKAGES_YAML}"
}


# looks up entries in packages.yaml
# takes into account the version, architecture and build options
#
# Every lookup is guarded with '|| return': without it the function would
# report the status of only its LAST probe, so a malformed key early in the
# list would be swallowed and the caller would receive a short list with a
# success status -- the exact failure mode this guarding exists to prevent.
get_yaml_array() {
    local key="$1"
    # Base all
    yq_query "${key}.all" || return
    # Version specific
    if [[ -n "${VERSION}" ]]; then
        yq_query "${key}.${VERSION}" || return
    fi
    # Architecture all
    yq_query "${key}.all_${MARCH}" || return
    # Version + architecture
    if [[ -n "${VERSION}" ]]; then
        yq_query "${key}.${VERSION}_${MARCH}" || return
    fi
    # Build options
    while read -r option
    do
        # Option all
        yq_query "${key}_${option}.all" || return
        # Option version
        if [[ -n "${VERSION}" ]]; then
            yq_query "${key}_${option}.${VERSION}" || return
        fi
        # Option architecture all
        yq_query "${key}_${option}.all_${MARCH}" || return
        # Option version architecture
        if [[ -n "${VERSION}" ]]; then
            yq_query "${key}_${option}.${VERSION}_${MARCH}" || return
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

