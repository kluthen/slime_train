class_name DebugOverlay
extends CanvasLayer
## The debug overlay: developer tools on top of the game, in debug builds
## only. The game root (src/main.gd) adds it by path, after TestModeGuard
## allows it and only when it is the running main scene, so a release export
## never loads anything from src/debug/ and a game a test adds has none
## unless the test asks (main.add_debug_overlay()).
##
## A bar of controls along the top of the screen, under the parent band:
## - speed 1x, 2x, 5x, 10x: the game root multiplies its frame clock by
##   `speed`, so each frame runs that many more ticks, the very same ticks
##   (test mode's time_scale does the same). The session's clocks run at the
##   same speed (DebugClock); autosave stays on real time;
## - Reset, clicked twice within RESET_CONFIRM_MS: the level starts over as
##   on a first launch (main.restart_fresh()) and the fresh state replaces the
##   level's save through SaveStore (a write over it, never a delete), when
##   the game autosaves;
## - Labels: DebugSlimeLabels draws each slime's id and state under it;
## - Kill: armed, the next tap on the game is the kill tool's instead of the
##   simulation's: the slime under it goes to the start of the loop as a lost
##   slime (DebugKill). One use, a tap on no slime, or a click on another
##   control disarms it;
## - the "woken / available" counter (DebugCounts) and the last action's
##   result.
##
## Input: the controls are Buttons (mouse_filter STOP) and consume their
## mouse clicks; the bar and the labels ignore the mouse, so the rest of the
## screen plays as usual. The game root also asks intercept() first in its
## _unhandled_input: it swallows a touch on a control (phones deliver the
## touch itself besides the emulated click) and, while Kill is armed, the
## next press anywhere (and its release). So the kill tap never reaches the
## simulation as a tap: no ripple, no call, no session start.

const SPEEDS: Array[int] = [1, 2, 5, 10]
## The second click on Reset must come within this, real milliseconds.
const RESET_CONFIRM_MS := 2000
## How long the last action's result stays on screen, real milliseconds.
const STATUS_MS := 4000
## Above the game's HUD (layer 1).
const LAYER := 50
## The bar's top-left corner, screen pixels: just under the parent band
## (TapDispatcher.TOP_BAND_HEIGHT), so the controls never cover a parent-zone
## tap, nor test mode's banner.
const BAR_AT := Vector2(8.0, TapDispatcher.TOP_BAND_HEIGHT + 8.0)
const RESET_TEXT := "Reset"
const RESET_CONFIRM_TEXT := "Reset? click again"
const KILL_TEXT := "Kill"
const KILL_ARMED_TEXT := "Kill: tap a slime"
const KILL_ARMED_COLOR := Color(1.0, 0.45, 0.45)

## Simulated seconds per real second (one of SPEEDS). The game root reads it.
var speed := 1:
	set(value):
		speed = value if value in SPEEDS else 1
		if clock != null:
			clock.speed = speed
		for each in speed_buttons:
			speed_buttons[each].set_pressed_no_signal(each == speed)
## Whether the next press on the game is the kill tool's.
var kill_armed := false
## The game root this overlay serves (its parent).
var game: Node = null
## The session clock the game reads, sped up (wraps the game's own).
var clock: DebugClock = null
## The world-space labels (a child of the game root), hidden until toggled.
var labels: DebugSlimeLabels = null
## The last action's result ("" when none showing).
var status := ""

var speed_buttons := {}
var reset_button: Button = null
var labels_button: Button = null
var kill_button: Button = null
var counter_label: Label = null
var status_label: Label = null

## Until when (Time.get_ticks_msec()) a second click on Reset resets; -1: not asked.
var _reset_until_ms := -1
var _status_until_ms := -1
## The presses swallowed whose release must be swallowed too ("touch:<index>", "mouse").
var _swallowed := {}


func _ready() -> void:
	name = "DebugOverlay"
	layer = LAYER
	game = get_parent()
	if game != null and game.get("session_clock") != null:
		clock = DebugClock.new(game.session_clock)
		clock.speed = speed
		game.session_clock = clock
	labels = DebugSlimeLabels.new()
	labels.name = "DebugSlimeLabels"
	labels.visible = false
	if game != null:
		game.add_child(labels)
	_build()


func _exit_tree() -> void:
	if labels != null and is_instance_valid(labels):
		labels.queue_free()


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	if _reset_until_ms >= 0 and now > _reset_until_ms:
		_reset_until_ms = -1
		reset_button.text = RESET_TEXT
	if _status_until_ms >= 0 and now > _status_until_ms:
		_status_until_ms = -1
		status = ""
	var sim: Simulation = game.get("simulation") if game != null else null
	if labels != null:
		labels.simulation = sim
	if sim != null:
		var counts := DebugCounts.count(sim)
		counter_label.text = "Woken %d / available %d" % [counts["woken"], counts["available"]]
	status_label.text = status


