#!/bin/bash
# `immutablue rebase` offers only the running backend's bootable images: the
# registry also holds the other backends' images and the build containers.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." > /dev/null && pwd)"
helper="$root/artifacts/overrides/usr/libexec/immutablue/immutablue-rebase-tags"
recipe="$root/artifacts/overrides/usr/libexec/immutablue/just/08-rollback.justfile"
temporary="$(mktemp -d)"
trap 'rm -rf "$temporary"' EXIT

fail () {
    echo "FAIL: $*" >&2
    exit 1
}

# Every tag shape the build produces, and the build containers beside them.
while read -r tag want; do
    got="$(bash "$helper" backend "$tag")"
    [[ "$got" == "$want" ]] || fail "$tag: got $got, want $want"
done <<'EOF'
44 fedora-bootc
44-20261029 fedora-bootc
44-nucleus fedora-bootc
44-cyan-lts fedora-bootc
44-kuberblue-nucleus fedora-bootc
41-build-a-blue-workshop fedora-bootc
arch arch-bootc
arch-20261029 arch-bootc
arch-trueblue arch-bootc
arch-kuberblue-nucleus arch-bootc
15.1-freebsd freebsd-be
15.1-freebsd-20261029 freebsd-be
43-distroless gnomeos
43-distroless-20261029 gnomeos
44-deps none
44-deps-20261029 none
44-cyan-deps-lts none
44-cyan-lts-deps none
arch-deps none
15.1-deps none
42-rpms none
latest none
EOF

printf '%s\n' 44 44-nucleus 44-deps arch arch-trueblue arch-deps 15.1-freebsd 15.1-deps 43-distroless > "$temporary/tags"

[[ "$(bash "$helper" filter arch-bootc < "$temporary/tags" | paste -s -d ' ' -)" == "arch arch-trueblue" ]] || fail 'arch filter'
[[ "$(bash "$helper" filter fedora-bootc < "$temporary/tags" | paste -s -d ' ' -)" == "44 44-nucleus" ]] || fail 'fedora filter'

# The default backend is the machine's; an image without the file is Fedora.
echo freebsd-be > "$temporary/backend"
[[ "$(IMMUTABLUE_BACKEND_FILE="$temporary/backend" bash "$helper" filter < "$temporary/tags")" == "15.1-freebsd" ]] || fail 'current backend filter'
[[ "$(IMMUTABLUE_BACKEND_FILE="$temporary/missing" bash "$helper" current)" == fedora-bootc ]] || fail 'missing backend file'

# The recipe filters the registry list and checks a typed tag.
grep -q 'immutablue-rebase-tags' "$recipe" || fail 'rebase recipe does not use the helper'
grep -q -- '--force' "$recipe" || fail 'rebase recipe has no --force override'

echo 'PASS: rebase offers only this backend'"'"'s bootable images and refuses the others without --force'
