#!/bin/bash
# Inspect the actual build recipes without running engines or prerequisites.
set -euo pipefail
case "${1:-}" in
	-h|--help) echo 'Usage: bash tests/test_build_platform.sh'; exit 0 ;;
	--license) echo 'AGPL-3.0-or-later'; exit 0 ;;
	'') ;;
	*) exit 2 ;;
esac
repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." > /dev/null && pwd)"
cd "$repo_dir"

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

# Dry-run the complete Makefile so conditional recipe selection is tested too.
# Mark generated prerequisites old to avoid regenerating any context metadata.
check_platform () {
	local platform="$1"
	shift
	local recipe
	recipe="$(hermetic_make --no-print-directory -n -o pre_test -o deps_manifest \
		-o .containerignore.image "PLATFORM=${platform}" "$@")"
	if [[ "$(printf '%s\n' "$recipe" | grep -Fc -- "--platform ${platform} " || true)" != 1 ]]; then
		printf 'FAIL: expected exactly one --platform %s in %s\n%s\n' "$platform" "$*" "$recipe" >&2
		return 1
	fi
}
for platform in linux/amd64 linux/arm64; do
	check_platform "$platform" build
	check_platform "$platform" DISTROLESS=1 build
	check_platform "$platform" build-deps
done
echo 'PASS: main and dependency build commands select the requested platform'
