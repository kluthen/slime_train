class_name TestMode
extends RefCounted
## Test mode: runs the game from a script for end-to-end tests. It sets the
## seed, scales or skips simulated time, feeds scripted input (taps, touches,
## tilt) to the simulation on the right ticks, and starts from a named
## fixture or a save file.
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
##     "fixture": "bump",          # optional: a test level fixture (below)
##     "load": "user://x.json",    # optional: a save file to start from
##     "autosave": false,          # optional: autosave while testing (off)
##     "block_real_input": true,   # optional; ignore the real mouse and touch
##     "screen_size": [1152, 648], # optional: the screen the taps are on
##     "steps": [ ... ],           # optional: the input script (TestModeScript)
##   }
##
## "screen_size" is the one place a run sets the screen's size, in viewport
## pixels (the project's 1152 x 648 by default): the game hands it to the
## simulation's view instead of the window's size, which headless runs report
## wrong.
##
## "fixture" and "load" start the run from a save (SaveData's format) instead
## of a fresh level; not both. The game checks the save against the level
## (SaveData.problems). A hand-made save without a seed plays on the run's.
##
## Fixtures (levels/test/fixtures/). A fixture is a sidecar,
## <name>.fixture.json, and, when it has one, a save, <name>.json:
##
##   {"description": "...", "save": true, "camera": [x, y]}
##
## "save" false: the level starts fresh (the "fresh" fixture). "camera", when
## given, is a level point: the camera starts on its rails nearest it.
## tools/make_fixture.gd writes the fixtures (docs/dev/README.md, "Saves and
## fixtures").
##
## Autosave is off in test mode, so a run never writes the player's saves;
## "autosave": true turns it on, and the game's save_now() saves on demand.

const FIXTURES_DIR := "res://levels/test/fixtures/"
## A fixture's save.
const FIXTURE_EXTENSION := ".json"
## A fixture's sidecar: what it is, whether it has a save, the camera.
const SIDECAR_EXTENSION := ".fixture.json"
const MAX_TIME_SCALE := 64.0
const CONFIG_KEYS := ["seed", "time_scale", "fixture", "load", "autosave", "block_real_input", "screen_size",
		"steps"]
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
## The save to start from (a fixture's or the "load" file's), or {} for a
## fresh level.
var save_data := {}
## Where the fixture puts the camera (a level point), or null.
var camera: Variant = null
## Whether the game autosaves in this run (off unless the run asks).
var autosave := false
## The screen the taps are on, viewport pixels (see the class doc).
var screen_size := ScreenView.DEFAULT_SIZE
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
	var size: Variant = _screen_size(config.get("screen_size", ScreenView.DEFAULT_SIZE))
	if size == null:
		tm.errors.append("'screen_size' must be [width, height], two numbers above 0")
	else:
		tm.screen_size = size
	var steps: Variant = config.get("steps", [])
	if typeof(steps) != TYPE_ARRAY:
		tm.errors.append("'steps' must be an array of steps")
	else:
		tm.input_script = TestModeScript.parse(steps)
		tm.errors.append_array(tm.input_script.errors)
	var autosave: Variant = config.get("autosave", false)
	if typeof(autosave) != TYPE_BOOL:
		tm.errors.append("'autosave' must be true or false")
	else:
		tm.autosave = autosave
	tm.fixture_name = str(config.get("fixture", ""))
	var load_path := str(config.get("load", ""))
	if not tm.fixture_name.is_empty() and not load_path.is_empty():
		tm.errors.append("'fixture' and 'load' both start from a save: give one, not both")
	elif not tm.fixture_name.is_empty():
		var fixture := load_fixture(tm.fixture_name)
		if not fixture["ok"]:
			var where := " (%s)" % fixture["path"] if not fixture["path"].is_empty() else ""
			tm.errors.append("fixture '%s'%s: %s" % [tm.fixture_name, where, fixture["error"]])
		else:
			tm.save_data = fixture["save"]
			tm.camera = fixture["camera"]
	elif not load_path.is_empty():
		var loaded := SaveStore.read_file(load_path)
		if loaded["status"] == SaveStore.OK:
			tm.save_data = loaded["save"]
		elif loaded["status"] == SaveStore.FRESH:
			tm.errors.append("'load': no save at %s" % load_path)
		else:
			tm.errors.append("'load': %s" % loaded["error"])
	return tm


