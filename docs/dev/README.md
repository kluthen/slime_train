# Developer notes

How the Godot project is laid out, how to run the tests, and the technical
choices made while building v1, with their reasons. Business behaviour is in
`specs/`; this document only covers the technical side.

## Requirements

- Godot 4.7.2 on the `PATH` as `godot`. `tools/test.sh` uses another binary
  if you set `GODOT`, for example `GODOT=/opt/godot/godot tools/test.sh`.

## Running the tests

```sh
tools/test.sh
```

This runs the whole suite headless and exits with code 0 when every test
passes, and non-zero when any test fails or the suite couldn't run. Extra
arguments go to GUT:

```sh
tools/test.sh -gselect=test_smoke        # scripts whose name contains it
tools/test.sh -gunit_test_name=runner    # tests whose name contains it
tools/test.sh -gdisable_colors           # plain output, for logs
```

The tests can also be run from the GUT panel in the editor (the plugin is
enabled in `project.godot`).

Writing a test: add a `test_*.gd` script under `tests/unit/` (or
`tests/e2e/`) that `extends GutTest`, with `test_*` methods. See the
[GUT documentation](https://gut.readthedocs.io).

Running the project headless: `godot --headless` starts the main scene,
`src/main.tscn`, the game root. It runs the simulation at its fixed step. A
debug build also loads the test level's greybox (see "Levels and
components"); run it in a window with `godot --path . src/main.tscn`.

## Layout

| Path | What it holds |
|---|---|
| `src/main.tscn` | The main scene, the game root: owns the simulation and drives its fixed step |
| `src/sim/` | The simulation core: pure logic, with no scene dependencies, so it can be unit tested |
| `src/test_mode_guard.gd` | The one check that keeps test mode out of release builds |
| `src/test_mode/` | Test mode: scripted input, time control, the fixture stub, the on-screen marker |
| `src/taps/` | Tap feedback drawing (`TapFeedback`: the ripples and the slimes' eye dots); the tap logic itself is in `src/sim/` (see "Taps and the call") |
| `src/slimes/` | Slime drawing (`SlimeRenderer` and its shaders), the terrain hand-off to the simulation (`SlimeWorld`) and the slime demo scene |
| `src/components/` | Reusable level components, configured in the editor (see "Levels and components") |
| `levels/<id>/` | One folder per level, with its scenes. `levels/test/level.tscn` is the test level |
| `tests/unit/` | Unit tests, mostly on `src/sim/` |
| `tests/e2e/` | End-to-end tests: boot the game scene headless and drive it through test mode |
| `tests/e2e/scripts/` | Test-mode run files (JSON) used by the end-to-end tests |
| `tests/gut_post_run.gd` | The GUT hook that makes a broken suite fail (see below) |
| `tools/test.sh` | The one entry point for the test suite |
| `tools/greybox_test_level.gd` | Generates the test level's greybox scene (see "Levels and components") |
| `tools/bench_slimes.gd` | Times the slime tick (see "Slimes") |
| `docs/dev/img/` | Screenshots used by these notes (`docs/.gdignore` keeps Godot from importing anything under `docs/`) |
| `spikes/` | Throwaway prototypes. Nothing else depends on them |
| `export_presets.cfg` | The Android export presets (see "Android export (debug)"); `build/` (gitignored) receives the APKs |
| `addons/gut/` | The GUT test framework, vendored |

Dependencies go one way: levels use components, components use the
simulation core, and the core uses nothing but plain GDScript. Levels sit at
the root rather than in `src/` because they are content, not code (D6).

## Simulation and test mode

### The fixed step

The simulation (`src/sim/simulation.gd`, class `Simulation`) runs at a fixed
**60 ticks per second** (`Simulation.TICK_RATE`). One `step()` is one tick.
The game root (`src/main.gd`) turns frame time into whole ticks with
`FixedStep` (`src/sim/fixed_step.gd`) in `_process`, so the game advances by
elapsed time, never by frame count: 30, 60 or 144 frames per second give the
same ticks. After a hitch a frame runs at most 8 ticks (times the time
scale); the rest is dropped, so the game slows down instead of spiralling.

Durations in `specs/tuning.md` become tick counts at 60 per second (3 s of
contact is 180 ticks). The fixed step is our own accumulator in `_process`,
not Godot's physics tick: the slimes are our own code, and this keeps time
scaling and skipping in one place.

### State

`Simulation` holds the whole game state: the tick, the master `Rng`, the
slimes (`SlimeBodies`), the train (`Train`: each train slime's progress
along the loop, see "Train"), the level's split zones, the free slimes and
the last call (`FreeSlimes`), the view, the ripples, the last 16 taps, the
slimes' facings (see "Taps and the call"), and a record of the input
received (the fingers down, the finger whose touch counts, the last tilt,
the last 64 input events). Each later chunk adds
its state there and **must add it to `dump()`**, or the state hash won't see
it.

### Input

Real touches (and the left mouse button on desktop) and test-mode input all
become the same simulation input events: `Simulation.touch_down(finger,
at)`, `touch_up(finger, at)` and `tilt(degrees)`. They are queued with
`push_input()` and consumed at the start of the next `step()`. Positions are
in viewport pixels. **Rule for later chunks:** game logic (tap dispatch, the
call, edge buttons, tilt) reads input only from these events, never from
Godot's `InputEvent` directly; `src/main.gd` is the one place that
translates. Otherwise scripted input would bypass it. Touches are turned
into taps inside the simulation (see "Taps and the call").

### Randomness

All gameplay randomness comes from one seeded generator: `Rng`
(`src/sim/rng.gd`), a wrapper around `RandomNumberGenerator`. The simulation
owns the master `Rng` (`simulation.rng`). **Code under `src/` never calls
Godot's global `randi()`, `randf()`, `randi_range()`, `randf_range()`,
`randfn()`, `randomize()` or `seed()`, nor `Array.shuffle()` or
`Array.pick_random()`**, and doesn't create its own `RandomNumberGenerator`:
those can't be seeded per run. `tests/unit/test_no_global_random.gd` fails
the suite if one appears.

- `rng.derive("slime:12")` gives an independent stream whose seed depends
  only on the master seed and the name (SHA-256 of `"<seed>/<name>"`), not on
  how many numbers were drawn before or in which order streams were made.
  Use one per slime (or per system) so that adding a draw in one place
  doesn't shift every other random number.
- `rng.state` is the position in the sequence; save it and set it back to
  resume. A stream a later chunk keeps must have its state in `dump()`.
- Normal play starts from `Rng.random_seed()`; test mode sets the seed.

### State dump and hash

`simulation.dump()` returns the state as plain data; `StateHash`
(`src/sim/state_hash.gd`) turns it into canonical JSON (keys sorted at every
level, no whitespace, floats at full precision, vectors as `[x, y]`) and
`simulation.state_hash()` is its SHA-256. Equal hashes mean equal states.
64-bit values (the seed, the generator state) are strings in the dump so
they survive a JSON round trip (saves, chunk 8). Hashes are compared on one
platform: floating-point results may differ between x86 and ARM.

### Test mode

Test mode runs the game from a script: it sets the seed, scales or skips
simulated time, feeds scripted taps, touches and tilt to the simulation on
exact ticks, and loads a named fixture. It is off unless asked for, and it
is only possible in a debug build (see "The release guard" below).

A run is one dictionary, in GDScript or in a JSON file:

```json
{
	"seed": 20260928,
	"time_scale": 1.0,
	"fixture": "fresh",
	"block_real_input": true,
	"steps": [
		{"tick": 10, "do": "tap", "at": [400, 300]},
		{"tick": 30, "do": "touch_down", "at": [200, 200]},
		{"tick": 31, "do": "touch_down", "at": [900, 500], "finger": 1},
		{"tick": 40, "do": "touch_up", "finger": 1},
		{"tick": 45, "do": "touch_up", "at": [210, 205]},
		{"tick": 60, "do": "tilt", "degrees": 20}
	]
}
```

- `seed` (required): the master seed. Each test sets its own.
- `time_scale` (0 to 64, default 1): simulated seconds per real second for
  the frame clock. `0` holds the clock, so only `run_ticks()` advances the
  simulation; end-to-end tests use that.
- `fixture`: a fixture name from `specs/levels/test/README.md`, resolved to
  `levels/test/fixtures/<name>.json`. **A stub until chunk 8:** it checks
  the name and reports "not implemented", which makes the run fail to start.
  The `.json` extension is provisional; chunk 8 settles the save format.
- `block_real_input` (default true): ignore the real mouse and touches.
- `screen_size` (`[width, height]`, default `[1152, 648]`): the screen size
  the simulation's view uses to dispatch taps (a headless window reports a
  wrong one). The game reads it in `sync_view()`; outside test mode it uses
  the viewport's size.
- `steps`: the input script (`src/test_mode/test_mode_script.gd`). `tick` is
  the tick the step happens on: its events are consumed by the step that
  advances that tick. `do` is `tap` (down and up on the same tick),
  `touch_down`, `touch_up` or `tilt`. `at` is a viewport position; `finger`
  is 0 by default, 1 for a second finger. Steps may come in any order. A typo
  in a key or a missing value is an error naming the step.

The game root takes a run with `enable_test_mode(config)`, which returns the
errors (empty when test mode is on) and starts a fresh simulation from the
seed. Then `game.test_mode.run_ticks(n)` runs n ticks at once (skipping
time) and `run_until(tick)` runs up to a tick.

From the command line (a debug build):

```sh
godot --headless -- --test-mode --test-script=res://tests/e2e/scripts/backbone.json --run-ticks=600
# prints: STATE tick=600 hash=<sha256>, then quits
```

Flags: `--test-script=PATH` (res:// or a file path), `--seed=N`,
`--time-scale=X`, `--fixture=NAME` (these override the file),
`--run-ticks=N` (run N ticks at once, print the hash, quit) and
`--print-state` (also print the state as JSON). A run that can't start
quits with code 1. Without `--run-ticks`, in a window, the game plays the
script in real time (scaled) with a pink "TEST MODE" banner and a ring on
every finger down. To record a debug run without a screen, use Godot's movie
maker under Xvfb:
`xvfb-run -a godot --write-movie /tmp/frames/f.png --quit-after 120 -- --test-mode --test-script=...`.

### Writing an end-to-end test

`tests/e2e/test_backbone_e2e.gd` is the pattern:

```gdscript
extends GutTest

func test_something() -> void:
	var game: Node = load("res://src/main.tscn").instantiate()
	add_child_autofree(game)
	var errors: PackedStringArray = game.enable_test_mode({
		"seed": 42,
		"time_scale": 0,
		"steps": [{"tick": 10, "do": "tap", "at": [400, 300]}],
	})
	assert_eq(errors, PackedStringArray())
	game.test_mode.run_ticks(600)
	assert_eq(game.simulation.tick, 600)
	# assert on game.simulation, or compare game.simulation.state_hash()
```

Put longer scripts in `tests/e2e/scripts/*.json` and load them with
`TestMode.load_config_file(path)`. Keep `time_scale` at 0 when the test
steps with `run_ticks`, or the frames GUT spends in `await` add ticks.
Compare hashes between runs in the same test rather than pinning a hash
value: every chunk that adds state changes the hash.

**Headless (settled here):** the real game scene, a `Node2D` with a
`CanvasLayer` and a drawing `Node2D`, runs under `godot --headless`:
`_ready`, `_process`, input queued through test mode and `_draw` all run, so
the frame clock ticks and the overlay draws (nothing is rendered). A child
Godot process started from a test also works. Caveats: headless has no real
window, so the viewport size is not the project's 1152×648 (Godot reports
1152×1152 for the visible rect and a 64×64 root). Anything that depends on
screen size (the tap zones in chunk 7, the camera) must take the size from
one place a test can set: test mode's `screen_size` (chunk 7). Nothing rendered can be checked headless; for
pixels use the movie maker under Xvfb, as above.

### The release guard

Test mode must never run in a release build. `TestModeGuard`
(`src/test_mode_guard.gd`) is the one check: it allows test mode only when
`OS.is_debug_build()` is true (the editor, the Linux build used for tests,
debug Android exports) and refuses in a release export. Test mode also has to
be asked for (`--test-mode` or `enable_test_mode()`); a debug build doesn't
start in it.

The chosen approach is **present but inert, and strippable**: the game root
names test-mode code only by path, after the guard, never by class. So in a
release export the guard refuses before anything in `src/test_mode/` loads,
and the release preset can also leave that folder out. Checked by
`tests/unit/test_test_mode_guard.gd`: the guard refuses when the build isn't
a debug build, a game with that guard refuses `enable_test_mode()` and the
command-line flags, and no script outside `src/test_mode/` names a
test-mode class.

When export presets exist (chunk 20), the release presets must exclude
`src/test_mode/*`, `tests/*`, `addons/gut/*`, `levels/test/*` and
`spikes/*`, and a CI check must confirm it:

1. Export the release build.
2. List the files in its pack and check that none is under
   `src/test_mode/` or `tests/`.
3. Run the Linux release export with
   `-- --test-mode --seed=1 --run-ticks=10`: it must print "Test mode is not
   available in this build" and no `STATE` line, and carry on as normal
   play.

## Levels and components

A level is a scene built only from the components in `src/components/`,
each a small scene plus its script, configured through exported properties
in the inspector. There are no per-level scripts (D6). The components draw a
greybox placeholder (labelled boxes, coloured circles, route lines), in the
editor too since they are `@tool`, until the real art arrives.

![The test level's start basin in a debug run](img/test-level-basin.png)

![Section 1 (Meadow) of the test level, zoomed out](img/test-level-overview.png)

### Units and coordinates

- **1 screen = 1152 px** (`LevelData.SCREEN`), the width of the view at
  normal zoom. The design documents give x in screens; x = 0 is the level's
  left edge.
- y grows downward, as everywhere in Godot. In the test level the hilltops
  are near y = 0.
- A size-1 slime's radius is 24 px for now (`PlaceholderArt.SLIME_RADIUS`),
  a placeholder until the slime body (chunk 5). The loop and routes are
  drawn at a slime's centre height, 24 px above the ground.

### The level root and the registry

The root of a level scene is a `Node2D` with `src/components/level.gd`
(class `Level`):

- `level_id` (`"test"`, later `"01"`) and `level_version` (1 or more; bump it
  on any change to a released level, which then needs a save migration, D72).
- `rules`: extra rules held by the level itself (usually empty).

When it enters the tree, the level builds a **registry**, stable ID to node,
from every component in it (components join the `Level.THINGS_GROUP` group
in `_init`, at any depth, so they can be grouped under plain `Node2D`s). It
reports each problem with `push_error` (which fails any test that loads the
level) and keeps them in `load_errors`:

- a missing or malformed stable ID, or a **duplicated** one;
- a property that refers to a stable ID that isn't in the level (a
  component lists these in `references()`);
- a rule whose objects, event or action don't exist;
- no loop, more than one loop, or loop segments that don't join.

`level.build()` does the same without the scene tree and returns the errors.
`level.find(id)`, `level.ids()`, `level.position_of(node)` (in level
coordinates) and `level.start_position()` (the first slime) are the lookups.

**Stable IDs** follow `<place>.<kind>.<name>` (D72, `StableId.is_valid`):
lowercase, `<place>` is `start` or `s1`, `s2`…, and the name part may hold
dashes; numbered things use two digits, counted left to right
(`s1.sleeper.01`). Conventions added here: the loop is `start.loop`; a
section's outgoing loop segment is `s1.loop`, its return route `s1.slide`
(test level); a signpost is `s1.signpost`. **Terrain has no ID**: it holds
no state a save would need.

### The components

| Component | Node | Properties | Notes |
|---|---|---|---|
| `Terrain` | `Path2D` | `curve` (a closed outline), `fill_color`, `outline_color`, `outline_width`, `has_collision`, `bake_tolerance_degrees` | Baked at load into a `StaticBody2D` + `CollisionPolygon2D`, a `Polygon2D` fill and a closed `Line2D` outline, from the same points (spike 2). The outline must not cross itself. No ID |
| `Loop` | `Node2D` | `stable_id` (`start.loop`) | Its children are the `LoopSegment`s, in loop order |
| `LoopSegment` | `Path2D` | `stable_id`, `section`, `kind` (`outgoing` or `return`), `gate_id`, `show_route` | Draw it in the direction of travel. A return route names the gate whose opening retires it |
| `RouteBack` | `Path2D` | `stable_id`, `serves` (a branch ID), `show_route` | From inside the branch down to a point on the loop (D69) |
| `ExplorationBranch` | `Area2D` | `stable_id`, `size` | The box a free slime in the branch can be in |
| `SplitZone` | `Area2D` | `stable_id`, `size` | At the start of the loop (rule 4). `SplitZones` in the simulation splits every slime inside it (see "Train") |
| `FirstSlime` | `Node2D` | `stable_id` (`start.first-slime`), `species` | Where the first awake slime starts: the game wakes it there in a fresh game (see "Train") |
| `Sleeper` | `Node2D` | `stable_id`, `species` (A to E) | Always size 1 |
| `Switch` | `Area2D` | `stable_id`, `size`, `basket_id` | |
| `Basket` | `Area2D` | `stable_id`, `size`, `quota` (weight), `on_full_object`, `on_full_action` | Holds its rule (below) |
| `Gate` | `Node2D` | `stable_id`, `size` | Accepts the action `open` |
| `Signpost` | `Node2D` | `stable_id`, `switch_id` | |
| `FramingZone` | `Area2D` | `stable_id`, `size`, `zoom`, `offset` | `zoom` as `Camera2D.zoom`: below 1 shows more (0.7 is a zoom-out); `offset` in px, negative y is up |

`size` is a box centred on the node's position. The `Area2D`s make their
rectangle collision shape at load; the `Path2D`s draw their curve. Nodes a
component makes at load (terrain bakes, shapes) have no owner, so they are
never saved into the level scene. The split zone splits and the first
slime is woken (chunk 6, see "Train"). **No behaviour yet** for the others:
the switch, the basket's counting, the gate opening and the camera reading
the framing zones come in later chunks; the level places them, gives them
IDs and checks the references.

### The rule format

The components share one rule format (master spec §5.4), as plain data:

```json
{"when": {"object": "s1.basket", "event": "full"},
 "then": {"object": "s1.gate", "action": "open"}}
```

`Rule` (`src/components/rule.gd`, a `Resource`) holds one; `Rule.to_dict()`
and `Rule.from_dict()` convert. Objects are named by stable ID. The object
that triggers a rule holds it: a `Basket` builds its rule from
`on_full_object` / `on_full_action`. A component declares the events it
emits with `rule_events()` (`Basket`: `full`) and the actions it accepts with
`rule_actions()` (`Gate`: `open`). At load every rule is checked: both
objects exist, the "when" object emits the event and the "then" object
accepts the action. Executing rules comes with chunk 14.

### The loop as data

At load the level turns the loop into plain data for the simulation:
`level.data` is a `LevelData` (`src/sim/level_data.gd`): the level ID and
version, the loop (`LoopData`, `src/sim/loop_data.gd`) and the routes back,
all as polylines in level pixels, the split zones (ID to `Rect2`) and the
first slime (`{id, species, position}`). The game root hands it to the
simulation (`simulation.load_level(data)`, which builds the train and the
split zones from it); `simulation.dump()` records the level's ID and version.

`LoopData` holds the segments in order, each `{id, section, kind, gate,
points, lengths, length}`. Which segments are in use depends on the open
gates: for each section in order, its outgoing segments, then, if the
section's return route's gate is closed, that return route and nothing
further. Opening gate 1 retires slide 1 and adds section 2's segments and
slide (the loop grows, D9). A last return route with no gate, or whose gate
is open, is kept, so the loop always closes.

- `current_segments(open_gates)`, `length(open_gates)`;
- `position_at(distance, open_gates)`: distances wrap round the loop;
- `frontier(open_gates)`: the end of the outgoing part (the slide entrance)
  and the gate there;
- `closest(point, open_gates)`: the nearest point on the loop in use, and
  its segment; `gap(point)`: the distance to any segment, in use or not;
- `validate()`: every segment joins the next (within 2 px) and every return
  route ends at the start of the loop.

### The test level

`levels/test/level.tscn` holds section 1, Meadow (screens 0 to 8), as a
greybox that follows `specs/levels/test/README.md`: the start basin with the
split zone and the first slime, the hills, the fusion dip, the high step, the
tree (an exploration branch with its route back and framing zone), frontier
set 1 and slide 1 back to the basin. Sections 2 and 3 come later.

Chunk 6 adjusted the greybox where a train slime couldn't pass (the
tables in the generator say where):

