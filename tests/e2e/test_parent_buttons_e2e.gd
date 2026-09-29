extends GutTest
## The parent buttons (src/parent/parent_gate.gd) through the real game scene,
## with real touch events and stepped ticks: a tap on the parent zone reveals
## them (once setup is done) and still gets its ripple, but never calls nor
## starts a session; they hide after 5 s with no press, a new parent-zone tap
## restarts the 5 s; a tap outside them closes them and does its normal job
## (it calls, and in screensaver mode starts a session: DoD 24); wake early
## shows only at bedtime, live; every button is at least 9 x 9 mm, 2 mm apart,
## and never shows a time left; a press on a button is swallowed and raises
## the code prompt for that action; nothing pauses; the debug bar moves below
## the row while it shows and hides under a surface that covers the world.
##
## Every game here gets its own ParentStore on a scratch directory, seeded
## with a code unless the test says otherwise.

# @test-link [[req_parent_gate_and_access]]
# @test-link [[req_controls_tap_zones]]
# @test-link [[req_actor_roles_and_permissions]]
# @test-link [[rule_time_left_shown_only_behind_code]]

const MAIN_SCENE := "res://src/main.tscn"
const DIR := "user://test-parent-buttons/"
const STORE_PATH := DIR + "parent.json"
const SEED := 20260928
const CODE := "123456"
## A point in the parent zone (7 mm, about 67 px on the reference phone),
## well left of the buttons.
const ZONE_POINT := Vector2(300, 20)
## A point on the world: below the parent zone, between the edge strips.
const WORLD_POINT := Vector2(576, 400)
## Controls hold float32 positions: drawn and hit rects agree to this, px.
const NEAR := Vector2(0.01, 0.01)


## Stands in for SessionClock in normal play.
class FakeClock:
	extends RefCounted
	var reading := Session.reading(1_800_000_000_000, 1_000, "fake")

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


func _store(with_code: bool) -> ParentStore:
	var store := ParentStore.new(STORE_PATH)
	if with_code:
		store.set_code(CODE)
	return store


## A game with a parent store (a code set unless `with_code` is false), in
## test mode with sessions, as in normal play (screensaver mode first), real
## input let through.
func _game(with_code := true, overlay := false) -> Node:
	var game: Node = load(MAIN_SCENE).instantiate()
	game.parent_store = _store(with_code)
	add_child_autofree(game)
	if overlay:
		game.add_debug_overlay()
	var run := {"seed": SEED, "time_scale": 0, "sessions": true, "block_real_input": false}
	assert_eq(game.enable_test_mode(run), PackedStringArray())
	return game


func _touch(game: Node, at: Vector2, pressed: bool, index := 0) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.pressed = pressed
	event.position = at
	game._unhandled_input(event)


## A tap (press and release) at `at`, then one step so the simulation reads it.
func _tap(game: Node, at: Vector2) -> void:
	_touch(game, at, true)
	_touch(game, at, false)
	game.step_simulation()


func _steps(game: Node, count: int) -> void:
	for i in count:
		game.step_simulation()


func _centre_of(game: Node, action: String) -> Vector2:
	return game.parent_gate.button_rect(action).get_center()


## The touch events the simulation got so far (down and up).
func _touches(sim: Simulation) -> int:
	var count := 0
	for event in sim.input_log:
		if event["kind"] in [Simulation.INPUT_TOUCH_DOWN, Simulation.INPUT_TOUCH_UP]:
			count += 1
	return count


func _start_session(game: Node) -> void:
	_tap(game, WORLD_POINT)
	assert_eq(game.simulation.session.phase, Session.SESSION, "a world tap starts a session")


# --- Reveal -----------------------------------------------------------------------

