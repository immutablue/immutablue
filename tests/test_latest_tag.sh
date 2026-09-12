#!/bin/bash
# Inspect the real recipes without invoking a container engine.
set -euo pipefail
case "${1:-}" in
	-h|--help) echo 'Usage: bash tests/test_latest_tag.sh'; echo 'Example: bash tests/test_latest_tag.sh'; exit 0 ;;
	--license) echo 'AGPL-3.0-or-later'; exit 0 ;;
	'') ;;
	*) exit 2 ;;
esac
cd "$(dirname "${BASH_SOURCE[0]}")/.." > /dev/null
# The image build jobs invoke the suite as `make ZFS=1 test`, and Make exports
# command-line assignments into every recipe's environment as well as into
# MAKEFLAGS. Both channels leak into the Make instances evaluated below and
# silently rewrite the variables under test. Scrub the environment so these
# assertions describe the Makefiles themselves rather than the job that
# happened to launch them; PATH is kept because the Makefiles shell out to
# date(1) while expanding variables.
hermetic_make () {
	env -i PATH="$PATH" make "$@"
}

for distroless in 0 1
do
	for latest in 0 1
	do
		recipe="$(hermetic_make --no-print-directory -n -o pre_test -o deps_manifest -o .containerignore.image \
			build IMAGE=example.invalid/review VERSION=44 DISTROLESS="$distroless" SET_AS_LATEST="$latest")"
		engine=buildah
		tag=44
		if [[ "$distroless" == 1 ]]; then engine='sudo podman'; tag=44-distroless; fi
		actual="$(printf '%s\n' "$recipe" | grep -Fc "$engine tag example.invalid/review:$tag example.invalid/review:latest" || true)"
		[[ "$actual" -eq "$latest" ]]
		if [[ "$latest" == 1 ]]
		then
			[[ "${recipe##*$'\n'}" == "$engine tag example.invalid/review:$tag example.invalid/review:latest" ]]
		fi
	done
done
echo 'PASS: latest tags follow successful builds and respect opt-in'
