#!/bin/bash
set -euo pipefail
source /usr/libexec/immutablue/immutablue-header.sh

# USER is set by login(1) and by the display manager, but not by every context
# that runs these hooks (systemd user units, CI containers, `su` without `-`).
# Under `set -u` a bare $USER aborts the hook, so fall back to the passwd entry
# for the effective uid, which is what USER would have held anyway.
login_user="${USER:-$(id -un)}"

echo "${login_user} has logged in"

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
        user_groups="$(id -nG "${login_user}")"
        if [[ " ${user_groups} " != *" docker "* ]]
        then
            sudo usermod -aG docker "${login_user}"
        fi
    fi
fi


# Check for settings file, if not present create it 
if [[ ! -f "${HOME}/.config/immutablue/settings.yaml" ]]
then 
    mkdir -p "${HOME}/.config/immutablue"
    echo -e "# Immutablue Settings file -- see /usr/immutablue/settings.yaml\n" > "${HOME}/.config/immutablue/settings.yaml"
fi
