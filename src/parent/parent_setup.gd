class_name ParentSetup
extends ParentSurface
## Setup: the parent layer's first-launch surface (ParentGate's SETUP state).
## The gate opens it at once when the parent store has no code (first
## launch), before the world takes a tap. It fills the screen, so every press
## is its own (no call, no session start, no parent buttons), over the running
## world: nothing pauses, and it has no idle timeout (proposed). Whoever holds
## the phone at first launch creates the code. Placeholder look (plain
## controls); the design tokens are ux-writer's, still to come.
##
## Four steps (`current`), each with "Step n of 4" and a heading:
## - WELCOME: what the parent code is for (the parent buttons along the top
##   of the screen; the child sees no text). Next.
## - CODE: the code typed twice (ParentChangeCode, as in settings); a match
##   moves on by itself (proposed), the code held in memory only; a mismatch
##   shakes, clears and starts the step's entry again. Back.
## - FORGOTTEN: what happens if the code is forgotten. Back, Next.
## - PINNING: screen pinning explained (pinning itself is chunk 20) and how
##   the parent zone shows the parent buttons. Back, Finish.
## Back (proposed) goes to the previous step; back on CODE, the code is chosen
## anew. Finish saves the code (ParentStore.set_code: its salted hash only)
## and closes setup to the game: the store has a code, so setup never shows
## again and the parent buttons can be revealed.
##
## The code is saved only when setup finishes: an interruption before that
## restarts setup from WELCOME, the entered code dropped. The app killed:
## nothing was saved, so the next launch opens setup afresh. The app going to
## the background (interrupts()): setup starts over at once.
# @spec-link [[req_parent_gate_and_access]]
# @spec-link [[req_actor_roles_and_permissions]]

enum Step { WELCOME, CODE, FORGOTTEN, PINNING }

## Each step's heading (ParentText keys).
const HEADINGS := {
	Step.WELCOME: "setup_welcome_title",
	Step.CODE: "setup_code_title",
	Step.FORGOTTEN: "setup_forgotten_title",
	Step.PINNING: "setup_pinning_title",
}
## Each step's text (ParentText keys); the code step shows the pad instead.
const TEXTS := {Step.WELCOME: "setup_welcome", Step.FORGOTTEN: "setup_forgotten", Step.PINNING: "setup_pinning"}
## Back and Next's width, mm (their height is settings' TARGET_MM: at least
## 9 x 9 mm).
const BUTTON_WIDTH_MM := 30.0
## The step counter's width, mm, at the right of the heading row.
const COUNTER_WIDTH_MM := 35.0

## The step shown.
var current := Step.WELCOME
## The labels: the step counter, the heading, the step's text.
var counter: Label = null
var heading: Label = null
var body: Label = null
## Back and Next (Finish on the last step), drawn only.
var back: Button = null
var next: Button = null
## The code step's entry (its pad, its slots, its own Back).
var code_entry: ParentChangeCode = null

var _background: ColorRect = null
## The code chosen on the code step, held until setup finishes ("" = none).
var _code := ""


## Setup's controls, all ignoring the mouse.
func _init() -> void:
	name = "Setup"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_background = ParentSettings.add_to(ColorRect.new(), self)
	_background.color = ParentSettings.BACKGROUND
	counter = ParentSettings.new_label(self)
	counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	heading = ParentSettings.new_label(self)
	body = ParentSettings.new_label(self)
	body.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	back = ParentSettings.new_button(self, "back")
	next = ParentSettings.new_button(self, "next")
	code_entry = ParentSettings.add_to(ParentChangeCode.new("setup_code", "setup_code_again"), self)
	code_entry.matched.connect(_code_chosen)
	code_entry.back_pressed.connect(_show.bind(Step.WELCOME))


## Setup from its first step, with no code chosen.
func opened() -> void:
	restart()


## Starts over: WELCOME, the entered code dropped.
# @spec-link [[req_parent_gate_and_access]]
func restart() -> void:
	_code = ""
	_show(Step.WELCOME)


## A press on setup: on the code step, the entry's; else Back or Next.
func press(at: Vector2) -> void:
	if current == Step.CODE:
		code_entry.press(at)
	elif next_rect().has_point(at):
		_forward()
	elif back.visible and back_rect().has_point(at):
		_show((current - 1) as Step)


## One simulation step: a mismatch's shake runs down.
func step() -> void:
	code_entry.step()


