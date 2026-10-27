#!/bin/bash
# backends/lib/run-stages.sh
#
# Runs the image build: every platform-neutral stage in build/NN-*.sh and every
# stage the selected backend adds in backends/<backend>/stages/NN-*.sh, merged
# into one sequence ordered by file name, then the backend's finalize step.
#
# Merging by name is what lets a backend put an OS-only step exactly where it
# belongs (Fedora's kernel/ZFS work at 29, its codec swaps at 35/36) without
# the neutral stages knowing it exists. When two files share a name prefix the
# build/ one runs first, so a backend stage can rely on the neutral stage of
# the same number having finished.
#
# Each stage is fed to bash on stdin, as the Containerfile always did, and the
# build stops at the first stage that fails.
#
# Environment: everything the Containerfile ARGs export, notably INSTALL_DIR,
# IMMUTABLUE_BACKEND and IMMUTABLUE_BUILD_OPTIONS.
#
# Usage: run-stages.sh [<repo root>]   (default: /mnt-ctx, the build context)
set -euo pipefail

CTX="${1:-/mnt-ctx}"
IMMUTABLUE_BACKEND="${IMMUTABLUE_BACKEND:-fedora-bootc}"
BACKEND_STAGES="${CTX}/backends/${IMMUTABLUE_BACKEND}/stages"

if [[ ! -d "${CTX}/backends/${IMMUTABLUE_BACKEND}" ]]
then
    echo "ERROR: unknown backend '${IMMUTABLUE_BACKEND}' (no ${CTX}/backends/${IMMUTABLUE_BACKEND})" >&2
    exit 1
fi


# Emit "<basename><TAB><rank><TAB><path>" for every stage, so a plain sort
# orders by name and puts build/ (rank 0) ahead of the backend (rank 1) on a
# tie. 99-common.sh is a library, not a stage, and is excluded.
list_stages() {
    local script

    for script in "${CTX}"/build/*.sh
    do
        [[ "$(basename "${script}")" == "99-common.sh" ]] && continue
        printf '%s\t0\t%s\n' "$(basename "${script}")" "${script}"
    done

    if [[ -d "${BACKEND_STAGES}" ]]
    then
        for script in "${BACKEND_STAGES}"/*.sh
        do
            [[ -e "${script}" ]] || continue
            printf '%s\t1\t%s\n' "$(basename "${script}")" "${script}"
        done
    fi
}


mapfile -t stages < <(list_stages | LC_ALL=C sort -t $'\t' -k1,1 -k2,2n | cut -f3)

echo "=== Backend: ${IMMUTABLUE_BACKEND}; ${#stages[@]} stages ==="
printf '    %s\n' "${stages[@]}"

for script in "${stages[@]}"
do
    echo "=== Stage: ${script#"${CTX}"/} ==="
    if ! bash < "${script}"
    then
        echo "ERROR: ${script} failed" >&2
        exit 1
    fi
done


# Finalize through the backend, with the same library every stage uses. By now
# 10-copy.sh has installed the repo at INSTALL_DIR and the runtime header the
# library sources.
echo "=== Finalize: ${IMMUTABLUE_BACKEND} ==="
# shellcheck source=build/99-common.sh
source "${INSTALL_DIR}/build/99-common.sh"
backend_finalize
