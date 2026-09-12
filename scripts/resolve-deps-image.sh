#!/bin/bash
# Resolve once, before starting the build, so mutable tags cannot change stages.
# SPDX-License-Identifier: AGPL-3.0-or-later
set -euo pipefail
case "${1:-}" in
	-h|--help) echo 'Usage: resolve-deps-image.sh IMAGE[:TAG|@DIGEST]'; echo 'Example: resolve-deps-image.sh quay.io/immutablue/immutablue:44-deps'; exit 0 ;;
	--license) echo 'AGPL-3.0-or-later'; exit 0 ;;
esac
[[ $# -eq 1 && -n "$1" ]] || { echo 'ERROR: supply one dependency image' >&2; exit 1; }
reference="$1"
if [[ "$reference" == *@* ]]; then
	digest="${reference##*@}"
	repository="${reference%@*}"
else
	digest="$(skopeo inspect --format '{{.Digest}}' "docker://${reference}")"
	repository="$reference"
	# Remove a tag from the final path component, preserving registry ports.
	[[ "${repository##*/}" != *:* ]] || repository="${repository%:*}"
fi
[[ "$digest" =~ ^sha256:[0-9a-f]{64}$ ]] || { echo 'ERROR: invalid dependency image digest' >&2; exit 1; }
printf '%s@%s\n' "$repository" "$digest"
