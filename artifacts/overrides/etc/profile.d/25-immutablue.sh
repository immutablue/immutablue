#!/bin/bash
# This profile script is part of immutablue
# - https://gitlab.com/immutablue/immutablue

# Set ulimits
if [[ "$(whoami)" != "root" ]]
then
    ulimit -n 65535
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

