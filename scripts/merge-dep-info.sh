#!/bin/bash
# Merge artifact-owned dependency metadata with the current image's source.
# yq is bootstrapped before this helper is called inside the image build.
# SPDX-License-Identifier: AGPL-3.0-or-later
set -euo pipefail
case "${1:-}" in
	-h|--help) echo 'Usage: merge-dep-info.sh IMAGE_JSON DEPS_JSON IMAGE_DIGEST'; echo 'Example: merge-dep-info.sh image.json deps.json registry/image@sha256:...'; exit 0 ;;
	--license) echo 'AGPL-3.0-or-later'; exit 0 ;;
esac
[[ $# -eq 3 ]] || exit 1
export IMMUTABLUE_DEP_MANIFEST="$2" IMMUTABLUE_DEP_IMAGE="$3"
# Old dependency containers are deliberately rejected instead of assigning
# the current checkout's commits to unknown binaries.
yq -e '(.deps | length) > 0 and (.immutablue.commit != null)' "$2" > /dev/null
[[ "$3" =~ @sha256:[0-9a-f]{64}$ ]] || exit 1
yq -o=json '.deps = load(strenv(IMMUTABLUE_DEP_MANIFEST)).deps |
	.dependency_build = load(strenv(IMMUTABLUE_DEP_MANIFEST)).immutablue |
	.dependency_generated = load(strenv(IMMUTABLUE_DEP_MANIFEST)).generated |
	.dependency_image = strenv(IMMUTABLUE_DEP_IMAGE)' "$1"
