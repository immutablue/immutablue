#!/bin/bash
# backends/freebsd-be/stages/31-freebsd-ports.sh
#
# Install the packages the deps image rebuilt from ports with Immutablue's
# patches (backend_deps_build_extra, backends/freebsd-be/ports/) over the
# stock ones stage 30 installed, and lock them so a 'pkg upgrade' on a
# machine does not quietly put the unpatched version back.
#
# consolekit2: gdm hands ConsoleKit the session's object path when it
# activates a session after the lock screen accepts a password, and
# ConsoleKit looked sessions up by bare id only ("Invalid session"), so the
# GNOME lock screen could never be unlocked.
set -euxo pipefail
if [[ -f "${INSTALL_DIR}/build/99-common.sh" ]]; then source "${INSTALL_DIR}/build/99-common.sh"; fi
if [[ -f "./99-common.sh" ]]; then source "./99-common.sh"; fi

shopt -s nullglob
pkgs=(/mnt-build-deps/ports/*.pkg)
if [[ ${#pkgs[@]} -eq 0 ]]
then
    echo "No patched ports in the deps image; keeping the stock packages"
    exit 0
fi

for pkg in "${pkgs[@]}"
do
    name="$(pkg query -F "${pkg}" '%n')"
    # Only replace what this variant installed (nucleus has no ConsoleKit).
    if ! pkg info -e "${name}"
    then
        echo "${name} is not installed in this variant; skipping its patched package"
        continue
    fi
    pkg add -f "${pkg}"
    pkg lock -y "${name}"
done
