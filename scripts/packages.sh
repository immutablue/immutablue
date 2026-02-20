#!/bin/bash
# We can get smarter with this later I think
# but we are expecting to run it from the Makefile
# so it can be relative to it
if [[ -f ./packages.yaml ]]
then
    PACKAGES_FILE="./packages.yaml"

    # Custom Pattern
    PACKAGES_CUSTOM_FMT="./packages.custom-*.yaml"
    FLATPAK_REFS_FILE="./flatpak_refs/flatpaks"
else
    PACKAGES_FILE="/usr/immutablue/packages.yaml"

    # Custom Pattern
    PACKAGES_CUSTOM_FMT="/usr/immutablue/packages.custom-*.yaml"
    FLATPAK_REFS_FILE="/usr/flatpak_refs/flatpaks"
fi

# Source the common stuff
source ./scripts/common.sh

# Source the header library for utility functions (immutablue_get_image_version, etc.)
if [[ -f /usr/libexec/immutablue/immutablue-header.sh ]]; then
    source /usr/libexec/immutablue/immutablue-header.sh
elif [[ -f ./artifacts/overrides/usr/libexec/immutablue/immutablue-header.sh ]]; then
    source ./artifacts/overrides/usr/libexec/immutablue/immutablue-header.sh
fi


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
    local key=".immutablue.distrobox.all[].name"
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
    local key=".immutablue.distrobox.all[${index}]"

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

    bash <(yq "${key}.extra_commands" < $packages_yaml) || true

    sudo $pkg_updt_cmd || true
    sudo $pkg_inst_cmd $(for pkg in $packages; do printf ' %s' "$pkg"; done) || true


    type npm &>/dev/null
    if [ 0 -eq $? ]
    then 
        [ "" != "$npm_packages" ] && sudo npm i -g $(for pkg in $npm_packages; do printf ' %s' "$pkg"; done) || true
    fi 
    
    type pip3 &>/dev/null
    if [ 0 -eq $? ]
    then 
        [ "" != "$pip_packages" ] && sudo pip3 install $(for pkg in $pip_packages; do printf ' %s' "$pkg"; done) || true
    fi 

    type cargo &>/dev/null
    if [ 0 -eq $? ]
    then
        [ "" != "$cargo_packages" ] && sudo cargo install $(for cargo_pkg in $cargo_packages; do printf ' %s' "$cargo_pkg"; done) || true
    fi

    for bin in $bin_export 
    do 
        make_export "${bin}" || true
    done

    for app in $app_export
    do 
        make_app "${app}" || true
    done

    for bin in $bin_symlink
    do 
        sudo ln -s /usr/bin/distrobox-host-exec "/usr/local/bin/${bin}" || true
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
        local key=".immutablue.distrobox.all[${i}]"

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
            distrobox enter --root "${name}" -- bash -x -c "source ./scripts/packages.sh && dbox_install_single ${packages_yaml} $i" || true
        else
            distrobox enter "${name}" -- bash -x -c "source ./scripts/packages.sh && dbox_install_single ${packages_yaml} $i" || true
        fi

        (( i++ ))
    done

}


