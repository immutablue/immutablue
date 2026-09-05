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

repos=$(cat <(yq '.immutablue.repo_urls[][].name' < ${INSTALL_DIR}/packages.yaml) <(yq ".immutablue.repo_urls_$(uname -m)[][].name" < ${INSTALL_DIR}/packages.yaml))

while read -r option 
do 
    repos=$(cat <(echo "${repos}") <(yq ".immutablue.repo_urls_${option}[][].name" < ${INSTALL_DIR}/packages.yaml) <(yq ".immutablue.repo_urls_${option}_$(uname -m)[][].name" < ${INSTALL_DIR}/packages.yaml))
    echo "${repos}"
done < <(get_immutablue_build_options)


# iterate and download any that have appropriate urls for their base options
for repo in $repos
do 
    curl -Lo "/etc/yum.repos.d/$repo" "$(yq ".immutablue.repo_urls[][] | select(.name == \"$repo\").url" < "${INSTALL_DIR}/packages.yaml")" || true
done

for repo in $repos
do
    curl -Lo "/etc/yum.repos.d/$repo" "$(yq ".immutablue.repo_urls_$(uname -m)[][] | select(.name == \"$repo\").url" < "${INSTALL_DIR}/packages.yaml")" || true
done


# iterate and download any that have appropriate urls for build options
while read -r option 
do 
    for repo in $repos
    do 
        curl -Lo "/etc/yum.repos.d/$repo" "$(yq ".immutablue.repo_urls_${option}[][] | select(.name == \"$repo\").url" < "${INSTALL_DIR}/packages.yaml")" || true
    done

    for repo in $repos
    do
        curl -Lo "/etc/yum.repos.d/$repo" "$(yq ".immutablue.repo_urls_${option}_$(uname -m)[][] | select(.name == \"$repo\").url" < "${INSTALL_DIR}/packages.yaml")" || true
    done
done < <(get_immutablue_build_options)


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


