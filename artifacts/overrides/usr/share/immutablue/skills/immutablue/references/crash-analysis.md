# Diagnosing a Crash

Read this when a process has dumped core, when asked why a program crashed or
disappeared, or when acting on an Immutablue crash notification.

Work from evidence. The goal is an honest account of what happened, not a
plausible-sounding story.

## Establish the facts

```bash
coredumpctl list                 # is this a one-off or a pattern?
coredumpctl info <pid>           # backtrace, signal, and the command line
```

The **command line** the process was started with is the most underused field
here — it usually reveals what the program was working on when it died, which is
often the whole answer.

`immutablue analyze_crash` collects this into an ephemeral working directory under
`~/.cache/immutablue/crash-analysis/` and opens it in `ai-tui`, so the analysis is
a conversation you can keep asking questions in rather than a single answer. The directory is
yours to write in; it is disposable and is not part of the system.

## Rule out the boring causes first

```bash
free -h
journalctl -k --since "10 minutes ago" | grep -i "oom\|killed process"
```

A process killed by the OOM killer is not a bug in that process. Check resource
exhaustion before blaming code.

## Correlate against the timeline

The crash timestamp is evidence. Compare it against:

- **Filesystem mtimes.** A file or directory whose mtime lands on the same second
  as the crash strongly suggests the trigger.
- **The journal** around that moment, for related warnings from the same or
  neighbouring processes.
- **The deployment.** On an atomic system this is sharper than on a normal
  distro: `rpm-ostree status` gives the exact image the crash happened on, and
  whether it was booted recently. A crash that starts immediately after a
  deployment changed points at that update, and the previous deployment is still
  on disk to test against.

```bash
rpm-ostree status
immutablue deployments
```

## Symbolize

Fedora runs a public debuginfod server:

```bash
core=$(mktemp -t crash-XXXXXX.core)
trap 'rm -f "$core"' EXIT
coredumpctl dump <pid> --output="$core"
DEBUGINFOD_URLS="https://debuginfod.fedoraproject.org" \
  gdb -q <executable> "$core" -batch \
  -ex 'set debuginfod enabled on' -ex 'bt'
```

A core is a verbatim copy of the process's memory and can hold passwords, tokens
and private documents. Write it to a fresh `mktemp` path, never a predictable
shared one, and delete it when done.

### Immutablue's own binaries have no debuginfod coverage

This is the case that matters most here and has no equivalent on a stock distro.
`cmacs`, `gowl`, `gst`, `gsurf`, `bacon` and the GLib libraries are built by
Immutablue from git — no Fedora debuginfo package exists for them, and debuginfod
has never heard of them.

The source is **not** on the machine; it is not worth 1.1 GB in every image for
the rare occasion it is needed. What ships instead is the provenance:

```bash
cat /usr/immutablue/deps/dep_info.json
```

Every component's `remote`, exact `commit`, `describe` and a `dirty` flag. That
is enough to fetch precisely the source the running binary was built from:

```bash
git clone <remote> src/<name>
git -C src/<name> checkout <commit>
```

`immutablue-crash analyze` does this for you when the crashing binary belongs to
one of these components — the clone lands inside the crash-analysis directory,
at the recorded commit, so the frames line up with the source without anyone
choosing a revision.

A `dirty: true` entry is worth reading carefully: the binary was built from a
working tree with uncommitted changes, so no commit describes it exactly and
line numbers may not agree.

## Read the whole core, not just frame 0

Thread stacks other than the crashing one show what work was *in flight* —
thumbnailers, image loaders, IPC readers, GPU queues. That context often explains
the trigger even when the crashing frame cannot be symbolized.

Note any third-party code in the address space: browser or file-manager
extensions, plugins, out-of-tree drivers. In-process third-party code is a common
crash source and worth flagging — but do not pin blame on it without evidence it
is actually implicated.

**gowl bar plugins are the local case of this.** They run in-process inside the
compositor. gowl guards every plugin entry point and quarantines a plugin that
faults, journaling it to `$XDG_STATE_HOME/gowl/bar-plugins.journal`. If the crash
is in or under gowl, read that journal before anything else — see
[`gowl-bar.md`](gowl-bar.md).

## Is it Immutablue's fault?

This is the question worth answering carefully, because the answer is usually no
and a confident wrong answer wastes a maintainer's time.

**Probably Immutablue** when the fault is in something Immutablue decides: a
missing or wrong package in the image, a file shipped in `artifacts/overrides/`, an
`immutablue-*` script, a service Immutablue enables or masks, a variant-specific
breakage, or a binary built from one of the components in `dep_info.json`.

**Probably not Immutablue** when a stock Fedora package crashes doing its own
work, when the same failure would reproduce on plain Silverblue, or when the
trigger is a layered package or a hand-edited `/etc` file. Check:

```bash
rpm -qf <executable>                    # is it a Fedora package or ours?
rpm-ostree status                       # anything layered?
immutablue check_local_etc_overrides    # is this machine stock?
```

`rpm -qf` is the single most useful discriminator. If the binary belongs to a
Fedora package and the machine is stock, the bug is upstream in that package, and
the right destination is Fedora's tracker — not Immutablue's.

If it does turn out to be Immutablue's, read [`reporting.md`](reporting.md) before
offering to file anything.

## Report

1. What crashed, and what it was doing at the time.
2. The most likely mechanism — separating clearly what the evidence **proves**
   from what you are **inferring**.
3. Whether any user data was lost, and where it can be recovered from.
4. Whether it is likely to recur, and what would avoid or fix it.
5. Whose bug it is: this program's, Fedora's, or Immutablue's — and say when you
   cannot tell.

Be straight about the limits of the evidence. If the cause is genuinely ambiguous,
say so rather than assembling confidence out of guesswork.

**Leave the system as you found it.** Diagnosis reads; it does not fix, tidy or
reconfigure. Delete the core you extracted — it is a copy of the crashed process's
memory. Do not disable a service, remove a package or change a setting as part of
"diagnosing", and do not install anything to get a better backtrace without
asking.
