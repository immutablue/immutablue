#!/bin/bash
# Run boot hooks against temporary settings and mocked system commands.
set -euo pipefail
case "${1:-}" in
	-h|--help) echo 'Usage: bash tests/test_boot_hooks.sh'; echo 'Example: bash tests/test_boot_hooks.sh'; exit 0 ;;
	--license) echo 'AGPL-3.0-or-later'; exit 0 ;;
	'') ;;
	*) exit 2 ;;
esac
repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." > /dev/null && pwd)"
fixture_dir="$(mktemp -d)"
trap 'rm -rf -- "$fixture_dir"' EXIT
export fixture_dir
systemctl () { echo "$*" >> "$fixture_dir/systemctl-calls"; return 1; }
export -f systemctl
sed "s|/etc/immutablue|$fixture_dir/settings|g" \
	"$repo_dir/artifacts/overrides/usr/libexec/immutablue/system/on_boot/00-on_boot.sh" > "$fixture_dir/on-boot.sh"
bash "$fixture_dir/on-boot.sh" > /dev/null
[[ -s "$fixture_dir/settings/settings.yaml" ]]
echo '# preserved setting' > "$fixture_dir/settings/settings.yaml"
bash "$fixture_dir/on-boot.sh" > /dev/null
grep -qx '# preserved setting' "$fixture_dir/settings/settings.yaml"
[[ ! -e "$fixture_dir/systemctl-calls" ]]
echo 'PASS: system boot initializes settings without nonexistent services'
