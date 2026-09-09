#!/bin/bash
# Check boot ordering with actual orchestration and mock host commands.
set -euo pipefail
case "${1:-}" in
	-h|--help) echo 'Usage: bash tests/kuberblue/test_boot_config_gate.sh'; exit 0 ;;
	--license) echo 'AGPL-3.0-or-later'; exit 0 ;;
	'') ;;
	*) exit 2 ;;
esac
repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." > /dev/null && pwd)"
scratch_dir="$(mktemp -d)"
trap 'rm -rf -- "$scratch_dir"' EXIT
export BOOT_FIXTURE="$scratch_dir"
mkdir -p "$scratch_dir/lib/setup"
sed "s|/usr/libexec/kuberblue|$scratch_dir/lib|g" \
	"$repo_dir/artifacts/overrides_kuberblue/usr/libexec/kuberblue/setup/on_boot.sh" > "$scratch_dir/on_boot.sh"
# Every mutating host command is mocked. No services or swap are changed.
cat > "$scratch_dir/environment.sh" <<'STUB'
sleep () { :; }
swapoff () { echo prep >> "${BOOT_FIXTURE}/events"; }
zramctl () { :; }
systemctl () { :; }
ls () { :; }
STUB
export BASH_ENV="$scratch_dir/environment.sh"
cat > "$scratch_dir/lib/setup/config_fetch.sh" <<'STUB'
#!/bin/bash
set -euo pipefail
echo fetch >> "${BOOT_FIXTURE}/events"
attempt="$(grep -cx fetch "${BOOT_FIXTURE}/events")"
[[ "$attempt" -gt "$FETCH_FAILURES" ]]
STUB
cat > "$scratch_dir/lib/setup/first_boot.sh" <<'STUB'
#!/bin/bash
set -euo pipefail
echo bootstrap >> "${BOOT_FIXTURE}/events"
attempt="$(grep -cx bootstrap "${BOOT_FIXTURE}/events")"
[[ "$attempt" -gt "$BOOT_FAILURES" ]]
STUB
printf '#!/bin/bash\nexit 0\n' > "$scratch_dir/lib/setup/systemd_settings.sh"
chmod +x "$scratch_dir/lib/setup/"*.sh

# Permanent remote failure must exhaust retries without touching provisioning.
export FETCH_FAILURES=99 BOOT_FAILURES=0
if bash "$scratch_dir/on_boot.sh" > "$scratch_dir/run.log" 2>&1; then
	echo 'FAIL: failed config fetch accepted'; exit 1
fi
[[ "$(grep -cx fetch "$scratch_dir/events")" == 5 ]]
! grep -Eq '^(bootstrap|prep)$' "$scratch_dir/events"

# Transient fetch and provisioning failures both retry, in that order.
: > "$scratch_dir/events"
export FETCH_FAILURES=2 BOOT_FAILURES=1
bash "$scratch_dir/on_boot.sh" > "$scratch_dir/run.log" 2>&1 || { cat "$scratch_dir/run.log"; exit 1; }
[[ "$(grep -cx fetch "$scratch_dir/events")" == 3 ]]
[[ "$(grep -cx bootstrap "$scratch_dir/events")" == 2 ]]
[[ "$(head -3 "$scratch_dir/events" | sort -u)" == fetch ]]

# Local configuration (the fetcher's successful no-op) still provisions.
: > "$scratch_dir/events"
export FETCH_FAILURES=0 BOOT_FAILURES=0
bash "$scratch_dir/on_boot.sh" > "$scratch_dir/run.log" 2>&1 || { cat "$scratch_dir/run.log"; exit 1; }
[[ "$(grep -cx fetch "$scratch_dir/events")" == 1 ]]
[[ "$(grep -cx bootstrap "$scratch_dir/events")" == 1 ]]
echo 'PASS: configuration gates provisioning with bounded retries'
