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
# Distroless builds don't use dnf/yum repos
# -----------------------------------
if [[ "$(is_option_in_build_options distroless)" == "${TRUE}" ]]
then
    echo "=== Distroless build: skipping yum/dnf repository setup ==="
    exit 0
fi

# -----------------------------------
# Resolve repositories for THIS Fedora version.
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

    {
        yq "${key}.all[]? | select(.name == \"${name}\").url" < "${PACKAGES_YAML}" 2>/dev/null || true
        if [[ -n "${VERSION}" ]]
        then
            yq "${key}.${VERSION}[]? | select(.name == \"${name}\").url" < "${PACKAGES_YAML}" 2>/dev/null || true
        fi
    } | grep -v '^null$' | grep -v '^$' | head -1
}


# Every key that can define a repository, most general first.
repo_keys=(
    ".immutablue.repo_urls"
    ".immutablue.repo_urls_${MARCH}"
)

while read -r option
do
    repo_keys+=(
        ".immutablue.repo_urls_${option}"
        ".immutablue.repo_urls_${option}_${MARCH}"
    )
done < <(get_immutablue_build_options)


# Collect the repo names, deduplicated: a name that appears under several keys
# only needs downloading once, and the previous code fetched it repeatedly.
repos="$(
    for key in "${repo_keys[@]}"
    do
        repo_names_for_key "${key}"
    done | grep -v '^null$' | grep -v '^$' | sort -u
)"


# Download each repo from the most specific key that defines it, so an
# architecture- or variant-specific URL wins over a general one.
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

    # Unlike before, a failed download is reported rather than silently
    # swallowed -- a missing repo means the packages it provides will be
    # missing from the image.
    if ! curl -fLo "/etc/yum.repos.d/${repo}" "${repo_url}"
    then
        echo "ERROR: failed to download ${repo} from ${repo_url}" >&2
        exit 1
    fi
    echo "Added ${repo} from ${repo_url}"
done


# -----------------------------------
# Deprioritise the third-party repos added above.
#
# Fedora's own repos carry the dnf default priority of 99, and a lower number
# wins. Every repo curled above therefore competes with Fedora base on equal
# footing: whichever has the higher package version wins, regardless of which
# is the intended source. These are single-purpose repos (tailscale,
# podman-bootc, znapzend), so a COPR that happens to carry a newer build of
# some shared dependency can silently replace the Fedora package for the whole
# image, and nothing in the build would report it.
#
# Setting them to 200 keeps them usable for the packages they exist to provide
# while making Fedora authoritative for everything else.
#
# Deliberately NOT applied to:
#   RPM Fusion  -- installed from release RPMs via rpm_url, and the mesa /
#                  ffmpeg freeworld swaps in 35-* and 36-* depend on pulling
#                  replacements from it.
#   the ZFS repo -- installed from a release RPM for the same reason.
# Both are intentional overrides of Fedora packages, which is exactly what the
# priority above is meant to prevent for everything else.
# -----------------------------------
REPO_PRIORITY=200

for repo in $repos
do
    repo_file="/etc/yum.repos.d/${repo}"

    # curl leaves a file behind even when the URL was empty (a repo that does
    # not apply to this architecture or build option), so only touch files
    # that actually parsed as a repo definition.
    if [[ ! -s "${repo_file}" ]] || ! grep -q '^\[' "${repo_file}"
    then
        continue
    fi

    # Respect an upstream repo that ships its own priority rather than
    # overriding a deliberate choice by whoever published it.
    if grep -qE '^[[:space:]]*priority[[:space:]]*=' "${repo_file}"
    then
        echo "Leaving ${repo_file} at its shipped priority"
        continue
    fi

    # Insert the priority into every section; a .repo file routinely defines
    # several (a COPR ships its main repo plus debuginfo/source variants).
    awk -v prio="${REPO_PRIORITY}" '
        /^\[/ { print; print "priority=" prio; next }
        { print }
    ' "${repo_file}" > "${repo_file}.tmp"
    mv "${repo_file}.tmp" "${repo_file}"
    echo "Set priority=${REPO_PRIORITY} on ${repo_file}"
done


