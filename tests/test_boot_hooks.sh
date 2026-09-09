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

# Exercise first-login membership handling, including an absent Docker group.
cat > "$fixture_dir/header.sh" <<'STUB'
TRUE=1
immutablue_build_has_package () { echo 1; }
STUB
sed -e "s|/usr/libexec/immutablue/immutablue-header.sh|$fixture_dir/header.sh|" \
	-e "s|\${HOME}|$fixture_dir/home|g" \
	"$repo_dir/artifacts/overrides/usr/libexec/immutablue/user/on_boot/00-on_login.sh" > "$fixture_dir/on-login.sh"
getent () { [[ "$test_membership" != absent ]]; }
id () {
	case "$test_membership" in
		member) echo 'users docker wheel' ;;
		lookalike) echo 'users docker-admin wheel' ;;
		*) echo 'users wheel' ;;
	esac
}
sudo () { printf '%s\n' "$*" >> "$fixture_dir/usermod-calls"; }
export -f getent id sudo
for test_membership in absent missing member lookalike
do
	export test_membership
	rm -rf "${fixture_dir:?}/home"
	: > "$fixture_dir/usermod-calls"
	bash "$fixture_dir/on-login.sh" > /dev/null
	[[ -s "$fixture_dir/home/.config/immutablue/settings.yaml" ]]
	case "$test_membership" in
		missing|lookalike) grep -qx "usermod -aG docker $USER" "$fixture_dir/usermod-calls" ;;
		*) [[ ! -s "$fixture_dir/usermod-calls" ]] ;;
	esac
done
echo 'PASS: first-login settings and exact Docker group membership'
