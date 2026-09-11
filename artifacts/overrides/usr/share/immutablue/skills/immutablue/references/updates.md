# Updating, Rolling Back, and Rebasing

Read this before updating the OS, undoing an update, or moving between variants.

## Updating

```bash
immutablue update
```

One command covers the bootc image, distrobox containers, system and user
flatpaks, and brew. Which of those it touches is set by the `immutablue.run_*`
keys in `settings.yaml` — see [`configuration.md`](configuration.md).

It takes a `/var` snapshot first (when `immutablue.snapshot_before_update` is on),
holds a lock so two updates cannot overlap, and inhibits sleep and shutdown for
the duration. An OS update is staged and applies at the **next boot**; nothing
changes underneath a running system.

Machine-specific work can be attached to an update without editing
`immutablue-update` (which lives in `/usr`): scripts in
`/etc/immutablue/scripts/user/pre_update/` run before anything is touched, and
`post_update/` runs only after every component succeeded. Run as root to use the
`system/` trees instead. See [`automation.md`](automation.md).

```bash
rpm-ostree status          # what is booted, what is staged, what is the rollback
bootc status
immutablue deployments     # both of the above, together
```

## The three recovery layers

These are complementary, not alternatives, and knowing which applies is most of
the work.

| Layer | Recovers | Command |
|-------|----------|---------|
| Deployment rollback | `/usr` and the deployment's `/etc` | `immutablue rollback` |
| `/var` snapshot | system flatpaks, container storage, logs, machine state | `immutablue restore_snapshot` |
| Rebase | moving to a different variant or version | `immutablue rebase` |

A bad update usually wants the first two together. **`bootc rollback` restores the
image but leaves `/var` exactly as the bad update left it** — so on its own, a
deployment rollback only half-recovers.

### Deployment rollback

```bash
immutablue rollback        # confirms, then stages
systemctl reboot           # you choose when
```

If the machine will not boot at all, hold <kbd>Shift</kbd> during boot for the
GRUB menu and select the previous deployment. That recovers the image without a
running system.

### /var snapshots

```bash
immutablue snapshots           # what exists
immutablue snapshot            # take one now, before something risky
immutablue restore_snapshot    # pick one with fzf
```

Snapshots are btrfs subvolume snapshots taken before each update, retained per
`immutablue.snapshot_keep`. A restore is **staged and applies at the next boot**,
and the previous `/var` is renamed rather than deleted, so the restore itself is
reversible.

Restoring reverts *everything* in `/var`, not just the thing that broke — flatpaks
installed since, container images pulled since, log history. Pick the snapshot
closest to the problem rather than the oldest available.

### Rebasing between variants

```bash
immutablue rebase              # lists tags that actually exist, picks with fzf
immutablue rebase 44-lts       # or name one
```

Tags come from the registry rather than a hardcoded list, so a newly published
variant appears and one that was never pushed does not. Like rollback, this
confirms first and only stages; reboot to apply.

Variants include `-cyan` (NVIDIA), `-lts`, `-trueblue` (ZFS + LTS), `-kuberblue`,
`-nucleus` (headless), `-asahi` (Apple Silicon), `-kinoite`/`-sericea`/other
desktop bases, and `-nix`.

## When an update fails

```bash
immutablue doctor              # start here
immutablue logs_since_boot
rpm-ostree status              # is something layered blocking it?
```

The most common cause of a *blocked* update on an atomic system is a layered
package whose dependencies no longer resolve. `rpm-ostree status` shows the
layered set; removing the offending package unblocks the update. See
[`packages.md`](packages.md) for why layering is a last resort.

If the update applied and the system is worse, roll back the deployment **and**
consider restoring the `/var` snapshot taken just before it.
