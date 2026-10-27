#!/bin/bash
# Drive immutablue-backend against stub OS tools and check what each verb runs.
# SPDX-License-Identifier: AGPL-3.0-or-later
set -euo pipefail
case "${1:-}" in
	-h|--help) echo 'Usage: bash tests/test_backend_dispatch.sh'; echo 'Example: bash tests/test_backend_dispatch.sh'; exit 0 ;;
	--license) echo 'AGPL-3.0-or-later'; exit 0 ;;
	'') ;;
	*) exit 2 ;;
esac
root="$(CDPATH='' cd -- "$(dirname "${BASH_SOURCE[0]}")/.." > /dev/null && pwd)"
fixture="$(mktemp -d)"
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/bin"

# Every OS tool a runtime.sh may call records its argv instead of acting.
for tool in rpm-ostree bootc rpm bectl pacman pkg jq; do
	cat > "$fixture/bin/$tool" <<MOCK
#!/bin/bash
printf '%s %s\n' "$tool" "\$*" >> "\$TRACE"
MOCK
	chmod +x "$fixture/bin/$tool"
done

dispatch () {
	local backend="$1"; shift
	: > "$fixture/trace"
	env -i PATH="$fixture/bin:/usr/bin:/bin" TRACE="$fixture/trace" \
		IMMUTABLUE_BACKEND="$backend" IMMUTABLUE_BACKENDS_DIR="$root/backends" \
		bash "$root/artifacts/overrides/usr/bin/immutablue-backend" "$@"
}

expect_trace () {
	local name="$1" want="$2" got
	got="$(paste -sd '|' "$fixture/trace")"
	if [[ "$got" != "$want" ]]; then
		echo "FAIL: $name" >&2
		echo "  want: $want" >&2
		echo "  got:  $got" >&2
		exit 1
	fi
}

# fedora-bootc runs exactly what the scripts ran before the dispatcher existed.
dispatch fedora-bootc upgrade;                 expect_trace 'fedora upgrade' 'bootc update'
dispatch fedora-bootc rollback;                expect_trace 'fedora rollback' 'rpm-ostree rollback'
dispatch fedora-bootc rebase quay.io/x/y:44;   expect_trace 'fedora rebase' 'bootc switch quay.io/x/y:44'
dispatch fedora-bootc kargs --append=quiet;    expect_trace 'fedora kargs' 'rpm-ostree kargs --append=quiet'
dispatch fedora-bootc cleanup;                 expect_trace 'fedora cleanup' 'rpm-ostree cleanup -bm'
dispatch fedora-bootc pkg-owner /usr/bin/sh;   expect_trace 'fedora pkg-owner' 'rpm -qf /usr/bin/sh'
dispatch fedora-bootc status --verbose;        expect_trace 'fedora status' 'rpm-ostree status --verbose'

# gnomeos has bootc but no package database.
dispatch gnomeos rollback;                     expect_trace 'gnomeos rollback' 'bootc rollback'
if dispatch gnomeos list-pkgs 2>/dev/null; then
	echo 'FAIL: gnomeos claimed to list packages' >&2; exit 1
elif [[ $? -ne 2 ]]; then
	echo 'FAIL: unsupported verb must exit 2' >&2; exit 1
fi

# Every backend that ships a runtime implements the verbs updates depend on.
for runtime in "$root"/backends/*/runtime.sh; do
	backend="$(basename "$(dirname "$runtime")")"
	for verb in status deployments healthy pending upgrade rollback rebase; do
		if ! bash -c 'source "$1"; declare -F "rt_$2" > /dev/null' _ "$runtime" "$verb"; then
			echo "FAIL: backend $backend runtime.sh lacks rt_$verb" >&2; exit 1
		fi
	done
done

# Unknown verbs are usage errors; images without a backend file are fedora-bootc.
if dispatch fedora-bootc frobnicate 2>/dev/null; then
	echo 'FAIL: unknown verb accepted' >&2; exit 1
fi
name="$(env -i PATH=/usr/bin:/bin bash "$root/artifacts/overrides/usr/bin/immutablue-backend" name)"
if [[ ! -e /usr/immutablue/backend && "$name" != fedora-bootc ]]; then
	echo "FAIL: default backend is '$name'" >&2; exit 1
fi

echo 'PASS: immutablue-backend dispatches each verb to the backend runtime'
