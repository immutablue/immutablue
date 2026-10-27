#!/bin/bash
set -euxo pipefail
if [[ -f "${INSTALL_DIR}/build/99-common.sh" ]]; then source "${INSTALL_DIR}/build/99-common.sh"; fi
if [[ -f "./99-common.sh" ]]; then source "./99-common.sh"; fi

# -----------------------------------
# Fail early and loudly on a malformed packages.yaml.
#
# This is the first build stage that reads the file, and every later stage
# depends on it. Without this check a parse error degrades into empty package
# lists rather than a failed build, producing an image that is missing
# software but reports success.
# -----------------------------------
validate_packages_yaml

# -----------------------------------
# Distroless builds add no repositories
# -----------------------------------
if [[ "$(is_option_in_build_options distroless)" == "${TRUE}" ]]
then
    echo "=== Distroless build: skipping yum/dnf repository setup ==="
    exit 0
fi

# -----------------------------------
# Resolve repositories for THIS release.
#
# The previous implementation queried each repo_urls key with '[][]', which
# flattens every version at once. For a key holding entries under 42, 43 and
# 44 that returned all three URLs, and the resulting
#
#     curl -Lo <file> $'<url42>\n<url43>\n<url44>'
#
# passed the lot as a single malformed argument, so the download failed and the
# repository was silently never added. The base lookup had the mirror-image
# problem: a repo defined only per-architecture produced an empty URL and
# 'curl: option : blank argument where content is expected'. Both errors were
# swallowed by '|| true'.
#
# The effect was that podman-bootc.repo -- and therefore the podman-bootc
# package packages.yaml asks for -- never made it into any image.
#
# Repos are now resolved the same way get_yaml_array() resolves packages:
# '.all' plus the entry for the running version, and nothing else.
# -----------------------------------

# Emit the repo names defined under a key, for this version only.
#
# param $1: the key to read, e.g. '.immutablue.repo_urls_x86_64'
repo_names_for_key() {
    local key="$1"

    yq "${key}.all[]?.name" < "${PACKAGES_YAML}" 2>/dev/null || true
    if [[ -n "${VERSION}" ]]
    then
        yq "${key}.${VERSION}[]?.name" < "${PACKAGES_YAML}" 2>/dev/null || true
    fi
}


# Emit the URL for one repo under a key, for this version only.
#
# head -1 guards against a repo listed twice under both '.all' and the version;
# passing two URLs to a single 'curl -o' is what broke this before.
#
# param $1: the key to read
# param $2: the repo file name to match
repo_url_for_key() {
    local key="$1"
    local name="$2"

    # The trailing '|| true' is load-bearing: this runs under 'set -e' with
    # pipefail, and grep exits 1 when a key defines no matching repo -- which is
    # the normal case for most key/repo combinations. Without it the first
    # non-match aborts the whole build.
    {
        yq "${key}.all[]? | select(.name == \"${name}\").url" < "${PACKAGES_YAML}" 2>/dev/null || true
        if [[ -n "${VERSION}" ]]
        then
            yq "${key}.${VERSION}[]? | select(.name == \"${name}\").url" < "${PACKAGES_YAML}" 2>/dev/null || true
        fi
    } | grep -v '^null$' | grep -v '^$' | head -1 || true
}


# Every key that can define a repository, most general first. The base key is
# the backend's (repo_urls for Fedora's .repo files); the suffixes follow the
# same option/architecture rules as package lists.
repo_base_key=".immutablue.$(backend_get repo_key)"
if [[ "${repo_base_key}" == ".immutablue." ]]
then
    echo "Backend ${IMMUTABLUE_BACKEND} defines no repo_key; skipping repository setup"
    exit 0
fi

repo_keys=(
    "${repo_base_key}"
    "${repo_base_key}_${MARCH}"
)

while read -r option
do
    repo_keys+=(
        "${repo_base_key}_${option}"
        "${repo_base_key}_${option}_${MARCH}"
    )
done < <(get_immutablue_build_options)


# Collect the repo names, deduplicated: a name that appears under several keys
# only needs downloading once, and the previous code fetched it repeatedly.
repos="$(
    for key in "${repo_keys[@]}"
    do
        repo_names_for_key "${key}"
    done | grep -v '^null$' | grep -v '^$' | sort -u || true
)"


# Add each repo from the most specific key that defines it, so an
# architecture- or variant-specific URL wins over a general one. How a repo is
# added -- a .repo file with a lowered priority on Fedora -- is the backend's
# business; see backend_repo_add.
for repo in ${repos}
do
    repo_url=""
    for key in "${repo_keys[@]}"
    do
        candidate="$(repo_url_for_key "${key}" "${repo}")"
        if [[ -n "${candidate}" ]]
        then
            repo_url="${candidate}"
        fi
    done

    if [[ -z "${repo_url}" ]]
    then
        # Defined for another architecture or variant; not an error.
        echo "No URL for ${repo} on ${MARCH}/${VERSION}; skipping"
        continue
    fi

    backend_repo_add "${repo}" "${repo_url}"
done
