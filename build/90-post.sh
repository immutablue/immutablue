#!/bin/bash 
set -euxo pipefail 
if [ -f "${INSTALL_DIR}/build/99-common.sh" ]; then source "${INSTALL_DIR}/build/99-common.sh"; fi
if [ -f "./99-common.sh" ]; then source "./99-common.sh"; fi

# This does nothing at the moment, simply just run true
true

