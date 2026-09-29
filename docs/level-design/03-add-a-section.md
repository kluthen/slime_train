# 03 Add a section

A section is the part of the level one gate opens. Adding one after the
current last section touches that section too: its basket stops firing the
celebration and opens a new gate instead.

**If the level is still the untouched skeleton,** the quickest correct way
is to start over with one more section: delete `levels/<id>/`,
`tests/e2e/levels/test_level_<id>.gd` and its `.uid`, and run the
scaffolder again with `--sections=N+1` ([01](01-scaffold-a-new-level.md)).

**Borrowing the skeleton's geometry:** scaffold a throwaway level with one
more section (`--id=zz-ref-<yourname> --sections=3`), open it next to
yours, copy the new section's pieces, then delete `levels/zz-ref-<yourname>/`,
its test and the test's `.uid`. Editing as text, compare the two files with
the `unique_id=` attributes stripped: besides the new blocks, the
differences are the changes listed below (the `Bedrock` curve, `gate_id` on
the old last return route, the old last basket's target and outlet, and an
`[ext_resource]` for `gate.tscn` if the file has none). The reference
file's resource ids differ from yours: rename them to your file's.

## What a new section needs

Below, section 2 is the current last section and section 3 the new one.

1. **Ground.** Terrain for section 3 continuing from section 2's end, and
   room underneath for its return route to run home (the skeleton extends
   the `Bedrock` outline, whose top is the tunnel's floor, under the new
   section).
2. **Section 2's frontier set gets a gate.** Add a `Gate`, `s2.gate`, where
   the loop leaves section 2, with its `entrance_lid` over section 2's
   return route entrance (the lid shuts it once the gate is open). Then on
   `s2.basket`: `on_full_object` = `s2.gate` (action `open`), and `outlet`
   back to `onward_route` (clear `outlet_point`).
3. **Section 2's return route names that gate:** on `s2.slide`,
   `gate_id` = `s2.gate`. Opening the gate retires it.
4. **Section 3's loop segments,** under `Loop`, after `s2.slide`:
   - `s3.loop` (`kind` outgoing, `section` 3), starting exactly where
     `s2.loop` ends (segments join within 2 px) and running through the
     gate, left to right;
   - `s3.slide` (`kind` return, `section` 3, no `gate_id` since it's the
     last), from section 3's end down and home to the loop's start,
     arriving **behind** the train (rule 22: it joins the other return
     routes' tail under the terrace and comes up the ramp into the pocket).
5. **Section 3's frontier set** ([04](04-interactive-objects.md)):
   `s3.signpost` (`switch_id` `s3.switch`), `s3.switch` (`basket_id`
   `s3.basket`, its `trapdoor` on the loop over the basket), `s3.basket`
   (its `quota`; as the last section, no target: `on_full_object` empty and
   `outlet` `point`, the celebration fires once every basket has). No gate.
6. **Sleepers** `s3.sleeper.01` onward, numbered left to right, with the
   species section 3 adds (rule 11: section 3 adds E) and any earlier ones
   ([06](06-population.md)), enough of them in a called slime's reach for
   the new basket's quota: the level report's progress line for section 3
   must say "progresses" ([10](10-the-level-report.md)).
7. **Framing zones**, optional: only where the view needs to be wider
   (rule 19), for example to show a basket and its gate together. The
   checker can't tell where one is needed; it's judged by eye in test mode.

## Then

```sh
tools/level.sh check --level=zz-tutorial --fast
tools/level.sh check --level=zz-tutorial
tools/level.sh fixture --level=zz-tutorial
tools/test.sh -gdisable_colors -gselect=test_level_zz-tutorial
```

The checker now reads `note: section 3 adds E` under rule 11, and a lap per
gate state under rule 1:

```
rule 1   PASS    The loop can be travelled with no input at all
         note: with the loop at section 1 (9.2 screens) a size-1 slime lapped it in 106 s
         note: with the loop at section 2 (16.2 screens) a size-1 slime lapped it in 185 s
         note: with the loop at section 3 (23.2 screens) a size-1 slime lapped it in 261 s
```

`make_fixture` rewrites every fixture of the level, the new `gate2-open`
included (`make_fixture: wrote gate2-open`): play section 3 with
`--fixture=gate2-open` ([08](08-fixtures-and-testing.md)).

## If you forgot a step

Forgot `gate_id` on `s2.slide` (the old last return route still closes the
loop at section 3):

```
rule 1   FAIL    The loop can be travelled with no input at all
         - s2.slide (x 0.21): with the loop at section 3 (gates open: s1.gate) the loop ends on s2.slide, not on section 3's return route: add one after its outgoing route
rule 12  FAIL    A frontier gate opens through the switch-plus-basket set
         - s2.slide (x 8.10): section 2's return route names no gate of the level (''): ...
```

Forgot the basket's target:

```
rule 12  FAIL    A frontier gate opens through the switch-plus-basket set
         - s2.gate (x 8.30): no basket's "full" rule opens the gate: set a basket's on_full_object to it
```
