# Updating, Rolling Back, and Rebasing

Read this before updating the OS, undoing an update, or moving between variants.

The image update, rollback and rebase go through `immutablue-backend`, which
does them the way this machine's backend does (`immutablue-backend name`):
bootc/rpm-ostree on `fedora-bootc`, bootc on `gnomeos` and `arch-bootc`, ZFS
boot environments (`bectl`) on `freebsd-be`. The `rpm-ostree` commands below
are the fedora-bootc forms; `immutablue-backend status`, `deployments`,
`upgrade`, `rollback` and `rebase <image:tag>` work on every backend. On
`freebsd-be` read *FreeBSD: boot environments*
below first; the GRUB, `systemctl` and btrfs parts of this guide do not apply
there.

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
immutablue deployments     # both of the above, together (immutablue-backend deployments)
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
desktop bases, and `-nix`. Arch images are tagged `arch`, `arch-trueblue`,
`arch-kuberblue-nucleus`, …, FreeBSD ones `15.1-freebsd…`.

**Stay on your backend.** The registry holds every backend's images and the
build containers (`44-deps`, `42-rpms`) together. The picker offers only the
running backend's bootable tags, and a typed tag of another backend is refused
without `--force` — switching an installed system between backends is not
supported, so do not pass it on a user's behalf.
`/usr/libexec/immutablue/immutablue-rebase-tags backend <tag>` says which
backend a tag is. On images built before that check (no such file), the
picker lists every tag: check `cat /usr/immutablue/backend` and pick a tag of
the same family (`arch*` on arch-bootc, a release number on fedora-bootc),
never a `-deps` or `-rpms` one.

NVIDIA and rebasing (details in [`hardware.md`](hardware.md)):

- **Onto 44+ `-cyan`:** nothing to run first. The first boot detects the GPU
  and saves `open`, `580` or `none` to `/etc/immutablue/nvidia.json`.
- **Off `-cyan`:** run `immutablue disable_nvidia_kmod` *before* rebasing; the
  kargs it removes outlive the image.
- **Updates and rollback on cyan** keep the saved choice (it is in `/etc`); each
  deployment brings stacks built for its own kernel. A saved choice is never
  re-detected — after a GPU swap run `immutablue nvidia_setup`.

## FreeBSD: boot environments (freebsd-be)

There is no bootc or ostree. An update is a new ZFS boot environment (BE) made
by `/usr/immutablue/backends/freebsd-be/deliver.sh`, which
`immutablue-backend upgrade` and `rebase` call (and `immutablue update` calls
`upgrade`):

1. **Always pulls** the image (`podman pull`; unchanged layers are not
   re-downloaded). A local copy is used only when the pull fails, e.g. offline —
   it says "pull failed; using the local copy … which may be out of date". Images
   older than immutablue `72326fd` reused the local copy whenever one existed, so
   their upgrades re-delivered the previous image: update once and it fixes
   itself.
2. Clones the running BE as `immutablue-<UTC timestamp>` and lays the image over
   it, keeping `/var` (except `/var/db/pkg`), `/home`, `/root`, `/tmp`, `/compat`
   and the machine's loader settings.
3. Merges `/etc` and `/usr/local/etc` three ways against the stock copies under
   `/usr/share/immutablue/stock/`: untouched files take the new version, locally
   edited ones are kept and logged as `kept local <path>`. `rc.conf` is merged
   key by key; users/groups the image adds are appended.
4. `bectl activate`s the new BE for the next boot. A failure part-way destroys the
   unfinished BE; the running system is never touched.

```bash
sudo immutablue-backend upgrade                 # the tag in image-info.json
sudo immutablue-backend rebase quay.io/immutablue/immutablue:15.1-freebsd-nucleus
sudo /usr/immutablue/backends/freebsd-be/deliver.sh --dry-run <image:tag>   # preview, no BE
immutablue-backend status                       # bectl list: N = now, R = on reboot
sudo immutablue-backend rollback                # bectl activate the BE before the running one
sudo shutdown -r now
```

Run by hand on a terminal, delivery shows progress: `pv` over the image export
("extracting image") and rsync's `--info=progress2` while the BE is written.
Piped or logged runs are silent; that is not a hang. Expect the extraction to
take a while on a GNOME image (~12 GB).

If the new BE does not boot, pick the previous one in the FreeBSD loader's boot
environment menu. Old BEs are never pruned (`immutablue-backend cleanup` only
cleans pkg); remove ones you no longer want with `sudo bectl destroy <name>`.
There is no `/var` snapshot layer (`immutablue-snapshot` is btrfs-only) and
`kargs` is not applicable — loader tunables go in `/boot/loader.conf.local`,
which delivery keeps.

### Podman storage across updates

podman's zfs driver makes each layer a child dataset of the dataset holding
`/var/db/containers`. If that is the BE itself, the next BE is a clone without
those children and every `podman` command fails with
`cannot open '<pool>/ROOT/<BE>/<layer>': dataset does not exist`. Current
machines keep podman storage on its own dataset, `<pool>/containers` (default
pool `zimmutablue`), outside every BE:

```bash
zfs list -o name,mountpoint | grep containers   # expect <pool>/containers  /var/db/containers
```

- **Installed by `install-disk.sh` / the ISO from immutablue `b5341b3` on:**
  created at install.
- **Older machines that can still update:** the first boot of an image that ships
  `rc.d/immutablue_containers` moves the old storage aside to
  `/var/db/containers.pre-dataset-<date>` and creates the dataset. Images and
  containers must be pulled and created again, once.
- **Older machines whose podman is already broken** cannot update their way out,
  because delivery pulls with podman. Do the move once by hand (ask the user
  first — it discards local images), then update:

```bash
sudo mv /var/db/containers /var/db/containers.pre-dataset-$(date -u +%Y%m%dT%H%M%SZ)
sudo zfs create -o mountpoint=/var/db/containers zimmutablue/containers   # <pool>/containers
sudo immutablue-backend upgrade
```

Delete the `.pre-dataset-*` directory once nothing in it is wanted.

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
