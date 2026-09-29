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
##     "level": "test",            # optional: the level, by ID (below)
##     "fixture": "bump",          # optional: a fixture of the level (below)
##     "load": "user://x.json",    # optional: a save file to start from
##     "at": "s1.gate",            # optional: where the camera starts (below)
##     "autosave": false,          # optional: autosave while testing (off)
##     "block_real_input": true,   # optional; ignore the real mouse and touch
##     "screen_size": [1152, 648], # optional: the screen the taps are on
##     "steps": [ ... ],           # optional: the input script (TestModeScript)
##     "sessions": false,          # optional: sessions on, as in normal play
##     "clock": {"away": 0, "restarted": false},  # optional: see below
##   }
##
## Sessions (Session, chunk 17). A run plays untimed, as in an endless
## session, unless "sessions" is true: then it opens in screensaver mode like
## normal play, and a tap that reaches the world starts a session. A save
## with a session or bedtime running counts down either way. The session's
## clocks are test mode's (TestClock), never the real ones: they run with
## the ticks, from the save's last reading when it has one. Skipping time:
## a "skip" step (TestModeScript) lets real time pass before a tick, and
## "clock" says what happened before the run starts: "away" seconds passed,
## and "restarted" (the app was killed or the phone restarted: a new
## monotonic epoch).
##
## "screen_size" is the one place a run sets the screen's size, in viewport
## pixels (the project's 1152 x 648 by default): the game hands it to the
## simulation's view instead of the window's size, which headless runs report
## wrong.
##
## "level" is the level the run plays, by ID (LevelCatalog: the scene
## res://levels/<id>/level.tscn), the test level by default. An unknown ID is
## an error naming the missing scene and listing the levels. Choosing a level
## is for tests and tools only: the player never chooses one (v1 ships one).
##
## "fixture" and "load" start the run from a save (SaveData's format) instead
## of a fresh level; not both. The game checks the save against the level
## (SaveData.problems). A hand-made save without a seed plays on the run's.
##
## Fixtures (levels/<level>/fixtures/, the run's level's). A fixture is a
## sidecar, <name>.fixture.json, and, when it has one, a save, <name>.json:
##
##   {"description": "...", "save": true, "camera": [x, y]}
##
## "save" false: the level starts fresh (the "fresh" fixture). "camera", when
## given, is a level point [x, y] or a stable ID of the level (like
## "s2.switch", chunk LD3): the camera starts on its rails nearest it. As
## with "at", the game finds the stable ID in the level.
##
## "at" starts the camera somewhere else, and wins over the fixture's
## "camera": a stable ID of the level (the camera starts on its rails nearest
## that thing) or [x, y] (a level point, as "camera"). Test mode can't see the
## level, so it keeps "at" as given and the game finds the stable ID (an ID
## that isn't in the level is an error there).
## tools/make_fixture.gd writes the fixtures (docs/dev/README.md, "Saves and
## fixtures").
##
## Autosave is off in test mode, so a run never writes the player's saves;
## "autosave": true turns it on, and the game's save_now() saves on demand.

