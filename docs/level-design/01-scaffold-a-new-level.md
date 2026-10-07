# 01 Scaffold a new level

One command writes a new level's folder, a skeleton scene that already
follows every rule the checker can verify, its first fixture and its own
test. You never register the level anywhere: the folder is the
registration.

## Choose the ID and the number of sections

- The ID: lowercase letters and digits, words joined by hyphens (`01`,
  `my-level`). Not `test` (the test level's).
- Sections: 1 to 4. Section 1 gets species A, B, C; each later section adds
  one (D, E, F), as rule 11 asks. You can add sections later
  ([03](03-add-a-section.md)), but it is less work to scaffold them now.

## Run the scaffolder

```sh
tools/level.sh new --id=zz-tutorial --sections=2
```

```
new_level: wrote level zz-tutorial (2 sections):
  res://levels/zz-tutorial/level.tscn
  res://levels/zz-tutorial/fixtures/fresh.fixture.json
  res://tests/e2e/levels/test_level_zz-tutorial.gd
Next steps:
  1. Open res://levels/zz-tutorial/level.tscn in the Godot editor and make it your level: ...
  2. Check the level rules:  tools/level.sh check --level=zz-tutorial
     and read its report:    tools/level.sh report --level=zz-tutorial
  3. Run the level's test:   tools/test.sh -gdisable_colors -gselect=test_level_zz-tutorial
  4. Play it:                godot --path . -- --test-mode --level=zz-tutorial --seed=1
```

It refuses, and writes nothing, when the level or its test already exists
(exit 1), or on a bad ID or section count (exit 2):

```
new_level: res://levels/zz-tutorial/ already exists: the scaffolder never overwrites a level. ...
new_level: invalid level ID 'Bad_Id': use lowercase letters and digits, words joined by hyphens (for example 01 or my-level)
new_level: --sections wants a number from 1 to 4 (got '5'): ...
```

## What you get

```
levels/zz-tutorial/
  level.tscn                  the skeleton scene (edit it by hand from now on)
  fixtures/fresh.fixture.json the level as new, for test mode
tests/e2e/levels/
  test_level_zz-tutorial.gd   the level's own test (yours to extend)
```

The next import also writes `test_level_zz-tutorial.gd.uid` next to the
test: commit it with the rest.

The skeleton, per section (3.7 screens each): a dip in the loop with a
hollow on each rim, two sleepers in each hollow; a frontier set (signpost,
switch and trapdoor over the pit basket, quota 4, a pillar, the gate with
its lid over the section's chute; the last section's basket fires the
celebration instead); and the section's return route down its chute and
home along a tunnel to the start basin, which is the test level's (the
pocket, the ramp, the terrace, the first sleeper's ledge, the split zone).

The hollows are the test level's `DipHollow` idiom: a ledge a base slime is
called up to may not hang over the loop where bigger slimes hop (rule 22),
so each hollow hangs over the dip's slope, 110 px above the rim and too
high to hop up to from the slope below it. A called base slime standing on
the rim hops across into it. The sleeper nearer the rim wakes first; the
one deeper in the hollow is in reach once it has gone.

## How the game finds it

`LevelCatalog` (`src/level_catalog.gd`) maps an ID to
`res://levels/<id>/level.tscn` and its fixtures to `res://levels/<id>/fixtures/`,
and lists the levels by scanning `levels/`. Test mode (`--level=<id>`), the
tools (`--level=<id>`) and the test all use it. A normal run of the game
still loads the test level: choosing a level is for test mode and the tools
only.

## Check it at once

```sh
tools/test.sh -gdisable_colors -gselect=test_level_zz-tutorial
tools/level.sh check --level=zz-tutorial
```

The test prints `6/6 passed.` (about 15 s: one of its tests plays section
1 to its basket full, below). The checker ends with
`check_level: 21 PASS, 0 FAIL, 2 MANUAL, 0 N/A, 0 warnings` (rule 19 is
MANUAL: no framing zone yet; rule 23 is always MANUAL, its result is the
level's test, [09](09-check-the-rules.md); rule 5 passes on the dips).

## The skeleton is a start, not a design

The skeleton is playable: every sleeper is in a called base slime's reach,
and the level report's progress section ([10](10-the-level-report.md))
says each section's basket can be filled by then. The level's test proves
section 1 in play: it wakes section 1's sleepers with scripted calls, each
tapped when a train slime stands where the call's hop takes off, then taps
the switch and waits for the basket to fill. Keep that test passing as you
reshape the level; when you move sleepers, the progress estimate and that
test are the first things to look at.

Never run the scaffolder on the level again: from here, the level is edited
by hand ([02](02-edit-in-the-editor.md)). To start over, delete
`levels/<id>/` and `tests/e2e/levels/test_level_<id>.gd` (and its `.uid`)
first.
