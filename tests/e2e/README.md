# End-to-end tests

Scripted scenario tests: each boots the game scene (`src/main.tscn`)
headless, turns on test mode with a seed and an input script, runs ticks and
asserts on the simulation state or its hash. `test_backbone_e2e.gd` is the
pattern; `scripts/` holds the JSON run files. How to write one:
`docs/dev/README.md`, "Simulation and test mode".

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
  dip's floor with the camera on them, `fresh` is the level as new, and
  every fixture in `levels/test/fixtures/` loads.
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
  reload doesn't replay it; the run has the same hash in a child process.
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
