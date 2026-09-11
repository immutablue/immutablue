# Kernel Crash Capture

This is the **kernel** side: hard lockups, oopses, panics. A userspace program
dumping core is a different thing — see [`crash-analysis.md`](crash-analysis.md).

A hard-locked kernel logs nothing: the journal stops mid-line, the screen goes
black, and the box sits dead until someone presses reset. Immutablue's policy
turns that into a panic with a visible trace, and on unattended machines into an
automatic reboot.

## Two tiers, chosen by whether a human is present

| Tier | Variants | What it does |
|------|----------|--------------|
| Baseline | every variant | `hardlockup_panic=1`, `panic_on_unrecovered_nmi=1` — panic only when the kernel is already dead |
| Unattended | nucleus, kuberblue, trueblue | also `panic_on_oops=1`, `panic=30` (auto-reboot), hardware watchdog `RuntimeWatchdogSec=60`, and `sleep`/`suspend`/`hibernate` targets **masked** |

The axis is attendance, not GUI: trueblue and kuberblue ship GNOME and still get
the unattended tier. `softlockup_panic` is never set — ZFS scrubs and heavy
transaction commits trip it legitimately.

`panic_on_oops` is not a workstation default because a GPU driver oops usually
kills one session and nothing else; promoting it to a reboot destroys unsaved
work for no gain. On a storage or cluster node the trade inverts.

## Where it lives

| Path | Tier |
|------|------|
| `/usr/lib/sysctl.d/70-immutablue-crash-capture.conf` | baseline, static in the image |
| `/usr/lib/sysctl.d/75-immutablue-crash-capture-unattended.conf` | written by `build/65-crash-capture.sh` |
| `/etc/systemd/system.conf.d/10-immutablue-watchdog.conf` | unattended |
| `/etc/sysctl.d/99-crash-capture-local.conf` | **host override**, written by the recipes; sorts last and wins |

Defaults are in `/usr/lib/sysctl.d`, not `/etc/sysctl.d`, so a host override in
`/etc` layers cleanly instead of fighting the three-way `/etc` merge. Keys carry a
leading `-` where the kernel may lack them (Asahi), so absence is silent.

## The watchdog / suspend interlock

Never arm the watchdog on a machine that can still sleep. Some watchdog drivers
do not stop the counter across S3, and the board resets on resume. The build
masks the sleep targets *before* writing the watchdog drop-in, in the same script,
so they cannot drift apart — and `immutablue doctor` re-checks the pairing at
runtime, because `immutablue enable_suspend` afterwards would recreate the bad
combination.

## Runtime control

```bash
immutablue crash_capture_status                       # everything, in one screen
```

Opting a workstation **in** (a desktop that never sleeps, a build host):

```bash
sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target
immutablue crash_capture_enable_panic_reboot          # DELAY="30"
immutablue crash_capture_enable_watchdog              # TIMEOUT="60"
```

Use `systemctl mask`, not `immutablue disable_suspend`: on a GNOME-based build
that recipe only changes one user's gsettings, leaving GDM and `systemctl
suspend` able to sleep the box. Only masking satisfies the interlock and only
masking is what `doctor` checks.

Opting an unattended host **out** writes explicit zeros rather than deleting the
file, so the image policy does not reassert itself at the next boot:

```bash
immutablue crash_capture_disable_panic_reboot
immutablue crash_capture_disable_watchdog
immutablue crash_capture_reset_local                  # back to the image's policy entirely
```

## Seeing the trace

A stock install boots with `rhgb quiet`, which hands the console to Plymouth. A
panic still prints — nobody sees it, and a lockup presents as "black screen".

```bash
immutablue crash_capture_verbose_console              # rpm-ostree kargs --delete-if-present
systemctl reboot
immutablue crash_capture_quiet_console                # put the splash back
```

These arguments come from Anaconda, so the image cannot remove them — bootc karg
files only append.

For a headless machine, stream kernel messages off the box as it dies:

```bash
immutablue crash_capture_netconsole 10.0.0.5          # TARGET_PORT="6666" SRC_PORT="6665"
socat -u UDP-RECV:6666 STDOUT                         # on the receiver
echo 'netconsole test' | sudo tee /dev/kmsg           # prove it end to end
```

The recipe bakes the next-hop MAC into `/etc/modprobe.d/netconsole.conf` from the
routing table, because a dying kernel cannot ARP — for an off-link target that is
the gateway's MAC, not the target's.

## Proving it works

```bash
immutablue crash_capture_test_panic
```

This **kills the machine immediately**. It asks for `CONFIRM`, warns if
`kernel.panic` is `0` (that combination panics and then sits dead), and raises
`kernel.sysrq` to `1` first. Stop container stacks and export ZFS pools before
running it, and only where you can reach the reset button.

## Reading the aftermath

After a panic-and-reboot, the evidence is in pstore and the previous boot's journal:

```bash
ls /sys/fs/pstore/
immutablue logs_since_last_boot | tail -200
immutablue crash_capture_status
```

If `doctor` reports the watchdog armed while sleep is unmasked, fix that before
anything else — it is the one combination the policy exists to prevent.
