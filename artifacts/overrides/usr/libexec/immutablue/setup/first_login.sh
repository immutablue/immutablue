#!/bin/bash 
set -euxo pipefail
source /usr/libexec/immutablue/immutablue-header.sh

if [[ "$(immutablue-settings .immutablue.run_first_login_script)" != "true" ]]
then 
    echo ".immutablue.run-first-login-script is not set to \"true\" -- bailing"
    exit 0
fi

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

