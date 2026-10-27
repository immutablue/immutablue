#!/bin/bash
# check-backend.sh
#
# Refuse an image build that cannot work, before any container is started.
#
# Checks, in order:
#   1. backends/<backend>/backend.yaml exists
#   2. this host can build the backend (backend.yaml 'build_host_os')
#   3. every build option is supported: variants/<option>.yaml lists
#      'requires: {field: value | [values]}' and each field must match the
#      backend's backend.yaml
#
# Usage: check-backend.sh <backend> <build_options_csv>
#   check-backend.sh fedora-bootc gui,silverblue,zfs
#   check-backend.sh freebsd-be nucleus,kuberblue      # fails: kuberblue needs linux
set -euo pipefail

if [[ $# -ne 2 ]]
then
    echo 'check-backend.sh requires 2 positional arguments'
    echo 'check-backend.sh <backend> <build_options_csv>'
    exit 1
fi

backend="${1}"
build_options="${2}"
root_dir="$(CDPATH='' cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
backend_yaml="${root_dir}/backends/${backend}/backend.yaml"

# -----------------------------------
# 1. The backend exists
# -----------------------------------
if [[ ! -f "${backend_yaml}" ]]
then
    echo "ERROR: unknown BACKEND '${backend}'" >&2
    echo "       available: $(find "${root_dir}/backends" -mindepth 2 -maxdepth 2 -name backend.yaml -printf '%h\n' | xargs -n1 basename | sort | paste -sd ' ' -)" >&2
    exit 1
fi

# -----------------------------------
# 2. This host can build it
#
# A FreeBSD image needs podman + ocijail on a FreeBSD host; there is no way to
# run its build stages from Linux.
# -----------------------------------
build_host_os="$(yq '.build_host_os // ""' < "${backend_yaml}")"
host_os="$(uname -s)"
if [[ -n "${build_host_os}" ]] && [[ "${build_host_os}" != "${host_os}" ]]
then
    echo "ERROR: BACKEND=${backend} must be built on a ${build_host_os} host (this is ${host_os})" >&2
    note="$(yq '.build_host_note // ""' < "${backend_yaml}")"
    if [[ -n "${note}" ]]
    then
        echo "       ${note}" >&2
    fi
    exit 1
fi

# Every script in the repository is '#!/bin/bash'. A FreeBSD build host keeps
# bash at /usr/local/bin/bash, so it needs the conventional link.
if [[ "${host_os}" == "FreeBSD" ]] && [[ ! -x /bin/bash ]]
then
    echo "ERROR: the FreeBSD build host needs /bin/bash: ln -s /usr/local/bin/bash /bin/bash" >&2
    exit 1
fi

# -----------------------------------
# 3. Every build option is supported by the backend
# -----------------------------------
failed=0
IFS=',' read -ra options <<< "${build_options}"
for option in "${options[@]}"
do
    variant_yaml="${root_dir}/variants/${option}.yaml"
    [[ -f "${variant_yaml}" ]] || continue

    while read -r field
    do
        [[ -n "${field}" ]] || continue
        have="$(yq ".${field} // \"\"" < "${backend_yaml}")"
        # 'requires.<field>' may be a scalar or a list of acceptable values.
        if ! yq -e ".requires.${field} | (. == \"${have}\") or (tag == \"!!seq\" and contains([\"${have}\"]))" < "${variant_yaml}" >/dev/null 2>&1
        then
            want="$(yq -o=json -I=0 ".requires.${field}" < "${variant_yaml}")"
            echo "ERROR: build option '${option}' requires ${field}=${want}; BACKEND=${backend} has ${field}=${have:-<unset>}" >&2
            failed=1
        fi
    done < <(yq '.requires // {} | keys | .[]' < "${variant_yaml}")
done

if [[ ${failed} -ne 0 ]]
then
    exit 1
fi

echo "backend ${backend}: ok for ${build_options}"
