# ════════════════════════════════════════════════════════════════════════════
# POWER MANAGEMENT - SUSPEND CONTROL
# ════════════════════════════════════════════════════════════════════════════
#
# On Silverblue (GNOME): uses gsettings to control idle auto-suspend
# On non-GNOME variants: uses systemctl mask/unmask on sleep targets


# disable suspend for both ac and battery
disable_suspend:
    #!/bin/bash
    set -euo pipefail
    source /usr/libexec/immutablue/immutablue-header.sh

    if [[ "$(immutablue_build_is_silverblue)" == "${TRUE}" ]]
    then
        gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing'
        gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type 'nothing'
        echo "disabled idle suspend for ac and battery (gsettings)"
    else
        sudo systemctl mask suspend.target hibernate.target hybrid-sleep.target sleep.target
        echo "disabled suspend system-wide (systemctl mask)"
    fi


# enable suspend for both ac and battery
enable_suspend:
    #!/bin/bash
    set -euo pipefail
    source /usr/libexec/immutablue/immutablue-header.sh

    if [[ "$(immutablue_build_is_silverblue)" == "${TRUE}" ]]
    then
        gsettings reset org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type
        gsettings reset org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type
        echo "enabled idle suspend for ac and battery (gsettings reset to defaults)"
    else
        sudo systemctl unmask suspend.target hibernate.target hybrid-sleep.target sleep.target
        echo "enabled suspend system-wide (systemctl unmask)"
    fi


# disable idle suspend on ac power
disable_suspend_ac:
    #!/bin/bash
    set -euo pipefail
    source /usr/libexec/immutablue/immutablue-header.sh

    if [[ "$(immutablue_build_is_silverblue)" == "${TRUE}" ]]
    then
        gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing'
        echo "disabled idle suspend on ac power (gsettings)"
    else
        echo "note: systemctl mask applies system-wide (no ac/battery distinction)"
        sudo systemctl mask suspend.target hibernate.target hybrid-sleep.target sleep.target
        echo "disabled suspend system-wide (systemctl mask)"
    fi


# enable idle suspend on ac power
enable_suspend_ac:
    #!/bin/bash
    set -euo pipefail
    source /usr/libexec/immutablue/immutablue-header.sh

    if [[ "$(immutablue_build_is_silverblue)" == "${TRUE}" ]]
    then
        gsettings reset org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type
        echo "enabled idle suspend on ac power (gsettings reset to default)"
    else
        echo "note: systemctl unmask applies system-wide (no ac/battery distinction)"
        sudo systemctl unmask suspend.target hibernate.target hybrid-sleep.target sleep.target
        echo "enabled suspend system-wide (systemctl unmask)"
    fi


# disable idle suspend on battery
disable_suspend_battery:
    #!/bin/bash
    set -euo pipefail
    source /usr/libexec/immutablue/immutablue-header.sh

    if [[ "$(immutablue_build_is_silverblue)" == "${TRUE}" ]]
    then
        gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type 'nothing'
        echo "disabled idle suspend on battery (gsettings)"
    else
        echo "note: systemctl mask applies system-wide (no ac/battery distinction)"
        sudo systemctl mask suspend.target hibernate.target hybrid-sleep.target sleep.target
        echo "disabled suspend system-wide (systemctl mask)"
    fi


# enable idle suspend on battery
enable_suspend_battery:
    #!/bin/bash
    set -euo pipefail
    source /usr/libexec/immutablue/immutablue-header.sh

    if [[ "$(immutablue_build_is_silverblue)" == "${TRUE}" ]]
    then
        gsettings reset org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type
        echo "enabled idle suspend on battery (gsettings reset to default)"
    else
        echo "note: systemctl unmask applies system-wide (no ac/battery distinction)"
        sudo systemctl unmask suspend.target hibernate.target hybrid-sleep.target sleep.target
        echo "enabled suspend system-wide (systemctl unmask)"
    fi
