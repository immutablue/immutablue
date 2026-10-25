# Rebaseline, verify and commit

Read this for steps 7–9 of the skill: once every guide change is written.

## Record the baseline

All in `artifacts/overrides/usr/share/immutablue/skills/immutablue/SKILL.md`,
in the **same commit** as the guide changes it covers:

1. Set the date in the start marker:
   `<!-- skill-baseline:start — reviewed YYYY-MM-DD; update with the skill, see AGENTS.md -->`.
2. Change a component's line **only if you reviewed it up to that commit**. A
   component reported `same` may be refreshed to the identical hash. A pin you
   did not read keeps its old line — that gap is exactly what the on-machine
   drift check exists to show.
3. Rewrite the paragraph under the block: what this review covered and the
   notable features it added.
4. Update the cmacs commit in the prose under the block (full hash plus the
   review date), and the list of cmacs's own pins that differ from
   immutablue's.

The values to copy, from the repository root:

```bash
git rev-parse HEAD
git submodule status deps/ | awk '{sub(/^[-+U ]/, "", $1); print $2, $1}' | sed 's|^deps/||' | column -t
git -C ../cmacs rev-parse HEAD
git -C ../cmacs submodule status deps/ | awk '{sub(/^[-+U ]/, "", $1); print $2, substr($1, 1, 12)}'
```

The `immutablue` line is the HEAD you reviewed — the commit *before* the skill
update, not the commit that will contain it.

## Verify

From the repository root:

```bash
(
	cd artifacts/overrides/usr/share/immutablue/skills/immutablue
	for f in SKILL.md references/*.md
	do
		d="$(dirname "${f}")"
		grep -o '](\([^)#]*\)\(#[^)]*\)\?)' "${f}" | sed 's/^](//;s/)$//' | while read -r l
		do
			t="${l%%#*}"
			[[ -z "${t}" || "${t}" == http* ]] && continue
			[[ -e "${d}/${t}" ]] || echo "BROKEN ${f} -> ${l}"
		done
	done
)
./tests/test_shellcheck.sh                # when any shell file changed
./tests/test_justfile_syntax.sh           # when any justfile changed
.claude/skills/skill-update-immutable-skill/scripts/drift-report.sh
```

The link loop must print nothing. In the drift report, every component you
reviewed now reads `same` (immutablue reads `CHANGED` by the uncommitted skill
update only until it is committed — that is expected). A skill-only change
needs no image build.

## Commit — only when the user asks

Work on `master` in the main checkout. **No worktrees** in this repository:
worktree submodule gitdirs break `make build`.

`docs/` is a submodule (`immutablue-docs`) and is normally on a detached HEAD.
Commit it first, on its `master`:

```bash
git -C docs fetch origin
git -C docs rev-parse HEAD origin/master   # must be equal; otherwise stop and ask the user
git -C docs checkout -B master origin/master
git -C docs add content/user-guide/agent-skill.md
git -C docs commit -m "docs(agent-skill): list the <guide> guide"
```

Then the parent, including the new submodule pointer and any code fixes:

```bash
git add docs artifacts/overrides/usr/share/immutablue/skills/immutablue <fixed files>
git commit
```

Commit message shape (Conventional Commits, no attribution lines):

```text
docs(skill): review against current deps and cmacs; record new baseline

Rebaseline the /immutablue skill on immutablue <hash>, every deps/
submodule pin and cmacs <hash>, after reading each component's changes
since the previous baseline into the guides.

- <guide>: <what it gained>
- fix stale claims: <list>

fix(<scope>): <one line per code bug fixed in passing>
```

## Push — only when the user asks

Push the docs submodule **before** the parent, so the parent never points at a
docs commit nobody can fetch:

```bash
git -C docs push origin master
git push origin master
```
