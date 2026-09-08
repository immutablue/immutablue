#!/bin/bash
# gen-dep-info.sh - Record what each vendored dependency was built from
#
# The submodules under deps/ are compiled into the deps container and are NOT
# shipped in the image -- 1.1G of source the image has no use for. What the
# image does need is provenance: which commit of which repository produced the
# binary that is running, so a crash can be read against the exact source.
#
# This writes that as JSON. `immutablue-crash` reads it to clone the right
# repository at the right commit into a crash-analysis directory, which is the
# same capability the shipped tree used to provide, fetched on demand instead.
#
# Usage:
#   gen-dep-info.sh [OUTPUT]      Default: artifacts/overrides/usr/immutablue/deps/dep_info.json
#
# Options:
#   -h, --help     Show this help message
#   --license      Show license information
#
# Exit codes:
#   0 - Success
#   1 - Not a git repository, or a dependency could not be read

set -euo pipefail

VERSION="1.0.0"

DEFAULT_OUT="artifacts/overrides/usr/immutablue/deps/dep_info.json"


show_help() {
    sed -n '2,25p' "$0" | sed 's/^# \{0,1\}//'
}


show_license() {
    echo "gen-dep-info.sh ${VERSION}"
    echo "Copyright (C) Zach Podbielniak"
    echo "License AGPLv3+: GNU AGPL version 3 or later <https://gnu.org/licenses/agpl.html>"
    echo "This is free software: you are free to change and redistribute it."
    echo "There is NO WARRANTY, to the extent permitted by law."
}


# Emit one JSON object for a git checkout.
#
# The remote is normalised to a form that can be cloned: a submodule may be
# configured with an ssh remote that only the maintainer can reach, so the
# .gitmodules URL is preferred when it differs -- that is the one written for
# other people to use.
#
# param $1: the name to record it under
# param $2: the path to the checkout
dep_object() {
    local name="$1"
    local path="$2"
    local commit remote gitmodules_url described dirty

    commit="$(git -C "${path}" rev-parse HEAD 2>/dev/null)" || return 1
    remote="$(git -C "${path}" remote get-url origin 2>/dev/null || echo "")"

    # The superproject's recorded URL, which is what a fresh clone would use.
    gitmodules_url="$(git config -f .gitmodules --get "submodule.${path}.url" 2>/dev/null || echo "")"
    [[ -n "${gitmodules_url}" ]] && remote="${gitmodules_url}"

    described="$(git -C "${path}" describe --tags --always 2>/dev/null || echo "")"

    # A dirty dependency means the binary does not correspond to any commit.
    # Recording it is the difference between "clone this and read it" and
    # "clone this and wonder why the line numbers are wrong".
    if [[ -n "$(git -C "${path}" status --porcelain 2>/dev/null)" ]]; then
        dirty="true"
    else
        dirty="false"
    fi

    printf '    {\n'
    printf '      "name": "%s",\n' "${name}"
    printf '      "commit": "%s",\n' "${commit}"
    printf '      "remote": "%s",\n' "${remote}"
    printf '      "describe": "%s",\n' "${described}"
    printf '      "dirty": %s\n' "${dirty}"
    printf '    }'
}


main() {
    local out="${DEFAULT_OUT}"
    local args=()

    while [[ $# -gt 0 ]]; do
        case "${1}" in
            -h|--help)  show_help; exit 0 ;;
            --license)  show_license; exit 0 ;;
            *)          args+=("${1}"); shift ;;
        esac
    done
    [[ ${#args[@]} -gt 0 ]] && out="${args[0]}"

    if ! git rev-parse --git-dir &>/dev/null; then
        echo "ERROR: not a git repository" >&2
        exit 1
    fi

    mkdir -p "$(dirname "${out}")"

    local self_commit self_remote generated first dir name
    self_commit="$(git rev-parse HEAD)"
    self_remote="$(git remote get-url origin 2>/dev/null || echo "")"
    # UTC, and no seconds-since-epoch: this is read by people as often as by
    # programs, and it lands in a crash report.
    generated="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

    {
        printf '{\n'
        printf '  "generated": "%s",\n' "${generated}"
        printf '  "immutablue": {\n'
        printf '    "commit": "%s",\n' "${self_commit}"
        printf '    "remote": "%s"\n' "${self_remote}"
        printf '  },\n'
        printf '  "note": "Source is not shipped in the image. Clone the remote and check out the commit to read it; immutablue-crash does this into a crash-analysis directory.",\n'
        printf '  "deps": [\n'

        first=1
        for dir in deps/*/; do
            [[ -d "${dir}" ]] || continue
            name="$(basename "${dir}")"
            # A submodule that was never initialised has no HEAD to record, and
            # a manifest that silently omits it would be worse than failing.
            if ! git -C "${dir}" rev-parse HEAD &>/dev/null; then
                echo "ERROR: ${dir} has no checkout -- run: git submodule update --init --recursive" >&2
                exit 1
            fi
            [[ ${first} -eq 0 ]] && printf ',\n'
            dep_object "${name}" "${dir%/}"
            first=0
        done

        printf '\n  ]\n'
        printf '}\n'
    } > "${out}"

    echo "Wrote ${out} ($(python3 -c "import json,sys; print(len(json.load(open('${out}'))['deps']))" 2>/dev/null || echo '?') deps)"
}

main "$@"
