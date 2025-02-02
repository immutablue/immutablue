#!/bin/bash 
set -euxo pipefail 
if [[ -f "${INSTALL_DIR}/build/99-common.sh" ]]; then source "${INSTALL_DIR}/build/99-common.sh"; fi
if [[ -f "./99-common.sh" ]]; then source "./99-common.sh"; fi


# Syncthing overrides
SYNCTHING_SVC_FILE="/usr/lib/systemd/user/syncthing.service"
SYNCTHING_WRAPPED_FILE="/usr/lib/systemd/user/syncthing-override.service"

if [[ -f "${SYNCTHING_SVC_FILE}" ]]
then 
    rm "${SYNCTHING_SVC_FILE}"
    ln -s "${SYNCTHING_WRAPPED_FILE}" "${SYNCTHING_SVC_FILE}"
fi


# add cyan justfile
if [[ "$(is_option_in_build_options cyan)" == "${TRUE}" ]]
then 
    echo -e 'import "./10-cyan.justfile"\n' >> /usr/libexec/immutablue/just/Justfile
fi

# add asahi justfile
if [[ "$(is_option_in_build_options asahi)" == "${TRUE}" ]]
then 
    echo -e 'import "./25-asahi.justfile"\n' >> /usr/libexec/immutablue/just/Justfile
fi


# set /etc/immutablue/setup to world-writable
chmod -R 777 /etc/immutablue/setup

# build hugo files
bash -c "cd /usr/immutablue/docs && hugo build"

