---
name: skill-update-immutable-skill
description: >
  Review the shipped /immutablue agent skill against current immutablue, deps/
  and ../cmacs commits, update its guides, and record the new baseline. Use for
  "update/rebaseline the immutablue skill".
---

# Skill: Update the /immutablue Skill

Immutablue ships an agent skill in the image at
`artifacts/overrides/usr/share/immutablue/skills/immutablue/` (a `SKILL.md`
router plus topic guides in `references/`). Its `skill-baseline` block records
the commit of immutablue and of every `deps/` submodule the guides were last
reviewed against, and the prose under it records the cmacs commit, so an agent
on a machine can tell how far the image and the skill have drifted. This skill
is the procedure for bringing the guides up to date with what those components
gained, correcting what has gone wrong in them, and recording the new commits
honestly. The rules for the baseline block itself are in `AGENTS.md`, section
*The /immutablue agent skill*.

In this file, `SKILL` means
`artifacts/overrides/usr/share/immutablue/skills/immutablue`, and every command
runs from the immutablue repository root unless it says otherwise.

## When to Use

- The user asks to update, review or rebaseline the immutablue skill.
- Submodules under `deps/` or `../cmacs` were bumped with user-facing features
  (new modules, config keys, CLI tools) the skill does not describe.
- A user reports the skill told an agent something wrong about the system.

## Prerequisites

- The immutablue checkout with submodules initialised
  (`git submodule update --init --recursive`) and `../cmacs` checked out beside
  it.
- `git`, `bash` 5, `shellcheck`, `just`, `awk`, `sed`, `column`.
- An agent harness that can run background subagents (optional; the work can
  be done serially).

## Instructions

1. **Update the checkouts**, so the review reads the commits you will record:

   ```bash
   git pull && git submodule update --init --recursive
   git -C ../cmacs pull
   ```

   Do not review against a pin you have not checked out.

2. **Measure the drift.** Run the helper,
   [`scripts/drift-report.sh`](scripts/drift-report.sh) (path from the
   repository root: `.claude/skills/skill-update-immutable-skill/scripts/drift-report.sh`):

   ```bash
   .claude/skills/skill-update-immutable-skill/scripts/drift-report.sh              # one row per component
   .claude/skills/skill-update-immutable-skill/scripts/drift-report.sh --log --docs # plus commits and doc diffs
   ```

   It reads the baseline from `SKILL/SKILL.md`, compares it with the checked-out
   pins and `../cmacs` HEAD, and lists cmacs's own submodule pins. A `same`
   component needs no review. `UNKNOWN BASE` means the clone lacks the old
   commit — fetch it before going on.

3. **Read the skill as it stands.** Read `SKILL/SKILL.md` and its guide list.
   For each `CHANGED` component, read its new and heavily changed doc files in
   full (gowl and cmacs routinely move a hundred commits between reviews), and
   skim the commit log for features the docs do not cover.

4. **Split the work by file ownership**, so no two workers edit one file. If
   the harness has subagents, run the others in the background:

   | Worker | Components | Owns |
   |---|---|---|
   | you | gowl, and cmacs's gowl embedding | `gowl.md`, `gowl-bar.md`, `gowl-macros.md`, `SKILL.md`, `troubleshooting.md` |
   | agent | cmacs, ai-glib, podomation, bacon | `cmacs.md`, `automation.md`, `configuration.md`, `packages.md` |
   | agent | gst, gsurf | `gst.md`, `gsurf.md` |
   | agent | immutablue itself: build, justfiles, variants | `building.md`, `hardware.md`, `recipes.md`, `updates.md`, `reporting.md`, `crash-analysis.md`, `crash-capture.md`, `desktop.md` |

   Each agent prompt must stand alone: the repository path, the skill path,
   its components with exact `base..HEAD` ranges from step 2, the files it owns,
   "verify against source", "do not commit", and "put suggested text for files
   you do not own in your final report". Drop a row whose components are all
   `same`. Fold the agents' suggestions into `SKILL.md` and
   `troubleshooting.md` yourself.

5. **Review against source.** Before writing, read
   [`references/review-traps.md`](references/review-traps.md) — the wrong
   claims past reviews found (`gowl` has no client mode, cmacs does read gowl's
   YAML, cmacs pins its own deps, nothing installs into `/usr`, opt-in modules,
   unreachable justfiles). Verify every flag, key, command, path and function
   name in the component's code, not only its docs. Also re-check the text
   already in each guide you own: a review fixes what is wrong, not only what is
   missing.

