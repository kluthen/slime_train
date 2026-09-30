extends GutTest
## The code pads on a short screen (chunk 20) through the real game scene:
## the reference phone's window (2400 x 1080 physical px, 1440 x 648
## viewport px) at the logical density Android reports for it (480 dpi), so
## the screen is about 57 mm tall and 127 mm wide, not the 68 mm of its real
## 405 ppi. Every tap target of the code prompt, setup's code step, settings'
## change of code and the new-code screen lies inside the safe area, at least
## 9 x 9 mm and 2 mm from the others, with the whole screen or a cut-out on
## the left. At the reference density the pad keeps its preferred sizes.
##
## The density is faked on the view (test mode keeps the reference phone's
## and only a simulation step sets it again; these runs never step). The root
## window is resized for each test and put back after it; every game gets its
## own ParentStore on a scratch directory.

# @test-link [[req_parent_gate_and_access]]

const MAIN_SCENE := "res://src/main.tscn"
const DIR := "user://test-short-screen/"
const STORE_PATH := DIR + "parent.json"
const SEED := 20260930
const CODE := "135790"
const WINDOW := Vector2i(2400, 1080)
const SCREEN := Vector2(1440, 648)
## The whole window, and a 100 px cut-out on the left (window px).
const WHOLE := Rect2i(0, 0, 2400, 1080)
const LEFT_CUT := Rect2i(100, 0, 2300, 1080)
## The logical density Android reports for the reference phone.
const LOGICAL_DPI := 480.0
## Float slack on the floors' checks, viewport px (a thousandth of a mm).
const SLACK := 0.01


## Stands in for the phone: its safe area is `area`; the lock screen is set,
## its prompt left for the test to answer (credential_finished).
class FakePlatform:
	extends PhonePlatform
	var area := WHOLE

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


## Viewport px per mm at the logical density on the reference phone's window.
func _short_px_per_mm() -> float:
	return ScreenView.px_per_mm_for(LOGICAL_DPI, float(WINDOW.y) / SCREEN.y)


## A game on a fake platform with the safe area `area`, in test mode on the
## reference phone's screen at `px_per_mm`, with sessions and real input let
## through, on a fresh store at STORE_PATH (seeded with CODE when `set_code`;
## else setup opens).
func _game(area: Rect2i, px_per_mm: float, set_code := true) -> Node:
	var store := ParentStore.new(STORE_PATH)
	if set_code:
		store.set_code(CODE)
	var fake := FakePlatform.new()
	fake.area = area
	var game: Node = load(MAIN_SCENE).instantiate()
	game.platform = fake
	game.parent_store = store
	add_child_autofree(game)
	var run := {"seed": SEED, "time_scale": 0, "sessions": true, "block_real_input": false,
			"screen_size": [SCREEN.x, SCREEN.y]}
	assert_eq(game.enable_test_mode(run), PackedStringArray())
	game.quit_app = func() -> void: pass
	_view(game).px_per_mm = px_per_mm
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


## The pad's keys' rects.
func _keys(pad: ParentPad) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for key in ParentPad.KEYS:
		if key != "":
			rects.append(pad.key_rect(key))
	return rects


## Each rect of `rects` is at least 9 x 9 mm, inside the safe area, and 2 mm
## from the others (SLACK allowed for floats), two frames after the last
## press (the gate lays the open surface out every frame).
func _check_targets(rects: Array[Rect2], view: ScreenView, what: String) -> void:
	assert_eq(view.px_per_mm, _short_px_per_mm(), "%s: still on the short screen" % what)
	var mm := view.px_per_mm
	var safe := view.safe_rect().grow(SLACK)
	for i in rects.size():
		var rect := rects[i]
		assert_gte(rect.size.x, 9.0 * mm - SLACK, "%s %d: at least 9 mm wide" % [what, i])
		assert_gte(rect.size.y, 9.0 * mm - SLACK, "%s %d: at least 9 mm tall" % [what, i])
		assert_true(safe.encloses(rect), "%s %d: inside the safe area (%s in %s)" % [what, i, rect, safe])
		for j in range(i + 1, rects.size()):
			assert_gte(_gap(rect, rects[j]), 2.0 * mm - SLACK, "%s %d and %d: 2 mm apart" % [what, i, j])


## The distance between two rects that don't overlap (0 if they do).
func _gap(a: Rect2, b: Rect2) -> float:
	var dx := maxf(0.0, maxf(a.position.x - b.end.x, b.position.x - a.end.x))
	var dy := maxf(0.0, maxf(a.position.y - b.end.y, b.position.y - a.end.y))
	return Vector2(dx, dy).length()


