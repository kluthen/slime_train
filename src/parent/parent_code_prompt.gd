class_name ParentCodePrompt
extends ParentSurface
## The code prompt: what every parent button leads to (ParentGate.open_prompt),
## for the gate's pending action. A panel about two thirds of the screen's
## width (ParentLayout.prompt_rect) on a dimming scrim over the running world;
## nothing pauses. Placeholder look (plain controls); the design tokens are
## ux-writer's, still to come.
##
## On the panel: on the left, the header (the wake-early prompt only: the time
## until sunrise, live), the title, the 6 digit slots shown as dots (never the
## digits), the wait's message, the "Forgot the code?" note and its button; on
## the right, the pad (ParentPad: 0-9 and delete, an in-game pad, never the
## phone's keyboard, ux D6).
##
## The 6th digit submits (proposed): the right code runs the pending action
## (ParentGate.act) and the parent's authority ends with it (the next action
## asks again); a wrong one shakes the slots (SHAKE_STEPS, visual only) and
## clears the entry. The tries are ParentStore's: one count for every parent
## button, on disk, the 5th wrong in a row starting the 30 s wait, timed on
## the game's wall clock (ParentGate.now_wall_ms) so it survives closing the
## prompt and a kill. During the wait the pad refuses digits and the message
## counts the seconds down. The prompt closes after IDLE_STEPS with no press
## on it; a press on the panel restarts them; a press outside closes it (the
## gate's rule).
# @spec-link [[req_denial_and_stepup_behavior]]
# @spec-link [[req_parent_gate_and_access]]

## The prompt closes after this many simulation steps with no press on it
## (15 s: specs/tuning.md).
const IDLE_STEPS := 900
## A wrong code's shake, simulation steps (ParentCodeSlots').
const SHAKE_STEPS := ParentCodeSlots.SHAKE_STEPS
## The left column's rows above the button, top to bottom, mm.
const HEADER_MM := 5.0
const TITLE_MM := 6.0
const SLOTS_ROW_MM := 6.0
const MESSAGE_MM := 6.0

## The digits entered so far (never shown).
var entry := ""
## The labels: the time until sunrise (wake early only), the title, the wait's
## message, the forgot-the-code note.
var header: Label = null
var title: Label = null
var message: Label = null
var note: Label = null
## The "Forgot the code?" button (drawn only; its rect is forgot_rect()).
var forgot: Button = null
var pad: ParentPad = null

var _scrim: ColorRect = null
var _panel: Panel = null
## The digit slots (they shake).
var _slots: ParentCodeSlots = null
## Simulation steps left before the prompt closes.
var _idle_left := 0


## The prompt's controls, all ignoring the mouse (the gate gives it its presses).
func _init() -> void:
	name = "CodePrompt"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scrim = _add(ColorRect.new(), self)
	_scrim.color = ParentLayout.SCRIM_COLOR
	_panel = _add(Panel.new(), self)
	header = _label()
	title = _label()
	title.text = ParentText.text("enter_code", ParentText.language())
	message = _label()
	note = _label()
	_slots = _add(ParentCodeSlots.new(), self)
	forgot = _add(Button.new(), self)
	forgot.text = ParentText.text("forgot_code", ParentText.language())
	forgot.focus_mode = Control.FOCUS_NONE
	forgot.clip_text = true
	pad = _add(ParentPad.new(), self)


## A fresh prompt for the gate's pending action: no digits, no note, the idle
## steps from the start, and the wait (if one runs) shown.
func opened() -> void:
	entry = ""
	note.text = ""
	_idle_left = IDLE_STEPS
	_slots.calm()
	_refresh()


## Only the panel is the prompt's; the scrim around it is outside.
func covers(at: Vector2) -> bool:
	return ParentLayout.prompt_rect(gate.simulation.view).has_point(at)


## A press on the panel restarts the idle steps; on "Forgot the code?" it
## shows the stub (chunk 20 brings the reset: nothing changes, no try counts);
## on a key it enters or deletes a digit, unless the wait refuses them.
# @spec-link [[req_denial_and_stepup_behavior]]
# @spec-link [[req_parent_gate_and_access]]
func press(at: Vector2) -> void:
	_idle_left = IDLE_STEPS
	if forgot_rect().has_point(at):
		note.text = ParentText.text("forgot_code_stub", ParentText.language())
		return
	var key := pad.key_at(at)
	if key == "" or waiting():
		return
	if key == ParentPad.DELETE:
		entry = entry.left(entry.length() - 1)
	else:
		entry += key
	if entry.length() == ParentStore.CODE_DIGITS:
		_submit()
	else:
		_refresh()


