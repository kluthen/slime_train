extends GutTest
## The display's safe area (chunk 20, D112: the world drawn edge to edge,
## the controls inside the safe area) through the real game scene, on the
## reference phone's window (2400 x 1080 physical px, 1440 x 648 viewport
## px) and a fake platform (PhonePlatform) whose safe area leaves out a
## 100 px cut-out on the left or on the right (60 viewport px). Everything a
## parent reads or taps lies inside the safe area and keeps the 9 x 9 mm /
## 2 mm rules: the parent buttons (from the safe area's top-right corner), the
## code prompt, settings (its three screens), setup (its steps) and the new
## code. Their backgrounds and the scrim still fill the screen, and the tap
## zones stay on the screen's edges: the parent zone over the cut-out too, the
## edge strips a tenth of the screen's width. A resize reads the safe area
## again.
##
## The root window is resized for each test and put back after it; every
## game gets its own ParentStore on a scratch directory.

# @test-link [[req_parent_gate_and_access]]
# @test-link [[req_controls_tap_zones]]

const MAIN_SCENE := "res://src/main.tscn"
const DIR := "user://test-safe-area/"
const STORE_PATH := DIR + "parent.json"
const SEED := 20260930
const CODE := "135790"
## The reference phone's window, physical px, and its viewport.
const WINDOW := Vector2i(2400, 1080)
const SCREEN := Vector2(1440, 648)
## The safe areas with a 100 px cut-out on the left, on the right (window px).
const LEFT_CUT := Rect2i(100, 0, 2300, 1080)
const RIGHT_CUT := Rect2i(0, 0, 2300, 1080)
## The cut-out in viewport px (100 physical px at 1080 / 648).
const CUT := 60.0


## Stands in for the phone: its safe area is `area`; the lock screen is set,
## its prompt left for the test to answer (credential_finished).
class FakePlatform:
	extends PhonePlatform
	var area := LEFT_CUT

	func safe_area() -> Rect2i:
		return area

	func is_device_secure() -> bool:
		return true

	func confirm_credential(_title: String, _subtitle: String) -> void:
		pass


## The root window's size before the test.
var _window_size := Vector2i.ZERO


func before_each() -> void:
	_clear(DIR)
	_window_size = get_tree().root.size
	get_tree().root.size = WINDOW


func after_each() -> void:
	get_tree().root.size = _window_size


func after_all() -> void:
	_clear(DIR)


func _clear(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)


## A game on `fake` in test mode on the reference phone's screen, with
## sessions and real input let through, on a fresh store at STORE_PATH
## (seeded with CODE when `set_code`; else setup opens).
func _game(fake: FakePlatform, set_code := true) -> Node:
	var store := ParentStore.new(STORE_PATH)
	if set_code:
		store.set_code(CODE)
	var game: Node = load(MAIN_SCENE).instantiate()
	game.platform = fake
	game.parent_store = store
	add_child_autofree(game)
	var run := {"seed": SEED, "time_scale": 0, "sessions": true, "block_real_input": false,
			"screen_size": [SCREEN.x, SCREEN.y]}
	assert_eq(game.enable_test_mode(run), PackedStringArray())
	game.quit_app = func() -> void: pass
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


func _gate(game: Node) -> ParentGate:
	return game.parent_gate


func _view(game: Node) -> ScreenView:
	return game.simulation.view


## Types `code` on `pad`.
func _type(game: Node, pad: ParentPad, code: String) -> void:
	for digit in code:
		_press(game, pad.key_rect(digit).get_center())


## The pad's keys' rects.
func _keys(pad: ParentPad) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for key in ParentPad.KEYS:
		if key != "":
			rects.append(pad.key_rect(key))
	return rects


## Asserts the view's safe rect leaves out `cut` viewport px on the left
## (`side` -1) or the right (1), nothing else.
func _assert_safe(game: Node, side: int) -> void:
	var safe := _view(game).safe_rect()
	assert_almost_eq(safe.position.x, CUT if side < 0 else 0.0, 0.01, "the left inset")
	assert_almost_eq(safe.end.x, SCREEN.x - (CUT if side > 0 else 0.0), 0.01, "the right inset")
	assert_eq(safe.position.y, 0.0, "no top inset")
	assert_eq(safe.end.y, SCREEN.y, "no bottom inset")


