# ════════════════════════════════════════════════════════════════════════════
# CRASH CAPTURE - PANIC POLICY, HARDWARE WATCHDOG, CONSOLE DIAGNOSABILITY
# ════════════════════════════════════════════════════════════════════════════
#
# Immutablue ships a conservative baseline on every variant in
#   /usr/lib/sysctl.d/70-immutablue-crash-capture.conf
# and the aggressive unattended policy only on nucleus / kuberblue / trueblue in
#   /usr/lib/sysctl.d/75-immutablue-crash-capture-unattended.conf
#   /etc/systemd/system.conf.d/10-immutablue-watchdog.conf
#
# These recipes let any host opt in or out of that policy at runtime, wire up
# netconsole, unhide the console, and prove the panic path actually works.
#
# Local overrides are written to a 99- prefixed file so they sort AFTER the
# image-provided 70-/75- files and therefore win, rather than being silently
# re-asserted from the image on the next boot.

CRASH_LOCAL_SYSCTL        := "/etc/sysctl.d/99-crash-capture-local.conf"
CRASH_WATCHDOG_DROPIN     := "/etc/systemd/system.conf.d/10-immutablue-watchdog.conf"
CRASH_NETCONSOLE_OPTIONS  := "/etc/modprobe.d/netconsole.conf"
CRASH_NETCONSOLE_AUTOLOAD := "/etc/modules-load.d/netconsole.conf"


# show the current crash-capture posture: sysctls, watchdog, console, pstore
crash_capture_status:
    #!/bin/bash
    # Deliberately no -e: every probe below is allowed to fail on kernels or
    # platforms that lack the knob, and we still want the rest of the report.
    set -uo pipefail

    echo "── kernel panic policy ──────────────────────────────────────"
    for key in kernel.hardlockup_panic kernel.panic_on_unrecovered_nmi \
               kernel.panic_on_oops kernel.panic kernel.softlockup_panic \
               kernel.sysrq
    do
        if value="$(sysctl -n "${key}" 2>/dev/null)"
        then
            printf '  %-32s %s\n' "${key}" "${value}"
        else
            printf '  %-32s %s\n' "${key}" "(not present on this kernel)"
        fi
    done

    echo
    echo "── hardware watchdog ────────────────────────────────────────"
    if compgen -G "/sys/class/watchdog/watchdog*" > /dev/null
    then
        for wd in /sys/class/watchdog/watchdog*
        do
            printf '  %-32s %s (%s)\n' \
                "$(basename "${wd}")" \
                "$(cat "${wd}/state" 2>/dev/null || echo unknown)" \
                "$(cat "${wd}/identity" 2>/dev/null || echo unknown)"
        done
    else
        echo "  no watchdog device present (expected inside a VM)"
    fi
    printf '  %-32s %s\n' "systemd RuntimeWatchdogUSec" \
        "$(systemctl show -p RuntimeWatchdogUSec --value)"

    echo
    echo "── console visibility ───────────────────────────────────────"
    # plymouth's quiet/rhgb suppress the panic trace on the local console, which
    # is how a hard lockup ends up looking like nothing more than a black screen.
    if grep -qE '(^| )(quiet|rhgb)( |$)' /proc/cmdline
    then
        echo "  quiet/rhgb PRESENT -- a panic trace would be hidden by plymouth"
        echo "  fix: immutablue crash_capture_verbose_console"
    else
        echo "  verbose -- a panic trace would print to the console"
    fi

    echo
    echo "── netconsole ───────────────────────────────────────────────"
    if [[ -f "{{CRASH_NETCONSOLE_OPTIONS}}" ]]
    then
        sed -n 's/^options netconsole /  configured: /p' "{{CRASH_NETCONSOLE_OPTIONS}}"
    else
        echo "  not configured"
    fi
    if lsmod | grep -q '^netconsole'
    then
        echo "  module loaded"
    else
        echo "  module not loaded"
    fi

    echo
    echo "── pstore (record left by a previous crash) ─────────────────"
    if [[ -d /sys/fs/pstore ]] && [[ -n "$(sudo ls -A /sys/fs/pstore 2>/dev/null)" ]]
    then
        sudo ls -l /sys/fs/pstore
        echo "  ^ a previous crash persisted a record -- read it before clearing"
    else
        echo "  empty (no persisted record, or no pstore backend on this board)"
    fi


