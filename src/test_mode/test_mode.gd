class_name TestMode
extends RefCounted
## Test mode: runs the game from a script for end-to-end tests. It sets the
## seed, scales or skips simulated time, feeds scripted input (taps, touches,
## tilt) to the simulation on the right ticks, and loads a named fixture (a
## stub until chunk 8).
##
## Only the game root (src/main.gd) creates one, through
## enable_test_mode(config), and only when TestModeGuard allows it: never in
## a release build.
##
## A run is configured with one dictionary, from GDScript or a JSON file:
##
##   {
##     "seed": 20260928,           # required: the master seed
##     "time_scale": 1.0,          # optional, 0 to 64; 0 holds the frame clock
##     "fixture": "fresh",         # optional; stub until chunk 8
##     "block_real_input": true,   # optional; ignore the real mouse and touch
##     "steps": [ ... ],           # optional: the input script (TestModeScript)
##   }

const FIXTURES_DIR := "res://levels/test/fixtures/"
## Provisional: chunk 8 settles the save format, and with it this extension.
const FIXTURE_EXTENSION := ".json"
const MAX_TIME_SCALE := 64.0
const CONFIG_KEYS := ["seed", "time_scale", "fixture", "block_real_input", "steps"]
const OVERLAY_SCRIPT := preload("res://src/test_mode/test_mode_overlay.gd")

## What is wrong with the configuration. Empty when it is valid.
var errors := PackedStringArray()
var seed_value := 0
## Simulated seconds per real second for the frame clock. 0 holds it, so that
## only run_ticks()/run_until() advance the simulation.
var time_scale := 1.0
## When true (the default), real mouse and touch input is ignored, so a stray
## click can't change a scripted run.
var block_real_input := true
var fixture_name := ""
var input_script: TestModeScript = TestModeScript.parse([])
## The game root this test mode drives, once attached.
var game: Node = null
## The on-screen banner and finger markers, once attached.
var overlay: TestModeOverlay = null

var _layer: CanvasLayer = null


## A test mode configured from `config`. Check `errors` before using it.
static func from_config(config: Dictionary) -> TestMode:
	var tm := TestMode.new()
	for key in config:
		if key not in CONFIG_KEYS:
			tm.errors.append("unknown setting '%s' (expected one of %s)" % [key, ", ".join(CONFIG_KEYS)])
	var seed_number: Variant = TestModeScript._whole_number(config.get("seed"))
	if seed_number == null:
		tm.errors.append("'seed' is required and must be a whole number")
	else:
		tm.seed_value = seed_number
	var scale: Variant = config.get("time_scale", 1.0)
	if typeof(scale) not in [TYPE_INT, TYPE_FLOAT] or scale < 0.0 or scale > MAX_TIME_SCALE:
		tm.errors.append("'time_scale' must be a number from 0 to %d" % MAX_TIME_SCALE)
	else:
		tm.time_scale = float(scale)
	var block: Variant = config.get("block_real_input", true)
	if typeof(block) != TYPE_BOOL:
		tm.errors.append("'block_real_input' must be true or false")
	else:
		tm.block_real_input = block
	var steps: Variant = config.get("steps", [])
	if typeof(steps) != TYPE_ARRAY:
		tm.errors.append("'steps' must be an array of steps")
	else:
		tm.input_script = TestModeScript.parse(steps)
		tm.errors.append_array(tm.input_script.errors)
	tm.fixture_name = str(config.get("fixture", ""))
	if not tm.fixture_name.is_empty():
		var fixture := load_fixture(tm.fixture_name)
		if not fixture["ok"]:
			var where := " (%s)" % fixture["path"] if not fixture["path"].is_empty() else ""
			tm.errors.append("fixture '%s'%s: %s" % [tm.fixture_name, where, fixture["error"]])
	return tm


## The simulation input events scripted for `tick`.
func inputs_for_tick(tick: int) -> Array:
	return input_script.events_at(tick)


## Runs `ticks` simulation ticks at once, without waiting for frames (skipping
## simulated time). Scripted input on those ticks is fed as usual.
func run_ticks(ticks: int) -> void:
	for i in ticks:
		game.step_simulation()


