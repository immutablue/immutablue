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


post_install_notes() {
    type brew 2>/dev/null >/dev/null
    if [ $? -ne 0 ]
    then 
        echo -e "brew is not part of your path. Add the following to your .bashrc"
        echo -e '\texport PATH="$HOME/../linuxbrew/.linuxbrew/bin:$PATH"'
    fi
}


check_plymouth_watermark() {
  echo "$(sha256sum /usr/share/pixmaps/fedora-logo.png | gawk '{ print $1 }') /usr/share/plymouth/themes/spinner/watermark.png" | sha256sum --check
}

update_initramfs_if_bad_watermark() {
    if [[ $(check_plymouth_watermark | grep "FAILED") && \
        $(rpm-ostree status -v | grep -i Initramfs | awk '{printf "%s\n", $2}') -eq "regenerate" ]]
    then
        bash -c "sudo rpm-ostree initramfs --enable"
    fi
}

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

    # First things firt, we need to `ln` in yq since we use it...
    type yq 2>/dev/null 
    if [ 0 -ne $? ]
    then 
        sudo ln -s /usr/bin/distrobox-host-exec /usr/local/bin/yq
    fi

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
        local root_mode=$(yq "${key}.root" < $packages_yaml)
        local add_flag=$(yq "${key}.additional_flags[]" < $packages_yaml)

        # Check for an empty line (new-line). If no image is specified
        if [ 0 -eq $(container_exists "${name}") ]
        then 
            if [ "$add_flag" != "" ]
            then 
                add_flag="--additional-flags \"$add_flag\""
            fi 

            if [ "true" == "$root_mode" ]
            then
                distrobox create --yes --root $add_flag -i "${image}" "${name}"
            else 
                distrobox create --yes -i $add_flag "${image}" "${name}"
            fi

            # If it failed to create, critically fail
            [ 0 -ne $? ] && echo "distrobox create --yes -i ${image} ${name} failed" && exit 1
        fi

        if [ "true" == "$root_mode" ]
        then
            distrobox enter --root "${name}" -- bash -c "source ./scripts/packages.sh && dbox_install_single ${packages_yaml} $i" 
        else
            distrobox enter "${name}" -- bash -c "source ./scripts/packages.sh && dbox_install_single ${packages_yaml} $i" 
        fi

        (( i++ ))
    done

}


dbox_install_all() {
    dbox_install_all_from_yaml $PACKAGES_FILE
    for f in $PACKAGES_CUSTOM_FMT; do if [ "$f" != "$PACKAGES_CUSTOM_FMT" ]; then dbox_install_all_from_yaml $f; fi; done
}


flatpak_config() {
	# Remove flathub if its configured
	sudo flatpak remote-delete flathub --force

	# Enabling flathub (unfiltered) for --user
	flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

	# Replace Fedora flatpaks with flathub ones
	flatpak install --user --noninteractive org.gnome.Platform//46
	flatpak install --user --noninteractive --reinstall flathub $(flatpak list --app-runtime=org.fedoraproject.Platform --columns=application | tail -n +1 )

	# Remove system flatpaks (pre-installed)
	#flatpak remove --system --noninteractive --all

	# Remove Fedora flatpak repo
	sudo flatpak remote-delete fedora --force
}


# Arg is yaml file
flatpak_install_all_from_yaml() {
    [ $# -ne 1 ] && echo "echo flatpak_install_all_from_yaml <packages.yaml>" && exit 1
    local flatpaks_yaml="$1"

    flatpaks_add=$(yq '.immutablue.flatpaks[]' < $flatpaks_yaml)
    flatpaks_rm=$(yq '.immutablue.flatpaks_rm[]' < $flatpaks_yaml)
    
    if [ "" != "$flatpaks_add" ]
    then 
        flatpak --noninteractive --user install $(for flatpak in $flatpaks_add; do printf '%s ' $flatpak; done)
    fi

    if [ "" != "$flatpaks_rm" ] 
    then 
        flatpak --noninteractive --user uninstall $(for flatpak in $flatpaks_rm; do printf '%s ' $flatpak; done)
    fi


    
}


flatpak_install_all() {
    if [ ! -f /opt/immutablue/did_initial_flatpak_install ]
    then 
        echo "Doing initial flatpak config"
        flatpak_config
        sudo mkdir -p /opt/immutablue
        sudo touch /opt/immutablue/did_initial_flatpak_install
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

run_all_post_upgrade_scripts() {
    bash -c 'cd /usr && ./immutablue-build*/post_install.sh'
}



brew_install_all_from_yaml() {
    [ $# -ne 1 ] && echo "echo brew_install_all_from_yaml <packages.yaml>" && exit 1
    local brew_yaml="$1"

    brew_add=$(yq '.brew.install[]' < $brew_yaml)
    brew_rm=$(yq '.brew.uninstall[]' < $brew_yaml)
    
    # Assume `brew` is not in $PATH yet
    export PATH="$HOME/../linuxbrew/.linuxbrew/bin:$PATH"

    if [ "" != "$brew_add" ]
    then 
        brew install $(for pkg in $brew_add; do printf '%s ' $pkg; done)
    fi

    if [ "" != "$brew_rm" ] 
    then 
        brew uninstall $(for pkg in $brew_rm; do printf '%s ' $pkg; done)
    fi
}


brew_install() {
    CI=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
}


brew_install_all_packages() {
    brew_install 
    brew_install_all_from_yaml $PACKAGES_FILE
    for f in $PACKAGES_CUSTOM_FMT; do brew_install_all_from_yaml $f; done
}