## A fixture's save.
const FIXTURE_EXTENSION := ".json"
## A fixture's sidecar: what it is, whether it has a save, the camera.
const SIDECAR_EXTENSION := ".fixture.json"
const MAX_TIME_SCALE := 64.0
const CONFIG_KEYS := ["seed", "time_scale", "level", "fixture", "load", "at", "autosave", "block_real_input",
		"screen_size", "steps", "sessions", "clock"]
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
## The level the run plays, by ID (see the class doc).
# @spec-link [[req_test_level_and_test_mode]]
var level_id := LevelCatalog.DEFAULT_ID
var fixture_name := ""
## The save to start from (a fixture's or the "load" file's), or {} for a
## fresh level.
var save_data := {}
## Where the fixture puts the camera (a level point, or a stable ID for the
## game to find), or null.
var camera: Variant = null
## Where the run puts the camera, over the fixture's: a stable ID of the
## level (a String, for the game to find), a level point (a Vector2), or null.
# @spec-link [[req_test_level_and_test_mode]]
var at: Variant = null
## Whether the game autosaves in this run (off unless the run asks).
var autosave := false
## The screen the taps are on, viewport pixels (see the class doc).
var screen_size := ScreenView.DEFAULT_SIZE
var input_script: TestModeScript = TestModeScript.parse([])
## Whether the run has sessions (see the class doc).
# @spec-link [[req_session_lifecycle]]
var sessions := false
## The session's clocks in this run (see the class doc).
var clock := TestClock.new()
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
	var level_ok := tm._read_level(config.get("level", LevelCatalog.DEFAULT_ID))
	tm._read_at(config.get("at"))
	tm.fixture_name = str(config.get("fixture", ""))
	var load_path := str(config.get("load", ""))
	if not tm.fixture_name.is_empty() and not load_path.is_empty():
		tm.errors.append("'fixture' and 'load' both start from a save: give one, not both")
	elif not tm.fixture_name.is_empty():
		# An unknown level has no fixtures: its own error says so.
		if level_ok:
			tm._read_fixture()
	elif not load_path.is_empty():
		var loaded := SaveStore.read_file(load_path)
		if loaded["status"] == SaveStore.OK:
			tm.save_data = loaded["save"]
		elif loaded["status"] == SaveStore.FRESH:
			tm.errors.append("'load': no save at %s" % load_path)
		else:
			tm.errors.append("'load': %s" % loaded["error"])
	var sessions: Variant = config.get("sessions", false)
	if typeof(sessions) != TYPE_BOOL:
		tm.errors.append("'sessions' must be true or false")
	else:
		tm.sessions = sessions
	var setting: Variant = config.get("clock", {})
	if not _clock_setting_ok(setting):
		tm.errors.append("'clock' must be {\"away\": seconds >= 0, \"restarted\": true or false}")
	else:
		var saved_sim: Variant = tm.save_data.get("sim", {})
		var start: Variant = TestModeScript._whole_number(saved_sim.get("tick", 0)) if saved_sim is Dictionary else 0
		tm.clock = TestClock.for_run(tm.save_data.get("session"), start if start != null else 0, setting,
				tm.input_script.skips)
	return tm