- the lip's nose moved right (0.60 to 0.64) and the loop's rise to the lip
  is at 0.58-0.59, in the open; the tunnel floor has a hump under the lip,
  so a slime falling short of the lip rolls back out to the basin;
- the loop starts at 0.3, not against the basin's left wall (a slime could
  not reach the old start, so its progress never wrapped); the slide ends
  there and the first slime starts there;
- the crust top runs on to 6.49, closing the 58 px notch over basket 1's
  pit where a slime wedged (the pit has no entrance yet: the switch chunk
  decides it);
- the high step's underside is at -210 (was -170) and the tree's climb
  starts at 4.72, -208 (was 4.62, -140): a size-2 or size-3 slime hopping
  under them wedged on their corners;
- the chute into slide 1 is wider at the top (the near wall starts at 7.5,
  was 7.56) and its far wall is upright down to y = 30, so a slime falling
  in isn't thrown back up onto the ledge.

The scene is generated by `tools/greybox_test_level.gd` from tables of
points (x in screens, y in px):

```sh
godot --headless -s res://tools/greybox_test_level.gd
```

It is still a normal scene that opens and edits in the editor, but a
re-run overwrites hand edits. Once the level is edited by hand for real,
delete the generator. `tests/e2e/test_test_level.gd` checks the scene
against the design and the level rules: every ID, the population, sleepers
off the loop, the first sleeper near the first slime, the loop and the
slide, the split zone at the start, routes back that start in their branch,
end on the loop and only go down, the frontier set and the terrain bake.

