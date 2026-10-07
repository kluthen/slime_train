# HANDOFF: item 24.7 (level rule 23), branch feat/24-7

Rotated at the context limit. Brief: the lead's scratchpad `brief-24-7.md`
(read it first, plus build plan item 24.7, level-design.md rule 23, D143,
D144, D161, O107). Delete this file in the last commit.

## Done (checkpoint commit, verified by targeted tests only)

- `tools/level_check/cluster_watch.gd` (`ClusterWatch`): rule 23's measure.
  `watch(sim)` every tick samples `DebugCounts.largest_cluster` every 6
  ticks; keeps `largest`, `ticks_above`, `longest_above`; `passes()` =
  never above `LIMIT` 20 for more than `HOLD_SECONDS` 5 s in a row;
  `fields()` / `report()`. The limit lives here (proposed, O107; tuning.md
  once calibrated, spec edit not ours). Unit test
  `tests/unit/test_cluster_watch.gd` (5/5 green).
- Bench (`tools/bench_level.gd`): RESULT line ends with
  `largest_cluster= above_limit_s= longest_above_s=`; table has 3 more
  columns. Measured (desktop, this branch):
  start 1 / 0.0 / 0.0; stress-moving 133 / 10.0 / 10.0 (the dense train is
  one long cluster: O107's question, yes); s3-basket-59of60 (lead-in 60)
  59 / 9.4 / 5.9.
- Checker: rule 23 added, MANUAL always, loop-free
  (`LevelRulesPlacement.awake_clusters`), rules 1..23 in check_level.gd
  and LevelChecker; `tests/e2e/test_level_checker.gd` updated + a rule-23
  test (37/37 green).
- Test level's played test (`tests/e2e/test_test_level_playable_e2e.gd`):
  watches each section's play and each basket's drain (until weight 0,
  DRAIN_TICKS 120 s), prints `rule 23, ...` lines, no assert. NOT RUN YET.
- Scaffolder template (`tools/new_level/test_level.gd.template`): section
  1's play continues through the fire-and-drain and asserts
  `_clusters.passes()`. NOT RUN YET (`test_new_level_e2e` runs the
  generated test: check it still passes, and copy its real `rule 23` line
  into `docs/level-design/06-population.md`, which shows an illustrative
  one now).
- Docs: `docs/dev/level-tooling.md` (rule 23 section, table row, bench),
  `docs/dev/README.md` (RESULT fields), `docs/level-design/01`, `06`
  (new section "Where slimes gather awake (rule 23)"), `09` (rule 23 line,
  "Rule 23: where its result comes from"), skills `level-review` and
  `new-level`.

## Left

1. **The synthetic test** `tests/e2e/test_rule_23_e2e.gd` (the name is
   already cited in `docs/dev/level-tooling.md`): a synthetic level with
   a bowl feeding a basket fails rule 23 in its played run, the same with
   them apart passes. Tag `# @test-link [[req_level_design_rules]]`.
   Probe so far (`build/probe247.gd`, copy in scratchpad `s247/probe.gd`;
   LevelData built in code like `tests/unit/test_frontier_sets.gd`, a
   floor with a bowl, basket box -900..-600 prefilled with QUOTA IN_BASKET
   slimes, 6 species): with quota 30 the basket's own pile stays awake as
   a 28-30 cluster for the whole minute (fails either way), and with the
   outlet on flat ground the first released slime blocked the outlet
   (weight stuck at 29). So: keep the basket's quota under 20 and make the
   cluster come from the bowl next to it (train slimes queued in a bowl
   beside the basket, touching its pile; apart = the bowl a screen away),
   or another layout that separates clearly. Measure with ClusterWatch.
2. Run the test level's played test, record its numbers (each section's
   play, each basket's drain) plus the bench's default cases and
   `s3-basket-59of60` in `docs/dev/README.md`, a new section "Level rule 23
   on the test level" (the playable test's doc already points there), as
   measured, no verdict (24.3, 24.8 pending; loop start's crowding set
   aside per D161). Refresh 06-population.md's stale bench example
   (`simulated`/`off_screen` names) with a current run.
3. Verify: full suite twice (`tools/test.sh`, redirected to a scratch
   log, under the flock), counts and exit codes; spot-check 3 fixtures'
   hashes unchanged against main (nothing in src/sim/ changed).
4. Delete HANDOFF.md, commit, push feat/24-7; report (<= 15 lines).

## Lock note

Twice the shared lock was held by 24.4's `build/probe_mig.gd`, which hangs
(a SceneTree script that never quits); I killed the hung godot child
(not the agent) both times so the queue could move. Report it.
