extends GutTest
## Setup (src/parent/parent_setup.gd, the parent layer's SETUP state, with the
## code typed twice on src/parent/parent_change_code.gd) through the real game
## scene, with real touch events and stepped ticks: on first launch (a parent
## store with no code) setup shows before anything else and fills the screen,
## so the world takes no tap (no call, no session start) and the parent zone
## reveals nothing; its four steps (welcome, the code typed twice, a forgotten
## code, screen pinning) are walked with Next; the code is saved only when
## setup finishes, then setup closes to the game and never shows again; a
## mismatch keeps the code step with nothing saved; an interruption before the
## end (the app killed, the app going to the background) drops the entered
## code and restarts setup from step 1 (DoD 23's scripted check); the texts
## are French on a French phone; every target is at least 9 x 9 mm and 2 mm
## apart; the simulation keeps stepping.
##
## Every game here gets its own ParentStore on a scratch directory, with no
## code unless the test says otherwise.

# @test-link [[req_parent_gate_and_access]]
# @test-link [[req_actor_roles_and_permissions]]
# @test-link [[rule_parent_code_not_stored_plaintext]]

const MAIN_SCENE := "res://src/main.tscn"
const DIR := "user://test-parent-setup/"
const STORE_PATH := DIR + "parent.json"
const SEED := 20260929
const CODE := "246801"
## A point in the parent zone, well left of the parent buttons' slots.
const ZONE_POINT := Vector2(300, 20)
## A world point: below the parent zone, between the edge strips.
const WORLD_POINT := Vector2(576, 400)


func before_each() -> void:
	_clear(DIR)


func after_each() -> void:
	ParentText.language_override = ""


func after_all() -> void:
	_clear(DIR)


## Removes `path` and everything under it.
func _clear(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)


## A game on the store at STORE_PATH (as a launch: whatever the file holds),
## in test mode with sessions (screensaver mode first), real input let
## through unless `block_real_input`.
func _game(block_real_input := false) -> Node:
	var game: Node = load(MAIN_SCENE).instantiate()
	game.parent_store = ParentStore.new(STORE_PATH)
	add_child_autofree(game)
	var run := {"seed": SEED, "time_scale": 0, "sessions": true, "block_real_input": block_real_input}
	assert_eq(game.enable_test_mode(run), PackedStringArray())
	game.quit_app = func() -> void: pass
	return game


