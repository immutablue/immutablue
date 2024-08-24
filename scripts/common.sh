#!/bin/bash 


make_export () {
    [ "$#" != 1 ] && echo "$0 <bin>" && exit 1
    mkdir -p ~/bin/export
    [ -f "~/bin/export/$1" ] && rm "~/bin/export/$1" 
    distrobox-export --bin $(which "$1") --export-path ~/bin/export/
}


make_app () {
    [ "$#" != 1 ] && echo "$0 <app>" && exit 1
    distrobox-export --app "$1"
}


get_containers () {
    local container_listing=$(distrobox list --no-color)

    while read -r line
    do
        [ "$line" != "NAME" ] && awk '{printf "%s\n", $3}'
    done <<< $container_listing
}


container_exists () {
    local to_check="$1"
    local containers=$(get_containers)
    local exists=0

    while read -r line
    do 
        [ "$to_check" == "$line" ] && exists=1 
    done <<< $containers

    echo $exists
}

