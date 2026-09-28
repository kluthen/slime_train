# End-to-end tests

Scripted scenario tests: each boots the game scene (`src/main.tscn`)
headless, turns on test mode with a seed and an input script, runs ticks and
asserts on the simulation state or its hash. `test_backbone_e2e.gd` is the
pattern; `scripts/` holds the JSON run files. How to write one:
`docs/dev/README.md`, "Simulation and test mode".
