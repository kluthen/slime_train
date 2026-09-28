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

const TEST_MODE_SCRIPT := "res://src/test_mode/test_mode.gd"
const TEST_MODE_REFUSED := "Test mode is not available in this build (release builds never run it)."
## The most ticks one frame runs at normal speed (8 ticks: a 133 ms hitch).
## Beyond that the game slows down rather than catching up.
const MAX_TICKS_PER_FRAME := 8

var simulation: Simulation
## The running TestMode, or null. Loosely typed on purpose (see above).
var test_mode: RefCounted = null
## Replaced by tests to check the release path.
var test_mode_guard := TestModeGuard.for_this_build()

var _clock := FixedStep.new()


func _ready() -> void:
	print("Slime Train booted (Godot %s)." % Engine.get_version_info().string)
	simulation = Simulation.new(Rng.random_seed())
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


## Runs one simulation tick, first feeding it the input test mode scripted for
## that tick.
func step_simulation() -> void:
	if test_mode != null:
		for event in test_mode.inputs_for_tick(simulation.tick):
			simulation.push_input(event)
	simulation.step()


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
	simulation = Simulation.new(candidate.seed_value)
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
