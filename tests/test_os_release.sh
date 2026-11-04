#!/bin/bash
# os-release is derived from the base OS and the build options: the release
# number comes from the base (never a hard-coded one), kuberblue names the
# image, and the variant follows the image tag's naming.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." > /dev/null && pwd)"
temporary="$(mktemp -d)"
trap 'rm -rf "$temporary"' EXIT

fail () {
    echo "FAIL: $*" >&2
    exit 1
}

# A Fedora 45 base, as the base image's /usr/lib/os-release would carry it:
# nothing about 45 is in the repository, so every 45 below came from here.
cat > "$temporary/fedora-base" <<'EOF'
NAME="Fedora Linux"
VERSION="45 (Silverblue)"
ID=fedora
VERSION_ID=45
PLATFORM_ID="platform:f45"
PRETTY_NAME="Fedora Linux 45 (Silverblue)"
CPE_NAME="cpe:/o:fedoraproject:fedora:45"
DEFAULT_HOSTNAME="fedora"
SUPPORT_END=2028-11-13
VARIANT="Silverblue"
VARIANT_ID=silverblue
EOF

# generate <backend> <options> [<base>]: prints the generated file
generate () {
    local out="$temporary/out"

    bash "$root/scripts/os-release.sh" "$root/backends/$1" "$2" "$out" ${3:+"$3"} > /dev/null
    cat "$out"
}

# field <file contents> <KEY>: the unquoted value
field () {
    sed -n "s/^$2=//p" <<< "$1" | tr -d '"'
}

out="$(generate fedora-bootc gui,silverblue "$temporary/fedora-base")"
[[ "$(field "$out" PRETTY_NAME)" == "Immutablue 45 (Silverblue)" ]] || fail "fedora default: $(field "$out" PRETTY_NAME)"
[[ "$(field "$out" ID)" == fedora ]] || fail 'fedora ID must stay fedora (bootc-image-builder, dnf)'
[[ "$(field "$out" PLATFORM_ID)" == "platform:f45" ]] || fail 'base fields must pass through'
[[ "$(field "$out" SUPPORT_END)" == 2028-11-13 ]] || fail 'SUPPORT_END must come from the base'

out="$(generate fedora-bootc nucleus,kuberblue "$temporary/fedora-base")"
[[ "$(field "$out" NAME)" == Kuberblue ]] || fail 'kuberblue NAME'
[[ "$(field "$out" PRETTY_NAME)" == "Kuberblue 45 (Nucleus)" ]] || fail "kuberblue: $(field "$out" PRETTY_NAME)"
[[ "$(field "$out" VARIANT_ID)" == nucleus ]] || fail 'kuberblue VARIANT_ID'
[[ "$(field "$out" DEFAULT_HOSTNAME)" == kuberblue ]] || fail 'kuberblue DEFAULT_HOSTNAME'
grep -q '^VARIANT_ID=nucleus$' <<< "$out" || fail 'VARIANT_ID must be unquoted'

out="$(generate fedora-bootc gui,silverblue,trueblue,lts,zfs "$temporary/fedora-base")"
[[ "$(field "$out" VARIANT)" == "Silverblue, Trueblue" ]] || fail "trueblue implies lts/zfs: $(field "$out" VARIANT)"
[[ "$(field "$out" VARIANT_ID)" == silverblue-trueblue ]] || fail 'trueblue VARIANT_ID'

out="$(generate fedora-bootc gui,silverblue,cyan,lts,zfs "$temporary/fedora-base")"
[[ "$(field "$out" VARIANT)" == "Silverblue, Cyan, LTS" ]] || fail "cyan lts: $(field "$out" VARIANT)"

# The backends' own bases, as shipped.
out="$(generate arch-bootc gui,silverblue,trueblue,lts,zfs)"
[[ "$(field "$out" PRETTY_NAME)" == "Immutablue Arch (GNOME, Trueblue)" ]] || fail "arch: $(field "$out" PRETTY_NAME)"
[[ "$(field "$out" ID_LIKE)" == arch ]] || fail 'arch ID_LIKE'

out="$(generate freebsd-be nucleus)"
[[ "$(field "$out" PRETTY_NAME)" == "Immutablue FreeBSD 15.1 (Nucleus)" ]] || fail "freebsd: $(field "$out" PRETTY_NAME)"

# A derived image brands the same file through the environment.
out="$(OS_RELEASE_NAME="Hyacinth Macaw" OS_RELEASE_URL=https://example.org OS_RELEASE_HOSTNAME=hyacinth-macaw \
    generate fedora-bootc gui,silverblue "$temporary/fedora-base")"
[[ "$(field "$out" PRETTY_NAME)" == "Hyacinth Macaw 45 (Silverblue)" ]] || fail "derived: $(field "$out" PRETTY_NAME)"
[[ "$(field "$out" BUG_REPORT_URL)" == https://example.org ]] || fail 'derived URL'
[[ "$(field "$out" DEFAULT_HOSTNAME)" == hyacinth-macaw ]] || fail 'derived hostname'

# No Fedora release number may be hard-coded in an os-release source again.
if grep -rlE '^(VERSION_ID|PLATFORM_ID)=.*4[0-9]' "$root/artifacts" "$root/backends" --include='*os-release*' 2>/dev/null | grep -q .; then
    fail 'a Fedora release is hard-coded in an os-release file'
fi

echo 'PASS: os-release follows the base release, kuberblue and the variant on every backend'
