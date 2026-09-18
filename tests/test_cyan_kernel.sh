#!/bin/bash
# Kernel resolution must never silently select the builder's running kernel.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
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