# opt in to the unattended panic policy: oops -> panic, auto-reboot after DELAY
crash_capture_enable_panic_reboot DELAY="30":
    #!/bin/bash
    set -euo pipefail
    source /usr/libexec/immutablue/immutablue-header.sh

    # On a GUI build there is a human in front of the box, and both of these
    # knobs trade away information for uptime. Warn, but do not block.
    if [[ "$(immutablue_build_is_gui)" == "${TRUE}" ]]
    then
        echo "note: this is a GUI build."
        echo "  panic_on_oops=1 turns a recoverable GPU driver oops into a full"
        echo "  machine reboot, and an auto-reboot erases the trace from the"
        echo "  screen before anyone can photograph it. Prefer this only on a"
        echo "  box that runs unattended."
        echo
    fi

    sudo tee "{{CRASH_LOCAL_SYSCTL}}" > /dev/null <<'EOF'
    # Local crash-capture override, written by:
    #   immutablue crash_capture_enable_panic_reboot
    #
    # Sorts after the image-provided 70-/75- files in /usr/lib/sysctl.d, so this
    # is the value that wins. Remove with:
    #   immutablue crash_capture_reset_local
    kernel.panic_on_oops = 1
    kernel.panic = {{DELAY}}
    EOF

    sudo sysctl --system > /dev/null
    echo "enabled: oops -> panic, auto-reboot {{DELAY}}s after a panic"
    echo "wrote {{CRASH_LOCAL_SYSCTL}}"


# opt out of the panic policy, even on a unattended build where the image sets it
crash_capture_disable_panic_reboot:
    #!/bin/bash
    set -euo pipefail

    # Write explicit zeros rather than deleting the file: on nucleus/kuberblue/
    # trueblue the image ships 75-...-unattended.conf, so simply removing the local
    # file would let the image policy re-assert itself on the next boot.
    sudo tee "{{CRASH_LOCAL_SYSCTL}}" > /dev/null <<'EOF'
    # Local crash-capture override, written by:
    #   immutablue crash_capture_disable_panic_reboot
    #
    # Explicit zeros so this beats the image-provided unattended policy in
    # /usr/lib/sysctl.d/75-immutablue-crash-capture-unattended.conf.
    kernel.panic_on_oops = 0
    kernel.panic = 0
    EOF

    sudo sysctl --system > /dev/null
    echo "disabled: kernel will limp on after an oops and hang after a panic"


# drop the local override entirely and fall back to the image's policy
crash_capture_reset_local:
    #!/bin/bash
    set -euo pipefail

    if [[ -f "{{CRASH_LOCAL_SYSCTL}}" ]]
    then
        sudo rm -f "{{CRASH_LOCAL_SYSCTL}}"
        echo "removed {{CRASH_LOCAL_SYSCTL}}"
    else
        echo "{{CRASH_LOCAL_SYSCTL}} not present; already on image policy"
    fi

    # sysctl cannot unset a key, so the running values persist until reboot.
    sudo sysctl --system > /dev/null
    echo "image policy restored on disk; reboot for the running values to match"


