#!/bin/bash
# Capture source metadata before a dependency build, or only the image source.
# Copyright (C) Zach Podbielniak
# SPDX-License-Identifier: AGPL-3.0-or-later
set -euo pipefail

# Build JSON with jq so remote URLs and descriptions are always escaped.
dep_object () {
	local name="$1" path="$2" remote="$3" dirty=false
	[[ -z "$(git -C "$path" status --porcelain)" ]] || dirty=true
	jq -n --arg name "$name" --arg commit "$(git -C "$path" rev-parse HEAD)" \
		--arg remote "$remote" --arg describe "$(git -C "$path" describe --tags --always)" \
		--argjson dirty "$dirty" \
		'{name: $name, commit: $commit, remote: $remote, describe: $describe, dirty: $dirty}'
}

main () {
	local mode=deps out=deps-container/dep_info.json
	case "${1:-}" in
		-h|--help)
			echo 'Usage: gen-dep-info.sh [--image] [OUTPUT]'
			echo 'Example: scripts/gen-dep-info.sh deps-container/dep_info.json'
			echo 'Example: scripts/gen-dep-info.sh --image .image-source.json'
			return 0 ;;
		--license) echo 'AGPL-3.0-or-later'; return 0 ;;
		--image) mode=image; out=.image-source.json; shift ;;
		-*) echo "ERROR: unknown option $1" >&2; return 1 ;;
	esac
	[[ $# -le 1 ]] || { echo 'ERROR: too many arguments' >&2; return 1; }
	out="${1:-$out}"
	local objects='' key path remote top root tmp
	root="$(git rev-parse --show-toplevel)"
	cd "$root" > /dev/null
	if [[ "$mode" == deps ]]; then
		# Enumerate declared submodules, including missing directories. Git can
		# otherwise walk up from an empty directory and report the parent's HEAD.
		while read -r key path; do
			[[ "$path" == deps/* ]] || continue
			top="$(git -C "$path" rev-parse --show-toplevel 2>/dev/null || true)"
			if [[ ! -e "$path/.git" || "$top" != "$(realpath "$path")" ]]; then
				echo "ERROR: $path is uninitialized; run git submodule update --init --recursive" >&2
				return 1
			fi
			remote="$(git config -f .gitmodules --get "${key%.path}.url")"
			objects+="$(dep_object "${path#deps/}" "$path" "$remote")"$'\n'
		done < <(git config -f .gitmodules --get-regexp '^submodule\..*\.path$')
		[[ -n "$objects" ]] || { echo 'ERROR: no dependency submodules found' >&2; return 1; }
	fi
	mkdir -p "$(dirname "$out")"
	tmp="$(mktemp "${out}.XXXXXX")"
	# Publish only complete JSON; a failed generator must preserve the old file.
	if printf '%s' "$objects" | jq -s --arg commit "$(git rev-parse HEAD)" \
		--arg remote "$(git remote get-url origin 2>/dev/null || true)" \
		--arg generated "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
		'{generated: $generated, immutablue: {commit: $commit, remote: $remote}, deps: .}' > "$tmp"; then
		mv "$tmp" "$out"
	else
		rm -f "$tmp"
		return 1
	fi
}
main "$@"
