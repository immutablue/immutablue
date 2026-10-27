#!/bin/bash
# backends/freebsd-be/backend.sh
#
# The freebsd-be implementation of backends/lib/interface.sh: pkg(8) for
# packages (pkgbase for the base system, the ports tree's packages for the
# rest), rc.conf via sysrc(8) for services, and a stock copy of the
# configuration trees as the finalize step so deliver.sh can carry local
# changes across updates.


# Add a pkg(8) repository.
#
# param $1: repository name
# param $2: repository URL
backend_repo_add() {
    local repo="$1"
    local url="$2"

    mkdir -p /usr/local/etc/pkg/repos
    cat > "/usr/local/etc/pkg/repos/${repo}.conf" <<EOF
${repo}: {
  url: "${url}",
  enabled: yes
}
EOF
    pkg update -f
}


backend_pkg_install() {
    if [[ $# -eq 0 ]]
    then
        return 0
    fi
    pkg install -y "$@"
}


# pkg add takes local paths and URLs alike.
backend_pkg_install_files() {
    local file

    for file in "$@"
    do
        pkg add "${file}"
    done
}


backend_pkg_remove() {
    if [[ $# -eq 0 ]]
    then
        return 0
    fi
    pkg delete -y "$@"
}


backend_pkg_installed() {
    local pkg="$1"

    if pkg info -e "${pkg}"
    then
        echo "${TRUE}"
    else
        echo "${FALSE}"
    fi
}


# Translate unit-state requests into rc.conf.
#
# rc(8) has no masking and no per-user services: mask/unmask are reported and
# ignored, and anything with --global (the systemd --global user presets) is
# skipped. packages.yaml maps unit names to rc script names with 'rc:'.
#
# param $1: enable | disable | mask | unmask
# param $2: optional '--global'
# param $@: the rc script name
backend_svc() {
    local action="$1"
    shift
    local svc

    if [[ "${1:-}" == "--global" ]]
    then
        echo "freebsd-be: no per-user services; skipping ${action} $*"
        return 0
    fi

    for svc in "$@"
    do
        case "${action}" in
            enable)
                sysrc "${svc}_enable=YES"
                ;;
            disable)
                sysrc "${svc}_enable=NO"
                ;;
            mask|unmask)
                echo "freebsd-be: rc(8) has no '${action}'; leaving ${svc} alone"
                ;;
            *)
                echo "ERROR: freebsd-be: unknown service action '${action}'" >&2
                return 1
                ;;
        esac
    done
}


backend_os_release_path() {
    echo "/etc/.os-release-freebsd"
}


# Prepare the deps container's package manager before build_deps install.
backend_deps_prepare() {
    pkg update -f
}


# Last step of the build.
#
# Records the image's own /etc and /usr/local/etc as shipped, under
# /usr/share/immutablue/stock/. deliver.sh compares a running system against
# the stock trees of the image it came from and of the image it is moving to:
# a file the administrator never changed takes the new image's version, a
# changed one is kept and reported. That is the three-way rule ostree applies
# to /etc on the Linux backends.
backend_finalize() {
    local stock="/usr/share/immutablue/stock"

    rm -rf "${stock}"
    mkdir -p "${stock}"
    cp -a /etc "${stock}/etc"
    if [[ -d /usr/local/etc ]]
    then
        cp -a /usr/local/etc "${stock}/usr-local-etc"
    fi

    # buildah on FreeBSD (1.43) drops setuid/setgid bits when it commits a
    # layer, so the image as stored has a non-setuid su, passwd and sudo, and
    # loses schg flags. They are still correct here, inside the build's RUN:
    # record them, and deliver.sh puts them back in the boot environment.
    # Format: <octal mode> TAB <chflags names or -> TAB <path>
    find / -xdev \( -path /mnt-ctx -o -path /dev -o -path /proc -o -path /tmp \) -prune -o \
        \( -type f -o -type d \) \( -perm -4000 -o -perm -2000 -o -flags +schg \) -print 2>/dev/null \
        | while IFS= read -r path
        do
            stat -f '%Mp%Lp%t%Sf%t%N' "${path}"
        done > "${stock}/modes"
    echo "Recorded $(wc -l < "${stock}/modes") setuid/setgid/schg paths in ${stock}/modes"

    pkg clean -ay
}
