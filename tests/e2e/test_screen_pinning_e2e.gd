extends GutTest
## Screen pinning, Back and the app's lifecycle (master spec §5.9, §5.7,
## chunk 20) through the real game scene, on a fake platform
## (PhonePlatform) that records what the game asks of the phone: a later
## launch asks for pinning as it opens, before the world takes a tap; a first
## launch asks right after setup finishes, and an interrupted setup only once
## it is finished; a locked parent store is a later launch; coming back from
## the background never asks again; leave stops the pinning before the app
## closes; Back does nothing while pinned and sends the app to the background
## otherwise (it never quits); the back gesture is kept off the edge strips at
## start and on every resize. Lifecycle: the app paused saves, the app
## resumed takes the tilt's neutral again, and the screen stays on during a
## session only.
##
## Every game here gets its own ParentStore on a scratch directory.

# @test-link [[req_screen_pinning]]
# @test-link [[req_session_lifecycle]]
# @test-link [[req_persistence_and_saves]]

const MAIN_SCENE := "res://src/main.tscn"
const DIR := "user://test-screen-pinning/"
const STORE_PATH := DIR + "parent.json"
const SAVE_DIR := DIR + "saves/"
const SEED := 20260930
const CODE := "135790"
## A point in the parent zone, well left of the parent buttons.
const ZONE_POINT := Vector2(300, 20)
## A world point: below the parent zone, between the edge strips.
const WORLD_POINT := Vector2(576, 400)


## Stands in for the phone: records the calls, in order ("quit" is the
## game's quit_app, added by _game()).
class FakePlatform:
	extends PhonePlatform
	var calls: Array[String] = []
	var pinned := false
	## Every exclusion handed over, in order.
	var exclusions: Array = []

	func request_pinning() -> void:
		calls.append("request_pinning")

	func stop_pinning() -> void:
		calls.append("stop_pinning")

	func is_pinned() -> bool:
		return pinned

	func move_to_background() -> void:
		calls.append("move_to_background")

	func set_back_gesture_exclusion(rects: Array[Rect2i]) -> void:
		exclusions.append(rects)


func before_each() -> void:
	_clear(SAVE_DIR)
	_clear(DIR)


func after_all() -> void:
	_clear(SAVE_DIR)
	_clear(DIR)


func _clear(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)


## A launch on the store at STORE_PATH (seeded with CODE when `set_code`),
## on a fake platform. Test mode with sessions and real input comes after the
## boot, so the boot is the launch's own. `store`: false for no parent layer.
## `saves`: the game's save store (none by default: it never writes).
func _game(fake: FakePlatform, set_code := true, store := true, saves: SaveStore = null) -> Node:
	var game: Node = load(MAIN_SCENE).instantiate()
	game.platform = fake
	game.save_store = saves
	if store:
		var parent_store := ParentStore.new(STORE_PATH)
		if set_code:
			parent_store.set_code(CODE)
		game.parent_store = parent_store
	game.quit_app = func() -> void: fake.calls.append("quit")
	add_child_autofree(game)
	return game


## Test mode with sessions and real input let through, `overrides` merged.
func _test_mode(game: Node, overrides := {}) -> void:
	var run := {"seed": SEED, "time_scale": 0, "sessions": true, "block_real_input": false}
	run.merge(overrides, true)
	assert_eq(game.enable_test_mode(run), PackedStringArray())


