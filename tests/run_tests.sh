#!/bin/bash
# One suite registry for the CLI and Make entry points.
# SPDX-License-Identifier: AGPL-3.0-or-later
set -euo pipefail

show_help () {
	echo 'Usage: tests/run_tests.sh [--suite SUITE] [--list] [IMAGE:TAG]'
	echo 'Suites: all (default), pre, regressions, container, package_presence, container_qemu, artifacts, setup, kuberblue'
	echo 'Examples: tests/run_tests.sh --suite regressions'
	echo '          tests/run_tests.sh quay.io/immutablue/immutablue:44'
	echo 'SKIP_TEST=1 skips execution; KUBERBLUE=1 adds Kuberblue checks.'
	echo 'KUBERBLUE_CLUSTER_TEST=1 enables cluster checks; KUBERBLUE_INTEGRATION_TEST=1 also enables integration checks.'
	echo 'KUBERBLUE_CHAINSAW_TEST=1 enables Chainsaw checks.'
}

# Register paths once. Each test runs in a fresh Bash process so the runner's
# conditional status capture cannot disable errexit inside the child script.
select_tests () {
	local suite="$1"
	case "$suite" in
		pre) selected+=(test_shellcheck.sh test_justfile_syntax.sh) ;;
		regressions)
			selected+=(test_image_config_kickstart.sh test_image_config_strings.sh
				kuberblue/test_token_dns.sh test_snapshot_restore_guard.sh test_boot_hooks.sh
				test_build_image_config.sh test_latest_tag.sh kuberblue/test_tailscale_bootstrap.sh
				kuberblue/test_config_fetch_permissions.sh kuberblue/test_ha_resume.sh
				kuberblue/test_boot_config_gate.sh test_build_variants.sh test_build_platform.sh
				test_brew_variants.sh test_dep_provenance.sh test_runner.sh) ;;
		container|package_presence|container_qemu|artifacts|setup) selected+=("test_${suite}.sh") ;;
		kuberblue)
			selected+=(kuberblue/test_kuberblue_container.sh kuberblue/test_kuberblue_components.sh
				kuberblue/test_kuberblue_security.sh)
			if [[ "${KUBERBLUE_CLUSTER_TEST:-0}" == 1 ]]; then
				selected+=(kuberblue/test_kuberblue_cluster.sh)
				if [[ "${KUBERBLUE_INTEGRATION_TEST:-0}" == 1 ]]; then
					selected+=(kuberblue/test_kuberblue_integration.sh)
				fi
			fi
			if [[ "${KUBERBLUE_CHAINSAW_TEST:-0}" == 1 ]]; then
				selected+=(kuberblue/chainsaw_runner.sh)
			fi ;;
		all)
			select_tests pre
			select_tests regressions
			selected+=(test_container.sh test_package_presence.sh test_container_qemu.sh test_artifacts.sh test_setup.sh)
			if [[ "${KUBERBLUE:-0}" == 1 || "$image" == *kuberblue* ]]; then
				select_tests kuberblue
			fi ;;
		*) echo "ERROR: unknown suite: $suite" >&2; return 2 ;;
	esac
}

main () {
	local test_dir root suite=all list=false image='' test status failed=0 passed=0
	local selected=() args=()
	test_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" > /dev/null && pwd)"
	root="$(dirname "$test_dir")"
	while [[ $# -gt 0 ]]; do
		case "$1" in
			-h|--help) show_help; return 0 ;;
			--license) echo 'AGPL-3.0-or-later'; return 0 ;;
			--suite) [[ $# -ge 2 ]] || return 2; suite="$2"; shift 2 ;;
			--list) list=true; shift ;;
			-*) echo "ERROR: unknown option $1" >&2; return 2 ;;
			*) [[ -z "$image" ]] || return 2; image="$1"; shift ;;
		esac
	done
	if [[ "${SKIP_TEST:-0}" == 1 && "$list" == false ]]; then
		select_tests "$suite"
		echo 'Skipping tests (SKIP_TEST=1)'
		return 0
	fi
	if [[ -z "$image" ]]; then
		image="$(make --no-print-directory -s -C "$root" image-reference)"
	fi
	select_tests "$suite"
	if [[ "$suite" == kuberblue || "$image" == *kuberblue* ]]; then
		export KUBERBLUE=1
	fi
	if [[ "$list" == true ]]; then
		printf '%s\n' "${selected[@]}"
		return 0
	fi
	cd "$root"
	for test in "${selected[@]}"; do
		args=()
		case "$test" in
			test_container.sh|test_package_presence.sh|test_container_qemu.sh|test_artifacts.sh|kuberblue/*)
				args+=("$image") ;;
		esac
		# The standalone Kuberblue regression scripts take no image argument.
		case "$test" in
			kuberblue/test_token_dns.sh|kuberblue/test_tailscale_bootstrap.sh|kuberblue/test_config_fetch_permissions.sh|kuberblue/test_ha_resume.sh|kuberblue/test_boot_config_gate.sh)
				args=() ;;
		esac
		printf '\n>> %s\n' "$test"
		status=0
		bash "$test_dir/$test" "${args[@]}" || status=$?
		if [[ "$status" == 0 ]]; then
			passed=$((passed + 1))
		else
			printf 'FAIL: %s (exit %s)\n' "$test" "$status" >&2
			failed=$((failed + 1))
		fi
	done
	printf '\nTest results: %s passed, %s failed\n' "$passed" "$failed"
	[[ "$failed" == 0 ]]
}
main "$@"