**Adding a section** (for example section 2): add its terrain; add its
outgoing `LoopSegment`s (`section = 2`) after `S1Slide` in the `Loop`, the
first starting where `s1.loop` ends (behind gate 1), then its slide
(`kind = return`, `gate_id = "s2.gate"`) ending at the start of the loop;
place its things with `s2.` IDs; extend the tests' expected IDs.

## Slimes

The slime bodies are `SlimeBodies` (`src/sim/slime_bodies.gd`), owned by the
`Simulation` (`simulation.slimes`) and advanced once per tick, after the
queued input. `SlimeRenderer` (`src/slimes/`) draws them; it only reads them.
Species and their colours are `Species` (`src/sim/species.gd`).

![The slime demo: six species in three sizes, blend renderer](img/slimes-demo.png)

### Layout

Struct of arrays (D94). Per point: `pos`, `prev` (Verlet: velocity is
`pos - prev`) and `rest_off` (offset on the rest circle). Per slime:
`id`, `first` and `npts` (its slice of the point arrays), `size`, `species`,
`state`, `held`, `supported`, `hop_timer`, `heading`, and the ring's rest
radius, area and edge length. Rings have 12, 15 and 18 points for sizes 1, 2
and 3; the ring radius is `21 * sqrt(size)` px, and the drawn body adds
`EDGE` (3 px) all round, so a size-1 slime looks 24 px in radius.

