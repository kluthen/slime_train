---
name: level-review
description: Review a Slime Train level against the level-design rules (specs/level-design.md, rules 1 to 22) - run the level-rules checker and the level report, list every rule as written today with its result, turn each FAIL into what, where and how to fix, flag likely blockers the checker can't see, and turn every by-eye item into a checklist of what to look at in test mode. Use this whenever the user asks to review, audit, check, validate or sign off a level, asks "does my level follow the rules", "is level 01 done", "what's wrong with this level", or just wants the level-design rules listed, even without naming the checker.
---

# Level review

Tell a level designer, who may not know the code, where their level stands
against every level-design rule, and what to do next. The checker judges
what code can; the rest becomes a checklist for their eyes. Background:
`docs/level-design/09-check-the-rules.md` and `11-done-checklist.md`.

Use the project's words (Terminology in `specs/concept.md`). Run every
command from the project root. Which level: the one the user names. If they
name none, `ls levels/`: with only `test/` there, review `test`; otherwise
ask.

## The rules come from the spec, every time

Read `specs/level-design.md` at the start of every review and quote rules
from it, by number. Never rely on a remembered or copied rule text: the
rules change. The helper script reads the spec itself, prints its status
line (say which version you reviewed against), and flags a rule the checker
doesn't know. The spec's rules have no titles; the short titles come from
the checker, and the spec's wording wins where they differ.

## Steps

1. **Read** `specs/level-design.md`.

2. **Run the checker in full** (no `--fast`: the laps and ways back are
   part of rules 1, 2 and 7) and merge it with the spec:
   ```sh
   tools/level.sh check --level=<id> --json 2>/dev/null \
     | python3 .claude/skills/level-review/scripts/rules_table.py -
   ```
   The script exits like the checker: 0 no FAIL, 1 a FAIL (or load
   errors), 2 no JSON. It prints every rule of the spec: the checker's
   status and short title, the spec's text, each finding and each warning
   (`WARNING`: may be wrong, a static estimate can't settle it; the status
   stays) with a `look:` and a `re-check:` command, the rule's `by eye:`
   item, and notes.
   - "MANUAL" as a **status** means nothing in the rule is checkable by
     code; `by eye:` items also sit under PASS rules. The checklist covers
     both, so a "0 MANUAL" count can come with ten by-eye items.
   - No JSON: run the checker without `--json` to see why (exit 2: a bad
     level ID or a level that doesn't load). `tools/level.sh` imports the
     project first, so a class added by a pull can't stop it.

3. **Run the level report**:
   `tools/level.sh report --level=<id>`.

4. **Look for likely blockers the checker can't see.** The checker passes
   a level that can't be finished. Work these out:
   - **Each section can progress.** The report's `== progress ==` line per
     basket (and the checker's rule 12 warning when one can't): starting
     from the first slime (its species is in the report's header), what a
     called slime can wake by then, sizes growing as same-species slimes
     fuse, against the quota. "MAY NOT PROGRESS" names the sleepers out of
     reach. Cross-check with `== reach ==` near the start: section 1 needs
     sleepers a size 1 reaches first.
   - **Each quota** leaves room under what can really be woken by then,
     not just "available by then" (every sleeper, reachable or not).
   - **Routes back** near 70 s (left alone at 10 s, lost 60 s later).
   The reach is a static estimate (one hop, no climbing): say "likely" and
   ask to play it.

5. **Write the review** in the format below.

## Review format

```
# Level <id> (version <n>) against specs/level-design.md (<spec status line>)

Checker: <n> PASS, <n> FAIL, <n> MANUAL, <n> N/A, <n> warnings, <full run | fast run>; <n> by-eye items

## Likely blockers
(from step 4; "none found" if so; lead with this when it isn't empty)

## Rules
| Rule | Short title (checker) | Result |
|---|---|---|
| 1 | The loop can be travelled with no input at all | PASS |
... every rule of the spec, in order; "not in this run: check by hand" where so;
"+ by eye" where it has a by-eye item; a load failure as a first row

## To fix (FAIL)
For each finding: what is wrong (plain words), where (stable ID, x in
screens), how to fix it (the finding's own advice, made concrete), and the
script's look and re-check commands. The re-check runs --fast except for
rules 1, 2 and 7, whose behaviour runs --fast skips.

## To look at by eye
A checkbox per by-eye item and per MANUAL rule: what to look at, and where,
with a test-mode command:
  godot --path . -- --test-mode --level=<id> --seed=1 --at=<stable id>
Pick the stable IDs from the level report (branches, frontier sets,
framing zones, sleeper rows; return routes are s<n>.slide). Terrain has no
ID: use --at=<x>,<y> in level pixels (x in screens times 1152; y grows
downward). Section N is reached from --fixture=gate<N-1>-open (section 1:
no fixture). Rule 16's item: `tools/level.sh bench --level=<id>` (the
level as new and each fixture with a save; `--fixture=<name>` for one),
then watch the pile in play.

## Numbers worth a look
From the level report: anything close to a limit.

## Next
The order to work in, with the tutorial page for each (docs/level-design/).
```

Keep it plain. When nothing fails and nothing blocks, say so in one line
and put the by-eye checklist first.

## Known on the test level

The test level passes every rule the checker runs (since chunk R22, which
moved `Terrain/Dip2Hollow` off the loop's path to fix rule 22 (b)), and the
checker exits 0 there. A FAIL on it is news: report it as such.

## Don'ts

- Don't fix the level during a review unless asked (then use the
  `level-content` skill), and never edit `tools/`, `src/` or the spec. A
  rule the checker gets wrong, or a rule of the spec it doesn't know, is a
  finding for the user (a follow-up for the tools, or for spec-writer).
- Don't soften a FAIL or skip a by-eye item because the level "looks fine".