func _touch(game: Node, at: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.pressed = pressed
	event.position = at
	game._unhandled_input(event)


func _press(game: Node, at: Vector2) -> void:
	_touch(game, at, true)
	_touch(game, at, false)


func _setup(game: Node) -> ParentSetup:
	return game.parent_gate.surfaces[ParentGate.State.SETUP]


## Setup's first three steps: Next, then CODE typed twice.
func _to_setup_last_steps(game: Node) -> void:
	var setup := _setup(game)
	_press(game, setup.next_rect().get_center())
	for entry in 2:
		for digit in CODE:
			_press(game, setup.code_entry.pad.key_rect(digit).get_center())
	assert_eq(setup.current, ParentSetup.Step.FORGOTTEN)


## Setup's last two Nexts (the last one Finish).
func _finish_setup(game: Node) -> void:
	_press(game, _setup(game).next_rect().get_center())
	_press(game, _setup(game).next_rect().get_center())


# --- When pinning is asked ------------------------------------------------------------------

func test_a_later_launch_asks_for_pinning_as_it_opens() -> void:
	var fake := FakePlatform.new()
	var game := _game(fake)
	assert_eq(game.simulation.tick, 0, "before any step, so before any tap")
	assert_eq(fake.calls, ["request_pinning"] as Array[String])
	_test_mode(game)
	_press(game, WORLD_POINT)
	game.step_simulation()
	assert_eq(fake.calls, ["request_pinning"] as Array[String], "once")


func test_a_first_launch_asks_right_after_setup_finishes() -> void:
	var fake := FakePlatform.new()
	var game := _game(fake, false)
	_test_mode(game)
	assert_eq(game.parent_gate.state, ParentGate.State.SETUP)
	assert_eq(fake.calls, [] as Array[String], "not during setup")
	_to_setup_last_steps(game)
	_press(game, _setup(game).next_rect().get_center())
	assert_eq(fake.calls, [] as Array[String], "not on the pinning step itself")
	_press(game, _setup(game).next_rect().get_center())
	assert_true(game.parent_store.has_code())
	assert_eq(game.parent_gate.state, ParentGate.State.HIDDEN)
	assert_eq(fake.calls, ["request_pinning"] as Array[String], "right after Finish")


func test_an_interrupted_setup_asks_only_once_it_is_finished() -> void:
	var fake := FakePlatform.new()
	var game := _game(fake, false)
	_test_mode(game)
	_to_setup_last_steps(game)
	game.propagate_notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	game.propagate_notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	assert_eq(_setup(game).current, ParentSetup.Step.WELCOME, "setup starts over")
	assert_eq(fake.calls, [] as Array[String])
	_to_setup_last_steps(game)
	_finish_setup(game)
	assert_eq(fake.calls, ["request_pinning"] as Array[String], "once, after the finish")


func test_a_setup_killed_midway_asks_nothing_until_the_next_launch_finishes_it() -> void:
	var killed := FakePlatform.new()
	var first := _game(killed, false)
	_test_mode(first)
	_to_setup_last_steps(first)
	assert_eq(killed.calls, [] as Array[String])
	var fake := FakePlatform.new()
	var again := _game(fake, false)
	_test_mode(again)
	assert_eq(again.parent_gate.state, ParentGate.State.SETUP, "setup afresh")
	assert_eq(fake.calls, [] as Array[String])
	_to_setup_last_steps(again)
	_finish_setup(again)
	assert_eq(fake.calls, ["request_pinning"] as Array[String])


func test_a_locked_parent_store_is_a_later_launch_and_asks_at_once() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	for path in [STORE_PATH, STORE_PATH + ParentStore.BACKUP_SUFFIX]:
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string("{ not json")
		file.close()
	var fake := FakePlatform.new()
	var game: Node = load(MAIN_SCENE).instantiate()
	game.platform = fake
	game.parent_store = ParentStore.new(STORE_PATH)
	assert_push_error("locked")
	add_child_autofree(game)
	assert_true(game.parent_store.is_locked())
	assert_eq(game.parent_gate.state, ParentGate.State.HIDDEN, "no setup")
	assert_eq(fake.calls, ["request_pinning"] as Array[String])


func test_coming_back_from_the_background_does_not_ask_again() -> void:
	var fake := FakePlatform.new()
	var game := _game(fake)
	_test_mode(game)
	for what in [Node.NOTIFICATION_APPLICATION_FOCUS_OUT, Node.NOTIFICATION_APPLICATION_PAUSED,
			Node.NOTIFICATION_APPLICATION_RESUMED, Node.NOTIFICATION_APPLICATION_FOCUS_IN]:
		game.propagate_notification(what)
	game.step_simulation()
	assert_eq(fake.calls, ["request_pinning"] as Array[String], "only the launch's")


func test_a_game_without_a_parent_layer_asks_nothing() -> void:
	var fake := FakePlatform.new()
	var game := _game(fake, false, false)
	assert_null(game.parent_gate)
	assert_eq(fake.calls, [] as Array[String], "nothing could leave the pinning")


# --- Leave and Back ---------------------------------------------------------------------------

func test_leave_stops_the_pinning_before_the_app_closes() -> void:
	var fake := FakePlatform.new()
	var game := _game(fake)
	_test_mode(game)
	_press(game, ZONE_POINT)
	game.step_simulation()
	_press(game, game.parent_gate.button_rect(ParentGate.LEAVE).get_center())
	assert_eq(game.parent_gate.state, ParentGate.State.PROMPT)
	var prompt: ParentCodePrompt = game.parent_gate.surfaces[ParentGate.State.PROMPT]
	for digit in CODE:
		_press(game, prompt.pad.key_rect(digit).get_center())
	assert_eq(fake.calls, ["request_pinning", "stop_pinning", "quit"] as Array[String])


func test_back_never_quits_the_app() -> void:
	assert_false(ProjectSettings.get_setting("application/config/quit_on_go_back"),
			"Back is the game's to handle")


func test_back_while_pinned_does_nothing() -> void:
	var fake := FakePlatform.new()
	fake.pinned = true
	var game := _game(fake)
	_test_mode(game)
	game.propagate_notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	assert_eq(fake.calls, ["request_pinning"] as Array[String])
	assert_true(game.is_inside_tree())


func test_back_not_pinned_sends_the_app_to_the_background_and_saves() -> void:
	var fake := FakePlatform.new()
	var game := _game(fake, true, true, SaveStore.new(SAVE_DIR))
	_test_mode(game, {"autosave": true})
	_press(game, WORLD_POINT)
	for i in 30:
		game.step_simulation()
	assert_eq(game.simulation.session.phase, Session.SESSION)
	game.propagate_notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	assert_eq(fake.calls, ["request_pinning", "move_to_background"] as Array[String])
	var saved := SaveStore.read_file(SAVE_DIR + "test.json")
	assert_eq(saved["status"], SaveStore.OK, "saved on the way out")
	if saved["status"] == SaveStore.OK:
		assert_eq(int(saved["save"]["sim"]["tick"]), game.simulation.tick)
		assert_eq(saved["save"]["session"]["phase"], Session.SESSION, "the session goes on")


func test_the_edge_strips_are_kept_off_the_back_gesture_at_start_and_on_resize() -> void:
	var fake := FakePlatform.new()
	var game := _game(fake)
	var viewport: Viewport = game.get_viewport()
	var expected := ScreenPinning.edge_strip_exclusions(viewport.get_visible_rect().size,
			viewport.get_final_transform(), game.get_window().size)
	assert_eq(fake.exclusions.size(), 1, "at start")
	assert_eq(fake.exclusions[0], expected)
	viewport.size_changed.emit()
	assert_eq(fake.exclusions.size(), 2, "again on a resize")


# --- Lifecycle --------------------------------------------------------------------------------

func test_the_app_paused_saves_at_once_in_normal_play() -> void:
	var game := _game(FakePlatform.new(), true, false, SaveStore.new(SAVE_DIR))
	assert_null(game.test_mode, "normal play")
	assert_true(game.autosave.enabled)
	assert_false(FileAccess.file_exists(SAVE_DIR + "test.json"))
	game.simulation.run(20)
	game.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	var saved := SaveStore.read_file(SAVE_DIR + "test.json")
	assert_eq(saved["status"], SaveStore.OK)
	if saved["status"] == SaveStore.OK:
		assert_eq(int(saved["save"]["sim"]["tick"]), game.simulation.tick)


func test_the_app_resumed_takes_the_tilt_neutral_again() -> void:
	var game := _game(FakePlatform.new())
	_test_mode(game)
	var sim: Simulation = game.simulation
	_press(game, WORLD_POINT)
	game.step_simulation()
	assert_eq(sim.session.phase, Session.SESSION)
	sim.push_input(Simulation.tilt(25.0))
	game.step_simulation()
	assert_ne(sim.phone_tilt.neutral, 25.0)
	game.propagate_notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	game.step_simulation()
	assert_eq(sim.phone_tilt.neutral, 25.0)


func test_the_screen_stays_on_during_a_session_only() -> void:
	assert_false(ProjectSettings.get_setting("display/window/energy_saving/keep_screen_on"),
			"the phone's usual timeout unless a session keeps it on")
	var expected := {"fresh": false, "wind-down": true, "bedtime": false, "sunrise": false}
	for fixture in expected:
		var game := _game(FakePlatform.new())
		_test_mode(game, {"fixture": fixture})
		game.session_screen._process(0.0)
		assert_eq(game.session_screen._keep_on, expected[fixture],
				"%s (%s)" % [fixture, game.simulation.session.phase])
	var playing := _game(FakePlatform.new())
	_test_mode(playing)
	playing.session_screen._process(0.0)
	assert_false(playing.session_screen._keep_on, "screensaver mode")
	_press(playing, WORLD_POINT)
	playing.step_simulation()
	playing.session_screen._process(0.0)
	assert_true(playing.session_screen._keep_on, "a session starts: on")
