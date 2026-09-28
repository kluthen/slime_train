extends Node2D
## The game root (the main scene). It owns the simulation and drives it at a
## fixed step: every frame, FixedStep turns the frame time into whole ticks
## and each tick runs one Simulation.step(), so the game runs the same at any
## frame rate. Real touches go to the simulation as input events.
##
## Test mode (see TestModeGuard) is reached only through enable_test_mode()
## or the "--test-mode" command-line flag, and only in a debug build. This
## script names test-mode code by path only, never by class, so a release
## export can leave src/test_mode/ out.
##
## In a debug build it loads the test level (levels/test/), adds a Camera2D
## and hands the level's plain data to the simulation. The test level is named by path too: it never ships (D91).
## A release build has no level yet (the real first level comes later).
##
## The level's collision terrain is baked once into TerrainSegments and
## shared by every simulation started on it; a SlimeRenderer draws the
## current simulation's slimes and a TapFeedback their ripples and eyes.
## The camera is the simulation's (Camera: rails, edge buttons, call drag);
## sync_view() makes the simulation's view and the scene's Camera2D show it,
## before and after every tick. EdgeButtons draws the edge buttons on a HUD
## layer.
##
## Saves (chunk 8). In normal play the game starts from the level's save when
## there is one (SaveStore, user://saves/<level id>.json; SaveData has the
## format), else fresh with the first slime woken. It autosaves (Autosave)
## every 15 s of wall time, when the app goes to the background, and when it
## quits. A save it can't use (unreadable, another level version) is left
## untouched: the game starts fresh, says why, and writes nothing over it.
## Only the main scene gets the default store: a game a test adds gets the
## store the test gives it, or none, and then never writes. Test mode starts
## from its fixture or "load" save, and autosaves only when its run asks.
##
## A build exported with the "spike_soft_slimes" feature tag (the "Android
## spike: soft slimes" preset) runs spike 1's phone benchmark instead of the
## game, since the official Android templates ignore a scene given on the
## command line (see docs/dev/README.md "Android export (debug)"). The spike
## is named by path only, like the test level.
# @spec-link [[req_test_level_and_test_mode]]

const TEST_LEVEL_SCENE := "res://levels/test/level.tscn"
const TEST_MODE_SCRIPT := "res://src/test_mode/test_mode.gd"
const TEST_MODE_REFUSED := "Test mode is not available in this build (release builds never run it)."
## The most ticks one frame runs at normal speed (8 ticks: a 133 ms hitch).
## Beyond that the game slows down rather than catching up.
const MAX_TICKS_PER_FRAME := 8
## The export feature tag that swaps the game for spike 1's benchmark.
const SPIKE_SOFT_SLIMES_FEATURE := "spike_soft_slimes"
const SPIKE_SOFT_SLIMES_SCENE := "res://spikes/soft-slimes/spike.tscn"

var simulation: Simulation
## The loaded level, or null (a release build has none yet).
var level: Level = null
## Shows what the simulation's camera shows (sync_view()); it has no logic of
## its own. Null without a level.
var camera: Camera2D = null
## Draws the current simulation's slimes (DIRECT when headless).
var slime_renderer: SlimeRenderer = null
## Draws the tap ripples and the slimes' facing, above the slimes.
var tap_feedback: TapFeedback = null
## Draws the edge buttons, in screen pixels on the HUD layer.
var edge_buttons: EdgeButtons = null
## The running TestMode, or null. Loosely typed on purpose (see above).
var test_mode: RefCounted = null
## Replaced by tests to check the release path.
var test_mode_guard := TestModeGuard.for_this_build()
## Where the levels' saves go, or null: the game never saves. The main scene
## gets the default (user://saves/) in _ready; tests set their own first.
# @spec-link [[req_persistence_and_saves]]
var save_store: SaveStore = null
## When the game saves on its own. Enabled in normal play with a store, and
## in test mode only when the run asks.
# @spec-link [[req_persistence_and_saves]]
var autosave := Autosave.new()

var _clock := FixedStep.new()
## The level's collision terrain for the slimes, or null without a level.
var _terrain: TerrainSegments = null