dbox_install_all() {
    if [ -d "$HOME/bin/export" ]; then rm "${HOME}"/bin/export/*; fi
    dbox_install_all_from_yaml $PACKAGES_FILE
    for f in $PACKAGES_CUSTOM_FMT; do
        if [[ -f "$f" ]]; then
            dbox_install_all_from_yaml "$f"
        fi
    done
}


flatpak_config() {
    local flatpaks_yaml="$1"

    # Verify the YAML file exists
    if [[ ! -f "$flatpaks_yaml" ]]; then
        echo "Warning: flatpak config file not found: $flatpaks_yaml"
        return 0
    fi

    # Get the current Fedora version for version-specific queries
    local version
    version=$(immutablue_get_image_version 2>/dev/null || echo "")
    local arch
    arch=$(uname -m)

    # Remove flathub if its configured on system (suppress error if not present)
    if flatpak remotes --system 2>/dev/null | grep -q "^flathub"; then
        sudo flatpak remote-delete flathub --force || true
    fi

    # Enabling flathub (unfiltered) for --user
    flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo || true

    # Add custom Flatpak Repositories
    # Query both .all[] and .${version}[] entries, plus arch-specific variants
    local repos
    repos=$(cat \
        <(yq '.immutablue.flatpak_repos.all[].name' < "$flatpaks_yaml" 2>/dev/null) \
        <(yq ".immutablue.flatpak_repos.${version}[].name" < "$flatpaks_yaml" 2>/dev/null) \
        <(yq ".immutablue.flatpak_repos_${arch}.all[].name" < "$flatpaks_yaml" 2>/dev/null) \
        <(yq ".immutablue.flatpak_repos_${arch}.${version}[].name" < "$flatpaks_yaml" 2>/dev/null) \
        | grep -v '^null$' | grep -v '^$' || true)

    if [[ -n "$repos" ]]; then
        for repo in $repos; do
            local repo_url
            repo_url=$(cat \
                <(yq ".immutablue.flatpak_repos.all[] | select(.name == \"$repo\").url" < "$flatpaks_yaml" 2>/dev/null) \
                <(yq ".immutablue.flatpak_repos.${version}[] | select(.name == \"$repo\").url" < "$flatpaks_yaml" 2>/dev/null) \
                <(yq ".immutablue.flatpak_repos_${arch}.all[] | select(.name == \"$repo\").url" < "$flatpaks_yaml" 2>/dev/null) \
                <(yq ".immutablue.flatpak_repos_${arch}.${version}[] | select(.name == \"$repo\").url" < "$flatpaks_yaml" 2>/dev/null) \
                | grep -v '^null$' | grep -v '^$' | head -1 || true)
            if [[ -n "$repo_url" ]]; then
                flatpak remote-add --user --if-not-exists "$repo" "$repo_url" || true
            fi
        done
    fi

    # Install GNOME Platform from packages.yaml (flatpaks_runtime section)
    # Query both .all[] and .${version}[] entries
    local gnome_platform
    gnome_platform=$(cat \
        <(yq '.immutablue.flatpaks_runtime.all[]' < "$flatpaks_yaml" 2>/dev/null) \
        <(yq ".immutablue.flatpaks_runtime.${version}[]" < "$flatpaks_yaml" 2>/dev/null) \
        | grep -v '^null$' | grep -i "org.gnome.Platform" | head -1 || true)
    if [[ -n "$gnome_platform" ]]; then
        flatpak install --user --noninteractive "$gnome_platform" || true
    fi

    # Replace Fedora flatpaks with flathub ones (if any exist)
    local fedora_apps
    fedora_apps=$(flatpak list --app-runtime=org.fedoraproject.Platform --columns=application 2>/dev/null | grep -v '^$' || true)
    if [[ -n "$fedora_apps" ]]; then
        for app in $fedora_apps; do
            flatpak install --user --noninteractive --reinstall flathub "$app" || true
        done
    fi

    # Remove Fedora flatpak repo (suppress error if not present)
    if flatpak remotes --system 2>/dev/null | grep -q "^fedora"; then
        sudo flatpak remote-delete fedora --force || true
    fi
}


# Arg is yaml file
flatpak_install_all_from_yaml() {
    [ $# -ne 1 ] && echo "flatpak_install_all_from_yaml <packages.yaml>" && exit 1
    local flatpaks_yaml="$1"

    # Verify the YAML file exists
    if [[ ! -f "$flatpaks_yaml" ]]; then
        echo "Warning: flatpak YAML file not found: $flatpaks_yaml"
        return 0
    fi

    # Get the current Fedora version for version-specific queries
    local version
    version=$(immutablue_get_image_version 2>/dev/null || echo "")
    local arch
    arch=$(uname -m)

    # Get flatpaks to install from all sections (both .all[] and .${version}[])
    local flatpaks_add
    flatpaks_add=$(cat \
        <(yq '.immutablue.flatpaks.all[]' < "$flatpaks_yaml" 2>/dev/null) \
        <(yq ".immutablue.flatpaks.${version}[]" < "$flatpaks_yaml" 2>/dev/null) \
        <(yq ".immutablue.flatpaks_${arch}.all[]" < "$flatpaks_yaml" 2>/dev/null) \
        <(yq ".immutablue.flatpaks_${arch}.${version}[]" < "$flatpaks_yaml" 2>/dev/null) \
        | grep -v '^null$' | grep -v '^$' || true)

    # Get flatpaks to remove from all sections (both .all[] and .${version}[])
    local flatpaks_rm
    flatpaks_rm=$(cat \
        <(yq '.immutablue.flatpaks_rm.all[]' < "$flatpaks_yaml" 2>/dev/null) \
        <(yq ".immutablue.flatpaks_rm.${version}[]" < "$flatpaks_yaml" 2>/dev/null) \
        <(yq ".immutablue.flatpaks_rm_${arch}.all[]" < "$flatpaks_yaml" 2>/dev/null) \
        <(yq ".immutablue.flatpaks_rm_${arch}.${version}[]" < "$flatpaks_yaml" 2>/dev/null) \
        | grep -v '^null$' | grep -v '^$' || true)

    if [[ -n "$flatpaks_add" ]]; then
        for flatpak in $flatpaks_add; do
            flatpak --noninteractive --user install "$flatpak" || true
        done
    fi

    if [[ -n "$flatpaks_rm" ]]; then
        for flatpak in $flatpaks_rm; do
            flatpak --noninteractive --user uninstall "$flatpak" || true
        done
    fi
}


flatpak_install_all() {
    if [ ! -f /opt/immutablue/did_initial_flatpak_install ]
    then
        echo "Doing initial flatpak config"
        flatpak_config $PACKAGES_FILE
        for f in $PACKAGES_CUSTOM_FMT; do
            if [[ -f "$f" ]]; then
                flatpak_config "$f"
            fi
        done
        sudo mkdir -p /opt/immutablue
        sudo touch /opt/immutablue/did_initial_flatpak_install
    fi

    flatpak_install_all_from_yaml $PACKAGES_FILE
    for f in $PACKAGES_CUSTOM_FMT; do
        if [[ -f "$f" ]]; then
            flatpak_install_all_from_yaml "$f"
        fi
    done
}


# Used to make flatpak_refs/flatpak file for iso building
flatpak_make_refs() {
    [ -f "$FLATPAK_REFS_FILE" ] && rm "$FLATPAK_REFS_FILE"

    # Get the current Fedora version for version-specific queries
    local version
    version=$(immutablue_get_image_version 2>/dev/null || echo "")
    local arch
    arch=$(uname -m)

    # Query both .all[] and .${version}[] entries for flatpaks
    local apps
    apps=$(cat \
        <(yq '.immutablue.flatpaks.all[]' < "$PACKAGES_FILE" 2>/dev/null) \
        <(yq ".immutablue.flatpaks.${version}[]" < "$PACKAGES_FILE" 2>/dev/null) \
        <(yq ".immutablue.flatpaks_${arch}.all[]" < "$PACKAGES_FILE" 2>/dev/null) \
        <(yq ".immutablue.flatpaks_${arch}.${version}[]" < "$PACKAGES_FILE" 2>/dev/null) \
        | grep -v '^null$' | grep -v '^$' || true)

    # Query both .all[] and .${version}[] entries for runtimes
    local runtimes
    runtimes=$(cat \
        <(yq '.immutablue.flatpaks_runtime.all[]' < "$PACKAGES_FILE" 2>/dev/null) \
        <(yq ".immutablue.flatpaks_runtime.${version}[]" < "$PACKAGES_FILE" 2>/dev/null) \
        | grep -v '^null$' | grep -v '^$' || true)

    for app in $apps; do printf "app/%s/%s/stable\n" "$app" "${arch}" >> "$FLATPAK_REFS_FILE"; done
    for runtime in $runtimes; do printf "runtime/%s\n" "$runtime" >> "$FLATPAK_REFS_FILE"; done
}

run_all_post_upgrade_scripts() {
    bash -c 'cd /usr && find ./immutablue-build*/post_install.sh -exec {} \;' || true
}



