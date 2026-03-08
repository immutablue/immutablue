#!/bin/bash
# check-image-freshness.sh — Compare local vs remote container image age.
#
# Usage: check-image-freshness.sh <image_reference>
# Output (stdout): pull | local | build
#   pull  — remote image is newer than local; caller should pull
#   local — local image is current (same age or newer); skip rebuild
#   build — no image exists locally or remotely; must build
#
# Requires: buildah, skopeo, jq, date (GNU coreutils)

set -euo pipefail

IMAGE="${1:?Usage: check-image-freshness.sh <image_reference>}"

get_local_ts () {
	local created
	created=$(buildah inspect --format '{{.Created}}' "${IMAGE}" 2>/dev/null) || return 1
	date -d "${created}" +%s 2>/dev/null || return 1
}

get_remote_ts () {
	local created
	created=$(skopeo inspect "docker://${IMAGE}" 2>/dev/null | jq -r '.Created // empty') || return 1
	[[ -n "${created}" ]] || return 1
	date -d "${created}" +%s 2>/dev/null || return 1
}

local_ts=$(get_local_ts 2>/dev/null) || local_ts=""
remote_ts=$(get_remote_ts 2>/dev/null) || remote_ts=""

if [[ -n "${local_ts}" ]] && [[ -n "${remote_ts}" ]]; then
	if [[ "${remote_ts}" -gt "${local_ts}" ]]; then
		echo "pull"
	else
		echo "local"
	fi
elif [[ -n "${remote_ts}" ]]; then
	echo "pull"
elif [[ -n "${local_ts}" ]]; then
	echo "local"
else
	echo "build"
fi
