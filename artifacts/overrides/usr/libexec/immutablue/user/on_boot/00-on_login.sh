#!/bin/bash
set -euo pipefail
source /usr/libexec/immutablue/immutablue-header.sh

echo "$USER has logged in"

# if [[ ! -f "${HOME}/.config/.immutablue_did_first_login" ]]
# then
#     bash < /usr/libexec/immutablue/setup/first_login.sh &
# fi

if [[ "$(immutablue_build_has_package docker null)" == "${TRUE}" ]]
then
    has_docker_group=$(grep -iP "docker" < /etc/group)
    if [[ "${has_docker_group}" != "" ]]
    then
        already_in_group=$(groups | grep -iP "docker")
        if [[ "${already_in_group}" == "" ]]
        then
            # Add user to group
            sudo usermod -aG docker ${USER}
        fi
    fi
fi


# Check for settings file, if not present create it 
if [[ ! -f "${HOME}/.config/immutablue/settings.yaml" ]]
then 
    mkdir -p "${HOME}/.config/immutablue"
    echo -e "# Immutablue Settings file -- see /usr/immutablue/settings.yaml\n" > "${HOME}/.config/immutablue/settings.yaml"
fi
