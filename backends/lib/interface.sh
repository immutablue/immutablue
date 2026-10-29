#!/bin/bash
# backends/lib/interface.sh
#
# The contract between Immutablue's platform-neutral build stages (build/*.sh)
# and the operating system underneath them.
#
# A backend is a directory backends/<name>/ containing:
#
#   backend.yaml   static facts: base image, package key, init system, kernel,
#                  delivery mechanism and the capabilities it provides
#   backend.sh     the functions in BACKEND_REQUIRED_FUNCS, implemented with
#                  that OS's own tools
#   Containerfile  how the image is assembled for that OS
#   stages/        optional NN-*.sh scripts interleaved with build/NN-*.sh by
#                  backends/lib/run-stages.sh, for steps only that OS needs
#   overrides/     optional files copied over / after artifacts/overrides
#   runtime.sh     optional verbs for /usr/bin/immutablue-backend on the
#                  installed system
#
# The build stages never call dnf5, pacman, pkg, systemctl or sysrc directly;
# they call the functions below. Adding an OS means writing one backend
# directory, not editing every stage.
#
# This file is sourced by build/99-common.sh, so every stage has it. It is
# deliberately free of 'set -e' side effects and safe to source more than once.

# The backend used when nothing selects one. Matches every image built before
# backends existed, so an unset variable can never change what gets built.
IMMUTABLUE_BACKEND_DEFAULT="fedora-bootc"
IMMUTABLUE_BACKEND="${IMMUTABLUE_BACKEND:-${IMMUTABLUE_BACKEND_DEFAULT}}"

# Functions every backend.sh must define. backend_load() refuses to continue
# when any is missing, so a half-written backend fails at the first stage that
# sources 99-common.sh rather than somewhere in the middle of a package install.
BACKEND_REQUIRED_FUNCS=(
    backend_repo_add            # <name> <url>
    backend_pkg_install         # <pkg>...
    backend_pkg_install_files   # <url-or-path>...  (local or remote package files)
    backend_pkg_remove          # <pkg>...
    backend_pkg_installed       # <pkg>  -> echoes ${TRUE}/${FALSE}
    backend_svc                 # <enable|disable|mask|unmask> [--global] <unit>
    backend_os_release_path     # -> echoes the os-release file to link /etc/os-release to
    backend_finalize            # last step of the image build
)

# Optional functions a backend may define; callers test with 'declare -F':
#   backend_deps_prepare        before the deps container installs build_deps
#   backend_deps_build_extra    <build-dir>: extras after the shared deps
#   backend_ldconfig            refresh the linker cache (default: ldconfig)
#   backend_finalize_derived    last step of an image built FROM an Immutablue
#                               image (immutablue-custom and its forks), where
#                               backend_finalize's one-time layout work must not
#                               run again


# Locate the backends/ directory.
#
# Inside the image build the repo has been copied to ${INSTALL_DIR} by
# 10-copy.sh; on a host (tests, the Makefile) it sits next to this file. The
# directory of this file is authoritative in both cases, so it is used rather
# than guessing from INSTALL_DIR.
#
# returns: the absolute path of backends/ on stdout
backend_root_dir() {
    local here
    here="$(CDPATH='' cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    dirname "${here}"
}


# Path of the selected backend's directory.
#
# returns: the absolute path on stdout
backend_dir() {
    echo "$(backend_root_dir)/${IMMUTABLUE_BACKEND}"
}


# Read one scalar field from the selected backend's backend.yaml.
#
# param $1: field name, e.g. 'pkg_key' or 'init'
# returns: the value on stdout; empty when the field is absent
backend_get() {
    local field="$1"
    local yaml
    local value

    yaml="$(backend_dir)/backend.yaml"
    value="$(yq ".${field} // \"\"" < "${yaml}")"
    echo "${value}"
}


# Is a capability listed under 'provides' in backend.yaml?
#
# Stages use this instead of testing the backend's name, so a new backend that
# provides the same capability gets the same behaviour without a stage edit.
#
# param $1: capability, e.g. 'flatpak', 'dracut', 'inhouse_deps'
# returns: ${TRUE} or ${FALSE} on stdout
backend_has() {
    local cap="$1"
    local yaml
    local found

    yaml="$(backend_dir)/backend.yaml"
    found="$(yq ".provides // [] | contains([\"${cap}\"])" < "${yaml}")"
    if [[ "${found}" == "true" ]]
    then
        echo "${TRUE}"
    else
        echo "${FALSE}"
    fi
}


# Source the selected backend and verify it implements the whole contract.
#
# Exits the calling stage with a clear message when the backend does not exist
# or is incomplete; there is no safe partial behaviour to fall back to.
backend_load() {
    local dir
    local fn
    local missing=()

    dir="$(backend_dir)"

    if [[ ! -f "${dir}/backend.yaml" ]] || [[ ! -f "${dir}/backend.sh" ]]
    then
        echo "ERROR: unknown backend '${IMMUTABLUE_BACKEND}': ${dir} has no backend.yaml/backend.sh" >&2
        echo "       available: $(CDPATH='' cd -- "$(backend_root_dir)" && find . -mindepth 2 -maxdepth 2 -name backend.yaml -printf '%h\n' | sed 's|^\./||' | sort | paste -sd ' ' -)" >&2
        exit 1
    fi

    # shellcheck source=/dev/null
    source "${dir}/backend.sh"

    for fn in "${BACKEND_REQUIRED_FUNCS[@]}"
    do
        if ! declare -F "${fn}" >/dev/null
        then
            missing+=("${fn}")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]
    then
        echo "ERROR: backend '${IMMUTABLUE_BACKEND}' does not implement: ${missing[*]}" >&2
        exit 1
    fi
}