func test_a_parent_zone_tap_reveals_the_buttons_with_a_ripple_but_no_call_and_no_session() -> void:
	var game := _game()
	var gate: ParentGate = game.parent_gate
	var sim: Simulation = game.simulation
	assert_eq(gate.state, ParentGate.State.HIDDEN)
	assert_eq(sim.session.phase, Session.SCREENSAVER)
	_touch(game, ZONE_POINT, true)
	assert_eq(gate.state, ParentGate.State.BUTTONS, "revealed at once")
	_touch(game, ZONE_POINT, false)
	game.step_simulation()
	assert_eq(sim.taps.size(), 1, "the tap still reached the simulation")
	assert_eq(sim.taps[-1]["zone"], TapDispatcher.ZONE_PARENT)
	assert_false(sim.taps[-1]["call"], "no call")
	assert_eq(sim.ripples.size(), 1, "the child still gets the ripple")
	assert_eq(sim.session.phase, Session.SCREENSAVER, "no session start")
	assert_true(gate.buttons[ParentGate.SETTINGS].visible)
	assert_true(gate.buttons[ParentGate.LEAVE].visible)
	assert_false(gate.buttons[ParentGate.WAKE_EARLY].visible, "not bedtime")


func test_no_reveal_without_a_code() -> void:
	# Setup isn't done: it is open (test_parent_setup_e2e) and takes the tap.
	var game := _game(false)
	var sim: Simulation = game.simulation
	assert_eq(game.parent_gate.state, ParentGate.State.SETUP, "setup first")
	_tap(game, ZONE_POINT)
	assert_eq(game.parent_gate.state, ParentGate.State.SETUP, "the parent zone reveals nothing")
	assert_eq(sim.taps.size(), 0, "setup's tap")
	assert_false(game.parent_gate.reveal(), "no reveal without a code")
	for action in game.parent_gate.buttons:
		assert_false(game.parent_gate.buttons[action].visible, action)


func test_a_game_without_a_parent_store_has_no_parent_layer() -> void:
	var game: Node = load(MAIN_SCENE).instantiate()
	add_child_autofree(game)
	assert_null(game.parent_store, "a game a test adds gets none unless the test gives one")
	assert_null(game.parent_gate)


# --- Hiding -----------------------------------------------------------------------

func test_the_buttons_hide_after_exactly_5_s_idle() -> void:
	var game := _game()
	var gate: ParentGate = game.parent_gate
	_touch(game, ZONE_POINT, true)
	_touch(game, ZONE_POINT, false)
	_steps(game, ParentGate.HIDE_STEPS - 1)
	assert_eq(gate.state, ParentGate.State.BUTTONS, "4.98 s: still shown")
	_steps(game, 1)
	assert_eq(gate.state, ParentGate.State.HIDDEN, "5 s: hidden")
	for action in gate.buttons:
		assert_false(gate.buttons[action].visible, action)


func test_a_parent_zone_tap_at_4_s_restarts_the_5_s_and_is_forwarded() -> void:
	var game := _game()
	var gate: ParentGate = game.parent_gate
	var sim: Simulation = game.simulation
	_tap(game, ZONE_POINT)
	_steps(game, 239)
	_touch(game, ZONE_POINT + Vector2(100, 0), true)
	_touch(game, ZONE_POINT + Vector2(100, 0), false)
	assert_eq(gate.state, ParentGate.State.BUTTONS, "not a toggle")
	_steps(game, ParentGate.HIDE_STEPS - 1)
	assert_eq(gate.state, ParentGate.State.BUTTONS, "9 s after the first tap: still shown")
	assert_eq(sim.taps.size(), 2, "the second tap reached the simulation too")
	assert_eq(sim.taps[-1]["zone"], TapDispatcher.ZONE_PARENT)
	_steps(game, 1)
	assert_eq(gate.state, ParentGate.State.HIDDEN, "5 s after the second tap")


func test_the_timers_run_in_normal_play_too() -> void:
	var game: Node = load(MAIN_SCENE).instantiate()
	game.parent_store = _store(true)
	add_child_autofree(game)
	assert_null(game.test_mode, "normal play")
	game.session_clock = FakeClock.new()
	var zone_point := Vector2(game.simulation.view.screen_size.x * 0.25, 5)
	_tap(game, zone_point)
	assert_eq(game.parent_gate.state, ParentGate.State.BUTTONS)
	_steps(game, ParentGate.HIDE_STEPS - 2)
	assert_eq(game.parent_gate.state, ParentGate.State.BUTTONS)
	_steps(game, 1)
	assert_eq(game.parent_gate.state, ParentGate.State.HIDDEN)


