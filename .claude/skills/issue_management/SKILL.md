---
name: issue_management
description: File, update, search and close tracked issues in the repo-root issues/ directory of Slime Train. Use it whenever the user reports something seen while playing (a playtest report on the desktop or the phone), asks to track or investigate a problem, or asks "do we have an issue on X" or "what's left to fix", and whenever you find a bug, a broken determinism or state hash, a performance regression, a save problem, a level that breaks a level-design rule, or a real risk in the code during your work.
---

# Issue management (Slime Train)

Issues record **problems**: something the game does wrong, or a real risk in
the code. They are not the place for decisions or for what to build next:

| What it is | Where it goes | Who keeps it |
|---|---|---|
| A problem seen or found (bug, risk, regression) | `issues/` (this skill) | anyone |
| A question about what the game should do | `specs/open-questions.md` (O-numbers) | spec-writer |
| A settled answer | `specs/decisions.md` (D-numbers) | spec-writer |
| Work to build, in order | `specs/versions/v1/build-plan.md` (chunks) | spec-writer |
| Declared intent | `docs/*.atom.md` | documentalist |

An issue often leads to the others: when the fix needs a product decision,
the issue says so and names the open question once spec-writer has opened
it; when a chunk takes the fix, the issue names the chunk. Never change a
spec, an atom or the build plan from this skill: that goes through their
owners (and, for code, through the intent-gating protocol).

## When to use it

- The **user reports** something from a play session (the main source).
  File it as they describe it, investigate enough to name the cause or the
  lead, and say what is still unknown.
- You find a **bug** or a **silent failure** (no crash, no log, wrong
  behaviour) while working.
- A run's **state hash** changes when nothing should have changed it, or a
  same-seed run doesn't repeat (determinism).
- A **performance** number regresses (measure it: phone numbers come from
  the logcat perf line, never from a screenshot).
- A **save** problem: a load that fails, loses something, or migrates badly.
- A **level** breaks a level-design rule in a way the checker doesn't see.
- A **constraint** the code relies on that nothing enforces.
- The user asks you to track something.

Don't file what is only an idea for a new behaviour with nothing wrong
today: that is an open question for spec-writer. If an expectation of the
user's was never written into the specs, that *is* worth an issue (a spec
gap), with the spec-writer step in its fix.

On an `exp/` branch (experiments are throwaway): file only what also holds
on `main`.

## Words

Use the canonical terms of the **Terminology** table in `specs/concept.md`
(species, switch, split zone, route back, loop's start…), whatever words
the report used. Name level places by their **stable ID**
(`s1.route-back.tree`, `s1.branch.tree`) and decisions, questions, rules
and atoms by their numbers (D46, O62, level rule 23, `req_call_mechanic`).

## Layout

```
issues/
├── README.md                    ← index table, newest first
├── YYYYMMDD_short_slug.md       ← one file per issue
└── ...
```

If `issues/` doesn't exist yet, create it with its `README.md` (header
below) before running the `issues` command: the command stops when it finds
no `issues/` directory.

## Step 1: filename and Ref

