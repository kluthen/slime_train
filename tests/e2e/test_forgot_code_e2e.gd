extends GutTest
## "Forgot the code?" (master spec §5.8 "Forgotten code", O73, chunk 20)
## through the real game scene, with real touch events and stepped ticks, on
## a fake platform (PhonePlatform) whose screen lock is set or not and whose
## Android prompt the test answers itself (credential_finished). With no
## screen lock the prompt explains that clearing the app's data is the only
## way and nothing else happens. With one, Android's prompt is asked once;
## while it is pending the prompt neither times out nor closes when the app
## loses the focus or pauses. Cancelled or failed: nothing changed, no try
## counted. Passed: the new code typed twice (ParentNewCode) replaces the old
## one at once, the wrong tries and the wait cleared, and the code prompt for
## the action started asks for it; Back or 30 s idle return to it with
## nothing changed. It works during the wait and on a locked store (both
## files rewritten), and the new code is never on disk in plain text.
##
## Every game here gets its own ParentStore on a scratch directory, seeded
## with CODE unless the test builds the store itself.

# @test-link [[req_parent_gate_and_access]]
# @test-link [[req_denial_and_stepup_behavior]]

const MAIN_SCENE := "res://src/main.tscn"
const DIR := "user://test-forgot-code/"
const STORE_PATH := DIR + "parent.json"
const BACKUP_PATH := STORE_PATH + ParentStore.BACKUP_SUFFIX
const SEED := 20260930
const CODE := "135790"
const NEW_CODE := "246813"
const WRONG := "975310"
## A point in the parent zone, well left of the parent buttons.
const ZONE_POINT := Vector2(300, 20)


## Stands in for the phone: its screen lock is set or not (`secure`), every
## confirm_credential() is recorded ([title, subtitle]) and left for the test
## to answer (credential_finished), stop_pinning() is counted.
class FakePlatform:
	extends PhonePlatform
	var secure := true
	var asked: Array = []
	var stops := 0

	func is_device_secure() -> bool:
		return secure

	func confirm_credential(title: String, subtitle: String) -> void:
		asked.append([title, subtitle])

	func stop_pinning() -> void:
		stops += 1


## Counts the calls to the game's quit_app.
var quits := 0


func before_each() -> void:
	quits = 0
	_clear(DIR)


func after_each() -> void:
	ParentText.language_override = ""


func after_all() -> void:
	_clear(DIR)


func _clear(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)


## A game on `fake` in test mode with sessions and real input let through,
## its quit counted, on `store` (by default a fresh one at STORE_PATH seeded
## with CODE).
func _game(fake: FakePlatform, store: ParentStore = null) -> Node:
	if store == null:
		store = ParentStore.new(STORE_PATH)
		store.set_code(CODE)
	var game: Node = load(MAIN_SCENE).instantiate()
	game.platform = fake
	game.parent_store = store
	add_child_autofree(game)
	var run := {"seed": SEED, "time_scale": 0, "sessions": true, "block_real_input": false}
	assert_eq(game.enable_test_mode(run), PackedStringArray())
	game.quit_app = func() -> void: quits += 1
	return game


