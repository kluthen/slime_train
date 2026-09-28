# Level components

Reusable, programmed level components (terrain, the loop and its segments,
routes back, exploration branches, the split zone, sleepers, the first slime,
switch, basket, gate, signpost, framing zone), each a scene plus its script,
configured through its properties in the Godot editor. Levels are built from
these; there are no per-level scripts (D6). `level.gd` is the script of every
level scene's root: it builds the stable-ID registry and checks the level at
load. `rule.gd` is the rule format they share.

Each component's properties, the stable IDs and the rule format:
`docs/dev/README.md`, "Levels and components".
