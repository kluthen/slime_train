# 09 Check the rules

The level-rules checker goes through every rule of
[`specs/level-design.md`](../../specs/level-design.md), 1 to 22, on your
level's scene, and says what it could check and what is left to you.

```sh
godot --headless --path . -s res://tools/check_level.gd -- --level=zz-tutorial
```

| Option | What it does |
|---|---|
| `--fast` | skips the behaviour runs (the laps of rules 1 and 2, the ways back of rule 7): well under a second. Use it while editing, then run the full check |
| `--rule=N[,M...]` | only those rules (`--rule=9,22`) |
| `--json` | one JSON object instead of the text. Godot prints its banner first: keep the last line (`... --json 2>/dev/null \| tail -n 1`) |

Exit code: 0 no FAIL, 1 a FAIL, 2 it can't run (a bad argument, an unknown
level).

## Reading the result

One line per rule, its status and a short title, then details. The short
titles are the checker's own summaries: the spec's rules have no titles,
and where the wording differs (rule 10's "Tilt is never needed to make
progress or open a gate" against the spec's "Tilt is only for exploration
or fun actions. It is never needed..."), the spec's text is the rule.

- `PASS`: checked by code, nothing wrong.
- `FAIL`: each finding names the thing (a stable ID), its x in screens, and
  what to do.
- `MANUAL`: nothing code can check here; do what the `manual:` line says.
- `N/A`: the rule doesn't apply (the note says why).
- `manual:` under a PASS: the part of the rule code can't judge. **These are
  yours to check by eye**, in test mode.
- `note:` facts worth knowing (lap times, species per section). The lap
  times are measured in the simulation; the level report's are worked out
  from lengths and paces, so they differ a little.

A rule's status can change as the level grows with nothing wrong: rule 19
is MANUAL while the level has no framing zone, and PASS once it has one
(its `manual:` line stays: where a wider view is needed is still yours to
judge).

```
check_level: level zz-tutorial (version 1): 2 sections, 10 base slimes
load     PASS    The level loads
rule 1   PASS    The loop can be travelled with no input at all
         note: with the loop at section 1 (9.2 screens) a size-1 slime lapped it in 108 s
...
rule 5   N/A     A dip in the loop may nudge same-species slimes into fusing
         note: the loop has no dip (a low point at least 80 px below both rims)
...
rule 7   PASS    From anywhere a free slime can reach, gravity leads back toward the loop
         manual: spots a free slime can reach that hold no sleeper (a ledge or bough it is called up to, where it falls) aren't tried: check by eye that the ground there leads back toward the loop
         note: section 1: 5 sleepers' spots tried (both ends of every row), slowest back in 8.2 s
...
rule 19  MANUAL  A framing zone wherever a wider view is needed
         manual: where a wider view is needed (a branch's hint, a basket and its gate, a big pile) is judged by eye
         note: the level has no framing zone
...
check_level: 20 PASS, 0 FAIL, 1 MANUAL, 1 N/A, 4.7 s
```

(The freshly scaffolded skeleton, before any edit.)

## Fixing a FAIL

Read the finding, go to the thing, fix, re-run that rule:

```
rule 22  FAIL    Slimes come home behind the loop's start; no called ledge overhangs the loop
         - s1.sleeper.06 (x 3.08): it rests on Section1/Lookout/Ledge, which overhangs the loop from x 3.03 to 3.20 only 80 px over the loop's ground (a size-3 train slime's hop reaches 130 px), its top 100 px up, within a called base slime's reach (133 px): move the ledge off the loop's path or out of reach, or extend the split zone over it
```

```sh
godot --path . -- --test-mode --level=zz-tutorial --seed=1 --at=s1.sleeper.06
godot --headless --path . -s res://tools/check_level.gd -- --level=zz-tutorial --fast --rule=22
```

Other FAILs met in this tutorial: a duplicated stable ID (rule 20,
[02](02-edit-in-the-editor.md)), a forgotten gate or target when adding a
section (rules 1, 3, 12, 13, [03](03-add-a-section.md)), a decoration in
front of a sleeper (rule 9, [07](07-decoration.md)).

## The test level passes

On `test` (the default level), every rule passes:

```sh
godot --headless --path . -s res://tools/check_level.gd -- --rule=22
```

```
rule 22  PASS    Slimes come home behind the loop's start; no called ledge overhangs the loop
         manual: only terrain holding a sleeper is checked for a low overhang: a ledge a slime is called up to for anything else (a bough, a lookout) is checked by eye
         note: called ledges over the loop inside a split zone (only base slimes pass): s1.sleeper.01
         note: a called ledge: its top at most 133 px over the loop's ground, its underside under 130 px
```

It once failed this rule, a worked example of the fix. The second dip's
hollow (`Terrain/Dip2Hollow`, holding `s2.sleeper.15` and `.16`) sat on the
dip's near rim, 110 px over the loop's flat ground, where a called base
slime could reach it. It was moved over the dip's far slope, where the
ground falls away: its underside is now at least 136 px over the loop
(a size-3 hop clears it), and its floor is 115 px over the far rim a called
slime hops up from. After such a move, check in test mode that a call still
wakes the sleepers (`--at=s2.sleeper.16`): the checker can't tell. If the
test level fails a rule, it is news: report it.

## What the checker doesn't know

It checks the scene, not the fun. It can't say whether a hint reads as
something to explore, whether ground holding no sleeper leads back, whether
tilt is ever needed, where a wider view is needed, or whether a sleeper can
really be woken by a call (the level report's reach is an estimate). Every
`manual:` line is a thing to look at in test mode, with `--at=<stable id>`;
the `level-review` skill turns them into a checklist.

The checker works from the rules as they were when it was written: when
`specs/level-design.md` changes, re-read it (the `level-review` skill lists
every rule from the spec itself and says when the two disagree).
