#!/bin/bash
set -euxo pipefail
if [[ -f "${INSTALL_DIR}/build/99-common.sh" ]]; then source "${INSTALL_DIR}/build/99-common.sh"; fi
if [[ -f "./99-common.sh" ]]; then source "./99-common.sh"; fi


files=$(get_immutablue_files_to_remove)


if [[ "$files" != "" ]]
then
    for file in $files
    do
        # A path the container runtime mounts into the build (resolv.conf,
        # hosts, hostname) cannot be removed (EBUSY), and is not part of the
        # committed image anyway; anything else that fails is an error.
        if ! rm -rfv "$file"
        then
            if grep -qs " ${file} " /proc/self/mountinfo
            then
                echo "Skipping ${file}: mounted into the build by the container runtime"
            else
                exit 1
            fi
        fi
    done
fi
