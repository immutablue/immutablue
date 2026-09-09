#!/bin/bash
# Run the actual wrapper with privilege/container operations mocked out.
set -euo pipefail
case "${1:-}" in
	-h|--help) echo 'Usage: bash tests/test_build_image_config.sh'; echo 'Example: bash tests/test_build_image_config.sh'; exit 0 ;;
	--license) echo 'AGPL-3.0-or-later'; exit 0 ;;
	'') ;;
	*) exit 2 ;;
esac
repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." > /dev/null && pwd)"
fixture_dir="$(mktemp -d)"
trap 'rm -rf -- "$fixture_dir"' EXIT
export fixture_dir
sudo () { printf '%s\n' "$*" >> "$fixture_dir/calls"; }
export -f sudo
for mode in missing external same hardlink
do
	build_dir="$fixture_dir/$mode"
	mkdir -p "$build_dir"
	config_file="$fixture_dir/$mode.toml"
	case "$mode" in
		external) echo '# external config' > "$config_file" ;;
		same) config_file="$build_dir/config.toml"; echo '# existing config' > "$config_file" ;;
		hardlink)
			echo '# linked config' > "$build_dir/config.toml"
			ln "$build_dir/config.toml" "$config_file"
			;;
	esac
	: > "$fixture_dir/calls"
	bash "$repo_dir/scripts/build-image.sh" qcow2 example.invalid/review:44 "$build_dir" "$config_file" > "$fixture_dir/output" 2>&1
	[[ -s "$build_dir/config.toml" ]]
	grep -q '^podman run ' "$fixture_dir/calls"
	if [[ "$mode" != missing ]]; then cmp "$config_file" "$build_dir/config.toml"; fi
done
echo 'PASS: missing, external, identical and linked builder configurations'
