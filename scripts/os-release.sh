#!/bin/bash
# os-release.sh
#
# Write the image's os-release(5) from its base and the build options, so the
# name, version and variant are derived at build time instead of hand-kept per
# release (the old artifacts/overrides/etc/.os-release-<version> files) or per
# variant (overrides_kuberblue/etc/os-release, which never shipped: 10-copy.sh
# replaced /etc/os-release with a link to the generic file after copying it).
#
# The base supplies everything this script does not set -- ID, ID_LIKE,
# VERSION_ID, PLATFORM_ID, CPE_NAME, SUPPORT_END, LOGO, ... -- so on Fedora
# those come from the base image's own /usr/lib/os-release and are right for
# whichever release is being built. backend.yaml names the base and how the
# version reads:
#
#   os_release_base:     /usr/lib/os-release (absolute: from the image), or a
#                        file in the backend directory (arch, freebsd)
#   os_release_version:  e.g. "{VERSION_ID}" -> "44", "FreeBSD {VERSION_ID}"
#   os_release_aliases:  build option -> variant id, e.g. {silverblue: gnome}
#                        where "silverblue" means plain GNOME
#
# Fields written:
#   NAME            Kuberblue for kuberblue images, else Immutablue
#   VARIANT/_ID     the build options that name the image, in tag order:
#                   'gui' and 'zfs' never do (zfs adds no tag suffix), nor
#                   'lts' on trueblue (implied), nor kuberblue (it is NAME)
#   VERSION         "<NAME> <version> (<VARIANT>)", PRETTY_NAME the same
#   VERSION_CODENAME, DEFAULT_HOSTNAME (kuberblue), ANSI_COLOR, *_URL
#
# An image built FROM Immutablue (hyacinth-macaw, immutablue-custom) can
# brand the same file, from its own build/10-copy.sh, through the environment:
#   OS_RELEASE_NAME      replaces "Immutablue" (kuberblue still wins)
#   OS_RELEASE_URL       replaces the Immutablue home/support/bug URLs
#   OS_RELEASE_HOSTNAME  DEFAULT_HOSTNAME when not kuberblue
#
# Usage: os-release.sh <backend_dir> <build_options_csv> <out_file> [<base_file>]
#   os-release.sh /usr/immutablue/backends/fedora-bootc nucleus,kuberblue /etc/.os-release-44
#   -> NAME="Kuberblue", PRETTY_NAME="Kuberblue 44 (Nucleus)", VARIANT_ID=nucleus
# <base_file> overrides backend.yaml's os_release_base (tests).
set -euo pipefail

