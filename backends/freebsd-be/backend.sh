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


# A GNOME install fetches ~850 packages, and one dropped connection to the
# mirror fails the whole transaction. Retry with backoff; packages already in
# the cache are not downloaded again.
backend_pkg_install() {
    local attempt
    local delay=5

    if [[ $# -eq 0 ]]
    then
        return 0
    fi
    for attempt in 1 2 3 4
    do
        if pkg install -y "$@"
        then
            return 0
        fi
        [[ ${attempt} -lt 4 ]] || break
        echo "WARNING: pkg install failed (attempt ${attempt}/4); retrying in ${delay}s" >&2
        sleep "${delay}"
        delay=$((delay * 2))
    done
    return 1
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


# Rebuild the ports under backends/freebsd-be/ports/<category>/<port>/ with
# the patch-* files there added (EXTRA_PATCHES), as packages in
# <build_dir>/ports/ for stages/31-freebsd-ports.sh to install over the stock
# ones. For bugs in FreeBSD packages Immutablue cannot wait out (ConsoleKit2's
# session lookup breaks unlocking the GNOME lock screen).
#
# The ports tree is the quarterly branch of the build date -- the one the
# FreeBSD:15:amd64/quarterly pkg repository is built from -- so a rebuilt
# package is the same version as the one it replaces, plus the patches.
# Ports are built with the base system's make(1), not gmake.
#
# param $1: the deps build directory (/build)
backend_deps_build_extra() {
    local build_dir="$1"
    local src="${IMMUTABLUE_SRC:-/tmp/immutablue}/backends/freebsd-be/ports"
    local ports_tree="/tmp/ports"
    local month
    local branch
    local dir
    local origin
    local patches
    local attempt

    [[ -d "${src}" ]] || return 0
    month="$(date -u +%m)"
    branch="$(date -u +%Y)Q$(( (10#${month} - 1) / 3 + 1 ))"
    for attempt in 1 2 3 4
    do
        rm -rf "${ports_tree}"
        if git clone --depth 1 --branch "${branch}" https://git.FreeBSD.org/ports.git "${ports_tree}"
        then
            break
        fi
        [[ ${attempt} -lt 4 ]] || return 1
        sleep $(( attempt * 5 ))
    done

    mkdir -p "${build_dir}/ports"
    for dir in "${src}"/*/*/
    do
        origin="${dir%/}"
        origin="${origin#"${src}/"}"
        patches="$(find "${dir}" -name 'patch-*' -type f | sort | tr '\n' ' ')"
        echo "=== ports: ${origin} (${branch}) with ${patches} ==="
        /usr/bin/make -C "${ports_tree}/${origin}" BATCH=yes install-missing-packages
        /usr/bin/make -C "${ports_tree}/${origin}" BATCH=yes WRKDIRPREFIX=/tmp/ports-wrk \
            EXTRA_PATCHES="${patches}" package
        cp "/tmp/ports-wrk${ports_tree}/${origin}"/work/pkg/*.pkg "${build_dir}/ports/"
    done
    rm -rf "${ports_tree}" /tmp/ports-wrk
}


# Refresh the run-time linker hints after a library install.
#
# A bare ldconfig on FreeBSD replaces the hints with only the directories it
# is given; -m merges. The library directories ports register (gcc's runtime,
# FFmpeg, ...) live in /usr/local/libdata/ldconfig and are normally added at
# boot by rc.d/ldconfig, which never runs in a container build.
backend_ldconfig() {
    local dirs=()

    mapfile -t dirs < <(cat /usr/local/libdata/ldconfig/* 2> /dev/null || true)
    ldconfig -m /usr/local/lib "${dirs[@]}"
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


# Last step of an image built FROM an Immutablue image: record the stock
# configuration and setuid modes again, so deliver.sh's three-way /etc merge
# and mode restore see what the derived image ships.
backend_finalize_derived() {
    backend_finalize
}