## `value` as a screen size ([w, h] or a Vector2, both above 0), or null.
static func _screen_size(value: Variant) -> Variant:
	if typeof(value) == TYPE_VECTOR2 or typeof(value) == TYPE_VECTOR2I:
		value = [value.x, value.y]
	if typeof(value) != TYPE_ARRAY or value.size() != 2:
		return null
	for n in value:
		if typeof(n) not in [TYPE_INT, TYPE_FLOAT] or n <= 0:
			return null
	return Vector2(value[0], value[1])


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


## Where the fixture `name`'s save lives, under the test level.
static func fixture_path(name: String) -> String:
	return FIXTURES_DIR + name + FIXTURE_EXTENSION


## Where the fixture `name`'s sidecar lives.
static func sidecar_path(name: String) -> String:
	return FIXTURES_DIR + name + SIDECAR_EXTENSION


## Loads the fixture `name` (see the class doc). Returns {"ok", "path" (its
## save's), "error", "save" ({} for none: a fresh level), "camera" (a
## Vector2 or null), "description"}.
static func load_fixture(name: String) -> Dictionary:
	var result := {"ok": false, "path": "", "error": "", "save": {}, "camera": null, "description": ""}
	if RegEx.create_from_string("^[a-z0-9]+(-[a-z0-9]+)*$").search(name) == null:
		result["error"] = "invalid fixture name '%s' (expected lowercase letters, digits and hyphens)" % name
		return result
	result["path"] = fixture_path(name)
	var sidecar_file := sidecar_path(name)
	if not FileAccess.file_exists(sidecar_file):
		result["error"] = "no such fixture: %s is missing" % sidecar_file
		return result
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(sidecar_file)) != OK or typeof(json.data) != TYPE_DICTIONARY:
		result["error"] = "%s is not a JSON object" % sidecar_file
		return result
	var sidecar: Dictionary = json.data
	result["description"] = str(sidecar.get("description", ""))
	if sidecar.has("camera"):
		var at: Variant = sidecar["camera"]
		if typeof(at) != TYPE_ARRAY or at.size() != 2 or typeof(at[0]) not in [TYPE_INT, TYPE_FLOAT] \
				or typeof(at[1]) not in [TYPE_INT, TYPE_FLOAT]:
			result["error"] = "%s: 'camera' must be [x, y]" % sidecar_file
			return result
		result["camera"] = Vector2(at[0], at[1])
	if sidecar.get("save", true):
		var loaded := SaveStore.read_file(result["path"])
		if loaded["status"] != SaveStore.OK:
			result["error"] = loaded["error"] if loaded["error"] != "" else "its save %s is missing" % result["path"]
			return result
		result["save"] = loaded["save"]
	result["ok"] = true
	return result


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
##   --load=PATH              start from the save at PATH
##   --run-ticks=N            run N ticks at once, print the state hash, quit
##   --print-state            with --run-ticks, also print the state as JSON
##   --save=PATH              with --run-ticks, then save to PATH
## Returns {"config", "run_ticks" (-1 when absent), "print_state",
## "save_path" ("" when absent), "errors"}.
static func config_from_args(user_args: PackedStringArray) -> Dictionary:
	var result := {"config": {}, "run_ticks": -1, "print_state": false, "save_path": "",
			"errors": PackedStringArray()}
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
			"--load":
				overrides["load"] = value
			"--save":
				if value.is_empty():
					errors.append("--save expects a file path")
				else:
					result["save_path"] = value
			_:
				errors.append("unknown test mode flag '%s'" % arg)
	result["config"].merge(overrides, true)
	if result["save_path"] != "" and result["run_ticks"] < 0:
		errors.append("--save saves after --run-ticks=N: give both")
	return result
