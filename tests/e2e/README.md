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