Slimes are kept in ascending id order with their point slices back to back.
`remove`, `merge` and `split` compact every array (no holes, order kept), so
a slime's index can change but its id never does; ids are never reused.
Callers hold ids; `index_of(id)` is a binary search. `topology_version`
changes whenever the set of slimes or their point counts change (the
renderer rebuilds its index arrays then).

The interface (create, remove, tick, merge, split, hop, the accessors,
dump) is small and plain so the tick can move to a GDExtension without the
callers changing.

### Solver

Verlet with position-based constraints, 2 substeps x 1 iteration at 60 Hz
(D94). Each substep: integrate (gravity 1400 px/s², air drag 5 %/s,
internal damping), then slime-slime contacts, ring constraints, terrain
contacts. The pair list comes from a uniform grid on the slime centres,
built on the first substep only (cells at least as big as the largest pair
reach, so each slime checks its own cell and its neighbours).

- **Ring constraints:** edge springs (stiffness 0.8), area (0.6) and shape
  matching toward the rest circle (0.3). The edge springs are solved
  Jacobi-style (all corrections computed, then applied): a sequential pass
  made rings slowly rotate and drift sideways.
- **Point 0 at the bottom.** A ring with an odd point count resting on an
  edge is unstable and rolls to stand on a point; starting every ring on a
  point keeps rings mirror-symmetric and still at rest.
- **Internal damping 0.2:** each substep pulls every point's velocity 20 %
  toward its slime's mean velocity. It kills internal jiggle without slowing
  the slime; at 0.1 a size-3 slime propelled itself along the floor.
- **Air drag is per second,** not per substep like the spike's (0.996 per
  substep, about 38 %/s), so a velocity set with `set_velocity` or a hop
  carries as expected.
