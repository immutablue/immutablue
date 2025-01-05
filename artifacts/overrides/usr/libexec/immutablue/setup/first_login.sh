#!/bin/bash 
set -euxo pipefail
source /usr/libexec/immutablue/immutablue-header.sh

if [[ ! -f /etc/immutablue/setup/did_first_boot_graphical ]]
then 
    bash < /usr/libexec/immutablue/setup/first_boot_graphical.sh
    status_code=$?
    if [[ $status_code -ne 0 ]]
    then 
        exit $status_code
    fi
fi

exit 0

