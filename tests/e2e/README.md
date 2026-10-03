# End-to-end tests

Scripted scenario tests: each boots the game scene (`src/main.tscn`)
headless, turns on test mode with a seed and an input script, runs ticks and
asserts on the simulation state or its hash. `test_backbone_e2e.gd` is the
pattern; `scripts/` holds the JSON run files. How to write one:
`docs/dev/README.md`, "Simulation and test mode".

Every fixture of the test level must be loaded by a test here (its quoted
name in a `.gd` file or a run file in `scripts/`), or
`tests/unit/test_e2e_fixture_coverage.gd` fails. Which test runs which
fixture: `docs/dev/README.md`, "Chunk 21: end-to-end suite".

The suite also runs inside an exported Linux debug build:
`tools/linux/e2e.sh` exports it and runs this folder in it, through
`tests/export_runner/` (a scene that starts GUT in the exported binary,
where `-s` doesn't exist, or hands over to the game in a child process).
Four editor-only files are left out there; the script lists them.

- `child_game.gd` is a helper, not a test: the engine arguments of a
  child process that runs the game with the same binary (`--path` only in
  the editor). Tests that compare a run's hash across processes use it.
- `test_test_level.gd` loads the test level scene and checks it against its
  design and the level rules (IDs, population, loop, routes back, terrain).
- `test_level_in_game.gd` checks that the game loads the test level in a
  debug build (and not in a release build) and hands its data to the
  simulation.
- `test_slimes_in_game.gd` checks that the game hands the level's terrain
  to the slime bodies: a slime comes to rest on the start basin's floor.
- `test_train_in_game.gd` checks the train on the test level: the first
  slime woken, every size travelling the loop, the split zone at the start.
- `test_train_session_e2e.gd` runs a 15-minute session with no input: the
  first slime laps the loop, is never lost, and the run is repeatable.
- `test_call_e2e.gd` checks taps and the call on the test level: a call on
  the hills pulls the first slime off the loop and it rejoins; a call to the
  tree's high bough gives up after 8 s and heads back directly from the
  ground, by the tree's route back from the platform; a run with taps is
  deterministic.
- `test_camera_e2e.gd` checks the camera on the test level: holding the
  right edge button goes round the loop (section 1, slide 1, the start
  basin), the left one the other way, a call by the tree drags it and it
  comes back to the rails, and a scripted run is repeatable.
- `test_save_e2e.gd` checks saves through the game scene [DoD 28, partly]:
  a scripted run with a call, saved and reloaded by a new game, has the same
  slimes and hash and carries on tick for tick like the run never stopped,
  also across two Godot processes (`--save`, `--load`); a fresh start
  without a save; autosave every interval, on going to the background, off
  in test mode unless asked; an unreadable save or one of another level
  version starts fresh and is never written over.
- `test_fixtures_e2e.gd` loads the test level's fixtures: `bump` has a
  size-3 and a size-2 slime of one species a little apart on the fusion
  dip's floor with the camera on them, `fresh` is the level as new,
  `stress-dense` (chunk 22m) has its 200 train slimes saved on the loop
  line, at most 9 per 300 px stretch of loop but 12 in the two at the
  bowl's bottom, 70 in the bowl, none past switch 3, the camera on the
  bowl, and reloads from a save to the same run; and every fixture in
  `levels/test/fixtures/` loads.
- `test_fixture_scenarios_e2e.gd` (chunk 21) runs a scripted scenario
  from each fixture that only had load-time checks or no same-seed hash
  test, twice on one seed for the same hash: `stress-moving` moves, keeping its mass of 200 in at most
  200 slimes, none above size 3, nothing lost (the wall time per tick is
  printed, a measurement only); `stress-dense` (chunk 22m) the same;
  `midair`'s slimes land and play on;
  `old-version`'s migrated slime travels the loop and nothing is wiped or
  newly lost; from `s1-optout` a tap on the switch empties the basket;
  `stress-still` keeps its 60 in the basket and its pile asleep;
  `s3-basket-59of60` fills basket 3 with the train through the bowl, fires
  it and plays the celebration (about 18 s). About 60 s.
- `test_fusion_e2e.gd` checks fusion and bumping on the Meadow's fusion
  dip [DoD 6]: from `bump` the size 3 and size 2 meet and never fuse in
  10 s; two base slimes put on the dip's rim fuse within 20 s (the dip
  nudges fusion), the run is repeatable and the fused slime hops on; 2 + 2
  and 3 + 1 on the dip meet and keep their sizes.
- `test_session_e2e.gd` checks sessions on the test level [DoD 20, 21,
  22], with test mode's clocks and `skip` steps: only a world tap starts a
  session (not the parent band, not an edge button) and bedtime comes 15
  minutes later; a killed session resumes where it was, in test mode and in
  normal play; from `wind-down` the light goes to dusk, then bedtime puts
  the slimes to sleep, saves, hides the edge buttons and a tap only
  ripples; from `sunrise` the slimes wake into screensaver mode and the next
  tap starts a session; the runs are repeatable, also in a child process.
- `test_frontier_e2e.gd` checks frontier set 1 on the test level, the
  basket on screen [DoD 9, 10, 11, 13, 14]: from `s1-basket-5of6` the
  basket fills, fires, opens gate 1 and lets its slimes go; a full basket
  off screen waits until it comes into view; from `s1-optout` flipping the
  switch back empties the basket (no tilt); once the gate is open the
  switch and the basket do nothing; the celebration plays once and a
  reload doesn't replay it; from `s3-basket-59of60` (chunk 22) the train
  through section 3's bowl brings basket 3's 60th slime, the basket fires
  in view and the celebration plays; the run has the same hash in a child
  process.
