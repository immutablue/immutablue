#!/bin/bash
# Verify discovery and HTTPS requests against mocked tailnet peers.
set -euo pipefail
case "${1:-}" in
	-h|--help) echo 'Usage/example: bash tests/kuberblue/test_token_dns.sh'; exit 0 ;;
	--license) echo 'AGPL-3.0-or-later'; exit 0 ;;
	'') ;;
	*) exit 2 ;;
esac
cd "$(dirname "${BASH_SOURCE[0]}")/../.." > /dev/null
fixture_dir="$(mktemp -d)"
trap 'rm -rf -- "$fixture_dir"' EXIT
STATE_DIR="$fixture_dir"
source artifacts/overrides_kuberblue/usr/libexec/kuberblue/kube_setup/kube_token_distribute.sh
kuberblue_config_get () { echo kuberblue-cp; }
tailscale () {
	case "$1" in
		ip) echo 100.64.0.2 ;;
		status) printf '{"Peer":{"cp":{"Tags":["tag:kuberblue-cp"],"TailscaleIPs":["100.64.0.1"],"DNSName":"%s"}}}\n' "$test_dns" ;;
		*) return 1 ;;
	esac
}
curl () {
	printf '%s\n' "$@" > "$fixture_dir/curl-args"
	[[ "${*: -1}" == https://cp.example.ts.net/kuberblue/join-token ]] || return 1
	echo 'kubeadm join endpoint:6443 --token dummy'
}
chown () { :; }
test_dns=cp.example.ts.net.
[[ "$(kuberblue_token_discover_cp)" == cp.example.ts.net ]]
kuberblue_token_fetch "$fixture_dir/join"
grep -q '^kubeadm join' "$fixture_dir/join"
if grep -qx -- '--insecure' "$fixture_dir/curl-args"; then exit 1; fi
# Never fall back to an IP when the required Serve hostname is unavailable.
test_dns=''
if kuberblue_token_discover_cp > /dev/null 2>&1; then exit 1; fi
echo 'PASS: Serve requests use DNS names with certificate verification'
