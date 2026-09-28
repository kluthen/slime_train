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
