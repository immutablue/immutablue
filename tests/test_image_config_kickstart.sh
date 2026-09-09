#!/bin/bash
# Exercise CLI dispatch with explicit kickstarts in every automatic mode.
set -euo pipefail
case "${1:-}" in
	-h|--help) echo 'Usage/example: bash tests/test_image_config_kickstart.sh'; exit 0 ;;
	--license) echo 'AGPL-3.0-or-later'; exit 0 ;;
	'') ;;
	*) exit 2 ;;
esac
cd "$(dirname "${BASH_SOURCE[0]}")/.." > /dev/null
fixture_dir="$(mktemp -d)"
trap 'rm -rf -- "$fixture_dir"' EXIT
printf '%s\n' 'lang en_US.UTF-8' 'firstboot --enable' > "$fixture_dir/install.ks"
for mode in automatic --non-interactive --no-user --lima
do
	options=()
	if [[ "$mode" != automatic ]]; then options+=("$mode"); fi
	bash scripts/generate-image-config.sh iso "$fixture_dir/config.toml" "${options[@]}" --kickstart "$fixture_dir/install.ks" < /dev/null
	[[ "$(yq -p toml -o yaml -r '.customizations.installer.kickstart.contents' "$fixture_dir/config.toml")" == "$(cat "$fixture_dir/install.ks")" ]]
	[[ "$(yq -p toml -o yaml '.customizations.user' "$fixture_dir/config.toml")" == null ]]
done
if bash scripts/generate-image-config.sh iso "$fixture_dir/invalid.toml" --non-interactive --kickstart "$fixture_dir/missing.ks" > /dev/null 2>&1
then
	echo 'FAIL: missing kickstart accepted' >&2
	exit 1
fi
echo 'PASS: explicit kickstarts preserved without automatic credentials'