## Each rect of `rects` is at least 9 x 9 mm, inside the safe area, and 2 mm
## from the others.
func _check_targets(rects: Array[Rect2], view: ScreenView, what: String) -> void:
	var mm := view.px_per_mm
	var safe := view.safe_rect()
	for i in rects.size():
		var rect := rects[i]
		assert_gte(rect.size.x, 9.0 * mm, "%s %d: at least 9 mm wide" % [what, i])
		assert_gte(rect.size.y, 9.0 * mm, "%s %d: at least 9 mm tall" % [what, i])
		assert_true(safe.encloses(rect), "%s %d: inside the safe area (%s in %s)" % [what, i, rect, safe])
		for j in range(i + 1, rects.size()):
			assert_gte(_gap(rect, rects[j]), 2.0 * mm, "%s %d and %d: 2 mm apart" % [what, i, j])


## Every control shown on `surface` (text, keys, buttons, slots) lies inside
## the safe area, but its background or scrim, which fill the screen. Two
## frames first: the gate lays the open surface out every frame, and a
## wrapping label settles its size on the frame after its width.
func _check_shown(surface: Control, view: ScreenView, what: String) -> void:
	await wait_process_frames(2)
	var whole := Rect2(Vector2.ZERO, view.screen_size)
	var safe := view.safe_rect()
	var backgrounds := 0
	for control in surface.find_children("*", "Control", true, false):
		if not control.is_visible_in_tree() or not control.get_global_rect().has_area():
			continue
		var rect: Rect2 = control.get_global_rect()
		if control is ColorRect and rect.is_equal_approx(whole):
			backgrounds += 1
			continue
		assert_true(safe.encloses(rect), "%s: %s inside the safe area (%s in %s)" % [what, control.name, rect, safe])
	assert_eq(backgrounds, 1, "%s: its background (or scrim) fills the screen" % what)


## The distance between two rects that don't overlap (0 if they do).
func _gap(a: Rect2, b: Rect2) -> float:
	var dx := maxf(0.0, maxf(a.position.x - b.end.x, b.position.x - a.end.x))
	var dy := maxf(0.0, maxf(a.position.y - b.end.y, b.position.y - a.end.y))
	return Vector2(dx, dy).length()


## The parent buttons, the code prompt and settings' three screens, for a
## cut-out on `side` (-1 left, 1 right).
func _check_buttons_prompt_and_settings(side: int) -> void:
	var fake := FakePlatform.new()
	fake.area = LEFT_CUT if side < 0 else RIGHT_CUT
	var game := _game(fake)
	var gate := _gate(game)
	var view := _view(game)
	_assert_safe(game, side)
	# The parent zone runs over the cut-out too: a tap there reveals the buttons.
	_press(game, Vector2(5, 5) if side < 0 else Vector2(SCREEN.x - 5, 5))
	assert_eq(gate.state, ParentGate.State.BUTTONS, "the parent zone is on the screen's edge")
	var buttons: Array[Rect2] = []
	for action in ParentGate.SLOTS:
		buttons.append(gate.button_rect(action))
	_check_targets(buttons, view, "parent buttons")
	var settings_rect := gate.button_rect(ParentGate.SETTINGS)
	assert_almost_eq(view.safe_rect().end.x - settings_rect.end.x, view.mm_to_px(ParentLayout.EDGE_MM), 0.01,
			"settings' button from the safe area's right edge")
	_press(game, settings_rect.get_center())
	var prompt: ParentCodePrompt = gate.surfaces[ParentGate.State.PROMPT]
	assert_eq(gate.state, ParentGate.State.PROMPT)
	var on_prompt := _keys(prompt.pad)
	on_prompt.append(prompt.forgot_rect())
	_check_targets(on_prompt, view, "code prompt")
	assert_true(view.safe_rect().encloses(ParentLayout.prompt_rect(view)), "the prompt's panel inside the safe area")
	await _check_shown(prompt, view, "code prompt")
	_type(game, prompt.pad, CODE)
	assert_eq(gate.state, ParentGate.State.SETTINGS, "the right code opens settings")
	var settings: ParentSettings = gate.surfaces[ParentGate.State.SETTINGS]
	var main: Array[Rect2] = [settings.close_rect(), settings.change_code_rect()]
	for id in settings.levels():
		main.append(settings.level_rect(id))
	_check_targets(main, view, "settings")
	await _check_shown(settings, view, "settings")
	_press(game, settings.change_code_rect().get_center())
	var change := _keys(settings.change_code.pad)
	change.append_array([settings.close_rect(), settings.change_code.back_rect()])
	_check_targets(change, view, "change of code")
	await _check_shown(settings, view, "change of code")
	_press(game, settings.change_code.back_rect().get_center())
	_press(game, settings.level_rect(settings.levels()[0]).get_center())
	var confirm: Array[Rect2] = [settings.close_rect(), settings.delete_save.yes_rect(), settings.delete_save.no_rect()]
	_check_targets(confirm, view, "delete confirmation")
	await _check_shown(settings, view, "delete confirmation")