- **Filename:** `YYYYMMDD_short_slug.md`. The date is today's, as given in
  the conversation (don't call a tool for it). The slug is lowercase, with
  underscores, 3 to 6 words: the part of the game and the nature of the
  problem (`20261012_parked_free_slimes_lifted_onto_route_back.md`).
- **Ref:** the next `ISS-NNN`, from `issues --next-ref`. Never reuse or skip
  a number.
- **Before filing**, run `issues --search <keyword>` (and grep `issues/`)
  so you don't file a duplicate; update the existing issue instead.

## Step 2: the issue file

Copy `.claude/skills/issue_management/templates/issue.md` and fill every
field.

- `**ID:**` is the filename without `.md`.
- `**Ref:**` is the `ISS-NNN` from Step 1.
- `**Severity:**` one of `Critical` / `High` / `Medium` / `Low` (guide below).
- `**Status:**` starts as `Open`; then `In Progress`, `Resolved` or
  `Wont Fix`.
- `**Component:**` the main file concerned, path from the repo root
  (`src/sim/offscreen.gd`); for a level problem, the level's scene.
- `**Affects:**` what else is involved (other files, levels, fixtures).
- `**Seen on:**` where it was seen: desktop or phone (which), debug or
  release build, native or GDScript tick, level and section or fixture.
- **How to reproduce** is a numbered list of steps (a fixture plus a test
  mode script when there is one). Mark what is guessed.
- **Cause** must say whether it is **confirmed** (read in the code, a test,
  a log) or a **lead**, and point at the lines.
- **Spec and intent** names the D/O numbers, level rules and atoms that
  govern the behaviour, and says whether the code follows the spec (a code
  bug) or the spec itself is wrong or silent (a spec gap, for spec-writer).
- **Recommended fix** has at least a **Short term** entry.

## Step 3: the index

Add a row to `issues/README.md`, newest first:

```markdown
| ISS-NNN | [YYYYMMDD_slug.md](YYYYMMDD_slug.md) | Severity | Status | One-line summary |
```

A new `README.md` starts with:

```markdown
# Issues

Tracked problems in Slime Train. Filed and kept with the `issue_management`
skill (`.claude/skills/issue_management/`). List them with `issues`.

## Index

| Ref | File | Severity | Status | Summary |
|---|---|---|---|---|
```

Then run `issues --update-readme`: it rewrites the `## Open Issues` section
at the end of the root `README.md` with the open and in-progress issues.

## Step 4: tell the user

Give the Ref, the file, the one-line summary, and your severity with its
reason. For example:

> Filed **ISS-001** (High): parked free slimes are lifted onto the route
> back above them. See `issues/20261012_parked_free_slimes_lifted_onto_route_back.md`.

Severity is a proposal: whether an issue blocks a version lock (v1) is the
user's call. Say so when it might.

## Listing and searching

The `issues` command (`~/.local/bin/issues`, outside the repo) reads the
issue files themselves, never the index:

```bash
issues                                  # all issues, newest first
issues --status open                    # open | "in progress" | resolved | "wont fix"
issues --severity high                  # critical | high | medium | low
issues --search "route back"            # title, summary, component, affects, file
issues --status open --severity high    # filters combine
issues --search "call" --full           # whole files
issues --next-ref                       # next ISS-NNN
issues --update-readme                  # refresh the root README's Open Issues table
```

Run it before filing, when the user asks what's open, and at the start of
work on a part of the game (`issues --search offscreen`) to see known
problems there. If the command is missing, read `issues/*.md` directly and
take the next Ref from the highest one there.

## Updating an issue

1. Change the **Status** and the sections that changed.
2. Add a line to the **Change log** at the end:
   `- **YYYY-MM-DD**: what changed and why (commit, D/O number, chunk).`
3. Update the row in `issues/README.md` and run `issues --update-readme`.

## Closing an issue

Set **Status** to `Resolved` (name the commit and the test that now covers
it) or `Wont Fix` (say who decided and why, with the D-number if there is
one). Update the index row, add a last change-log line, run
`issues --update-readme`.

## Severity guide

| Severity | Meaning for Slime Train |
|---|---|
| **Critical** | A crash, a save lost or damaged, a child locked out or let past the parent gate, a session that never ends. Fix now. |
| **High** | Breaks how the game should play, in normal play, and is easy to meet (a slime teleported, a call that misbehaves, the train stuck), or makes a target fail on the reference phone. Fix before the version lock, unless the user says otherwise. |
| **Medium** | Visible but rare, recoverable, or only in test tooling; or a risk not yet met in play. Track it and fix when its area is next worked on. |
| **Low** | Cosmetic, very unlikely, or already well covered. File so it's known. |

## Checklist

```
[ ] issues --search run, no duplicate
[ ] Ref from issues --next-ref, filename YYYYMMDD_slug.md
[ ] File made from the template, every field filled, canonical terms
[ ] How to reproduce as steps; Cause marked confirmed or lead
[ ] Spec and intent filled (code bug or spec gap)
[ ] Short term fix given
[ ] Index row added, issues --update-readme run
[ ] User told: Ref, file, summary, severity and why
```
