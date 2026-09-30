class_name ParentNewCode
extends ParentSurface
## The new-code screen of "Forgot the code?" (ParentGate's NEW_CODE state):
## the code prompt opens it once the phone's own screen lock was passed
## (ParentCodePrompt, through the game's PhonePlatform). It fills the screen
## (so every press is its own) over the running world; nothing pauses.
## Placeholder look (plain controls); the design tokens are ux-writer's,
## still to come.
##
## A heading, then the new code typed twice as at setup (ParentChangeCode:
## its pad, its dots, its mismatch shake, its Back). When both entries match,
## the code replaces the old one at once (ParentStore.set_code: its salted
## hash only; the wrong tries and any wait cleared, a locked store unlocked)
## and the parent is back at the code prompt for the action they started
## (gate.pending_action, kept all along), where the new code is asked: passing
## the screen lock gives no parent authority. Back, or IDLE_STEPS with no
## press (settings' 30 s, proposed), returns to that code prompt with nothing
## changed.
# @spec-link [[req_parent_gate_and_access]]
# @spec-link [[req_denial_and_stepup_behavior]]

## The screen returns to the code prompt after this many simulation steps
## with no press (settings' 30 s, proposed).
const IDLE_STEPS := ParentSettings.IDLE_STEPS

## The heading.
var heading: Label = null
## The new code typed twice (its pad, its slots, its Back).
var code_entry: ParentChangeCode = null

var _background: ColorRect = null
## Simulation steps left before the screen returns to the code prompt.
var _idle_left := 0


## The screen's controls, all ignoring the mouse.
func _init() -> void:
	name = "NewCode"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_background = ParentSettings.add_to(ColorRect.new(), self)
	_background.color = ParentSettings.BACKGROUND
	heading = ParentSettings.new_label(self)
	heading.text = ParentText.text("forgot_new_code_title", ParentText.language())
	code_entry = ParentSettings.add_to(ParentChangeCode.new("new_code", "new_code_again"), self)
	code_entry.visible = true
	code_entry.matched.connect(_code_set)
	code_entry.back_pressed.connect(_back_to_prompt)


## A fresh entry (the first code asked) and the idle steps from the start.
func opened() -> void:
	_idle_left = IDLE_STEPS
	code_entry.begin()


## A press anywhere restarts the idle steps and goes to the entry (a key, or
## its Back).
func press(at: Vector2) -> void:
	_idle_left = IDLE_STEPS
	code_entry.press(at)


## One simulation step: the idle steps run down (at 0: back to the code
## prompt, nothing changed) and a mismatch's shake runs.
# @spec-link [[req_parent_gate_and_access]]
func step() -> void:
	_idle_left -= 1
	if _idle_left <= 0:
		_back_to_prompt()
		return
	code_entry.step()


## The background fills the screen; in the safe area
## (ParentLayout.surface_rect), the heading row at the top; under it, the pad
## on the right and the entry left of it (its Back level with the pad's last
## row). On a short screen the heading row (text only) and the gap under it
## give the pad room (ParentLayout.rows_over_pad, down to a line of text).
# @spec-link [[req_parent_gate_and_access]]
func lay_out(view: ScreenView) -> void:
	_background.size = view.screen_size
	var area := ParentLayout.surface_rect(view)
	var margin := view.mm_to_px(ParentLayout.PROMPT_MARGIN_MM)
	var top := area.position.y + view.mm_to_px(ParentSettings.TOP_MM)
	var bottom := area.end.y - margin
	var rows := ParentLayout.rows_over_pad(top, bottom, ParentSettings.LINE_MM, view)
	var left := area.position.x + margin
	ParentSettings.place(heading, Rect2(left, top, area.size.x - 2.0 * margin, rows.x), view)
	var pad_top := top + rows.x + rows.y
	var pad_at := Vector2(area.end.x - margin - ParentPad.size_px(view, bottom - pad_top).x, pad_top)
	var column := Rect2(left, pad_at.y, pad_at.x - margin - left, bottom - pad_at.y)
	code_entry.lay_out(column, pad_at, view)


## Both entries matched: `code` replaces the parent code at once (the store
## keeps its salted hash only, clears the wrong tries and any wait, unlocks a
## locked store) and the code prompt for the pending action asks for it.
# @spec-link [[req_parent_gate_and_access]]
# @spec-link [[req_denial_and_stepup_behavior]]
# @spec-link [[rule_parent_code_not_stored_plaintext]]
func _code_set(code: String) -> void:
	gate.store.set_code(code)
	gate.open_prompt(gate.pending_action)
	var prompt: ParentCodePrompt = gate.surfaces[ParentGate.State.PROMPT]
	prompt.show_note(ParentText.text("forgot_code_changed", ParentText.language()))


## Back (or the idle steps run out): the code prompt for the pending action,
## nothing changed.
# @spec-link [[req_parent_gate_and_access]]
func _back_to_prompt() -> void:
	gate.open_prompt(gate.pending_action)