# --- A tap outside ---------------------------------------------------------------

func test_a_world_tap_while_open_closes_them_calls_and_starts_a_session() -> void:
	var game := _game()
	var gate: ParentGate = game.parent_gate
	var sim: Simulation = game.simulation
	_tap(game, ZONE_POINT)
	_steps(game, 30)
	_touch(game, WORLD_POINT, true)
	assert_eq(gate.state, ParentGate.State.HIDDEN, "closed at once")
	_touch(game, WORLD_POINT, false)
	game.step_simulation()
	assert_eq(sim.taps.size(), 2)
	assert_eq(sim.taps[-1]["zone"], TapDispatcher.ZONE_GROUND, "it reached the world")
	assert_true(sim.taps[-1]["call"], "and called")
	assert_eq(sim.session.phase, Session.SESSION, "screensaver mode: it starts a session (DoD 24)")


# --- Wake early and the layout ----------------------------------------------------

func test_wake_early_shows_only_at_bedtime_and_follows_the_phase_live() -> void:
	var game := _game()
	var gate: ParentGate = game.parent_gate
	var sim: Simulation = game.simulation
	_start_session(game)
	_tap(game, ZONE_POINT)
	assert_false(gate.buttons[ParentGate.WAKE_EARLY].visible, "a session: no wake early")
	var settings_at := gate.button_rect(ParentGate.SETTINGS)
	var leave_at := gate.button_rect(ParentGate.LEAVE)
	sim.session.jump(sim, Session.BEDTIME_MS)
	game.step_simulation()
	assert_eq(sim.session.phase, Session.BEDTIME)
	assert_eq(gate.state, ParentGate.State.BUTTONS, "still open")
	assert_true(gate.buttons[ParentGate.WAKE_EARLY].visible, "bedtime came: wake early appears")
	assert_eq(gate.button_rect(ParentGate.SETTINGS), settings_at, "settings didn't move")
	assert_eq(gate.button_rect(ParentGate.LEAVE), leave_at, "leave didn't move")
	sim.session.jump(sim, Session.SUNRISE_MS)
	game.step_simulation()
	assert_eq(sim.session.phase, Session.SCREENSAVER)
	assert_false(gate.buttons[ParentGate.WAKE_EARLY].visible, "sunrise: it goes")
	assert_eq(gate.state, ParentGate.State.BUTTONS)


func test_revealed_at_bedtime_all_three_show() -> void:
	var game := _game()
	var sim: Simulation = game.simulation
	_start_session(game)
	sim.session.jump(sim, Session.BEDTIME_MS)
	game.step_simulation()
	_touch(game, ZONE_POINT, true)
	for action in [ParentGate.WAKE_EARLY, ParentGate.LEAVE, ParentGate.SETTINGS]:
		assert_true(game.parent_gate.buttons[action].visible, action)


func test_each_button_is_at_least_9_mm_square_and_2_mm_apart_in_a_row_from_the_top_right() -> void:
	var game := _game()
	var sim: Simulation = game.simulation
	_start_session(game)
	sim.session.jump(sim, Session.BEDTIME_MS)
	game.step_simulation()
	_tap(game, ZONE_POINT)
	var gate: ParentGate = game.parent_gate
	var mm: float = sim.view.px_per_mm
	var wake := gate.button_rect(ParentGate.WAKE_EARLY)
	var leave := gate.button_rect(ParentGate.LEAVE)
	var settings := gate.button_rect(ParentGate.SETTINGS)
	for rect in [wake, leave, settings]:
		assert_gte(rect.size.x, 9.0 * mm, "at least 9 mm wide")
		assert_gte(rect.size.y, 9.0 * mm, "at least 9 mm tall")
		assert_gte(rect.position.y, 0.0)
		assert_lte(rect.end.x, sim.view.screen_size.x, "on the screen")
	assert_gte(leave.position.x - wake.end.x, 2.0 * mm, "wake early, then leave, 2 mm apart")
	assert_gte(settings.position.x - leave.end.x, 2.0 * mm, "leave, then settings, 2 mm apart")
	assert_lt(sim.view.screen_size.x - settings.end.x, 2.0 * mm, "settings at the far right")
	assert_eq(wake.position.y, settings.position.y, "one row")
	for action in gate.buttons:
		var button: Button = gate.buttons[action]
		var rect := gate.button_rect(action)
		assert_almost_eq(button.position, rect.position, NEAR, "%s drawn where it's hit" % action)
		assert_almost_eq(button.size, rect.size, NEAR, "%s: its size" % action)