# arm the hardware watchdog so a total freeze self-resets after TIMEOUT seconds
crash_capture_enable_watchdog TIMEOUT="60":
    #!/bin/bash
    set -euo pipefail

    if ! compgen -G "/sys/class/watchdog/watchdog*" > /dev/null
    then
        echo "no watchdog device on this host -- nothing to arm."
        echo "  normal inside a VM. On bare metal, check the driver loaded:"
        echo "    sudo dmesg | grep -iE 'sp5100|iTCO|wdat|watchdog'"
        exit 1
    fi

    sudo mkdir -p "$(dirname "{{CRASH_WATCHDOG_DROPIN}}")"
    sudo tee "{{CRASH_WATCHDOG_DROPIN}}" > /dev/null <<'EOF'
    # systemd pets the hardware watchdog every RuntimeWatchdogSec/2. If the
    # kernel wedges so completely that it cannot even panic, the board resets
    # itself instead of hanging until someone presses the physical reset button.
    #
    # This interlocks with kernel.panic: the panic timer fires first whenever the
    # kernel is alive enough to panic, so a trace is captured when that is
    # possible, and the watchdog is only the backstop for a total freeze.
    #
    # RebootWatchdogSec is already systemd's default; kept explicit so the whole
    # policy is readable in one place.
    [Manager]
    RuntimeWatchdogSec={{TIMEOUT}}
    RebootWatchdogSec=10min
    EOF

    # daemon-reexec is what makes PID 1 re-read Manager settings and open
    # /dev/watchdog; daemon-reload is not enough.
    sudo systemctl daemon-reexec

    echo "wrote {{CRASH_WATCHDOG_DROPIN}}"
    echo "state:   $(cat /sys/class/watchdog/watchdog0/state 2>/dev/null || echo unknown)"
    echo "systemd: $(systemctl show -p RuntimeWatchdogUSec --value)"


# disarm the hardware watchdog
crash_capture_disable_watchdog:
    #!/bin/bash
    set -euo pipefail

    if [[ -f "{{CRASH_WATCHDOG_DROPIN}}" ]]
    then
        sudo rm -f "{{CRASH_WATCHDOG_DROPIN}}"
        echo "removed {{CRASH_WATCHDOG_DROPIN}}"
    else
        echo "{{CRASH_WATCHDOG_DROPIN}} not present"
    fi

    sudo systemctl daemon-reexec
    echo "state:   $(cat /sys/class/watchdog/watchdog0/state 2>/dev/null || echo unknown)"
    echo "systemd: $(systemctl show -p RuntimeWatchdogUSec --value)"


# remove quiet/rhgb so a panic trace actually prints to the console
crash_capture_verbose_console:
    #!/bin/bash
    set -euo pipefail

    # --unchanged-exit-77 returns 77 when the kargs already match, which is a
    # success case here, so the exit status is captured before `set -e` sees it.
    exit_status=0
    sudo rpm-ostree kargs \
        --delete-if-present=quiet \
        --delete-if-present=rhgb \
        --unchanged-exit-77 || exit_status=$?

    if [[ ${exit_status} -eq 77 ]]
    then
        echo "console was already verbose; nothing to do"
    elif [[ ${exit_status} -ne 0 ]]
    then
        echo "rpm-ostree kargs failed with status ${exit_status}" >&2
        exit "${exit_status}"
    else
        echo "quiet/rhgb removed. Run 'systemctl reboot' to apply."
        echo "tradeoff: boot is scrolling text instead of the plymouth splash."
    fi


# restore quiet/rhgb (plymouth splash, hidden panic traces)
crash_capture_quiet_console:
    #!/bin/bash
    set -euo pipefail

    exit_status=0
    sudo rpm-ostree kargs \
        --append-if-missing=quiet \
        --append-if-missing=rhgb \
        --unchanged-exit-77 || exit_status=$?

    if [[ ${exit_status} -eq 77 ]]
    then
        echo "console was already quiet; nothing to do"
    elif [[ ${exit_status} -ne 0 ]]
    then
        echo "rpm-ostree kargs failed with status ${exit_status}" >&2
        exit "${exit_status}"
    else
        echo "quiet/rhgb restored. Run 'systemctl reboot' to apply."
    fi


