#!/bin/bash
# Run the production package selector against fixture paths and a fake brew.
# The installer uses an absolute brew path; a shell function cannot intercept it.
# SPDX-License-Identifier: AGPL-3.0-or-later
set -euo pipefail
case "${1:-}" in
	-h|--help) echo 'Usage: bash tests/test_brew_variants.sh'; echo 'Example: bash tests/test_brew_variants.sh'; exit 0 ;;
	--license) echo 'AGPL-3.0-or-later'; exit 0 ;;
	'') ;;
	*) exit 2 ;;
esac
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." > /dev/null && pwd)"
fixture="$(mktemp -d)"
trap 'rm -rf "$fixture"' EXIT
[[ -n "${HOME:-}" ]] || { echo 'ERROR: test requires a user home' >&2; exit 1; }
export BREW_TRACE="$fixture/trace" BREW_OPTIONS="$fixture/options"
cat > "$fixture/header.sh" <<'MOCK'
immutablue_get_image_version () { echo 44; }
get_immutablue_build_options () { cat "$BREW_OPTIONS"; }
MOCK
cat > "$fixture/brew" <<'MOCK'
#!/bin/bash
printf '%s\n' "$@" >> "$BREW_TRACE"
MOCK
chmod +x "$fixture/brew"
# Extract the real function, substitute only its three external filesystem
# dependencies, and never source the machine's installed header or packages.
sed -n '/^brew_install_all_from_yaml()/,/^}/p' "$root/scripts/packages.sh" | \
	sed -e "s|/usr/libexec/immutablue/immutablue-header.sh|$fixture/header.sh|g" \
		-e "s|/usr/immutablue/build_options|$fixture/options|g" \
		-e "s|/var/home/linuxbrew/.linuxbrew/bin/brew|$fixture/brew|g" > "$fixture/selector.sh"
# Fail closed if the implementation changes enough that path substitution misses it.
! grep -qE '/(usr|var|home)/' "$fixture/selector.sh"
# shellcheck disable=SC1091
source "$fixture/selector.sh"
cat > "$fixture/packages.yaml" <<'YAML'
immutablue:
  brew:
    install:
      all: [base-package]
      44: [version-package]
    uninstall:
      all: [obsolete-package]
    install_gui:
      all: [gui-package]
    install_kuberblue:
      all: [kubectl]
      44: [cluster-version-package]
    install_trueblue:
      all: [zfs-utils]
YAML
# No variants: both common and versioned packages, plus removals.
brew_install_all_from_yaml "$fixture/packages.yaml"
printf '%s\n' install base-package version-package uninstall obsolete-package > "$fixture/expected"
cmp "$BREW_TRACE" "$fixture/expected"
# Several variants: require every package, rather than accepting base-only output.
: > "$BREW_TRACE"
printf '%s\n' gui kuberblue trueblue > "$BREW_OPTIONS"
brew_install_all_from_yaml "$fixture/packages.yaml"
printf '%s\n' install base-package version-package gui-package kubectl cluster-version-package zfs-utils uninstall obsolete-package > "$fixture/expected"
cmp "$BREW_TRACE" "$fixture/expected"
# Unknown variants contribute nothing and do not suppress base packages.
: > "$BREW_TRACE"
echo nonexistent_variant > "$BREW_OPTIONS"
brew_install_all_from_yaml "$fixture/packages.yaml"
printf '%s\n' install base-package version-package uninstall obsolete-package > "$fixture/expected"
cmp "$BREW_TRACE" "$fixture/expected"
echo 'PASS: brew selection covers versions, variants, removals, and missing keys without host changes'
