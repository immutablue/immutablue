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
	# Missing groups and membership are expected on first login, not errors.
	# Resolve through NSS and compare whole group names (docker-admin is not docker).
	if getent group docker > /dev/null
	then
		user_groups="$(id -nG "${USER}")"
		if [[ " ${user_groups} " != *" docker "* ]]
		then
			sudo usermod -aG docker "${USER}"
		fi
	fi
fi


# Check for settings file, if not present create it 
if [[ ! -f "${HOME}/.config/immutablue/settings.yaml" ]]
then 
    mkdir -p "${HOME}/.config/immutablue"
    echo -e "# Immutablue Settings file -- see /usr/immutablue/settings.yaml\n" > "${HOME}/.config/immutablue/settings.yaml"
fi
