#!/bin/bash
# backends/gnomeos/backend.sh
#
# The gnomeos implementation of backends/lib/interface.sh.
#
# GNOME OS images carry no package manager, so the package and repository
# functions refuse loudly rather than pretend: every stage that would call them
# is listed under skip_stages in backend.yaml, and reaching one means a stage
# was added without considering this backend.


backend_repo_add() {
    echo "ERROR: gnomeos has no package manager; cannot add repository '$1'" >&2
    return 1
}


backend_pkg_install() {
    if [[ $# -eq 0 ]]
    then
        return 0
    fi
    echo "ERROR: gnomeos has no package manager; cannot install: $*" >&2
    return 1
}


backend_pkg_install_files() {
    backend_pkg_install "$@"
}


backend_pkg_remove() {
    if [[ $# -eq 0 ]]
    then
        return 0
    fi
    echo "ERROR: gnomeos has no package manager; cannot remove: $*" >&2
    return 1
}


# Nothing is installed "as a package" on GNOME OS.
backend_pkg_installed() {
    echo "${FALSE}"
}


# systemd is present, so unit state can still be changed where a stage needs it.
backend_svc() {
    local action="$1"
    shift
    systemctl "${action}" "$@"
}


# GNOME OS's own os-release, extended by stages/30-install-packages.sh.
backend_os_release_path() {
    echo "/usr/lib/os-release"
}


# GNOME OS images are bootc + composefs without an ostree container commit.
# Lint is advisory: GNOME OS nightly layouts trip checks Immutablue does not own.
backend_finalize() {
    bootc container lint || true
}


# Last step of an image built FROM an Immutablue image: the same lint.
backend_finalize_derived() {
    bootc container lint || true
}
