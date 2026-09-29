extends GutTest
## Settings (src/parent/parent_settings.gd, its screens
## src/parent/parent_change_code.gd and src/parent/parent_delete_save.gd)
## through the real game scene, with real touch events and stepped ticks,
## opened through the parent buttons and the code prompt with the right code:
## the header shows the time left matching the session clock (in a session,
## in bedtime; no session in screensaver mode), live (DoD 24); settings close
## after 30 s with no input, warning over the last 10 s, a touch resets the
## 30 s (DoD 24's scripted check), and the same 30 s covers the change of
## code and the delete confirmation; closing settings ends the parent's
## authority; changing the code (typed twice) replaces the old one at once,
## a mismatch keeps it, and neither is ever on disk in plain text; deleting
## the running level's save asks a second confirmation: No keeps the save,
## Yes reloads the level fresh and saves it while the session goes on (DoD
## 29), the parent store untouched; a failed delete shows an error; every
## target is at least 9 x 9 mm and 2 mm apart; nothing pauses.
##
## Every game here gets its own ParentStore (seeded with CODE) and, when a
## test needs one, its own SaveStore, on a scratch directory.

# @test-link [[req_parent_gate_and_access]]
# @test-link [[rule_time_left_shown_only_behind_code]]
# @test-link [[req_actor_roles_and_permissions]]
# @test-link [[req_persistence_and_saves]]
# @test-link [[rule_parent_code_not_stored_plaintext]]

const MAIN_SCENE := "res://src/main.tscn"
const DIR := "user://test-parent-settings/"
const STORE_PATH := DIR + "parent.json"
const SAVES_DIR := DIR + "saves/"
const LEVEL := "test"
const SEED := 20260929
const CODE := "123456"
const NEW_CODE := "908172"
## A point in the parent zone, well left of the parent buttons.
const ZONE_POINT := Vector2(300, 20)
## A world point for starting a session while nothing is open.
const START_POINT := Vector2(576, 400)
## A point on settings away from every control (bottom-left corner).
const EMPTY_POINT := Vector2(40, 630)
## 30 s and 10 s in simulation steps.
const IDLE := 1800
const WARNING := 600


func before_each() -> void:
	_clear(DIR)


func after_all() -> void:
	_clear(DIR)


## Removes `path` and everything under it.
func _clear(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for sub in DirAccess.get_directories_at(path):
		_clear(path.path_join(sub))
	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)


## A game in test mode with sessions (screensaver mode first), real input let
## through, its parent store seeded with CODE; with `saves`, a SaveStore on
## SAVES_DIR.
func _game(saves := false) -> Node:
	var store := ParentStore.new(STORE_PATH)
	store.set_code(CODE)
	var game: Node = load(MAIN_SCENE).instantiate()
	game.parent_store = store
	game.save_store = SaveStore.new(SAVES_DIR) if saves else null
	add_child_autofree(game)
	var run := {"seed": SEED, "time_scale": 0, "sessions": true, "block_real_input": false}
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


## Reveals the parent buttons and presses settings': the code prompt opens.
func _open_prompt(game: Node) -> ParentCodePrompt:
	_tap(game, ZONE_POINT)
	_press(game, game.parent_gate.button_rect(ParentGate.SETTINGS).get_center())
	assert_eq(game.parent_gate.state, ParentGate.State.PROMPT, "settings' button raises the code prompt")
	return game.parent_gate.surfaces[ParentGate.State.PROMPT]


## Types `code` on `pad`.
func _type(game: Node, pad: ParentPad, code: String) -> void:
	for digit in code:
		_press(game, pad.key_rect(digit).get_center())


## Opens settings the parent's way: the buttons, the prompt, `code`.
func _open(game: Node, code := CODE) -> ParentSettings:
	var prompt := _open_prompt(game)
	_type(game, prompt.pad, code)
	assert_eq(game.parent_gate.state, ParentGate.State.SETTINGS, "the right code opens settings")
	return game.parent_gate.surfaces[ParentGate.State.SETTINGS]


func _state(game: Node) -> ParentGate.State:
	return game.parent_gate.state


func _to_bedtime(game: Node) -> void:
	var sim: Simulation = game.simulation
	_tap(game, START_POINT)
	assert_eq(sim.session.phase, Session.SESSION)
	sim.session.jump(sim, Session.BEDTIME_MS)
	game.step_simulation()
	assert_eq(sim.session.phase, Session.BEDTIME)


func _text(key: String) -> String:
	return ParentText.text(key, ParentText.language())


func _level_label() -> String:
	return _text("level_name").format({"id": LEVEL})


