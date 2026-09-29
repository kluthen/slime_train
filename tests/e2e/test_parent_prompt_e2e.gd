extends GutTest
## The code prompt (src/parent/parent_code_prompt.gd, its pad
## src/parent/parent_pad.gd) through the real game scene, with real touch
## events and stepped ticks: every parent button raises it and nothing happens
## without the code; a wrong code shakes and clears the entry and counts one
## try; 5 wrong in a row start the 30 s wait, which refuses even the right
## code and survives closing the prompt and a kill (a new game on the same
## store); one count for every button; "Forgot the code?" is a stub; the
## prompt closes after 15 s idle, a press on it restarts the 15 s; a tap
## outside closes it and does its normal job (DoD 24); the right code runs
## the one action (wake early: sunrise on the next step; leave: the app quits;
## settings: settings open) and the next action asks again; the wake-early
## prompt shows the time until sunrise, live; the pad's keys are at least
## 9 x 9 mm, 2 mm apart; nothing pauses; test mode's block_real_input keeps
## real input off the parent layer.
##
## Every game here gets its own ParentStore on a scratch directory, seeded
## with CODE unless the test reloads the store (a "kill").

# @test-link [[req_denial_and_stepup_behavior]]
# @test-link [[req_parent_gate_and_access]]
# @test-link [[req_actor_roles_and_permissions]]
# @test-link [[rule_time_left_shown_only_behind_code]]
# @test-link [[req_session_lifecycle]]

const MAIN_SCENE := "res://src/main.tscn"
const DIR := "user://test-parent-prompt/"
const STORE_PATH := DIR + "parent.json"
const SEED := 20260929
const CODE := "123456"
const WRONG := "654321"
## A point in the parent zone, well left of the parent buttons.
const ZONE_POINT := Vector2(300, 20)
## A point on the world outside the prompt: below the parent zone, right of
## the left edge strip, left of the prompt's panel.
const WORLD_POINT := Vector2(150, 400)
## A world point for starting a session while nothing is open.
const START_POINT := Vector2(576, 400)

## Counts the calls to the game's quit_app.
var quits := 0


func before_each() -> void:
	quits = 0
	_clear(DIR)


func after_all() -> void:
	_clear(DIR)


func _clear(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)


## A game in test mode with sessions (screensaver mode first), real input let
## through, its quit counted. `set_code`: seed the store with CODE (a fresh
## store) or read it from disk as it is (a game started again after a kill).
func _game(set_code := true, block_real_input := false) -> Node:
	var store := ParentStore.new(STORE_PATH)
	if set_code:
		store.set_code(CODE)
	var game: Node = load(MAIN_SCENE).instantiate()
	game.parent_store = store
	add_child_autofree(game)
	var run := {"seed": SEED, "time_scale": 0, "sessions": true, "block_real_input": block_real_input}
	assert_eq(game.enable_test_mode(run), PackedStringArray())
	game.quit_app = func() -> void: quits += 1
	return game


