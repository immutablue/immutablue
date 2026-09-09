#!/bin/bash
# Run the actual first-boot state machine with services replaced by fixtures.
set -euo pipefail
case "${1:-}" in
	-h|--help) echo 'Usage: bash tests/kuberblue/test_ha_resume.sh'; exit 0 ;;
	--license) echo 'AGPL-3.0-or-later'; exit 0 ;;
	'') ;;
	*) exit 2 ;;
esac
repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." > /dev/null && pwd)"
source_dir="${repo_dir}/artifacts/overrides_kuberblue/usr/libexec/kuberblue"
scratch_dir="$(mktemp -d)"
trap 'rm -rf -- "$scratch_dir"' EXIT
export HA_FIXTURE="$scratch_dir"
mkdir -p "$scratch_dir/lib/kube_setup" "$scratch_dir/etc"
cp "$source_dir/kube_setup/kube_state.sh" "$scratch_dir/lib/kube_setup/"
# Only remap filesystem paths. All branch and state-transition logic is real.
sed -e "s|/usr/libexec/kuberblue|$scratch_dir/lib|g" \
	-e "s|/etc/kuberblue|$scratch_dir/etc|g" \
	"$source_dir/setup/first_boot.sh" > "$scratch_dir/first_boot.sh"
cat > "$scratch_dir/lib/variables.sh" <<'STUB'
STATE_DIR="${HA_FIXTURE}/state"
KUBERBLUE_TOPOLOGY=ha
KUBERBLUE_NODE_ROLE=control-plane
KUBERBLUE_TAILSCALE_ENABLED="${TEST_TAILSCALE:-false}"
KUBERBLUE_ADVERTISE_ADDR=auto
KUBERBLUE_SOPS_ENABLED=false
KUBERBLUE_GITOPS_ENABLED=false
kuberblue_load_all () { :; }
kuberblue_config_get () {
	if [[ "$2" == .networking.tailscale.tag ]]; then echo cp; else echo "$3"; fi
}
STUB
cat > "$scratch_dir/lib/99-common.sh" <<'STUB'
sleep () { :; }
chown () { :; }
wait_for_node_ready_state () { :; }
tailscale () { echo '{}'; }
yq () { cat > /dev/null; }
curl () { printf '%064d\n' 0; }
kubeadm () {
	printf 'kubeadm %s\n' "$*" >> "${HA_FIXTURE}/events"
	printf '%064d\n' 0
}
kubeadm_join_safe () { echo join >> "${HA_FIXTURE}/events"; }
STUB
cat > "$scratch_dir/lib/kube_setup/kube_init.sh" <<'STUB'
#!/bin/bash
set -euo pipefail
source "${HA_FIXTURE}/lib/variables.sh"
source "${HA_FIXTURE}/lib/kube_setup/kube_state.sh"
# Emulate kube_init marking success before returning to first_boot.
[[ "$(kuberblue_state_get ha-role)" == init-cp ]]
echo init >> "${HA_FIXTURE}/events"
kuberblue_state_set cluster-initialized true
STUB
cat > "$scratch_dir/lib/kube_setup/kube_post_install.sh" <<'STUB'
#!/bin/bash
echo post >> "${HA_FIXTURE}/events"
[[ ! -f "${HA_FIXTURE}/fail-post" ]]
STUB
cat > "$scratch_dir/lib/kube_setup/kube_add_kuberblue_user.sh" <<'STUB'
#!/bin/bash
echo user >> "${HA_FIXTURE}/events"
[[ ! -f "${HA_FIXTURE}/fail-user" ]]
STUB
printf '#!/bin/bash\nexit 0\n' > "$scratch_dir/lib/kube_setup/kube_put_config.sh"
printf '#!/bin/bash\nexit 0\n' > "$scratch_dir/lib/kube_setup/kube_tailscale_setup.sh"
printf 'kuberblue_vip_setup () { :; }\n' > "$scratch_dir/lib/kube_setup/kube_vip_setup.sh"
cat > "$scratch_dir/lib/kube_setup/kube_token_distribute.sh" <<'STUB'
kuberblue_token_discover_cp () { echo 192.0.2.1; }
kuberblue_token_fetch () { echo 'kubeadm join fixture' > "$1"; }
STUB
chmod +x "$scratch_dir/lib/kube_setup/"*.sh

# The first CP fails after kubeadm init, then resumes without becoming a joiner.
touch "$scratch_dir/fail-post"
if bash "$scratch_dir/first_boot.sh" > "$scratch_dir/run.log" 2>&1; then
	echo 'FAIL: expected post-install failure'; exit 1
fi
[[ ! -f "$scratch_dir/etc/did_first_boot" ]]
[[ "$(<"$scratch_dir/state/state/ha-role")" == init-cp ]]
rm "$scratch_dir/fail-post"
bash "$scratch_dir/first_boot.sh" >> "$scratch_dir/run.log" 2>&1 || { cat "$scratch_dir/run.log"; exit 1; }
[[ "$(grep -cx init "$scratch_dir/events")" == 1 ]]
[[ "$(grep -cx post "$scratch_dir/events")" == 2 ]]
! grep -qx join "$scratch_dir/events"
[[ -f "$scratch_dir/etc/did_first_boot" ]]

# A fresh secondary CP joins once; failure in user setup resumes after join.
rm -rf "$scratch_dir/state" "$scratch_dir/etc/did_first_boot"
: > "$scratch_dir/events"
export TEST_TAILSCALE=true
touch "$scratch_dir/fail-user"
if bash "$scratch_dir/first_boot.sh" > "$scratch_dir/run.log" 2>&1; then
	echo 'FAIL: expected user setup failure'; exit 1
fi
[[ "$(<"$scratch_dir/state/state/ha-role")" == join-cp ]]
rm "$scratch_dir/fail-user"
bash "$scratch_dir/first_boot.sh" >> "$scratch_dir/run.log" 2>&1 || { cat "$scratch_dir/run.log"; exit 1; }
[[ "$(grep -cx join "$scratch_dir/events")" == 1 ]]
[[ "$(grep -cx user "$scratch_dir/events")" == 2 ]]
! grep -qx init "$scratch_dir/events"
[[ -f "$scratch_dir/etc/did_first_boot" ]]

# Completed boots perform no further work; ambiguous old state fails closed.
cp "$scratch_dir/events" "$scratch_dir/expected-events"
bash "$scratch_dir/first_boot.sh" > /dev/null
cmp "$scratch_dir/events" "$scratch_dir/expected-events"
rm "$scratch_dir/etc/did_first_boot" "$scratch_dir/state/state/ha-role"
if bash "$scratch_dir/first_boot.sh" > "$scratch_dir/run.log" 2>&1; then
	echo 'FAIL: ambiguous initialized state accepted'; exit 1
fi
cmp "$scratch_dir/events" "$scratch_dir/expected-events"
echo 'PASS: HA init and join resume without repeating kubeadm'