func _touch(game: Node, at: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.pressed = pressed
	event.position = at
	game._unhandled_input(event)


## A press and its release at `at`.
func _press(game: Node, at: Vector2) -> void:
	_touch(game, at, true)
	_touch(game, at, false)


func _steps(game: Node, count: int) -> void:
	for i in count:
		game.step_simulation()


func _state(game: Node) -> ParentGate.State:
	return game.parent_gate.state


func _prompt(game: Node) -> ParentCodePrompt:
	return game.parent_gate.surfaces[ParentGate.State.PROMPT]


func _new_code(game: Node) -> ParentNewCode:
	return game.parent_gate.surfaces[ParentGate.State.NEW_CODE]


## Reveals the parent buttons and presses `action`'s: the code prompt opens.
func _open(game: Node, action: String) -> ParentCodePrompt:
	_press(game, ZONE_POINT)
	game.step_simulation()
	_press(game, game.parent_gate.button_rect(action).get_center())
	assert_eq(_state(game), ParentGate.State.PROMPT, "%s raises the code prompt" % action)
	return _prompt(game)


## Types `code` on the code prompt's pad.
func _enter(game: Node, code: String) -> void:
	for digit in code:
		_press(game, _prompt(game).pad.key_rect(digit).get_center())


## Types `code` on the new-code screen's pad.
func _enter_new(game: Node, code: String) -> void:
	for digit in code:
		_press(game, _new_code(game).code_entry.pad.key_rect(digit).get_center())


func _tap_forgot(game: Node) -> void:
	_press(game, _prompt(game).forgot_rect().get_center())


## Taps "Forgot the code?", checks Android's prompt was asked, answers it
## `ok`.
func _pass_the_lock(game: Node, fake: FakePlatform, ok := true) -> void:
	var asked := fake.asked.size()
	_tap_forgot(game)
	assert_eq(fake.asked.size(), asked + 1, "Android's prompt is asked")
	fake.credential_finished.emit(ok)


func _text(key: String) -> String:
	return ParentText.text(key, ParentText.language())


# --- No screen lock ---------------------------------------------------------------------------

func test_with_no_screen_lock_it_explains_clearing_the_data_and_nothing_else_happens() -> void:
	var fake := FakePlatform.new()
	fake.secure = false
	var game := _game(fake)
	var prompt := _open(game, ParentGate.LEAVE)
	_enter(game, WRONG)
	_enter(game, "12")
	var before := FileAccess.get_file_as_bytes(STORE_PATH)
	_tap_forgot(game)
	assert_eq(prompt.note.text, _text("forgot_no_lock"))
	assert_true("erases all progress" in ParentText.text("forgot_no_lock", "en"), "and that it erases all progress")
	assert_true(prompt.note.visible)
	assert_false(prompt.title.visible, "the explanation takes the column")
	assert_eq(fake.asked.size(), 0, "no Android prompt")
	assert_eq(_state(game), ParentGate.State.PROMPT, "still the code prompt")
	assert_eq(prompt.entry, "12", "the entry is untouched")
	assert_eq(game.parent_store.wrong_tries(), 1, "no try counted")
	assert_eq(FileAccess.get_file_as_bytes(STORE_PATH), before, "the store is untouched")
	_press(game, prompt.pad.key_rect("3").get_center())
	assert_eq(prompt.note.text, "", "a key brings the entry back")
	assert_true(prompt.title.visible)
	assert_eq(prompt.entry, "123")
	assert_eq(quits, 0)


# --- Android's prompt pending -------------------------------------------------------------------

func test_with_a_screen_lock_android_is_asked_once_and_a_second_tap_does_nothing() -> void:
	var fake := FakePlatform.new()
	var game := _game(fake)
	var prompt := _open(game, ParentGate.SETTINGS)
	_tap_forgot(game)
	assert_eq(fake.asked, [[_text("forgot_confirm_title"), _text("forgot_confirm_subtitle")]])
	assert_true(prompt.awaiting_credential)
	assert_eq(prompt.note.text, "", "no explanation: the phone has a lock")
	_tap_forgot(game)
	assert_eq(fake.asked.size(), 1, "a second tap while pending does nothing")
	assert_eq(game.parent_store.wrong_tries(), 0)


func test_while_android_asks_the_prompt_neither_times_out_nor_closes_on_focus_loss_or_pause() -> void:
	var fake := FakePlatform.new()
	var game := _game(fake)
	_open(game, ParentGate.LEAVE)
	_tap_forgot(game)
	_steps(game, ParentCodePrompt.IDLE_STEPS * 2)
	assert_eq(_state(game), ParentGate.State.PROMPT, "no idle timeout while Android's prompt shows")
	for what in [Node.NOTIFICATION_APPLICATION_FOCUS_OUT, Node.NOTIFICATION_APPLICATION_PAUSED]:
		game.propagate_notification(what)
		_steps(game, 10)
	assert_eq(_state(game), ParentGate.State.PROMPT, "focus lost and paused: still open")
	for what in [Node.NOTIFICATION_APPLICATION_RESUMED, Node.NOTIFICATION_APPLICATION_FOCUS_IN]:
		game.propagate_notification(what)
	assert_eq(game.parent_gate.pending_action, ParentGate.LEAVE, "the pending action is kept")
	fake.credential_finished.emit(true)
	assert_eq(_state(game), ParentGate.State.NEW_CODE, "the answer still arrives: the new-code screen")
	assert_eq(game.parent_gate.pending_action, ParentGate.LEAVE)


func test_cancelling_or_failing_android_changes_nothing_and_counts_no_try() -> void:
	var fake := FakePlatform.new()
	var game := _game(fake)
	var prompt := _open(game, ParentGate.LEAVE)
	_enter(game, WRONG)
	_enter(game, WRONG)
	_enter(game, "4")
	var before := FileAccess.get_file_as_bytes(STORE_PATH)
	_pass_the_lock(game, fake, false)
	assert_eq(_state(game), ParentGate.State.PROMPT, "back at the code prompt")
	assert_false(prompt.awaiting_credential)
	assert_eq(prompt.entry, "4", "as it was")
	assert_eq(game.parent_store.wrong_tries(), 2, "no wrong try counted")
	assert_eq(FileAccess.get_file_as_bytes(STORE_PATH), before, "the store is untouched")
	_steps(game, ParentCodePrompt.IDLE_STEPS - 1)
	assert_eq(_state(game), ParentGate.State.PROMPT, "the idle steps start again from the answer")
	_steps(game, 1)
	assert_eq(_state(game), ParentGate.State.HIDDEN, "then the prompt times out as usual")
	_open(game, ParentGate.LEAVE)
	_enter(game, CODE)
	assert_eq(quits, 1, "the old code still works")


func test_an_answer_for_a_prompt_that_closed_meanwhile_is_dropped() -> void:
	var fake := FakePlatform.new()
	var game := _game(fake)
	_open(game, ParentGate.LEAVE)
	_tap_forgot(game)
	_press(game, ZONE_POINT)
	assert_ne(_state(game), ParentGate.State.PROMPT, "a tap outside closed it")
	fake.credential_finished.emit(true)
	assert_ne(_state(game), ParentGate.State.NEW_CODE, "no new-code screen out of nowhere")


# --- The new code ---------------------------------------------------------------------------

func test_passing_the_lock_sets_a_new_code_typed_twice_then_the_prompt_asks_for_it() -> void:
	var fake := FakePlatform.new()
	var game := _game(fake)
	_open(game, ParentGate.LEAVE)
	_pass_the_lock(game, fake)
	var screen := _new_code(game)
	assert_eq(_state(game), ParentGate.State.NEW_CODE)
	assert_true(screen.visible)
	assert_false(_prompt(game).visible)
	assert_eq(screen.heading.text, _text("forgot_new_code_title"))
	assert_eq(screen.code_entry.title.text, _text("new_code"))
	_enter_new(game, NEW_CODE)
	assert_eq(screen.code_entry.title.text, _text("new_code_again"), "typed twice, as at setup")
	_enter_new(game, WRONG)
	assert_eq(screen.code_entry.message.text, _text("codes_differ"), "a mismatch starts again")
	assert_eq(_state(game), ParentGate.State.NEW_CODE)
	_enter_new(game, NEW_CODE)
	_enter_new(game, NEW_CODE)
	assert_eq(_state(game), ParentGate.State.PROMPT, "back at the code prompt")
	assert_eq(game.parent_gate.pending_action, ParentGate.LEAVE, "for the action started")
	assert_eq(_prompt(game).note.text, _text("forgot_code_changed"))
	assert_eq(quits, 0, "passing the lock gives no parent authority: the new code is asked")
	_enter(game, CODE)
	assert_eq(quits, 0, "the old code stopped working at once")
	assert_eq(game.parent_store.wrong_tries(), 1)
	_enter(game, NEW_CODE)
	assert_eq(quits, 1, "the new code runs the pending action")
	assert_eq(fake.stops, 1, "leave stops pinning")
	var again := ParentStore.new(STORE_PATH)
	assert_eq(again.try_code(NEW_CODE, 0), ParentStore.Result.OK, "the new code is on disk")


func test_back_or_30_s_idle_on_the_new_code_screen_returns_to_the_prompt_with_nothing_changed() -> void:
	var fake := FakePlatform.new()
	var game := _game(fake)
	_open(game, ParentGate.SETTINGS)
	var before := FileAccess.get_file_as_bytes(STORE_PATH)
	_pass_the_lock(game, fake)
	_enter_new(game, NEW_CODE)
	_press(game, _new_code(game).code_entry.back_rect().get_center())
	assert_eq(_state(game), ParentGate.State.PROMPT, "Back: the code prompt")
	assert_eq(game.parent_gate.pending_action, ParentGate.SETTINGS)
	assert_eq(_prompt(game).note.text, "")
	assert_eq(FileAccess.get_file_as_bytes(STORE_PATH), before, "nothing changed")
	_pass_the_lock(game, fake)
	_steps(game, ParentNewCode.IDLE_STEPS - 1)
	_enter_new(game, "1")
	_steps(game, ParentNewCode.IDLE_STEPS - 1)
	assert_eq(_state(game), ParentGate.State.NEW_CODE, "a press restarts the 30 s")
	_steps(game, 1)
	assert_eq(_state(game), ParentGate.State.PROMPT, "30 s idle: the code prompt")
	assert_eq(game.parent_gate.pending_action, ParentGate.SETTINGS)
	assert_eq(FileAccess.get_file_as_bytes(STORE_PATH), before, "nothing changed")
	_enter(game, CODE)
	assert_eq(_state(game), ParentGate.State.SETTINGS, "the old code still opens settings")


func test_it_works_during_the_wait_and_the_reset_clears_the_tries_and_the_wait() -> void:
	var fake := FakePlatform.new()
	var game := _game(fake)
	var prompt := _open(game, ParentGate.SETTINGS)
	for i in ParentStore.WRONG_TRIES_BEFORE_WAIT:
		_enter(game, WRONG)
	assert_true(prompt.waiting(), "5 wrong: the wait")
	_pass_the_lock(game, fake, false)
	assert_true(prompt.waiting(), "cancelled: the wait goes on")
	assert_eq(game.parent_store.wrong_tries(), ParentStore.WRONG_TRIES_BEFORE_WAIT)
	_pass_the_lock(game, fake)
	_enter_new(game, NEW_CODE)
	_enter_new(game, NEW_CODE)
	assert_eq(_state(game), ParentGate.State.PROMPT)
	assert_false(prompt.waiting(), "the wait is cleared")
	assert_eq(game.parent_store.wrong_tries(), 0, "the tries are cleared")
	_enter(game, NEW_CODE)
	assert_eq(_state(game), ParentGate.State.SETTINGS, "the new code opens the pending action")


func test_it_unlocks_a_locked_store_and_rewrites_both_files() -> void:
	var seeded := ParentStore.new(STORE_PATH)
	seeded.set_code(CODE)
	for path in [STORE_PATH, BACKUP_PATH]:
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_buffer(PackedByteArray([0x00, 0xff, 0x7b, 0x13]))
		file.close()
	var locked := ParentStore.new(STORE_PATH)
	assert_push_error("locked")
	assert_true(locked.is_locked())
	var damaged := FileAccess.get_file_as_bytes(STORE_PATH)
	var fake := FakePlatform.new()
	var game := _game(fake, locked)
	_open(game, ParentGate.SETTINGS)
	_enter(game, CODE)
	assert_eq(_state(game), ParentGate.State.PROMPT, "locked: even the old code is refused")
	_pass_the_lock(game, fake)
	_enter_new(game, NEW_CODE)
	_enter_new(game, NEW_CODE)
	assert_false(game.parent_store.is_locked(), "the LOCKED state is gone")
	assert_ne(FileAccess.get_file_as_bytes(STORE_PATH), damaged, "parent.json rewritten")
	assert_ne(FileAccess.get_file_as_bytes(BACKUP_PATH), damaged, "parent.json.bak rewritten")
	for path in [STORE_PATH, BACKUP_PATH]:
		var copy := DIR + "check.json"
		DirAccess.copy_absolute(path, copy)
		var read := ParentStore.new(copy)
		assert_false(read.is_locked(), "%s reads on its own" % path)
		assert_eq(read.try_code(NEW_CODE, 0), ParentStore.Result.OK, "%s holds the new code" % path)
		DirAccess.remove_absolute(copy)
		DirAccess.remove_absolute(copy + ParentStore.BACKUP_SUFFIX)
	_enter(game, NEW_CODE)
	assert_eq(_state(game), ParentGate.State.SETTINGS, "the new code opens the pending action")


# @test-link [[rule_parent_code_not_stored_plaintext]]
func test_after_a_reset_neither_parent_file_holds_the_new_code_in_plain_text() -> void:
	var fake := FakePlatform.new()
	var game := _game(fake)
	_open(game, ParentGate.LEAVE)
	_pass_the_lock(game, fake)
	_enter_new(game, NEW_CODE)
	_enter_new(game, NEW_CODE)
	assert_eq(_state(game), ParentGate.State.PROMPT, "the code is reset")
	for path in [STORE_PATH, BACKUP_PATH]:
		assert_true(FileAccess.file_exists(path), path)
		var text := FileAccess.get_file_as_bytes(path).get_string_from_utf8()
		assert_false(NEW_CODE in text, "%s: no plain new code" % path)
		assert_false(CODE in text, "%s: no plain old code" % path)


# --- Layout -------------------------------------------------------------------------------

func test_every_target_on_the_new_code_screen_is_at_least_9_mm_square_and_2_mm_apart() -> void:
	var fake := FakePlatform.new()
	var game := _game(fake)
	_open(game, ParentGate.LEAVE)
	_pass_the_lock(game, fake)
	var entry := _new_code(game).code_entry
	var view: ScreenView = game.simulation.view
	var mm := view.px_per_mm
	var screen := Rect2(Vector2.ZERO, view.screen_size)
	var rects: Array[Rect2] = [entry.back_rect()]
	for key in ParentPad.KEYS:
		if key != "":
			rects.append(entry.pad.key_rect(key))
	for i in rects.size():
		assert_gte(rects[i].size.x, 9.0 * mm, "%d: at least 9 mm wide" % i)
		assert_gte(rects[i].size.y, 9.0 * mm, "%d: at least 9 mm tall" % i)
		assert_true(screen.encloses(rects[i]), "%d: on the screen" % i)
		for j in range(i + 1, rects.size()):
			assert_gte(_gap(rects[i], rects[j]), 2.0 * mm, "%d and %d: 2 mm apart" % [i, j])


func test_the_no_lock_explanation_fits_above_the_button_in_english_and_french() -> void:
	for lang in ParentText.LANGUAGES:
		ParentText.language_override = lang
		var fake := FakePlatform.new()
		fake.secure = false
		var game := _game(fake)
		var prompt := _open(game, ParentGate.LEAVE)
		_tap_forgot(game)
		await get_tree().process_frame
		assert_eq(prompt.note.text, ParentText.text("forgot_no_lock", lang))
		assert_gt(prompt.note.get_line_count(), 1, "%s: it wraps" % lang)
		assert_eq(prompt.note.get_visible_line_count(), prompt.note.get_line_count(), "%s: every line shows" % lang)
		assert_lte(prompt.note.get_rect().end.y, prompt.forgot_rect().position.y, "%s: above the button" % lang)
		assert_true(ParentLayout.prompt_rect(game.simulation.view).encloses(prompt.note.get_rect()), "%s: on the panel" % lang)
		game.queue_free()
		await get_tree().process_frame


## The distance between two rects that don't overlap (0 if they do).
func _gap(a: Rect2, b: Rect2) -> float:
	var dx := maxf(0.0, maxf(a.position.x - b.end.x, b.position.x - a.end.x))
	var dy := maxf(0.0, maxf(a.position.y - b.end.y, b.position.y - a.end.y))
	return Vector2(dx, dy).length()