## Whether notification `what` interrupts setup: the app paused (going to the
## background), and on desktop (not `on_mobile`) the window losing the focus
## (proposed; a phone's focus also goes to its notification shade).
static func interrupts(what: int, on_mobile: bool) -> bool:
	if what == Node.NOTIFICATION_APPLICATION_PAUSED:
		return true
	return what == Node.NOTIFICATION_APPLICATION_FOCUS_OUT and not on_mobile


## The screen rect of Back (as laid out).
func back_rect() -> Rect2:
	return ParentSettings.rect_of(back)


## The screen rect of Next or Finish (as laid out).
func next_rect() -> Rect2:
	return ParentSettings.rect_of(next)


## The heading row (the heading, the counter at the right), the step's text
## under it, Back at the bottom-left and Next at the bottom-right; on the
## code step, the pad on the right under the heading row and the entry left
## of it.
func lay_out(view: ScreenView) -> void:
	var screen_size := view.screen_size
	_background.size = screen_size
	var margin := view.mm_to_px(ParentLayout.PROMPT_MARGIN_MM)
	var target := view.mm_to_px(ParentSettings.TARGET_MM)
	var gap := view.mm_to_px(ParentSettings.GAP_MM)
	var top := view.mm_to_px(ParentSettings.TOP_MM)
	var counter_width := view.mm_to_px(COUNTER_WIDTH_MM)
	ParentSettings.place(counter, Rect2(screen_size.x - margin - counter_width, top, counter_width, target), view)
	ParentSettings.place(heading, Rect2(margin, top, screen_size.x - 3.0 * margin - counter_width, target), view)
	var width := view.mm_to_px(BUTTON_WIDTH_MM)
	var row := screen_size.y - margin - target
	ParentSettings.place(back, Rect2(margin, row, width, target), view)
	ParentSettings.place(next, Rect2(screen_size.x - margin - width, row, width, target), view)
	var text_top := top + target + gap
	ParentSettings.place(body, Rect2(margin, text_top, screen_size.x - 2.0 * margin, row - gap - text_top), view)
	var pad_at := Vector2(screen_size.x - margin - ParentPad.size_px(view).x, text_top)
	code_entry.lay_out(Rect2(margin, text_top, pad_at.x - 2.0 * margin, screen_size.y - margin - text_top), pad_at, view)


## The app going to the background interrupts setup: it starts over, the
## entered code dropped (it was never saved).
# @spec-link [[req_parent_gate_and_access]]
func _notification(what: int) -> void:
	if gate != null and gate.state == ParentGate.State.SETUP and interrupts(what, OS.has_feature("mobile")):
		restart()


## Next: the following step; on the last, Finish.
func _forward() -> void:
	if current == Step.PINNING:
		_finish()
	else:
		_show((current + 1) as Step)


## Both entries of the code step matched: the code is held (not saved) and
## setup moves on.
func _code_chosen(code: String) -> void:
	_code = code
	_show(Step.FORGOTTEN)


## Setup finishes: now, and only now, the code is saved (the store keeps its
## salted hash only), and setup closes to the game for good.
# @spec-link [[req_parent_gate_and_access]]
# @spec-link [[req_actor_roles_and_permissions]]
# @spec-link [[rule_parent_code_not_stored_plaintext]]
func _finish() -> void:
	assert(ParentStore.is_valid_code(_code), "ParentSetup: finishing without a chosen code")
	gate.store.set_code(_code)
	_code = ""
	gate.close()


## Shows step `to` in the parent's language, laid out; entering the code
## step starts a fresh entry, any code chosen before dropped.
func _show(to: Step) -> void:
	current = to
	var lang := ParentText.language()
	if to == Step.CODE:
		_code = ""
		code_entry.begin()
	counter.text = ParentText.text("setup_step", lang).format({"n": to + 1, "total": Step.size()})
	heading.text = ParentText.text(HEADINGS[to], lang)
	body.text = ParentText.text(TEXTS[to], lang) if TEXTS.has(to) else ""
	body.visible = TEXTS.has(to)
	code_entry.visible = to == Step.CODE
	back.visible = to in [Step.FORGOTTEN, Step.PINNING]
	next.visible = to != Step.CODE
	next.text = ParentText.text("setup_done" if to == Step.PINNING else "next", lang)
	back.text = ParentText.text("back", lang)
	if gate != null and gate.simulation != null:
		lay_out(gate.simulation.view)