## The code prompt, then settings' change of code, for the safe area `area`.
func _check_prompt_and_change_of_code(area: Rect2i) -> void:
	var game := _game(area, _short_px_per_mm())
	var gate := _gate(game)
	var view := _view(game)
	assert_almost_eq(view.screen_size.y / view.px_per_mm, 57.15, 0.01, "about 57 mm tall")
	assert_almost_eq(view.screen_size.x / view.px_per_mm, 127.0, 0.01, "127 mm wide")
	_press(game, Vector2(300, 20))
	_press(game, gate.button_rect(ParentGate.SETTINGS).get_center())
	assert_eq(gate.state, ParentGate.State.PROMPT)
	var prompt: ParentCodePrompt = gate.surfaces[ParentGate.State.PROMPT]
	await wait_process_frames(2)
	var on_prompt := _keys(prompt.pad)
	on_prompt.append(prompt.forgot_rect())
	_check_targets(on_prompt, view, "code prompt")
	for digit in CODE:
		_press(game, prompt.pad.key_rect(digit).get_center())
	assert_eq(gate.state, ParentGate.State.SETTINGS, "the right code opens settings")
	var settings: ParentSettings = gate.surfaces[ParentGate.State.SETTINGS]
	_press(game, settings.change_code_rect().get_center())
	await wait_process_frames(2)
	var change := _keys(settings.change_code.pad)
	change.append_array([settings.close_rect(), settings.change_code.back_rect()])
	_check_targets(change, view, "change of code")


# @test-link [[req_parent_gate_and_access]]
func test_on_a_short_screen_the_prompt_and_the_change_of_code_fit() -> void:
	await _check_prompt_and_change_of_code(WHOLE)


# @test-link [[req_parent_gate_and_access]]
func test_on_a_short_screen_with_a_cut_out_the_prompt_and_the_change_of_code_fit() -> void:
	await _check_prompt_and_change_of_code(LEFT_CUT)


# @test-link [[req_parent_gate_and_access]]
func test_on_a_short_screen_setups_code_step_fits() -> void:
	for area in [WHOLE, LEFT_CUT]:
		var game := _game(area, _short_px_per_mm(), false)
		var view := _view(game)
		var setup: ParentSetup = _gate(game).surfaces[ParentGate.State.SETUP]
		assert_eq(_gate(game).state, ParentGate.State.SETUP, "first launch: setup")
		await wait_process_frames(2)
		_press(game, setup.next_rect().get_center())
		assert_eq(setup.current, ParentSetup.Step.CODE)
		await wait_process_frames(2)
		var code := _keys(setup.code_entry.pad)
		code.append(setup.code_entry.back_rect())
		_check_targets(code, view, "setup's code step")
		assert_lte(setup.heading.get_global_rect().end.y, setup.code_entry.pad.position.y,
				"the heading row above the pad")


# @test-link [[req_parent_gate_and_access]]
func test_on_a_short_screen_the_new_code_fits() -> void:
	for area in [WHOLE, LEFT_CUT]:
		var game := _game(area, _short_px_per_mm())
		var gate := _gate(game)
		var view := _view(game)
		_press(game, Vector2(300, 20))
		_press(game, gate.button_rect(ParentGate.SETTINGS).get_center())
		var prompt: ParentCodePrompt = gate.surfaces[ParentGate.State.PROMPT]
		await wait_process_frames(2)
		_press(game, prompt.forgot_rect().get_center())
		game.platform.credential_finished.emit(true)
		assert_eq(gate.state, ParentGate.State.NEW_CODE, "the screen lock passed: the new code")
		var new_code: ParentNewCode = gate.surfaces[ParentGate.State.NEW_CODE]
		await wait_process_frames(2)
		var targets := _keys(new_code.code_entry.pad)
		targets.append(new_code.code_entry.back_rect())
		_check_targets(targets, view, "new code")


# @test-link [[req_parent_gate_and_access]]
func test_at_the_reference_density_the_pads_keep_their_preferred_sizes() -> void:
	var game := _game(WHOLE, ScreenView.REFERENCE_PX_PER_MM)
	var gate := _gate(game)
	var view := _view(game)
	_press(game, Vector2(300, 20))
	_press(game, gate.button_rect(ParentGate.SETTINGS).get_center())
	var prompt: ParentCodePrompt = gate.surfaces[ParentGate.State.PROMPT]
	await wait_process_frames(2)
	assert_eq(prompt.pad.key_px, view.mm_to_px(ParentPad.KEY_MM), "the prompt's keys")
	assert_eq(prompt.pad.gap_px, view.mm_to_px(ParentPad.GAP_MM))
	for digit in CODE:
		_press(game, prompt.pad.key_rect(digit).get_center())
	var settings: ParentSettings = gate.surfaces[ParentGate.State.SETTINGS]
	_press(game, settings.change_code_rect().get_center())
	await wait_process_frames(2)
	assert_eq(settings.change_code.pad.key_px, view.mm_to_px(ParentPad.KEY_MM), "the change of code's keys")
	assert_eq(settings.change_code.pad.gap_px, view.mm_to_px(ParentPad.GAP_MM))
	assert_almost_eq(settings.close_rect().size.y, view.mm_to_px(ParentSettings.TARGET_MM), 0.001,
			"the close button's row")