## Runs ticks at once until the simulation reaches `tick`.
func run_until(tick: int) -> void:
	while game.simulation.tick < tick:
		game.step_simulation()


## Hooks into the game root: adds the overlay on its own canvas layer.
func attach(game_root: Node) -> void:
	game = game_root
	_layer = CanvasLayer.new()
	_layer.name = "TestModeLayer"
	_layer.layer = 128
	overlay = OVERLAY_SCRIPT.new()
	overlay.name = "TestModeOverlay"
	overlay.test_mode = self
	_layer.add_child(overlay)
	game_root.add_child(_layer)


## Removes the overlay (when test mode is replaced).
func detach() -> void:
	if _layer != null:
		_layer.queue_free()
	_layer = null
	overlay = null
	game = null


## Where the fixture `name` lives: a save file under the test level.
static func fixture_path(name: String) -> String:
	return FIXTURES_DIR + name + FIXTURE_EXTENSION


## Loads the fixture `name`. Returns {"ok", "path", "error"}. A stub until
## chunk 8 (fixtures are saves): it checks the name, resolves the path and
## reports that loading isn't implemented.
static func load_fixture(name: String) -> Dictionary:
	if RegEx.create_from_string("^[a-z0-9]+(-[a-z0-9]+)*$").search(name) == null:
		return {"ok": false, "path": "", "error":
				"invalid fixture name '%s' (expected lowercase letters, digits and hyphens)" % name}
	return {"ok": false, "path": fixture_path(name), "error":
			"loading fixtures is not implemented until chunk 8 (save format and fixtures)"}


## Reads a run configuration from a JSON file: either the full dictionary or
## just the array of steps. Returns {"config", "errors"}.
static func load_config_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"config": {}, "errors": PackedStringArray(["cannot read the test script '%s'" % path])}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return {"config": {}, "errors": PackedStringArray([
				"%s:%d: %s" % [path, json.get_error_line(), json.get_error_message()]])}
	var data: Variant = json.data
	if typeof(data) == TYPE_ARRAY:
		return {"config": {"steps": data}, "errors": PackedStringArray()}
	if typeof(data) == TYPE_DICTIONARY:
		return {"config": data, "errors": PackedStringArray()}
	return {"config": {}, "errors": PackedStringArray(["%s: expected a dictionary or an array of steps" % path])}


## Reads test mode's command-line flags (the user arguments, after "--"):
##   --test-mode              ask for test mode (see TestModeGuard)
##   --test-script=PATH       a JSON run configuration (see above)
##   --seed=N                 the seed (overrides the file's)
##   --time-scale=X           the time scale (overrides the file's)
##   --fixture=NAME           a fixture (overrides the file's)
##   --run-ticks=N            run N ticks at once, print the state hash, quit
##   --print-state            with --run-ticks, also print the state as JSON
## Returns {"config", "run_ticks" (-1 when absent), "print_state", "errors"}.
static func config_from_args(user_args: PackedStringArray) -> Dictionary:
	var result := {"config": {}, "run_ticks": -1, "print_state": false, "errors": PackedStringArray()}
	var overrides := {}
	var errors: PackedStringArray = result["errors"]
	for arg in user_args:
		var flag := arg.get_slice("=", 0)
		var value := arg.substr(flag.length() + 1) if "=" in arg else ""
		match flag:
			"--test-mode":
				pass
			"--test-script":
				var loaded := load_config_file(value)
				errors.append_array(loaded["errors"])
				result["config"].merge(loaded["config"], true)
			"--seed":
				if value.is_valid_int():
					overrides["seed"] = value.to_int()
				else:
					errors.append("--seed expects a whole number, got '%s'" % value)
			"--time-scale":
				if value.is_valid_float():
					overrides["time_scale"] = value.to_float()
				else:
					errors.append("--time-scale expects a number, got '%s'" % value)
			"--fixture":
				overrides["fixture"] = value
			"--run-ticks":
				if value.is_valid_int() and value.to_int() >= 0:
					result["run_ticks"] = value.to_int()
				else:
					errors.append("--run-ticks expects a whole number >= 0, got '%s'" % value)
			"--print-state":
				result["print_state"] = true
			_:
				errors.append("unknown test mode flag '%s'" % arg)
	result["config"].merge(overrides, true)
	return result