- **Slime-slime contacts** push points out along the other ring's radial
  profile (the spike's method), with friction (0.3) on the sliding part, so
  slimes can pile up. Two rings within `TOUCH_SKIN` (2 px) count as
  touching (`touching`, `touching_pairs`); a slime resting on another's top
  is `supported`.

### Terrain contact (O78)

The simulation never reads nodes. At level load, `SlimeWorld.terrain_from`
gathers every `Terrain` piece with collision (its baked polygon, in level
coordinates) and builds a `TerrainSegments` (`src/sim/terrain_segments.gd`):
the polygons as segment arrays with outward normals, plus a CSR grid
(32 px cells) listing, per cell, the segments within `MARGIN` (16 px) of it.
Each ring point asks its cell for the nearest segment:

- a point inside a piece is pushed out to the surface plus `terrain_skin`
  (`EDGE`, so the drawn body rests on the ground instead of overlapping it);
- a point outside but within the skin is pushed out along the direction from
  the nearest point (rounded convex corners);
- friction (0.4) takes from the tangential velocity and the inward normal
  velocity is zeroed;
- a surface whose normal points up by more than 0.3 marks the slime
  `supported` (it may hop).

Limits: a point deeper than `MARGIN` inside a piece is not seen, so terrain
pieces must be thicker than about 32 px, and pieces must not overlap or
share edges (a point between two could be pushed into the other). At the
speeds capped by `max_speed` (1200 px/s, 10 px per substep) points never
get that deep.

The terrain is baked once per level load in `main.gd` and shared by every
fresh simulation (`_new_simulation`).

### Hops

A train slime hops on its own timer: when `hop_timer` runs out and the slime
is `supported`, it hops forward along its `heading` and draws its next
interval from its own stream, `rng.derive("slime:<id>")`. Intervals are
1.5-3 s (specs/tuning.md), 15 % longer per size above 1; take-off speed is
620 px/s, 12 % faster per size, with a ±10 % random strength. A size-1 hop
rises about 114 px and covers about 224 px; a size-3 hop 176 px and 336 px.
`hop(id, dir, strength)` is the direct form (switches, taps later); it
refuses a slime that isn't supported or whose state doesn't hop.
`set_hop_held` pauses the timer (a queued slime at a gate, later).
`set_hop_aim(id, velocity)` aims the next automatic hop, if it comes this
tick: that take-off velocity instead of a plain hop along the heading (the
strength is still drawn, so the stream doesn't shift). It is cleared by
every tick, so it isn't state. `brake(id, share)` removes that share of a
slime's mean velocity and spin, keeping its squish: how the train makes a
slime grip the ground between hops.

### Merge and split

`merge(a, b)` keeps the lower id, adds the sizes (refused above
`MAX_SIZE`, or across species), and reshapes the survivor into a fresh
ring at the size-weighted centre, with the size-weighted velocity. Whether
two slimes have touched long enough to fuse is the caller's decision (a
later chunk); `touching_pairs()` is what it reads. `split(id)` reshapes the
slime into size 1 and creates size-1 slimes for the rest, 52 px apart
(size 2: side by side; size 3: a triangle), each with the same state,
heading, hold and velocity. Both bump `topology_version`.

### Renderer

`SlimeRenderer` builds one triangle mesh each frame (a fan per ring plus a
6 px skirt where the field fades to 0) and draws it through the
`RenderingServer`. Two modes:

- **Blend** (default): the spike's technique. The fields go into two
  `SubViewport`s at half the screen's resolution (`field_scale`), one
  species per colour channel (A-C, D-F); a full-screen composite thresholds
  them, so same-species slimes that touch melt into one blob and different
  species meet at a seam. The viewports follow the camera
  (`canvas_transform`) every frame.
- **Direct** (fallback): one mesh, each ring drawn on its own in its species
  colour. It is the default headless (`default_mode()`), and the demo
  toggles it with D.

It draws the last tick's state; there is no interpolation between ticks.

### Demo and bench

```sh
godot --path . src/slimes/demo.tscn              # D: blend/direct, Space: pause
godot --path . src/slimes/demo.tscn -- --draw=direct --seed=7
godot --headless -s res://tools/bench_slimes.gd  # -- --count=200 --ticks=600
```

The bench drops 200 slimes into a 1152 px box, settles them for 180 ticks,
then times 600 ticks of `SlimeBodies.tick`, headless (same machine as the
spike: Ryzen 5 PRO 8640HS, Godot 4.7.2):

| Case | Points | Still, ms/tick | Moving, ms/tick |
|---|---|---|---|
| 200 × size 1 | 2400 | 9.99 | 9.84 (857 hops) |
| 200, 60/25/15 % sizes 1/2/3 | 2730 | 14.68 | 15.22 (806 hops) |
| Spike, GDScript, 12 points, flat floor | 2400 | 8.75 | 8.08 |
| Spike, native estimate | | ~0.35-0.41 | |

Split of a mixed still tick (per substep call): slime contacts 3.8 ms, ring
constraints 1.7 ms, pair grid 1.1 ms, integrate 0.7 ms, terrain 0.6 ms.
Heavier than the spike: terrain segments instead of a flat floor, friction,
touch tracking and a denser pile. In GDScript the tick alone is most of a
60 Hz frame at 200 slimes: fine for development and a handful of slimes,
but the full count needs the native tick (spike 1's conclusion).

## Train

`Train` (`src/sim/train.gd`, `simulation.train`) moves the train slimes
along the loop. It reads the loop in use (`LoopData.current_segments`,
flattened into one polyline with a per-edge "slide" flag) and keeps, per
train slime, its progress: a distance along the loop and a lap count.
Each tick, `Simulation.step()` runs the input, `train.steer()` (grip, carry
and hop aim, before the bodies move), `slimes.tick()`, the split zones
(`SplitZones.apply`, whose parts `train.inherit()` their parent's
progress), then `train.follow()` (progress, laps, lost). `train.dump()` is
in the state dump.

![The first slime hopping along the loop from the start basin](img/train-first-slime.png)

**Progress.** A slime's progress is re-derived every tick by projecting its
centre onto the loop, but only onto a window from its last progress to
`PROGRESS_WINDOW` (400 px) ahead. It never goes back (a slime bumped back
keeps its progress), and it can't snap to a part of the loop that is close
in space but far along it (the slide runs back under the outgoing route).
Past the end it wraps and counts a lap. A slime knocked more than
`OFF_ROUTE` (36 px) off the route at its progress (thrown back out of the
chute onto the ledge, pushed back across the start basin) steers from the
route point nearest it within the window behind; its recorded progress
doesn't move. New train slimes (split parts, later sleepers) are adopted
where the loop passes closest (`LoopData.closest`).

**Hop targeting.** When a slime's next hop is due, the train aims it:
`Train.aim(from, to, apex, gravity, cap)` gives the take-off velocity of a
ballistic arc from the slime's centre to a point `hop_reach(size)` (150 px,
+20 % per size) ahead along the route, whose top clears the higher end by
`hop_apex(size)` (34 px, +25 % per size) plus any route point in between
that stands higher. The speed is capped at 1.15 x the size's plain hop
speed. Two cases change the target:

- a **steep rise** (a step the route crosses in the air): the slime first
  hops to its foot (`STEP_FOOT` px short of it), then from within
  `STEP_NEAR` of the foot over it, to `STEP_LANDING` px along the top;
- a **steep drop** (the chute into a slide): it aims `DROP_OVER` (40 px)
  past the top of the drop, along the way it was going, and falls in.

**Grip.** Soft bodies roll down any slope (a size-1 slime rolled 317 px in
3 s down a 30° slope). The spec lets a slime roll where its hops can't
hold it (master spec §5.2), so the train only grips where the route is at
most 45° steep: a supported slime there is braked by half each tick
(`GRIP`), so it stays put between hops.

**The slide (placeholder, O22).** On a return route a slime doesn't hop
(it is held) and, while it touches the ground, its velocity along the
route is pulled towards `SLIDE_SPEED` (360 px/s) by a fifth each tick. The
real slide comes with the level art.

**Lost (placeholder until chunk 15).** A slime is lost when its centre
leaves the level's bounds (the terrain and the loop, plus 64 px, plus 2000
px above), or when its progress hasn't advanced 24 px in 60 s. Lost slimes
are listed in `train.lost` with the tick and the reason (`stalled`,
`out_of_bounds`); nothing is done about them yet.

**Split zones.** `SplitZones` (`src/sim/split_zones.gd`) holds the level's
split zone boxes. Every tick, every slime above size 1 whose centre is in a
zone is split (`SlimeBodies.split`) into base slimes, which keep its
species and state: train slimes stay on the train. Nothing else splits.

**Waking the first slime.** `Simulation.load_level` creates the level's
first slime (size 1, its species, a train slime) at its marker when the
state is fresh (tick 0, no slimes): a restored state keeps its own slimes.
There are no sleepers on the level yet (chunk 9).