func test_no_button_ever_shows_a_digit() -> void:
	var game := _game()
	var sim: Simulation = game.simulation
	_start_session(game)
	sim.session.jump(sim, Session.BEDTIME_MS)
	game.step_simulation()
	_tap(game, ZONE_POINT)
	var digits := RegEx.create_from_string("[0-9]")
	for action in game.parent_gate.buttons:
		var shown: String = game.parent_gate.buttons[action].text
		assert_eq(shown, ParentText.text(action, ParentText.language()), "%s: its word" % action)
		assert_null(digits.search(shown), "%s: no time left, no number" % action)
		for lang in ParentText.LANGUAGES:
			assert_null(digits.search(ParentText.text(action, lang)), "%s in %s" % [action, lang])


# --- A press on a button ----------------------------------------------------------

func test_pressing_settings_enters_the_prompt_and_the_tap_is_swallowed() -> void:
	var game := _game()
	var gate: ParentGate = game.parent_gate
	var sim: Simulation = game.simulation
	_tap(game, ZONE_POINT)
	var taps := sim.taps.size()
	var touches := _touches(sim)
	var at := _centre_of(game, ParentGate.SETTINGS)
	_touch(game, at, true)
	assert_eq(gate.state, ParentGate.State.PROMPT, "every button leads to the code prompt")
	assert_eq(gate.pending_action, ParentGate.SETTINGS)
	assert_false(gate.buttons[ParentGate.SETTINGS].visible, "the row gives way to the prompt")
	_touch(game, at, false)
	game.step_simulation()
	assert_eq(sim.taps.size(), taps, "no tap reached the simulation")
	assert_eq(_touches(sim), touches, "neither the press nor its release")
	assert_eq(sim.session.phase, Session.SCREENSAVER)


func test_every_shown_button_enters_the_prompt_for_its_action() -> void:
	for action in [ParentGate.WAKE_EARLY, ParentGate.LEAVE, ParentGate.SETTINGS]:
		var game := _game()
		var sim: Simulation = game.simulation
		_start_session(game)
		sim.session.jump(sim, Session.BEDTIME_MS)
		game.step_simulation()
		_tap(game, ZONE_POINT)
		_touch(game, _centre_of(game, action), true)
		assert_eq(game.parent_gate.state, ParentGate.State.PROMPT, action)
		assert_eq(game.parent_gate.pending_action, action)


func test_the_hidden_wake_early_slot_is_no_button() -> void:
	var game := _game()
	_tap(game, ZONE_POINT)
	var at := _centre_of(game, ParentGate.WAKE_EARLY)
	_touch(game, Vector2(at.x, maxf(at.y, TapDispatcher.parent_zone_height(game.simulation.view) + 4)), true)
	assert_ne(game.parent_gate.state, ParentGate.State.PROMPT, "not bedtime: nothing there")


