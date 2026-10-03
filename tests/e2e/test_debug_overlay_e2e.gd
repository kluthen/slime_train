extends GutTest
## The debug overlay (src/debug/) through the real game scene: each speed
## runs the very same ticks as 1x; Reset, clicked twice within 2 s, starts
## the level over and replaces its save; the armed kill tool takes the next
## tap (and its release) from the simulation and sends the slime under it to
## the start of the loop; a touch on a control never reaches the simulation
## while one elsewhere does; a release build gets no overlay, and a game a
## test adds gets one only when the test asks.
##
## Every game here that saves gets its own SaveStore on a scratch directory.

const MAIN_SCENE := "res://src/main.tscn"
const DIR := "user://test-debug-overlay/"
const LEVEL := "test"
const SEED := 20260928


## Stands in for SessionClock in normal play.
class FakeClock:
	extends RefCounted
	var reading := {}

	func now() -> Dictionary:
		return reading


func before_each() -> void:
	_clear(DIR)


func after_all() -> void:
	_clear(DIR)


func _clear(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)


## A game with the overlay, in normal play (with `store`) or, given a config,
## in test mode. `shipped`: whether it plays as an app that has shipped
## (SaveData.SHIPPED, D149).
func _game(store: SaveStore = null, config := {}, shipped := SaveData.SHIPPED) -> Node:
	var game: Node = load(MAIN_SCENE).instantiate()
	game.save_store = store
	game.save_shipped = shipped
	add_child_autofree(game)
	game.add_debug_overlay()
	if not config.is_empty():
		var run := {"seed": SEED, "time_scale": 0}
		run.merge(config, true)
		assert_eq(game.enable_test_mode(run), PackedStringArray())
	return game


func _id_of(sim: Simulation, stable_id: String) -> int:
	for slime_id in sim.slimes.ids():
		if sim.identities.stable_id_of(slime_id) == stable_id:
			return slime_id
	return -1


