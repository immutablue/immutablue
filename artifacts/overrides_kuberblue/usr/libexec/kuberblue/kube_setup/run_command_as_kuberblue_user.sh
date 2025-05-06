#!/bin/bash
set -euxo pipefail

until su -l -c "$1" kuberblue || true; do echo "$2" && sleep 5; done