brew_install_all_from_yaml() {
    [ $# -ne 1 ] && echo "echo brew_install_all_from_yaml <packages.yaml>" && exit 1
    local brew_yaml="$1"

    # Source the immutablue header for utility functions
    if [[ -f "/usr/libexec/immutablue/immutablue-header.sh" ]]; then
        source "/usr/libexec/immutablue/immutablue-header.sh"
    fi

    # Get version for version-specific queries (e.g., 42, 43)
    local version
    version=$(immutablue_get_image_version 2>/dev/null || echo "")

    # Start with base packages - query both .all[] and .${version}[]
    # Using correct path: .immutablue.brew.install.all[] and .immutablue.brew.install.${version}[]
    local brew_add
    brew_add=$(cat \
        <(yq '.immutablue.brew.install.all[]' < "$brew_yaml" 2>/dev/null) \
        <(yq ".immutablue.brew.install.${version}[]" < "$brew_yaml" 2>/dev/null) \
        | grep -v '^null$' | grep -v '^$' || true)

    local brew_rm
    brew_rm=$(cat \
        <(yq '.immutablue.brew.uninstall.all[]' < "$brew_yaml" 2>/dev/null) \
        <(yq ".immutablue.brew.uninstall.${version}[]" < "$brew_yaml" 2>/dev/null) \
        | grep -v '^null$' | grep -v '^$' || true)

    # Add variant-specific packages for all detected variants
    if [[ -f "/usr/immutablue/build_options" ]]
    then
        # Use the existing function from immutablue-header.sh if available
        if type get_immutablue_build_options >/dev/null 2>&1; then
            while read -r option
            do
                # Try to get variant-specific packages for this option
                # Query both .all[] and .${version}[] for the variant
                local variant_add
                variant_add=$(cat \
                    <(yq ".immutablue.brew.install_${option}.all[]" < "$brew_yaml" 2>/dev/null) \
                    <(yq ".immutablue.brew.install_${option}.${version}[]" < "$brew_yaml" 2>/dev/null) \
                    | grep -v '^null$' | grep -v '^$' || true)

                local variant_rm
                variant_rm=$(cat \
                    <(yq ".immutablue.brew.uninstall_${option}.all[]" < "$brew_yaml" 2>/dev/null) \
                    <(yq ".immutablue.brew.uninstall_${option}.${version}[]" < "$brew_yaml" 2>/dev/null) \
                    | grep -v '^null$' | grep -v '^$' || true)

                # Add to the main lists (handles multiple variants automatically)
                [[ -n "$variant_add" ]] && brew_add="$brew_add $variant_add"
                [[ -n "$variant_rm" ]] && brew_rm="$brew_rm $variant_rm"
            done < <(get_immutablue_build_options)
        else
            # Fallback to manual parsing if header not available
            local build_options
            build_options="$(cat /usr/immutablue/build_options)"
            IFS=',' read -ra option_array <<< "${build_options}"

            for option in "${option_array[@]}"
            do
                # Try to get variant-specific packages for this option
                # Query both .all[] and .${version}[] for the variant
                local variant_add
                variant_add=$(cat \
                    <(yq ".immutablue.brew.install_${option}.all[]" < "$brew_yaml" 2>/dev/null) \
                    <(yq ".immutablue.brew.install_${option}.${version}[]" < "$brew_yaml" 2>/dev/null) \
                    | grep -v '^null$' | grep -v '^$' || true)

                local variant_rm
                variant_rm=$(cat \
                    <(yq ".immutablue.brew.uninstall_${option}.all[]" < "$brew_yaml" 2>/dev/null) \
                    <(yq ".immutablue.brew.uninstall_${option}.${version}[]" < "$brew_yaml" 2>/dev/null) \
                    | grep -v '^null$' | grep -v '^$' || true)

                # Add to the main lists (handles multiple variants automatically)
                [[ -n "$variant_add" ]] && brew_add="$brew_add $variant_add"
                [[ -n "$variant_rm" ]] && brew_rm="$brew_rm $variant_rm"
            done
        fi
    fi

    # Assume `brew` is not in $PATH yet
    local brew_cmd
    brew_cmd="/var/home/linuxbrew/.linuxbrew/bin/brew"


    if [ "" != "$brew_add" ]
    then
        if [[ -z ${HOME} ]]
        then 
            su -c "${brew_cmd} install $(for pkg in $brew_add; do printf '%s ' "$pkg"; done) || true" $(id -n -u 1000)
        else 
            ${brew_cmd} install $(for pkg in $brew_add; do printf '%s ' "$pkg"; done) || true
        fi
    fi

    if [ "" != "$brew_rm" ]
    then
        if [[ -z ${HOME} ]]
        then 
            su -c "${brew_cmd} uninstall $(for pkg in $brew_rm; do printf '%s ' "$pkg"; done) || true" $(id -n -u 1000)
        else 
            ${brew_cmd} uninstall $(for pkg in $brew_rm; do printf '%s ' "$pkg"; done) || true
        fi
    fi

}


brew_install_all_packages() {
    # Brew is set up by linuxbrew-setup.service on first boot
    # This function just installs packages from YAML configs
    brew_install_all_from_yaml $PACKAGES_FILE
    for f in $PACKAGES_CUSTOM_FMT; do
        if [[ -f "$f" ]]; then
            brew_install_all_from_yaml "$f"
        fi
    done
}


services_unmask_disable_enable_mask_yaml() {
    local svc_yaml="$1"

    # Get the current Fedora version for version-specific queries
    local version
    version=$(immutablue_get_image_version 2>/dev/null || echo "")
    local arch
    arch=$(uname -m)

    # Query both .all[] and .${version}[] entries for each service section
    local enable
    enable="$(cat \
        <(yq '.immutablue.services_enable_user.all[]' < "${svc_yaml}" 2>/dev/null) \
        <(yq ".immutablue.services_enable_user.${version}[]" < "${svc_yaml}" 2>/dev/null) \
        <(yq ".immutablue.services_enable_user_${arch}.all[]" < "${svc_yaml}" 2>/dev/null) \
        <(yq ".immutablue.services_enable_user_${arch}.${version}[]" < "${svc_yaml}" 2>/dev/null) \
        | grep -v '^null$' | grep -v '^$' || true)"

    local disable
    disable="$(cat \
        <(yq '.immutablue.services_disable_user.all[]' < "${svc_yaml}" 2>/dev/null) \
        <(yq ".immutablue.services_disable_user.${version}[]" < "${svc_yaml}" 2>/dev/null) \
        <(yq ".immutablue.services_disable_user_${arch}.all[]" < "${svc_yaml}" 2>/dev/null) \
        <(yq ".immutablue.services_disable_user_${arch}.${version}[]" < "${svc_yaml}" 2>/dev/null) \
        | grep -v '^null$' | grep -v '^$' || true)"

    local mask
    mask="$(cat \
        <(yq '.immutablue.services_mask_user.all[]' < "${svc_yaml}" 2>/dev/null) \
        <(yq ".immutablue.services_mask_user.${version}[]" < "${svc_yaml}" 2>/dev/null) \
        <(yq ".immutablue.services_mask_user_${arch}.all[]" < "${svc_yaml}" 2>/dev/null) \
        <(yq ".immutablue.services_mask_user_${arch}.${version}[]" < "${svc_yaml}" 2>/dev/null) \
        | grep -v '^null$' | grep -v '^$' || true)"

    local unmask
    unmask="$(cat \
        <(yq '.immutablue.services_unmask_user.all[]' < "${svc_yaml}" 2>/dev/null) \
        <(yq ".immutablue.services_unmask_user.${version}[]" < "${svc_yaml}" 2>/dev/null) \
        <(yq ".immutablue.services_unmask_user_${arch}.all[]" < "${svc_yaml}" 2>/dev/null) \
        <(yq ".immutablue.services_unmask_user_${arch}.${version}[]" < "${svc_yaml}" 2>/dev/null) \
        | grep -v '^null$' | grep -v '^$' || true)"

    systemctl --user daemon-reload || true
    for s in $unmask; do systemctl --user unmask --now "$s"; done
    for s in $disable; do systemctl --user disable --now "$s"; done
    for s in $enable; do systemctl --user enable --now "$s"; done
    for s in $mask; do systemctl --user mask --now "$s"; done
}


services_unmask_disable_enable_mask_all() {
    services_unmask_disable_enable_mask_yaml "$PACKAGES_FILE"
    for f in $PACKAGES_CUSTOM_FMT; do
        if [[ -f "$f" ]]; then
            services_unmask_disable_enable_mask_yaml "$f"
        fi
    done
}


