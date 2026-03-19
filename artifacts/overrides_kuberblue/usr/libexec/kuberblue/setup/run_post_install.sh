#!/bin/bash
set -euxo pipefail

if [[ -z "${1:-}" ]]; then
    echo "Usage: run_post_install.sh <install_dir>"
    exit 1
fi

bash -x "$1"/post_install.sh
