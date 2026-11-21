#!/bin/bash 


# Export a binary from the current distrobox to ~/bin/export.
#
# The binary is a name looked up on PATH, or an absolute path. A binary
# that is not there is skipped with a warning (return 1): distrobox-export
# must never get an empty --bin, because its argument parser only shifts
# past a non-empty value and spins forever on '--bin ""'.
#
# Returns (not exits): this runs once per bin_export entry, sourced, and a
# missing binary must not stop the rest of the distrobox setup.
make_export () {
    if [[ $# -ne 1 ]] || [[ -z "${1}" ]]
    then
        echo 'make_export <bin>' >&2
        return 1
    fi

    local export_dir="${HOME}/bin/export"
    local bin_to_export="${1}"
    local bin_path

    # 'command -v' prints a path for files only; builtins, functions and
    # aliases come back as a bare name, which distrobox-export cannot use
    bin_path="$(command -v -- "${bin_to_export}" 2> /dev/null || true)"
    if [[ "${bin_path}" != /* ]] || [[ ! -x "${bin_path}" ]]
    then
        echo "make_export: '${bin_to_export}' is not installed in this container, not exporting it" >&2
        return 1
    fi

    mkdir -p "${export_dir}"
    rm -f "${export_dir}/$(basename "${bin_path}")"
    distrobox-export --bin "${bin_path}" --export-path "${export_dir}/"
}


# Export a desktop application from the current distrobox. An empty name
# would hang distrobox-export the same way an empty --bin does.
make_app () {
    if [[ $# -ne 1 ]] || [[ -z "${1}" ]]
    then
        echo 'make_app <app>' >&2
        return 1
    fi

    distrobox-export --app "${1}"
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