func _touch(game: Node, at: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
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


func _prompt(game: Node) -> ParentCodePrompt:
	return game.parent_gate.surfaces[ParentGate.State.PROMPT]


## Reveals the parent buttons and presses `action`'s: the code prompt opens.
func _open(game: Node, action: String) -> ParentCodePrompt:
	_tap(game, ZONE_POINT)
	var at: Vector2 = game.parent_gate.button_rect(action).get_center()
	_touch(game, at, true)
	_touch(game, at, false)
	assert_eq(game.parent_gate.state, ParentGate.State.PROMPT, "%s raises the code prompt" % action)
	return _prompt(game)


## Presses the pad's `key` (a digit or ParentPad.DELETE), press and release.
func _key(game: Node, key: String) -> void:
	var at := _prompt(game).pad.key_rect(key).get_center()
	_touch(game, at, true)
	_touch(game, at, false)


func _enter(game: Node, code: String) -> void:
	for digit in code:
		_key(game, digit)


func _to_bedtime(game: Node) -> void:
	var sim: Simulation = game.simulation
	_tap(game, START_POINT)
	assert_eq(sim.session.phase, Session.SESSION)
	sim.session.jump(sim, Session.BEDTIME_MS)
	game.step_simulation()
	assert_eq(sim.session.phase, Session.BEDTIME)


func _wait_text(seconds: int) -> String:
	return ParentText.text("wait", ParentText.language()).format({"s": seconds})


# --- Refused without the code ---------------------------------------------------

func test_every_parent_button_raises_the_prompt_and_nothing_happens_without_the_code() -> void:
	for action in [ParentGate.WAKE_EARLY, ParentGate.LEAVE, ParentGate.SETTINGS]:
		var game := _game()
		var gate: ParentGate = game.parent_gate
		var sim: Simulation = game.simulation
		_to_bedtime(game)
		var prompt := _open(game, action)
		assert_eq(prompt.entry, "", action)
		_enter(game, "12345")
		_steps(game, 30)
		_enter(game, "7")
		_steps(game, 30)
		assert_eq(sim.session.phase, Session.BEDTIME, "%s: still bedtime" % action)
		assert_eq(quits, 0, "%s: no quit" % action)
		assert_eq(gate.state, ParentGate.State.PROMPT, "%s: settings not opened" % action)


# --- Wrong codes and the wait ---------------------------------------------------

func test_a_wrong_code_shakes_and_clears_the_entry_and_counts_one_try() -> void:
	var game := _game()
	var prompt := _open(game, ParentGate.LEAVE)
	_enter(game, "65432")
	assert_eq(prompt.entry, "65432", "five digits: not yet checked")
	assert_eq(game.parent_store.wrong_tries(), 0)
	_key(game, "1")
	assert_eq(prompt.entry, "", "the 6th digit submits; wrong: the entry clears")
	assert_eq(game.parent_store.wrong_tries(), 1, "one try counted, on disk")
	assert_eq(ParentStore.new(STORE_PATH).wrong_tries(), 1)
	assert_true(prompt.shaking(), "the entry shakes")
	var moved := false
	for i in ParentCodePrompt.SHAKE_STEPS:
		moved = moved or absf(prompt.shake_offset()) > 0.5
		game.step_simulation()
	assert_true(moved, "a horizontal shake")
	assert_false(prompt.shaking(), "a short one")
	assert_eq(prompt.shake_offset(), 0.0)
	assert_eq(game.parent_gate.state, ParentGate.State.PROMPT, "the prompt stays for another try")
	assert_eq(quits, 0)


func test_the_delete_key_takes_back_the_last_digit() -> void:
	var game := _game()
	var prompt := _open(game, ParentGate.LEAVE)
	_enter(game, "129")
	_key(game, ParentPad.DELETE)
	assert_eq(prompt.entry, "12")
	_enter(game, "3456")
	assert_eq(quits, 1, "the right code after a delete")


func test_the_slots_show_dots_never_the_digits() -> void:
	var game := _game()
	var prompt := _open(game, ParentGate.LEAVE)
	_enter(game, "98")
	assert_eq(prompt.filled_slots(), 2, "two dots filled")
	for label in prompt.find_children("*", "Label", true, false):
		assert_false("98" in label.text or "9" in label.text, "no digit shown in '%s'" % label.text)


func test_five_wrong_start_the_wait_which_survives_closing_and_a_kill_then_ends() -> void:
	var game := _game()
	var store: ParentStore = game.parent_store
	var prompt := _open(game, ParentGate.LEAVE)
	for i in ParentStore.WRONG_TRIES_BEFORE_WAIT:
		_enter(game, WRONG)
	assert_eq(store.wrong_tries(), 5)
	assert_true(prompt.waiting(), "the wait")
	assert_eq(prompt.message.text, _wait_text(30), "the seconds left")
	_steps(game, 60)
	assert_eq(prompt.message.text, _wait_text(29), "live")
	_enter(game, CODE)
	assert_eq(prompt.entry, "", "the pad refuses digits")
	assert_eq(quits, 0, "even the right code is refused")
	# Closing the prompt: the wait goes on.
	_tap(game, WORLD_POINT)
	assert_eq(game.parent_gate.state, ParentGate.State.HIDDEN)
	prompt = _open(game, ParentGate.LEAVE)
	assert_true(prompt.waiting(), "the wait survives closing the prompt")
	# A kill: a new game on the same store file.
	var again := _game(false)
	assert_true(again.parent_store.has_code())
	prompt = _open(again, ParentGate.SETTINGS)
	assert_true(prompt.waiting(), "the wait survives a kill")
	_enter(again, CODE)
	assert_eq(again.parent_gate.state, ParentGate.State.PROMPT, "refused after the kill too")
	_steps(again, ParentStore.WAIT_MS * 60 / 1000)
	prompt = _open(again, ParentGate.SETTINGS)
	assert_false(prompt.waiting(), "30 s later: the wait is over")
	assert_eq(prompt.message.text, "")
	_enter(again, CODE)
	assert_eq(again.parent_gate.state, ParentGate.State.SETTINGS, "the right code works")
	assert_eq(again.parent_store.wrong_tries(), 0, "and the count restarted")


func test_after_the_wait_the_count_starts_again_from_zero() -> void:
	var game := _game()
	_open(game, ParentGate.LEAVE)
	for i in ParentStore.WRONG_TRIES_BEFORE_WAIT:
		_enter(game, WRONG)
	_steps(game, ParentStore.WAIT_MS * 60 / 1000 + 1)
	var prompt := _open(game, ParentGate.LEAVE)
	_enter(game, WRONG)
	assert_eq(game.parent_store.wrong_tries(), 1, "a fresh count")
	assert_false(prompt.waiting())


func test_one_count_for_every_parent_button() -> void:
	var game := _game()
	_open(game, ParentGate.LEAVE)
	for i in 3:
		_enter(game, WRONG)
	_tap(game, WORLD_POINT)
	var prompt := _open(game, ParentGate.SETTINGS)
	_enter(game, WRONG)
	assert_false(prompt.waiting(), "four so far")
	_enter(game, WRONG)
	assert_true(prompt.waiting(), "3 via leave + 2 via settings: the wait")


func test_forgot_the_code_shows_the_stub_changes_nothing_and_counts_no_try() -> void:
	var game := _game()
	var prompt := _open(game, ParentGate.LEAVE)
	var stub := ParentText.text("forgot_code_stub", ParentText.language())
	assert_eq(prompt.forgot.text, ParentText.text("forgot_code", ParentText.language()))
	assert_eq(prompt.note.text, "")
	_enter(game, "12")
	_tap(game, prompt.forgot_rect().get_center())
	assert_eq(prompt.note.text, stub)
	assert_eq(prompt.entry, "12", "the entry is untouched")
	assert_eq(game.parent_store.wrong_tries(), 0, "no try counted")
	assert_eq(game.parent_gate.state, ParentGate.State.PROMPT)
	assert_eq(quits, 0)
	for i in ParentStore.WRONG_TRIES_BEFORE_WAIT:
		_enter(game, WRONG)
	_tap(game, WORLD_POINT)
	prompt = _open(game, ParentGate.LEAVE)
	assert_eq(prompt.note.text, "", "a fresh prompt")
	_tap(game, prompt.forgot_rect().get_center())
	assert_eq(prompt.note.text, stub, "it works during the wait too")
	assert_true(prompt.waiting(), "the wait goes on")
	assert_eq(game.parent_store.wrong_tries(), 5)


# --- Idle and a tap outside -------------------------------------------------------

func test_the_prompt_closes_after_15_s_idle_and_a_press_on_it_restarts_the_15_s() -> void:
	var game := _game()
	var gate: ParentGate = game.parent_gate
	_open(game, ParentGate.LEAVE)
	_steps(game, 600)
	_key(game, "1")
	_steps(game, ParentCodePrompt.IDLE_STEPS - 1)
	assert_eq(gate.state, ParentGate.State.PROMPT, "25 s after opening, 15 s after the key: still open")
	_steps(game, 1)
	assert_eq(gate.state, ParentGate.State.HIDDEN, "15 s idle: closed")
	assert_eq(gate.pending_action, "")
	_open(game, ParentGate.LEAVE)
	assert_eq(_prompt(game).entry, "", "a fresh entry")
	_steps(game, ParentCodePrompt.IDLE_STEPS)
	assert_eq(gate.state, ParentGate.State.HIDDEN)


func test_a_world_tap_closes_the_prompt_calls_and_starts_a_session() -> void:
	var game := _game()
	var gate: ParentGate = game.parent_gate
	var sim: Simulation = game.simulation
	_open(game, ParentGate.SETTINGS)
	var taps := sim.taps.size()
	assert_eq(sim.session.phase, Session.SCREENSAVER)
	_touch(game, WORLD_POINT, true)
	assert_eq(gate.state, ParentGate.State.HIDDEN, "closed at once")
	_touch(game, WORLD_POINT, false)
	game.step_simulation()
	assert_eq(sim.taps.size(), taps + 1, "the tap reached the simulation")
	assert_true(sim.taps[-1]["call"], "it called")
	assert_eq(sim.session.phase, Session.SESSION, "screensaver mode: a session starts (DoD 24)")


func test_a_parent_zone_tap_closes_the_prompt_and_reveals_the_buttons() -> void:
	var game := _game()
	var gate: ParentGate = game.parent_gate
	var sim: Simulation = game.simulation
	_open(game, ParentGate.LEAVE)
	var taps := sim.taps.size()
	_tap(game, ZONE_POINT)
	assert_eq(gate.state, ParentGate.State.BUTTONS)
	assert_eq(gate.pending_action, "")
	assert_eq(sim.taps.size(), taps + 1, "the tap still reached the simulation")
	assert_false(sim.taps[-1]["call"])


# --- The right code ---------------------------------------------------------------

func test_wake_early_with_the_right_code_brings_sunrise_on_the_next_step() -> void:
	var game := _game()
	var sim: Simulation = game.simulation
	_to_bedtime(game)
	_open(game, ParentGate.WAKE_EARLY)
	_enter(game, CODE)
	assert_eq(game.parent_gate.state, ParentGate.State.HIDDEN, "the authority ends with the action")
	assert_eq(sim.session.phase, Session.BEDTIME, "applied on the next step")
	game.step_simulation()
	assert_eq(sim.session.phase, Session.SCREENSAVER, "sunrise, then screensaver mode")


func test_the_wake_early_prompt_shows_the_time_until_sunrise_live() -> void:
	var game := _game()
	var sim: Simulation = game.simulation
	_to_bedtime(game)
	var prompt := _open(game, ParentGate.WAKE_EARLY)
	var lang := ParentText.language()
	var expected := ParentText.text("time_left_bedtime", lang).format({"t": ParentText.time_left(sim.session.time_left_ms())})
	assert_eq(prompt.header.text, expected)
	assert_true(prompt.header.visible)
	var before := prompt.header.text
	_steps(game, 120)
	expected = ParentText.text("time_left_bedtime", lang).format({"t": ParentText.time_left(sim.session.time_left_ms())})
	assert_eq(prompt.header.text, expected, "live")
	assert_ne(prompt.header.text, before, "it runs down")


func test_the_leave_and_settings_prompts_show_no_time_left() -> void:
	for action in [ParentGate.LEAVE, ParentGate.SETTINGS]:
		var game := _game()
		_to_bedtime(game)
		var prompt := _open(game, action)
		_steps(game, 2)
		assert_false(prompt.header.visible, action)
		assert_eq(prompt.header.text, "", action)


func test_leave_with_the_right_code_quits_the_app() -> void:
	var game := _game()
	_open(game, ParentGate.LEAVE)
	_enter(game, CODE)
	assert_eq(quits, 1, "the app closes")
	assert_eq(game.parent_gate.state, ParentGate.State.HIDDEN)


func test_settings_with_the_right_code_opens_settings() -> void:
	var game := _game()
	_open(game, ParentGate.SETTINGS)
	_enter(game, CODE)
	assert_eq(game.parent_gate.state, ParentGate.State.SETTINGS)
	assert_eq(quits, 0)


func test_the_next_action_asks_for_the_code_again() -> void:
	var game := _game()
	_open(game, ParentGate.LEAVE)
	_enter(game, CODE)
	assert_eq(quits, 1)
	var prompt := _open(game, ParentGate.LEAVE)
	assert_eq(prompt.entry, "", "no remembered code")
	_enter(game, "12")
	assert_eq(quits, 1, "no action without the code again")
	assert_eq(game.parent_gate.state, ParentGate.State.PROMPT)


# --- Layout, pausing, test mode ------------------------------------------------------

func test_every_pad_key_is_at_least_9_mm_square_and_2_mm_apart() -> void:
	var game := _game()
	var prompt := _open(game, ParentGate.LEAVE)
	var view: ScreenView = game.simulation.view
	var mm := view.px_per_mm
	var panel := ParentLayout.prompt_rect(view)
	var rects: Array[Rect2] = []
	for key in ParentPad.KEYS:
		if key != "":
			rects.append(prompt.pad.key_rect(key))
	rects.append(prompt.forgot_rect())
	assert_eq(rects.size(), 12, "0-9, delete, forgot")
	for i in rects.size():
		var rect := rects[i]
		assert_gte(rect.size.x, 9.0 * mm, "%d: at least 9 mm wide" % i)
		assert_gte(rect.size.y, 9.0 * mm, "%d: at least 9 mm tall" % i)
		assert_true(panel.encloses(rect), "%d: on the panel" % i)
		for j in range(i + 1, rects.size()):
			assert_gte(_gap(rect, rects[j]), 2.0 * mm, "%d and %d: 2 mm apart" % [i, j])
	assert_gte(panel.position.y, TapDispatcher.parent_zone_height(view), "the parent zone stays free")
	assert_almost_eq(panel.size.x, view.screen_size.x * 2.0 / 3.0, 0.5, "two thirds of the width")


## The distance between two rects that don't overlap (0 if they do).
func _gap(a: Rect2, b: Rect2) -> float:
	var dx := maxf(0.0, maxf(a.position.x - b.end.x, b.position.x - a.end.x))
	var dy := maxf(0.0, maxf(a.position.y - b.end.y, b.position.y - a.end.y))
	return Vector2(dx, dy).length()


func test_the_simulation_keeps_stepping_while_the_prompt_is_open() -> void:
	var game := _game()
	var sim: Simulation = game.simulation
	_tap(game, START_POINT)
	_open(game, ParentGate.LEAVE)
	var tick := sim.tick
	var elapsed := sim.session.elapsed_ms
	_enter(game, "12")
	_steps(game, 60)
	assert_eq(sim.tick, tick + 60, "the prompt pauses nothing")
	assert_gt(sim.session.elapsed_ms, elapsed, "the session timer runs")


func test_test_mode_blocking_real_input_keeps_it_off_the_parent_layer() -> void:
	var game := _game(true, true)
	var sim: Simulation = game.simulation
	_tap(game, ZONE_POINT)
	assert_eq(game.parent_gate.state, ParentGate.State.HIDDEN, "no reveal")
	assert_eq(sim.taps.size(), 0, "nor a tap for the world")