## The level save on disk (asserted readable).
func _on_disk() -> Dictionary:
	var written := SaveStore.read_file(SaveStore.new(SAVES_DIR).path_for(LEVEL))
	assert_eq(written["status"], SaveStore.OK)
	return written["save"]


# --- The header: the time left --------------------------------------------------

func test_in_a_session_the_header_shows_the_session_clock_live() -> void:
	var game := _game()
	var sim: Simulation = game.simulation
	_tap(game, START_POINT)
	var settings := _open(game)
	var expected := _text("time_left_session").format({"t": ParentText.time_left(sim.session.time_left_ms())})
	assert_eq(settings.header.text, expected, "the session clock's time left")
	assert_true(settings.header.visible)
	var before := settings.header.text
	_steps(game, 120)
	expected = _text("time_left_session").format({"t": ParentText.time_left(sim.session.time_left_ms())})
	assert_eq(settings.header.text, expected, "live")
	assert_ne(settings.header.text, before, "it runs down")


func test_at_bedtime_the_header_shows_the_time_until_sunrise() -> void:
	var game := _game()
	var sim: Simulation = game.simulation
	_to_bedtime(game)
	var settings := _open(game)
	_steps(game, 60)
	var expected := _text("time_left_bedtime").format({"t": ParentText.time_left(sim.session.time_left_ms())})
	assert_eq(settings.header.text, expected)


func test_in_screensaver_mode_the_header_says_no_session() -> void:
	var game := _game()
	assert_eq(game.simulation.session.phase, Session.SCREENSAVER)
	var settings := _open(game)
	assert_eq(settings.header.text, _text("no_session"))
	_steps(game, 10)
	assert_eq(settings.header.text, _text("no_session"))


# --- Idle: 30 s, the warning over the last 10 s -----------------------------------

func test_settings_close_after_30_s_idle_and_warn_over_the_last_10_s() -> void:
	var game := _game()
	var settings := _open(game)
	assert_false(settings.warning.visible, "no warning at first")
	_steps(game, IDLE - WARNING - 1)
	assert_false(settings.warning.visible, "no warning before 20 s")
	_steps(game, 1)
	assert_true(settings.warning.visible, "the warning from 20 s")
	assert_eq(settings.warning.text, _text("closing_soon").format({"s": 10}))
	_steps(game, 60)
	assert_eq(settings.warning.text, _text("closing_soon").format({"s": 9}), "live seconds")
	_steps(game, WARNING - 61)
	assert_eq(_state(game), ParentGate.State.SETTINGS, "still open just before 30 s")
	_steps(game, 1)
	assert_eq(_state(game), ParentGate.State.HIDDEN, "closed at 30 s idle")


func test_a_touch_at_25_s_resets_the_30_s() -> void:
	# DoD 24's scripted check: open, touch at 25 s, still open at 50 s, closed at 55 s.
	var game := _game()
	var settings := _open(game)
	_steps(game, 1500)
	assert_true(settings.warning.visible)
	_press(game, EMPTY_POINT)
	assert_eq(_state(game), ParentGate.State.SETTINGS, "a touch on settings is settings'")
	assert_false(settings.warning.visible, "the touch hides the warning")
	_steps(game, 1500)
	assert_eq(_state(game), ParentGate.State.SETTINGS, "still open at 50 s")
	_steps(game, 299)
	assert_eq(_state(game), ParentGate.State.SETTINGS)
	_steps(game, 1)
	assert_eq(_state(game), ParentGate.State.HIDDEN, "closed at 55 s")


func test_the_30_s_cover_the_change_of_code_screen() -> void:
	var game := _game()
	var settings := _open(game)
	_steps(game, 600)
	_press(game, settings.change_code_rect().get_center())
	assert_eq(settings.screen, ParentSettings.Screen.CHANGE_CODE)
	_steps(game, 600)
	_press(game, settings.change_code.pad.key_rect("4").get_center())
	_steps(game, IDLE - WARNING)
	assert_true(settings.warning.visible, "the warning shows there too")
	_steps(game, WARNING - 1)
	assert_eq(_state(game), ParentGate.State.SETTINGS, "a key reset the 30 s")
	_steps(game, 1)
	assert_eq(_state(game), ParentGate.State.HIDDEN, "30 s idle: back to the game")


func test_the_30_s_cover_the_delete_confirmation() -> void:
	var game := _game()
	var settings := _open(game)
	_press(game, settings.level_rect(LEVEL).get_center())
	assert_eq(settings.screen, ParentSettings.Screen.DELETE)
	_steps(game, IDLE - 1)
	assert_eq(_state(game), ParentGate.State.SETTINGS)
	_steps(game, 1)
	assert_eq(_state(game), ParentGate.State.HIDDEN, "30 s idle: back to the game, nothing deleted")


