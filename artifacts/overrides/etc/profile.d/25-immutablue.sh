#!/bin/bash
# This profile script is part of immutalblue
# - https://gitlab.com/immutablue/immutablue

# Set ulimits
if [[ "$(whoami)" != "root" ]]
then
    ulimit -n 65535
fi


# Make sure this is bash, is interactive, and has not already been sourced
if [[ "${BASH_VERSION-}" != "" ]] && [[ "${PS1-}" != "" ]] && [[ "${IMMUTABLUE_BASH_COMPLETION-}" == "" ]]
then

    if [[ -f /usr/bin/fzf-git ]]
    then 
        source /usr/bin/fzf-git
    fi
    
    if [[ -d /home/linuxbrew/.linuxbrew/etc/bash_completion.d/ ]]
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
    type starship 2>/dev/null >/dev/null
    if [[ $? -eq 0 ]]
    then
        eval "$(starship init bash)"
    fi


    IMMUTABLUE_BASH_COMPLETION=1
    export IMMUTABLUE_BASH_COMPLETION
fi