func _touch(game: Node, at: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.pressed = pressed
	event.position = at
	game._unhandled_input(event)


## A press and its release at `at` (no step).
func _press(game: Node, at: Vector2) -> void:
	_touch(game, at, true)
	_touch(game, at, false)


## A tap at `at`, then one step so the simulation reads it.
func _tap(game: Node, at: Vector2) -> void:
	_press(game, at)
	game.step_simulation()


func _steps(game: Node, count: int) -> void:
	for i in count:
		game.step_simulation()


func _setup(game: Node) -> ParentSetup:
	return game.parent_gate.surfaces[ParentGate.State.SETUP]


func _state(game: Node) -> ParentGate.State:
	return game.parent_gate.state


## Types `code` on setup's pad.
func _type(game: Node, code: String) -> void:
	for digit in code:
		_press(game, _setup(game).code_entry.pad.key_rect(digit).get_center())


## Presses Next (the last step's finish).
func _next(game: Node) -> void:
	_press(game, _setup(game).next_rect().get_center())


## From step 1 to step 3: Next, then CODE typed twice.
func _to_forgotten_step(game: Node) -> void:
	_next(game)
	_type(game, CODE)
	_type(game, CODE)
	assert_eq(_setup(game).current, ParentSetup.Step.FORGOTTEN, "a matching code moves on")


func _text(key: String) -> String:
	return ParentText.text(key, ParentText.language())


# --- First launch --------------------------------------------------------------------

func test_first_launch_shows_setup_step_1_before_anything_else() -> void:
	var game := _game()
	assert_eq(_state(game), ParentGate.State.SETUP, "setup is open before the first tap")
	var setup := _setup(game)
	assert_true(setup.visible)
	assert_eq(setup.current, ParentSetup.Step.WELCOME)
	assert_eq(setup.counter.text, _text("setup_step").format({"n": 1, "total": 4}))
	assert_eq(setup.heading.text, _text("setup_welcome_title"))
	assert_eq(setup.body.text, _text("setup_welcome"))
	assert_true(setup.next.visible)
	assert_eq(setup.next.text, _text("next"))
	assert_false(setup.back.visible, "no Back on the first step")
	_steps(game, 1)
	assert_eq(setup.size, game.simulation.view.screen_size, "it fills the screen")
	assert_true(game.parent_gate.covers_world())
	assert_false(game.parent_store.has_code())


func test_a_game_whose_store_has_a_code_shows_no_setup() -> void:
	ParentStore.new(STORE_PATH).set_code(CODE)
	var game := _game()
	assert_eq(_state(game), ParentGate.State.HIDDEN)
	assert_false(_setup(game).visible)


func test_the_world_and_the_parent_zone_take_no_tap_during_setup() -> void:
	var game := _game()
	var sim: Simulation = game.simulation
	var taps := sim.taps.size()
	for at in [WORLD_POINT, ZONE_POINT, Vector2(20, 400), Vector2(1130, 400)]:
		_tap(game, at)
		assert_eq(_state(game), ParentGate.State.SETUP, "%s: setup's own" % at)
	assert_eq(sim.taps.size(), taps, "no tap reached the world: no call")
	assert_eq(sim.session.phase, Session.SCREENSAVER, "no session started")
	for action in game.parent_gate.buttons:
		assert_false(game.parent_gate.buttons[action].visible, "no parent button: %s" % action)
	assert_false(game.parent_gate.reveal(), "the buttons reveal only after setup")


func test_the_simulation_keeps_stepping_during_setup() -> void:
	var game := _game()
	var sim: Simulation = game.simulation
	var tick := sim.tick
	_steps(game, 120)
	assert_eq(sim.tick, tick + 120, "setup pauses nothing")
	assert_eq(_state(game), ParentGate.State.SETUP, "no idle timeout on setup")


# --- The four steps ---------------------------------------------------------------------

func test_walking_the_four_steps_saves_the_code_and_closes_setup_for_good() -> void:
	var game := _game()
	var setup := _setup(game)
	_next(game)
	assert_eq(setup.current, ParentSetup.Step.CODE)
	assert_eq(setup.counter.text, _text("setup_step").format({"n": 2, "total": 4}))
	assert_true(setup.code_entry.visible)
	assert_false(setup.next.visible, "a matching code moves on by itself")
	assert_eq(setup.code_entry.title.text, _text("setup_code"))
	_type(game, CODE)
	assert_eq(setup.code_entry.title.text, _text("setup_code_again"), "the second entry")
	assert_false(game.parent_store.has_code(), "nothing saved after the first entry")
	_type(game, CODE)
	assert_eq(setup.current, ParentSetup.Step.FORGOTTEN)
	assert_false(setup.code_entry.visible)
	assert_eq(setup.heading.text, _text("setup_forgotten_title"))
	assert_eq(setup.body.text, _text("setup_forgotten"))
	assert_false(game.parent_store.has_code(), "the code isn't saved before setup finishes")
	assert_false(FileAccess.file_exists(STORE_PATH), "nothing on disk yet")
	_next(game)
	assert_eq(setup.current, ParentSetup.Step.PINNING)
	assert_eq(setup.counter.text, _text("setup_step").format({"n": 4, "total": 4}))
	assert_eq(setup.heading.text, _text("setup_pinning_title"))
	assert_eq(setup.body.text, _text("setup_pinning"))
	assert_eq(setup.next.text, _text("setup_done"), "the last step's button finishes")
	assert_false(game.parent_store.has_code())
	_next(game)
	assert_eq(_state(game), ParentGate.State.HIDDEN, "setup closes to the game")
	assert_true(game.parent_store.has_code(), "saved when setup finishes")
	assert_eq(ParentStore.new(STORE_PATH).try_code(CODE, 0), ParentStore.Result.OK, "on disk")
	var file := JSON.parse_string(FileAccess.get_file_as_string(STORE_PATH)) as Dictionary
	assert_false(CODE in [file["code"]["salt"], file["code"]["hash"]], "a salted hash only")
	# The parent buttons can now be revealed; a new launch shows no setup.
	_tap(game, ZONE_POINT)
	assert_eq(_state(game), ParentGate.State.BUTTONS, "the parent zone reveals the buttons")
	var again := _game()
	assert_eq(_state(again), ParentGate.State.HIDDEN, "setup never shows again")


func test_back_goes_to_the_previous_step() -> void:
	var game := _game()
	var setup := _setup(game)
	_next(game)
	_press(game, setup.code_entry.back_rect().get_center())
	assert_eq(setup.current, ParentSetup.Step.WELCOME, "Back from the code step")
	_to_forgotten_step(game)
	_next(game)
	assert_true(setup.back.visible)
	_press(game, setup.back_rect().get_center())
	assert_eq(setup.current, ParentSetup.Step.FORGOTTEN, "Back from pinning")
	_press(game, setup.back_rect().get_center())
	assert_eq(setup.current, ParentSetup.Step.CODE, "back to the code step")
	assert_eq(setup.code_entry.entry, "", "a fresh entry")
	assert_eq(setup.code_entry.title.text, _text("setup_code"), "the code is chosen again")
	assert_false(game.parent_store.has_code())


func test_a_mismatch_shakes_clears_and_stays_on_the_code_step() -> void:
	var game := _game()
	var setup := _setup(game)
	_next(game)
	_type(game, CODE)
	_type(game, "13579")
	assert_eq(setup.code_entry.filled_slots(), 5, "dots, never digits")
	_type(game, "1")
	assert_eq(setup.current, ParentSetup.Step.CODE, "still the code step")
	assert_true(setup.code_entry.shaking(), "a mismatch shakes")
	assert_eq(setup.code_entry.entry, "", "and clears")
	assert_eq(setup.code_entry.title.text, _text("setup_code"), "the step's entry starts again")
	assert_eq(setup.code_entry.message.text, _text("codes_differ"))
	assert_false(game.parent_store.has_code(), "nothing saved")
	assert_false(FileAccess.file_exists(STORE_PATH))
	_steps(game, ParentCodeSlots.SHAKE_STEPS)
	assert_false(setup.code_entry.shaking(), "the shake runs with the steps")


# --- Interruptions ----------------------------------------------------------------------

func test_killed_at_step_3_setup_restarts_from_step_1_with_no_code() -> void:
	# DoD 23's scripted check: the app killed mid-setup is a new game on the same store.
	var game := _game()
	_to_forgotten_step(game)
	var again := _game()
	assert_false(again.parent_store.has_code(), "no code kept")
	assert_false(FileAccess.file_exists(STORE_PATH), "nothing on disk")
	assert_eq(_state(again), ParentGate.State.SETUP)
	assert_eq(_setup(again).current, ParentSetup.Step.WELCOME, "from step 1")


func test_going_to_the_background_at_step_3_restarts_setup_from_step_1() -> void:
	var game := _game()
	var setup := _setup(game)
	_to_forgotten_step(game)
	game.propagate_notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	assert_eq(_state(game), ParentGate.State.SETUP)
	assert_eq(setup.current, ParentSetup.Step.WELCOME, "from step 1")
	assert_false(game.parent_store.has_code())
	_next(game)
	assert_eq(setup.code_entry.title.text, _text("setup_code"), "the entered code is dropped")
	_type(game, CODE)
	game.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_eq(setup.current, ParentSetup.Step.WELCOME, "losing the focus on desktop too")
	_next(game)
	assert_eq(setup.code_entry.entry, "")
	assert_eq(setup.code_entry.title.text, _text("setup_code"), "a half-typed code is dropped too")
	assert_false(FileAccess.file_exists(STORE_PATH))


func test_which_notifications_interrupt_setup() -> void:
	assert_true(ParentSetup.interrupts(Node.NOTIFICATION_APPLICATION_PAUSED, true))
	assert_true(ParentSetup.interrupts(Node.NOTIFICATION_APPLICATION_PAUSED, false))
	assert_true(ParentSetup.interrupts(Node.NOTIFICATION_APPLICATION_FOCUS_OUT, false), "desktop")
	assert_false(ParentSetup.interrupts(Node.NOTIFICATION_APPLICATION_FOCUS_OUT, true), "a phone: paused only")
	assert_false(ParentSetup.interrupts(Node.NOTIFICATION_APPLICATION_RESUMED, false))


func test_a_notification_after_setup_changes_nothing() -> void:
	var game := _game()
	_to_forgotten_step(game)
	_next(game)
	_next(game)
	game.propagate_notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	assert_eq(_state(game), ParentGate.State.HIDDEN, "setup stays closed")
	assert_true(game.parent_store.has_code())


# --- Language, targets, test mode ----------------------------------------------------------

func test_the_texts_are_french_on_a_french_phone() -> void:
	ParentText.language_override = "fr"
	var game := _game()
	var setup := _setup(game)
	assert_eq(setup.heading.text, ParentText.text("setup_welcome_title", "fr"))
	assert_eq(setup.body.text, ParentText.text("setup_welcome", "fr"))
	assert_eq(setup.next.text, ParentText.text("next", "fr"))
	_next(game)
	assert_eq(setup.code_entry.title.text, ParentText.text("setup_code", "fr"))
	assert_eq(setup.code_entry.back.text, ParentText.text("back", "fr"))
	_type(game, CODE)
	_type(game, CODE)
	assert_eq(setup.body.text, ParentText.text("setup_forgotten", "fr"))
	_next(game)
	assert_eq(setup.body.text, ParentText.text("setup_pinning", "fr"))
	assert_eq(setup.next.text, ParentText.text("setup_done", "fr"))
	assert_eq(setup.back.text, ParentText.text("back", "fr"))
	assert_ne(ParentText.text("setup_pinning", "fr"), ParentText.text("setup_pinning", "en"))


func test_every_setup_target_is_at_least_9_mm_square_and_2_mm_apart() -> void:
	var game := _game()
	var setup := _setup(game)
	var view: ScreenView = game.simulation.view
	_check_targets([setup.next_rect()], view, "welcome")
	_check_fits(setup, "welcome")
	_next(game)
	var code: Array[Rect2] = [setup.code_entry.back_rect()]
	for key in ParentPad.KEYS:
		if key != "":
			code.append(setup.code_entry.pad.key_rect(key))
	_check_targets(code, view, "code")
	_type(game, CODE)
	_type(game, CODE)
	_check_targets([setup.back_rect(), setup.next_rect()], view, "forgotten")
	_check_fits(setup, "forgotten")
	_next(game)
	_check_targets([setup.back_rect(), setup.next_rect()], view, "pinning")
	_check_fits(setup, "pinning")


## Each rect of `rects` is at least 9 x 9 mm, on the screen, and 2 mm from the others.
func _check_targets(rects: Array[Rect2], view: ScreenView, step: String) -> void:
	var mm := view.px_per_mm
	var whole := Rect2(Vector2.ZERO, view.screen_size)
	for i in rects.size():
		var rect := rects[i]
		assert_gte(rect.size.x, 9.0 * mm, "%s %d: at least 9 mm wide" % [step, i])
		assert_gte(rect.size.y, 9.0 * mm, "%s %d: at least 9 mm tall" % [step, i])
		assert_true(whole.encloses(rect), "%s %d: on the screen" % [step, i])
		for j in range(i + 1, rects.size()):
			assert_gte(_gap(rect, rects[j]), 2.0 * mm, "%s %d and %d: 2 mm apart" % [step, i, j])


## The step's text shows whole (no line cut off) and stays above its buttons.
func _check_fits(setup: ParentSetup, step: String) -> void:
	assert_eq(setup.body.get_visible_line_count(), setup.body.get_line_count(), "%s: the text shows whole" % step)
	assert_lte(setup.body.position.y + setup.body.size.y, setup.next_rect().position.y, "%s: above the buttons" % step)


## The distance between two rects that don't overlap (0 if they do).
func _gap(a: Rect2, b: Rect2) -> float:
	var dx := maxf(0.0, maxf(a.position.x - b.end.x, b.position.x - a.end.x))
	var dy := maxf(0.0, maxf(a.position.y - b.end.y, b.position.y - a.end.y))
	return Vector2(dx, dy).length()


func test_a_test_mode_run_that_blocks_real_input_shows_no_setup() -> void:
	# Nobody could answer it (proposed); no code is saved, so the next launch shows it.
	var game := _game(true)
	assert_eq(_state(game), ParentGate.State.HIDDEN)
	assert_false(game.parent_store.has_code())
	assert_false(game.parent_gate.covers_world())
