#!/bin/bash
# Preserve RPM preset results as immutable vendor dependencies in the extension.
set -euo pipefail
source_units=${1:?Supply the installed system unit configuration directory}
extension=${2:?Supply the extension root}
links=$(mktemp)
trap 'rm -f "$links"' EXIT
find "$source_units" -type l -print0 > "$links"
while IFS= read -r -d '' link; do
    target=$(readlink "$link")
    unit=${target##*/}
    case "$unit" in nvidia-*.service) ;; *) continue ;; esac
    # Exclude fallback/masked/foreign units that this extension does not ship.
    [[ -f "$extension/usr/lib/systemd/system/$unit" ]] || continue
    relative=${link#"$source_units/"}
    case "$relative" in *.wants/*|*.requires/*) ;; *) continue ;; esac
    destination="$extension/usr/lib/systemd/system/$relative"
    mkdir -p "$(dirname "$destination")"
    ln -sfn "/usr/lib/systemd/system/$unit" "$destination"
done < "$links"
