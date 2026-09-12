#!/bin/bash
# Evaluate real Make variables without running a build or generating files.
set -euo pipefail
case "${1:-}" in
	-h|--help) echo 'Usage: bash tests/test_build_variants.sh'; exit 0 ;;
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

# Compare the complete option list: missing delimiters, lost add-ons and
# retained desktop flags must all fail, including explicit desktop selection.
check_options () {
	local expected="$1"
	shift
	local actual
	actual="$(hermetic_make --no-print-directory -s -f - "$@" print_options <<'MAKE'
include makefiles/00-variables.mk
include makefiles/10-variants-data.mk
include makefiles/20-variants-logic.mk
.PHONY: print_options
print_options:
	@printf '%s\n' '$(BUILD_OPTIONS)'
MAKE
)"
	if [[ "$actual" != "$expected" ]]; then
		printf 'FAIL: %s: expected %s, got %s\n' "$*" "$expected" "$actual" >&2
		return 1
	fi
}
check_options 'gui,silverblue'
check_options 'gui,kinoite,cyan,kuberblue' KINOITE=1 CYAN=1 KUBERBLUE=1
check_options 'nucleus' NUCLEUS=1
check_options 'nucleus,cyan,kuberblue' NUCLEUS=1 CYAN=1 KUBERBLUE=1
check_options 'nucleus,nix' NUCLEUS=1 KINOITE=1 NIX=1
check_options 'gui,distroless' DISTROLESS=1
check_options 'gui,distroless,nix' DISTROLESS=1 NIX=1
check_options 'gui,bazzite,cyan' BAZZITE=1 CYAN=1
check_options 'build_a_blue_workshop,kuberblue' BUILD_A_BLUE_WORKSHOP=1 KUBERBLUE=1
check_options 'nucleus,trueblue,lts,zfs' NUCLEUS=1 TRUEBLUE=1
echo 'PASS: special variants replace desktop flags and retain add-ons'