if [[ $# -lt 3 ]] || [[ $# -gt 4 ]]
then
    echo 'os-release.sh requires 3 or 4 positional arguments'
    echo 'os-release.sh <backend_dir> <build_options_csv> <out_file> [<base_file>]'
    exit 1
fi

backend_dir="${1}"
build_options="${2}"
out_file="${3}"
base_file="${4:-}"
backend_yaml="${backend_dir}/backend.yaml"


# -----------------------------------
# The base os-release.
# -----------------------------------
if [[ -z "${base_file}" ]]
then
    base_file="$(yq '.os_release_base // "/usr/lib/os-release"' < "${backend_yaml}")"
    if [[ "${base_file}" != /* ]]
    then
        base_file="${backend_dir}/${base_file}"
    fi
fi
if [[ ! -f "${base_file}" ]]
then
    echo "ERROR: os-release base ${base_file} does not exist" >&2
    exit 1
fi

# Read the base into an ordered key list and a value map, unquoting values.
declare -a keys=()
declare -A values=()
while IFS= read -r line || [[ -n "${line}" ]]
do
    [[ "${line}" =~ ^([A-Z0-9_]+)=(.*)$ ]] || continue
    key="${BASH_REMATCH[1]}"
    value="${BASH_REMATCH[2]}"
    value="${value#[\"\']}"
    value="${value%[\"\']}"
    if [[ -z "${values[${key}]+set}" ]]
    then
        keys+=("${key}")
    fi
    values["${key}"]="${value}"
done < "${base_file}"


# -----------------------------------
# Name and variant from the build options.
# -----------------------------------

# Human label for a variant id; anything unlisted is title-cased.
variant_label () {
    local id="${1}"
    local label

    case "${id}" in
        lts) label="LTS" ;;
        cosmic) label="COSMIC" ;;
        gnome) label="GNOME" ;;
        build-a-blue-workshop) label="Build-a-Blue Workshop" ;;
        *) label="${id^}" ;;
    esac
    echo "${label}"
}

name="${OS_RELEASE_NAME:-Immutablue}"
declare -a options=()
IFS=',' read -ra options <<< "${build_options}"

is_trueblue=0
for option in "${options[@]}"
do
    if [[ "${option}" == "kuberblue" ]]
    then
        name="Kuberblue"
    fi
    if [[ "${option}" == "trueblue" ]]
    then
        is_trueblue=1
    fi
done

declare -a variant_ids=()
declare -a variant_labels=()
for option in "${options[@]}"
do
    case "${option}" in
        ""|gui|zfs|kuberblue) continue ;;
        lts) [[ ${is_trueblue} -eq 1 ]] && continue ;;
        *) ;;
    esac
    id="$(yq ".os_release_aliases.${option} // \"${option}\"" < "${backend_yaml}")"
    id="${id//_/-}"
    variant_ids+=("${id}")
    variant_labels+=("$(variant_label "${id}")")
done
if [[ ${#variant_ids[@]} -eq 0 ]]
then
    variant_ids=("base")
    variant_labels=("Base")
fi

variant_id="$(IFS='-'; echo "${variant_ids[*]}")"
variant="${variant_labels[0]}"
for label in "${variant_labels[@]:1}"
do
    variant="${variant}, ${label}"
done


# -----------------------------------
# Version, as the backend phrases it.
# -----------------------------------
version="$(yq '.os_release_version // "{VERSION_ID}"' < "${backend_yaml}")"
version="${version//\{VERSION_ID\}/${values[VERSION_ID]:-}}"
version="${version# }"
version="${version% }"

if [[ -n "${version}" ]]
then
    pretty="${name} ${version} (${variant})"
else
    pretty="${name} (${variant})"
fi


# -----------------------------------
# Override, then write in the base's order with new keys appended.
# -----------------------------------
set_field () {
    local key="${1}"
    local value="${2}"

    if [[ -z "${values[${key}]+set}" ]]
    then
        keys+=("${key}")
    fi
    values["${key}"]="${value}"
}

set_field NAME "${name}"
set_field VERSION "${pretty}"
set_field PRETTY_NAME "${pretty}"
set_field VERSION_CODENAME "Immutablue"
set_field VARIANT "${variant}"
set_field VARIANT_ID "${variant_id}"
set_field ANSI_COLOR "0;38;2;60;110;180"
if [[ -n "${OS_RELEASE_URL:-}" ]]
then
    set_field HOME_URL "${OS_RELEASE_URL}"
    set_field DOCUMENTATION_URL "${OS_RELEASE_URL}"
    set_field SUPPORT_URL "${OS_RELEASE_URL}"
    set_field BUG_REPORT_URL "${OS_RELEASE_URL}"
else
    set_field HOME_URL "https://gitlab.com/immutablue/immutablue"
    set_field DOCUMENTATION_URL "https://immutablue.io"
    set_field SUPPORT_URL "https://gitlab.com/immutablue/immutablue"
    set_field BUG_REPORT_URL "https://gitlab.com/immutablue/immutablue/-/issues"
fi
if [[ "${name}" == "Kuberblue" ]]
then
    set_field DEFAULT_HOSTNAME "kuberblue"
elif [[ -n "${OS_RELEASE_HOSTNAME:-}" ]]
then
    set_field DEFAULT_HOSTNAME "${OS_RELEASE_HOSTNAME}"
fi

# ID, VERSION_ID and VARIANT_ID are unquoted identifiers per os-release(5);
# everything else is quoted. Written to a temporary file first so the base
# and the output may be the same file (gnomeos rewrites /usr/lib/os-release).
tmp_file="$(mktemp)"
for key in "${keys[@]}"
do
    case "${key}" in
        ID|VERSION_ID|VARIANT_ID|BUILD_ID|IMAGE_ID|IMAGE_VERSION)
            printf '%s=%s\n' "${key}" "${values[${key}]}" ;;
        *)
            printf '%s="%s"\n' "${key}" "${values[${key}]//\"/\\\"}" ;;
    esac
done > "${tmp_file}"

mkdir -p "$(dirname "${out_file}")"
install -m 0644 "${tmp_file}" "${out_file}"
rm -f "${tmp_file}"

echo "os-release: ${pretty} (VARIANT_ID=${variant_id}) -> ${out_file}"
