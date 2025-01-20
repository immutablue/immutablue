#!/bin/bash 
set -euo pipefail
source /usr/libexec/immutablue/immutablue-header.sh

if [[ "$(immutablue-settings .immutablue.run_first_boot_script)" != "true" ]]
then 
    echo ".immutablue.run-first-boot-script is not set to \"true\" -- bailing"
    exit 0
fi

# Not doing anything here currently so just return 0 status
exit 0