**Tests.** `tests/unit/test_train_progress.gd` (progress window, wrap,
laps, lost, aim, targets, off-route steering) and
`tests/unit/test_split_zones.gd`; `tests/e2e/test_train_in_game.gd`
(the first slime woken, each size 1 to 3 completes a lap and comes back as
base slimes, a size 3 and a size 2 entering the split zone leave as five
base slimes on the train); `tests/e2e/test_train_session_e2e.gd` runs a
15-minute session (54 000 ticks) with no input and checks the first slime
is never lost, its progress never goes back, it makes at least 4 laps (0.7
of the ideal pace; it makes 5) and the same seed gives the same hash twice.
It takes about 2 s per run, 4-5 s for the test. Several slimes at once in
the start basin can still jam (see chunk 6's choices).

## Taps and the call

Master spec §5.2 and §5.5. All of it is simulation logic in `src/sim/`
(`ScreenView`, `TapDispatcher`, `FreeSlimes`, driven by `Simulation`);
`src/taps/tap_feedback.gd` only draws.

![A tap on the hills: the ripple, and the first slime hopping back to it](img/chunk7-call.png)

**The view.** Taps arrive in screen pixels, so the simulation holds a view,
`simulation.view` (`ScreenView`): the level point at the screen's centre,
the zoom and the screen size. `main.gd`'s `sync_view()` copies it from the
camera before every tick (`camera_centre()` reproduces Camera2D's limit
clamp and adds the offset); the screen size is test mode's `screen_size`
in test mode, else the viewport's. `world = centre + (screen - size / 2) /
zoom`. The view is in the dump. The camera itself stays in the scene until
chunk 12.

**Tap zones** (`TapDispatcher.dispatch`), checked in this order:

| Order | Zone | Where | Does |
|---|---|---|---|
| 1 | `parent_zone` | the top `TOP_BAND_HEIGHT` (64) screen px | nothing yet (parent buttons, chunk 18); never calls |
| 2 | `edge_button` | `EDGE_BUTTON_SIZE` (96×192) screen px against each side, vertically centred | nothing yet (camera, chunk 12); never calls |
| 3 | `object` | a tap target's box grown by `OBJECT_HIT_MARGIN` (24) screen px | nothing yet (chunks 9, 14); a **sleeper** calls, centred on it |
| 4 | `open_ground` | anywhere else | calls, centred on the tap |

Tap targets come from the registry: `Level.build()` adds every node with a
`tap_target()` (switch, basket, sleeper) to `LevelData.tap_targets` (ID,
kind, level box). Where hit areas overlap, the nearest box centre wins
(ties: the smaller ID). The top band and edge button sizes are
placeholders until the ui_ux tree settles them.

**First touch wins** (D66, O67's proposed default). A tap is dispatched
when its finger touches down, and only if no finger is down then
(`active_finger`). A touch that starts while any finger is down gets
nothing, not even a ripple, and stays ignored until it lifts, even if the
first finger lifts before it. `fingers_down` still records every finger.

**Ripples and facing.** Every accepted tap, whatever its zone, appends a
ripple `{at, tick}` (level point) to `simulation.ripples`; it lasts
`RIPPLE_TICKS` (36, 0.6 s). The ripples are sim state and in the hash:
they are deterministic (a function of the input), and keeping them there
lets the renderer draw from the state alone. `TapFeedback` draws each as a
ring growing from 10 to 64 screen px and fading. The tap also turns every
awake slime within the call radius toward it (`simulation.facing`, a unit
vector per slime), and every hop turns its slime the way it hops;
`TapFeedback` draws the facing as an eye dot (placeholder art). The last 16
taps are logged in `simulation.taps` (zone, object, whether it called, who
answered), for tests and debugging.

**The call** (`FreeSlimes`, `simulation.free_slimes`). A call has a point
and a tick. Every awake slime (train or free) whose centre is within the
call radius, half the view's width in level px (576 at zoom 1), answers:
it becomes free (state `free`, the train drops it), is let go if it was
held on the slide, and hops within `FIRST_HOP_SECONDS` (0.35 s). A new call
replaces the point for every slime still answering, in range or not, and
restarts its 8 s. Sleepers don't answer (waking them is chunk 9). A free
slime then goes through three phases, recorded per slime with the tick it
entered them:

| Phase | Hops | Ends |
|---|---|---|
| `answering` | toward the point, at 0.6× its usual hop interval; up to `Train.hop_reach` sideways; upward when the point is higher, up to `max_rise(size)` (about 133, 168, 208 px for sizes 1 to 3: bigger slimes jump higher) | within `REACHED` (56 px, plus the extra radius of bigger slimes) of the point, or after `CALL_SECONDS` (8 s): turns unsure |
| `unsure` | lazy random hops (60 px, low) near the point, at 1.3× its interval, directions from its own stream `free:<id>:<tick>`; hops back toward the point if more than 120 px away | after `UNSURE_SECONDS` (15 s): heads back |
| `heading_back` | toward the loop at its usual pace (see below) | its centre within `REJOIN_DISTANCE` (40 px, plus the extra radius) of the current loop: back to state `train`, adopted at the closest loop point |

Physics applies throughout: the bodies are the same soft bodies, and a
free slime grips ground up to 45° between hops like a train slime (rolls on
steeper ground). A free slime with no record (none yet: later chunks may
free slimes otherwise) is adopted as heading back.

**The way back (route-back selection rule).** Chosen again at every hop,
from where the slime stands:

1. If its centre is inside an exploration branch's box
   (`LevelData.branch_at`, first ID in sorted order) and that branch has a
   route back (`route_back_for`), it follows that route: it aims
   `hop_reach` ahead of its projection on the route, until it is at the
   route's end. `route_of(id)` names the route used.
2. Otherwise (no branch, a branch without a route, or past the route's
   end), it hops straight for the nearest point of the current loop,
   always at least `MIN_SIDEWAYS` (60 px) sideways (the loop's direction
   there when the loop point is right below), so it leaves a ledge rather
   than hop in place above the loop.

**Tick order.** Input (taps, calls answered); `train.steer`;
`free_slimes.steer`; `slimes.tick`; `free_slimes.paced` and hop facings;
split zones (`train.inherit`, `free_slimes.inherit`: split parts keep the
phase and get a fresh stream); `free_slimes.follow` (phases, rejoining);
`train.follow`; spent ripples go.

**Tests.** `tests/unit/test_screen_view.gd` (screen to world and back,
zoom), `tests/unit/test_tap_dispatch.gd` (zone order, hit margins at zoom,
ripples in every zone, first touch wins, taps in the state) and
`tests/unit/test_call.gd` (on a synthetic world: radius just inside and
just outside, a new tap, 8 s give-up, 15 s unsure, heading back by a route
and directly, rejoining, determinism). `tests/e2e/test_call_e2e.gd` on the
test level: a call on the hills pulls the first slime off the loop, it
reaches the point and rejoins within 45 s; a call to the tree's high bough
gives up after exactly 8 s and heads back directly from the ground, or by
`s1.route-back.tree` from the tree platform; a scripted run with taps
gives the same hash twice and a different one without them.

## Tilt

Master spec §5.5 and DoD 8. `Tilt` (`src/sim/tilt.gd`) is pure logic owned by
the simulation (`simulation.phone_tilt`); only free slimes feel it.

**The reading.** The `tilt` input event, `Simulation.tilt(degrees, flat :=
false)`, carries the direction of real gravity in the screen's plane,
measured from the screen's down, in degrees. **Positive turns down toward
screen-right** (the phone's right edge dips, like a steering wheel turned
right). `flat` says the phone lies flat (screen up): its angle means nothing
and it counts as neutral. On desktop the event comes from test mode's
script: `{"tick": 60, "do": "tilt", "degrees": 20}`, with an optional
`"flat": true`. Turning the sensor into readings (the angle, and the
threshold under which the phone is flat) is chunk 20's.

**Neutral.** Readings count from `neutral`, the hold when the session
started: `take_neutral_now()` takes the last reading (0°, the screen's down,
if the phone lies flat or nothing was read yet); `set_neutral(angle)` sets
it. Placeholder until sessions (chunk 17): `Simulation.load_level()` takes
it, so every fresh or resumed level starts at neutral (D95's proposed
clause). Angles wrap at ±180°.

**Dead zone and cap.** Relative to neutral, a tilt within
`DEAD_ZONE_DEGREES` (10) leaves gravity plain down (exactly `Vector2.DOWN`,
so a tilt held at neutral changes nothing, bit for bit). Past it, gravity
turns continuously from 0° at the dead zone's edge to `CAP_DEGREES` (45) at
45°, and no further (60° is the same as 45°): `turn = sign * (min(|a|, 45) -
10) * 45 / 35`. The spec doesn't say what happens just past the dead zone;
ramping from 0 avoids a 10° jump at its edge, and at the cap gravity turns
exactly as much as the phone.

**Only free slimes.** Before the bodies tick, the simulation sets
`slimes.free_down = phone_tilt.down()` (a unit vector). `SlimeBodies.gravity_for(state)`
gives a free slime `gravity` turned to `free_down` (same strength), every
other state (train, sleeper, bedtime-asleep) the plain `gravity`. Hop aims
still use the plain gravity, so a tilted free slime's hops drift the way it
is tilted, and between hops the free slime's grip (45°, judged against the
world's down) only slows the drift on gentle ground. The tilt's `degrees`,
`neutral` and `flat` are in the dump (`input.tilt`); `Tilt.dump()` and
`restore()` give them to saves.

**Tests.** `tests/unit/test_tilt.gd`: the dead zone (9° plain down, 11°
turned), the cap, neutral offsets and wrapping, taking neutral, lying flat,
the sign and length of the way down, the event through the simulation, the
dump, the script's `flat`, and on a flat floor a free slime rolling with 30°
of tilt while a train slime, a sleeper and a bedtime-asleep slime don't move.
`tests/e2e/test_tilt_e2e.gd` on the test level: a scripted tap calls the
first slime, a scripted ±30° tilt shifts it right or left while a train
slime ahead on the loop moves exactly as without tilt; scripted tilts give
the same hash twice; and a tilt held at neutral or inside the dead zone gives
the very same world as no tilt, so the no-input session test
(`test_train_session_e2e.gd`) also shows the level is travelled with tilt at
neutral (no level requires tilt).

## Android export (debug)

`export_presets.cfg` holds two Android presets, both debug-signed APKs with
no Gradle build, arm64-v8a only, landscape (from `project.godot`),
minimum SDK 24 (Godot's default):

| Preset | Package | Output | What it runs |
|---|---|---|---|
| `Android debug` | `com.slimetrain.dev` | `build/slime-train-debug.apk` | the game (`src/main.tscn`); `spikes/` is left out |
| `Android spike: soft slimes` | `com.slimetrain.spike` | `build/spike-debug.apk` | spike 1's phone benchmark (feature tag `spike_soft_slimes`) |

The preset file holds no credentials. The debug keystore comes from the
editor settings (`~/.config/godot/editor_settings-4.7.tres`), which need:

```
export/android/android_sdk_path = "/home/<you>/Android/Sdk"
export/android/java_sdk_path = "/usr/lib/jvm/java-21-openjdk-amd64"
export/android/debug_keystore = "/home/<you>/.local/share/godot/keystores/debug.keystore"
export/android/debug_keystore_pass = "android"
```

The user defaults to `androiddebugkey`. Create the keystore once if it is missing:

```sh
keytool -genkeypair -keystore ~/.local/share/godot/keystores/debug.keystore \
  -storepass android -alias androiddebugkey -keypass android -keyalg RSA \
  -keysize 2048 -validity 10000 -dname "CN=Android Debug,O=Android,C=US"
```

Godot 4.7 asks for JDK 17; the JDK 21 of Debian 13 signs and exports
without complaint (no Gradle build). `project.godot` enables
`rendering/textures/vram_compression/import_etc2_astc`, which every Android
export requires.

Export, install, run and read the output (Godot's `print()` goes to the
logcat tag `godot`):

```sh
mkdir -p build
godot --headless --path . --export-debug "Android debug" build/slime-train-debug.apk
adb install -r build/slime-train-debug.apk
adb shell am start -n com.slimetrain.dev/com.godot.game.GodotAppLauncher
adb logcat -v time -s godot:*
```

- The launcher activity is `com.godot.game.GodotAppLauncher`: starting
  `GodotApp` directly is refused (not exported).
- A headless export restarts the adb server, which kills a running
  `adb logcat`; start the capture after exporting.
- The official Android templates are built without path overrides, so
  a scene given on the command line (`command_line/extra_args`) aborts the
  engine. That is why the spike preset uses a **feature tag** instead:
  `src/main.gd` checks `OS.has_feature("spike_soft_slimes")` first thing and
  changes to `res://spikes/soft-slimes/spike.tscn`. Options after `--` in
  `command_line/extra_args` do reach the spike (for example
  `-- --draw-only`); intent extras from `adb shell am start` are stripped for
  an exported activity, so they don't.
- On the phone, the spike runs its whole bench matrix and then a 10-minute
  soak, prints one `RESULT` line per case and quits (see
  `docs/dev/spike-soft-slimes.md`).

## Technical choices

### Chunk 0: tooling and project setup

- **Test framework: GUT 9.7.1**, vendored in `addons/gut/` (MIT licence).
  It is the most used Godot 4 test framework, it runs headless from the
  command line, and 9.7 is the release made for Godot 4.7. It was checked on
  Godot 4.7.2 before being picked. gdUnit4 wasn't needed.
- **Closing GUT's false greens.** As shipped, GUT exits with code 0 in cases
  where the suite didn't really pass: a test script that fails to parse is
  skipped silently, a run with no tests passes, and GUT quits with 0 if its
  classes haven't been imported yet (a fresh clone) or if nothing matches
  `-gselect`. So:
  - `tools/test.sh` runs `godot --headless --import` before the tests;
  - the post-run hook `tests/gut_post_run.gd` fails the run if any
    `test_*.gd` under `tests/` fails to load, or if no test ran;
  - the hook writes a marker file, and `tools/test.sh` fails if GUT exited
    without writing it.
- **Renderer left as is:** "Compatibility" (`gl_compatibility`) on desktop
  and mobile. It is the renderer that reaches the most Android phones.
  Spike 1 (chunk 1) confirms or changes it.
- **Landscape, locked** (D78): `display/window/handheld/orientation` is
  `0`, landscape. It is also Godot's default, so the editor may drop the line
  when it saves the project settings. The meaning stays the same.
- **2D:** the main scene is a `Node2D` and the stretch mode is
  `canvas_items`. The 3D physics setting was removed before this chunk.
- **Application name:** "Slime Train".
- **Not done yet:** there are no export presets. When they arrive,
  `addons/gut/`, `tests/` and `spikes/` must be left out of release exports
  (chunk 3 checks that test mode is absent from them).

### Chunk 3: test backbone

- **60 ticks per second**, run from `_process` with our own accumulator
  rather than Godot's physics tick: the slimes are our own code, and time
  scaling and skipping stay in one place. See "Simulation and test mode".
- **One seeded generator, streams by name:** a stream's seed is SHA-256 of
  the master seed and its name, not `String.hash()`, which isn't documented
  as stable across versions. A lint test enforces the randomness rule.
- **State hash: SHA-256 of canonical JSON.** Readable when two runs differ
  (`--print-state` prints the JSON to diff), and good enough for speed at
  this size.
- **Test mode guarded by `OS.is_debug_build()`**, reached by path only, so it
  can be stripped from release exports. No custom feature tag: a debug build
  is already what the Linux test build and debug Android builds are.
- **Script format: data, not code.** A dictionary or JSON file with the seed
  and a list of steps, so end-to-end tests are data plus assertions and the
  same file runs from a test or the command line.
- **The fixture loader is a stub** that resolves the name to
  `levels/test/fixtures/<name>.json` and refuses; chunk 8 implements it.

### Chunk 4: level scaffolding

- **One scene plus one script per component**, configured by exported
  properties; the level root's script is the same for every level. The
  components are `@tool` so the greybox draws in the editor.
- **Registration by group, lookup by stable ID.** Components join
  `Level.THINGS_GROUP` in `_init`, so the registry finds them at any depth
  and without the scene tree. References between objects are stable IDs
  (properties like `basket_id`), not `NodePath`s: they survive moving nodes
  and are what saves and rules use anyway.
- **Load checks fail loudly.** Every problem is a `push_error`, which GUT
  counts as a failure, so a test that only loads a level catches a broken
  one.
- **Rules as a `Resource` with a plain-data form**, held by the object that
  triggers them. A level-held `rules` list covers rules no component owns.
- **The loop is plain data** (`LoopData` in `src/sim/`), built once at load
  from the `LoopSegment` curves (`Curve2D.tessellate`), so the simulation
  never reads nodes. Gate growth is a pure function of the open gates.
- **Terrain bakes once at load** (and live in the editor), from a closed
  `Path2D`, as spike 2 recommended. Straight parts stay two points.
- **The greybox is generated** from point tables by a tool script: laying
  out 60-odd nodes by hand is slow and hard to check, and the tables are
  easy to review against the design. It remains a normal scene.

### Chunk 5: slime body

- **Struct of arrays, Verlet, 2 substeps x 1 iteration, grid on centres**
  (D94), with a plain interface so the tick can go native later. 12/15/18
  ring points for sizes 1/2/3.
- **Terrain as baked segments** (O78): the simulation tests ring points
  against the terrain's baked polygons through a CSR grid, not against
  Godot physics, so it stays pure and deterministic.
- **Jacobi edge springs, point 0 at the bottom, internal damping 0.2, air
  drag per second:** each fixes a drift or self-propulsion seen in testing
  (see "Slimes", "Solver").
- **One stream per slime** (`slime:<id>`) for hop timing and strength, so
  adding a slime doesn't shift the others' hops.
- **Blend renderer with a direct fallback** (D94), Compatibility renderer.
  Headless runs draw direct.
- **Measured tick cost** is in "Slimes", "Demo and bench": GDScript is
  10-15 ms per tick for 200 slimes.

### Chunk 7: taps and the call

- **Taps are resolved in the simulation, through a view.** The scene only
  copies the camera into `simulation.view` each tick, so scripted and real
  taps take the same path and a test sets the screen size in one place.
- **Dispatch on touch down**, so a tap answers at once; a long press or a
  drag (later chunks) can still build on the same touch.
- **Ripples, taps and facings are in the hash:** they are deterministic
  functions of the input, and the renderer draws from the state alone.
- **A new call restarts the 8 s** for every slime still answering (the
  spec says the new tap replaces the point; restarting the clock is the
  reading taken).
- **The way back is re-chosen at every hop** from where the slime stands,
  so a slime that falls off a branch mid-route heads straight for the loop.
  Heading back directly keeps at least 60 px sideways, or a slime on a
  ledge right above the loop hops in place.
- **Placeholders:** the top band (64 px) and edge buttons (96×192 px) until
  ux-writer settles them; the ripple ring and the eye dot as art.
- **The basket is a tap target** (per the build plan), though the spec has
  a basket act by presence: it only blocks a call there, nothing else yet.
- **Known limit:** from the ground, a base slime can't hop onto the tree
  climb's lower end (about 180 px up; it aims at most about 133 px, a size
  2 about 168, a size 3 about 208). Called to the platform from below, a
  base slime gives up after 8 s. Level tuning, not code, if it matters.