## One simulation step: the wake-early prompt closes once bedtime is over
## (its button is gone, proposed); else the idle steps and the shake run down
## and the live texts (time until sunrise, the wait's seconds) follow.
# @spec-link [[req_parent_gate_and_access]]
func step() -> void:
	if gate.pending_action == ParentGate.WAKE_EARLY and gate.simulation.session.phase != Session.BEDTIME:
		gate.close()
		return
	_idle_left -= 1
	if _idle_left <= 0:
		gate.close()
		return
	_slots.step()
	_refresh()


## Whether the wrong-code wait runs now (the pad refuses digits).
# @spec-link [[req_denial_and_stepup_behavior]]
func waiting() -> bool:
	return gate.store.wait_left_ms(gate.now_wall_ms()) > 0


## Whether a wrong code's shake is still running.
func shaking() -> bool:
	return _slots.shaking()


## How far the slots are shaken sideways now, viewport pixels (0 at rest).
func shake_offset() -> float:
	return _slots.shake_offset(gate.simulation.view)


## How many slots show a dot: one per digit entered.
func filled_slots() -> int:
	return _slots.filled()


## The screen rect of the "Forgot the code?" button (as laid out).
func forgot_rect() -> Rect2:
	return Rect2(forgot.position, forgot.size)


## The scrim fills the screen; on the panel, the pad on the right and the
## left column (header, title, slots, message, note; the button at the
## bottom, level with the pad's last row).
func lay_out(view: ScreenView) -> void:
	_scrim.size = view.screen_size
	var panel := ParentLayout.prompt_rect(view)
	_panel.position = panel.position
	_panel.size = panel.size
	var margin := view.mm_to_px(ParentLayout.PROMPT_MARGIN_MM)
	var pad_size := ParentPad.size_px(view)
	var pad_at := Vector2(panel.end.x - margin - pad_size.x, panel.position.y + margin)
	pad.lay_out(pad_at, view)
	var left := panel.position.x + margin
	var width := pad_at.x - margin - left
	var y := pad_at.y
	for row in [[header, HEADER_MM], [title, TITLE_MM], [null, SLOTS_ROW_MM], [message, MESSAGE_MM], [note, MESSAGE_MM]]:
		var height := view.mm_to_px(row[1])
		if row[0] == null:
			_slots.lay_out(Vector2(left, y), Vector2(width, height), view)
		else:
			_place(row[0], Rect2(left, y, width, height), view)
		y += height
	var key := view.mm_to_px(ParentPad.KEY_MM)
	_place(forgot, Rect2(left, pad_at.y + pad_size.y - key, width, key), view)


## Checks the entry: runs the action on the right code, shakes and clears on
## a wrong one (counted on disk by the store; the 5th starts the wait).
# @spec-link [[req_denial_and_stepup_behavior]]
# @spec-link [[req_actor_roles_and_permissions]]
func _submit() -> void:
	var code := entry
	entry = ""
	var result := gate.store.try_code(code, gate.now_wall_ms())
	if result == ParentStore.Result.OK:
		gate.act(gate.pending_action)
		return
	if result == ParentStore.Result.WRONG:
		_slots.shake()
	_refresh()


## Shows the state: the dots, the wait's seconds left (and the pad refusing),
## the time until sunrise on the wake-early prompt. The time left shows here
## and in settings only, behind the code.
# @spec-link [[rule_time_left_shown_only_behind_code]]
# @spec-link [[req_denial_and_stepup_behavior]]
func _refresh() -> void:
	var lang := ParentText.language()
	_slots.show_digits(entry.length())
	var wait_ms := gate.store.wait_left_ms(gate.now_wall_ms())
	message.text = ParentText.text("wait", lang).format({"s": ceili(wait_ms / 1000.0)}) if wait_ms > 0 else ""
	pad.set_refusing(wait_ms > 0)
	header.visible = gate.pending_action == ParentGate.WAKE_EARLY
	header.text = ""
	if header.visible:
		var time_left := ParentText.time_left(gate.simulation.session.time_left_ms())
		header.text = ParentText.text("time_left_bedtime", lang).format({"t": time_left})


## Puts `control` on `rect` with the parent surfaces' font size.
func _place(control: Control, rect: Rect2, view: ScreenView) -> void:
	control.position = rect.position
	control.size = rect.size
	control.add_theme_font_size_override("font_size", ParentLayout.font_px(view))


## A new wrapping label on the prompt.
func _label() -> Label:
	var label: Label = _add(Label.new(), self)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


## Adds `control` to `to`, ignoring the mouse; returns it.
func _add(control: Control, to: Control) -> Control:
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	to.add_child(control)
	return control