func _ready() -> void:
	autosave.enabled = false
	if OS.has_feature(SPIKE_SOFT_SLIMES_FEATURE):
		set_process(false)
		set_process_unhandled_input(false)
		get_tree().change_scene_to_file.call_deferred(SPIKE_SOFT_SLIMES_SCENE)
		return
	print("Slime Train booted (Godot %s)." % Engine.get_version_info().string)
	if save_store == null and get_tree().current_scene == self:
		save_store = SaveStore.new()
	if test_mode_guard.allows():
		_load_level(TEST_LEVEL_SCENE)
	slime_renderer = SlimeRenderer.new()
	slime_renderer.name = "Slimes"
	slime_renderer.draw_mode = SlimeRenderer.default_mode()
	add_child(slime_renderer)
	tap_feedback = TapFeedback.new()
	tap_feedback.name = "TapFeedback"
	add_child(tap_feedback)
	var hud := CanvasLayer.new()
	hud.name = "Hud"
	add_child(hud)
	edge_buttons = EdgeButtons.new()
	edge_buttons.name = "EdgeButtons"
	hud.add_child(edge_buttons)
	_use_simulation(_new_simulation(Rng.random_seed()))
	var user_args := OS.get_cmdline_user_args()
	if TestModeGuard.requested(user_args):
		var errors := start_test_mode_from_args(user_args)
		for error in errors:
			printerr("Test mode: ", error)
		# A scripted run that can't start must not carry on as normal play,
		# but in a release build the flag is simply ignored.
		if not errors.is_empty() and test_mode_guard.allows():
			get_tree().quit(1)
			return
	if test_mode == null:
		_resume_play()


func _process(delta: float) -> void:
	var scale: float = test_mode.time_scale if test_mode != null else 1.0
	var max_ticks := MAX_TICKS_PER_FRAME * maxi(1, ceili(scale))
	for i in _clock.advance(delta * scale, max_ticks):
		step_simulation()
	if autosave.due(_now()):
		var error := save_now()
		if error != "":
			printerr("Autosave: ", error)


## Going to the background (Autosave.is_background) saves at once.
func _notification(what: int) -> void:
	if autosave.enabled and Autosave.is_background(what):
		var error := save_now()
		if error != "":
			printerr("Autosave: ", error)


## Quitting (or the game root leaving the tree) saves too.
func _exit_tree() -> void:
	if autosave.enabled:
		var error := save_now()
		if error != "":
			printerr("Autosave: ", error)
		autosave.enabled = false


func _unhandled_input(event: InputEvent) -> void:
	if test_mode != null and test_mode.block_real_input:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			simulation.push_input(Simulation.touch_down(event.index, event.position))
		else:
			simulation.push_input(Simulation.touch_up(event.index, event.position))
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		# On a phone, Godot also turns each touch into a mouse event; those
		# are already handled above.
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			return
		if event.pressed:
			simulation.push_input(Simulation.touch_down(0, event.position))
		else:
			simulation.push_input(Simulation.touch_up(0, event.position))


## Runs one simulation tick, first giving it the view and feeding it the
## input test mode scripted for that tick.
func step_simulation() -> void:
	sync_view()
	if test_mode != null:
		for event in test_mode.inputs_for_tick(simulation.tick):
			simulation.push_input(event)
	simulation.step()
	sync_view()


## Makes the simulation's view show what its camera shows (taps are
## dispatched through the view), and the scene's Camera2D show the view. The
## screen's size is test mode's "screen_size" in test mode (a headless window
## reports a wrong size), else the viewport's.
# @spec-link [[req_controls_tap_zones]]
# @spec-link [[req_camera_rails_and_framing]]
func sync_view() -> void:
	var size: Vector2 = test_mode.screen_size if test_mode != null else get_viewport_rect().size
	simulation.camera.apply_to(simulation.view, size)
	if camera != null:
		camera.position = simulation.view.centre
		camera.zoom = Vector2(simulation.view.zoom, simulation.view.zoom)


## Saves the running simulation to its level's file now. Returns "" or why
## nothing was written (no store, no level, or SaveStore refused: the old
## file is kept). Autosave calls it; test mode may too.
# @spec-link [[req_persistence_and_saves]]
func save_now() -> String:
	autosave.saved(_now())
	if save_store == null:
		return "this game has no save store"
	if level == null or simulation == null or simulation.level == null:
		return "no level to save"
	return save_store.write(simulation.to_save())