func test_after_closing_settings_the_code_is_asked_again() -> void:
	var game := _game()
	var settings := _open(game)
	_press(game, settings.close_rect().get_center())
	assert_eq(_state(game), ParentGate.State.HIDDEN, "the close button closes settings")
	_open_prompt(game)
	assert_eq(_state(game), ParentGate.State.PROMPT, "settings again: the code first")
	_type(game, game.parent_gate.surfaces[ParentGate.State.PROMPT].pad, CODE)
	_steps(game, IDLE)
	assert_eq(_state(game), ParentGate.State.HIDDEN)
	_open_prompt(game)
	assert_eq(_state(game), ParentGate.State.PROMPT, "after the idle close too")


func test_reopened_settings_start_on_their_main_screen() -> void:
	var game := _game()
	var settings := _open(game)
	_press(game, settings.change_code_rect().get_center())
	_type(game, settings.change_code.pad, "12")
	_press(game, settings.close_rect().get_center())
	settings = _open(game)
	assert_eq(settings.screen, ParentSettings.Screen.MAIN)
	assert_eq(settings.note.text, "")
	_press(game, settings.change_code_rect().get_center())
	assert_eq(settings.change_code.entry, "", "a fresh entry")


# --- Changing the code ------------------------------------------------------------

func test_changing_the_code_typed_twice_replaces_the_old_one() -> void:
	var game := _game()
	var settings := _open(game)
	_press(game, settings.change_code_rect().get_center())
	var change := settings.change_code
	assert_eq(change.title.text, _text("new_code"))
	_type(game, change.pad, NEW_CODE)
	assert_eq(settings.screen, ParentSettings.Screen.CHANGE_CODE)
	assert_eq(change.title.text, _text("new_code_again"), "the second entry")
	assert_eq(change.entry, "")
	_type(game, change.pad, NEW_CODE)
	assert_eq(settings.screen, ParentSettings.Screen.MAIN, "back to settings")
	assert_eq(settings.note.text, _text("code_changed"), "a short confirmation")
	for label in settings.find_children("*", "Label", true, false):
		assert_false(NEW_CODE in label.text or CODE in label.text, "no code shown in '%s'" % label.text)
	_assert_not_on_disk(CODE, "the old code isn't on disk in plain text")
	_assert_not_on_disk(NEW_CODE, "the new code isn't on disk in plain text")
	_press(game, settings.close_rect().get_center())
	var prompt := _open_prompt(game)
	_type(game, prompt.pad, CODE)
	assert_eq(_state(game), ParentGate.State.PROMPT, "the old code is refused")
	assert_eq(game.parent_store.wrong_tries(), 1)
	_type(game, prompt.pad, NEW_CODE)
	assert_eq(_state(game), ParentGate.State.SETTINGS, "the new code opens settings")
	assert_eq(ParentStore.new(STORE_PATH).try_code(NEW_CODE, 0), ParentStore.Result.OK, "on disk at once")


func test_a_mismatch_shakes_clears_starts_again_and_keeps_the_old_code() -> void:
	var game := _game()
	var settings := _open(game)
	_press(game, settings.change_code_rect().get_center())
	var change := settings.change_code
	_type(game, change.pad, NEW_CODE)
	_type(game, change.pad, "11111")
	assert_eq(change.filled_slots(), 5, "dots, never digits")
	_type(game, change.pad, "1")
	assert_true(change.shaking(), "a mismatch shakes")
	assert_eq(change.entry, "", "and clears")
	assert_eq(change.title.text, _text("new_code"), "from the first entry again")
	assert_eq(change.message.text, _text("codes_differ"))
	assert_eq(settings.screen, ParentSettings.Screen.CHANGE_CODE)
	_press(game, change.back_rect().get_center())
	assert_eq(settings.screen, ParentSettings.Screen.MAIN, "back to settings")
	assert_eq(settings.note.text, "")
	_press(game, settings.close_rect().get_center())
	_open(game, CODE)
	assert_eq(ParentStore.new(STORE_PATH).try_code(NEW_CODE, 0), ParentStore.Result.WRONG, "the old code stays")


func test_the_delete_key_takes_back_a_digit_of_the_new_code() -> void:
	var game := _game()
	var settings := _open(game)
	_press(game, settings.change_code_rect().get_center())
	var change := settings.change_code
	_type(game, change.pad, "129")
	_press(game, change.pad.key_rect(ParentPad.DELETE).get_center())
	assert_eq(change.entry, "12")