- `test_frontier_bedtime_e2e.gd` (chunk 23D, item 23.5) checks baskets at
  bedtime: from `bedtime` a releasing basket 1 lets nothing go until
  sunrise, and its slimes stay in it through sunrise; from
  `s1-basket-5of6` a full basket in view at bedtime plays no reward and
  opens no gate until sunrise; a save taken at bedtime reloads the same;
  the run is repeatable.
- `test_celebration_e2e.gd` (chunk 23D, item 23.11) checks the
  celebration from `stress-still` (woken early): the camera stays put
  through the burst, a tap during it calls, the awake slimes on screen
  hop, and the lasting mark stands at the start of the loop, after a
  reload too, and not on a level whose celebration hasn't played.
- `test_frontier_level.gd` checks the test level's frontier set against
  the level rules: a signpost at every fork, not tappable; the trapdoor on
  the loop over the basket (no tilt needed); the outlet on the onward
  route; the gate on section 2's route and its lid over slide 1's
  entrance; a return route per section; every route back still ends on
  the loop with gate 1 open.
- `test_level_rules.gd` and `test_level_ways_back_e2e.gd` (chunk 16) check
  the level rules over the whole test level, sections 1 to 3: species per
  section, hints seen from the loop, a slide back in every gate state, the
  fusion dips; and, by behaviour, the way back to the train from both ends
  of every row of sleepers (rules 7 and 8).
- `test_level_dod1_e2e.gd` (chunk 16) runs DoD 1 over the whole level: a
  15-minute session with no input from `gate2-open` and from `gate1-open`
  (nothing goes back, no train slime stalls and nothing is lost, every
  slime laps; the same hash in a second run and in a child process), then
  a size-1, size-2 and size-3 slime each lapping the whole loop, with the
  camera left alone and held on the size 3. About 4.5 minutes.
- `test_start_basin_e2e.gd` (chunk 16e) checks the start basin: the slides
  come home behind the loop's start, never along its first stretch; a
  slime coming home doesn't shove the train slimes on the terrace back; a
  size 3 coming home with two base slimes behind it splits and all leave
  the basin; a lone slime of every size passes the first sleeper's ledge
  at its normal pace. About 6 s.
- `test_safety_nets_e2e.gd` (chunk 23A) checks the safety nets on the test
  level: two base slimes of different species put on one centre are stuck,
  and the higher id goes to the start of the loop, logged in the state
  dump; from `wind-down`, over 70 s of bedtime, no bedtime-asleep slime is
  counted as stalled or moved. About 12 s.
- `test_level_selection_e2e.gd` (chunk LD1) checks choosing a level in
  test mode (`"level"`, `--level`) on a throwaway level it writes under
  `levels/zz-selection-*` and removes: it loads, its fixtures resolve in
  its folder, an unknown or broken level is refused and the game kept,
  `"at"` puts the camera on the rails nearest a stable ID or a point, and
  the normal debug game still loads the test level.
- `test_level_checker.gd` (chunk LD1) checks the level-rules checker
  (`tools/level_check/`): each rule it can check fails on a synthetic
  level that breaks it, the test level passes every rule (its rule-22
  break was fixed in chunk R22), and the command line's output and exit
  codes.
- `test_dip2_hollow_e2e.gd` (chunk R22) checks that the second dip's hollow,
  moved over the dip's far slope for rule 22 (b), is still reached by a
  call: a base slime called from the far rim wakes the sleeper nearest it
  (`s2.sleeper.18` since chunk TL1; `.16` before).
- `test_test_level_playable_e2e.gd` (chunk TL1) plays the test level from
  a fresh game by calls alone, base slimes only: section 1 from `fresh`
  until gate 1 opens, section 2 from `gate1-open` until gate 2 opens,
  section 3 from `gate2-open` until basket 3 fires and the celebration
  plays (calls on the sleepers the progress estimate counts on, a tap on
  each switch); and the level-rules checker gives the level no warning.
  About 1.5 minutes.
- `test_new_level_e2e.gd` (chunk LD1) scaffolds throwaway levels with
  `tools/new_level.gd` (1, 2 and 4 sections), checks they load, pass the
  checker and their generated test, appear in test mode, and that the
  scaffolder refuses to overwrite; then removes them. About 40 s.
- `test_level_tools_e2e.gd` (chunk LD1) checks `tools/make_fixture.gd
  --level` on a throwaway level (fresh and gate fixtures that load) and
  `tools/level_report.gd` on the test level.
- `test_bench_pile_rest_e2e.gd` (chunk 22, D131) checks the level
  bench's start: `stress-still` loaded and stepped as
  `tools/bench_level.gd` does, its pile rest detection
  (`tools/bench_level/pile_rest.gd`) finds the pile resting within the
  bench's bound, every member RESTING at the tick found; with too small a
  bound it answers "never".
- `test_bench_rest_e2e.gd` (chunk 22, D107) pins the resting-pile
  measurement of `tools/bench_rest.gd`: a heap of 20 size-1 slimes asleep
  at bedtime on the parade (section 2's flat floor), seed 1, rests as one
  pile between 600 and 2400 ticks (measured: 1329), every member RESTING,
  none parked.
- `levels/test_level_<id>.gd`: each level's own test, written by the
  scaffolder (the level loads, passes the checker, runs 2 minutes with no
  input losing nothing, and its fixtures load).