func test_a_tap_outside_the_prompt_closes_it_and_is_forwarded() -> void:
	var game := _game()
	var gate: ParentGate = game.parent_gate
	var sim: Simulation = game.simulation
	_tap(game, ZONE_POINT)
	_touch(game, _centre_of(game, ParentGate.LEAVE), true)
	_touch(game, _centre_of(game, ParentGate.LEAVE), false)
	var panel := ParentLayout.prompt_rect(sim.view)
	var taps := sim.taps.size()
	_tap(game, panel.get_center())
	assert_eq(gate.state, ParentGate.State.PROMPT, "a tap on the prompt is the prompt's")
	assert_eq(sim.taps.size(), taps)
	var outside := Vector2(panel.get_center().x, panel.end.y + 20)
	_touch(game, outside, true)
	assert_eq(gate.state, ParentGate.State.HIDDEN, "a tap outside closes it")
	assert_eq(gate.pending_action, "")
	_touch(game, outside, false)
	game.step_simulation()
	assert_eq(sim.taps.size(), taps + 1, "and does its normal job")
	assert_true(sim.taps[-1]["call"])


# --- Nothing pauses ---------------------------------------------------------------

func test_the_simulation_keeps_stepping_while_the_buttons_or_the_prompt_are_open() -> void:
	var game := _game()
	var sim: Simulation = game.simulation
	_start_session(game)
	_tap(game, ZONE_POINT)
	var tick := sim.tick
	var elapsed := sim.session.elapsed_ms
	_steps(game, 60)
	assert_eq(sim.tick, tick + 60, "the buttons pause nothing")
	assert_gt(sim.session.elapsed_ms, elapsed, "the session timer runs")
	_touch(game, _centre_of(game, ParentGate.LEAVE), true)
	assert_eq(game.parent_gate.state, ParentGate.State.PROMPT)
	elapsed = sim.session.elapsed_ms
	_steps(game, 60)
	assert_eq(sim.tick, tick + 120, "the prompt pauses nothing")
	assert_gt(sim.session.elapsed_ms, elapsed)


# --- The debug bar ----------------------------------------------------------------

func test_the_debug_bar_sits_below_the_row_while_open_and_hides_under_the_prompt() -> void:
	var game := _game(true, true)
	var overlay: Node = game.debug_overlay
	assert_not_null(overlay, "headless tests run a debug build")
	var gate: ParentGate = game.parent_gate
	var view: ScreenView = game.simulation.view
	var home := TapDispatcher.parent_zone_height(view) + DebugOverlay.BAR_GAP
	overlay._process(0.0)
	assert_almost_eq(overlay.bar.position.y, home, 0.01, "under the parent zone")
	_tap(game, ZONE_POINT)
	overlay._process(0.0)
	assert_almost_eq(overlay.bar.position.y, gate.menu_bottom() + DebugOverlay.BAR_GAP, 0.01, "below the row")
	assert_gt(gate.menu_bottom(), TapDispatcher.parent_zone_height(view))
	assert_true(overlay.bar.visible)
	for action in gate.buttons:
		assert_lt(gate.button_rect(action).end.y, overlay.bar.position.y, "%s: no overlap" % action)
	_steps(game, ParentGate.HIDE_STEPS)
	overlay._process(0.0)
	assert_almost_eq(overlay.bar.position.y, home, 0.01, "back in its place")
	_tap(game, ZONE_POINT)
	_touch(game, _centre_of(game, ParentGate.SETTINGS), true)
	_touch(game, _centre_of(game, ParentGate.SETTINGS), false)
	overlay._process(0.0)
	assert_false(overlay.bar.visible, "hidden under a surface that covers the world")
	assert_ne(overlay.fps_label.text, "", "its stats keep working")
	_tap(game, Vector2(ParentLayout.prompt_rect(view).get_center().x, view.screen_size.y - 10))
	overlay._process(0.0)
	assert_true(overlay.bar.visible, "shown again after")
	assert_almost_eq(overlay.bar.position.y, home, 0.01)


func test_an_armed_kill_never_takes_a_parent_zone_tap() -> void:
	var game := _game(true, true)
	var overlay: Node = game.debug_overlay
	var sim: Simulation = game.simulation
	overlay.arm_kill(true)
	_tap(game, ZONE_POINT)
	assert_eq(game.parent_gate.state, ParentGate.State.BUTTONS)
	assert_true(overlay.kill_armed, "the parent zone tap isn't the kill tool's")
	assert_eq(sim.taps.size(), 1, "the simulation got it")
