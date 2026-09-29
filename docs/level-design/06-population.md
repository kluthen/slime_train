# 06 Population: sleepers, species, the 200 cap

## What counts

- Every slime starts as the **first slime** (awake, in the start basin) or a
  **sleeper** (asleep, size 1, somewhere off the loop). The population is
  counted in base slimes: first slime + sleepers.
- **At most 200** per level (rule 16). The test level has exactly 200.
- A sleeper belongs to the section its stable ID names (`s2.sleeper.07` is
  section 2's); the first slime counts in section 1.

## Species per section (rule 11)

Section 1 has **exactly 3** species; each later section adds **exactly
one** new species (it may also hold earlier ones); the game has 6 (A to F).
The skeleton uses A, B, C, then D, E, F. A section that adds none, or two,
fails:

```
rule 11  PASS    The first section has 3 native species, and each later section adds one
         note: section 1: A, B, C
         note: section 2 adds D
         note: section 3 adds E
```

## Where they go

- Never on the loop (rule 17): more than 48 px from it.
- The first sleeper within a third of a screen of the first slime (rule 18),
  where the first call and the first-play hint pay off.
- Visible from the loop, or hinted at (rule 9); reachable by calls, without
  tilt (rule 10); on ground that leads back (rule 7); not on a low ledge
  over the loop (rule 22). See [05](05-branches-and-routes-back.md).
- Numbered left to right in their section, from `.01` (rule 20).

## Enough for the baskets

A basket's `quota` is weight: the base slimes the player must have woken by
then. Keep it well under what is available: the level report prints, per
frontier set, the base slimes of the sections so far:

```
set 1 (section 1): switch s1.switch, basket s1.basket, quota 4, opens gate s1.gate; available by then 8 (base slimes of sections 1 to 1)
```

"Available" counts every sleeper, reachable or not: check that enough of
them can really be woken ([10](10-the-level-report.md), reach).

## Check it

```sh
godot --headless --path . -s res://tools/level_report.gd -- --level=zz-tutorial
```

```
== population ==
section     A    B    C    D    E  total
1           3    2    3    -    -      8
2           1    -    -    3    -      4
3           -    1    -    -    3      4
level       4    3    3    3    3     16
base slimes: 16 of at most 200 (rule 16): PASS
species per section (rule 11: section 1 has 3, each later section adds 1): section 1: A, B, C; section 2 adds D; section 3 adds E: PASS
```

Rule 16's other half, big piles staying mostly still, is a MANUAL item.
The checker points to `tools/bench_level.gd`, but today that benchmark
runs the test level only (it takes no `--level`): for your level, play the
crowded spot in test mode and watch that the pile settles (a pile in a
basket rests; see [08](08-fixtures-and-testing.md)).