## Takes the run's "level" (see the class doc). Returns whether it is a
## level that exists.
# @spec-link [[req_test_level_and_test_mode]]
func _read_level(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING:
		errors.append("'level' must be a level ID (a string, like \"%s\")" % LevelCatalog.DEFAULT_ID)
		return false
	var problem := LevelCatalog.problem(value)
	if problem != "":
		errors.append("'level': %s" % problem)
		return false
	level_id = value
	return true


## Takes the run's "at" (see the class doc): a stable ID, or [x, y] (or a
## Vector2).
# @spec-link [[req_test_level_and_test_mode]]
func _read_at(value: Variant) -> void:
	if value == null:
		return
	if typeof(value) == TYPE_STRING and StableId.is_valid(value):
		at = value
		return
	if typeof(value) in [TYPE_VECTOR2, TYPE_VECTOR2I]:
		at = Vector2(value)
		return
	if typeof(value) == TYPE_ARRAY and value.size() == 2 and typeof(value[0]) in [TYPE_INT, TYPE_FLOAT] \
			and typeof(value[1]) in [TYPE_INT, TYPE_FLOAT]:
		at = Vector2(value[0], value[1])
		return
	errors.append("'at' must be a stable ID of the level (like \"s1.gate\") or [x, y] in level pixels, got %s"
			% JSON.stringify(value))


## Loads the run's fixture from its level's fixtures (see the class doc).
# @spec-link [[req_test_level_and_test_mode]]
func _read_fixture() -> void:
	var fixture := load_fixture(fixture_name, level_id)
	if not fixture["ok"]:
		var of_level := " of level '%s'" % level_id if level_id != LevelCatalog.DEFAULT_ID else ""
		var where := " (%s)" % fixture["path"] if not fixture["path"].is_empty() else ""
		errors.append("fixture '%s'%s%s: %s" % [fixture_name, of_level, where, fixture["error"]])
		return
	save_data = fixture["save"]
	camera = fixture["camera"]


static func _clock_setting_ok(setting: Variant) -> bool:
	if typeof(setting) != TYPE_DICTIONARY:
		return false
	for key in setting:
		if key not in ["away", "restarted"]:
			return false
	var away: Variant = setting.get("away", 0)
	return typeof(away) in [TYPE_INT, TYPE_FLOAT] and away >= 0 and typeof(setting.get("restarted", false)) == TYPE_BOOL


## The session's clocks before `tick`'s step (TestClock).
func clock_at(tick: int) -> Dictionary:
	return clock.reading_at(tick)


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


## Where the fixture `name`'s save lives, under level `level_id` (the test
## level by default).
# @spec-link [[req_test_level_and_test_mode]]
static func fixture_path(name: String, level_id := LevelCatalog.DEFAULT_ID) -> String:
	return LevelCatalog.fixtures_dir(level_id) + name + FIXTURE_EXTENSION


## Where the fixture `name`'s sidecar lives, under level `level_id`.
static func sidecar_path(name: String, level_id := LevelCatalog.DEFAULT_ID) -> String:
	return LevelCatalog.fixtures_dir(level_id) + name + SIDECAR_EXTENSION


## Loads the fixture `name` of level `level_id` (the test level by default;
## see the class doc). Returns {"ok", "path" (its save's), "error", "save"
## ({} for none: a fresh level), "camera" (a Vector2, a stable ID or null),
## "description"}.
# @spec-link [[req_test_level_and_test_mode]]
static func load_fixture(name: String, level_id := LevelCatalog.DEFAULT_ID) -> Dictionary:
	var result := {"ok": false, "path": "", "error": "", "save": {}, "camera": null, "description": ""}
	if RegEx.create_from_string("^[a-z0-9]+(-[a-z0-9]+)*$").search(name) == null:
		result["error"] = "invalid fixture name '%s' (expected lowercase letters, digits and hyphens)" % name
		return result
	var level_problem := LevelCatalog.problem(level_id)
	if level_problem != "":
		result["error"] = level_problem
		return result
	result["path"] = fixture_path(name, level_id)
	var sidecar_file := sidecar_path(name, level_id)
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
		if typeof(at) == TYPE_STRING and StableId.is_valid(at):
			result["camera"] = at
		elif typeof(at) == TYPE_ARRAY and at.size() == 2 and typeof(at[0]) in [TYPE_INT, TYPE_FLOAT] \
				and typeof(at[1]) in [TYPE_INT, TYPE_FLOAT]:
			result["camera"] = Vector2(at[0], at[1])
		else:
			result["error"] = "%s: 'camera' must be [x, y] or a stable ID of the level (like \"s1.gate\"), got %s" \
					% [sidecar_file, JSON.stringify(at)]
			return result
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
##   --level=ID               the level (overrides the file's)
##   --fixture=NAME           a fixture of the level (overrides the file's)
##   --load=PATH              start from the save at PATH
##   --at=ID or --at=X,Y      where the camera starts: a stable ID of the
##                            level, or a level point (overrides the file's)
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
			"--level":
				if value.is_empty():
					errors.append("--level expects a level ID")
				else:
					overrides["level"] = value
			"--at":
				var where: Variant = _at_from_arg(value)
				if where == null:
					errors.append("--at expects a stable ID or x,y (level pixels), got '%s'" % value)
				else:
					overrides["at"] = where
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


## --at's value as the run's "at": "x,y" -> [x, y] (two numbers), else the
## stable ID as given (from_config checks it). Null when empty or not two
## numbers around a comma.
# @spec-link [[req_test_level_and_test_mode]]
static func _at_from_arg(value: String) -> Variant:
	if value.is_empty():
		return null
	if "," not in value:
		return value
	var parts := value.split(",")
	if parts.size() != 2 or not parts[0].strip_edges().is_valid_float() or not parts[1].strip_edges().is_valid_float():
		return null
	return [parts[0].strip_edges().to_float(), parts[1].strip_edges().to_float()]
