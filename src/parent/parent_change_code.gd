class_name ParentChangeCode
extends Control
## A new parent code typed twice on the pad (ParentPad, the code prompt's),
## its digits shown as dots (ParentCodeSlots), never the digits. Used by
## settings' change of the code (a screen of ParentSettings, under its header
## and its 30 s) and by setup's code step (ParentSetup). The 6th digit ends an
## entry (as in the code prompt): after the first, the second is asked; when
## both match it emits `matched` with the code and its owner decides what
## becomes of it (settings: the store takes it at once; setup: it is held
## until setup finishes). A mismatch shakes the slots, clears the entry and
## starts again from the first entry (proposed). "Back" emits `back_pressed`.
## Its controls ignore the mouse: the owner gives it its presses.
# @spec-link [[req_parent_gate_and_access]]

## Both entries matched: `code` is the new parent code (6 digits).
signal matched(code: String)
## "Back" was pressed.
signal back_pressed

## The left column's rows above the back button, mm.
const TITLE_MM := 6.0
const SLOTS_ROW_MM := 6.0
const MESSAGE_MM := 6.0
## The back button's width, mm.
const BACK_WIDTH_MM := 30.0

## The ParentText keys of the title: the first entry asked, the second.
var first_key := ""
var again_key := ""
## The digits of the entry being typed (never shown).
var entry := ""
## The labels: which entry is asked, the mismatch's message.
var title: Label = null
var message: Label = null
## The back button (drawn only) and the pad.
var back: Button = null
var pad: ParentPad = null

var _slots: ParentCodeSlots = null
## The first entry once typed, "" while it is being typed.
var _first := ""


## The screen's controls, all ignoring the mouse; its title shows ParentText's
## `first_title_key` while the first entry is asked, `again_title_key` for the
## second.
func _init(first_title_key: String, again_title_key: String) -> void:
	assert(ParentText.TABLE.has(first_title_key) and ParentText.TABLE.has(again_title_key),
			"ParentChangeCode: unknown title keys '%s', '%s'" % [first_title_key, again_title_key])
	first_key = first_title_key
	again_key = again_title_key
	name = "ChangeCode"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	title = ParentSettings.new_label(self)
	message = ParentSettings.new_label(self)
	_slots = ParentSettings.add_to(ParentCodeSlots.new(), self)
	back = ParentSettings.new_button(self, "back")
	pad = ParentSettings.add_to(ParentPad.new(), self)


## A fresh change: the first entry asked, no digits, no message, no shake.
func begin() -> void:
	entry = ""
	_first = ""
	message.text = ""
	_slots.calm()
	_refresh()


## A press on the screen: "Back" is the owner's (back_pressed); a key enters
## or deletes a digit, the 6th ending the entry.
func press(at: Vector2) -> void:
	if back_rect().has_point(at):
		back_pressed.emit()
		return
	var key := pad.key_at(at)
	if key == "":
		return
	if key == ParentPad.DELETE:
		entry = entry.left(entry.length() - 1)
	else:
		entry += key
	if entry.length() == ParentStore.CODE_DIGITS:
		_submit()
	else:
		_refresh()


## One simulation step: the shake runs down.
func step() -> void:
	_slots.step()


## Whether a mismatch's shake is still running.
func shaking() -> bool:
	return _slots.shaking()


## How many slots show a dot: one per digit entered.
func filled_slots() -> int:
	return _slots.filled()


## The screen rect of the back button (as laid out).
func back_rect() -> Rect2:
	return ParentSettings.rect_of(back)


## The pad with its top-left corner at `pad_at`; in `column` (left of it):
## the title, the slots, the message, and the back button level with the
## pad's last row.
func lay_out(column: Rect2, pad_at: Vector2, view: ScreenView) -> void:
	pad.lay_out(pad_at, view)
	var y := column.position.y
	ParentSettings.place(title, Rect2(column.position.x, y, column.size.x, view.mm_to_px(TITLE_MM)), view)
	y += view.mm_to_px(TITLE_MM)
	_slots.lay_out(Vector2(column.position.x, y), Vector2(column.size.x, view.mm_to_px(SLOTS_ROW_MM)), view)
	y += view.mm_to_px(SLOTS_ROW_MM)
	ParentSettings.place(message, Rect2(column.position.x, y, column.size.x, view.mm_to_px(MESSAGE_MM)), view)
	var key := view.mm_to_px(ParentPad.KEY_MM)
	var bottom := pad_at.y + ParentPad.size_px(view).y
	var width := minf(view.mm_to_px(BACK_WIDTH_MM), column.size.x)
	ParentSettings.place(back, Rect2(column.position.x, bottom - key, width, key), view)


## Ends an entry: the first is kept and the second asked; a second that
## matches is handed to the owner (matched); a mismatch shakes and starts
## again.
# @spec-link [[req_parent_gate_and_access]]
func _submit() -> void:
	var code := entry
	entry = ""
	if _first == "":
		_first = code
		message.text = ""
		_refresh()
		return
	if code != _first:
		_first = ""
		_slots.shake()
		message.text = ParentText.text("codes_differ", ParentText.language())
		_refresh()
		return
	_first = ""
	_refresh()
	matched.emit(code)


## Shows the dots and which entry is asked.
func _refresh() -> void:
	_slots.show_digits(entry.length())
	title.text = ParentText.text(first_key if _first == "" else again_key, ParentText.language())
