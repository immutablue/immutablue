#!/bin/bash
set -euxo pipefail

for dir in /var/home/*; do su -l -c 'kuberblue --verbose kube_get_config' "$(basename $dir)" || true; done