### Chunk 6: train and split zone

- **Progress by windowed projection, not by path following:** the bodies
  stay free soft bodies; the train only reads where they are and aims their
  hops. The window (never back, 400 px ahead) keeps progress monotonic and
  stops it jumping between parts of the loop that pass close.
- **Aimed ballistic hops** through `SlimeBodies.set_hop_aim`, with the
  timing and strength still from the slime's own stream: the hops land on
  the route, and the stream doesn't shift.
- **Grip by braking** (`SlimeBodies.brake`) on route slopes up to 45°,
  because soft bodies otherwise roll back down between hops.
- **Placeholders:** the slide carry and the "lost" rule (60 s without
  progress, or out of bounds) are simple stand-ins until the level art and
  chunk 15.
- **Greybox fixes, not special cases:** where a slime couldn't pass, the
  generator changed (see "The test level"), never the scene by hand.
- **Known limit:** the slide ends across the start basin, where the
  outgoing route starts back the other way. Several slimes arriving at once
  can jam there, and two slimes shoved into each other by the carry can end
  up overlapping for good (the contact model can't separate two rings with
  the same centre). One slime per size passes on every seed tried; three at
  once jammed on 1 of 6 seeds. Chunk 9 (sleepers joining) has to settle the
  crowd at the start.

### Chunk 5N: native tick (contingency, deferred by D96)

- A verified GDExtension toolchain, not used by the game and kept out of
  the tests and exports. See `docs/dev/native.md`.

### Chunk 2: spike: vector look

- Terrain is drawn as a `Curve2D`/`Path2D` baked into `Polygon2D` +
  `Line2D`, not an SVG texture, because it stays crisp when zoomed and an
  SVG texture blurs. See `docs/dev/spike-vector-look.md`.

### Chunk 1: spike: soft slimes

- Ring-of-springs slimes with a species-field blend shader hold 200 on one
  screen only if the simulation tick is native code, and the renderer stays
  Compatibility. See `docs/dev/spike-soft-slimes.md`.
- On the reference phone (Galaxy S20 FE 5G) the GDScript tick is 2.0–2.1×
  the desktop's (16.7–18.1 ms at 12 points), and ~27 ms once the phone
  throttles after ~4.5 minutes: short of 60 fps without native code. The
  blend costs ≤ 5 ms of GPU at full-resolution fields, 2.6 ms at half.
  Reported for spec-writer as the D94 native-contingency trigger.
