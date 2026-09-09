#!/bin/bash
# Round-trip generated credentials through a TOML parser, using dummy values.
set -euo pipefail
case "${1:-}" in
	-h|--help) echo 'Usage/example: bash tests/test_image_config_strings.sh'; exit 0 ;;
	--license) echo 'AGPL-3.0-or-later'; exit 0 ;;
	'') ;;
	*) exit 2 ;;
esac
cd "$(dirname "${BASH_SOURCE[0]}")/.." > /dev/null
source <(sed -n '/^toml_string()/,/^append_kickstart()/p' scripts/generate-image-config.sh | sed '$d')
fixture_dir="$(mktemp -d)"
trap 'rm -rf -- "$fixture_dir"' EXIT
for password in plain 'quote"value' 'back\slash' $'tab\tnewline\ncontrol\001end'
do
	: > "$fixture_dir/config.toml"
	write_user_config "$fixture_dir/config.toml" user "$password" y 'ssh-ed25519 dummy comment"with\slashes'
	[[ "$(yq -p toml -o yaml -r '.customizations.user[0].password' "$fixture_dir/config.toml")" == "$password" ]]
	[[ "$(yq -p toml -o yaml -r '.customizations.user[0].key' "$fixture_dir/config.toml")" == 'ssh-ed25519 dummy comment"with\slashes' ]]
done
# Test the actual prompt reader as well: read must not consume backslashes.
OUTPUT="$fixture_dir/prompt.toml"
LIMA=0
prompt_for_user <<< $'y\nuser\nback\\slash"quote\ny\nn' > /dev/null
[[ "$(yq -p toml -o yaml -r '.customizations.user[0].password' "$OUTPUT")" == 'back\slash"quote' ]]
echo 'PASS: TOML and prompt credentials preserve literal text'