func test_with_a_cut_out_on_the_left_the_parent_controls_are_inside_the_safe_area() -> void:
	await _check_buttons_prompt_and_settings(-1)


func test_with_a_cut_out_on_the_right_the_parent_controls_are_inside_the_safe_area() -> void:
	await _check_buttons_prompt_and_settings(1)


func test_setup_is_inside_the_safe_area() -> void:
	for side in [-1, 1]:
		var fake := FakePlatform.new()
		fake.area = LEFT_CUT if side < 0 else RIGHT_CUT
		var game := _game(fake, false)
		var view := _view(game)
		_assert_safe(game, side)
		var setup: ParentSetup = _gate(game).surfaces[ParentGate.State.SETUP]
		assert_eq(_gate(game).state, ParentGate.State.SETUP, "first launch: setup")
		await _check_shown(setup, view, "welcome")
		_check_targets([setup.next_rect()], view, "welcome")
		_press(game, setup.next_rect().get_center())
		var code := _keys(setup.code_entry.pad)
		code.append(setup.code_entry.back_rect())
		_check_targets(code, view, "code")
		await _check_shown(setup, view, "code")
		_type(game, setup.code_entry.pad, CODE)
		_type(game, setup.code_entry.pad, CODE)
		assert_eq(setup.current, ParentSetup.Step.FORGOTTEN, "a matching code moves on")
		_check_targets([setup.back_rect(), setup.next_rect()], view, "forgotten")
		await _check_shown(setup, view, "forgotten")
		_press(game, setup.next_rect().get_center())
		_check_targets([setup.back_rect(), setup.next_rect()], view, "pinning")
		await _check_shown(setup, view, "pinning")


func test_the_new_code_is_inside_the_safe_area() -> void:
	var fake := FakePlatform.new()
	var game := _game(fake)
	var gate := _gate(game)
	var view := _view(game)
	_press(game, Vector2(300, 20))
	_press(game, gate.button_rect(ParentGate.SETTINGS).get_center())
	var prompt: ParentCodePrompt = gate.surfaces[ParentGate.State.PROMPT]
	_press(game, prompt.forgot_rect().get_center())
	fake.credential_finished.emit(true)
	assert_eq(gate.state, ParentGate.State.NEW_CODE, "the screen lock passed: the new code")
	var new_code: ParentNewCode = gate.surfaces[ParentGate.State.NEW_CODE]
	var targets := _keys(new_code.code_entry.pad)
	targets.append(new_code.code_entry.back_rect())
	_check_targets(targets, view, "new code")
	await _check_shown(new_code, view, "new code")


func test_the_edge_strips_stay_on_the_screen_edges() -> void:
	var game := _game(FakePlatform.new())
	var view := _view(game)
	_assert_safe(game, -1)
	var width := SCREEN.x * TapDispatcher.EDGE_STRIP_SHARE
	assert_eq(TapDispatcher.edge_button_rect(-1, view).position.x, 0.0, "the left strip from the screen's edge")
	assert_eq(TapDispatcher.edge_button_rect(-1, view).size.x, width, "a tenth of the screen's width")
	assert_eq(TapDispatcher.edge_button_rect(1, view).end.x, SCREEN.x, "the right strip to the screen's edge")


func test_a_resize_reads_the_safe_area_again() -> void:
	var fake := FakePlatform.new()
	var game := _game(fake)
	_assert_safe(game, -1)
	fake.area = RIGHT_CUT
	game.get_viewport().size_changed.emit()
	game.step_simulation()
	_assert_safe(game, 1)
	_press(game, Vector2(300, 20))
	assert_almost_eq(_gate(game).button_rect(ParentGate.SETTINGS).end.x,
			SCREEN.x - CUT - _view(game).mm_to_px(ParentLayout.EDGE_MM), 0.01, "the buttons follow the safe area")
