#!/bin/bash
# Exercise the actual fetch functions in a scratch tree without host changes.
set -euo pipefail
case "${1:-}" in
	-h|--help) echo 'Usage: bash tests/kuberblue/test_config_fetch_permissions.sh'; exit 0 ;;
	--license) echo 'AGPL-3.0-or-later'; exit 0 ;;
	'') ;;
	*) exit 2 ;;
esac
repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." > /dev/null && pwd)"
fetch_script="${repo_dir}/artifacts/overrides_kuberblue/usr/libexec/kuberblue/setup/config_fetch.sh"
source <(sed -n '/^decrypt_sops_files() {/,/^}/p; /^install_config() {/,/^}/p' "$fetch_script")
scratch_dir="$(mktemp -d)"
trap 'rm -rf -- "$scratch_dir"' EXIT
CLONE_DIR="${scratch_dir}/repo"
KB_CONFIG_PATH=cluster
SECRETS_DIR="${scratch_dir}/keys"
SYSTEM_CONFIG_DIR="${scratch_dir}/installed"
umask 0022
mkdir -p "${CLONE_DIR}/cluster/secrets" "$SECRETS_DIR" "${SYSTEM_CONFIG_DIR}/secrets"
printf 'test-key\n' > "${SECRETS_DIR}/age.key"
printf 'encrypted fixture\n' > "${CLONE_DIR}/cluster/secrets/auth.sops.yaml"
printf 'old plaintext\n' > "${CLONE_DIR}/cluster/secrets/auth.yaml"
printf 'old installed plaintext\n' > "${SYSTEM_CONFIG_DIR}/secrets/auth.yaml"
chmod 0644 "${CLONE_DIR}/cluster/secrets/auth.yaml" "${SYSTEM_CONFIG_DIR}/secrets/auth.yaml"

# Check privacy during decryption, not merely after a subsequent chmod.
sops () {
	[[ "$(stat -Lc '%a' /dev/stdout)" == 600 ]] || return 1
	printf 'password: fixture\n'
}
decrypt_sops_files
install_config
[[ "$(stat -c '%a' "${SYSTEM_CONFIG_DIR}/secrets/auth.yaml")" == 600 ]]
[[ "$(<"${SYSTEM_CONFIG_DIR}/secrets/auth.yaml")" == 'password: fixture' ]]
[[ ! -e "${CLONE_DIR}/cluster/secrets/auth.sops.yaml" ]]

# A failed decryption must not replace the previous plaintext or leave output.
printf 'bad ciphertext\n' > "${CLONE_DIR}/cluster/secrets/auth.sops.yaml"
sops () { printf 'partial plaintext\n'; return 1; }
if decrypt_sops_files; then
	echo 'FAIL: failed decryption accepted' >&2
	exit 1
fi
[[ "$(<"${CLONE_DIR}/cluster/secrets/auth.yaml")" == 'password: fixture' ]]
[[ -e "${CLONE_DIR}/cluster/secrets/auth.sops.yaml" ]]
[[ -z "$(find "${CLONE_DIR}" -name 'auth.yaml.*' -print -quit)" ]]
echo 'PASS: private secret installation and decryption failure isolation'
