#!/bin/bash
set -euxo pipefail
if [[ -f "${INSTALL_DIR}/build/99-common.sh" ]]; then source "${INSTALL_DIR}/build/99-common.sh"; fi
if [[ -f "./99-common.sh" ]]; then source "./99-common.sh"; fi

# -----------------------------------
# Distroless builds don't use dnf for package removal
# -----------------------------------
if [[ "$(is_option_in_build_options distroless)" == "${TRUE}" ]]
then
    echo "=== Distroless build: skipping dnf package removal ==="
    exit 0
fi

pkgs=$(get_immutablue_packages_to_remove)


# -----------------------------------
# Remove only what is actually installed.
#
# dnf5 fails the whole transaction with "no match for argument" when handed a
# package that is not present, which under `set -e` aborts the image build --
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
        # --whatprovides resolves plain package names and capabilities alike,
        # matching what dnf5 itself accepts in a remove request.
        if rpm --quiet -q --whatprovides "${pkg}"
        then
            installed_pkgs+=("${pkg}")
        else
            echo "Skipping removal of '${pkg}': not installed"
        fi
    done

    if [[ ${#installed_pkgs[@]} -gt 0 ]]
    then
        dnf5 -y remove "${installed_pkgs[@]}"
    else
        echo "None of the requested packages are installed; nothing to remove"
    fi
fi

