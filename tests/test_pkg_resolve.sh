#!/bin/bash
# Resolve logical packages.yaml entries per backend with the production library.
# SPDX-License-Identifier: AGPL-3.0-or-later
set -euo pipefail
case "${1:-}" in
	-h|--help) echo 'Usage: bash tests/test_pkg_resolve.sh'; echo 'Example: bash tests/test_pkg_resolve.sh'; exit 0 ;;
	--license) echo 'AGPL-3.0-or-later'; exit 0 ;;
	'') ;;
	*) exit 2 ;;
esac
root="$(CDPATH='' cd -- "$(dirname "${BASH_SOURCE[0]}")/.." > /dev/null && pwd)"
fixture="$(mktemp -d)"
trap 'rm -rf "$fixture"' EXIT
march="$(uname -m)"

# The fixture covers every entry shape and every way a list is composed.
cat > "$fixture/packages.yaml" <<YAML
immutablue:
  rpm:
    all: [rpm-only, shared-plain]
  pacman:
    all: [pacman-only]
  pkg:
    all:
    - shared-plain
    - {name: renamed, pacman: renamed-arch, freebsd: renamed-bsd}
    - {name: dropped-on-bsd, freebsd: null}
    - {name: split, pacman: [split-a, split-b]}
    - {name: arch-empty, pacman: []}
    44:
    - versioned
  pkg_gui:
    all: [gui-tool]
  pkg_${march}:
    all: [arch-specific]
  pkg_rm:
    all: [{name: unwanted, pacman: unwanted-arch}]
  rpm_rm:
    all: [rpm-unwanted]
  services_enable_sys:
    all:
    - plain.service
    - {name: sshd.service, rc: sshd}
    - {name: systemd-only.service, rc: null}
YAML

# Load the real library against the fixture, without a host header.
resolve () {
	local field="$1" key="$2" options="$3"
	env -i PATH="$PATH" INSTALL_DIR="$fixture" VERSION=44 FEDORA_VERSION=44 \
		IMMUTABLUE_BUILD_OPTIONS="$options" IMMUTABLUE_BACKEND=fedora-bootc \
		bash -c '
			TRUE=1; FALSE=0
			source "$1/build/99-common.sh"
			PACKAGES_YAML="$INSTALL_DIR/packages.yaml"
			get_yaml_array "$2" "$3"
		' _ "$root" "$key" "$field" | paste -sd ' ' -
}

expect () {
	local name="$1" want="$2" got="$3"
	if [[ "$got" != "$want" ]]; then
		echo "FAIL: $name" >&2
		echo "  want: $want" >&2
		echo "  got:  $got" >&2
		exit 1
	fi
}

# Plain names pass through; 'name' is the default; overrides win; null drops;
# lists expand; an empty list installs nothing; suffixes compose.
expect 'rpm resolution' \
	"shared-plain renamed dropped-on-bsd split arch-empty versioned arch-specific gui-tool" \
	"$(resolve rpm .immutablue.pkg gui)"
expect 'pacman resolution' \
	"shared-plain renamed-arch dropped-on-bsd split-a split-b versioned arch-specific gui-tool" \
	"$(resolve pacman .immutablue.pkg gui)"
expect 'freebsd resolution' \
	"shared-plain renamed-bsd split arch-empty versioned arch-specific" \
	"$(resolve freebsd .immutablue.pkg nucleus)"
expect 'service resolution for rc' "plain.service sshd" \
	"$(resolve rc .immutablue.services_enable_sys '')"
expect 'service resolution for systemd' "plain.service sshd.service systemd-only.service" \
	"$(resolve systemd .immutablue.services_enable_sys '')"
expect 'native lists are unaffected' "rpm-only shared-plain" \
	"$(resolve '' .immutablue.rpm '')"

# The backend list is native plus logical, deduplicated in first-seen order.
backend_list () {
	local fn="$1"
	env -i PATH="$PATH" INSTALL_DIR="$fixture" VERSION=44 FEDORA_VERSION=44 \
		IMMUTABLUE_BUILD_OPTIONS=nucleus IMMUTABLUE_BACKEND=fedora-bootc \
		bash -c 'TRUE=1; FALSE=0; source "$1/build/99-common.sh"; PACKAGES_YAML="$INSTALL_DIR/packages.yaml"; "$2"' \
		_ "$root" "$fn" | paste -sd ' ' -
}
expect 'fedora-bootc install list' \
	"rpm-only shared-plain renamed dropped-on-bsd split arch-empty versioned arch-specific" \
	"$(backend_list get_immutablue_packages)"
expect 'fedora-bootc removal list' "rpm-unwanted unwanted" \
	"$(backend_list get_immutablue_packages_to_remove)"

# A typo in an override field ('pacmna') would silently fall back to 'name'
# and install the wrong package, so the real file may only use known fields.
pkg_fields='["name","rpm","pacman","freebsd"]'
bad="$(yq "[.immutablue | to_entries | .[] | select(.key | test(\"^(pkg|build_deps)\")) | .value | .. | select(tag == \"!!map\" and has(\"name\")) | select((keys - $pkg_fields) | length > 0) | .name] | join(\" \")" "$root/packages.yaml")"
expect 'packages.yaml logical entries use only known fields' '' "$bad"
svc_fields='["name","systemd","rc"]'
bad="$(yq "[.immutablue | to_entries | .[] | select(.key | test(\"^services_\")) | .value | .. | select(tag == \"!!map\" and has(\"name\")) | select((keys - $svc_fields) | length > 0) | .name] | join(\" \")" "$root/packages.yaml")"
expect 'packages.yaml service entries use only known fields' '' "$bad"

# Every backend names a package field the logical entries can carry.
for backend_yaml in "$root"/backends/*/backend.yaml; do
	key="$(yq '.pkg_key // ""' "$backend_yaml")"
	case "$key" in
		''|rpm|pacman|freebsd) ;;
		*) echo "FAIL: $backend_yaml pkg_key '$key' is not a logical package field" >&2; exit 1 ;;
	esac
done

echo 'PASS: logical packages resolve per backend, compose by suffix, and use known fields'
