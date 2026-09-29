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
| `src/test_mode/` | Test mode: scripted input, time control, fixtures and saves to start from, the on-screen marker |
| `src/debug/` | The debug overlay, debug builds only: speed, reset, slime labels, the kill tool, the woken/available counter (see "Debug overlay") |
| `src/save/` | The save files (`SaveStore`: one per level, never wiped), autosave timing (`Autosave`) and the real clocks sessions count on (`SessionClock`); the save format itself is `src/sim/save_data.gd` (see "Saves and fixtures") |
| `src/session/` | The session's screen effects (`SessionScreen`: the dusk tint, keeping the screen on); the session logic itself is `src/sim/session.gd` (see "Sessions (chunk 17)") |
| `src/frontier/` | Frontier set drawing (`FrontierView`: doors, arrows, the basket's outlines, the celebration); the logic itself is `src/sim/frontier_sets.gd` (see "Frontier sets (chunk 14)") |
| `src/taps/` | Tap feedback drawing (`TapFeedback`: the ripples and the slimes' eye dots); the tap logic itself is in `src/sim/` (see "Taps and the call") |
| `src/slimes/` | Slime drawing (`SlimeRenderer` and its shaders), the terrain hand-off to the simulation (`SlimeWorld`) and the slime demo scene |
| `src/components/` | Reusable level components, configured in the editor (see "Levels and components") |
| `levels/<id>/` | One folder per level: `level.tscn` and `fixtures/`, found by ID (`src/level_catalog.gd`, see [level-tooling.md](level-tooling.md)). `levels/test/level.tscn` is the test level |
| `levels/<id>/fixtures/` | A level's fixtures: saves test mode starts from by name (see "Saves and fixtures") |
| `tests/unit/` | Unit tests, mostly on `src/sim/` |
| `tests/e2e/` | End-to-end tests: boot the game scene headless and drive it through test mode |
| `tests/e2e/scripts/` | Test-mode run files (JSON) used by the end-to-end tests |
| `tests/e2e/levels/` | Each level's generated test script, `test_level_<id>.gd` (written by `tools/new_level.gd`; not for the test level) |
| `tests/gut_post_run.gd` | The GUT hook that makes a broken suite fail (see below) |
| `tools/test.sh` | The one entry point for the test suite |
| `tools/greybox_test_level.gd` | Generates the test level's greybox scene (see "Levels and components") |
| `tools/bench_slimes.gd` | Times the slime tick (see "Slimes") |
| `tools/bench_offscreen.gd` | Times the off-screen fallbacks (see "Off-screen simulation (chunk 15)") |
| `tools/bench_level.gd` | Times the whole test level with its 200 slimes (see "Off-screen simulation (chunk 15)") |
| `tools/make_fixture.gd` | Writes a level's fixtures (see "Saves and fixtures") |
| `tools/check_level.gd`, `tools/level_check/` | The level-rules checker, rules 1 to 22, on any level (see [level-tooling.md](level-tooling.md)) |
| `tools/new_level.gd` | The new-level scaffolder (see [level-tooling.md](level-tooling.md)) |
| `tools/level_report.gd` | A level's population, frontier sets, framing zones and reach, for designers (see [level-tooling.md](level-tooling.md)) |
| `tools/level_builder/` | Helpers that write a level scene from the components by script (the test level's generator and the scaffolder use them) |
| `docs/dev/img/` | Screenshots used by these notes (`docs/.gdignore` keeps Godot from importing anything under `docs/`) |
| `docs/level-design/` | The tutorial for building a level, one task per page (see "Level-design tutorial and skills (chunk LD2)") |
| `.claude/skills/` | Project skills for Claude: `new-level`, `level-content`, `level-review` (same section) |
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
the last 64 input events), which placed slimes each slime is made of
(`identities`) and the objects' and gates' state by stable ID (empty until
chunk 14). Each later chunk adds
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
they survive a JSON round trip (see "Saves and fixtures"). Hashes are compared on one
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
	"level": "test",
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
- `level` (default `"test"`, chunk LD1): the level the run plays, by ID:
  `levels/<id>/level.tscn` (`LevelCatalog`, see
  [level-tooling.md](level-tooling.md)). When it isn't the loaded level,
  the game loads it first; an unknown ID or a level with load errors is an
  error naming what is missing, and the running game is left as it was.
- `fixture`: a fixture name (for the test level, from
  `specs/levels/test/README.md`): the run starts from
  `levels/<level>/fixtures/<name>.json` (see "Saves and fixtures"). An
  unknown name is an error naming the missing sidecar.
- `at` (chunk LD1): where the camera starts, on its rails nearest a stable
  ID of the level (a loop segment or a route back: its first point) or a
  level point `[x, y]`. It wins over the fixture's camera.
- `load`: a save file (`user://...` or a file path) to start from instead;
  not both `fixture` and `load`. A save's own seed wins over `seed`; a
  hand-made save without one plays on `seed`.
- `sessions` (default false): sessions on, as in normal play: the run
  opens in screensaver mode and a tap that reaches the world starts a
  session (see "Sessions (chunk 17)"). Off, the run plays untimed, as in an
  endless session; a fixture or save with a session or bedtime running
  counts down either way.
- `clock` (`{"away": seconds, "restarted": bool}`, default `{}`): what
  happened to the real clocks before the run starts: `away` seconds passed,
  and `restarted` (the app was killed or the phone restarted: a new
  monotonic epoch). Only meaningful with a save or fixture.
- `autosave` (default false): autosave during the run. Off, a run never
  writes a save; `game.save_now()` saves on demand either way (to the
  game's `save_store`, which a test sets before adding the game).
- `block_real_input` (default true): ignore the real mouse and touches.
- `screen_size` (`[width, height]`, default `[1152, 648]`): the screen size
  the simulation's view uses to dispatch taps (a headless window reports a
  wrong one). The game reads it in `sync_view()`; outside test mode it uses
  the viewport's size.
- `steps`: the input script (`src/test_mode/test_mode_script.gd`). `tick` is
  the tick the step happens on: its events are consumed by the step that
  advances that tick. `do` is `tap` (down and up on the same tick),
  `touch_down`, `touch_up`, `tilt` or `skip` (`{"tick": 150, "do": "skip",
  "seconds": 900}`: that much real time passes before the tick, as if the
  app sat in the background; the simulation doesn't run meanwhile, only the
  session's clocks jump). `at` is a viewport position; `finger`
  is 0 by default, 1 for a second finger. Steps may come in any order. A typo
  in a key or a missing value is an error naming the step.

The game root takes a run with `enable_test_mode(config)`, which returns the
errors (empty when test mode is on) and starts a simulation from the seed:
fresh, or from the fixture's or `load`'s save (checked against the level
first). Then `game.test_mode.run_ticks(n)` runs n ticks at once (skipping
time) and `run_until(tick)` runs up to a tick.

From the command line (a debug build):

```sh
godot --headless -- --test-mode --test-script=res://tests/e2e/scripts/backbone.json --run-ticks=600
# prints: STATE tick=600 hash=<sha256>, then quits
```

Flags: `--test-script=PATH` (res:// or a file path), `--seed=N`,
`--time-scale=X`, `--fixture=NAME`, `--level=ID`, `--at=ID` or
`--at=X,Y` (these override the file),
`--load=PATH` (start from a save), `--run-ticks=N` (run N ticks at once,
print the hash, quit), `--print-state` (also print the state as JSON) and
`--save=PATH` (with `--run-ticks`: then save to PATH, for kill-and-reload
across processes). A run that can't start
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
`src/test_mode/*`, `src/debug/*` (the debug overlay, same guard, see "Debug
overlay"), `tests/*`, `addons/gut/*`, `levels/test/*` and `spikes/*`, and a
CI check must confirm it:

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
| `Sleeper` | `Node2D` | `stable_id`, `species` (A to F; F since chunk LD1, for v1's six species) | Always size 1 |
| `Switch` | `Area2D` | `stable_id`, `size`, `basket_id`, `trapdoor` (a box relative to the switch) | Tappable. Its trapdoor is solid while the flow goes onward, open while flipped (see "Frontier sets (chunk 14)") |
| `Basket` | `Area2D` | `stable_id`, `size`, `quota` (weight), `on_full_object`, `on_full_action`, `outlet` (`onward_route` or `point`), `outlet_before` (px), `outlet_point` | Holds its rule (below). Its box is where caught slimes rest |
| `Gate` | `Node2D` | `stable_id`, `size`, `entrance_lid` (a box relative to the gate) | Accepts the action `open`. Its box is solid while closed; its lid shuts the old slide entrance once open |
| `Signpost` | `Node2D` | `stable_id`, `switch_id` | Not interactive: the game draws its arrow the way its switch sends the flow |
| `FramingZone` | `Area2D` | `stable_id`, `size`, `zoom`, `offset` | `zoom` as `Camera2D.zoom`: below 1 shows more (0.7 is a zoom-out); `offset` in px, negative y is up |
| `Decoration` | `Path2D` | `curve` (a closed outline), `fill_color`, `in_front` | Scenery that is neither terrain nor an object (chunk LD1, O96's proposed default, D123): it never collides, has no ID and is never a tap target (a tap on it is a call), and draws behind the level unless `in_front`. The checker fails one in front that covers an object or a hint (rule 9). No ID |

`size` is a box centred on the node's position. The `Area2D`s make their
rectangle collision shape at load; the `Path2D`s draw their curve. Nodes a
component makes at load (terrain bakes, shapes) have no owner, so they are
never saved into the level scene. The split zone splits and the first
slime is woken (chunk 6, see "Train"). The camera reads the framing zones
(chunk 13, see "Camera"); the switch, the basket and the gate work through
`FrontierSets` and the signpost is drawn by `FrontierView` (chunk 14, see
"Frontier sets (chunk 14)"). The level places them, gives them IDs and
checks the references.

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
accepts the action. `Level.build()` copies every rule into
`LevelData.rules`; `FrontierSets` runs a basket's rules when it fires
(chunk 14).

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

`levels/test/level.tscn` holds the whole test level as a greybox that
follows `specs/levels/test/README.md`, with its 200 base slimes: section 1,
Meadow (screens 0 to 8): the start basin with the split zone and the first
slime, the hills, the fusion dip, the high step, the tree (an exploration
branch with its route back and framing zone), frontier set 1 and slide 1
back to the basin; section 2, Caves (screens 8 to 12.66, chunk 15, see
"Off-screen simulation (chunk 15)"); and section 3, Big bowl (screens 12.66
to 16.55, chunk 16, see "Test level sections 2 and 3, full population
(chunk 16)").

Chunk 6 adjusted the greybox where a train slime couldn't pass (the
tables in the generator say where):

- the start basin's lip and the loop's start (moved to 0.64 and 0.3 in
  chunk 6, with a hump in the tunnel's floor under the lip) were rebuilt in
  chunk 16e (below);
- the crust top runs on to 6.49, closing the 58 px notch over basket 1's
  pit where a slime wedged (the pit has no entrance yet: the switch chunk
  decides it);
- the high step's underside is at -210 (was -170) and the tree's climb
  starts at 4.72, -208 (was 4.62, -140): a size-2 or size-3 slime hopping
  under them wedged on their corners;
- the chute into slide 1 is wider at the top (the near wall starts at 7.5,
  was 7.56) and its far wall is upright down to y = 30, so a slime falling
  in isn't thrown back up onto the ledge.

Chunk 14 built frontier set 1 into it:

- basket 1's pit is open at the top, under switch 1's trapdoor (6.5 to
  7.29, y -100 to -75): the old crust bridge over it is gone; the basket's
  box is 0.81 screens wide, 200 px deep, centred at 6.895;
- the "Pillar" (7.66 to 8.5) replaces the bedrock's far wall of the chute:
  its top carries the loop on to gate 1 (at 8.58); gate 1's lid (7.49 to
  7.67, y -100 to -68) covers slide 1's entrance once the gate is open;
- a stub of section 2: `s2.loop` (section 2, outgoing, 7.6 to 8.58 at
  y = -124, through the gate) and `s2.slide` (its return route, no gate,
  down the shaft past 8.66 and back along slide 1's tunnel), so opening
  gate 1 has a loop to grow into. Chunk 15 replaced them with section 2.

Chunk 16e rebuilt the start basin (DoD 1, rules 1 and 2). Before, the
slides' tail ran back along the basin floor over the loop's first stretch,
so every slime coming home met the train head on and shoved it back, and
the first sleeper's ledge (80 px over the floor) let only base slimes pass
under it at pace. Now the slimes come home behind the loop's start:

- **The terrace:** the loop's first stretch runs on a terrace, the crust's
  left end, top y 460 from 0.26 to 0.6 (flat past the first sleeper's
  ledge, so no hop takes off steeply from under it), then climbs out of the
  basin at 35-38° (0.66, 410; 0.75, 330; 0.9, 200) to the hills. Its
  underside (the lane's roof) is y 500 from 0.26 to 0.6, then 470 at 0.66
  and 420 at 0.78. The old lip and its hump are gone.
- **The lane:** the slides run home under the terrace, along the bedrock's
  floor (0.78, 585; 0.64, 600; 0.28, 610), about 100 px high (94 px at the
  terrace's end: a size 3 is 79 px tall), then up a ramp to the loop's
  start at its top: 0.21, y 476 (the ramp's ground 0.28, 610; 0.255, 590;
  0.21, 500: 60° at the top, where the slide's carry still holds). The
  slides' last points are 0.78, 561; 0.64, 576; 0.28, 586; 0.255, 566;
  0.21, 476.
- **The pocket:** behind the loop's start, the basin floor y 500 from 0.05
  to 0.21, against the level's left wall (35 px thick: 0.03 to 0.04 at the
  floor). A slime coming home up the ramp at the slide's pace pops out
  there, behind the train, and hops on after it; the first slime starts
  there at 0.19, 476. From the loop's start the train hops up over the
  ramp onto the terrace (40 px up, 0.05 screens across): the loop's route
  rises from its start to 0.25, 416 (60 px up, above the ramp) and eases
  down onto the terrace (0.6, 436), so the hops clear a slime sitting in
  the ramp, and that slime, more than `OFF_ROUTE` from the loop, steers
  from the slide (the nearest route behind it) and is carried back up to
  the pocket. The pocket is wide enough for a size 3 coming home (split
  there into three) and the slimes behind it. Two earlier 16e layouts
  lost a part as stalled there: with a pocket half as wide and a ramp
  twice as long, the slimes piled up and blocked each other's hops out;
  with the route running straight from the loop's start to the terrace's
  corner, a slime in the ramp sat right at `OFF_ROUTE` from it, was held
  there as a loop slime half the time and blocked the hop out.
- **The first sleeper** (`s1.sleeper.01`, B) sits at 0.46, 311 on
  `FirstLedge` (0.42 to 0.5, top y 335, 20 px thick: 105 px over the
  terrace), 0.27 screens right of the first slime (352 px away). A called
  base slime can hop onto the ledge (its `max_rise` is about 133 px), and
  a hopping base slime passes under it with 20 px to spare. A size-2 or
  size-3 train slime couldn't pass under a ledge that low at its pace (its
  hop tops out 108 or 130 px over the ground), and a ledge high enough for
  them would be out of a called slime's reach, so:
- **The split zone** reaches past the ledge: x 0.03 to 0.54, y 370 to 560
  (the pocket, the ramp's top and the terrace), and only base slimes ever
  pass under the ledge. Nothing fuses in the basin either (a split zone
  has no fusion).

`tests/e2e/test_start_basin_e2e.gd` checks it: no slide runs within 48 px
of the loop's first 1.5 screens outside the join at its start (in every
gate state); a slime coming home doesn't shove the train slimes on the
terrace back (they moved back 0 to 15 px, against 37 to 109 px before);
a size-3 slime coming home with two base slimes behind it is split and all
five are 0.15 screens past the first sleeper within 30 s (18 s); a slime
of every size (split or whole) is past it within 10 s (6 to 7 s; before,
a size 2 or 3 never was).

The scene is generated by `tools/greybox_test_level.gd` from tables of
points (x in screens, y in px), written since chunk LD1 on the builder
helpers of `tools/level_builder/` (the same output):

```sh
godot --headless -s res://tools/greybox_test_level.gd
```

It is still a normal scene that opens and edits in the editor, but a
re-run overwrites hand edits. Once the level is edited by hand for real,
delete the generator. `tests/e2e/test_test_level.gd` checks the scene
against the design and the level rules: every ID of sections 1 to 3, the
population (200 base slimes by species and section), sleepers off the loop,
the first sleeper near the first slime, the loop and the slides, the split
zone at the start (the start basin itself: `tests/e2e/test_start_basin_e2e.gd`), routes back that start in their branch, end on the loop
and only go down, the frontier sets, the framing zones and the terrain bake.
The level rules over the whole level are in `tests/e2e/test_level_rules.gd`
and `tests/e2e/test_level_ways_back_e2e.gd`, and DoD 1 in
`tests/e2e/test_level_dod1_e2e.gd` (chunk 16).

**Adding a section** (as sections 2 and 3 were): add its terrain; add its
outgoing `LoopSegment`s (`section = n`) after the previous section's
outgoing segments in the `Loop`, the first starting where the previous
section's loop ends (behind its gate), then its slide (`kind = return`,
with the section's own gate as `gate_id`, none for the last section)
ending at the start of the loop, joining the previous slide's tail; place
its things with `s<n>.` IDs; extend the tests' expected IDs and the
fixtures (`tools/make_fixture.gd`).

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
- inside or outside is the side of the nearest segment's normal, except
  where the nearest point is a segment's end (a vertex): there it is the
  side of the vertex's normal, the mean of its two segments' normals
  (`seg_na`, `seg_nb`, `TerrainSegments.side_normal`; the solver inlines
  it). Before chunk 16d the segment's own normal decided there too, and at
  a sharp convex corner both segments are equally near: when the one
  listed first was the other face's, a wedge outside the corner (up to
  about 25 px out at the dip hollows' lips) counted as inside, and ring
  points passing through it were pulled onto the corner. That threw
  heading-back slimes back into the dip hollows and off the hills' bumps
  (the rule 7 breaks 16c found), and it could stick a ring round a piece;
- friction (0.4) takes from the tangential velocity and the inward normal
  velocity is zeroed;
- a surface whose normal points up by more than 0.3 marks the slime
  `supported` (it may hop).

Limits: a point deeper than `MARGIN` inside a piece is not seen, so terrain
pieces must be thicker than about 32 px, and pieces must not overlap or
share edges (a point between two could be pushed into the other). At the
speeds capped by `max_speed` (1200 px/s, 10 px per substep) points never
get that deep. The test level's floating ledges are 20 to 25 px thick (the
hills' bumps, the section 2 ledges and cave pieces, section 3's shelves,
ramp ledges and rim), under that: a point more than half their thickness
in is nearer the far face and is pushed out there, so a ring that hits a
ledge's end hard can end up split over its top and bottom faces with its
centre inside the ledge. The corner fix removed the hard hits seen so far
(chunk 16d); none of the 199 sleepers' spots strands a slime.

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
progress), then `train.follow()` (progress, laps, stalled slimes).
`train.dump()` is in the state dump.

![The first slime hopping along the loop from the start basin](img/train-first-slime.png)

**Progress.** A slime's progress is re-derived every tick by projecting its
centre onto the loop, but only onto a window from its last progress to
`PROGRESS_WINDOW` (400 px) ahead. It never goes back (a slime bumped back
keeps its progress), and it can't snap to a part of the loop that is close
in space but far along it (the slide runs back under the outgoing route).
Past the end it wraps and counts a lap. A slime knocked more than
`OFF_ROUTE` (36 px) off the route at its progress (thrown back out of the
chute onto the ledge, fallen short of the start basin's terrace onto the
ramp) steers from the
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

**Stalled (D118, D121; chunk 23A).** A train slime is stalled when its
progress hasn't advanced `STALL_ADVANCE` (24 px) in `STALL_SECONDS` (60 s),
on screen or off, or when its centre leaves the level's bounds (the
terrain and the loop, plus 64 px, plus 2000 px above). `train.follow()`
then moves it to the start of the loop, back on the train (`LoopStart.move`,
the move lost and stuck slimes take too), and logs the case in
`train.stalled` (`{"id", "tick", "reason"}`, `stalled` or `out_of_bounds`,
the last 64): every case, and the 60 s count starts again from the move. A
slime asleep at bedtime isn't a train slime, so it has no count and is never
moved. The whole-level DoD 1 test still fails on any logged case. "Lost" is
for free slimes only: a free slime left alone off screen is lost by
`Offscreen` (see "Off-screen simulation (chunk 15)"). `advance()` only
re-derives the progress and its mark; `stall_of()` says whether a followed
slime is stalled. See "Safety nets: stuck and stalled slimes (chunk 23A)".

**Split zones.** `SplitZones` (`src/sim/split_zones.gd`) holds the level's
split zone boxes. Every tick, every slime above size 1 whose centre is in a
zone is split (`SlimeBodies.split`) into base slimes, which keep its
species and state: train slimes stay on the train. Nothing else splits.

**Waking the first slime.** `Simulation.load_level` creates the level's
first slime (size 1, its species, a train slime) at its marker when the
state is fresh (tick 0, no slimes): a restored state keeps its own slimes.
It also puts every sleeper to sleep at its marker (chunk 9, see "Sleepers,
waking and the hint").

**Tests.** `tests/unit/test_train_progress.gd` (progress window, wrap,
laps, stalled and out of bounds, aim, targets, off-route steering),
`tests/unit/test_train_stalled.gd` (the stalled safety net) and
`tests/unit/test_split_zones.gd`; `tests/e2e/test_train_in_game.gd`
(the first slime woken, each size 1 to 3 completes a lap and comes back as
base slimes, a size 3 and a size 2 entering the split zone leave as five
base slimes on the train); `tests/e2e/test_train_session_e2e.gd` runs a
15-minute session (54 000 ticks) with no input and checks the first slime
is never lost, its progress never goes back, it makes at least 4 laps (0.7
of the ideal pace; it makes 5) and the same seed gives the same hash twice.
It takes about 2 s per run, 4-5 s for the test. Chunk 16e rebuilt the
start basin so slimes coming home no longer meet the train head on (see
"The test level").

## Safety nets: stuck and stalled slimes (chunk 23A)

Build plan items 23.3 (D100, `rule_stuck_slimes_moved_to_start`) and 23.13
(D121, `rule_stalled_train_slime_moved_to_start`). Three cases now send a
slime to the start of the loop, back on the train, each logged with its own
reason: a **lost** free slime (D10, `Offscreen.lose`, reason `lost`), a
**stuck** slime (D100, `StuckSlimes`, reason `stuck`) and a **stalled**
train slime (D121, `Train.follow`, reason `stalled` or `out_of_bounds`).
"Lost" is for free slimes only (the lexicon); none of the three counts as
another.

**One move: `LoopStart.move(bodies, train, id)`** (`src/sim/loop_start.gd`).
The lost timer's move (chunk 15), taken out of `Offscreen` so the three
share it: the slime's centre goes to the loop point lifted by its size
(`Offscreen.lift`), at rest and unsupported (a parked slime is only
translated), state train, hops no longer held, and the Train follows it
from there with a fresh record (laps and stall count start again). New:
**a free spot.** Two rings put on one centre never come apart (the stuck
case itself: a probe put a size-1 and a size-2 of different species on one
centre, and they stayed within 1.4 px for 6 s), so the move doesn't land on
a slime already there: it takes the first of `SPOTS` (8) spots one width of
the slime apart along the loop from its start (0, 48 px, 96 px, ... for a
base slime) whose room is clear of every other slime's ring, else the start
itself. On the test level the first slime waits at the start, so a slime
sent there by the debug kill tool lands one width on.

**Stuck (23.3).** `StuckSlimes` (`src/sim/stuck_slimes.gd`,
`simulation.stuck_slimes`) runs in `Simulation.step` right after
`train.follow()`. On every tick that is a multiple of `CHECK_TICKS` (30,
0.5 s) it looks at the simulated slimes (not parked; every state): a pair
whose centres (the mean of their points: `SlimeBodies.centre` is a
mid-substep estimate, several px off in a squeeze, and missed pairs) are
closer than `CLOSE_SHARE` (a quarter) of the smaller ring radius counts one
more check; any other pair loses its count. A pair about to fuse is never
counted: `SlimeBodies.can_merge` (same species, sizes up to 3) and both
awake (train or free, Fusion's rule; a same-species sleeper inside a train
slime is counted). At `CHECKS` (4) checks in a row (about 2 s; 1.5 s from
the first check that saw it) the pair is stuck: the smaller slime, on a tie
the higher id, among those of the two that are train or free slimes, goes
to the start (`LoopStart.move`) and its counts go. When neither may move
(sleepers, slimes in a basket, bedtime-asleep slimes) the pair is only
logged, once while it stays so. The log, `stuck_slimes.stuck`, keeps the
last `LOG_SIZE` (64) cases `{"id", "other", "tick", "reason": "stuck",
"moved"}`; it and the counts are in the state dump (`"stuck_slimes"`) and in
saves. The pairs come from one sweep along x (a native sort of the centres,
then only neighbours within the largest threshold): one check with 200
simulated slimes costs 0.39 ms, about 0.013 ms a tick on average. The
level bench (`tools/bench_level.gd`), run A/B interleaved on a busy machine
(A as built, B with the check's call taken out), shows nothing above the
noise: stress-moving median 36.8 and 34.4 ms (A) against 34.3 and 34.1 ms
(B), mean 37.8 and 38.4 against 36.1 and 38.4; start 1.12 to 1.24 and
stress-still 1.54 to 1.68 in both. Before the chunk, on the same machine,
stress-moving was 30.9 ms median (32.6 mean) under a lighter load.

**Stalled (23.13).** Chunk 6's stall check in `Train` only logged. It now
moves the slime (see "Train", "Stalled"). The renames: `Train.lost` is
`Train.stalled`, `LOST_STALL_SECONDS` / `LOST_STALL_ADVANCE` /
`LOST_STALLED` / `LOST_OUT_OF_BOUNDS` are `STALL_SECONDS` / `STALL_ADVANCE`
/ `STALLED` / `OUT_OF_BOUNDS`, the train record's `lost` flag is gone (it
kept a slime from being logged twice; now each case is logged and moved)
and `advance()` no longer checks: `stall_of()` does, from `follow()` only,
so a parked slime's progress (moved by `Offscreen`) is checked once a tick
like any other. The log keeps the last `STALL_LOG_SIZE` (64) cases. The
whole-level DoD 1 test still reads it (`train.stalled` with
`offscreen.lost`) and fails on any entry: the safety net is for play, not
a pass.

**`Offscreen.lose(sim, id)`** is public (it was `_lose`); the debug
overlay's kill tool (`DebugKill.send_to_start`) calls it directly, and its
"unavailable" case is gone.

**Saves.** Format 1 still, extended: an optional `"stuck_slimes"` key
(counts and log), and `train.stalled` for the train's log (the old
`train.lost` key and the train record's `lost` flag are ignored when read).
See "What a save holds".

**Values not in the spec (proposed):** the free spot (`SPOTS` 8, one width
of the slime apart), the log sizes (64 cases each), and which pairs "about
to fuse" means (both awake). The rest is D100 and D121: 30 ticks, 4
checks, a quarter of the smaller radius, 24 px in 60 s.

**Tests.** `tests/unit/test_stuck_slimes.gd` (13: two species on one
centre, the tie, a free slime, a same-species pair too big to fuse, one
that can fuse left to fuse, pairs touching normally never moved, only train
or free slimes move, a pair that can't move logged once, parked slimes
skipped, the free spot, dump, a save mid-count, same seed same hash);
`tests/unit/test_train_stalled.gd` (7: wedged, the move and the log at 60
s, wedged again moved again, out of bounds, bedtime-asleep never counted
and a fresh count from waking, a save mid-count, same seed same hash, the
log's size); `tests/unit/test_train_progress.gd` (`stall_of`);
`tests/e2e/test_safety_nets_e2e.gd` (through the game: two base slimes on
one centre on the test level, and from `wind-down` over 70 s of bedtime no
bedtime-asleep slime counted as stalled or moved).

## Taps and the call

Master spec §5.2 and §5.5. All of it is simulation logic in `src/sim/`
(`ScreenView`, `TapDispatcher`, `FreeSlimes`, driven by `Simulation`);
`src/taps/tap_feedback.gd` only draws.

![A tap on the hills: the ripple, and the first slime hopping back to it](img/chunk7-call.png)

**The view.** Taps arrive in screen pixels, so the simulation holds a view,
`simulation.view` (`ScreenView`): the level point at the screen's centre,
the zoom and the screen size. `main.gd`'s `sync_view()` sets it from the
simulation's camera (`Camera.apply_to()`, see "Camera" below) before and
after every tick; the screen size is test mode's `screen_size` in test
mode, else the viewport's. `world = centre + (screen - size / 2) / zoom`.
The view is in the dump.

**Tap zones** (`TapDispatcher.dispatch`), checked in this order:

| Order | Zone | Where | Does |
|---|---|---|---|
| 1 | `parent_zone` | a band `PARENT_ZONE_MM` (7 mm) high along the top, measured on the screen: `parent_zone_height(view)` screen px (about 67 on the reference phone) | nothing yet (parent buttons, chunk 18); never calls |
| 2 | `edge_button` | a strip `EDGE_STRIP_SHARE` (10%) of the screen's width against each side, from the parent zone to the bottom (`edge_button_rect(side, view)`) | moves the camera along its rails (`Camera.press`, see "Camera"); never calls, operates no object under it |
| 3 | `object` | the hit area (`hit_area(kind, box, view)`) of a tap target that answers a tap now: an object's drawing plus 5 mm a side, at least 20 × 20 mm, on the screen (chunk 23E below); a sleeper's body plus 24 screen px | a **switch** whose basket is filling flips (chunk 14); a **sleeper** calls, centred on it |
| 4 | `open_ground` | anywhere else | calls, centred on the tap |

Tap targets come from the registry: `Level.build()` adds every node with a
`tap_target()` (switch, basket, sleeper) to `LevelData.tap_targets` (ID,
kind, level box). Only those that answer a tap now reach the dispatcher
(`FrontierSets.answering()`, chunk 23E below). Where hit areas overlap, the
nearest box centre wins (ties: the smaller ID). The zones' sizes are the spec's (D99, D113;
chunk 23B below); how they are drawn is a placeholder until the ui_ux tree
settles it.

**First touch wins** (D66, O67's proposed default). A tap is dispatched
when its finger touches down, and only if no finger is down then
(`active_finger`). A touch that starts while any finger is down gets
nothing, not even a ripple, and stays ignored until it lifts, even if the
first finger lifts before it. `fingers_down` still records every finger.
One exception, a resting thumb (D110, chunk 23B below): a finger that
pressed an edge strip and has been down 5 s stops blocking other touches.

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
restarts its 8 s. Sleepers don't answer: a free slime's touch wakes them
(see "Sleepers, waking and the hint"). A free
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
   always at least `MIN_SIDEWAYS` (60 px) sideways. When the loop point is
   more or less right below, it hops the loop's way there, level with where
   it stands (chunk 9: aiming down at the loop, the hop came down after
   about 30 px and a slime woken on a ledge stayed stuck on its corner).

The rule was not changed for the rule 7 breaks chunk 16c found (slimes left
in the dip hollows and on the hills' bumps): those were the terrain's sharp
corners pulling ring points onto them ("Terrain contact"), and with that
fixed every sleeper's spot of the test level leads back with this rule
(`test_level_ways_back_e2e.gd`; a scratch sweep of all 199 spots on seeds
1, 2, 3 and 909 left none stuck). `tests/unit/test_heading_back.gd` keeps
the two shapes (a hollow with 20 px lips, a thin ledge's high end facing
another across 104 px) on a synthetic world.

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

### Chunk 23B: edge strips, the parent zone at 7 mm, a resting thumb

Build plan items 23.2 (D99), 23.6b (D113) and 23.8 (D110); master spec
§5.5.

**Millimetres on the screen.** `ScreenView.px_per_mm` is how many
viewport px make a millimetre on this screen; `view.mm_to_px(mm)` converts,
whatever the zoom. It is the one place sizes measured on the screen come
from (the parent zone now; objects' hit areas, D109, next). It defaults to
the reference phone's, `ScreenView.REFERENCE_PX_PER_MM`: the S20 FE's
about 405 ppi over its 1080 / 648 physical px per viewport px (the
project's stretch is canvas_items, aspect expand, so its 2400 × 1080
screen is `REFERENCE_PHONE_SIZE`, 1440 × 648 viewport px), about 9.57 px
per mm. `main.gd`'s `screen_px_per_mm()` sets it at every `sync_view()`: on
a phone, `ScreenView.px_per_mm_for(DisplayServer.screen_get_dpi(), window
px / viewport px)`; in test mode and on the desktop, the reference phone's
(runs match everywhere, and the desktop shows the phone's layout). A
phone reading of 0 or less is reported with `push_error` and the reference
used. Tests set `view.px_per_mm` directly; a value of 0 or less is refused
loudly. It is not in the dump nor in saves: it belongs to the display, like
the window, and what it decided is in `taps`.

**The parent zone** is `TapDispatcher.parent_zone_height(view)` =
`mm_to_px(PARENT_ZONE_MM)` (7 mm) screen px from the top, full width: about
67 px on the reference phone (64 before). Level rule 21 (objects below the
parent zone, item 23.9) measures against the same function.

**The edge strips** (`TapDispatcher.edge_button_rect(side, view)`): 10% of
the screen's width (`EDGE_STRIP_SHARE`) against each side, from the parent
zone down to the bottom: 115.2 px wide on the default 1152 × 648 screen,
144 on the reference phone's. The parent zone is checked first, so it wins
in the top corners; a strip is checked before objects, so it takes the
whole tap (no call, no object operated). Hidden at bedtime as before: a tap
there is an ordinary tap (which at bedtime only ripples). A strip tap never
starts a session (unchanged: only open ground and objects do).
`EdgeButtons` draws the placeholder arrow in the middle of each strip,
sized from the strip's width (45% wide, 80% tall); the strip itself isn't
marked (ui_ux decides).

**A resting thumb** (`Simulation.edge_holds`, `RESTING_THUMB_TICKS`). Each
accepted edge-strip press records its finger and touch-down tick in
`edge_holds` (dropped when the finger lifts). A touch starting now counts
when every finger down is a resting thumb: in `edge_holds` for at least
`RESTING_THUMB_TICKS` (300, 5 s). The resting finger keeps holding its
strip (the camera keeps moving); the new touch becomes `active_finger` and
the first-touch rule applies to it as usual. A touch that started before
the 5 s is an ordinary ignored finger and keeps blocking until it lifts.
`edge_holds` is in the dump (`input.edge_holds`, finger as a string ->
tick), not in saves (no finger is saved).

Values the spec doesn't give, chosen here (proposed): the reference
phone's density for the desktop and test mode; exactly 300 ticks for "about
5 s"; the resting thumb applies only to an accepted strip press (a finger
held on open ground keeps blocking).

**Tests.** `tests/unit/test_edge_strips.gd` (synthetic loop with a switch):
taps at the top, middle and bottom of each strip step the camera and never
call; 1 px inside a strip's inner edge presses, 1 px past it calls; the top
corners are the parent zone; a switch under a strip isn't flipped (and
flips once brought inward); 8 mm down a strip on the reference phone moves
the camera, 6 mm is the parent zone; strip taps in screensaver mode start
no session; at bedtime a strip tap moves nothing (against a twin run); the
resting thumb: a second touch after 5 s calls with its ripple, one before
gets nothing, one started before 5 s keeps blocking, the new touch is the
first touch again, a held touch off the strips never rests, `edge_holds`
in the dump. `tests/unit/test_tap_dispatch.gd`: the strips' rectangles and
whole height, the parent zone at 7 mm (6 mm parent, 8 mm a call or a press,
the zoom ignored, the density followed). `tests/unit/test_screen_view.gd`:
the reference density and the conversion. `tests/e2e/test_camera_e2e.gd`:
the game sets the reference density in test mode.

### Chunk 23E: hit areas on the screen, only what answers a tap takes it, objects below the parent zone

Build plan items 23.6, 23.7 and 23.9 (D109, D111); master spec §5.4, §5.5.

**Hit areas held on the screen** (item 23.6). `TapDispatcher.hit_area(kind,
box, view)` replaces the fixed 24 px margin. An interactive object's hit
area is its drawing grown by `HIT_MARGIN_MM` (5 mm) on every side, then
widened and heightened about the drawing's centre to `HIT_FLOOR_MM` (20 mm)
where it is smaller, both measured on the screen (`view.mm_to_px()`,
divided by the zoom for level px). Zooming out shrinks the drawing on the
screen, never the floor. The test level's switches are 80 px, about 8.4 mm
on the reference phone: plus 5 mm a side is 18.4 mm, so the floor holds
and the hit area reaches about 5.8 mm past the drawing at zoom 1 (6.7 mm at
zoom 0.8). A sleeper is a slime, not an object: its hit area stays its body
plus `SLEEPER_HIT_MARGIN` (24 screen px, D91) (proposed; D109 sizes
objects). With the 20 mm floor, a sleeper box would turn every tap within
about 1 cm of a sleeper into a call centred on it. Overlaps still go to the
nearest box centre (D109). `object_at(world, view, targets)` now takes the
view (zoom and density), not the zoom.

**Only what answers a tap takes it** (item 23.7).
`Simulation._tap` passes the dispatcher only
`frontier.answering(sim, Sleepers.tap_targets(sim))`. A switch is kept
while `switch_answers()`, which is while its basket is `filling`. A basket
is never kept. Other kinds (sleepers) pass. So a tap on a basket, a gate,
a signpost (gates and signposts were never tap targets), or a switch whose
basket is full, rewarding or fired is open ground. It is a call centred
on the tap, the slimes in range answer, and in screensaver mode it starts
a session (as any tap that reaches the world). Where a filling basket's
switch and a basket overlap, the switch takes the tap even when the
basket's centre is nearer: a target that doesn't answer doesn't compete.
`tap_switch()` flips only when `switch_answers()`. Baskets stay in
`LevelData.tap_targets` (the registry and rule 21 use them).

**Level rule 21: objects below the parent zone** (item 23.9, D111).
It is the level-rules checker's rule 21 (chunk LD1's
`LevelRulesObjects.below_parent_zone`, `tools/level_check/rules_objects.gd`),
reworked here rather than duplicated:
- `parent_zone_objects(data)`: the interactive objects checked, every
  switch, basket and gate by its drawn box (signposts aren't interactive;
  sleepers are slimes). LD1 checked the switches and baskets.
- The views: `LevelChecker.rail_frames(section, screen_size)` for every
  section (its outgoing route, the gates before it open, framing zones
  included, every 32 px), now on the reference phone's screen (1440 × 648
  viewport px); each frame also carries its `ScreenView` ("screen"). Every
  object is checked against every section's rails (LD1: its own
  section's), so the whole level is covered.
- `parent_zone_findings(data, views)`: for each object, the view where its
  top goes deepest into the parent zone (`TapDispatcher.parent_zone_height`
  at that view), among the views that frame it (its centre within the
  view's width); an object framed above the screen's top counts. A pure
  function over any views. The checker turns each into a finding at the
  rail point's x.

Readings taken (proposed): "the rails' framing" is the settled view on the
outgoing routes' rails. The return routes (slides) also have rails, and
from them the camera frames some objects from below, their tops in the
band or cut off by the screen's top (in the test level: s1.basket, s1.gate,
s2.gate, s2.switch and s3.switch, from the slides). Those views aren't
where a child meets the objects; the rule's wording doesn't settle it. On
the outgoing rails every object of the test level clears the band by at
least 150 screen px.

**Edge strips and the test level** (D99, report only; no geometry moved).
With the camera aimed at basket 1 (the rail point nearest it, zoom 1) on
test mode's default 1152 × 648 screen, switch 1 (x 46 to 126) has its
centre inside the left strip (0 to 115): a tap on it presses the strip.
On the reference phone's wider 1440 × 648 screen it is clear. Basket 1
(933 px wide) always reaches into a strip when aimed at the gate or switch
1, and baskets 2 and 3 partly do from gate 2 and switch 3, but a basket
doesn't answer taps. No framing zone puts an object inside a strip.

**Tests.** `tests/unit/test_object_taps.gd` (synthetic level; switch, basket,
gate and signpost in call range of the first slime): at zoom 1, 4 mm
outside the switch flips it and 6 mm calls (left and below); the 20 mm floor at
zoom 0.8; the density followed; a filling basket's switch flips; a tap on
the basket, the gate, the signpost, or the switch with its basket full, in
its reward, or fired, calls and the slime answers; overlapping hit areas
go to the answering switch; in screensaver mode each of those calls starts
a session; `answering()` directly.
`tests/unit/test_tap_dispatch.gd`: `hit_area()` (5 mm a side, the floor,
centred, zoom, density, a sleeper's 24 px), the margin in mm at zoom 1 and
0.5, and a basket tap in the simulation calls.
`tests/e2e/test_object_taps_e2e.gd` (test level): switch 1 at zoom 1 (4 mm
flips, 6 mm calls); in `s3.frame.basket` (zoom 0.8, from `gate2-open`),
0.5 mm inside the floor's edge flips switch 3 and 0.5 mm past it calls. From
`gate1-open` in screensaver mode, taps on basket 1, gate 1, signpost 1 and
the inert switch 1 call exactly the slimes in range and start a session.
Switch 2 (basket filling) still flips.
`tests/e2e/test_level_checker.gd` (the base level): a switch in the band
fails (LD1's test); 1 px below the band passes and 1 px inside fails; a gate
in the band fails; an object framed above the screen fails; a framing
zone's framing counts; which objects. `tests/e2e/test_level_rules.gd`: rule
21 passes on the whole test level, and every object is on screen in some
rail view (599 views). `tests/e2e/test_frontier_e2e.gd`'s DoD 13 test now expects the tap
on the inert switch 1 to be a call (it asserted "the tap does nothing").

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
it. The session takes it (chunk 17, D95): when a session starts, and again
when a running session comes back after the app was in the background or
killed (see "Sessions (chunk 17)"). Loading a level no longer takes it (the
chunk 11 placeholder is gone). Angles wrap at ±180°.

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

## Camera

Master spec §5.6, tap zone 2 of §5.5, DoD 18 (in part). `Camera`
(`src/sim/camera.gd`) is pure logic owned by the simulation
(`simulation.camera`): where the view is decides where taps land and how far
the call reaches, so it is deterministic and scriptable like the rest. It
steps after the train in `Simulation.step()`. This replaces "The view" of
chunk 7 above: `camera_centre()`, the Camera2D's limit clamp and
`CAMERA_OFFSET` are gone.

**Rails.** On the rails the camera's place is `distance`, px along the
current loop (`LoopData.current_segments` for the open gates), return
routes included: each section's slide has its own rail. Its point is
`loop.position_at(distance) + RAIL_OFFSET` (0, -120: the view shows more
above the route than under it; one constant, a framing zone's `offset`
shifts it where needed, below). **Forward is increasing distance** whatever the
direction on screen: forward along a slide, which runs right to left, moves
the view left, round the frontier turn and back toward the start; the rail
wraps at the loop's end like the train. When a gate opens and the loop
changes, the camera finds the nearest point on the new loop and doesn't
jump. `Simulation.load_level()` starts it on the rail point nearest the
first slime (the loop's start without one).

**Edge buttons** (O70's proposed behaviour, D95). A tap in an edge button
zone (`TapDispatcher`, first touch only) calls `camera.press(side, finger)`;
the finger lifting calls `release`. Right is forward, left backward; an
edge button never calls. A press sets the distance left to go
(`rail_left`) to at least `STEP` (a third of a screen, 384 px) that way; a
press the other way turns back. While the finger stays down the goal stays
a `STEP` ahead, so the camera moves at a steady `PACE` (¾ screen/s,
864 px/s). After the finger lifts it closes on the goal at `EASE` (5) times
the distance left per second, never faster than `PACE` nor slower than
`SETTLE` (30 px/s), so it eases to a stop without a final jump. A short tap
moves exactly one `STEP`.

**Call drag.** A call (`hit["call"]` in `_tap`) calls
`camera.on_call(point, tick, view)`, which outside the call's dead zone
(chunk 23C, below) calls `camera.follow_call(point, tick)`: the camera leaves the rails and moves
toward the call point at `DRAG_PACE` (a fifth of a screen a second,
230.4 px/s, "slow and steady"), for `DRAG_SECONDS` (the call's 8 s,
counted in ticks as `FreeSlimes` counts it) or until a new call replaces
the point. Then (`RETURN`) it glides back at the same pace to the rail
point nearest where it stopped, and is on the rails again. The return is a
tuning value the spec leaves open: this is the reading taken. An edge press
while off the rails puts the camera straight back on the rails at the
nearest point (`rail_gap` holds the difference, closed at `CATCH_UP`,
1 screen/s, so the view doesn't jump) and the press moves it on from there.
`camera.place(centre, zoom)` puts it off the rails for tests (it glides
back the same way); it isn't an input.

**Zoom and bounds.** `zoom` is the camera's; no input sets it (DoD 18):
framing zones, the idle cue and the idle camera do (chunk 13, below), and it
is 1.0 elsewhere. The only level bound is the old left edge, kept in the simulation:
`view_centre()` holds the view's centre so the view never shows left of
x = 0 (`LEVEL_LEFT`); the camera itself may sit nearer (the start basin's
first rail point is at x 345.6).

**The scene.** `main.gd`'s `sync_view()`, before and after every tick,
calls `simulation.camera.apply_to(simulation.view, size)` and sets the
Camera2D's position and zoom from the view: the Camera2D only mirrors the
simulation, with no limits. `EdgeButtons` (`src/taps/edge_buttons.gd`, on a
`Hud` CanvasLayer) draws a translucent placeholder arrow in each button's
rectangle, hidden when `camera.edge_buttons_visible` is false (default true;
bedtime hides them in chunk 17). The camera's whole state is in the dump
(`camera`), and `Camera.dump()` / `restore()` give it to saves.

![Holding the right edge button: the camera has moved from the start basin to the hills](img/chunk12-camera.png)

The screenshot is from a debug run with a display: a real left-button press
at the right button's centre, held 1.5 s, carried the camera from distance
0 to 1677.9 px along the loop, the Camera2D following.

**Tests.** `tests/unit/test_camera.gd` on a synthetic loop (a 3000 px rail
out, a slide back underneath, 6800 px): starting on the nearest rail point,
one step per short press, at least one step per press, the left button
wrapping onto the return route, a steady pace while held then easing,
turning back, forward moving the view left on a right-to-left rail,
rounding the frontier to the start, a gate opening without a jump, the
drag's pace and 8 s, the glide back, a new call restarting the drag, an
edge press off the rails without a jump, the zoom never changing, the
buttons shown by default, the view's left edge, determinism and restore;
and through the simulation, an edge tap moving the camera and never
calling, hold and release, a second finger doing nothing, a call dragging,
and the camera in the dump. `tests/e2e/test_camera_e2e.gd` on the test
level: a right hold goes through section 1 up to the frontier turn, back
along slide 1 (the view moving left) and into the start basin; a left hold
goes the other way; a call by the tree drags the camera for 8 s and it
comes back to the rails by the tree; the Camera2D mirrors the simulation at
zoom 1; a scripted run gives the same hash twice. `test_call_e2e.gd` aims
the camera with `camera.place()` now, not by moving the Camera2D.

**Choices.** The camera lives in the simulation, not the scene, so taps and
scripted runs see the same view. The view is set in `sync_view()`, not
inside `Simulation.step()`, so unit tests that set `sim.view` by hand keep
working. The drag and the return share one pace. A per-segment rail offset
was left out: framing zones cover it.

### Framing zones (chunk 13)

Master spec §5.6 "Automatic framing", rule 19, DoD 18
(`req_camera_rails_and_framing`, `rule_framing_zone_wherever_wider_view_needed`).
A `FramingZone` (`src/components/framing_zone.gd`, an Area2D) is placed in
the level like any component. Its editor properties:

| Property | What |
|---|---|
| `stable_id` | `<place>.frame.<name>` |
| `size` | the box it covers, centred on its position, level px |
| `zoom` | as Camera2D.zoom: 1 is normal play, below 1 shows more (0.7 shows 43 % more), above 1 closes in; 0.25-2 |
| `offset` | how far the view shifts from where the rails put it, level px (negative y is up) |
| `exit_hold` | seconds of holding an edge button to leave it; -1 (default) uses `Camera.EXIT_HOLD` |

`Level.build()` collects them into `LevelData.framing_zones` (stable ID ->
`{"box", "zoom", "offset", "exit_hold"}`), and `Simulation.load_level()`
hands them to the camera (`camera.zones`) before starting it. The test level
had two in chunk 13, from `tools/greybox_test_level.gd`: `s1.frame.high-step`
(x 3.5-4.5 screens, zoom 0.85, offset (0, -120): the loop and the ledge) and
`s1.frame.tree` (x 4.5-5.5, zoom 0.7, offset (0, -250): the loop, the
tree's lower platform and the bough). Since then: `s2.frame.parade` and
`s2.frame.gate` (chunk 15), `s3.frame.bowl` and `s3.frame.basket` (chunk
16), and `s2.frame.cave` (chunk 16d: x 10.6-11.9, zoom 0.7, offset
(0, -140): settled, the view spans y -767 to 159, the loop and the cave's
pocket with its sleepers at y -724, for rule 9).

**Framing.** A zone frames the camera while its **rail point** (the rails'
place, before framing) is inside the zone's box; the box is tested against
that point, so a zone above the way out doesn't frame the slide under it.
Framed, the camera's place is the rail point plus `frame_shift`, which eases
toward the zone's `offset`, and `zoom` eases toward the zone's zoom; both
ease back to (0, 0) and 1.0 when the rail point leaves. The ease is
`FRAME_EASE` (1.5) times the difference left per second, never slower than
`ZOOM_SETTLE` (0.02 /s) for the zoom or `SETTLE` (30 px/s) for the shift,
so it lands without creeping: just under 3 s from 1.0 to 0.7. A zone reframes
the rails, it doesn't pin the view: the camera still moves along them
inside. Where boxes overlap the current zone keeps the camera, else the
smaller ID. A camera started inside a zone (a level load, a fixture's
camera) shows its framing at once. A call still drags the camera out of a
zone; it keeps the zone's framing while dragged and is framed again by
wherever its rail point lands.

**Leaving a zone** (O70's proposed default). In `RAILS`, a move that would
take the rail point from inside the current zone's box to outside it is
held back (the camera stays at the edge) until the edge button has been
held for the zone's exit hold (`EXIT_HOLD`, 1 s, unless the zone sets its
own) since it was pressed in that zone (`zone_hold`, ticks; it restarts on
each press and on entering a zone). A short press, or a hold let go before
then, stays inside: the rest of the press is dropped at the edge. Once the
hold has lasted long enough the right to leave stays until the next press,
so the ease after the finger lifts carries the camera on out. **With STEP
and PACE:** a press still moves a `STEP` and a hold still moves at `PACE`
inside a zone; only the crossing of its edge waits. Holding across a whole
zone is never slowed as long as crossing it at `PACE` takes longer than its
exit hold (the test level's zones are one screen wide: 1.33 s at `PACE`,
over the 1 s). Zones are entered freely.

### Idle camera and screensaver mode (chunk 13)

Master spec §5.6, §5.7, DoD 19 (`req_idle_camera_and_screensaver_zoom`).
`Camera.watch(slimes, touching, screensaver, bedtime)` runs once a tick before
`step()`: `touching` is whether a finger is down (a finger held down counts
all along), and `Simulation._apply_input` calls `camera.touched()` for every
touch that counts, before the tap does its job. `quiet` counts the ticks
since the last touch. Tilt doesn't count as input for this clock: it
steers free slimes, it doesn't take the camera.

- **Cue.** From `IDLE_SECONDS - CUE_SECONDS` (35 s) the zoom goes slowly
  (smoothstep over 10 s) from where it was to `IDLE_ZOOM`, while the camera
  stays the child's (on its rails). A touch stops the cue and the zoom
  eases back to its framing.
- **Following.** At `IDLE_SECONDS` (45 s) the camera switches to `FOLLOW`:
  it picks the **train slime whose centre is nearest the camera's point**
  (the smaller id on a tie; with none it tries again each tick) and glides
  after it, keeping it `RAIL_OFFSET` under the middle of the view, at
  `FOLLOW_EASE` (2) times the distance per second, between `SETTLE` and
  `FOLLOW_PACE` (half a screen a second, above the slide's 360 px/s). A
  hopping slime runs a little ahead of the view (about half a second of
  its motion). Framing zones are ignored while following.
- **The follow rule.** The camera keeps its slime's id. Through **fusion**
  it follows the fused slime: `SlimeBodies.merge` keeps the lower id, so if
  the followed id is gone the camera takes the slime of the same species
  with a lower id nearest where it was. Through **splitting** it follows the
  piece that keeps the id (`SlimeBodies.split`'s first part). A slime gone
  any other way: the train slime nearest where it was.
- **Taking control back.** Any touch ends following and still does its
  normal job: the camera glides back to the rails as after a call
  (`RETURN`), framed again only if its point (the view's centre) is still
  inside a framing zone, else as in chunk 12; an edge button puts it
  straight back on the rails at the nearest point and moves it on; a call on
  open ground drags it toward the call. The idle clock starts again.
- **One zoom.** `IDLE_ZOOM` = 1/1.15 (15 % wider than normal play, within the
  spec's 10-20 %) is the only zoom while following, in idle and screensaver
  mode alike: it replaces a zone's zoom, it never stacks with one. It never
  zooms in (chunk 23C, D103): where the camera is already wider (a zone
  under 0.8696, like the tree's 0.7), the cue and the idle camera keep that
  zoom (`_idle_zoom()`).
- **At bedtime** (chunk 23C) the idle camera follows no one: `watch()`'s
  `bedtime` drops the followed slime and the camera stays where it is
  (`FOLLOW` with `follow_id` -1), and no idle camera starts; the cue may
  still settle the zoom. At sunrise it follows the train slime nearest it.
- **Screensaver mode.** `simulation.screensaver` (true: screensaver mode).
  Turning it on starts the idle camera at once, at `IDLE_ZOOM`, with no cue.
  A touch takes the camera back as above; it idles again after the usual
  45 s. The core default is false (a session, and test mode and the unit
  tests play as in one). Once sessions are open (`session.open()`: normal
  play, or a test-mode run with `"sessions": true`), the session sets it
  every tick: on in screensaver mode, off during a session and at bedtime
  (see "Sessions (chunk 17)"). It is a mode set from outside, so it is not in `Simulation.dump()` nor in saves; the
  camera's own dump records what it did (`screensaver` as last seen,
  `quiet`, `cue_from`, `follow_id`, `follow_species`, `follow_point`,
  `frame_zone`, `frame_shift`, `zone_hold`, and since chunk 23C
  `show_distance`, `show_tick`).

`camera.place()` (tests, debugging) also ends following, restarts the idle
clock and frames the camera by the zone its centre is in.

![In s1.frame.tree: zoom 0.7, the view shifted up onto the tree's lower platform and the bough](img/chunk13-framing.png)

![The idle camera following the first slime through a dip, at the shared zoom](img/chunk13-idle.png)

The screenshots are from a debug run with a display, seed 91: a scripted
right hold to the middle of the tree's zone (the camera at distance
5769.6, zoom 0.7, shift (0, -250)), and a fresh run left alone for 50 s
(following slime 1 at zoom 0.8696; at 40 s the cue had it at 0.9348).

**Minimum zoom (Known gap 4), data only.** A base (size 1) slime's visible
edge is `RING_RADIUS_SIZE_1` + `EDGE` = 24 level px from its centre, so it
is drawn 48 level px across: 48 viewport px at zoom 1, 40.8 in
`s1.frame.high-step` (0.85), **33.6 in `s1.frame.tree` (0.7)**, 41.7 at
`IDLE_ZOOM` (measured about 33 px across in the tree screenshot). On the
reference phone (S20 FE, 2400×1080 at about 405 ppi, 1.667 physical px per
viewport px) that is 80 px (5.0 mm) at zoom 1 and 56 px (3.5 mm) at 0.7,
the Meadow's smallest. No rule is set here.

**Tests.** `tests/unit/test_camera_framing.gd` (synthetic loop, one zone):
`Level.build()` collecting the zones with their exit hold, entering a zone
reframing smoothly (the zoom only going out, less than 0.01 a tick, no jump
in place) and settling on its zoom and offset, not there after 0.5 s, a
camera started inside framed at once, the slide under a zone not framed,
short presses forward and backward staying inside, a hold leaving after
1 s, a shorter hold staying, a hold across the zone not slowed, a hold let
go near the edge easing on out, a zone's own exit hold, only the zone
setting the zoom, a call from inside a zone keeping and regaining its
framing, dump and restore. `tests/unit/test_camera_idle.gd`: idle at 45 s
with the cue from 35 s (half way at 40 s), a finger held down counting as
input, waiting without a train slime, following the train slime nearest
the middle (not a free slime or a sleeper) and gliding to it, following
through a fusion (either id) and a split (with `SlimeBodies` directly), a
touch taking control back and restarting the clock, a touch stopping the
cue, an edge press from following, zones ignored while following, framing
resumed on touch only inside a zone, screensaver mode starting at once
(also inside a wide zone, keeping its zoom since chunk 23C), one shared zoom, and through the
simulation the zones handed over, screensaver mode, tilt not counting, a
tap on open ground taking control and still calling, an edge tap taking
control and moving the camera, dump and restore.
`tests/e2e/test_camera_framing_e2e.gd` on the test level (seed 91): the
zones reach the camera, a right hold into `s1.frame.tree` reframes it
(zoom 0.7, the shift, the platform and the loop on screen, the Camera2D
mirroring the zoom), four short presses stay inside and a hold leaves after
about 1 s, 45 s alone gives the cue then the follow of the first slime and
a tap takes the camera back and calls, screensaver mode, and a repeatable
hash. `test_camera_e2e.gd`'s call to the tree now stops short of the tree
(in the high step's zone): the tree's zone shifts the view onto the call
point, which left the drag nothing to do.

**Choices.** Framing is relative to the rails (rail point plus a shift),
not a fixed view per zone, so the camera still travels inside a zone and a
zone's edge needs no special seam. The exit hold is a fence on the rail
point rather than a slower pace, so short presses behave the same inside a
zone and a long hold is not slowed. Tilt is not input for the idle clock.
`screensaver` stays out of the dump so a reload in normal play still
matches the saved hash.

### Chunk 23C: call dead zone, idle zoom, showing a gate open, idle camera at bedtime

Build plan items 23.1, 23.4, 23.10 and 23.12 (master spec §5.6; D101,
D103; ux D4, D5). All in `Camera`, plus one accessor on `FrontierSets` and
three lines in `Simulation`.

- **Call dead zone (23.1, D101).** `Simulation._tap` hands a call to
  `camera.on_call(point, tick, view)`. `Camera.in_dead_zone(point, view)`:
  the call point shows inside a box centred on the screen, `DEAD_ZONE`
  (0.2) of its width by 0.2 of its height (230.4 × 129.6 px on the
  1152 × 648 viewport), measured on the screen, so the same at every zoom.
  Inside it the call happens as usual (the slimes answer, the ripple) and
  the camera doesn't move: on the rails nothing changes; off them (a drag,
  a return, the idle camera or a gate's show just taken back) the camera
  is held where it is for the call's window (a `DRAG` toward its own
  position), then glides back to the rails as after any call. So a call
  inside the box during a drag stops the drag where it is. Outside the
  box, `follow_call()` as before. The box's edge counts as inside.
- **The idle zoom never zooms in (23.4, D103).** The cue goes from its
  starting zoom to `_idle_zoom(from)` = `min(IDLE_ZOOM, from)`, and
  following (and screensaver mode's start) keeps `min(IDLE_ZOOM, zoom)`.
  In the tree's zone (0.7) the zoom stays 0.7; in a zone narrower than the
  idle zoom (section 2's gate zone, 0.9) the cue zooms out to 0.8696 as
  before. The zoom a followed camera keeps stays with it out of the zone
  (framing is ignored while following).
- **Showing a gate open (23.10).** `FrontierSets._open_gate` records the
  tick in a transient `_opened_on` (emptied by `start()`, not saved), and
  `frontier.gates_fired_open(sim)` returns the gates a basket fired open
  on this tick. `Simulation.step` hands each to
  `camera.show_gate(box, view, loop, open_gates, tick)`, after
  `camera.watch()`: unless the gate's box is wholly in view (or an edge
  button is held), the camera enters `SHOW` and glides in `SHOW_SECONDS`
  (1.5 s) to the rail point nearest the gate's centre on the grown loop,
  framed by the zone there (the zoom and shift ease on the way), a
  straight glide timed to arrive on the 90th tick; then it is on the rails
  there (`RAILS`), under normal control, and stays. Any touch takes it back
  (`_take_back()`, as from the idle camera): a call drags it, an edge press
  moves on from the nearest rail point, another tap sends it back to the
  rails. The show ends the idle camera and restarts the idle clock, so it
  stays at the gate rather than going back to a slime. A gate saved open
  (a fixture, a reload) shows nothing: only a firing in this run counts.
- **The idle camera at bedtime (23.12).** `watch()` gets
  `session.phase == Session.BEDTIME`. Following at bedtime, the camera
  drops its slime (`_follow_no_one()`: `follow_id` -1, `follow_point` its
  own point) and `step()` holds it still; no idle camera starts at
  bedtime. The cue may still run to the idle zoom. At sunrise (screensaver
  mode) it follows the train slime nearest it again. Before, a camera
  still gliding to its slime when bedtime began kept gliding to the
  now-asleep slime.

**Values (proposed; the spec gives none).** The dead zone's edge counts
as inside. The glide to a gate is a straight, even glide of exactly 1.5 s
to the rail point nearest the gate's centre (not the gate's centre
itself), so the camera ends on the rails. "In view" for a gate is its
whole box inside the view. No show while an edge button is held. The show
restarts the idle clock (a following idle camera, or screensaver mode's,
gives way to it and resumes 45 s later).

**Tests.** `tests/unit/test_camera_dead_zone.gd`: the box's size and
edges, the same on the screen at six zooms, a call inside it leaving the
camera on the rails through its window, one just outside dragging at the
drag's pace, one inside during a drag stopping it for the new window then
the return, one inside a return holding it, and through the simulation a
call inside the box answered by the slime in range with the camera still.
`tests/unit/test_camera_gate_show.gd` (synthetic loop, gate at 3000 px):
a gate off screen shown in 1.5 s without a jump and ending on the rail
point, staying there then moving on with the edge buttons, easing into a
zone's framing at the gate, a gate in view moving nothing, a gate half in
view shown, a call, a touch and an edge press during the glide, no show
while a button is held, the idle clock restarted and the cue stopped, the
idle camera giving way, dump and restore mid-glide; and through the
simulation `gates_fired_open()` on the firing tick only, a basket saved
fired showing nothing after a load, a basket firing showing its gate
within 1.5 s, and a gate in view keeping the camera still.
`tests/unit/test_camera_idle.gd` adds: screensaver mode inside a wide zone
keeping its zoom (this test expected `IDLE_ZOOM` before D103, and was
changed with the spec), the cue and the idle camera keeping a wide zone's
zoom, a narrower zone's cue zooming out, and at bedtime following no one
and staying put (then following at sunrise) and no idle camera from a cue
at bedtime. End to end on the test level:
`tests/e2e/test_camera_dead_zone_e2e.gd` (seed 23: inside and just outside
the box, the box in every framing zone (seven) from `gate2-open`, stopping a
drag, a repeatable hash); `test_camera_framing_e2e.gd` adds the tree's zone
(the zoom never above 0.7 over 50 s alone) and section 2's gate zone
(zooming out to the shared zoom); `tests/e2e/test_camera_gate_show_e2e.gd`
(seed 14, `s1-basket-5of6`: gate 1 in view within 1.5 s of the firing and
staying, a tap during the glide calling and dragging, gate 1 already in
view leaving the camera still, a repeatable hash);
`tests/e2e/test_camera_bedtime_e2e.gd` (seed 4242, `wind-down` with
sessions: the camera idle, or in its cue, when bedtime begins stays put
through the whole 10-minute cooldown, 30 s ticked, 9 min skipped, the rest
ticked, then follows a train slime after sunrise; a repeatable hash). The
e2e runs set `camera.quiet` at the start so the camera is idle when bedtime
comes 10 s in.

## Fusion and bumping

Master spec §5.2 and §5.3, D20, D37, D49 (`rule_fusion_contact_time`,
`rule_max_size_three`, `rule_dip_may_nudge_fusion`). `Fusion`
(`src/sim/fusion.gd`, pure logic) holds the contact counts; the ring
operation is `SlimeBodies.merge`, reached through `Simulation.fuse()` so the
stable identities follow. `Simulation.step()` calls `fusion.step(self)` after
the split zones and before the free slimes and the train follow (they drop
the fused-away slime's records).

**Contact timers.** After the bodies tick, every touching pair
(`SlimeBodies.touching_pairs()`, rings within `TOUCH_SKIN` 2 px) that
counts adds one tick to its count. A pair counts when both slimes are awake
(train or free; sleepers never count), of the same species, both centres on
screen, and neither in a split zone (a slime fused there would split again
at once). A pair that stops touching or counting for even one tick loses
its count. **No grace:** two slimes resting against each other stay
touching every tick (`test_179_ticks_of_contact_do_not_fuse_and_180_do`
checks every tick), so solver jitter never needed one.

At `CONTACT_TICKS` (180, 3 s) the pair acts:

- sizes adding up to 3 at most: it **fuses**. The fused slime keeps the
  lower runtime id and with it that slime's state and records (a train
  slime keeps its progress, a free slime its phase, call point and stream),
  at the size-weighted centre, momentum kept. Its identity is the union of
  both (D72).
- above 3: it **bumps**. Each slime gets a push apart (`BUMP_SPEED` 240
  px/s shared by size, the smaller moving more) and a lift (`BUMP_LIFT`
  200 px/s up), and the count starts again. A pair that stays together
  bumps once every 3 s, not every tick.

**On screen only.** The view is `Simulation.view` (the scene copies the
camera into it before every tick; unit tests set it by hand). A centre is
on screen when it is inside the view shrunk by `VIEW_MARGIN` (24 px, a base
slime's drawn radius, so the whole body shows). Off screen the count is
**dropped, not paused**: a pair that comes back into view starts from zero.

**The dip nudges fusion** (level rule 5, test level 1.3). Measured first:
without help, two base slimes of one species put on the Meadow dip's rim
pass through the dip at the train's pace. Over 20 seeds none fused in 60 s;
the longest contact was 16 to 115 ticks. Two lighter tweaks weren't enough:
holding touching pairs only (9 of 20 seeds fused) and doubling the hop
interval on landing at the floor (13 of 20). The kept nudge is sim-side, in
`Fusion`:

- a **dip floor** is found from the loop (`Fusion.dip_floors()`): a vertex
  of the outgoing route from which the route rises `DIP_DEPTH` (100 px)
  above it on both sides before going any lower; the floor is the stretch
  around it at most `DIP_FLOOR_RISE` (30 px) higher. The Meadow's fusion
  dip gives one floor, 3217 to 3570 px along the loop; the smaller dips and
  the slide have none. Recomputed when the open gates change, not state.
- **gathering:** a train slime on a dip floor doesn't hop while a train
  slime it may fuse with (same species, sizes up to 3) is less than
  `DIP_GATHER` (300 px, two base hops) behind it along the loop, so the one
  behind catches up. For the train slime **directly behind** it (no other
  train slime between them) it waits as long as that holds. For a partner
  with other slimes between them, it waits only until its own progress has
  not advanced for `DIP_WAIT_SECONDS` (5 s; the train's stall mark,
  `marked_at`, which moves on every 24 px of progress, so no new state and
  nothing new in saves). Chunk 16f added the limit (below);
- **holding:** two such slimes touching on the floor don't hop until they
  fuse or lose contact.

Both apply only on screen, where fusion can happen, and only to pairs that
may fuse: pairs that would bump, or of different species, pass through. A
held slime's hop timer is kept at `DIP_HOLD_SECONDS` (0.25 s), so it hops
soon after it is let go. With it, all 20 seeds fuse, in 7.5 to 11.6 s.

**A mixed queue on a dip (chunk 16f).** Since 16e the train reaches the
dips as about 20 base slimes whose species alternate (A, B, C, A, ...), so
a partner behind a slime on the floor usually has a slime of another
species between them and can't catch up. Gathering used to wait for it
with no limit and held the whole queue: 8 alternating slimes put on the
Meadow dip crept a few px a second, 9 of 10 seeds still on the floor after
120 s, 7 of 10 with train slimes stalled (D118); `gate2-open` seed 6 held 17 train
slimes on section 3's bowl floor for 6 minutes (1 lap in 15 min). Now the
partner directly behind is waited for as before, and one with slimes
between them for `DIP_WAIT_SECONDS` at most. Measured on the Meadow dip
(seeds 1 to 10 for the queue, 1 to 20 for the rest):

| Case | Before 16f | After |
|---|---|---|
| two C slimes on the rim (the chunk 10 check) | 20 of 20 fuse, 454 to 679 ticks | the same runs, tick for tick |
| A, C, C, B (neighbours of one species) | 15 of 20 fuse; the other 5 stay on the floor | the same 15 fuse, tick for tick; the other 5 leave the floor in 23 to 35 s |
| A, B, C, A, B, C, A, B | 1 of 10 leaves the floor in 120 s; 7 with stalled slimes | all leave in 33 to 58 s, 0 to 3 fusions, none stalled |

Waiting only for the slime directly behind (no limited wait) passes the
queue faster (19 to 26 s) but leaves the `bump` fixture's 3 + 1 bump
unmet: its size 1 sits ahead of the size 3 and waits for a size 2 behind
that, which is what kept the 3 + 1 pair together for 3 s. With the 5 s wait
the fixture's 3 + 1 pair bumps once, at tick 179, on seeds 1 to 8 (before:
six times in 20 s, since the 1 never left). The 2 + 2 pair bumps within
20 s on seeds 1 and 3 to 7 (seed 5 is the end-to-end test's), no longer on
seeds 2 and 8, where it bumped only in the pile the held size 1 kept.
`DIP_WAIT_SECONDS` is a new tuning value, proposed for `specs/tuning.md`.

**State and saves.** The counts are state: `dump()["fusion"]` is
`[[a, b, ticks]]` in id order. They are saved too, in the save's
`transient.fusion`, because it is trivial and keeps the reload invariant (a
reloaded save has the same hash and fuses on the same tick).

![The fusion dip: two base slimes of species C touching at the bottom (count 160 of 180), then the fused size-2 slime 30 ticks after the fusion](img/chunk10-fusion.png)

The screenshot is from a debug run with a display, seed 5, the camera on
the dip at zoom 1: two species-C base slimes put on the rim (2.58 and 2.68
screens) gather on the floor and fuse at tick 491 (8.2 s).

**Tests.** `tests/unit/test_fusion.gd` (flat floor, automatic hops off, the
view set by hand): 179 ticks don't fuse and 180 do, with the summed size; a
small hop at tick 100 breaks the contact and the fusion comes exactly 180
ticks after the contact is back (293); different species and sleepers
never count; free slimes fuse; 1 + 2 fuse; 2 + 2 and 3 + 1 bump (both
remain, pushed apart and lifted, the smaller faster, at most one bump per
3 s); off screen, half off screen and inside the margin nothing fuses, and
going off screen drops the count; a fused train slime keeps its progress
and hops on along the loop; identities merge; determinism; the counts in
the dump and through a save; `dip_floors()` on a synthetic loop; the
nudge on a synthetic dip lying on the flat floor (16f): a partner directly
behind is waited for past 5 s, one behind a slime of another species for
5 s and no more, and nothing waits for a partner out of reach or for a
2 + 2. `tests/e2e/test_fusion_e2e.gd` on the Meadow: from `bump` the size 3 and
size 2 meet and are both there after 10 s [DoD 6, bump]; two base slimes
on the dip rim fuse within 20 s and the run is repeatable; the fused slime
leaves the dip; 2 + 2 and 3 + 1 on the dip meet and stay apart in size;
(16f) 8 alternating slimes leave the dip's floor within 75 s (seed 5: 43
s), and in A, C, C, B the two C slimes fuse there within 20 s.

**Choices.** The nudge is a small sim-side wait, not a level edit and not a
physics change: the dip geometry is the level's, and the train's grip and
hop aims stay as they are. The count is dropped, not paused, off screen, so
a fusion the player sees always shows its full 3 s. The bumped pair's count
starts again rather than bumping every tick, which would shake them apart
on every contact.

**Known gaps.** In the `bump` fixture's 10 s the pair meets (touching for
75 ticks, the longest run 68) but never reaches 3 s together, so no bump
push happens in that run; the bumps themselves are covered by the unit
tests. The `bump` fixture holds a 3 + 2 pair, while the build plan's
"`bump` (2 + 2 and 3 + 1)" names other sizes; 2 + 2 and 3 + 1 are covered by
scripted spawns on the dip instead.

## Sleepers, waking and the hint

Master spec §5.2, D13, D70, D65 and D95 (`req_waking_sleepers`,
`req_first_play_hint`, `req_controls_tap_zones`). The code is in `Sleepers`
(`src/sim/sleepers.gd`, stateless) and `Hint` (`src/sim/hint.gd`,
`simulation.hint`). `TapFeedback` draws the hint.

- **Placing.** `Level.build()` adds every `Sleeper` component to
  `LevelData.sleepers` (stable ID, species, position). On a fresh state,
  `Simulation.load_level` creates the first slime and then every sleeper
  (`Sleepers.place`) in stable ID order. Each sleeper is size 1, in state
  `sleeper`, named by its stable ID. A restored save brings its own
  sleepers and gets no new ones. The test level has 29. The markers only
  draw in the editor: the game draws the bodies.
- **Asleep.** A sleeper doesn't simulate. `SlimeBodies` skips its hops,
  integration, ring and terrain constraints, so its points never move. It
  still takes part in the contacts, as a wall: the other slime takes the
  whole overlap, can rest on it, and wakes it. Two sleepers are never
  paired.
- **Waking.** Right after the bodies tick, `Sleepers.wake` wakes every
  sleeper touching a free slime when both are on screen: any part of the
  ring in `simulation.view`. Train slimes never wake one. The woken slime
  becomes free and `unsure` at its own centre, then heads back and rejoins
  like any free slime. It can wake another sleeper on a later tick.
- **Tapping.** A tap on a sleeper is a call centred on its body.
  `Sleepers.tap_targets` moves the level's box onto the body and drops it
  once the sleeper is awake.
- **The hint.** The hint has one place: the sleeper nearest the first
  slime's marker (the smaller ID on a tie). It is due until the first call:
  any tap that calls, on open ground or on a sleeper. The game calls
  `hint.world_shown(tick)` whenever it shows a simulation. If no call comes
  in the 10 s after that, the hint shows, but never during bedtime
  (`hint.bedtime`, which chunk 17 drives). `TapFeedback` draws it as a
  steady ring plus a ring that swells and fades every 1.2 s of sim time.
  This is placeholder art.
- **Saving.** `hint_done` sits at the top level of the save (absent means
  false, so the hint is due). `transient.hint` holds `{since, bedtime}`.
  `readable()` keeps `hint_done`.

![The first-play hint pulsing around the first sleeper, 10 s into a fresh run with no call](img/chunk9-hint.png)

The screenshot comes from a debug run with a display: fresh, seed 91, no
input, tick 677. It was recorded with the movie maker under
`xvfb-run -a -s "-screen 0 1280x720x24"`, `--fixed-fps 60 --quit-after
700 -- --test-mode --seed=91`.

**Tick cost.** Measured with `Simulation.step` on the test level, seed 909,
over 3600 steps, headless. The figure is the median of rounds 2 and 3.

| Case | Slimes | ms per step |
|---|---|---|
| No sleepers | 1 | 0.057 |
| 29 sleepers (not simulating) | 30 | 0.142 to 0.148 |
| The same 29 as bedtime-asleep (simulated) | 30 | 0.91 to 0.94 |

The 54 000-tick session test now takes 7.9 s. The bench's "still" case
(`tools/bench_slimes.gd`) uses bedtime-asleep slimes, because sleepers no
longer simulate.

**Tests.**
- `tests/unit/test_sleepers.gd` (12 tests):
  - placing, and a restored save placing none;
  - never moving, and resting on a sleeper;
  - train slimes not waking one;
  - on and off screen, and both having to be on screen;
  - unsure, then rejoining;
  - the tap following the body, and a woken sleeper no longer a target;
  - determinism.
- `tests/unit/test_hint.gd` (10 tests):
  - 10 s after the world shows, next to the first sleeper;
  - showing again restarts the count;
  - done for good, a call hiding it, and a tap that doesn't call leaving it due;
  - bedtime, and a level without sleepers;
  - the save round trip, a save without the mark, and a bad mark.
- `tests/e2e/test_sleepers_e2e.gd` (7 tests, on `fresh`):
  - every sleeper asleep;
  - the hint after 10 s with no call [DoD 16];
  - a call at 5 s means no hint, even after a reload;
  - a reload counts 10 s again;
  - a call on the first sleeper wakes it and both rejoin;
  - no waking in a lap without calls;
  - repeatability.
- `tests/unit/test_call.gd` gains a heading-back test from a ledge above
  the loop.

**Crowd check** (scratch runs, not tests):
- **Hill sleepers can't be reached.** Hill sleepers `.02` to `.13` sit on
  slabs about 150 to 210 px above the hill surface, beyond a base slime's
  `max_rise` of about 133 px.
  - A called slime came no closer than 65 to 70 px (the tree: 105 to 112;
    the bough: 380; ledges B and C: 69 to 76).
  - In 8 minutes of taps, none woke.
  - This is a level design question, not code. The slabs also have to
    clear size-3 train slimes on the loop below.
- **Woken on a ledge.** Force-woken hill sleepers (6 per run) first got
  stuck on their slab's corner. The way back is now fixed (see the call
  above), with a test.
- **Corner snag.** A slime can snag on bump 2's right end, around
  (1746 to 1751, −164 to −174). At a convex corner that isn't square,
  `TerrainSegments` takes the first-listed segment on a tie. That can
  count a point just past the corner as inside the terrain, so a
  wedge-shaped strip of air acts as solid (seen at x 1778 to 1802,
  y −184).
  - After the fix, one slime still stuck there on 9 of 10 seeds.
  - A fix (the vertex's summed normal on a tie, in both `resolve` and
    `SlimeBodies._solve_terrain`) changes contact physics everywhere, so
    it is left open.
- **Lost by stalling.** Crowds were lost by the 60 s stall rule:
  - at the start basin's lip, around (716 to 723, 370 to 381), on seed 4
    (seed 2 before the fix);
  - on the fusion dip's floor, around (3459 to 3592, 200 to 218), on
    seeds 6 and 9, mixed species (the dip nudge held a mixed queue; limited
    in chunk 16f, see "Fusion and bumping").
  - Not settled; the start crowd from chunk 6's known limit remains.

**Choices and gaps.**
- The hint ends on the first call, not on the first call that wakes a
  sleeper as D65 words it. This follows D95 and `req_first_play_hint`.
- The done mark lives in the level's save. Deleting the save brings the
  hint back.
- A reload while the hint is due restarts its 10 s, so the hash of a
  reloaded run can differ from the unbroken run's while the hint is due.
- The bedtime flag stays off until chunk 17.
- Tests changed because sleepers now exist and don't simulate:
  - test_slime_physics, test_slimes_in_game and the bench use
    bedtime-asleep bodies;
  - the e2e counts expect 1 + the level's sleepers at load;
  - the `bump` fixture expects 3 awake slimes.

## Frontier sets (chunk 14)

Master spec §5.4, DoD 9-14 (`req_switch_basket_gate_set`,
`req_interactive_objects_general`, `rule_gate_opens_via_switch_basket_set`,
`rule_frontier_set_inert_after_gate_open`, `rule_signpost_at_every_fork`,
`req_level_completion_celebration`). `FrontierSets`
(`src/sim/frontier_sets.gd`, pure logic) is `simulation.frontier`;
`FrontierView` (`src/frontier/frontier_view.gd`, the node `Frontier` under
main) draws it. Its class doc is the reference; in short:

**Data flow.** The components (`Switch`, `Basket`, `Gate`, `Signpost`)
only configure: `Level.build()` turns them into `LevelData.switches`,
`baskets`, `gates`, `signposts` and `rules` (level pixels). At load (and on
a save restore) `frontier.start(sim)` fills `sim.object_states` and
`sim.gate_states` with each object's state, syncs the train's open gates
and builds the doors. Each tick, after fusion, `frontier.step(sim)`:

1. catches every train or free slime whose centre is inside a basket's box
   (state `in_basket`: no hopping, no train, no call; it falls and settles);
2. weighs each basket (a size-3 slime weighs 3) and moves it through its
   phases: `filling` (collecting while its switch is flipped) -> `full` at
   its quota -> `reward` once its box's centre is in the view, for
   `REWARD_SECONDS` -> `fired`: its rules run (its gate opens) and, when
   every basket of the level has fired, the celebration plays, once per
   save;
3. lets a basket that isn't holding (fired, or its switch flipped back)
   release its slimes, lowest id first, one every `RELEASE_SECONDS`, at its
   outlet when there is room; the slime is moved there at rest and rides
   the train again;
4. sets the doors: a flipped switch's trapdoor is open, a closed gate's box
   is solid, an open gate's lid shuts the old slide entrance; a door only
   shuts once no slime is in its way. The shut ones go to
   `SlimeBodies.doors`, solved like the terrain.

Then `sim.gates` follows the train's open gates. A tap on a switch
(`Simulation._tap`, `KIND_SWITCH`) calls `frontier.tap_switch()`: it flips
only while the basket is `filling`, so the set is locked once full and inert
for good once fired. Since chunk 23E (D109) a switch that isn't answering
(`switch_answers()`) and a basket don't take the tap at all: it is a call. At bedtime taps reach no object (chunk 17), so the
switch can't be flipped then.

**Opening a gate** adds it to the train's open gates: the loop grows
(`LoopData.current_segments`: the section's return route is replaced by the
next section's segments). Train slimes on the outgoing part keep their
distance; those still on the old return route are put the same distance
from the new loop's end, and every progress mark restarts.

**Editor configuration.** In the level scene:

- `Switch`: at the fork, before the gate; `basket_id` its basket;
  `trapdoor` a box (relative to the switch) of the loop's ground over the
  basket, solid while the flow goes onward, open while flipped. Tappable
  (its box plus the tap margin).
- `Basket`: its box is where caught slimes rest (the pit under the
  trapdoor); `quota` the weight that fills it; `on_full_object` its gate,
  `on_full_action` `open`; the outlet (below).
- `Gate`: its box blocks the loop while closed (put it across the next
  section's outgoing route); `entrance_lid` a box (relative to the gate)
  over the old slide entrance, solid once the gate is open. The section's
  return `LoopSegment` names it in `gate_id`.
- `Signpost`: next to its switch (`switch_id`), one at every fork; not
  interactive. The game draws its arrow the way its switch sends the flow.

**The outlet** (Known gap 3, O62: not settled by the spec) is a basket
property. `onward_route` (the default): on the onward route, `outlet_before`
px (200) along the loop before the start of the return route its gate
retires (`FrontierSets.onward_outlet`); a level with no such route falls
back to the outgoing route's point nearest the basket. `point`:
`outlet_point`, relative to the basket. Released slimes land there and ride
on through the open gate.

**Saved.** `objects` (switches and baskets) and `gates` hold the states
above by stable ID, and `celebration_done` the celebration's mark; the
celebration's start tick is transient (`transient.frontier`), so a reload
never replays it. A save holding states of objects the level doesn't have
keeps them as they are.

**Placeholder art** (`FrontierView`, z 5): the shut trapdoors, closed gate
boxes and shut lids as blocks; the switch's and signpost's arrows (down
into the basket when flipped, else along the loop); the basket's quota as
slime outlines filled by weight, pulsing during the reward; rings for the
celebration; bunting for the lasting mark (chunk 23D).

**Tuning** (constants in `FrontierSets`): `REWARD_SECONDS` 2.0,
`RELEASE_SECONDS` 0.3, `CELEBRATION_SECONDS` 4.0, `OUTLET_CLEARANCE` 8 px
(the outlet is free when no slime is closer than the two radii plus this),
`DOOR_CLEARANCE` `SlimeBodies.EDGE` (3 px); the basket's `outlet_before`
200 px.

**Fixtures.** `s1-basket-5of6` (basket 1 at 5 of 6, the first slime about
to drop in) and `s1-optout` (basket 1 at 3 of 6, to flip back), both with
the camera on the basket (see "Fixtures").

**Test mode.** To watch a set fire:

```json
{"seed": 14, "fixture": "s1-basket-5of6", "time_scale": 1.0}
```

The first slime drops through the open trapdoor, the outlines fill to 6,
the reward pulses (2 s), gate 1 opens, the lid shuts slide 1's entrance and
the six slimes are let out one by one at the outlet, then ride section 2's
loop and back down to the start. The celebration waits for basket 2 (since
chunk 15; to watch it, run `s2-basket-offscreen` and bring basket 2 into
view). To opt out, start
from `s1-optout` and tap the switch (a `tap` step at its screen position): the basket
lets its slime go and its outlines empty. With `--save=` under a scratch
directory, a reload after the celebration shows no celebration.

**Tests.** `tests/unit/test_frontier_sets.gd` (on a synthetic level: the
outlet, catching and weighing, the reward waiting for the view, firing and
the loop remap, release pacing and clearance, opting out, the lock and
inertness, the doors, the celebration once, saves, same seed same hash),
`tests/e2e/test_frontier_e2e.gd` (the game scene on the fixtures, basket on
screen: DoD 9, 10, 11, 13, 14, and a child process with the same hash) and
`tests/e2e/test_frontier_level.gd` (the test level's set against the level
rules: a signpost at every fork, the trapdoor over the basket, the outlet
on the onward route, the gate and its lid, a return route per section,
every branch still reachable with the gate open).

**Known gaps.** Section 3's segments are a stub (chunk 16). What a basket
does at bedtime, undecided when chunk 14 was built, is settled by D105 and
built in chunk 23D (below).

### Chunk 23D: baskets at bedtime and the celebration's lasting mark

Items 23.5 and 23.11 of the build plan (D105; master spec §5.1, §5.4,
§5.7; ux D4). Atoms: `req_switch_basket_gate_set`,
`req_session_lifecycle`, `req_slime_states`, `req_hopping_behavior`,
`req_level_completion_celebration`, `req_persistence_and_saves`.

**Baskets at bedtime (23.5).** `FrontierSets.paused(sim)` is true while the
session is at bedtime, and `frontier.step()` then runs `_basket_wait`
instead of `_basket_step`: baskets still catch (nothing is awake to catch)
and weigh, the doors keep their states, but no phase changes and nothing is
released. The slimes in a basket were never put to sleep (`_bedtime` only
touches train and free slimes) and sunrise only wakes bedtime-asleep
slimes, so they stay `in_basket` through bedtime and sunrise, and the
releases resume at sunrise where they stood (`next_release` has passed).
A reward due (`full`) doesn't turn to `reward`, so no gate opens; a reward
playing has its `since` moved on by one every bedtime tick, so its clock
stands still and it plays the rest at sunrise. A celebration playing when
bedtime begins stands still the same way (`celebration_since`) and isn't
drawn (`celebration_showing(sim)`: playing and not at bedtime). Why this
shape: the pause needs no new saved field. The session's phase and the
existing `since` / `celebration_since` already hold it, so a save taken at
bedtime reloads the same, with no save format change.

**The lasting mark (23.11).** `frontier.mark_showing(tick)` is true once
the celebration has played (`celebration_done`, the level's saved done
mark) and its burst is over; `FrontierSets.mark_point(level)` is the start
of the loop (distance 0). `FrontierView.mark_at()` gives where the mark is
drawn, or null; it draws placeholder bunting there (two thin posts and six
pennants in the celebration's colours, `MARK_*` constants), not solid and
not tappable. A reload shows it at once (the done mark is saved); a level
whose celebration hasn't played has none. The real look is ux-writer's
(ux D4 names bunting as an example).

**The double hop (23.11).** `CelebrationHops` (`src/sim/celebration_hops.gd`,
`frontier.hops`): when the celebration begins, every train or free slime
whose centre is in the view gets two hops to do; each tick of the burst
(not at bedtime) each of them that stands on something hops straight up
(`SlimeBodies.hop`, strength `HOP_STRENGTH`), so the second hop comes on
landing. Slimes asleep, in a basket or off screen don't; hops still due
when the burst ends are dropped. The hops still due are state: in
`frontier.dump()` (`celebration_hops`, so the hash) and in saves
(`transient.frontier.celebration_hops`, `[[slime id, hops left]]`,
optional: absent means none; format still 1).

**Values** (proposed; the spec gives none): `CelebrationHops.HOPS` 2,
`HOP_STRENGTH` 0.6 (about 50 px high, half a second in the air; both hops
fit well inside the 4 s burst); the bunting `MARK_HALF_WIDTH` 90 px,
`MARK_HEIGHT` 150 px above the ground, `MARK_SAG` 20 px,
`MARK_PENNANTS` 6, `MARK_PENNANT_DROP` 26 px.

**Tests.** `tests/unit/test_frontier_bedtime.gd` (synthetic level:
releases pause and resume, the slimes in a basket stay through sunrise, a
due reward waits and no gate opens, a playing reward stands still and plays
the rest, the last basket's celebration waits for sunrise, a celebration
playing at bedtime hides and resumes, a bedtime save reloads the same and
goes on the same), `tests/unit/test_celebration.gd` (the mark after the
burst, after a reload, never without the celebration; the double hop of
every awake slime on screen and of nobody else; the hops saved and hashed;
same seed same hash), `tests/e2e/test_frontier_bedtime_e2e.gd` (from
`bedtime` with basket 1 releasing: nothing leaves until sunrise, then one
at a time; from `s1-basket-5of6`, full and in view at bedtime: no reward and
gate 1 shut until sunrise; a bedtime save reloads the same; repeatable) and
`tests/e2e/test_celebration_e2e.gd` (from `stress-still`, woken early:
the camera stays put through the burst, a tap during it calls, the awake
slimes on screen hop, the mark stands at the start of the loop, after a
reload too, and not on `fresh` or `gate2-open`). `stress-still` is at
bedtime, so the DoD 14 test in `test_frontier_e2e.gd` now wakes it
(`session.sunrise`) before basket 3 can fire. Shared helpers for the new
unit tests: `tests/unit/frontier_test_support.gd`.

**Test mode.** To watch the celebration and the mark, load `stress-still`
(at bedtime: basket 3's reward waits) with a `skip` step of 600 s to reach
sunrise, then bring basket 3 into view (a held right edge button); with
`--save=` and a reload, the mark is there at once.

**Not built here.** No slime has an asleep look yet (all asleep slimes,
bedtime-asleep or in a basket at bedtime, look like awake ones but for the
dusk tint): "shown asleep" waits for the ui_ux tree's slime look.

## Off-screen simulation (chunk 15)

Master spec §5.3, D10, D69, D70, D96, DoD 5 and 10
(`req_offscreen_simulation`, `rule_left_alone_and_lost`, and
`req_switch_basket_gate_set` for the off-screen filling). `Offscreen`
(`src/sim/offscreen.gd`, pure logic) is `simulation.offscreen`; its class
doc is the reference. `SlimeBodies` gained a per-slime `calm` (ACTIVE,
RESTING, PARKED) and a low-detail flag.

**Physics only on or near the screen.** `offscreen.step(sim)` runs at the
start of every tick, before the train steers. A slime whose centre leaves
the view grown by `PARK_MARGIN` (384 px) is parked: not simulated, not
even a wall. One that comes within `NEAR_MARGIN` (288 px) is simulated
again where it was put, so it appears just outside the view; between the
two a slime keeps what it was. Parked slimes move at the deterministic
pace (`Offscreen.pace(size)`: a hop's reach per mean hop interval, about
67 px/s for a size-1 slime; about 64 px/s on screen):

- a train slime: its progress moves `pace × dt` along the loop (slide
  speed on a slide), and its centre goes to that loop point lifted by its
  size (`Offscreen.lift`) along the loop's upward normal
  (`Offscreen.up_normal`: where a slime resting on the slope has its
  centre; straight up on the flat). `Offscreen` advances the progress
  itself (`Train.advance` from the loop point, which projects onto itself),
  then `Train.follow()` projects the centre as usual (laps, gates; never
  backward). Fix in chunk 16s: the centre used to be lifted straight up and
  only `follow()` moved the progress; on a downhill stretch the lifted
  centre projected behind the progress whenever `pace × dt` was less than
  lift × the slope's sine (about 4.5° for a size 3, 7.7° for a size 2), so
  a big slime stopped there (section 3's ramp, 2.3 screens in section 1)
  and was lost as stalled 60 s later; uphill it ran up to 3.5 times too
  fast. `tests/unit/test_offscreen_slopes.gd` and
  `tests/e2e/test_offscreen_slopes_e2e.gd` cover it.
  Single file (chunk 16): a parked train slime never moves closer than the
  two slimes' widths (ring radius plus `EDGE`, each) behind the train slime
  ahead of it along the loop, parked or simulated; it waits there, as on
  screen it would bump into it (`Offscreen._train_room`, from the distances
  at the start of the tick, so the order doesn't matter; on one spot the
  higher id is ahead). Before, a parked slime faster than the one ahead (at
  the slide's speed behind one sliding slower on screen, or a bigger slime's
  pace) ran through it; the two came back on screen on one spot, where two
  rings never come apart, and crawled, blocking the train behind them until
  one was lost as stalled (found by the DoD 1 test from `gate1-open`).
  `tests/unit/test_offscreen_single_file.gd` covers it;
  over an open trapdoor it drops into that basket's box, in the first clear
  slot of a grid its own width plus `SLOT_GAP` (4 px) apart, bottom row
  first. Baskets so keep counting weight off screen; the reward and firing
  already wait until the basket is in view (chunk 14);
- a free slime: it takes the nearest point of its branch's route back when
  within `ROUTE_NEAR` (288 px), queued a slime's width behind any slime
  already on that route (single file, not one point), and follows it; out
  of any branch, a straight line to the nearest loop point within
  `ROUTE_NEAR`. At the end it rejoins the train. With nothing near it
  stays put, and the timer below loses it;
- sleepers, slimes in a basket and bedtime-asleep slimes stay put.

Fusion and waking already happen on screen only (chunks 10 and 9).

**Left alone and lost (D10).** A free slime outside the view (the screen,
no margin) counts ticks from `away[id]`. After `LEFT_ALONE_TICKS` (600,
10 s) it is left alone (`is_left_alone`); `LOST_TICKS` (3600, 1 min) later
and still free it is lost (`Offscreen.lose(sim, id)`, public since chunk
23A): moved to the start of the loop, back on the train (`LoopStart.move`,
shared with the stuck and stalled safety nets, chunk 23A) and logged in
`offscreen.lost` (`{"id", "tick", "reason": "lost"}`, last 16). On screen
the count stops; a free slime that stays on screen is never lost (DoD 5).
A train slime isn't lost but stalled: `train.stalled` (see "Train").

**Cheaper states.**
- Resting piles (`SlimeBodies`): pile slimes (in a basket, asleep at
  bedtime) that touch rest together once every one has been supported and
  within `REST_DRIFT` (1 px) of its anchor for `REST_TICKS` (30). A
  resting slime is a wall, like a sleeper, and two walls are never paired.
  A pile wakes whole when disturbed: a touching slime faster than
  `WAKE_SPEED` (30 px/s: a hop, a landing, a neighbour moving), a state
  change (bedtime, sunrise, a basket catching or releasing), a new velocity
  or body, a slime removed, fused or split next to it; a call wakes the
  resting slimes within its radius and a tilt change every resting slime
  (`Offscreen`); a door opening or shutting wakes the piles within
  `FrontierSets.DOOR_WAKE_REACH` (80 px) of it.
- Sleepers don't simulate (chunk 9); bedtime-asleep slimes now rest once
  settled, and park off screen like every slime.
- Slimes in a full basket rest as a pile.
- Zoomed out: below `LOW_ZOOM` (0.8) every ring uses
  `SlimeBodies.LOW_POINTS_BY_SIZE` (8, 10, 12 points for sizes 1, 2, 3),
  resampled from its current shape; from `FULL_ZOOM` (0.85) up, the full
  counts.

**Saves and hash.** A body's `"rest"` (calm, rest count, anchor, pile) and
`"low"` flag, and the Offscreen state (`"offscreen"`: zoomed out, away
counts, proxies, lost log) are saved (`SaveData`, optional keys) and in
`dump()`, so a reload continues the same way. `offscreen.enabled` is a
mode, like the screensaver: the game turns it on (`src/main.gd`,
`_new_simulation`); off, every slime is simulated, which the core's unit
tests rely on.

**Section 2, Caves (greybox).** `tools/greybox_test_level.gd` builds
section 2 as in `specs/levels/test/README.md`: the descent (8.5 to 9), the
parade's overhang ledges, the second dip and its hollow, the cave (the
stepped climb, the pocket at y -700, shelves A and B, its branch
`s2.branch.cave` and route back `s2.route-back.cave` landing on the loop at
11.92), frontier set 2 (signpost, switch at 10.97, basket 2 at 12.2 to
12.55 with a 170 px pit, quota 15, gate 2 at 12.8 opening section 3),
slide 2 back along the tunnel, two framing zones (`s2.frame.parade`,
`s2.frame.gate`) and 40 sleepers (A 7, B 7, C 7, D 19, numbered left to
right). Section 3 is a stub (`s3.loop`, `s3.slide`). Basket 2 is now the
level's last basket: the celebration waits for it.

**Fixtures.** `s2-basket-offscreen`, `s2-cave-return` and `lost` (see
"Fixtures"). All fixtures were regenerated for the new level.

**Test mode.** To watch a basket fill off screen, run
`{"seed": 14, "fixture": "s2-basket-offscreen", "time_scale": 1.0}`: the
camera is on switch 2; the first slime rides off screen and the basket
fills (about 26 s in). Pan to basket 2: the reward plays and gate 2 opens.
`lost` shows the lost path at 70 s with the camera left on the basin.

**Tick cost.** Headless, Ryzen 5 PRO 8640HS, Godot 4.7.2.
`tools/bench_offscreen.gd` times 600 ticks after 600 untimed:

| Case | Slimes | Before, ms/tick | After, ms/tick |
|---|---|---|---|
| Pile: a full basket (60) and the train beside it (20), `SlimeBodies.tick` | 80 | 3.794 (rest off) | 0.966 (rest on), 0.809 (rest on, zoomed out) |
| Test level, `Simulation.step`, the first slime and 40 train slimes along the loop, camera on the start | 110 | 2.612 (offscreen off) | 1.919 (offscreen on, 86 parked) |

The "before" columns are the same script with the rule off. The level case
grew with section 2's 40 sleepers (before section 2: 70 slimes, 2.074
ms/tick). `tools/bench_slimes.gd` is unchanged by design (it settles only
180 ticks, too short for its 200-slime pile to rest): size 1 still 10.389,
moving 10.796; mix still 12.865, moving 12.300 (before: 10.494, 10.077,
11.773, 11.161; the spread is run-to-run noise).

**The whole level, 200 slimes.** `tools/bench_level.gd` and its numbers
are in "Test level sections 2 and 3, full population (chunk 16)".

**Tests.**
- `tests/unit/test_offscreen.gd` (21 tests, synthetic level): parking and
  the margins, the train pace and the loop, dropping into a basket and the
  clear slot, the route back and single file, left alone and lost, never
  lost on screen, zoomed-out detail, the call and tilt wakes, saves, same
  seed same hash.
- `tests/unit/test_offscreen_slopes.gd` (4 tests, synthetic level with a
  1-in-5 slope down and one up; chunk 16s): parked size-2 and size-3 train
  slimes keep the pace down and up a slope, ride lifted along the loop's
  normal, and lap the whole loop (every corner, the slide) without being
  lost.
- `tests/unit/test_slime_rest.gd` (17 tests): piles rest whole and wake
  whole on each disturbance, walls, low detail, saves.
- `tests/e2e/test_offscreen_e2e.gd` (9 tests, game scene): DoD 10 from
  `s2-basket-offscreen`, DoD 5 from `s2-cave-return` and `lost` (left alone
  at 600, lost at 4200 to the loop start; followed, never lost), the camera
  coming back, a save keeping the state, same hash in process and in a
  child process.
- `tests/unit/test_offscreen_single_file.gd` (4 tests, synthetic level;
  chunk 16): parked train slimes keep single file: off the slide behind a
  slower one, a bigger one behind a smaller one, two on one spot coming
  apart, and a parked one behind a simulated one between the margins.
- `tests/e2e/test_offscreen_slopes_e2e.gd` (1 test, game scene, chunk
  16s): from `gate2-open`, a size-3 train slime spawned at 12.9 screens
  with the camera on the start basin stays parked and moves on at least
  95 % of the pace every 5 s for 85 s, down section 3's ramp and on, and is
  never lost.
- Changed because the level grew: `test_test_level.gd` (section 2's IDs,
  sleepers, branch, set and framing zones), `test_frontier_level.gd` (a set
  per section), `test_sleepers_e2e.gd` (69 sleepers), `test_frontier_e2e.gd`
  (the celebration waits for basket 2). `test_slime_physics.gd` turns the
  rest rule off for its contact-solver pile; `slime_test_support.gd` checks
  the new arrays and low-detail point counts.

**Known gaps.** The section 2 greybox is checked by the fixtures' paths
(the cave's route back, trapdoor 2), not yet by a size-3 slime on every
step and shelf. The off-screen pace is an ideal pace (no stalls). Queued
proxies whose place is before the route's start wait at its start. When a
basket has no clear slot left, the slot falls back to the top row's centre
and can overlap.

## Test level sections 2 and 3, full population (chunk 16)

Build plan chunk 16 (`req_level_design_rules` and the level rule atoms,
`req_scope_one_level_four_sections`, `rule_max_200_slimes_per_level`,
`req_test_level_and_test_mode`): section 3 in greybox, the full population
of 200 base slimes, the fixtures for the whole loop, the level rules
checked over the whole level, DoD 1 over the whole level, and the tick cost
measured. Section 2 came with chunk 15 ("Off-screen simulation (chunk
15)"). Sub-steps: 16a/16b (section 3, the population, the fixtures), 16s
(the off-screen stall), 16c-A (the level rule tests, the bench), 16d (the
terrain-contact fix, the cave's framing zone), 16c-B (the DoD 1 test, the
parked train slimes' single file, these notes).

**Section 3, Big bowl (greybox).** `tools/greybox_test_level.gd`
(`_build_section_3`, the `S3_*` tables, `_on_ledge`), regenerated into
`levels/test/level.tscn`:

- the loop: from gate 2 (12.66 screens) down the entry ramp (13.0 to 13.6),
  across the bowl's floor (13.6 to 15.05, ground y 100), up the far wall
  (15.05 to 15.62) to the plateau (ground y -120), over basket 3's trapdoor
  to slide 3's entrance at 16.4 (loop y -144). `s3.slide`, the level's last
  return route (no gate), drops down a chute at 16.4 and runs back under
  sections 2 and 1, joining slide 2's and then slide 1's tail; section 2's
  pillar 2 was taken out to make room;
- the terrain: `S3Crust`; two flat ramp ledges (y -210 and -160); six
  shelves floating in the bowl, three tiers a side (tops about -90/-105,
  -250/-265, -410/-425, tilted down toward the bowl's middle); the rim over
  the far wall and the plateau (15.05 to 16.19, top -300 to -310); all
  25 px thick;
- 130 sleepers `s3.sleeper.01` to `.130` (numbered left to right; three
  digits past 99, so sort them by number, not as text): 10 E on the ramp
  ledges, 15 on each shelf and 30 on the rim, species cycling A E B E C D;
- frontier set 3: signpost `s3.signpost` (15.62), switch `s3.switch`
  (15.67), basket `s3.basket` (centre 16.01, 0.58 screens by 220 px, pit
  floor y 100, quota 60, no rule: the celebration is its target; outlet a
  point 200 px before slide 3's entrance), trapdoor 15.72 to 16.3; no gate;
- framing zones `s3.frame.bowl` (centre 14.375, 1.85 screens wide, zoom
  0.5) and `s3.frame.basket` (centre 15.875, 1.15 screens, zoom 0.8);
- three exploration branches with their routes back into the bowl:
  `s3.branch.left-shelves`, `s3.branch.right-shelves`, `s3.branch.rim`
  (`s3.route-back.*`), in groups Bowl/LeftShelves, Bowl/RightShelves and
  Bowl/Rim.

16d added `s2.frame.cave` to section 2 (Section2/Cave; centre 11.25
screens, y -150, 1.3 screens by 500 px, zoom 0.7, offset (0, -140)): on the
rails from 10.6 to 11.9 the view spans y -767 to 159, the loop and the
cave pocket's 14 sleepers (y -724) at once (rule 9). It stays clear of
`s2.frame.gate` and above O65's 0.6 floor.

**Population.** 1 first slime (A) and 199 size-1 sleepers:

| Section | A | B | C | D | E | Total |
|---|---|---|---|---|---|---|
| S1 (first slime included) | 10 | 9 | 11 | | | 30 |
| S2 | 7 | 7 | 7 | 19 | | 40 |
| S3 | 20 | 20 | 20 | 20 | 50 | 130 |
| Level | 37 | 36 | 38 | 39 | 50 | 200 |

**Fixtures** (the table in "Fixtures"): `gate1-open`, `gate2-open` (added:
the whole loop), `stress-still` and `stress-moving` are new; `bump` was
rebuilt with two size-2, one size-3 and one size-1 C train slime on the
dip's floor (both bumps, 2 + 2 and 3 + 1, on seeds 1 to 8, never a
fusion). `stress-still` is the slow one to build (see "Fixtures"): size-1
slimes don't stack, so a 140-slime pile spreads for about a minute before
it rests; the builder settles it at the zoomed-out detail its camera shows,
reloads it and settles it again 6 times, and keeps the state whose reload
rests soonest (670 ticks today). Every fixture is regenerated when the
level changes.

**The level rules over the whole level** (numbered as in
`specs/level-design.md`):

- `tests/e2e/test_level_rules.gd`: rule 11 (S1 A, B, C; each later section
  adds one), the species total (3 + sections - 1: the test level's 3 give
  5, v1's 4 would give 6), rule 9 (every exploration branch shows a sleeper,
  or for the high step the top of its route back, in a settled rail view of
  its section, framing zones included), rule 3 (in every gate state the
  section's slide takes the frontier back to the start, every segment joins
  the next), rule 5 (the dips at 2.5 to 3.5 and 10 to 10.5 are at least
  80 px below both rims).
- `tests/e2e/test_level_ways_back_e2e.gd`: rules 7 and 8 by behaviour. From
  both ends of every row of sleepers (58 spots), with the level as the loop
  first reaches that section (`fresh`, `gate1-open`, `gate2-open`) and every
  other slime taken out, the sleeper's slime is made free and heading back,
  and must rejoin the train within 70 s (left alone, then lost). Slowest
  after 16d: section 1 17.7 s, section 2 46.4 s (the cave's route), section
  3 26.6 s. About 11 s.
- `tests/e2e/test_level_dod1_e2e.gd`: rules 1 and 2 and DoD 1 (below).
- Already covered: rules 4, 6, 8, 12, 13 and 16 to 19 by
  `test_test_level.gd` and `test_frontier_level.gd` (tags added in 16c-A:
  `rule_max_200_slimes_per_level`, `rule_framing_zone_wherever_wider_view_needed`,
  `rule_gate_opens_via_switch_basket_set`); rule 15 by `test_frontier_sets.gd`
  and `test_frontier_e2e.gd` (and over a session by the DoD 1 test); rule 10
  (nothing needs tilt) by `test_frontier_level.gd` and `test_tilt_e2e.gd`;
  rule 14 (no exploration on the slides yet) by `test_frontier_level.gd`;
  rule 20 by `test_level_registry.gd` and `test_test_level.gd`.
- Rule 21 (every interactive object below the parent zone at the rails'
  framing, D111) by `test_level_rules.gd` and `test_level_checker.gd`
  (chunk 23E). Rule 16's "piles mostly still" is measured (the bench), not
  asserted.

**The off-screen stall (16s).** A parked size-2 or size-3 train slime
stopped on a downhill stretch and was lost as stalled: its centre was
lifted straight up and projected behind its progress. `Offscreen` now moves
the progress itself and lifts the centre along the loop's normal (see
"Off-screen simulation (chunk 15)").

**Terrain contact at sharp corners (16d).** Seven sleeper spots broke
rule 7 (the dip hollows, the hills' bumps 2, 4 and 6): a heading-back slime
stayed stuck. The cause was the terrain contact, not the heading-back aim:
at a sharp convex corner both segments are equally near, and when the
other face's segment was listed first a wedge outside the corner counted
as inside, so ring points passing there were pulled onto the corner. Now
a vertex's own normal (the mean of its two segments') decides there, in
`TerrainSegments.resolve` and `SlimeBodies._solve_against` (see "Terrain
contact"). No level tweak was needed. It changed `stress-still`'s settling
(its reloads rest in 670 to 910 ticks, were under 600) and
`test_tilt_e2e.gd`'s neutral-tilt comparison (15 s instead of 20: the
called slime now reaches the call point and is back on the train by 19 s).

**Parked train slimes keep single file (16c-B).** Found by the DoD 1 test:
a parked train slime going faster than the one ahead ran through it, and
the two came back on screen on one spot, where two rings never come apart.
Now a parked train slime waits a slime's width behind the train slime ahead
(see "Off-screen simulation (chunk 15)").

**Tick cost: the whole level, 200 slimes.** `tools/bench_level.gd` runs
`Simulation.step` as the game does (the view follows the camera, off-screen
simulation on, no input) and times every tick:

```sh
godot --headless --path . -s res://tools/bench_level.gd  # -- --ticks=600
```

- `start`: the level as new (the first slime and 199 sleepers), the camera
  at the start; 600 ticks untimed first.
- `stress-still`: the fixture, the camera where it puts it (the bowl, zoom
  0.5); timed from tick 670 (`REST_TICK`), when the loaded pile rests, and
  over before the idle camera's cue changes the zoom. The script prints
  `camera_steady=true` when the zoom and the rails held throughout.
- `stress-moving`: the fixture, the camera on the bowl; 60 ticks untimed
  (the rings take shape from the saved centres), then the train climbing out
  of the bowl. Train slimes fuse on the way, so the bodies drop while the
  base slimes stay 200.

Runs on the same machine (Ryzen 5 PRO 8640HS, Godot 4.7.2, headless),
600 timed ticks each. 16c-A ran beside a test suite (a little high); 16d
and 16c-B ran alone:

| Case | Base slimes | Bodies | 16c-A median (p95) | 16d median (p95) | 16c-B median (p95), mean | Notes |
|---|---|---|---|---|---|---|
| `start` | 200 | 200 | 1.067 (1.315) | 0.962 (1.008) | 0.980 (1.027), 0.991 | 196 parked |
| `stress-still` | 200 | 200 | 1.422 (1.832) | 1.323 (1.396) | 1.329 (1.399), 1.338 | the 140 in the bowl resting all along, basket 3's 60 parked |
| `stress-moving` | 200 | 200 to 137 | 15.398 (19.695) | 15.094 (18.904) | 14.821 (18.599), 15.385 | 1 parked; fusing as it goes (138 bodies left before 16d) |

All in ms per tick. The single file (16c-B) orders the train slimes with a
native sort: a first version with `sort_custom` cost about 1 ms a tick in
`stress-moving` (200 train slimes, one parked).

`stress-still` resting costs about as much as the level's start (a first
reading of 8.5 ms/tick, before 16b, was the pile not resting yet).
`stress-moving` is the worst moving case, a measurement rather than a
target (D96): beyond what normal play produces.

**DoD 1 over the whole level** (`tests/e2e/test_level_dod1_e2e.gd`, 4
tests). A 15-minute session with no input, through the game scene and test
mode (off-screen simulation on, the camera left to itself, so the idle
camera follows the train), from `gate2-open` and from `gate1-open` (20
train slimes each), checked every 30 ticks: no train slime's progress goes
back; no gate closes, no basket's phase goes back, no switch flips, the
train's open gates never shrink; the level keeps its 200 base slimes;
nothing is in the train's lost log (stalled, out of bounds) nor in the
off-screen one; every train slime makes at least 2 laps. The run repeats:
a second in-process run gives the same hash at 2 minutes, and a child
process (`--test-mode --seed= --fixture= --run-ticks=54000`, started first
and run alongside, its pipe drained as the test goes) gives the same hash
at 15 minutes. Then every size laps the whole loop: from `gate2-open` with
its train slimes taken out, a size-1 A, a size-2 B and a size-3 C (so they
don't fuse) each complete a lap, once with the camera left to itself (so
partly off screen) and once with the camera held on the size-3 slime.
The file took about 4 minutes before 16f added the seed 6 session (in 16e's suite run: the sessions 86 s
from `gate2-open` and 85 s from `gate1-open` in process, plus the 2-minute
rerun, the child running alongside; the laps 25 s and 27 s, each size
lapping in 21 600 to 23 400 ticks, about 6 minutes of play). Seed 2: every
train slime makes 2 or 3 laps from `gate2-open`, 3 or 4 from `gate1-open`. It is the
slowest test file; if the suite's time matters, it is the one to run apart.

**The start basin jam (fixed in chunk 16e).** Before 16e, DoD 1 broke on
seed 2 from both fixtures, and probes on seeds 1 to 4 and 16 lost a train
slime as stalled in 5 of 10 sessions, always in the start basin: the
slides' tail ran back along the basin floor (0.62 to 0.3 screens) over the
loop's first stretch the other way, so each slime coming home shoved the
train slimes heading for the rise back 100 to 250 px; slimes queued there
fused past the split zone (which ended at 0.4) and a size 3 then crawled
under the first sleeper's ledge (37 px in 20 s); a slime kept behind its
recorded progress for 60 s was lost. Chunk 16e rebuilt the basin (see "The
test level"): the slides come home under a terrace and up into a pocket
behind the loop's start, the ledge is where a called base slime reaches it,
and the split zone reaches past it. The session tests have no known break
now. The train's stall rule (`Train.LOST_STALL_*`) is chunk 6's
placeholder and is not changed.

Probes after 16e, 15 minutes with no input from each fixture (the probe
stops at the first loss): seeds 1 to 8 and 16 from `gate1-open` and from
`gate2-open`, 18 sessions, none lost a slime or went back. From
`gate1-open` every slime made 3 laps. From `gate2-open` they made 2 or 3,
except seed 6, where the dip nudge held a mixed queue in the bowl (fixed in
chunk 16f, below).

**The dip nudge and DoD 1 (chunk 16f).** The dip nudge waited with no
limit for a partner that a slime of another species kept back, so a mixed
queue stood on a dip's floor (see "Fusion and bumping", "A mixed queue on a
dip"). Probes, 15 minutes with no input, seeds 1 to 8 and 16 from each
fixture: before 16f, `gate2-open` seed 6 left 13 of its 17 train slimes at
1 lap; after, every train slime made 2 or 3 laps from `gate2-open` and 3 or
4 from `gate1-open` in all 18 sessions, none stalled or lost, nothing went back.
The DoD 1 test now also runs `gate2-open` on seed 6 (without the repeat
runs), so the file takes about 6 minutes.
The level bench (`tools/bench_level.gd`) is unchanged within noise: 0.999,
1.325 and 15.119 ms median per tick (`start`, `stress-still`,
`stress-moving`).

**Known problems still open.**
- On screen, woken bowl slimes crowd: a rejoin probe lost 6 train slimes to
  stalls and left one free slime stuck at 14.57 screens, y 26; 40 size-1
  slimes in the bowl for 5 min lost 0, 1, 0 on seeds 1 to 3.
- Reach: ramp ledge 1 (y -210) and the upper shelves only by a size 2 or 3;
  the rim only by a size 3 from the plateau's right end (16.3 to 16.4).
- Big piles outside a basket rest slowly: the rest rule's anchor is where
  the count started, so in a large touching group of size-1 slimes (which
  don't stack) some member always creeps past 1 px until the whole pile has
  stopped spreading. Kept for v1 and revisited in chunk 22 (O87, D107).
- A centre can end up inside a terrain outline when a ring hits the end of
  a floating piece thinner than the 32 px `TerrainSegments` needs (the
  level's are 20 to 25 px): its points end up on both faces. No spot of the
  level triggers it since 16d; pieces of 32 px or more would remove it
  (O91, D100).

**Deviations from `specs/levels/test/README.md`** (for spec-writer):
- `s2.frame.cave` (16d, above) is not in the README's framing-zone table,
  its stable IDs, or `specs/tuning.md`'s zone values.
- `stress-still` rests about 670 ticks (11 s) after loading since 16d; the
  README says about 8 s.
- The start basin (1.1) is rebuilt (chunk 16e, "The test level"): the
  loop's start is at 0.21, y 476 (was 0.3), at the top of a ramp, with a
  pocket behind it (floor y 500, 0.05 to 0.21; the level's left wall is
  0.03 thick there); the loop's route rises over the ramp to 0.25, 416 and
  its first stretch runs on a terrace (top y 460, 0.26 to 0.6), then
  climbs out at 35-38° (the lip at 0.64 is gone);
  the slides' tail runs under the terrace (0.78, 561; 0.64, 576; 0.28,
  586) and up the ramp to the loop's start (0.255, 566; 0.21, 476), no
  longer along the basin floor; the first slime starts at 0.19,
  476 (was 0.3); the first sleeper sits at 0.46, 311 (was 0.48, 376) on
  `FirstLedge`, 0.42 to 0.5, top y 335, 20 px thick (was 0.44 to 0.52,
  top y 400), 0.27 screens to the right of the first slime (the README
  says about a third); the split zone spans x 0.03 to 0.54, y 370 to 560
  (was 0.12 to 0.4, y 400 to 500), past the first sleeper's ledge, so only
  base slimes pass under it (a ledge a called base slime can reach is too
  low for a size 2 or 3 to pass under at its pace). The slides' tail is
  still a placeholder (O22).
- The `bump` fixture (chunk 16f, "Fusion and bumping"): both bumps within
  20 s on seeds 1 and 3 to 7, the README says seeds 1 to 8 (seeds 2 and 8
  now show the 3 + 1 bump only). The end-to-end test's seed 5 shows both.
- `Fusion.DIP_WAIT_SECONDS` (5 s, chunk 16f) is a new tuning value, proposed
  for `specs/tuning.md`.

**Running.**
```sh
godot --headless --path . -s res://tools/greybox_test_level.gd   # the level
godot --headless --path . -s res://tools/make_fixture.gd         # all fixtures
godot --headless --path . -s res://tools/make_fixture.gd -- stress-still
godot --headless --path . -s res://tools/bench_level.gd          # tick cost
tools/test.sh -gdisable_colors -gselect=test_level_dod1_e2e      # DoD 1
```

## Sessions (chunk 17)

Master spec §5.7, DoD 20-22, D95 (`req_session_lifecycle`), with O68
(reopening resumes where it was) and O69 (only a tap that reaches the world
starts a session) built to their proposed defaults. `Session`
(`src/sim/session.gd`, pure logic) is `simulation.session`; the scene layer
hands it the clocks and shows its effects.

**The state machine.** Phases are strings (`Session.PHASES`):

```
screensaver --world tap--> session --14:00--> wind_down --15:00--> bedtime --25:00--> screensaver
```

One timer, `elapsed_ms`, counts real milliseconds since the session
started: `WIND_DOWN_MS` (840 000), `BEDTIME_MS` (900 000), `SUNRISE_MS`
(1 500 000: bedtime plus the 10-minute cooldown). Sunrise is the transition
`sunrise(sim, cue)` back to screensaver mode (chunk 18's wake early will call
it too). `advance()` runs once a tick, after the input and before the
slimes move; its checks are sequential, so a long gap goes through every
phase it passed, each with its effects. A sunrise more than
`SUNRISE_CUE_LATE_MS` (1 s) late shows no cue (`sunrise_tick` = -1): a
cooldown that ran out while the app was closed lands in screensaver mode
without replaying sunrise.

**Who starts a session.** `Simulation._tap()`: a tap whose zone is open
ground or an object starts one when `session.can_start()` (sessions open,
screensaver mode), and still does its usual job (a call, a sleeper call).
The parent band and the edge buttons never do (the edge button still
presses). `start()` takes the tilt's neutral.

**Sessions open or not.** `session.enabled` is a mode set from outside and
not in the dump, like `screensaver`: `main.gd` calls `session.open(sim)` in
normal play after loading the save, and test mode does when its run says
`"sessions": true`. Open, the session sets `simulation.screensaver` every
tick (on only in screensaver mode). Not open (the unit tests, test mode by
default) the game plays untimed, as in an endless session, and
`screensaver` is left to whoever set it; a restored session or bedtime
still counts down.

**The clock rule.** The simulation never reads a clock (a unit test lints
`src/sim/` for it). Before every tick `main.gd` calls
`session.read_clock(reading)`, a `Session.reading(wall_ms, mono_ms,
epoch)`: in normal play `SessionClock.now()` (`src/save/session_clock.gd`:
Unix time, `Time.get_ticks_usec()`, and an epoch naming this process), in
test mode `test_mode.clock_at(tick)`. Without a new reading time stands
still. The session keeps `anchor` `{wall_ms, mono_ms, elapsed_ms}` (where
counting last started over) and `clock` `{wall_ms, mono_ms, epoch, tick}`
(the last reading counted):
- same epoch: `elapsed = anchor.elapsed + max(mono - anchor.mono, wall -
  anchor.wall)`. The monotonic clock ignores the player setting the wall
  clock back; the wall clock covers a phone asleep, which may pause the
  monotonic one. Counting from the anchor, not step by step, keeps the two
  from adding jitter.
- a new epoch (the app was killed or the phone restarted): the time away is
  the wall clock's gap, `max(0, wall - clock.wall)`; the anchor starts over
  there, and a session or wind-down takes the tilt's neutral again.
- `elapsed_ms` never decreases.
Coming back from the background (`NOTIFICATION_APPLICATION_RESUMED`) calls
`session.reopened()`: the next step takes the neutral again during a
session or wind-down.

**Effects.**
- Wind-down: `dusk(tick)` ramps 0 to 1 over the minute; `hop_rate(tick)`
  slows the hop timers from 1 to `WIND_DOWN_HOP_RATE` (0.5), through
  `SlimeBodies.hop_rate` (set every tick, not dumped; at 1.0 the arithmetic
  is unchanged, so no earlier hash moved).
- Bedtime (`_bedtime`): train and free slimes become bedtime-asleep where
  they are, hops let go; sleepers and slimes in a basket are left alone
  (a slime in a basket sleeps in place: it stays `in_basket`, and the
  frontier sets stand still until sunrise, chunk 23D below "Frontier
  sets").
  The edge buttons hide (`camera.edge_buttons_visible`, a held one lets
  go), `hint.bedtime` is set, and `session.save_due` asks the game root to
  save (it does when autosave is on). Taps at bedtime still ripple and the
  parent band stays, but they hit no object, no edge button and never call.
- Sunrise (`_wake`): a bedtime-asleep slime within `FreeSlimes.REJOIN_DISTANCE`
  (plus its extra radius) of the loop is the train again (the train adopts
  it; its lap count starts over), any other is free and heads back. The
  edge buttons show, the hint may show again, screensaver mode is on, and
  `dusk()` fades from 1 to 0 over `SUNRISE_SECONDS` (3 s) when there is a
  cue.
- `SessionScreen` (`src/session/session_screen.gd`, a `CanvasModulate` on
  the game root, so the HUD isn't tinted) lerps white to `DUSK_COLOUR` by
  `dusk()`, and keeps the screen on during a session or wind-down only
  (`DisplayServer.screen_set_keep_on`; skipped headless). `DUSK_COLOUR` is
  a placeholder until the ui_ux tree settles the dusk.

**Saves.** `SaveData` writes `session` (`session.dump()`: `phase`,
`elapsed_ms`, `anchor`, `clock`, `sunrise_tick`, all whole numbers and
strings) and checks it (a known phase, whole numbers, `anchor` and `clock`
together). Restoring puts back what it implies (at bedtime: edge buttons
hidden, the hint's bedtime); the first step after a reload counts the time
away by the rule above, so a killed session or bedtime resumes where it
was. `enabled`, `save_due`, the pending reading and `reopened` stay out of
the dump, so a normal-play reload still has the saved hash.

**Test mode's clocks and skipping time.** `TestClock`
(`src/test_mode/test_clock.gd`) is a pure function of the tick: both clocks
run 1000/60 ms a tick from a base (the save's `session.clock` and its tick,
else wall 1 800 000 000 000 ms, mono 0, epoch `"test"` at tick 0), plus the
script's `skip` steps on the run's start tick or later (a reloaded run
doesn't count again the skips before its save). The run's `"clock"`
setting says what happened before it starts: `"away"` seconds pass on both
clocks, `"restarted": true` gives a new epoch and a monotonic clock from 0.
So a scripted session reaches bedtime with `{"tick": 150, "do": "skip",
"seconds": 900}`, and a kill-and-reopen is a save then a run with `"load"`
and `"clock": {"away": 60, "restarted": true}`. `Session.jump(sim, ms)`
sets the timer directly (tools and tests).

**Fixtures.** `wind-down` (14:50), `bedtime` (15:00) and `sunrise` (9:55
into the cooldown), made by `tools/make_fixture.gd` from the fresh level:
a session started on the default test clock and jumped with
`Session.jump()`. Run them with `"sessions": true`
(`tests/e2e/scripts/session_sunrise.json` does).

**Tests.**
- `tests/unit/test_session.gd` (28 tests): untimed by default, opening,
  which taps start a session and the neutral, the phase thresholds, dusk and
  the hop rate, bedtime's effects and inert taps, waking near and far from
  the loop, the clock rule (wall set back, monotonic lagging, never
  backwards, restarts with and without a gap, reopening), catching up with
  and without a cue, save round trips and checks, the readable form,
  `TestClock`, `skip` parsing, test mode's settings, and the no-clock lint.
- `tests/e2e/test_session_e2e.gd` (8 tests) on the test level: DoD 20
  (parent band and edge button don't start a session, a world tap does,
  bedtime 15 minutes later; resume after a kill in test mode and in normal
  play with a stand-in `session_clock`, which also saves at bedtime), DoD
  21 (from `wind-down`: dusk, slower hops, the tint, then bedtime asleep,
  saved, buttons hidden, a tap only ripples), the `bedtime` fixture, DoD 22
  (from `sunrise`: sunrise 5 s in, screensaver mode, everyone awake, the
  next tap starts a session), repeatable in process and in a child process.
- Wake early (DoD 22's parent part) is chunk 18's.

**Choices.** One timer through all phases, rather than a timer per phase,
keeps catching up one comparison per limit. The clock rule trusts the
larger of the two clocks inside an epoch and the wall clock across one; a
player who moves the wall clock forward while the app is closed shortens
the cooldown (accepted: the monotonic clock can't survive a restart).
Bedtime-asleep slimes fall and settle like any body, then rest as a pile
(chunk 15's resting-pile rule: a settled pile stops simulating and is a
wall until something disturbs it; bedtime and sunrise, as state changes,
wake it), and off screen they are parked like every slime.

## Debug overlay

Developer tooling for playing the test level, not a build-plan chunk: a bar
of controls under the parent band, in debug builds only. The code is all
in `src/debug/`; the game root has a few hooks (`add_debug_overlay()`,
`restart_fresh()`, the speed factor in `_process`, the first line of
`_unhandled_input`). Tests: `tests/unit/test_debug_overlay.gd` and
`tests/e2e/test_debug_overlay_e2e.gd`.

![The debug overlay at 2x with labels on and Kill armed, seed 91 from the bump fixture](img/debug-overlay.png)

The screenshot is from a debug run with a display (`xvfb-run`, `--fixed-fps
60`, `-- --test-mode --seed=91 --fixture=bump`), with a scratch script turning
labels on and 2x at frame 3 and arming Kill at frame 150: tick 299 at frame
152. The magenta banner above is test mode's; its "time x1.0" is test mode's
`time_scale`, and the overlay's speed multiplies it.

| Control | What it does |
|---|---|
| **1x / 2x / 5x / 10x** | The simulation speed. Each frame runs that many times the ticks (the same ticks, see below) |
| **Reset** | Asks ("Reset? click again"). A second click within 2 s starts the level over and replaces its save |
| **Labels** | Draws each slime's runtime id and state under it (`#12 train`) and its stable ID on a second line (`s1.sleeper.04 +2`: its first member and how many more) |
| **Kill** | Arms the kill tool (red, "Kill: tap a slime"). The next tap sends the slime under it to the start of the loop, as a lost slime |
| **Woken n / available m** | The counter, in base slimes (see below) |

The last action's result shows after the counter for 4 s ("Kill: #12 sent
to the start of the loop", "Reset: fresh level, save replaced") and Reset
also prints it.

**Speed and the clocks.** The game root multiplies its frame time by the
overlay's `speed` before `FixedStep`, like test mode's `time_scale` (they
multiply), and raises the hitch cap with it (8 ticks a frame times the
speed, so 80 at 10x). The ticks are the very same ticks: a run at 10x has
the same state hash as at 1x after the same tick. The sessions' clock runs
at the same speed: `DebugClock` wraps the game root's `session_clock` and
adds (speed - 1) x the real time elapsed to both its wall and monotonic
readings, so at 10x a session reaches bedtime in 1 min 30 s. The offset
only grows (back at 1x the time already gained stays), so a session never
sees its clock go back. After a restart the real clock has no offset, and
the new epoch counts no time away until real time catches up (the rule is
`max(0, wall - saved wall)`). In test mode the session clock is test mode's
tick-counting `TestClock`, which already follows the speed. Autosave stays
on real time (every 15 s of wall time, whatever the speed): it guards
against losing real play, not simulated time.

**Reset.** `main.restart_fresh()` starts the level over as a first launch
does: a fresh simulation from a new random seed in normal play (sessions
open, so the next tap starts one), or from the run's seed in test mode (no
fixture, sessions open when the run has them; a test script carries on by
tick number from the new tick 0).
Then, when the game autosaves (normal play, or test mode with `autosave`),
the overlay saves at once through `SaveStore.write`: the fresh state is
written over the level's file, by the usual side file and rename, never by
deleting it. A save SaveStore has blocked (unreadable or unusable at
launch) is still never written over: the reset happens, the file stays, and
the overlay says "save not written". The 2 s window is real time.

**The counter.** "Woken" and "available" count base slimes, by the members
each slime carries (D72), so fusing and splitting don't move them; a slime
with no members (one a test spawns) counts its size, in section 1.
Available: every base slime from an accessible section. Woken: those not in
the sleeper state (train, free, in a basket, asleep at bedtime). Sections
aren't recorded per slime, so a member's section is its stable ID's prefix:
`sN.` is section N, and anything else (`start.first-slime`) is section 1.
The accessible sections are section 1 plus every section in the loop's
current segments with the open gates (`LoopData.current_segments`): a
section's entrance is the previous section's return-route gate, so opening
`s1.gate` makes section 2 accessible. The open gates are the train's
(`Train.open_gates`, kept in step by the frontier sets).

**Kill.** The tap is intercepted before the simulation: the game root's
`_unhandled_input` asks `DebugOverlay.intercept()` first, and while Kill is
armed the next press anywhere (and its release) is the overlay's. So no
tap, ripple, call or session start reaches the simulation, even with test
mode's `block_real_input` on. `DebugKill.slime_at` picks the slime whose
drawn body, grown by the tap zones' 24 px margin, holds the point (the
nearest centre if several). The move is the lost-slime move,
`Offscreen.lose(sim, id)` (public since chunk 23A, called directly): the
slime goes to the start of the loop, back on the train (`LoopStart.move`:
the first free spot from the start, see "Safety nets: stuck and stalled
slimes (chunk 23A)"), and is logged in `offscreen.lost`. Any slime can be sent, a sleeper too: it
becomes a train slime (that's what makes it useful for testing). One use,
a tap on no slime, or any other control disarms it; a click on Kill again
does too.

**Input.** The controls are Buttons with `mouse_filter` STOP and consume
their mouse clicks before the game sees them. The game root also swallows
a touch on a control (on a phone the touch comes besides the emulated
click). The bar, the counter and the labels ignore the mouse: the rest of
the screen plays as usual. The bar sits 8 px under the parent zone
(`TapDispatcher.parent_zone_height`, placed every frame from the
simulation's view), so it never eats a parent-zone tap and
the band keeps its meaning; a control over the world takes that spot's
taps, which is fine for a debug tool. The overlay is a CanvasLayer (layer
50) above the HUD; the labels are a world-space Node2D beside
`TapFeedback`, and only read the simulation.

**The release guard.** The game root adds the overlay only when
`TestModeGuard` allows it (a debug build) and only when it is the running
main scene; a game a test adds gets one only through
`add_debug_overlay()`. It names the overlay by path only
(`DEBUG_OVERLAY_SCRIPT`), and no script outside `src/debug/` names a debug
class (a lint in `tests/unit/test_debug_overlay.gd`), so a release export
loads nothing from `src/debug/` and its preset can leave it out.

## Saves and fixtures

Master spec §6.4 and D72 (`req_persistence_and_saves`,
`rule_saves_never_wiped`). The format is `SaveData`
(`src/sim/save_data.gd`, pure logic); `Simulation.to_save()` and
`Simulation.from_save(save, level_data, terrain, fallback_seed)` wrap it. A
reloaded save has the saved state hash and stays equal to the run that
never stopped, tick for tick (`tests/unit/test_save_data.gd`).

### What a save holds

One JSON object, keys sorted, tab-indented:

| Key | What |
|---|---|
| `format` | 1. A newer format is refused, never read half-way |
| `level` | `{"id", "version"}`. Another id or version is refused (migration: chunk 19) |
| `sim` | `tick`, `seed` and `rng_state` (strings: 64-bit), `next_slime_id`. Optional |
| `slimes` | Every slime, in runtime id order (at least one): `id` (its stable ID, below), `members`, `runtime_id`, `species` (a letter), `size`, `state` (`train`, `free`, `sleeper`, `bedtime_asleep`, `in_basket`), `centre`, `velocity`, then `train` (distance, laps, slide, stall mark; a `lost` flag from before chunk 23A is ignored) or `free` (phase, since, point, route back, stream state), and `body` (points, previous points, the solver's centre, hop timer, heading, held, supported, stream state) |
| `train` | The open gates and the stalled log (`stalled`: `{"id", "tick", "reason"}`, chunk 23A; the key was `lost` before and is ignored now) |
| `call` | The last call (point, tick), or null |
| `objects`, `gates` | Stable ID to state (chunk 14): a switch `{"flipped", "trapdoor_shut"}`, a basket `{"phase", "weight", "since", "next_release"}`, a gate `{"open", "entrance_closed"}` (see "Frontier sets (chunk 14)") |
| `celebration_done` | `true` once the level's celebration has played; left out (false) before. Optional |
| `transient` | The view, the camera, the ripples, the last taps, the facings, the input log, the tilt (reading, neutral, flat), the fusion contact counts and the celebration's start tick and double hops still due (`frontier`: `celebration_since`, `celebration_hops` `[[slime id, hops left]]`, optional, chunk 23D). Optional |
| `session` | The session (chunk 17): `phase`, `elapsed_ms`, `anchor` and `clock` (the clock readings it counts from; see "Sessions (chunk 17)"), `sunrise_tick`. Optional: none is screensaver mode |
| `stuck_slimes` | The stuck safety net (chunk 23A): `counts` (`[lower id, higher id, checks]`) and the `stuck` log (`{"id", "other", "tick", "reason", "moved"}`). Optional: none is no count, no case |

Not saved: the fingers on the screen and input not yet consumed (a
restarted game has no finger down: a held edge button is let go), and what
each tick recomputes (hop aims, touching pairs, rest shapes).

**Exact reals.** Godot's JSON parser doesn't always read a 17-digit double
back to the same double (about one in seven), so every real goes through
`SaveData.exact()`: a plain number when it reads back the same, else
`"f64:<16 hex digits>"`, its IEEE bytes. Body points are base64 of their
coordinates as little-endian doubles. JSON reads every number as a float;
the loader turns whole numbers back into ints where the state has ints.

**Hand-made saves** (fixtures) may leave out `sim`, `runtime_id`, `body`,
`train`, `free.rng_state` and `transient`: the run's seed and tick 0, ids 1,
2, ... in list order, a rest ring at the centre, the loop's closest point,
a fresh stream, an empty view. `SaveData.readable()` cuts a save down to
that form; it keeps a running session (its last clock reading moved to tick
0, where the readable save starts) and drops one in screensaver mode. `SaveData.problems(save, level)` lists what makes a save
unusable, without pushing errors.

### Stable identity (D72)

Runtime ids change with every fusion and split; a save names slimes by the
placed base slimes they are made of (`SlimeIdentities`,
`src/sim/slime_identities.gd`). A slime's `members` are those stable IDs,
sorted; its `id` in the save is the first member.

- A placed slime has one member: the first slime `start.first-slime` (named
  by `load_level()` from the level's FirstSlime marker), a woken sleeper its
  own ID (chunk 9).
- A fusion (`Simulation.fuse(a, b)`, the hook for chunk 10) gives the union
  to the lower runtime id, the one `SlimeBodies.merge` keeps.
- A split gives the members out in sorted order: part 0 (the original id)
  the first, part k the k-th. Members beyond the part count stay with part
  0; parts beyond the member count get none (a slime a test spawned has
  none).

### Files and autosave

`SaveStore` (`src/save/save_store.gd`) keeps one file per level,
`user://saves/<level id>.json` (on Linux,
`~/.local/share/godot/app_userdata/Slime Train/saves/`). A test gives it
another directory. The game (`src/main.gd`) reads it at start in normal
play: a usable save is resumed, a missing file means a fresh start (the
first slime woken).

It never wipes a save (`rule_saves_never_wiped`):

- no code under `src/` can delete a file (a lint test in
  `tests/unit/test_save_store.gd`; the one rename allowed is SaveStore's);
- a save with no slimes, or with a NaN, is refused and the old file kept;
- a write goes to `<file>.new`, is read back, then renamed over the old
  file: a write that fails leaves the old file;
- a file it can't read, or a save of another level version, is left as it
  is: the game starts fresh, prints why, and writes nothing over it for the
  session (`SaveStore.block`). A backup copy and migration come with chunk
  19.

`Autosave` (`src/save/autosave.gd`) saves every 15 s of wall time, and on
`NOTIFICATION_APPLICATION_PAUSED` (Android and iOS leaving the
foreground), `NOTIFICATION_APPLICATION_FOCUS_OUT`,
`NOTIFICATION_WM_CLOSE_REQUEST` and `NOTIFICATION_WM_GO_BACK_REQUEST`
(Android's back button), and when the game root leaves the tree
(quitting). Only the main scene gets the default store; a game a test adds
without one never writes. Test mode turns autosave off unless its run says
`"autosave": true`.

To see it: `godot --headless --path . --quit-after 300` writes
`user://saves/test.json`; run it again and the game carries on from there.

### Fixtures

A fixture is a named starting point for test mode (`"fixture": "bump"`),
in the level's `levels/<id>/fixtures/` (the test level's are below): a sidecar `<name>.fixture.json`,
`{"description", "save" (true when there is a save), "camera" (optional
[x, y]: the camera starts on its rails nearest that level point)}`, and the
save `<name>.json` in the hand-made form above.

| Fixture | State |
|---|---|
| `fresh` | No save: the level as new, the first slime at its marker, every sleeper asleep at its own, the hint due |
| `bump` | Four train slimes of species C on the fusion dip's floor, left to right sizes 2 (`s1.sleeper.14`, `.15`), 2 (`.10`, `.13`), 3 (`.04`, `.07`, `.20`) and 1 (`.21`), 0.05 screen apart at x 2.95 to 3.1 (the eight C sleepers nearest the dip; their bodies gone, the other sleepers asleep), and the first slime; the camera on the dip. Both bumps happen, 2 + 2 and 3 + 1, and nothing fuses (seeds 1 to 8, 20 s, chunk 16) |
| `s1-basket-5of6` | Switch 1 flipped (its trapdoor open), basket 1 at 5 of 6: a size-3 C and a size-2 B resting in it, made of the five ledge sleepers above the switch; the first slime on the loop just before the switch, so it drops in and the basket fills, fires and opens gate 1 (no celebration: basket 3 is the last); the camera on the basket |
| `s1-optout` | Switch 1 flipped, basket 1 at 3 of 6: a size-3 C resting in it (the three C ledge sleepers; the B ones asleep), the first slime at its marker; tap the switch to opt out; the camera on the basket |
| `wind-down` | The fresh level 14:50 into a session (the wind-down on, bedtime 10 s in), on test mode's default clocks. Run it with `"sessions": true` |
| `bedtime` | The fresh level with bedtime just reached: every awake slime asleep, the edge buttons hidden, the 10-minute cooldown starting |
| `sunrise` | The fresh level at bedtime, 9:55 into the cooldown: sunrise 5 s in |
| `s2-basket-offscreen` | Gate 1 open (basket 1 fired, slide 1 shut), switch 2 flipped and basket 2 at 14 of 15 (a size-3 A, B, C and D and a size-2 D resting in it, made of section 2 sleepers); the first slime on the loop just before switch 2; the camera on switch 2, 1.5 screens from the basket: the basket fills off screen, waits, and fires once in view, opening gate 2 (DoD 10); no celebration: it waits for basket 3 |
| `s2-cave-return` | Gate 1 open; 3 free size-1 slimes (A, B, C, the cave pocket's sleepers) on the cave tunnel's first shelf, down its route back; the camera on the start basin: off screen they follow the route back, are left alone at 10 s and rejoin the train (DoD 5) |
| `lost` | The fresh level with one free size-1 D (a parade sleeper) on the parade's first ledge beyond closed gate 1, with no route back or loop near: left alone at 10 s, lost at 70 s and moved to the start of the loop (DoD 5) |
| `gate1-open` | Gate 1 open as after basket 1 fired (switch 1 inert, slide 1 shut): the loop runs into section 2. 20 size-1 train slimes (the first slime and `s1.sleeper.01` to `.19`) spread along the outgoing loop from 60 px past the split zone to 400 px before its end; the other 180 asleep; the camera at section 2's start (8.3 S) |
| `gate2-open` | Gates 1 and 2 open as after baskets 1 and 2 fired (slides 1 and 2 shut): the loop runs through section 3 to slide 3. The same 20 train slimes, spread along the whole outgoing loop; the camera at section 3's start (13.0 S). Added in chunk 16 for the whole loop (DoD 1) |
| `stress-still` | Gates 1 and 2 open, all 200 base slimes woken, none left asleep: 60 size-1 slimes in basket 3 (switch 3 flipped, the basket full, waiting to be in view: out of it, they park), and 140 piled at the bottom of section 3's bowl, asleep at bedtime (a session at bedtime: outside a basket, a pile rests only asleep); the camera on the bowl (its framing zone zooms to 0.5, so the rings are zoomed-out). The pile comes to rest about 670 ticks (11 s) after loading and stays resting (the worst still case on one screen; see below) |
| `stress-moving` | Gates 1 and 2 open, all 200 base slimes as size-1 train slimes spread through section 3's bowl from its bottom up (the floor, the slopes, the shelves; x 13.5 to 15.33 S, inside the view), each following the loop from its nearest point; the camera on the bowl. The worst moving case: a measurement, not a target (D96) |

To make or remake them: `godot --headless -s res://tools/make_fixture.gd`
(all) or `... -- bump` (one). `gate1-open`, `gate2-open`, `stress-still`
and `stress-moving` came with the whole level (chunk 16); `gate1-open` and
`gate2-open` start the DoD 1 sessions (`tests/e2e/test_level_dod1_e2e.gd`). Each fixture is a builder function in the
tool that sets up a simulation on the test level and saves it; the tool
looks the stable IDs up in the level scene and checks the save loads back.
To add one, add an entry to `FIXTURES` and its builder. Fixtures follow
the level: when it changes, run the tool again. Since chunk LD1 it takes
`--level=<id>` (another level gets the generic `fresh` and `gate<k>-open`)
and `--list` (see [level-tooling.md](level-tooling.md)).

`stress-still` is the slow one (about a minute): a fixture keeps only each
slime's centre, so a loaded pile starts from round bodies and settles again,
and size-1 slimes don't stack (a pyramid of them flattens into a row), so a
140-slime pile spreads slowly before it rests. The builder settles it at
the zoomed-out detail the fixture's camera shows until every slime rests
(at most 2 minutes, else it fails), then reloads it from its save and
settles it again 6 times, and keeps the state whose reload rests soonest
(it must within 12.5 s; today 670 ticks). Before chunk 16d's terrain
corner fix it rested at 490 with 4 rounds and a 10 s bar; with the fix the
reloads rest in 670 to 910 ticks (4 rounds gave 744 at best), so the rounds
went to 6 and the bar to 12.5 s, under the 15 s the load test allows. `test_fixtures_e2e.gd` checks that
the loaded pile rests.

## Level-design toolkit (chunk LD1)

Build plan chunk LD (D123), part 1: the tools. Technical: no ATD steps.
The design note, every tool's usage and the choices made are in
[level-tooling.md](level-tooling.md); the tutorial for level designers and
the project skills built on these tools come in part 2
(`docs/level-design/`, `.claude/skills/`).

- **Levels by ID:** `LevelCatalog` (`src/level_catalog.gd`) finds
  `levels/<id>/level.tscn` and `levels/<id>/fixtures/` by convention. Test
  mode takes `"level"` / `--level=<id>` and `"at"` / `--at=` (see "Test
  mode"); a normal debug run still loads the test level, and the player
  never chooses a level.
- **The level-rules checker:** `tools/check_level.gd -- --level=<id>`,
  rules 1 to 22, PASS / FAIL / MANUAL / N/A, on the library
  `tools/level_check/`. The level-rule tests of the test level call it. It
  finds one break of rule 22 on the test level (`Dip2Hollow`, section 2),
  reported in [level-tooling.md](level-tooling.md), not fixed here.
- **The scaffolder:** `tools/new_level.gd -- --id=<id> [--sections=N]`
  writes a skeleton level that passes the checker, its `fresh` fixture and
  its test script `tests/e2e/levels/test_level_<id>.gd`.
- **Helpers:** fixtures for any level (`tools/make_fixture.gd --
  --level=<id>`), a level report (`tools/level_report.gd`), the level
  builder (`tools/level_builder/`, which the test level's generator now
  uses) and the `Decoration` component (O96's proposed default).
- **Species F** is now accepted by the `Sleeper` and `FirstSlime`
  components (v1's level has 6 species; the test level places A to E).

Tests: `tests/unit/test_level_catalog.gd`, `test_decoration.gd`,
`test_level_builder.gd`, `test_test_mode.gd`; `tests/e2e/test_level_selection_e2e.gd`,
`test_level_checker.gd`, `test_new_level_e2e.gd`, `test_level_tools_e2e.gd`.
The e2e tests that need a second level create a throwaway one
(`levels/zz-*`) and remove it, crashed runs' leftovers included.

## Level-design tutorial and skills (chunk LD2)

Build plan chunk LD, part 2: docs and skills only, no code.

- **The tutorial:** [`docs/level-design/`](../level-design/README.md), one
  task per page for a level designer: concepts, scaffolding, editing in the
  editor (and editing `level.tscn` as text), adding a section, the
  components and the rules each must meet, exploration branches and routes
  back, population, decoration, fixtures and test mode, reading the
  checker, the level report, and a done checklist. Every command in it was
  run on a throwaway level (`zz-tutorial`, removed); its two screenshots
  are in `docs/level-design/img/`.
- **The project skills** (`.claude/skills/`, tracked): `new-level`
  (scaffold, run the level's test, the checker and the report),
  `level-content` (add a section, place or configure an existing
  component, add a decoration, then check), `level-review` (every rule of
  `specs/level-design.md` with the checker's result, FAILs to fix, MANUAL
  items as a checklist). `level-review/scripts/rules_table.py` reads the
  rules from the spec at run time and merges the checker's `--json`.
- **Gotchas found while writing it** (in the pages): after a pull that adds
  classes, the headless tools fail to parse until `godot --headless
  --import`; `--json` output follows Godot's banner (keep `tail -n 1`);
  opening the editor drops `window/handheld/orientation=0` from
  `project.godot`; a fixture's save goes stale when the level changes.

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

### Chunk 8: save format and fixtures

- **The whole state, exactly.** A save holds everything in the hash (body
  points and previous points, streams, timers, the view, the camera, the
  ripples, the taps, the input log, the tilt), not just the spec's
  essentials, so a reload is equal by hash and not merely close. Reals that
  JSON can't carry exactly go as their bytes.
- **The saved tilt neutral is kept on load.** `load_level()` takes a new
  neutral, then the save's tilt state is put back, so the reloaded state
  equals the saved one. Taking a neutral when a session resumes belongs to
  sessions (chunk 17, D95).
- **The view follows the screen.** A save restores the view, but the game
  re-syncs it to its window every tick: a resumed game on another screen
  size has another view (and hash) at once.
- **Unusable saves block writing.** An unreadable file or a save of
  another level version is kept untouched and nothing is written over it in
  that session; the player plays fresh. The other choice (refuse to start)
  seemed worse. Chunk 19 adds the backup copy and migration.
- **Writes go through a side file and a rename** now, rather than chunk
  19's full scheme, so a failed write can't cut a save short.
- **Fixtures are generated**, by a tool that looks the stable IDs up in the
  level, rather than typed in; their saves are the readable hand-made form.
- **Object and gate states are plain JSON** keyed by stable ID; chunk 14
  gives them their types (JSON reads numbers back as floats).

### Chunk 7: taps and the call

- **Taps are resolved in the simulation, through a view.** The scene only
  copies the simulation's camera (chunk 12) into `simulation.view` each tick, so scripted and real
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
  Heading back directly keeps at least 60 px sideways, level with the
  slime, or a slime on a ledge right above the loop hops in place.
- **Placeholders:** the top band (64 px) and edge buttons (96×192 px) until
  ux-writer settles them; the ripple ring and the eye dot as art. (Chunk
  23B replaced both sizes with the spec's: the 7 mm parent zone and the
  whole-height strips.)
- **The basket is a tap target** (per the build plan), though the spec has
  a basket act by presence: it only blocks a call there, nothing else yet.
  (Chunk 23E: it no longer blocks a call, D109; it stays a tap target for
  level rule 21.)
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
- **Known limit (fixed in chunk 16e, see "The test level"):** the slide
  ends across the start basin, where the outgoing route starts back the
  other way. Several slimes arriving at once
  can jam there, and two slimes shoved into each other by the carry can end
  up overlapping for good (the contact model can't separate two rings with
  the same centre). One slime per size passes on every seed tried; three at
  once jammed on 1 of 6 seeds. Chunk 9's crowd check (see "Sleepers,
  waking and the hint") still sees jams there: not settled.

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