func _click(game: Node, at: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = at
	game._unhandled_input(event)


func _touch(game: Node, at: Vector2, pressed: bool, index := 0) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.pressed = pressed
	event.position = at
	game._unhandled_input(event)


# --- Speed ------------------------------------------------------------------------

func test_every_speed_runs_the_same_ticks_as_1x() -> void:
	var reference := _game(null, {"time_scale": 1})
	reference.set_process(false)
	for frame in 120:
		reference._process(Simulation.TICK_SECONDS)
	assert_eq(reference.simulation.tick, 120)
	var expected: String = reference.simulation.state_hash()
	for speed in [2, 5, 10]:
		var game := _game(null, {"time_scale": 1})
		game.set_process(false)
		game.debug_overlay.speed = speed
		for frame in 120 / speed:
			game._process(Simulation.TICK_SECONDS)
		assert_eq(game.simulation.tick, 120, "%dx: %d ticks a frame" % [speed, speed])
		assert_eq(game.simulation.state_hash(), expected, "%dx: the same state" % speed)


func test_speed_runs_the_session_clock_as_fast() -> void:
	var game := _game()
	assert_true(game.session_clock is DebugClock, "the overlay wraps the session clock")
	var inner := FakeClock.new()
	game.session_clock.inner = inner
	inner.reading = Session.reading(1_000_000, 0, "e")
	game.session_clock.now()
	game.debug_overlay.speed = 10
	inner.reading = Session.reading(1_001_000, 1000, "e")
	assert_eq(game.session_clock.now(), Session.reading(1_010_000, 10_000, "e"), "one real second reads as ten")


func test_a_speed_not_offered_falls_back_to_1x() -> void:
	var game := _game()
	game.debug_overlay.speed = 3
	assert_eq(game.debug_overlay.speed, 1)
	game.debug_overlay.speed = 5
	assert_true(game.debug_overlay.speed_buttons[5].button_pressed, "its button shows it")
	assert_false(game.debug_overlay.speed_buttons[1].button_pressed)


# --- Reset ------------------------------------------------------------------------

func test_reset_twice_within_2s_starts_over_and_replaces_the_save() -> void:
	var store := SaveStore.new(DIR)
	var game := _game(store)
	assert_null(game.test_mode, "normal play")
	assert_true(game.autosave.enabled)
	var old_seed: int = game.simulation.rng.seed_value
	game.simulation.run(300)
	assert_eq(game.save_now(), "")
	var before := SaveStore.read_file(store.path_for(LEVEL))
	assert_eq(int(before["save"]["sim"]["tick"]), 300)
	var overlay: Node = game.debug_overlay
	assert_false(overlay.press_reset(10_000), "the first click only asks")
	assert_eq(overlay.reset_button.text, DebugOverlay.RESET_CONFIRM_TEXT)
	assert_eq(game.simulation.tick, 300, "nothing reset yet")
	assert_true(overlay.press_reset(11_500), "the second within 2 s resets")
	var sim: Simulation = game.simulation
	assert_eq(sim.tick, 0, "a fresh level")
	assert_ne(sim.rng.seed_value, old_seed, "a new random seed, as on a first launch")
	assert_eq(sim.session.enabled, true, "sessions on, as in normal play")
	assert_eq(DebugCounts.count(sim)["woken"], 1, "only the first slime awake")
	var after := SaveStore.read_file(store.path_for(LEVEL))
	assert_eq(after["status"], SaveStore.OK, "the save is still there")
	assert_eq(int(after["save"]["sim"]["tick"]), 0, "written over with the fresh level")
	# Both sides go through a load: a load puts mid-air slimes down (D12,
	# chunk 19), and the live fresh level, not yet ticked, has no slime
	# marked as supported.
	var restored := Simulation.from_save(after["save"], game.level.data, game._terrain)
	var fresh := Simulation.from_save(sim.to_save(), game.level.data, game._terrain)
	assert_eq(restored.state_hash(), fresh.state_hash(), "the save holds the fresh level")
	assert_eq(overlay.reset_button.text, DebugOverlay.RESET_TEXT)


func test_a_second_click_after_2s_only_asks_again() -> void:
	var game := _game(null, {"seed": SEED})
	game.simulation.run(60)
	var overlay: Node = game.debug_overlay
	assert_false(overlay.press_reset(10_000))
	assert_false(overlay.press_reset(12_001), "too late: asks again")
	assert_eq(game.simulation.tick, 60)
	assert_true(overlay.press_reset(13_000))
	assert_eq(game.simulation.tick, 0)


func test_reset_in_test_mode_keeps_the_run_seed() -> void:
	var game := _game(null, {"seed": SEED})
	var fresh: String = game.simulation.state_hash()
	game.test_mode.run_ticks(90)
	var overlay: Node = game.debug_overlay
	overlay.press_reset(0)
	overlay.press_reset(1)
	assert_eq(game.simulation.rng.seed_value, SEED)
	assert_eq(game.simulation.state_hash(), fresh, "the run starts over")
	assert_string_contains(overlay.status, "no save written")



func test_reset_in_test_mode_opens_sessions_only_when_the_run_has_them() -> void:
	for sessions in [false, true]:
		var game := _game(null, {"sessions": sessions})
		game.debug_overlay.press_reset(0)
		game.debug_overlay.press_reset(1)
		assert_eq(game.simulation.session.enabled, sessions, "sessions: %s" % sessions)

func test_reset_never_writes_over_a_blocked_save() -> void:
	# A save of a newer level version, once the app has shipped (D149): the
	# game blocks it (an unreadable file is set aside instead since chunk 19,
	# and before shipping a refused save is too, so neither blocks).
	var store := SaveStore.new(DIR)
	var newer := JSON.stringify({"format": SaveData.FORMAT, "level": {"id": LEVEL, "version": 999},
			"sim": {"tick": 5}, "slimes": [{"species": "A", "size": 1, "state": "train", "centre": [10, 20]}],
			"objects": {}, "gates": {}})
	DirAccess.make_dir_recursive_absolute(DIR)
	var file := FileAccess.open(store.path_for(LEVEL), FileAccess.WRITE)
	file.store_string(newer)
	file.close()
	var game := _game(store, {}, true)
	assert_false(store.can_write(LEVEL), "blocked")
	var overlay: Node = game.debug_overlay
	overlay.press_reset(0)
	overlay.press_reset(1)
	assert_eq(game.simulation.tick, 0)
	assert_eq(FileAccess.get_file_as_string(store.path_for(LEVEL)), newer, "kept as it is")
	assert_string_contains(overlay.status, "save not written")


# --- Kill -------------------------------------------------------------------------

func test_the_armed_kill_tap_sends_the_slime_to_the_start_and_never_reaches_the_sim() -> void:
	var game := _game(null, {"block_real_input": false})
	var sim: Simulation = game.simulation
	game.test_mode.run_ticks(30)
	var slime := _id_of(sim, "s1.sleeper.01")
	assert_gt(slime, 0)
	var at: Vector2 = sim.view.world_to_screen(sim.slimes.centre_of(slime))
	var overlay: Node = game.debug_overlay
	overlay.arm_kill(true)
	assert_eq(overlay.kill_button.text, DebugOverlay.KILL_ARMED_TEXT, "shows it is armed")
	_click(game, at, true)
	_click(game, at, false)
	assert_false(overlay.kill_armed, "one use disarms")
	assert_eq(overlay.kill_button.text, DebugOverlay.KILL_TEXT)
	assert_eq(sim.slimes.state_of(slime), SlimeBodies.TRAIN, "on the train")
	# At the start of the loop: the first free spot from it (LoopStart.move).
	assert_lt(sim.train.distance_of(slime), LoopStart.SPOTS * 2.0 * (SlimeBodies.ring_radius_for(1) + SlimeBodies.EDGE),
			"at the start of the loop")
	assert_eq(sim.offscreen.lost.back()["id"], slime)
	game.test_mode.run_ticks(1)
	assert_eq(sim.input_log.size(), 0, "neither the press nor the release reached the simulation")
	assert_eq(sim.taps.size(), 0)
	_click(game, at, true)
	game.test_mode.run_ticks(1)
	assert_eq(sim.input_log.size(), 1, "disarmed, the next press is the game's")


func test_an_armed_kill_on_no_slime_just_disarms() -> void:
	var game := _game(null, {"block_real_input": false})
	var overlay: Node = game.debug_overlay
	overlay.arm_kill(true)
	# Far from every slime, and below the parent zone (never the kill tool's).
	_touch(game, Vector2(-5000, 5000), true)
	_touch(game, Vector2(-5000, 5000), false)
	assert_false(overlay.kill_armed)
	assert_eq(overlay.status, "Kill: no slime there")
	game.test_mode.run_ticks(1)
	assert_eq(game.simulation.input_log.size(), 0)


func test_another_control_disarms_the_kill_tool() -> void:
	var game := _game(null, {"seed": SEED})
	var overlay: Node = game.debug_overlay
	overlay.arm_kill(true)
	overlay.show_labels(true)
	assert_false(overlay.kill_armed, "Labels disarms it")
	overlay.arm_kill(true)
	overlay.speed_buttons[2].pressed.emit()
	assert_false(overlay.kill_armed, "a speed disarms it")
	assert_eq(overlay.speed, 2)


# --- Input ------------------------------------------------------------------------

func test_a_touch_on_a_control_is_the_overlays_and_one_elsewhere_the_games() -> void:
	var game := _game(null, {"block_real_input": false})
	await get_tree().process_frame
	var overlay: Node = game.debug_overlay
	var button: Button = overlay.speed_buttons[5]
	var on_button := button.get_global_rect().get_center()
	assert_true(overlay.over_controls(on_button))
	for each in overlay.speed_buttons.values() + [overlay.reset_button, overlay.labels_button, overlay.kill_button]:
		assert_gte(each.get_global_rect().position.y, TapDispatcher.parent_zone_height(game.simulation.view),
				"%s stays out of the parent band" % each.text)
	_touch(game, on_button, true)
	_touch(game, on_button, false)
	game.test_mode.run_ticks(1)
	assert_eq(game.simulation.input_log.size(), 0, "the control's touch is swallowed")
	_touch(game, Vector2(576, 400), true)
	_touch(game, Vector2(576, 400), false)
	game.test_mode.run_ticks(1)
	assert_eq(game.simulation.input_log.size(), 2, "a touch elsewhere reaches the game")


func test_the_labels_draw_for_every_slime() -> void:
	var game := _game(null, {"seed": SEED})
	var overlay: Node = game.debug_overlay
	assert_false(overlay.labels.visible, "hidden until toggled")
	overlay.show_labels(true)
	assert_true(overlay.labels.visible)
	overlay._process(0.0)
	assert_eq(overlay.labels.simulation, game.simulation)
	var first := _id_of(game.simulation, "start.first-slime")
	var lines := DebugSlimeLabels.lines_for(game.simulation, first)
	assert_eq(lines[0], "#%d train" % first)
	assert_eq(lines[1], "start.first-slime")
	assert_string_contains(overlay.counter_label.text, "Woken 1 / available")


# --- Release guard ----------------------------------------------------------------

func test_a_release_build_gets_no_overlay() -> void:
	var game: Node = load(MAIN_SCENE).instantiate()
	game.test_mode_guard = TestModeGuard.new(false)
	add_child_autofree(game)
	game.add_debug_overlay()
	assert_null(game.debug_overlay)
	assert_false(game.session_clock is DebugClock)


func test_a_game_a_test_adds_has_no_overlay_unless_asked() -> void:
	var game: Node = load(MAIN_SCENE).instantiate()
	add_child_autofree(game)
	assert_null(game.debug_overlay)
	assert_null(game.get_node_or_null("DebugOverlay"))
