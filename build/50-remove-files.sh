#!/bin/bash 
set -euxo pipefail
if [ -f "${INSTALL_DIR}/build/99-common.sh" ]; then source "${INSTALL_DIR}/build/99-common.sh"; fi
if [ -f "./99-common.sh" ]; then source "./99-common.sh"; fi


files=$(get_immutablue_files_to_remove)


if [[ "$files" != "" ]]
then 
    for file in $files
    do  
        rm -rfv "$file" 
    done 
fi