## The game root asks this first for every input event: true means the
## overlay took it and the simulation must not get it (see the class doc).
func intercept(event: InputEvent) -> bool:
	var key := ""
	if event is InputEventScreenTouch:
		key = "touch:%d" % event.index
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
			and event.device != InputEvent.DEVICE_ID_EMULATION:
		key = "mouse"
	else:
		return false
	if not event.pressed:
		return _swallowed.erase(key)
	if over_controls(event.position):
		_swallowed[key] = true
		return true
	if kill_armed:
		_swallowed[key] = true
		kill_at(event.position)
		return true
	return false


## Whether screen point `at` is on one of the overlay's buttons.
func over_controls(at: Vector2) -> bool:
	for button in _buttons():
		if button.is_visible_in_tree() and button.get_global_rect().has_point(at):
			return true
	return false


## Arms or disarms the kill tool.
func arm_kill(on: bool) -> void:
	kill_armed = on
	if kill_button != null:
		kill_button.set_pressed_no_signal(on)
		kill_button.text = KILL_ARMED_TEXT if on else KILL_TEXT
		kill_button.modulate = KILL_ARMED_COLOR if on else Color.WHITE


## The kill tool at screen point `at`: the slime there goes to the start of
## the loop. Disarms either way. Returns the slime's id, or -1.
func kill_at(at: Vector2) -> int:
	arm_kill(false)
	var sim: Simulation = game.get("simulation")
	if sim == null:
		return -1
	if not DebugKill.available(sim):
		_show("Kill: unavailable (no lost-slime move in Offscreen)")
		return -1
	var slime_id := DebugKill.slime_at(sim, at)
	if slime_id < 0:
		_show("Kill: no slime there")
		return -1
	if not DebugKill.send_to_start(sim, slime_id):
		_show("Kill: #%d couldn't be moved" % slime_id)
		return -1
	_show("Kill: #%d sent to the start of the loop" % slime_id)
	return slime_id


## A click on Reset at `now_ms`: the first asks, a second within
## RESET_CONFIRM_MS resets. Returns whether it reset.
func press_reset(now_ms: int) -> bool:
	arm_kill(false)
	if _reset_until_ms >= 0 and now_ms <= _reset_until_ms:
		_reset_until_ms = -1
		reset_button.text = RESET_TEXT
		_reset()
		return true
	_reset_until_ms = now_ms + RESET_CONFIRM_MS
	reset_button.text = RESET_CONFIRM_TEXT
	return false


## Shows or hides the slime labels.
func show_labels(on: bool) -> void:
	arm_kill(false)
	labels.visible = on
	labels_button.set_pressed_no_signal(on)


func _reset() -> void:
	game.restart_fresh()
	if game.autosave.enabled:
		var error: String = game.save_now()
		_show("Reset: fresh level, save replaced" if error == "" else "Reset: fresh level; save not written (%s)" % error)
	else:
		_show("Reset: fresh level (autosave off: no save written)")
	print("Debug overlay: ", status)


func _show(text: String) -> void:
	status = text
	_status_until_ms = Time.get_ticks_msec() + STATUS_MS
	if status_label != null:
		status_label.text = text


func _on_speed(value: int) -> void:
	arm_kill(false)
	speed = value


func _buttons() -> Array[Button]:
	var out: Array[Button] = []
	for each in speed_buttons:
		out.append(speed_buttons[each])
	for button in [reset_button, labels_button, kill_button]:
		if button != null:
			out.append(button)
	return out


func _build() -> void:
	var bar := HBoxContainer.new()
	bar.name = "Bar"
	bar.position = BAR_AT
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_constant_override("separation", 6)
	add_child(bar)
	var group := ButtonGroup.new()
	for each in SPEEDS:
		var button := _button("%dx" % each)
		button.toggle_mode = true
		button.button_group = group
		button.button_pressed = each == speed
		button.pressed.connect(_on_speed.bind(each))
		speed_buttons[each] = button
		bar.add_child(button)
	reset_button = _button(RESET_TEXT)
	reset_button.pressed.connect(func() -> void: press_reset(Time.get_ticks_msec()))
	bar.add_child(reset_button)
	labels_button = _button("Labels")
	labels_button.toggle_mode = true
	labels_button.toggled.connect(show_labels)
	bar.add_child(labels_button)
	kill_button = _button(KILL_TEXT)
	kill_button.toggle_mode = true
	kill_button.toggled.connect(arm_kill)
	bar.add_child(kill_button)
	counter_label = _label()
	bar.add_child(counter_label)
	status_label = _label()
	bar.add_child(status_label)


func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.name = text.replace(" ", "")
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.focus_mode = Control.FOCUS_NONE
	return button


func _label() -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	return label
