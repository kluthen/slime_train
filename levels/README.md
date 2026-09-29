# Levels

One folder per level, holding its Godot scene (`level.tscn`) and its
fixtures (`fixtures/`). Levels are content, not code: they are built in the
editor from `src/components/` (D6), and nothing in a level's folder is a
script. The game and the tools find a level by its folder's name, its ID
(`src/level_catalog.gd`); start a new one with `tools/new_level.gd` (see
`docs/dev/level-tooling.md`).

- `test/`: the test level, for building and for the end-to-end tests. It
  never ships. Its design is in `specs/levels/test/README.md`.
- `01/`: the real first level, added once it is designed.
