#!/bin/bash
# Exercise the production bootstrap with a daemon that starts logged out.
set -euo pipefail
case "${1:-}" in
	-h|--help) echo 'Usage: bash tests/kuberblue/test_tailscale_bootstrap.sh'; echo 'Example: bash tests/kuberblue/test_tailscale_bootstrap.sh'; exit 0 ;;
	--license) echo 'AGPL-3.0-or-later'; exit 0 ;;
	'') ;;
	*) exit 2 ;;
esac
repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." > /dev/null && pwd)"
fixture_dir="$(mktemp -d)"
trap 'rm -rf -- "$fixture_dir"' EXIT
export fixture_dir
cat > "$fixture_dir/variables.sh" <<'STUB'
STATE_DIR="$fixture_dir/state"
kuberblue_tailscale_enabled () { echo true; }
kuberblue_config_get () { printf '%s\n' "$3"; }
STUB
printf '%s\n' 'dummy-bootstrap-auth-key' > "$fixture_dir/authkey"
# Rewrite only installation paths; execute the complete production script.
sed -e "s|/usr/libexec/kuberblue/variables.sh|$fixture_dir/variables.sh|" \
	-e "s|/etc/kuberblue/tailscale-authkey|$fixture_dir/authkey|g" \
	"$repo_dir/artifacts/overrides_kuberblue/usr/libexec/kuberblue/kube_setup/kube_tailscale_setup.sh" > "$fixture_dir/bootstrap.sh"
systemctl () { return 0; }
sleep () { :; }
tailscale () {
	printf '%s\n' "$*" >> "$fixture_dir/calls"
	case "$1" in
		status)
			[[ "${daemon_unavailable:-0}" != 1 ]] || return 1
			[[ "${2:-}" == --json || -f "$fixture_dir/logged-in" ]]
			;;
		ip) [[ -f "$fixture_dir/logged-in" ]] && echo 100.64.0.1 ;;
		up) touch "$fixture_dir/logged-in" ;;
		*) return 1 ;;
	esac
}
export -f systemctl sleep tailscale
bash "$fixture_dir/bootstrap.sh" > "$fixture_dir/output" 2>&1
[[ "$(cat "$fixture_dir/state/tailscale-ip")" == 100.64.0.1 ]]
grep -q '^up ' "$fixture_dir/calls"
# An unreachable daemon must still fail after bounded retries, without login.
: > "$fixture_dir/calls"
if daemon_unavailable=1 bash "$fixture_dir/bootstrap.sh" > "$fixture_dir/output" 2>&1
then
	echo 'FAIL: unavailable daemon accepted' >&2
	exit 1
fi
[[ "$(wc -l < "$fixture_dir/calls")" -eq 12 ]]
if grep -q '^up ' "$fixture_dir/calls"; then exit 1; fi
echo 'PASS: fresh Tailscale login and bounded daemon readiness'
