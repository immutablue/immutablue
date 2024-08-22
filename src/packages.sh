#!/bin/bash 
# We can get smarter with this later I think
# but we are expecting to run it from the Makefile
# so it can be relative to it
PACKAGES_FILE="./packages.yaml"
# Custom Pattern
PACKAGES_CUSTOM_FMT="./packages.custom-*.yaml"
source ./src/common.sh


# Arg 1 is path to packages.yaml
get_yaml_distrobox_length() {
    [ $# -ne 1 ] && echo "$0 <packages.yaml>" && exit 1
    local packages_yaml="$1"
    local key=".distrobox[].name"
    local length=$(yq "${key}" < $packages_yaml | wc -l)
    echo $length
}


# Arg should be index
dbox_install_single() {
    [ ! -f /run/.containerenv ] && echo "This is not a container!" && exit 1
    [ $# -ne 2 ] && echo "$0 <packages.yaml> <index>" && exit 1

    local packages_yaml="$1"
    local index="$2"
    local key=".distrobox[${index}]"
    local name=$(yq "${key}.name" < $packages_yaml)
    local image=$(yq "${key}.image" < $packages_yaml)
    local pkg_inst_cmd=$(yq "${key}.pkg_inst_cmd" < $packages_yaml)
    local pkg_updt_cmd=$(yq "${key}.pkg_updt_cmd" < $packages_yaml)
    local extra_commands=$(yq "${key}.extra_commands" < $packages_yaml)
    local packages=$(yq "${key}.packages[]" < $packages_yaml)
    local npm_packages=$(yq "${key}.npm_packages[]" < $packages_yaml)
    local pip_packages=$(yq "${key}.pip_packages[]" < $packages_yaml)
    local bin_export=$(yq "${key}.bin_export[]" < $packages_yaml)
    local app_export=$(yq "${key}.app_export[]" < $packages_yaml)
    local bin_symlink=$(yq "${key}.bin_symlink[]" < $packages_yaml)


    bash -c "$extra_commands"

    sudo $pkg_updt_cmd 
    sudo $pkg_inst_cmd $(for pkg in $packages; do printf ' %s' $pkg; done)


    type npm 2>/dev/null
    if [ 0 -eq $? ]
    then 
        [ "" != "$npm_packages" ] && sudo npm i -g $(for pkg in $npm_packages; do printf ' %s' $pkg; done)
    fi 
    
    type pip3 2>/dev/null
    if [ 0 -eq $? ]
    then 
        [ "" != "$pip_packages" ] && sudo pip3 install $(for pkg in $pip_packages; do printf ' %s' $pkg; done)
    fi 

    for bin in $bin_export 
    do 
        make_export "${bin}"
    done

    for app in $app_export
    do 
        make_app "${app}"
    done

    for bin in $bin_symlink
    do 
        sudo ln -s /usr/bin/distrobox-host-exec "/usr/local/bin/${bin}"
    done
}


# First argument is path to packages.yaml to use
dbox_install_all_from_yaml() {
    [ $# -ne 1 ] && echo "$0 <packages.yaml>" && exit 1
    local packages_yaml="$1"

    i=0
    local dbox_count=$(get_yaml_distrobox_length $packages_yaml)

    while [ $i -lt $dbox_count ]
    do 
        echo "$i"
        local key=".distrobox[${i}]"
        local name=$(yq "${key}.name" < $packages_yaml)
        local image=$(yq "${key}.image" < $packages_yaml)

        # Check for an empty line (new-line). If no image is specified
        if [ 0 -eq $(container_exists "${name}") ]
        then 
            distrobox create --yes -i "${image}" "${name}"

            # If it failed to create, critically fail
            [ 0 -ne $? ] && echo "distrobox create --yes -i ${image} ${name} failed" && exit 1
        fi

        # Run the single installer in the new dbox
        distrobox enter "${name}" -- bash -c "source ./src/packages.sh && dbox_install_single ${packages_yaml} $i"
        (( i++ ))
    done
}


dbox_install_all() {
    dbox_install_all_from_yaml $PACKAGES_FILE
    for f in $PACKAGES_CUSTOM_FMT; do dbox_install_all_from_yaml $f; done
}

