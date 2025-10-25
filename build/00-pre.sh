#!/bin/bash 
set -euxo pipefail 

# Normal files don't exist yet since we are too early in the build. Need to source these from the 
# ctx container
# if [[ -f "/mnt-ctx/build/99-common.sh" ]]; then source "/mnt-ctx/build/99-common.sh"; fi
# if [[ -f "/mnt-ctx/artifacts/overrides/usr/libexec/immutablue/immutablue-header.sh" ]]; then source "/mnt-ctx/artifacts/overrides/usr/libexec/immutablue/immutablue-header.sh"; fi
# if [[ -f "${INSTALL_DIR}/build/99-common.sh" ]]; then source "${INSTALL_DIR}/build/99-common.sh"; fi
# if [[ -f "./99-common.sh" ]]; then source "./99-common.sh"; fi

# This does nothing at the moment, simply just run true
true

