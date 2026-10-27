#!/bin/bash
# Resolve once, before starting the build, so mutable tags cannot change stages.
#
# --allow-local: when the registry has no such image (a deps image built
# locally and never pushed, e.g. a new backend's), fall back to the image in
# local container storage, still pinned by its digest. Off by default: the
# fedora-bootc path must fail on a registry error rather than build against
# whatever happens to be local. Enabled per backend by backend.yaml
# 'deps_local_fallback: true'.
# SPDX-License-Identifier: AGPL-3.0-or-later
set -euo pipefail
allow_local=0
case "${1:-}" in
	-h|--help) echo 'Usage: resolve-deps-image.sh [--allow-local] IMAGE[:TAG|@DIGEST]'; echo 'Example: resolve-deps-image.sh quay.io/immutablue/immutablue:44-deps'; echo 'Example: resolve-deps-image.sh --allow-local quay.io/immutablue/immutablue:arch-deps'; exit 0 ;;
	--license) echo 'AGPL-3.0-or-later'; exit 0 ;;
	--allow-local) allow_local=1; shift ;;
esac
[[ $# -eq 1 && -n "$1" ]] || { echo 'ERROR: supply one dependency image' >&2; exit 1; }
reference="$1"
if [[ "$reference" == *@* ]]; then
	digest="${reference##*@}"
	repository="${reference%@*}"
else
	repository="$reference"
	[[ "${repository##*/}" != *:* ]] || repository="${repository%:*}"
	if ! digest="$(skopeo inspect --format '{{.Digest}}' "docker://${reference}" 2>/dev/null)"; then
		digest=""
		if [[ "$allow_local" -eq 1 ]] && digest="$(podman image inspect --format '{{.Digest}}' "$reference" 2>/dev/null)"; then
			echo "WARNING: ${reference} is not in the registry; using the local image ${digest}" >&2
		else
			echo "ERROR: cannot resolve ${reference} in the registry" >&2
			exit 1
		fi
	fi
fi
[[ "$digest" =~ ^sha256:[0-9a-f]{64}$ ]] || { echo 'ERROR: invalid dependency image digest' >&2; exit 1; }
printf '%s@%s\n' "$repository" "$digest"
