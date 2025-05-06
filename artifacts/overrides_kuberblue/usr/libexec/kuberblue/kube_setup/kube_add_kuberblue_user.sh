#!/bin/bash 
set -euxo pipefail 

source /usr/libexec/kuberblue/variables.sh

useradd -m -g wheel -u "$KUBERBLUE_UID" -s /bin/bash kuberblue || true
