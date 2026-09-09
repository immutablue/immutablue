#!/bin/bash
# Check restore targeting without privileged filesystem operations.
set -euo pipefail
case "${1:-}" in
	-h|--help) echo 'Usage/example: bash tests/test_snapshot_restore_guard.sh'; exit 0 ;;
	--license) echo 'AGPL-3.0-or-later'; exit 0 ;;
	'') ;;
	*) exit 2 ;;
esac
cd "$(dirname "${BASH_SOURCE[0]}")/.." > /dev/null
source <(sed -n '/^restore_snapshot()/,/^main()/p' artifacts/overrides/usr/libexec/immutablue/immutablue-snapshot | sed '$d')
fixture_dir="$(command mktemp -d)"
trap 'rm -rf -- "$fixture_dir"' EXIT
SNAPSHOT_SOURCE=/var
SNAPSHOT_DIR="$fixture_dir/snapshots"
mkdir -p "$SNAPSHOT_DIR/var-test" "$fixture_dir/top/var"
echo restored > "$SNAPSHOT_DIR/var-test/content"
echo original > "$fixture_dir/top/var/content"
id () { echo 0; }
mktemp () { echo "$fixture_dir/top"; }
mount () { echo mount >> "$fixture_dir/mutations"; }
umount () { :; }
rmdir () { :; }
findmnt () {
	case "$*" in
		*SOURCE*) echo '/dev/example[/var]' ;;
		*OPTIONS*) echo 'rw,subvolid=258,subvol=/var' ;;
	esac
}
btrfs () {
	case "$2" in
		show) [[ "$3" != /var || "$source_is_subvolume" == true ]] ;;
		snapshot) cp -a "$3" "$4" ;;
		*) return 1 ;;
	esac
}
source_is_subvolume=false
if restore_snapshot var-test > "$fixture_dir/output" 2>&1; then exit 1; fi
[[ ! -e "$fixture_dir/mutations" ]]
[[ "$(cat "$fixture_dir/top/var/content")" == original ]]
# Positive control: a real /var subvolume must still be staged successfully.
source_is_subvolume=true
restore_snapshot var-test > "$fixture_dir/output" 2>&1
[[ "$(cat "$fixture_dir/top/var/content")" == restored ]]
[[ "$(cat "$fixture_dir"/top/var-immutablue-previous-*/content)" == original ]]
echo 'PASS: bind-mounted directories rejected; subvolume restore preserved'
