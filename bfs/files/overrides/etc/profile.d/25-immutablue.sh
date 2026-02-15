#!/bin/bash
# This profile script is part of immutablue
# - https://gitlab.com/immutablue/immutablue

# Set ulimits
if [[ "$(whoami)" != "root" ]]
then
    _ulimit_nofile="$(immutablue-settings .immutablue.profile.ulimit_nofile 2>/dev/null)"
    if [[ -z "${_ulimit_nofile}" ]] || [[ "${_ulimit_nofile}" == "null" ]]; then
        _ulimit_nofile=524288
    fi
    ulimit -n "${_ulimit_nofile}"
    unset _ulimit_nofile
fi


# Make sure this is bash
if [[ "${BASH_VERSION-}" != "" ]]
then

    if [[ -f /usr/bin/fzf-git ]] && [[ "$(immutablue-settings .immutablue.profile.enable_sourcing_fzf_git)" == "true" ]]
    then 
        source /usr/bin/fzf-git
    fi
    
    if [[ -d /home/linuxbrew/.linuxbrew/etc/bash_completion.d/ ]] && [[ "$(immutablue-settings .immutablue.profile.enable_brew_bash_completions)" == "true" ]]
    then
        for f in /home/linuxbrew/.linuxbrew/etc/bash_completion.d/*
        do
            # Check if readable
            if [[ -r "${f}" ]]
            then 
                source "${f}"
            fi
        done
        unset f
    fi

    # starship prompt by default
    type starship &>/dev/null
    if [[ $? -eq 0 ]]
    then
        if [[ "$(immutablue-settings .immutablue.profile.enable_starship)" == "true" ]]
        then
            eval "$(starship init bash)"
        fi
    fi


    IMMUTABLUE_BASH_COMPLETION=1
    export IMMUTABLUE_BASH_COMPLETION
fi

