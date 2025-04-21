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
    type brew &>/dev/null
    if [ $? -ne 0 ]
    then 
        echo -e "brew is not part of your path. Add the following to your .bashrc"
        echo -e '\texport PATH="$HOME/../linuxbrew/.linuxbrew/bin:$PATH"'
    fi
}


# Arg 1 is path to packages.yaml
get_yaml_distrobox_length() {
    [ $# -ne 1 ] && echo "$0 <packages.yaml>" && exit 1
    local packages_yaml="$1"
    local key=".distrobox[].name"
    local length
    length="$(yq "${key}" < "$packages_yaml" | wc -l)"
    echo "$length"
}


# Arg should be index
dbox_install_single() {
    [ ! -f /run/.containerenv ] && echo "This is not a container!" && exit 1
    [ $# -ne 2 ] && echo "$0 <packages.yaml> <index>" && exit 1

    # First things firt, we need to `ln` in yq since we use it...
    type yq &>/dev/null
    if [ 0 -ne $? ]
    then 
        sudo ln -s /usr/bin/distrobox-host-exec /usr/local/bin/yq
    fi

    local packages_yaml="$1"
    local index="$2"
    local key=".distrobox[${index}]"
    
    # Declare and assign separately to avoid masking return values
    local name
    name="$(yq "${key}.name" < "$packages_yaml")"
    
    local image
    image="$(yq "${key}.image" < "$packages_yaml")"
    
    local remove
    remove="$(yq "${key}.rm" < "$packages_yaml")"
    
    local pkg_inst_cmd
    pkg_inst_cmd="$(yq "${key}.pkg_inst_cmd" < "$packages_yaml")"
    
    local pkg_updt_cmd
    pkg_updt_cmd="$(yq "${key}.pkg_updt_cmd" < "$packages_yaml")"
    
    local packages
    packages="$(cat <(yq "${key}.packages[]" < "$packages_yaml") <(yq "${key}.packages_$(uname -m)[]" < "$packages_yaml"))"
    
    local npm_packages
    npm_packages="$(cat <(yq "${key}.npm_packages[]" < "$packages_yaml") <(yq "${key}.npm_packages_$(uname -m)[]" < "$packages_yaml"))"
    
    local pip_packages
    pip_packages="$(cat <(yq "${key}.pip_packages[]" < "$packages_yaml") <(yq "${key}.pip_packages_$(uname -m)[]" < "$packages_yaml"))"
    
    local cargo_packages
    cargo_packages="$(cat <(yq "${key}.cargo_packages[]" < "$packages_yaml") <(yq "${key}.cargo_packages_$(uname -m)[]" < "$packages_yaml"))"
    
    local bin_export
    bin_export="$(cat <(yq "${key}.bin_export[]" < "$packages_yaml") <(yq "${key}.bin_export_$(uname -m)[]" < "$packages_yaml"))"
    
    local app_export
    app_export="$(cat <(yq "${key}.app_export[]" < "$packages_yaml") <(yq "${key}.app_export_$(uname -m)[]" < "$packages_yaml"))"
    
    local bin_symlink
    bin_symlink="$(cat <(yq "${key}.bin_symlink[]" < "$packages_yaml") <(yq "${key}.bin_symlink_$(uname -m)[]" < "$packages_yaml"))"

    if [[ "${remove}" == "true" ]]
    then 
        distrobox rm -f "${name}"
        return 0
    fi

    bash <(yq "${key}.extra_commands" < $packages_yaml)

    sudo "$pkg_updt_cmd"
    sudo "$pkg_inst_cmd" "$(for pkg in $packages; do printf ' %s' "$pkg"; done)"


    type npm &>/dev/null
    if [ 0 -eq $? ]
    then 
        [ "" != "$npm_packages" ] && sudo npm i -g "$(for pkg in $npm_packages; do printf ' %s' "$pkg"; done)"
    fi 
    
    type pip3 &>/dev/null
    if [ 0 -eq $? ]
    then 
        [ "" != "$pip_packages" ] && sudo pip3 install "$(for pkg in $pip_packages; do printf ' %s' "$pkg"; done)"
    fi 

    type cargo &>/dev/null
    if [ 0 -eq $? ]
    then
        [ "" != "$cargo_packages" ] && sudo cargo -t default --locked install "$(for cargo_pkg in $cargo_packages; do printf ' %s' "$cargo_pkg"; done)"
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
    local dbox_count
    dbox_count="$(get_yaml_distrobox_length "$packages_yaml")"

    while [ $i -lt $dbox_count ]
    do 
        echo "$i"
        local key=".distrobox[${i}]"
        
        local name
        name="$(yq "${key}.name" < "$packages_yaml")"
        
        local image
        image="$(yq "${key}.image" < "$packages_yaml")"
        
        local root_mode
        root_mode="$(yq "${key}.root" < "$packages_yaml")"
        
        local add_flag
        add_flag="$(cat <(yq "${key}.additional_flags[]" < "$packages_yaml") <(yq "${key}.additional_flags_$(uname -m)[]" < "$packages_yaml"))"

        # Check for an empty line (new-line). If no image is specified
        if [ 0 -eq "$(container_exists "${name}")" ]
        then 
            # Set this to an empty space if its nothing
            # so distrobox-create doesn't hang wanting more params.
            if [ "$add_flag" == "" ]
            then 
                add_flag=" "
            fi 

            if [ "true" == "$root_mode" ]
            then
                distrobox create --yes --root --additional-flags "$add_flag" -i "${image}" "${name}"
            else 
                distrobox create --yes --additional-flags "$add_flag" -i "${image}" "${name}"
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
    if [ -d "$HOME/bin/export" ]; then rm "${HOME}"/bin/export/*; fi
    dbox_install_all_from_yaml $PACKAGES_FILE
    for f in $PACKAGES_CUSTOM_FMT; do if [ "$f" != "$PACKAGES_CUSTOM_FMT" ]; then dbox_install_all_from_yaml $f; fi; done
}


flatpak_config() {
        local flatpaks_yaml="$1"
        
	# Remove flathub if its configured
	sudo flatpak remote-delete flathub --force

	# Enabling flathub (unfiltered) for --user
	flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

        # Add custom Flatpak Repositories
        repos=$(cat <(yq '.immutablue.flatpak_repos[].name' < $flatpaks_yaml) <(yq ".immutablue.flatpak_repos_$(uname -m)[].name" < $flatpaks_yaml))
        if [ "" != "$repos" ]
        then 
            for repo in $repos; do  flatpak remote-add --user --if-not-exists "$repo" "$(cat <(yq ".immutablue.flatpak_repos[] | select(.name == \"$repo\").url" < "$flatpaks_yaml") <(yq ".immutablue.flatpak_repos_$(uname -m)[] | select(.name == \"$repo\").url" < "$flatpaks_yaml"))" || true; done
        fi

	# Replace Fedora flatpaks with flathub ones
	flatpak install --user --noninteractive org.gnome.Platform//46
	flatpak install --user --noninteractive --reinstall flathub "$(flatpak list --app-runtime=org.fedoraproject.Platform --columns=application | tail -n +1)"

	# Remove system flatpaks (pre-installed)
	#flatpak remove --system --noninteractive --all

	# Remove Fedora flatpak repo
	sudo flatpak remote-delete fedora --force
}


# Arg is yaml file
flatpak_install_all_from_yaml() {
    [ $# -ne 1 ] && echo "echo flatpak_install_all_from_yaml <packages.yaml>" && exit 1
    local flatpaks_yaml="$1"

    flatpaks_add=$(cat <(yq '.immutablue.flatpaks[]' < $flatpaks_yaml) <(yq ".immutablue.flatpaks_$(uname -m)[]" < $flatpaks_yaml))
    flatpaks_rm=$(cat <(yq '.immutablue.flatpaks_rm[]' < $flatpaks_yaml) <(yq ".immutablue.flatpaks_rm_$(uname -m)[]" < $flatpaks_yaml))
    
    if [ "" != "$flatpaks_add" ]
    then 
        for flatpak in $flatpaks_add; do flatpak --noninteractive --user install "$flatpak"; done
    fi

    if [ "" != "$flatpaks_rm" ] 
    then 
        for flatpak in $flatpaks_rm; do flatpak --noninteractive --user uninstall "$flatpak"; done
    fi


    
}


flatpak_install_all() {
    if [ ! -f /opt/immutablue/did_initial_flatpak_install ]
    then 
        echo "Doing initial flatpak config"
        flatpak_config $PACKAGES_FILE
        for f in $PACKAGES_CUSTOM_FMT; do flatpak_config $f; done
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

    for app in $apps; do printf "app/%s/%s/stable\n" "$app" "$(uname -m)" >> "$FLATPAK_REFS_FILE"; done
    for runtime in $runtimes; do printf "runtime/%s\n" $runtime >> $FLATPAK_REFS_FILE; done
}

run_all_post_upgrade_scripts() {
    bash -c 'cd /usr && find ./immutablue-build*/post_install.sh -exec {} \;' || true
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
        brew install "$(for pkg in $brew_add; do printf '%s ' "$pkg"; done)"
    fi

    if [ "" != "$brew_rm" ] 
    then 
        brew uninstall "$(for pkg in $brew_rm; do printf '%s ' "$pkg"; done)"
    fi
}


brew_install() {
    CI=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
}


brew_install_all_packages() {
    # Brew is currently only supported on x86_64 -- but we should make the directory
    # for other architectures in case of confusion, or dependencies of other tools
    if [ "$(uname -m)" == "x86_64" ]
    then 
        brew_install 
        brew_install_all_from_yaml $PACKAGES_FILE
        for f in $PACKAGES_CUSTOM_FMT; do brew_install_all_from_yaml $f; done
    else 
        sudo mkdir -p /var/home/linuxbrew/.linuxbrew/bin/
        sudo bash -c "chown -R $USER:$USER /var/home/linuxbrew/"
    fi
}


services_unmask_disable_enable_mask_yaml() {
    local svc_yaml="$1"
    local enable
    enable="$(cat <(yq '.immutablue.services_enable_user[]' < "${svc_yaml}") <(yq ".immutablue.services_enable_user_$(uname -m)" < "${svc_yaml}"))"
    
    local disable
    disable="$(cat <(yq '.immutablue.services_disable_user[]' < "${svc_yaml}") <(yq ".immutablue.services_disable_user_$(uname -m)" < "${svc_yaml}"))"
    
    local mask
    mask="$(cat <(yq '.immutablue.services_mask_user[]' < "${svc_yaml}") <(yq ".immutablue.services_mask_user_$(uname -m)" < "${svc_yaml}"))"
    
    local unmask
    unmask="$(cat <(yq '.immutablue.services_unmask_user[]' < "${svc_yaml}") <(yq ".immutablue.services_unmask_user_$(uname -m)" < "${svc_yaml}"))"

    systemctl --user daemon-reload
    for s in $unmask; do systemctl --user unmask --now "$s"; done
    for s in $disable; do systemctl --user disable --now "$s"; done
    for s in $enable; do systemctl --user enable --now "$s"; done
    for s in $mask; do systemctl --user mask --now "$s"; done
}


services_unmask_disable_enable_mask_all() {
    services_unmask_disable_enable_mask_yaml "$PACKAGES_FILE"
    for f in $PACKAGES_CUSTOM_FMT; do services_unmask_disable_enable_mask_yaml "$f"; done
}


