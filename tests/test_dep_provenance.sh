#!/bin/bash
# Exercise real git checkouts and metadata merging without building an image.
# SPDX-License-Identifier: AGPL-3.0-or-later
set -euo pipefail
case "${1:-}" in
	-h|--help) echo 'Usage: bash tests/test_dep_provenance.sh'; echo 'Example: bash tests/test_dep_provenance.sh'; exit 0 ;;
	--license) echo 'AGPL-3.0-or-later'; exit 0 ;;
	'') ;;
	*) exit 2 ;;
esac
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." > /dev/null && pwd)"
fixture="$(mktemp -d)"
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/repo/deps/component" "$fixture/bin"
cd "$fixture/repo"
git init -q
# Identity is fixture-local and does not change the user's Git configuration.
git config user.name Test
git config user.email test@example.invalid
git config -f .gitmodules submodule.legacy.path deps/component
git config -f .gitmodules submodule.legacy.url 'https://example.invalid/quoted"repo.git'
git add .gitmodules
git commit -qm 'test: initialize fixture'
# An empty submodule directory must not borrow the parent's HEAD.
if bash "$root/scripts/gen-dep-info.sh" "$fixture/invalid.json"; then
	echo 'FAIL: accepted uninitialized dependency' >&2; exit 1
fi
bash "$root/scripts/gen-dep-info.sh" --image "$fixture/image.json"
image_commit="$(git rev-parse HEAD)"
git -C deps/component init -q
git -C deps/component config user.name Test
git -C deps/component config user.email test@example.invalid
git -C deps/component commit --allow-empty -qm 'test: first dependency version'
first_commit="$(git -C deps/component rev-parse HEAD)"
bash "$root/scripts/gen-dep-info.sh" "$fixture/deps.json"
jq -e --arg commit "$first_commit" '.deps[0].commit == $commit and .deps[0].remote == "https://example.invalid/quoted\"repo.git"' "$fixture/deps.json" > /dev/null
# The current checkout advances, but the saved artifact still contains A.
git -C deps/component commit --allow-empty -qm 'test: second dependency version'
printf 'dirty\n' > deps/component/untracked
bash "$root/scripts/gen-dep-info.sh" "$fixture/new-deps.json"
jq -e '.deps[0].dirty == true' "$fixture/new-deps.json" > /dev/null
digest="sha256:$(printf '%064d' 1)"
bash "$root/scripts/merge-dep-info.sh" "$fixture/image.json" "$fixture/deps.json" "registry/image@$digest" > "$fixture/merged.json"
jq -e --arg dep "$first_commit" --arg image "$image_commit" \
	'.deps[0].commit == $dep and .immutablue.commit == $image and (.dependency_image | contains("@sha256:"))' "$fixture/merged.json" > /dev/null
if bash "$root/scripts/merge-dep-info.sh" "$fixture/image.json" "$fixture/image.json" "registry/image@$digest" > /dev/null; then
	echo 'FAIL: accepted artifact without dependency provenance' >&2; exit 1
fi
# Mock only the registry lookup; digest validation and reference parsing are real.
cat > "$fixture/bin/skopeo" <<'MOCK'
#!/bin/bash
printf '%s\n' "$*" >> "$LOOKUPS"
[[ "${LOOKUP_FAIL:-0}" == 0 ]] || exit 1
printf '%s\n' "$DIGEST"
MOCK
chmod +x "$fixture/bin/skopeo"
export PATH="$fixture/bin:$PATH" DIGEST="$digest" LOOKUPS="$fixture/lookups"
actual="$(bash "$root/scripts/resolve-deps-image.sh" localhost:5000/team/image:44-deps)"
[[ "$actual" == "localhost:5000/team/image@$digest" ]]
[[ "$(bash "$root/scripts/resolve-deps-image.sh" "$actual")" == "$actual" ]]
[[ "$(wc -l < "$LOOKUPS")" == 1 ]]
if LOOKUP_FAIL=1 bash "$root/scripts/resolve-deps-image.sh" registry/image:tag; then
	echo 'FAIL: lookup failure accepted' >&2; exit 1
fi
if DIGEST=invalid bash "$root/scripts/resolve-deps-image.sh" registry/image:tag; then
	echo 'FAIL: invalid digest accepted' >&2; exit 1
fi

# Execute the actual Make recipes with stub engines. A failed resolver must
# stop both build paths before any engine runs, and successful paths must
# receive the resolved digest rather than the mutable input tag.
cp "$root/Makefile" .
cp -a "$root/makefiles" .
mkdir scripts
cp "$root/scripts/resolve-deps-image.sh" scripts/
cat > "$fixture/bin/buildah" <<'MOCK'
#!/bin/bash
printf '%s\n' "$@" >> "$ENGINE_LOG"
MOCK
cp "$fixture/bin/buildah" "$fixture/bin/podman"
cat > "$fixture/bin/sudo" <<'MOCK'
#!/bin/bash
exec "$@"
MOCK
chmod +x "$fixture/bin/"{buildah,podman,sudo}
for mode in 0 1; do
	: > "$fixture/engine"
	env -i PATH="$PATH" LOOKUPS="$LOOKUPS" DIGEST="$DIGEST" ENGINE_LOG="$fixture/engine" \
		make --no-print-directory -s -o pre_test -o deps_manifest -o .containerignore.image \
		build DISTROLESS="$mode" DEPS_IMAGE=localhost:5000/team/image:44-deps
	grep -qx -- "--build-arg=DEPS_IMAGE=localhost:5000/team/image@$digest" "$fixture/engine"
	: > "$fixture/engine"
	if env -i PATH="$PATH" LOOKUPS="$LOOKUPS" DIGEST="$DIGEST" LOOKUP_FAIL=1 ENGINE_LOG="$fixture/engine" \
		make --no-print-directory -s -o pre_test -o deps_manifest -o .containerignore.image \
		build DISTROLESS="$mode"; then
		echo 'FAIL: build continued after registry failure' >&2; exit 1
	fi
	[[ ! -s "$fixture/engine" ]]
done
echo 'PASS: artifact provenance survives source drift and rejects missing metadata'