6. **Write the guides.**
   - Match the existing style: a short intro, tables, small code blocks, a
     troubleshooting table at the end. Give an agent enough to configure and use
     the feature; point at the installed `deps/<dep>/*.org` for depth, after
     checking the file exists in the cmacs tree.
   - A feature large enough for its own guide gets
     `SKILL/references/<topic>.md`, a line in `SKILL/SKILL.md`'s guide list,
     links from related guides, and a row in the table in
     `docs/content/user-guide/agent-skill.md` (a separate submodule).
   - Guides link each other by bare filename; `SKILL/SKILL.md` links them as
     `references/<guide>.md`.
   - New user-facing features get *Common requests* rows and description
     triggers in `SKILL/SKILL.md`; new failure modes get rows in
     `troubleshooting.md`.
   - If you find a code bug: fix it in the same change when it is trivial and
     obviously intended (a missing `import`, a misspelt option), and scope any
     workaround in the skill to images built from the previous commit or
     earlier. Report anything larger to the user instead.

7. **Record the baseline.** Follow *Record the baseline* in
   [`references/rebaseline-and-commit.md`](references/rebaseline-and-commit.md):
   new review date, changed lines only for components actually reviewed, the
   summary paragraph, and the cmacs commit and its differing pins in the prose.

8. **Verify.** Run the link check, `./tests/test_shellcheck.sh`,
   `./tests/test_justfile_syntax.sh` and the drift report, as listed under
   *Verify* in [`references/rebaseline-and-commit.md`](references/rebaseline-and-commit.md).
   Every relative link must resolve and every reviewed component must read
   `same`.

9. **Report, then commit only when asked.** Give the user the summary described
   in *Output Format*. When the user asks to commit or push, follow *Commit* and
   *Push* in [`references/rebaseline-and-commit.md`](references/rebaseline-and-commit.md):
   the `docs` submodule first on its `master`, then the parent, on `master` in
   the main checkout.

## Output Format

- Edited guides under `SKILL/references/`, and any new guide there, as
  lowercase kebab-case Markdown.
- `SKILL/SKILL.md` with a new review date, updated baseline lines, an updated
  summary paragraph, the new cmacs commit, guide-list entries, *Common
  requests* rows and description triggers.
- `docs/content/user-guide/agent-skill.md` in the `docs` submodule, when the
  guide list changed.
- Any trivial code fixes found along the way.
- A report to the user: the commit recorded for each component, what each guide
  gained, wrong claims corrected, code bugs fixed or found, and upstream doc
  bugs worth raising.

## Examples

### Example: Rebaseline after gowl gains macros and per-device input remapping

**Input:** "Update our immutablue skill for the latest deps and ../cmacs — gowl
got an input remapper and macro support, make sure the skill knows how to
write and configure those."

**Result:** The drift report shows:

```text
immutablue           CHANGED        base=28babfe4d820 head=f549e2dbd19f commits=27
ai-glib              CHANGED        base=093aba30a12a head=6ad8a37557fc commits=95
gowl                 CHANGED        base=5287abbfae25 head=cf647db44e80 commits=113
gsurf                CHANGED        base=f9d2b0bd421e head=722fc8c8701 commits=24
crispy               same           base=53b8fc7c5444 head=53b8fc7c5444 commits=0
cmacs                CHANGED        base=2de411d4d0f9 head=a85f24f7032f commits=101
```

Three background agents take cmacs/ai-glib/podomation/bacon, gst/gsurf, and
immutablue itself. You read gowl's `docs/macros.org`, `docs/input-remap.org`,
`docs/ipc.org` and the `configuration.org` diff, check the API against
`src/macro/gowl-macro.h` and `src/boxed/gowl-input-remap-rule.h`, and write:

- `SKILL/references/gowl-macros.md` — new: writing a macro, the two modes,
  triggers and filters, containment, the remap rule schema, the
  `gowl-msg inputremap-identify` workflow, C config, and the cmacs Elisp for
  both;
- `SKILL/references/gowl.md` — `gowl-msg`, the menu, new rule matchers,
  `rules.d/`, modes, output profiles, `gowl-lock`, `--check-config`;
- fixes to existing text: `gowl bar-*` becomes `gowl-msg bar-*`, and
  `(gowl-reload-config)` is documented as resetting to defaults.

The baseline block becomes `gowl cf647db44e80…` with the date
`reviewed 2026-10-01`, the cmacs prose names `a85f24f7032f…` and its differing
pins, a missing `import "./09-dictation.justfile"` is fixed in passing, and the
user gets the summary. On "commit it", the `docs` submodule is committed on its
`master` first, then the parent.

## Constraints

- Never change a baseline line for a component you did not review up to that
  commit.
- Never document a flag, key, path or function you have not found in source.
- Never tell an agent to write to `/usr`, to `dnf install`, or to self-update a
  shipped binary; the answer on the machine is "update the image".
- Do not commit or push unless the user asks. Never force-push. Do not use a git
  worktree in this repository.
- Do not fix non-trivial code bugs inside a skill update; report them.
- Keep the shipped guides tool-agnostic: they are read by every agent harness.
