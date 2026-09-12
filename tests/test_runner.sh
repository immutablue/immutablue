#!/bin/bash
# Test the production runner against lightweight child scripts, never containers.
# SPDX-License-Identifier: AGPL-3.0-or-later
set -euo pipefail
case "${1:-}" in
	-h|--help) echo 'Usage: bash tests/test_runner.sh'; echo 'Example: bash tests/test_runner.sh'; exit 0 ;;
	--license) echo 'AGPL-3.0-or-later'; exit 0 ;;
	'') ;;
	*) exit 2 ;;
esac
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." > /dev/null && pwd)"
fixture="$(mktemp -d)"
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/tests"
cp "$root/tests/run_tests.sh" "$fixture/tests/"
export TRACE="$fixture/trace"
# Discover every optional test through the real registry, and stub its body.
while read -r test; do
	mkdir -p "$fixture/tests/$(dirname "$test")"
	cat > "$fixture/tests/$test" <<'MOCK'
#!/bin/bash
set -e
printf '%s:%s\n' "${0##*/}" "$*" >> "$TRACE"
# Errexit must remain active in a failing child, even though its caller captures status.
if [[ "${0##*/}" == "${FAIL_TEST:-}" ]]; then
	false
	echo 'FAIL: errexit disabled' >> "$TRACE"
fi
MOCK
done < <(KUBERBLUE=1 KUBERBLUE_CLUSTER_TEST=1 KUBERBLUE_INTEGRATION_TEST=1 KUBERBLUE_CHAINSAW_TEST=1 \
	bash "$fixture/tests/run_tests.sh" --list example/image:44)
# Ignore caller variant/skip flags; these assertions define their own scenarios.
unset KUBERBLUE KUBERBLUE_CLUSTER_TEST KUBERBLUE_INTEGRATION_TEST KUBERBLUE_CHAINSAW_TEST
export SKIP_TEST=0
if FAIL_TEST=test_shellcheck.sh bash "$fixture/tests/run_tests.sh" example/image:44 > "$fixture/output" 2>&1; then
	echo 'FAIL: ShellCheck failure ignored' >&2; exit 1
fi
grep -q '^test_setup.sh:$' "$TRACE"
! grep -q -- '--report-only\|errexit disabled' "$TRACE"
grep -q '^test_dep_provenance.sh:$' "$TRACE"
grep -q '^test_container.sh:example/image:44$' "$TRACE"
grep -q '1 failed' "$fixture/output"
: > "$TRACE"
SKIP_TEST=1 bash "$fixture/tests/run_tests.sh" example/image:44 > /dev/null
[[ ! -s "$TRACE" ]]
if SKIP_TEST=1 bash "$fixture/tests/run_tests.sh" --suite nonexistent example/image:44 > /dev/null 2>&1; then
	echo 'FAIL: skip accepted an invalid suite' >&2; exit 1
fi
bash "$fixture/tests/run_tests.sh" --suite regressions example/image:44 > /dev/null
! grep -q '^test_container.sh:' "$TRACE"
# Make and CLI must dispatch identical tests, including configured image arguments.
cp "$root/Makefile" "$fixture/"
cp -a "$root/makefiles" "$fixture/"
: > "$TRACE"
env -u MAKEFLAGS -u MAKEOVERRIDES make --no-print-directory -s -C "$fixture" test \
	IMAGE=example/image VERSION=44 KUBERBLUE=0 SKIP_TEST=0 > /dev/null
cp "$TRACE" "$fixture/make-trace"
: > "$TRACE"
KUBERBLUE=0 bash "$fixture/tests/run_tests.sh" example/image:44 > /dev/null
cmp "$TRACE" "$fixture/make-trace"
KUBERBLUE_CLUSTER_TEST=1 KUBERBLUE_INTEGRATION_TEST=1 bash "$fixture/tests/run_tests.sh" --list example/image:44-kuberblue > "$fixture/list"
grep -q '^kuberblue/test_kuberblue_integration.sh$' "$fixture/list"
! grep -q 'chainsaw' "$fixture/list"
echo 'PASS: runner aggregates failures, preserves errexit, and matches Make'
