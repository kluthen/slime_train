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
## In a debug build it loads the test level (levels/test/), puts a plain
## camera on the start basin and hands the level's plain data to the
## simulation. The test level is named by path too: it never ships (D91).
## A release build has no level yet (the real first level comes later).
##
## The level's collision terrain is baked once into TerrainSegments and
## shared by every simulation started on it; a SlimeRenderer draws the
## current simulation's slimes and a TapFeedback their ripples and eyes.
## Before every tick, sync_view() copies what the camera shows into the
## simulation's view, through which the simulation dispatches taps.
##
## A build exported with the "spike_soft_slimes" feature tag (the "Android
## spike: soft slimes" preset) runs spike 1's phone benchmark instead of the
## game, since the official Android templates ignore a scene given on the
## command line (see docs/dev/README.md "Android export (debug)"). The spike
## is named by path only, like the test level.
# @spec-link [[req_test_level_and_test_mode]]

const TEST_LEVEL_SCENE := "res://levels/test/level.tscn"
## Where the camera sits relative to the first slime: a little above it, so
## the basin's floor and the first sleeper's ledge are both in view.
const CAMERA_OFFSET := Vector2(0, -120)
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
## A plain camera on the start basin. The camera rails come with chunk 13.
var camera: Camera2D = null
## Draws the current simulation's slimes (DIRECT when headless).
var slime_renderer: SlimeRenderer = null
## Draws the tap ripples and the slimes' facing, above the slimes.
var tap_feedback: TapFeedback = null
## The running TestMode, or null. Loosely typed on purpose (see above).
var test_mode: RefCounted = null
## Replaced by tests to check the release path.
var test_mode_guard := TestModeGuard.for_this_build()

var _clock := FixedStep.new()
## The level's collision terrain for the slimes, or null without a level.
var _terrain: TerrainSegments = null


func _ready() -> void:
	if OS.has_feature(SPIKE_SOFT_SLIMES_FEATURE):
		set_process(false)
		set_process_unhandled_input(false)
		get_tree().change_scene_to_file.call_deferred(SPIKE_SOFT_SLIMES_SCENE)
		return
	print("Slime Train booted (Godot %s)." % Engine.get_version_info().string)
	if test_mode_guard.allows():
		_load_level(TEST_LEVEL_SCENE)
	slime_renderer = SlimeRenderer.new()
	slime_renderer.name = "Slimes"
	slime_renderer.draw_mode = SlimeRenderer.default_mode()
	add_child(slime_renderer)
	tap_feedback = TapFeedback.new()
	tap_feedback.name = "TapFeedback"
	add_child(tap_feedback)
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


func _process(delta: float) -> void:
	var scale: float = test_mode.time_scale if test_mode != null else 1.0
	var max_ticks := MAX_TICKS_PER_FRAME * maxi(1, ceili(scale))
	for i in _clock.advance(delta * scale, max_ticks):
		step_simulation()


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


## Copies what the camera shows into the simulation's view (taps are
## dispatched through it). The screen's size is test mode's "screen_size" in
## test mode (a headless window reports a wrong size), else the viewport's.
# @spec-link [[req_controls_tap_zones]]
func sync_view() -> void:
	var size: Vector2 = test_mode.screen_size if test_mode != null else get_viewport_rect().size
	if camera == null:
		simulation.view.set_to(size * 0.5, 1.0, size)
		return
	simulation.view.set_to(camera_centre(size), camera.zoom.x, size)


## The level point at the middle of a `size` screen: the camera's position
## held inside its limits as Camera2D does it (left, then right; bottom, then
## top), plus its offset.
func camera_centre(size: Vector2) -> Vector2:
	var span := size / camera.zoom
	var corner := camera.position - span * 0.5
	if camera.limit_enabled:
		if corner.x < camera.limit_left:
			corner.x = camera.limit_left
		if corner.x + span.x > camera.limit_right:
			corner.x = camera.limit_right - span.x
		if corner.y + span.y > camera.limit_bottom:
			corner.y = camera.limit_bottom - span.y
		if corner.y < camera.limit_top:
			corner.y = camera.limit_top
	return corner + span * 0.5 + camera.offset


## Turns test mode on with a run configuration (see src/test_mode/test_mode.gd)
## and starts a fresh simulation from its seed. Returns the errors; empty
## means test mode is on. Refused in a release build.
func enable_test_mode(config: Dictionary) -> PackedStringArray:
	if not test_mode_guard.allows():
		return PackedStringArray([TEST_MODE_REFUSED])
	var candidate: RefCounted = load(TEST_MODE_SCRIPT).from_config(config)
	if not candidate.errors.is_empty():
		return candidate.errors
	if test_mode != null:
		test_mode.detach()
	test_mode = candidate
	_use_simulation(_new_simulation(candidate.seed_value))
	_clock.reset()
	test_mode.attach(self)
	return PackedStringArray()


## Starts test mode from the command-line flags (see TestMode.config_from_args).
## With --run-ticks=N it runs N ticks at once, prints
## "STATE tick=<N> hash=<sha256>" and quits. Returns the errors.
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
		get_tree().quit()
	return PackedStringArray()


## Adds the level scene at `path` and a camera on its start basin.
# @spec-link [[req_loop_and_world]]
func _load_level(path: String) -> void:
	level = load(path).instantiate()
	add_child(level)
	_terrain = SlimeWorld.terrain_from(level)
	camera = Camera2D.new()
	camera.name = "Camera"
	camera.position = level.start_position() + CAMERA_OFFSET
	camera.limit_left = 0
	add_child(camera)
	camera.make_current()


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
