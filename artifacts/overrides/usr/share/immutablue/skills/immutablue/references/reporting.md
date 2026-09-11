# Reporting an Immutablue Bug

Read this before offering to file anything. Most failures on an Immutablue machine
are upstream bugs in the software that failed, not Immutablue's doing — see
[`crash-analysis.md`](crash-analysis.md) for how to tell.

Issues go to **https://gitlab.com/immutablue/immutablue/-/issues**.

## First: is it actually Immutablue's?

It plausibly is when the fault is in something Immutablue *decides*:

- a package that should be in the image and is not, or the reverse
- a file shipped in `artifacts/overrides/` that is wrong, missing or misplaced
- an `immutablue-*` script or justfile recipe misbehaving
- a service Immutablue enables, disables or masks
- a setting default in `settings.yaml`
- something built from one of the components in `dep_info.json` — but that
  usually belongs upstream in that component's own repository, not here
- a variant-specific breakage (cyan/NVIDIA, trueblue/ZFS, asahi, kuberblue)
- an update, rollback, snapshot or rebase path failing

It is probably **not** Immutablue's when a stock Fedora package crashes doing its
own work, when the same failure reproduces on plain Silverblue, or when the
trigger is a layered package or a hand-made `/etc` change. Say so rather than
filing.

## Gather this before filing

```bash
immutablue sysinfo
cat /usr/share/immutablue/image-info.json    # exact tag and build date
rpm-ostree status                            # deployment + anything layered
immutablue doctor_json                       # structured health state
immutablue check_local_etc_overrides         # how far this machine diverges
cat /usr/immutablue/deps/dep_info.json       # exact commit of every component
```

The last two matter more than they look. `doctor_json` gives a maintainer machine
state without a round trip, and `check_local_etc_overrides` answers the first
question any maintainer of an image-based OS asks: *is this a stock image, or has
this machine been modified?*

For a crash, add what [`crash-analysis.md`](crash-analysis.md) produced — the
backtrace, the signal, and the correlation work. For an update failure, the
`immutablue-update` transcript.

## What a good report contains

1. **The exact image tag**, from `image-info.json` — not "the latest".
2. **The variant**, and whether the machine is x86_64 or aarch64.
3. **What you expected and what happened**, separated.
4. **Whether the machine is stock**, per `check_local_etc_overrides` and the
   layered package list.
5. **A reproduction**, or an honest statement that you cannot reproduce it.
6. **What you already ruled out** — this is what saves the maintainer the most
   time, and it is the part most reports omit.

Be explicit about the boundary between what the evidence proves and what you are
inferring. A report that says "this is a bug in X" on a hunch costs more than one
that says "X crashed here, I could not determine why, here is everything I have".

## Do not file without asking

Filing is a public, outward-facing action. Prepare the report, show it to the
user, and let them file it — or ask explicitly before doing it for them. Never
open an issue as a side effect of a diagnosis.
