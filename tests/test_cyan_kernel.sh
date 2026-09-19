#!/bin/bash
# Kernel resolution must never silently select the builder's running kernel.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." > /dev/null && pwd)"
temporary="$(mktemp -d)"
trap 'rm -rf "$temporary"' EXIT
cat > "$temporary/podman" <<'EOF'
#!/bin/bash
set -euo pipefail
printf '%s\n' "$@" > "$CALL_LOG"
printf '%s\n' "$TEST_KERNEL"
EOF
chmod +x "$temporary/podman"
export PATH="$temporary:$PATH" CALL_LOG="$temporary/call" TEST_KERNEL=7.2.4-200.fc44.x86_64
actual="$(bash "$root/scripts/cyan-kernel-version.sh" example/base:44 linux/amd64)"
[[ "$actual" == "$TEST_KERNEL" ]]
grep -Fxq example/base:44 "$CALL_LOG"
grep -Fxq linux/amd64 "$CALL_LOG"
rm "$CALL_LOG"
[[ "$(bash "$root/scripts/cyan-kernel-version.sh" unused linux/amd64 7.2.5-200.fc44.x86_64 kernel-longterm 44 6.18)" == 7.2.5-200.fc44.x86_64 ]]
[[ ! -e "$CALL_LOG" ]]
for TEST_KERNEL in '' 'not installed' $'7.2.4-200.fc44.x86_64\n7.2.5-200.fc44.x86_64'; do
    export TEST_KERNEL
    if bash "$root/scripts/cyan-kernel-version.sh" example/base:44 linux/amd64 > /dev/null 2>&1; then
        echo 'FAIL: accepted missing or ambiguous kernel' >&2
        exit 1
    fi
done
echo 'PASS: Cyan kernel follows the target base, supports explicit override, and rejects ambiguity'

# LTS routing must not make ordinary Trueblue builds consume a Cyan LTS image.
cd "$root"
check_make() {
    local expected=$1 actual
    shift
    actual=$(env -i PATH="$PATH" make --no-print-directory -s -f - "$@" review-vars <<'MAKE'
include makefiles/00-variables.mk
include makefiles/10-variants-data.mk
include makefiles/20-variants-logic.mk
review-vars:
	@printf '%s %s\n' '$(CYAN_KERNEL_PACKAGE)' '$(CYAN_DEPS_IMAGE)'
MAKE
)
    [[ "$actual" == "$expected" ]] || { echo "FAIL: Cyan routing: $actual"; return 1; }
}
check_make 'kernel-longterm quay.io/immutablue/immutablue:44-cyan-deps' VERSION=44 TRUEBLUE=1
check_make 'kernel-longterm example/review:44-cyan-deps-lts' VERSION=44 TRUEBLUE=1 CYAN=1 IMAGE=example/review
check_make 'kernel-longterm example/custom:tag' VERSION=44 LTS=1 CYAN=1 CYAN_DEPS_IMAGE=example/custom:tag
check_make 'kernel quay.io/immutablue/immutablue:44-cyan-deps' VERSION=44 CYAN=1
export TEST_KERNEL=6.18.1-1.fc44.x86_64
[[ $(bash "$root/scripts/cyan-kernel-version.sh" unused linux/amd64 '' kernel-longterm 44 6.18) == "$TEST_KERNEL" ]]
grep -Fq kwizart/kernel-longterm-6.18 "$CALL_LOG"
echo 'PASS: Cyan LTS resolution and Make image routing'
