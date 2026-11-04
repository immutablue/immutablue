#!/bin/bash
set -euxo pipefail
if [[ -f "${INSTALL_DIR}/build/99-common.sh" ]]; then source "${INSTALL_DIR}/build/99-common.sh"; fi
if [[ -f "./99-common.sh" ]]; then source "./99-common.sh"; fi

pkgs=$(get_immutablue_packages_to_remove)


# -----------------------------------
# Remove only what is actually installed.
#
# Package managers fail the whole transaction when handed a package that is
# not present (dnf5: "no match for argument"), which under `set -e` aborts the image build --
# on a package we wanted gone anyway. That turns an upstream rename or a
# dropped Fedora package into a hard build failure for no benefit, so the
# request is intersected with the installed set first.
#
# Anything filtered out is reported, because a permanently-absent entry in
# rpm_rm is dead configuration worth noticing.
# -----------------------------------
if [[ -n "${pkgs}" ]]
then
    installed_pkgs=()
    for pkg in ${pkgs}
    do
        if [[ "$(backend_pkg_installed "${pkg}")" == "${TRUE}" ]]
        then
            installed_pkgs+=("${pkg}")
        else
            echo "Skipping removal of '${pkg}': not installed"
        fi
    done

    if [[ ${#installed_pkgs[@]} -gt 0 ]]
    then
        backend_pkg_remove "${installed_pkgs[@]}"
    else
        echo "None of the requested packages are installed; nothing to remove"
    fi
fi

