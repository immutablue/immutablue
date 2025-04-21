#!/bin/bash 


make_export () {
    [ "$#" != 1 ] && echo "$0 <bin>" && exit 1
    local export_dir="$HOME/bin/export"
    local bin_to_export="$1"
    mkdir -p "${export_dir}"
    if [ -f "${export_dir}/${bin_to_export}" ]; then rm "${export_dir}/${bin_to_export}"; fi
    distrobox-export --bin "$(which "${bin_to_export}")" --export-path "${export_dir}/"
}


make_app () {
    [ "$#" != 1 ] && echo "$0 <app>" && exit 1
    distrobox-export --app "$1"
}


get_containers () {
    local container_listing
    container_listing="$(distrobox list --no-color)"

    while read -r line
    do
        [ "$line" != "NAME" ] && awk '{printf "%s\n", $3}'
    done <<< $container_listing
}


container_exists () {
    local to_check="$1"
    local containers
    containers="$(get_containers)"
    local exists=0

    while read -r line
    do 
        [ "$to_check" == "$line" ] && exists=1 
    done <<< $containers

    echo $exists
}

