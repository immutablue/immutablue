#!/bin/bash
set -euxo pipefail
if [[ -f "${INSTALL_DIR}/build/99-common.sh" ]]; then source "${INSTALL_DIR}/build/99-common.sh"; fi
if [[ -f "./99-common.sh" ]]; then source "./99-common.sh"; fi

# -----------------------------------
# Crash-capture policy for unattended builds.
#
# The conservative half of this policy ships to every variant as a static
# override in /usr/lib/sysctl.d/70-immutablue-crash-capture.conf. Only the
# aggressive half lives here, because it depends on the build options rather
# than on a single flag.
#
# "Unattended" is the axis that matters, NOT "headless". nucleus is the only
# variant without a GUI: TRUEBLUE=1 and KUBERBLUE=1 both append to the default
# gui,silverblue BUILD_OPTIONS, so both ship GNOME. What makes all three
# different from a workstation is that nobody is sitting in front of them to
# read a trace off the console or reach the reset button -- which is exactly
# what turns a hard lockup into an hour of downtime instead of ten seconds.
#
# Runs after 60-services.sh so the service state this script inspects and
# modifies is already settled.
# -----------------------------------

# -----------------------------------
# Distroless builds use a GNOME OS base with a different service and sysctl
# layout; 60-services.sh bails out for the same reason.
# -----------------------------------
if [[ "$(is_option_in_build_options distroless)" == "${TRUE}" ]]
then
    echo "=== Distroless build: skipping crash-capture policy ==="
    exit 0
fi

# -----------------------------------
# There is no single "unattended" build option, so this is the union of the
# three variants that ship to run without a seat in front of them.
# -----------------------------------
UNATTENDED_OPTIONS="nucleus kuberblue trueblue"
IS_UNATTENDED="${FALSE}"

for option in ${UNATTENDED_OPTIONS}
do
    if [[ "$(is_option_in_build_options "${option}")" == "${TRUE}" ]]
    then
        IS_UNATTENDED="${TRUE}"
    fi
done

if [[ "${IS_UNATTENDED}" == "${FALSE}" ]]
then
    echo "=== Attended build: keeping the conservative crash-capture baseline ==="
    echo "A workstation opts in at runtime with:"
    echo "  immutablue crash_capture_enable_panic_reboot"
    echo "  immutablue crash_capture_enable_watchdog"
    exit 0
fi

echo "=== Installing unattended crash-capture policy ==="

# -----------------------------------
# Panic policy.
#
# On a box with nobody in front of it, an unattended reboot beats a dead
# machine: no human will photograph a trace, and downtime lasts until someone
# walks to the reset button.
#
# panic_on_oops is the knob to think twice about here, because trueblue and
# kuberblue have real GPUs running a compositor. An amdgpu/i915 oops that today
# kills the session and leaves services running will instead reboot the host.
# That is still the right trade on a storage or cluster node -- an oops means
# undefined kernel state, and limping on with a pool imported or a kubelet
# mid-write is the worse failure -- but it is a deliberate choice, not a
# side effect of the variant having no display.
# -----------------------------------
mkdir -p /usr/lib/sysctl.d
cat > /usr/lib/sysctl.d/75-immutablue-crash-capture-unattended.conf <<'EOF'
# Immutablue crash-capture policy for unattended builds
# (nucleus, kuberblue, trueblue). Installed by build/65-crash-capture.sh.
#
# The baseline in 70-immutablue-crash-capture.conf applies everywhere and only
# reacts to a machine that is already dead. These two go further and trade
# information for recovery, which is only correct when nobody is watching.
#
# Override on a specific host with /etc/sysctl.d/99-crash-capture-local.conf,
# which sorts after this file and therefore wins:
#   immutablue crash_capture_disable_panic_reboot
kernel.panic_on_oops = 1
kernel.panic = 30
EOF

# -----------------------------------
# Suspend must be impossible before the watchdog is armed.
#
# "Runs 24/7" is an operator intention, not a property the image enforces.
# trueblue and kuberblue ship GNOME, and both GNOME and GDM will idle-suspend a
# machine on their own -- GDM does it sitting at the login screen with nobody
# logged in at all. A suspended host with an armed hardware watchdog is
# board-dependent: watchdog drivers are supposed to stop the counter across S3,
# but a driver missing that hook resets the box on resume.
#
# Masking sleep is independently correct on a ZFS storage box or a cluster node,
# so this is not a workaround -- but it is also a hard precondition for the
# drop-in written below, which is why the two live in one script instead of
# being split across packages.yaml and here where they could drift apart.
# -----------------------------------
SLEEP_TARGETS="sleep.target suspend.target hibernate.target hybrid-sleep.target"

for target in ${SLEEP_TARGETS}
do
    systemctl mask "${target}"
done

# -----------------------------------
# Arm the hardware watchdog (sp5100_tco, iTCO_wdt, wdat_wdt, ...).
#
# systemd pets the timer every RuntimeWatchdogSec/2. If the kernel wedges so
# completely that it cannot even panic -- the fingerprint of the 2026-08-20
# nas-main lockup, where the journal simply stopped mid-line -- the board resets
# itself rather than hanging until someone presses reset.
#
# This interlocks with kernel.panic=30 above: the panic timer fires first
# whenever the kernel is alive enough to panic, so a trace is captured when that
# is possible, and the 60s hardware timer is only the backstop for a total
# freeze. RebootWatchdogSec is already systemd's default; it is stated
# explicitly so the whole policy is readable in one place.
#
# A drop-in, not an edit to /etc/systemd/system.conf: that file is already
# shipped whole in artifacts/overrides and shadows the vendor copy, which is a
# pattern worth shrinking rather than extending.
#
# No-op on a host without a /dev/watchdog (VMs, most containers).
# -----------------------------------
mkdir -p /etc/systemd/system.conf.d
cat > /etc/systemd/system.conf.d/10-immutablue-watchdog.conf <<'EOF'
# Immutablue hardware watchdog policy for unattended builds.
# Installed by build/65-crash-capture.sh, which also masks the sleep targets
# this setting depends on. If suspend is ever unmasked on a host, disarm this:
#   immutablue crash_capture_disable_watchdog
[Manager]
RuntimeWatchdogSec=60
RebootWatchdogSec=10min
EOF

echo "=== Unattended crash-capture policy installed ==="
