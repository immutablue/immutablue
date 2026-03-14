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


# ==============================================================================
# Immunablue: Verified Download Functions
# ==============================================================================
# When 'immunablue' is in BUILD_OPTIONS, all binary downloads are verified
# against SHA256 checksums from immunablue/checksums.yaml.
# ==============================================================================

IMMUNABLUE_CHECKSUMS_FILE="/mnt-ctx/immunablue/checksums.yaml"
IMMUNABLUE_ACTIVE=""

# Detect if immunablue is enabled
if [[ "$(is_option_in_build_options immunablue)" == "${TRUE}" ]]; then
    IMMUNABLUE_ACTIVE="true"
    echo "IMMUNABLUE: Security hardening ENABLED"

    if [[ ! -f "${IMMUNABLUE_CHECKSUMS_FILE}" ]]; then
        echo "IMMUNABLUE FATAL: checksums.yaml not found at ${IMMUNABLUE_CHECKSUMS_FILE}"
        exit 1
    fi

    # Load all checksums into variables for fast lookup
    IMMUNABLUE_HUGO_SHA256=$(yq ".hugo.${MARCH}.sha256" < "${IMMUNABLUE_CHECKSUMS_FILE}")
    IMMUNABLUE_JUST_SHA256=$(yq ".just.${MARCH}.sha256" < "${IMMUNABLUE_CHECKSUMS_FILE}")
    IMMUNABLUE_FZF_GIT_SHA256=$(yq ".fzf_git.all.sha256" < "${IMMUNABLUE_CHECKSUMS_FILE}")
    IMMUNABLUE_STARSHIP_SHA256=$(yq ".starship_installer.all.sha256" < "${IMMUNABLUE_CHECKSUMS_FILE}")
    IMMUNABLUE_ZEROFS_SHA256=$(yq ".zerofs.all.sha256" < "${IMMUNABLUE_CHECKSUMS_FILE}")
    IMMUNABLUE_CHAINSAW_SHA256=$(yq ".chainsaw.${MARCH}.sha256" < "${IMMUNABLUE_CHECKSUMS_FILE}")
    IMMUNABLUE_FLUX_SHA256=$(yq ".flux.${MARCH}.sha256" < "${IMMUNABLUE_CHECKSUMS_FILE}")
    IMMUNABLUE_SOPS_SHA256=$(yq ".sops.${MARCH}.sha256" < "${IMMUNABLUE_CHECKSUMS_FILE}")
    IMMUNABLUE_CRIO_SHA256=$(yq ".crio.${MARCH}.sha256" < "${IMMUNABLUE_CHECKSUMS_FILE}")
    IMMUNABLUE_NIX_SHA256=$(yq ".nix_installer.all.sha256" < "${IMMUNABLUE_CHECKSUMS_FILE}")
fi

# immunablue_verify_sha256 <file_path> <expected_sha256> <label>
# Verifies a downloaded file's SHA256 against an expected value.
# Exits with error on mismatch. No-op if immunablue is not active.
immunablue_verify_sha256() {
    local file_path="$1"
    local expected="$2"
    local label="${3:-$(basename "$file_path")}"

    if [[ "${IMMUNABLUE_ACTIVE}" != "true" ]]; then
        return 0
    fi

    if [[ -z "${expected}" ]] || [[ "${expected}" == "null" ]]; then
        echo "IMMUNABLUE ERROR: No checksum found for ${label}"
        echo "Add the SHA256 hash to immunablue/checksums.yaml"
        exit 1
    fi

    local actual
    actual=$(sha256sum "${file_path}" | awk '{print $1}')

    if [[ "${actual}" != "${expected}" ]]; then
        echo "IMMUNABLUE ERROR: SHA256 verification FAILED for ${label}"
        echo "  Expected: ${expected}"
        echo "  Got:      ${actual}"
        echo ""
        echo "The remote file has changed since the checksum was recorded."
        echo "If expected (version update), update immunablue/checksums.yaml"
        echo "after verifying the new content is legitimate."
        rm -f "${file_path}"
        exit 1
    fi

    echo "IMMUNABLUE: SHA256 verified — ${label}"
}

# immunablue_verified_curl <output_path> <url> <expected_sha256> [<label>]
# Downloads a file via curl and verifies its SHA256 checksum.
# When immunablue is not active, performs a standard curl download.
immunablue_verified_curl() {
    local output="$1"
    local url="$2"
    local expected_sha256="${3:-}"
    local label="${4:-$(basename "$output")}"

    if [[ "${IMMUNABLUE_ACTIVE}" == "true" ]]; then
        # Use -f (fail on HTTP errors) — no silent failures
        curl -fLo "${output}" "${url}"
        immunablue_verify_sha256 "${output}" "${expected_sha256}" "${label}"
    else
        curl -Lo "${output}" "${url}"
    fi
}

