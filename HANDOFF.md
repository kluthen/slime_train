# feat/24g: hand-off after part A (2026-10-07), for part B (the geyser object)

Chunk 24g (D159; D160 being written by spec-writer: the user, 2026-10-07, the start's
crowding is not a v1 blocker; the geyser becomes a standalone level object). Worktree
`.claude/worktrees/24g`, branch feat/24g (pushed), based on origin/main 874d24f. Not merged.
Delete this file before the merge.

## Part A: done

The train's climb fix, ported from exp/dip-jam (a3ea22f, variants g and r) as the plain
behaviour, no flags (see docs/dev/README.md "Train" and "Chunk 24g"):

- **Hold on a climb** (`Train.steer`, `SlimeBodies.hold_on_slope`, HOLD_FROM 0.1,
  HOLD_LIFT 0.5): an active train slime standing between hops on an outgoing rise, on the
  route, has its motion down the slope cancelled. Guard added by part A (not in exp): not
  when knocked off the route (it steered from the climb behind and was trapped; found by
  test_new_level_e2e, rule 2 on a 4-section skeleton).
- **The relay** (`Train._relay`, `_behind`, RELAY_DELAY 0.15 s): on a take-off, the train
  slime right behind, within reach, standing on the outgoing route, hops within 0.15 s.
- Probe kept: `tools/dipjam_probe.gd` (no variant flags); `Fusion.fused_count` /
  `bumped_count` debug counters. Tests: `tests/unit/test_train_climb.gd` (11).
- Before the guard the port was exact: stress-dense seed 1 3600 gave exp's g,r hash.
- Full suite at 5b708ef: 1516/1516 native + 126/126 GDScript pass, exit 0. Fixture hashes:
  11 of 18 re-recorded in docs/dev/native.md (both ticks equal).
- Measured (s3-basket-59of60, held camera, seeds 1/2): departures past 750 px 2.5/3.1 ->
  7.6/7.4 per 600 ticks against ~18 arrivals; cluster near the start max 95/89 (limit 20);
  fusions/min 17.0/16.2 -> 8.0/6.9 (unexplained, a risk). stress-dense 16.3 -> 24.3 px/s.

## Part B: the geyser as a level object (not started)

- Read D160 (spec-writer) for what the object is: placed by a level, not part of every
  loop start (D159 §3 said "part of the loop's start in v1"; D160 changes that).
- Code to start from: exp/geyser 8b116e4 (`git diff main...8b116e4`, variant C) and the
  same code applied over g,r on exp/dip-jam's throwaway commit 05e9d15
  (`docs/perf/exp-dipjam-p2/geyser.patch` there; the probe's DJ_GEYSER counters).
  exp/dip-jam's HANDOFF (`git show origin/exp/dip-jam:HANDOFF.md`, last section): with
  g,r the geyser added x750 +1.1 and cut the start's cluster mean 60 -> 50, launched only
  36-38 % of the arrivals (rejects: off the route, under FirstLedge), fus/min 7.7 -> 5.1.
- Atoms: `rule_geyser_spreads_arrivals_at_loop_start` (DRAFT, no code tag yet). Part A's
  code is tagged `req_hopping_behavior`; documentalist may want a dedicated atom for the
  hold and the relay (flagged in part A's report).

## Mechanics (this worktree)

- Native libs copied from the main checkout into `addons/slime_native/bin/` (godot-cpp
  can't build from a worktree: a C++ change goes to the orchestrator).
- Every Godot command under `flock /tmp/slime_train-godot.lock`. Full suite:
  `tools/test.sh -gdisable_colors` (~13 min, two passes). Fixture hashes: for each of the
  18 fixtures, `SLIME_TICK=<native|gdscript> godot --headless --no-header --path . --
  --test-mode --level=test --fixture=<name> --seed=909 --run-ticks=<600|2400>`, the last
  64-hex string of the output.
- train.gd is at 428 effective LOC (CODING_RULE §6 warns over 400): part B should not
  grow it; a geyser belongs in its own file.
