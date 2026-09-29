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
godot --headless --path . -s res://tools/new_level.gd -- --id=zz-tutorial --sections=2
```

```
new_level: wrote level zz-tutorial (2 sections):
  res://levels/zz-tutorial/level.tscn
  res://levels/zz-tutorial/fixtures/fresh.fixture.json
  res://tests/e2e/levels/test_level_zz-tutorial.gd
Next steps:
  1. Open res://levels/zz-tutorial/level.tscn in the Godot editor and make it your level: ...
  2. Check the level rules:  godot --headless --path . -s res://tools/check_level.gd -- --level=zz-tutorial
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

The skeleton, per section (3.5 screens each): two bumps with two sleepers
each, a frontier set (signpost, switch and trapdoor over the pit basket,
quota 4, a pillar, the gate with its lid over the section's chute; the last
section's basket fires the celebration instead), and the section's return
route down its chute and home along a tunnel to the start basin, which is
the test level's (the pocket, the ramp, the terrace, the first sleeper's
ledge, the split zone).

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
godot --headless --path . -s res://tools/check_level.gd -- --level=zz-tutorial
```

The test prints `4/4 passed.` The checker ends with
`check_level: 20 PASS, 0 FAIL, 1 MANUAL, 1 N/A` (rule 19 is MANUAL: no
framing zone yet; rule 5 is N/A: no dip).

## The skeleton is a start, not a design

The skeleton passes the checker, but it is not yet playable to the end: the
level report ([10](10-the-level-report.md)) says its bump sleepers are
"reachable by a called size 3 hop from the loop" only, and section 1 opens
with the first slime (A) and the first sleeper (B), which can't fuse. Your
first design pass should give section 1 sleepers a base slime can reach
(see [05](05-branches-and-routes-back.md) and rule 22), then play it.

Never run the scaffolder on the level again: from here, the level is edited
by hand ([02](02-edit-in-the-editor.md)). To start over, delete
`levels/<id>/` and `tests/e2e/levels/test_level_<id>.gd` (and its `.uid`)
first.
