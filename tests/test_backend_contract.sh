#!/bin/bash
# Check that every backend implements the build contract and is self-consistent.
# SPDX-License-Identifier: AGPL-3.0-or-later
set -euo pipefail
case "${1:-}" in
	-h|--help) echo 'Usage: bash tests/test_backend_contract.sh'; echo 'Example: bash tests/test_backend_contract.sh'; exit 0 ;;
	--license) echo 'AGPL-3.0-or-later'; exit 0 ;;
	'') ;;
	*) exit 2 ;;
esac
root="$(CDPATH='' cd -- "$(dirname "${BASH_SOURCE[0]}")/.." > /dev/null && pwd)"
failed=0

fail () {
	echo "FAIL: $*" >&2
	failed=1
}

# The required function list comes from the interface itself, so adding a
# function there makes every backend that lacks it fail here.
mapfile -t required < <(bash -c 'source "$1/backends/lib/interface.sh"; printf "%s\n" "${BACKEND_REQUIRED_FUNCS[@]}"' _ "$root")
[[ ${#required[@]} -gt 0 ]] || fail 'interface.sh lists no required functions'

backends=0
for dir in "$root"/backends/*/; do
	dir="${dir%/}"
	name="$(basename "$dir")"
	[[ "$name" == lib ]] && continue
	backends=$((backends + 1))
	yaml="$dir/backend.yaml"

	# Metadata every stage and the Makefile read.
	[[ -f "$yaml" ]] || { fail "$name: no backend.yaml"; continue; }
	[[ "$(yq '.name' "$yaml")" == "$name" ]] || fail "$name: backend.yaml name does not match its directory"
	for field in init kernel delivery base_image; do
		[[ -n "$(yq ".${field} // \"\"" "$yaml")" ]] || fail "$name: backend.yaml has no $field"
	done
	[[ -f "$dir/Containerfile" ]] || fail "$name: no Containerfile"
	[[ -f "$dir/runtime.sh" ]] || fail "$name: no runtime.sh for immutablue-backend"

	# Every required function, defined by sourcing the file with no side effects.
	for fn in "${required[@]}"; do
		bash -c 'source "$1" && declare -F "$2" > /dev/null' _ "$dir/backend.sh" "$fn" || fail "$name: backend.sh lacks $fn"
	done

	# scripts/os-release.sh writes the file /etc/os-release links to from
	# backend.yaml's os_release_base: the base image's /usr/lib/os-release
	# (absolute) or a file in the backend directory, which must exist.
	release="$(TRUE=1 FALSE=0 FEDORA_VERSION=44 bash -c 'source "$1" && backend_os_release_path' _ "$dir/backend.sh")"
	[[ -n "$release" ]] || fail "$name: backend_os_release_path prints nothing"
	release_base="$(yq '.os_release_base // ""' "$yaml")"
	[[ -n "$release_base" ]] || fail "$name: backend.yaml has no os_release_base"
	if [[ "$release_base" != /* ]]; then
		[[ -f "$dir/$release_base" ]] || fail "$name: os_release_base $release_base does not exist"
	fi

	# Stages named in skip_stages must exist, so a rename cannot silently
	# re-enable a stage for this backend.
	while read -r stage; do
		[[ -z "$stage" ]] && continue
		[[ -f "$root/build/$stage" ]] || fail "$name: skip_stages names missing build/$stage"
	done < <(yq '.skip_stages // [] | .[]' "$yaml")

	# A backend that regenerates an initramfs must say which modules it needs.
	if [[ "$(yq '.provides // [] | contains(["dracut"])' "$yaml")" == true ]]; then
		[[ "$(yq '.dracut_modules // [] | length' "$yaml")" -gt 0 ]] || fail "$name: provides dracut but lists no dracut_modules"
	fi
done

[[ $backends -ge 2 ]] || fail "expected several backends, found $backends"

# A backend that cannot build on this host is refused before podman runs.
if [[ "$(uname -s)" != FreeBSD ]] && bash "$root/scripts/check-backend.sh" freebsd-be nucleus > /dev/null 2>&1; then
	fail 'check-backend.sh accepted freebsd-be on a non-FreeBSD host'
fi
# ...as is a variant the backend cannot support.
if bash "$root/scripts/check-backend.sh" arch-bootc gui,silverblue,cyan > /dev/null 2>&1; then
	fail 'check-backend.sh accepted cyan on arch-bootc'
fi
bash "$root/scripts/check-backend.sh" fedora-bootc gui,silverblue,zfs,cyan > /dev/null || fail 'check-backend.sh rejected a normal fedora-bootc build'
# A 'requires' list (trueblue/zfs/lts: [rpm, pacman]) accepts each listed value.
bash "$root/scripts/check-backend.sh" fedora-bootc gui,silverblue,trueblue,lts,zfs > /dev/null || fail 'check-backend.sh rejected trueblue on fedora-bootc'
bash "$root/scripts/check-backend.sh" arch-bootc gui,silverblue,trueblue,lts,zfs > /dev/null || fail 'check-backend.sh rejected trueblue on arch-bootc'

# ARCHLINUX=1 / FREEBSD=1 select their backends; ARCH (a CPU architecture to
# many toolchains) is not an alias.
backend_of () {
	env -i PATH="$PATH" HOME="${HOME:-/tmp}" make --no-print-directory -s -C "$root" "$@" backend
}
[[ "$(backend_of ARCHLINUX=1)" == arch-bootc ]] || fail 'ARCHLINUX=1 does not select arch-bootc'
[[ "$(backend_of ARCH=1)" == fedora-bootc ]] || fail 'ARCH=1 changed the backend'
[[ "$(backend_of FREEBSD=1)" == freebsd-be ]] || fail 'FREEBSD=1 does not select freebsd-be'
[[ "$(backend_of ARCH=x86_64)" == fedora-bootc ]] || fail 'ARCH=x86_64 changed the backend'
[[ "$(backend_of)" == fedora-bootc ]] || fail 'the default backend is not fedora-bootc'

[[ $failed -eq 0 ]] || exit 1
echo "PASS: $backends backends implement the contract and are self-consistent"