# stream kernel messages to another host as the kernel dies
crash_capture_netconsole TARGET_IP TARGET_PORT="6666" SRC_PORT="6665":
    #!/bin/bash
    set -euo pipefail

    target="{{TARGET_IP}}"

    # Derive the source interface and address from the routing table rather than
    # asking for them: netconsole needs a concrete src-ip/dev pair, and getting
    # it wrong means silent nothing at exactly the moment it matters.
    route="$(ip -o route get "${target}")"
    dev="$(sed -n 's/.* dev \([^ ]*\).*/\1/p' <<< "${route}")"
    src_ip="$(sed -n 's/.* src \([^ ]*\).*/\1/p' <<< "${route}")"

    if [[ -z "${dev}" ]] || [[ -z "${src_ip}" ]]
    then
        echo "could not resolve a route to ${target}" >&2
        exit 1
    fi

    # netconsole transmits raw UDP from inside the dying kernel: there is no ARP
    # resolution at that point, so the destination MAC must be baked in. For an
    # off-link target that is the gateway's MAC, not the target's.
    nexthop="$(sed -n 's/.* via \([^ ]*\).*/\1/p' <<< "${route}")"
    if [[ -z "${nexthop}" ]]
    then
        nexthop="${target}"
    fi

    # Prime the neighbour cache so the lladdr lookup below has something to read.
    ping -c 1 -W 1 "${nexthop}" > /dev/null 2>&1 || true
    mac="$(ip -o neigh show "${nexthop}" | sed -n 's/.* lladdr \([^ ]*\).*/\1/p' | head -1)"

    if [[ -z "${mac}" ]]
    then
        echo "could not resolve the MAC for next hop ${nexthop}" >&2
        echo "  is it reachable? try: ping ${nexthop}" >&2
        exit 1
    fi

    config="{{SRC_PORT}}@${src_ip}/${dev},{{TARGET_PORT}}@${target}/${mac}"

    sudo tee "{{CRASH_NETCONSOLE_OPTIONS}}" > /dev/null <<EOF
    # Written by: immutablue crash_capture_netconsole {{TARGET_IP}}
    # Format: src-port@src-ip/dev,tgt-port@tgt-ip/tgt-mac
    options netconsole netconsole=${config}
    EOF

    echo netconsole | sudo tee "{{CRASH_NETCONSOLE_AUTOLOAD}}" > /dev/null

    # Reload now so the current boot is covered too, not just the next one.
    sudo modprobe -r netconsole 2>/dev/null || true
    sudo modprobe netconsole

    echo "netconsole configured: ${config}"
    echo
    echo "on ${target}, listen with one of:"
    echo "  socat -u UDP-RECV:{{TARGET_PORT}} STDOUT"
    echo "  nc -u -l -p {{TARGET_PORT}}"
    echo
    echo "verify end to end:"
    echo "  echo 'netconsole test' | sudo tee /dev/kmsg"


# stop streaming kernel messages over the network
crash_capture_netconsole_disable:
    #!/bin/bash
    set -euo pipefail

    sudo rm -f "{{CRASH_NETCONSOLE_OPTIONS}}" "{{CRASH_NETCONSOLE_AUTOLOAD}}"
    sudo modprobe -r netconsole 2>/dev/null || true
    echo "netconsole disabled and unloaded"


# DANGER: deliberately crash the machine to prove the panic path works
crash_capture_test_panic:
    #!/bin/bash
    set -euo pipefail

    echo "This will IMMEDIATELY panic the kernel. The machine dies right now."
    echo
    echo "Before continuing:"
    echo "  - stop container stacks cleanly (podman/quadlet, k8s workloads)"
    echo "  - export ZFS pools or accept an unclean import on the way back"
    echo "  - be somewhere you can reach the box if it does NOT come back"
    echo
    echo "Expected: a trace on the console, then an automatic reboot after"
    echo "kernel.panic seconds. Current value: $(sysctl -n kernel.panic)"

    if [[ "$(sysctl -n kernel.panic)" == "0" ]]
    then
        echo
        echo "WARNING: kernel.panic is 0 -- the box will panic and then SIT DEAD"
        echo "until someone presses reset. Run this first if that is not what"
        echo "you want:  immutablue crash_capture_enable_panic_reboot"
    fi

    echo
    read -r -p "Type CONFIRM to crash this machine: " reply
    if [[ "${reply}" != "CONFIRM" ]]
    then
        echo "aborted"
        exit 1
    fi

    # Fedora ships kernel.sysrq=16, which does not include the crash bit (0x40).
    # Nothing restores this if the panic path fails and the box survives, so the
    # value stays permissive until the next reboot -- acceptable for a test that
    # is expected to end in a reboot regardless.
    echo 1 | sudo tee /proc/sys/kernel/sysrq > /dev/null

    sync
    echo "crashing now..."
    echo c | sudo tee /proc/sysrq-trigger > /dev/null
