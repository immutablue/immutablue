# ════════════════════════════════════════════════════════════════════════════
# FREEBSD (freebsd-be)
# ════════════════════════════════════════════════════════════════════════════
#
# Imported into the Justfile by backends/freebsd-be/stages/61-freebsd-desktop.sh
# on FreeBSD images only.


# Show or choose the login screen: gdm (GNOME's lock screen) or lightdm (gowl and CMacs at login, GNOME cannot lock)
display_manager dm="":
    #!/bin/bash
    set -euo pipefail

    # .immutablue.freebsd.display_manager, read at each boot by
    # rc.d/immutablue_dm, which writes /etc/rc.conf.d/{gdm,lightdm} from it.
    # The system copy lives in /etc/immutablue/settings.yaml, which updates
    # keep.
    key=".immutablue.freebsd.display_manager"
    settings="/etc/immutablue/settings.yaml"
    current="$(immutablue-settings "${key}" 2> /dev/null || true)"
    case "${current}" in
        lightdm) ;;
        *) current="gdm" ;;
    esac
    dm="{{ dm }}"

    if [[ -z "${dm}" ]]
    then
        echo "Login screen: ${current}"
        echo "  gdm      GNOME's lock screen; gowl and CMacs start from a text console"
        echo "  lightdm  gowl and CMacs at login; GNOME sessions cannot lock"
        echo "Change it: immutablue display_manager <gdm|lightdm>"
        exit 0
    fi
    if [[ "${dm}" != "gdm" ]] && [[ "${dm}" != "lightdm" ]]
    then
        echo "display_manager takes gdm or lightdm, not '${dm}'" >&2
        exit 1
    fi
    if [[ "${dm}" == "${current}" ]]
    then
        echo "The login screen is already ${dm}."
        exit 0
    fi

    sudo mkdir -p "$(dirname "${settings}")"
    if sudo test -s "${settings}"
    then
        sudo yq -i "${key} = \"${dm}\"" "${settings}"
    else
        printf 'immutablue:\n  freebsd:\n    display_manager: %s\n' "${dm}" | sudo tee "${settings}" > /dev/null
    fi
    if [[ "$(yq "${key}" "${settings}")" != "${dm}" ]]
    then
        echo "Could not record ${dm} in ${settings}" >&2
        exit 1
    fi
    # Rewrite /etc/rc.conf.d now, so the next boot needs nothing else.
    sudo service immutablue_dm start > /dev/null
    echo "Login screen set to ${dm}; it takes over at the next boot."
    echo "To switch now (this ends the graphical session):"
    echo "  sudo service ${current} stop && sudo service ${dm} start"
