#!/bin/bash 
# We can get smarter with this later I think
# but we are expecting to run it from the Makefile
# so it can be relative to it
PACKAGES_FILE="./packages.yaml"
# Custom Pattern
PACKAGES_CUSTOM_FMT="./packages.custom-*.yaml"
FLATPAK_REFS_FILE="./flatpak_refs/flatpaks"

# Source the common stuff
source ./scripts/common.sh


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

        # Submit and run the single installer in the new dbox as a background job
        distrobox enter "${name}" -- bash -c "source ./scripts/packages.sh && dbox_install_single ${packages_yaml} $i" &
        (( i++ ))
    done

    # Wait for all background jobs of distrobox-enter to finish
    wait
}


dbox_install_all() {
    dbox_install_all_from_yaml $PACKAGES_FILE
    for f in $PACKAGES_CUSTOM_FMT; do dbox_install_all_from_yaml $f; done
}


flatpak_config() {
	# Remove flathub if its configured
	flatpak remote-delete flathub --force

	# Enabling flathub (unfiltered) for --user
	flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

	# Replace Fedora flatpaks with flathub ones
	flatpak install --user --noninteractive org.gnome.Platform//46
	flatpak install --user --noninteractive --reinstall flathub $(flatpak list --app-runtime=org.fedoraproject.Platform --columns=application | tail -n +1 )

	# Remove system flatpaks (pre-installed)
	#flatpak remove --system --noninteractive --all

	# Remove Fedora flatpak repo
	flatpak remote-delete fedora --force
}


# Arg is yaml file
flatpak_install_all_from_yaml() {
    [ $# -ne 1 ] && echo "echo flatpak_install_all_from_yaml <packages.yaml>" && exit 1
    local flatpaks_yaml="$1"

    flatpaks_add=$(yq '.immutablue.flatpaks[]' < $flatpaks_yaml)
    flatpaks_rm=$(yq '.immutablue.flatpaks_rm[]' < $flatpaks_yaml)

    for flatpak in $flatpaks_add; do flatpak --noninteractive --user install $flatpak; done
    for flatpak in $flatpaks_rm; do flatpak --noninteractive --user uninstall $flatpak; done
    
}


flatpak_install_all() {
    if [ ! -f /etc/immutablue/did_initial_flatpak_install ]
    then 
        echo "Doing initial flatpak config"
        flatpak_config
        sudo mkdir -p /etc/immutablue
        sudo touch /etc/immutablue/did_initial_flatpak_install
    fi

    flatpak_install_all_from_yaml $PACKAGES_FILE 
    for f in $PACKAGES_CUSTOM_FMT; do flatpak_install_all_from_yaml $f; done
}


# Used to make flatpak_refs/flatpak file for iso building
flatpak_make_refs() {
    [ -f $FLATPAK_REFS_FILE ] && rm $FLATPAK_REFS_FILE

    apps=$(yq '.immutablue.flatpaks[]' < $PACKAGES_FILE)
    runtimes=$(yq '.immutablue.flatpaks_runtime[]' < $PACKAGES_FILE)

    for app in $apps; do printf "app/%s/%s/stable\n" $app $(uname -m) >> $FLATPAK_REFS_FILE; done
    for runtime in $runtimes; do printf "runtime/%s\n" $runtime >> $FLATPAK_REFS_FILE; done
}
