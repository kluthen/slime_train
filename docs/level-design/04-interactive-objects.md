# 04 Place and configure interactive objects

Every object is an existing component from `src/components/`: instantiate
its `.tscn`, place it, set its fields ([02](02-edit-in-the-editor.md)).
Boxes (`size`) are centred on the node's position, in px. The fields and
technical notes are in `docs/dev/README.md`, "The components".

After placing anything: `check_level --fast`, then the full checker
([09](09-check-the-rules.md)).

## The frontier set: signpost, switch, basket, gate

The four work together (rule 12). The skeleton's set is a good pattern:
the signpost just before the switch, the switch on the loop, its trapdoor
over the pit that holds the basket, the gate where the loop leaves the
section.

| Component | Fields | Rules to watch |
|---|---|---|
| `Signpost` (`s1.signpost`) | `switch_id` | 6: one signpost within 200 px of every switch; it isn't tappable, the game draws its arrow the way the switch sends the flow |
| `Switch` (`s1.switch`) | `size` (its box), `basket_id`, `trapdoor` (a box relative to the switch, solid while the flow goes onward, open while flipped) | 1: it goes onward by default. 10: its trapdoor is on the loop, over its basket. 12: one switch per basket. 21: below the parent zone at the rails' framing |
| `Basket` (`s1.basket`) | `size` (where caught slimes rest), `quota` (weight: a size 3 counts 3), `on_full_object` + `on_full_action` (`open`), `outlet` (`onward_route`, `outlet_before` px before the return route's entrance; or `point`, at `outlet_point`) | 12: its "full" rule opens the section's gate. 16: a big pile in it stays still. 21: below the parent zone. Keep `quota` below what's available by then (the level report) |
| `Gate` (`s1.gate`) | `size` (solid while closed), `entrance_lid` (a box relative to the gate, solid once open: it shuts the old return route's entrance) | 12: a basket opens it. 13: the section's return route names it (`gate_id`). 14: exploration on a route its lid shuts needs another way in. 15: inert for good once open |

The last section's basket has no gate: leave `on_full_object` empty and use
`outlet` `point` (the celebration plays once every basket has fired).

## The start

| Component | Fields | Rules to watch |
|---|---|---|
| `SplitZone` (`start.split-zone`) | `size` | 4: the loop's start is inside it. 22: it may reach over a low ledge near the start, where only base slimes pass |
| `FirstSlime` (`start.first-slime`) | `species` | 18: the first sleeper within a third of a screen of it |

## Sleepers

| Component | Fields | Rules to watch |
|---|---|---|
| `Sleeper` (`s1.sleeper.01`) | `species` (A to F) | 17: more than 2 slime radii (48 px) from the loop. 20: numbered from `.01` left to right in its section. 22: not on a ledge a called base slime reaches that overhangs the loop lower than a size 3's hop, outside a split zone. 9, 11, 16: see [06](06-population.md) |

Adding a sleeper between two others means renumbering those to its right
(fine before release; never after, rule 20).

## The loop and the camera

| Component | Fields | Rules to watch |
|---|---|---|
| `Loop` (`start.loop`) | none | its `LoopSegment` children are in loop order |
| `LoopSegment` (`s1.loop`, `s1.slide`) | the curve (in the direction of travel), `section`, `kind` (`outgoing` or `return`), `gate_id` (a return route: the gate that retires it), `show_route` | 1, 3: the loop closes in every gate state. 13: one return route per section. 22: return routes arrive behind the loop's start |
| `FramingZone` (`s1.frame.tree`) | `size`, `zoom` (below 1 shows more: 0.7 is a zoom-out), `offset` (px, negative y is up), `exit_hold` (-1: the default) | 19: it meets the loop, `zoom` in (0, 1]. 21: objects stay below the parent zone in its view too |
| `Terrain` (no ID) | the closed outline, `fill_color`, `outline_color`, `outline_width`, `has_collision` | 7: ground a free slime reaches leads back toward the loop. 22: a ledge holding a sleeper |

Exploration branches and routes back: [05](05-branches-and-routes-back.md).
Decoration: [07](07-decoration.md).

## A new kind of object?

v1 levels use only these components. A new kind of interactive object is
v2 scope: it needs a spec decision first (spec-writer: what it does, which
rules it must meet), then a component in `src/components/` and its
simulation (a coding chunk). Until then, compose it from the existing ones.