## Turns test mode on with a run configuration (see src/test_mode/test_mode.gd)
## and starts a simulation from its seed: fresh, or from the fixture's or the
## "load" file's save (a save's own seed wins), the camera where the fixture
## puts it. Returns the errors; empty means test mode is on. Refused in a
## release build.
func enable_test_mode(config: Dictionary) -> PackedStringArray:
	if not test_mode_guard.allows():
		return PackedStringArray([TEST_MODE_REFUSED])
	var candidate: RefCounted = load(TEST_MODE_SCRIPT).from_config(config)
	if not candidate.errors.is_empty():
		return candidate.errors
	if candidate.autosave and save_store == null:
		return PackedStringArray(["'autosave' needs a save store, and this game has none"])
	var fresh: Simulation
	if candidate.save_data.is_empty():
		fresh = _new_simulation(candidate.seed_value)
	else:
		var problems := SaveData.problems(candidate.save_data, level.data if level != null else null)
		if not problems.is_empty():
			return problems
		fresh = Simulation.from_save(candidate.save_data, level.data, _terrain, candidate.seed_value)
	if candidate.camera != null and level != null and level.data.loop != null:
		fresh.camera.start(level.data.loop, fresh.train.open_gates if fresh.train != null else [], candidate.camera)
	if test_mode != null:
		test_mode.detach()
	test_mode = candidate
	_use_simulation(fresh)
	_clock.reset()
	autosave.enabled = candidate.autosave
	autosave.start(_now())
	test_mode.attach(self)
	return PackedStringArray()


## Starts test mode from the command-line flags (see TestMode.config_from_args).
## With --run-ticks=N it runs N ticks at once, prints
## "STATE tick=<N> hash=<sha256>", saves to --save's file if given, and
## quits. Returns the errors.
func start_test_mode_from_args(user_args: PackedStringArray) -> PackedStringArray:
	if not test_mode_guard.allows():
		return PackedStringArray([TEST_MODE_REFUSED])
	var parsed: Dictionary = load(TEST_MODE_SCRIPT).config_from_args(user_args)
	if not parsed["errors"].is_empty():
		return parsed["errors"]
	var errors := enable_test_mode(parsed["config"])
	if not errors.is_empty():
		return errors
	if parsed["run_ticks"] >= 0:
		test_mode.run_ticks(parsed["run_ticks"])
		print("STATE tick=%d hash=%s" % [simulation.tick, simulation.state_hash()])
		if parsed["print_state"]:
			print("STATE_JSON ", StateHash.canonical_json(simulation.dump()))
		if parsed["save_path"] != "":
			var error := SaveStore.write_file(parsed["save_path"], simulation.to_save())
			if error != "":
				return PackedStringArray([error])
			print("SAVED ", parsed["save_path"])
		get_tree().quit()
	return PackedStringArray()


## Adds the level scene at `path` and the Camera2D that shows the
## simulation's camera.
# @spec-link [[req_loop_and_world]]
func _load_level(path: String) -> void:
	level = load(path).instantiate()
	add_child(level)
	_terrain = SlimeWorld.terrain_from(level)
	camera = Camera2D.new()
	camera.name = "Camera"
	add_child(camera)
	camera.make_current()


## Normal play: starts from the level's save if there is a usable one (else
## the fresh simulation stays), then turns autosave on. A save that can't be
## used is kept as it is and blocked from being written over.
# @spec-link [[req_persistence_and_saves]]
# @spec-link [[rule_saves_never_wiped]]
func _resume_play() -> void:
	if save_store == null or level == null:
		return
	var level_id := level.data.level_id
	var result := save_store.read(level_id)
	if result["status"] == SaveStore.UNREADABLE:
		printerr("Save: ", result["error"], " Starting fresh; it won't be written over.")
	elif result["status"] == SaveStore.OK:
		var problems := SaveData.problems(result["save"], level.data)
		if problems.is_empty():
			_use_simulation(Simulation.from_save(result["save"], level.data, _terrain, simulation.rng.seed_value))
		else:
			var reason := "; ".join(problems)
			save_store.block(level_id, reason)
			printerr("Save: %s can't be used (%s). Starting fresh; it won't be written over."
					% [save_store.path_for(level_id), reason])
	autosave.enabled = true
	autosave.start(_now())


## Wall-clock seconds, for autosave.
func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


## A fresh simulation from `seed_value`, holding the level's plain data and
## its collision terrain.
func _new_simulation(seed_value: int) -> Simulation:
	var fresh := Simulation.new(seed_value)
	fresh.slimes.terrain = _terrain
	if level != null:
		fresh.load_level(level.data)
	return fresh


## Makes `fresh` the running simulation, and the one drawn.
func _use_simulation(fresh: Simulation) -> void:
	simulation = fresh
	if slime_renderer != null:
		slime_renderer.bodies = fresh.slimes
	if tap_feedback != null:
		tap_feedback.simulation = fresh
	if edge_buttons != null:
		edge_buttons.simulation = fresh
	sync_view()
