#!/bin/bash 
# We can get smarter with this later I think
# but we are expecting to run it from the Makefile
# so it can be relative to it
PACKAGES_FILE="./packages.yaml"


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


get_yaml_distrobox_length() {
    local key=".distrobox[].name"
    local length=$(yq "${key}" < $PACKAGES_FILE | wc -l)
    echo $length
}


# Arg should be index
dbox_install_single() {
    [ ! -f /run/.containerenv ] && echo "This is not a container!" && exit 1
    [ $# -ne 1 ] && echo "$0 <index>" && exit 1

    local index="$1"
    local key=".distrobox[${index}]"
    local name=$(yq "${key}.name" < $PACKAGES_FILE)
    local image=$(yq "${key}.image" < $PACKAGES_FILE)
    local pkg_inst_cmd=$(yq "${key}.pkg_inst_cmd" < $PACKAGES_FILE)
    local pkg_updt_cmd=$(yq "${key}.pkg_updt_cmd" < $PACKAGES_FILE)
    local extra_commands=$(yq "${key}.extra_commands" < $PACKAGES_FILE)
    local packages=$(yq "${key}.packages[]" < $PACKAGES_FILE)
    local npm_packages=$(yq "${key}.npm_packages[]" < $PACKAGES_FILE)
    local pip_packages=$(yq "${key}.pip_packages[]" < $PACKAGES_FILE)
    local bin_export=$(yq "${key}.bin_export[]" < $PACKAGES_FILE)
    local app_export=$(yq "${key}.app_export[]" < $PACKAGES_FILE)
    local bin_symlink=$(yq "${key}.bin_symlink[]" < $PACKAGES_FILE)


    bash -c "$extra_commands"

    sudo $pkg_updt_cmd 
    sudo $pkg_inst_cmd $(for pkg in $packages; do printf ' %s' $pkg; done)


    type npm 2>/dev/null
    if [ 0 -eq $? ]
    then 
        sudo npm i -g $(for pkg in $npm_packages; do printf ' %s' $pkg; done)
    fi 
    
    type pip3 2>/dev/null
    if [ 0 -eq $? ]
    then 
        sudo pip3 install $(for pkg in $pip_packages; do printf ' %s' $pkg; done)
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


dbox_install_all() {
    i=0
    local dbox_count=$(get_yaml_distrobox_length)

    while [ $i -lt $dbox_count ]
    do 
        echo "$i"
        local key=".distrobox[${i}]"
        local name=$(yq "${key}.name" < $PACKAGES_FILE)
        local image=$(yq "${key}.image" < $PACKAGES_FILE)
        distrobox create --yes -i "${image}" "${name}"
        [ $? -ne 0 ] && echo "distrobox create --yes -i ${image} ${name} failed" && exit 1
        distrobox enter "${name}" -- bash -c "source ./packages.sh && dbox_install_single $i"
        (( i++ ))
    done
}


