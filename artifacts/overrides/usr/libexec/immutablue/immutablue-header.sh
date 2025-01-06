#!/bin/bash 
# The purpose of this file is to not be ran directly
# rather to be sourced in other files. It provides 
# useful functions that can be used elsewhere.
#
# To Use:
# source /usr/libexec/immutablue/immutablue-header.sh


# C style defs
TRUE=1
FALSE=0


# quay.io/immutablue/immutablue:41-lts
# returns: immutablue:41-lts
immutablue_get_image_full() {
    rpm-ostree status | grep -i quay | head -n 1 | awk -F/ '{ printf "%s\n", $3 }'
}

# quay.io/immutablue/immutablue:41-lts
# returns: 41-lts
immutablue_get_image_tag() {
    immutablue_get_image_full | awk -F: '{printf "%s\n", $2 }'
}

# quay.io/immutablue/immutablue:41-lts
# returns: immutablue
immutablue_get_image_base() {
    immutablue_get_image_full | awk -F: '{printf "%s\n", $1 }'
}


immutablue_build_is_nucleus() {
    if [[ "$(immutablue_get_image_tag)" =~ nucleus ]] 
    then 
        echo ${TRUE}
    else
        echo ${FALSE}
    fi
}

immutablue_build_is_kuberblue() {
    if [[ "$(immutablue_get_image_tag)" =~ kuberblue ]] 
    then 
        echo ${TRUE}
    else
        echo ${FALSE}
    fi
}

immutablue_build_is_trueblue() {
    if [[ "$(immutablue_get_image_tag)" =~ trueblue ]] 
    then 
        echo ${TRUE}
    else
        echo ${FALSE}
    fi
}

immutablue_build_is_lts() {
    if [[ "$(immutablue_get_image_tag)" =~ lts ]] 
    then 
        echo ${TRUE}
    else
        echo ${FALSE}
    fi
}

immutablue_build_is_cyan() {
    if [[ "$(immutablue_get_image_tag)" =~ cyan ]] 
    then 
        echo ${TRUE}
    else
        echo ${FALSE}
    fi
}


# takes two args:
# arg1: regex of package 
# arg2: exclude package regex (if not needed pass "null")
immutablue_build_has_package() {
    local pkg_search="$1"
    local pkg_exclude="$2"
    pkg=$(rpm -qa | grep -P "${pkg_search}" | grep -vP "${pkg_exclude}")
    if [[ "$pkg" != "" ]]
    then 
        echo ${TRUE}
    else
        echo ${FALSE}
    fi
}

immutablue_build_has_zfs() {
    immutablue_build_has_package "^zfs" "zfs-fuse"
}

immutablue_build_has_gnome() {
    immutablue_build_has_package "^gnome-session-\d{1,3}" "null"
}

immutablue_build_has_working_tailscale() {
    type tailscale >/dev/null 2>/dev/null
    if [[ $? -eq 0 ]]
    then 
        if [[ "$(tailscale status --json | jq .BackendState)" == "\"Running\"" ]]
        then
            if [[ "$(tailscale ip -4)" =~ ^100\. ]]
            then
                echo $TRUE
            fi
        fi
    else
        echo $FALSE
    fi
}

immutablue_has_internet_v4() {
    ping -c1 -W2 9.9.9.9 >/dev/null 2>/dev/null
    if [[ $? -eq 0 ]]
    then
        echo $TRUE 
    else
        echo $FALSE
    fi
}

immutablue_has_internet_v6() {
    ping -c1 -W2 2620:fe::fe >/dev/null 2>/dev/null
    if [[ $? -eq 0 ]]
    then
        echo $TRUE 
    else
        echo $FALSE
    fi
}

immutablue_has_internet() {
    if [[ "$(immutablue_has_internet_v4)" == "${FALSE}" ]]
    then
        if [[ "$(immutablue_has_internet_v6)" == "${FALSE}" ]]
        then
            echo "${FALSE}"
        else
            echo "${TRUE}"
        fi
    else 
        echo "${TRUE}"
    fi
}


immutablue_get_terminal_command() {
    type kitty 2>/dev/null >/dev/null
    if [[ $? -eq 0 ]] 
    then 
        echo "kitty"
        return 0
    fi

    type ptyxis 2>/dev/null >/dev/null 
    if [[ $? -eq 0 ]] 
    then 
        echo "ptyxis --"
        return 0
    fi
    
    type gnome-terminal 2>/dev/null >/dev/null 
    if [[ $? -eq 0 ]] 
    then 
        echo "gnome-terminal --"
        return 0
    fi

    echo "" 
}

