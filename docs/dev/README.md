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
| `src/components/` | Reusable level components, configured in the editor (see "Levels and components") |
| `levels/<id>/` | One folder per level, with its scenes. `levels/test/level.tscn` is the test level |
| `tests/unit/` | Unit tests, mostly on `src/sim/` |
| `tests/e2e/` | End-to-end tests: boot the game scene headless and drive it through test mode |
| `tests/e2e/scripts/` | Test-mode run files (JSON) used by the end-to-end tests |
| `tests/gut_post_run.gd` | The GUT hook that makes a broken suite fail (see below) |
| `tools/test.sh` | The one entry point for the test suite |
| `tools/greybox_test_level.gd` | Generates the test level's greybox scene (see "Levels and components") |
| `docs/dev/img/` | Screenshots used by these notes (`docs/.gdignore` keeps Godot from importing anything under `docs/`) |
| `spikes/` | Throwaway prototypes. Nothing else depends on them |
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

`Simulation` holds the whole game state. For now that is the tick, the
master `Rng`, an empty slime list and a record of the input received (the
fingers down, the last tilt, the last 64 input events). Each later chunk adds
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
translates. Otherwise scripted input would bypass it.

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
one place a test can set. Nothing rendered can be checked headless; for
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
| `SplitZone` | `Area2D` | `stable_id`, `size` | At the start of the loop (rule 4) |
| `FirstSlime` | `Node2D` | `stable_id` (`start.first-slime`), `species` | Where the first awake slime starts |
| `Sleeper` | `Node2D` | `stable_id`, `species` (A to E) | Always size 1 |
| `Switch` | `Area2D` | `stable_id`, `size`, `basket_id` | |
| `Basket` | `Area2D` | `stable_id`, `size`, `quota` (weight), `on_full_object`, `on_full_action` | Holds its rule (below) |
| `Gate` | `Node2D` | `stable_id`, `size` | Accepts the action `open` |
| `Signpost` | `Node2D` | `stable_id`, `switch_id` | |
| `FramingZone` | `Area2D` | `stable_id`, `size`, `zoom`, `offset` | `zoom` as `Camera2D.zoom`: below 1 shows more (0.7 is a zoom-out); `offset` in px, negative y is up |

`size` is a box centred on the node's position. The `Area2D`s make their
rectangle collision shape at load; the `Path2D`s draw their curve. Nodes a
component makes at load (terrain bakes, shapes) have no owner, so they are
never saved into the level scene. **No behaviour yet**: splitting, waking,
the switch, the basket's counting, the gate opening and the camera reading
the framing zones come in later chunks; this chunk places them, gives them
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
all as polylines in level pixels. The game root hands it to the simulation
(`simulation.level`); `simulation.dump()` records the level's ID and version.

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

### Chunk 2: spike: vector look

- Terrain is drawn as a `Curve2D`/`Path2D` baked into `Polygon2D` +
  `Line2D`, not an SVG texture, because it stays crisp when zoomed and an
  SVG texture blurs. See `docs/dev/spike-vector-look.md`.

### Chunk 1: spike: soft slimes

- Ring-of-springs slimes with a species-field blend shader hold 200 on one
  screen only if the simulation tick is native code, and the renderer stays
  Compatibility. See `docs/dev/spike-soft-slimes.md`.