## Asserts the store file holds `code` nowhere in plain text, deterministically:
## the salt and hash are lowercase hex of their lengths (16 and 32 bytes), no
## value is the code, and the file's text with the salt and hash taken out
## doesn't hold it (a 6-digit run can occur by chance inside random hex).
func _assert_not_on_disk(code: String, why: String) -> void:
	var raw := FileAccess.get_file_as_string(STORE_PATH)
	var data := JSON.parse_string(raw) as Dictionary
	var salt: String = data["code"]["salt"]
	var digest: String = data["code"]["hash"]
	var hex := RegEx.create_from_string("^[0-9a-f]+$")
	assert_eq(salt.length(), ParentStore.SALT_BYTES * 2, "%s: the salt is %d bytes" % [why, ParentStore.SALT_BYTES])
	assert_eq(digest.length(), 64, "%s: the hash is a SHA-256" % why)
	for value in [salt, digest]:
		assert_not_null(hex.search(value), "%s: '%s' is lowercase hex" % [why, value])
	for key in data:
		assert_ne(str(data[key]), code, "%s: '%s' isn't the code" % [why, key])
	var rest := raw.replace(salt, "").replace(digest, "")
	assert_false(rest.contains(code), "%s: %s" % [why, rest])


# --- Deleting a level save ----------------------------------------------------------

func test_settings_list_the_running_level() -> void:
	var game := _game()
	var settings := _open(game)
	assert_eq(settings.levels(), PackedStringArray([LEVEL]), "v1: the running level")
	assert_eq(settings.level_button(LEVEL).text, _level_label())


func test_no_keeps_the_save() -> void:
	var game := _game(true)
	_tap(game, START_POINT)
	assert_eq(game.save_now(), "")
	var path: String = game.save_store.path_for(LEVEL)
	var before := FileAccess.get_file_as_bytes(path)
	var sim: Simulation = game.simulation
	var settings := _open(game)
	_press(game, settings.level_rect(LEVEL).get_center())
	assert_eq(settings.screen, ParentSettings.Screen.DELETE, "a second confirmation")
	assert_eq(settings.delete_save.text.text, _text("delete_confirm").format({"level": _level_label()}))
	_press(game, settings.delete_save.no_rect().get_center())
	assert_eq(settings.screen, ParentSettings.Screen.MAIN, "back to settings")
	assert_eq(_state(game), ParentGate.State.SETTINGS)
	assert_eq(game.simulation, sim, "nothing reloaded")
	assert_eq(FileAccess.get_file_as_bytes(path), before, "the save is as it was")


func test_yes_deletes_the_save_reloads_fresh_and_the_session_goes_on() -> void:
	# DoD 29.
	var game := _game(true)
	_tap(game, START_POINT)
	var old: Simulation = game.simulation
	old.frontier.celebration_done = true
	_steps(game, 60)
	assert_eq(game.save_now(), "")
	assert_true(_on_disk().get("celebration_done", false), "some progress saved")
	var settings := _open(game)
	var parent: ParentStore = game.parent_store
	assert_eq(parent.try_code("000000", game.now_wall_ms()), ParentStore.Result.WRONG)
	var parent_file := FileAccess.get_file_as_bytes(STORE_PATH)
	var phase: String = old.session.phase
	var left: int = old.session.time_left_ms()
	_press(game, settings.level_rect(LEVEL).get_center())
	_press(game, settings.delete_save.yes_rect().get_center())
	var sim: Simulation = game.simulation
	assert_ne(sim, old, "the level reloaded fresh")
	assert_false(sim.frontier.celebration_done)
	assert_eq(sim.session.phase, phase, "the session goes on")
	assert_eq(sim.session.time_left_ms(), left, "the same time left")
	assert_false(_on_disk().get("celebration_done", false), "the save on disk is fresh")
	assert_eq(_on_disk()["session"]["phase"], phase)
	assert_eq(_state(game), ParentGate.State.SETTINGS, "back to settings")
	assert_eq(settings.screen, ParentSettings.Screen.MAIN)
	assert_eq(settings.note.text, _text("save_deleted").format({"level": _level_label()}))
	assert_eq(FileAccess.get_file_as_bytes(STORE_PATH), parent_file, "the parent store is untouched")
	var reread := ParentStore.new(STORE_PATH)
	assert_eq(reread.wrong_tries(), 1, "the wrong tries stay")
	assert_true(reread.has_code(), "the code stays")
	_steps(game, 60)
	var expected := _text("time_left_session").format({"t": ParentText.time_left(sim.session.time_left_ms())})
	assert_eq(settings.header.text, expected, "the header follows the reloaded level's session")


