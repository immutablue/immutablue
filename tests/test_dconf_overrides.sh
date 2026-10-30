#!/bin/bash
# A backend's dconf keyfile that sets an array key the shared defaults also
# set replaces the shared value (dconf takes the later keyfile's), so it has
# to repeat every shared entry. Today that is freebsd-be's Super+L binding,
# which redefines media-keys' custom-keybindings.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." > /dev/null && pwd)"
shared="$root/artifacts/overrides/etc/dconf/db/local.d/00-immutablue-defaults"

fail () {
    echo "FAIL: $*" >&2
    exit 1
}

# entries <keyfile>: the custom-keybindings paths, one per line
entries () {
    sed -n "s/^custom-keybindings=\[\(.*\)\]$/\1/p" "$1" | tr ',' '\n' | tr -d " '" | grep -v '^$' || true
}

checked=0
for keyfile in "$root"/backends/*/overrides/etc/dconf/db/local.d/*
do
    [[ -f "$keyfile" ]] || continue
    grep -q '^custom-keybindings=' "$keyfile" || continue
    while read -r entry
    do
        [[ -n "$entry" ]] || continue
        entries "$keyfile" | grep -Fxq "$entry" \
            || fail "${keyfile#"$root"/} drops shared custom keybinding $entry"
    done < <(entries "$shared")
    # Every listed binding has its own section.
    while read -r entry
    do
        section="${entry#/}"
        section="${section%/}"
        grep -Fq "[$section]" "$keyfile" "$shared" \
            || fail "${keyfile#"$root"/} lists $entry without a [$section] section"
    done < <(entries "$keyfile")
    checked=$((checked + 1))
done

[[ $checked -gt 0 ]] || fail 'no backend keyfile sets custom-keybindings (freebsd-be lock binding missing?)'
echo "PASS: backend dconf keyfiles keep every shared custom keybinding ($checked checked)"