func test_a_failed_delete_shows_an_error_and_changes_nothing() -> void:
	var game := _game(true)
	var path: String = game.save_store.path_for(LEVEL)
	# A folder with a file in it where the save goes: the store can't delete it.
	DirAccess.make_dir_recursive_absolute(path)
	var inside := FileAccess.open(path.path_join("keep"), FileAccess.WRITE)
	inside.store_string("x")
	inside.close()
	var sim: Simulation = game.simulation
	var settings := _open(game)
	_press(game, settings.level_rect(LEVEL).get_center())
	_press(game, settings.delete_save.yes_rect().get_center())
	assert_eq(settings.screen, ParentSettings.Screen.MAIN)
	assert_eq(settings.note.text, _text("delete_failed"), "an error line")
	assert_eq(game.simulation, sim, "nothing reloaded")
	assert_true(FileAccess.file_exists(path.path_join("keep")))


# --- Layout and pausing ---------------------------------------------------------------

func test_every_settings_target_is_at_least_9_mm_square_and_2_mm_apart() -> void:
	var game := _game()
	var settings := _open(game)
	var view: ScreenView = game.simulation.view
	var main: Array[Rect2] = [settings.close_rect(), settings.change_code_rect(), settings.level_rect(LEVEL)]
	_check_targets(main, view, "main")
	_press(game, settings.change_code_rect().get_center())
	var change: Array[Rect2] = [settings.close_rect(), settings.change_code.back_rect()]
	for key in ParentPad.KEYS:
		if key != "":
			change.append(settings.change_code.pad.key_rect(key))
	_check_targets(change, view, "change of code")
	_press(game, settings.change_code.back_rect().get_center())
	_press(game, settings.level_rect(LEVEL).get_center())
	var confirm: Array[Rect2] = [settings.close_rect(), settings.delete_save.yes_rect(), settings.delete_save.no_rect()]
	_check_targets(confirm, view, "delete confirmation")


## Each rect of `rects` is at least 9 x 9 mm, on the screen, and 2 mm from the others.
func _check_targets(rects: Array[Rect2], view: ScreenView, screen: String) -> void:
	var mm := view.px_per_mm
	var whole := Rect2(Vector2.ZERO, view.screen_size)
	for i in rects.size():
		var rect := rects[i]
		assert_gte(rect.size.x, 9.0 * mm, "%s %d: at least 9 mm wide" % [screen, i])
		assert_gte(rect.size.y, 9.0 * mm, "%s %d: at least 9 mm tall" % [screen, i])
		assert_true(whole.encloses(rect), "%s %d: on the screen" % [screen, i])
		assert_false(rect.has_point(EMPTY_POINT), "%s %d: EMPTY_POINT is empty" % [screen, i])
		for j in range(i + 1, rects.size()):
			assert_gte(_gap(rect, rects[j]), 2.0 * mm, "%s %d and %d: 2 mm apart" % [screen, i, j])


## The distance between two rects that don't overlap (0 if they do).
func _gap(a: Rect2, b: Rect2) -> float:
	var dx := maxf(0.0, maxf(a.position.x - b.end.x, b.position.x - a.end.x))
	var dy := maxf(0.0, maxf(a.position.y - b.end.y, b.position.y - a.end.y))
	return Vector2(dx, dy).length()


func test_settings_fill_the_screen_and_take_every_press() -> void:
	var game := _game()
	var sim: Simulation = game.simulation
	_open(game)
	var taps := sim.taps.size()
	for at in [EMPTY_POINT, ZONE_POINT, START_POINT]:
		_tap(game, at)
		assert_eq(_state(game), ParentGate.State.SETTINGS, "%s: settings' own" % at)
	assert_eq(sim.taps.size(), taps, "no tap reached the world")
	assert_eq(sim.session.phase, Session.SCREENSAVER, "no session started")


func test_the_simulation_keeps_stepping_with_settings_open() -> void:
	var game := _game()
	var sim: Simulation = game.simulation
	_tap(game, START_POINT)
	var settings := _open(game)
	var tick := sim.tick
	var elapsed := sim.session.elapsed_ms
	_press(game, settings.change_code_rect().get_center())
	_steps(game, 60)
	assert_eq(sim.tick, tick + 60, "settings pause nothing")
	assert_gt(sim.session.elapsed_ms, elapsed, "the session timer runs")
