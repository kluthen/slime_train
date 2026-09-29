class_name ParentSettings
extends ParentSurface
## Settings: what the settings button leads to, past the code prompt with the
## right code (ParentGate.act). They fill the screen (so every press is
## theirs: there is no outside) over the running world; nothing pauses.
## Placeholder look (plain controls); the design tokens are ux-writer's,
## still to come.
##
## Always shown: the header (the time left, live, from the session clock: the
## only place with the code prompt where it shows), the close button at the
## top-right, a warning line and a note line. Three screens (`screen`):
## - MAIN: "Change the code", and under "Delete a level's save:" one button
##   per level whose save can be deleted (levels(): v1 lists the running
##   level only, proposed);
## - CHANGE_CODE: the new code typed twice on the pad (ParentChangeCode);
## - DELETE: the second confirmation of a level save's delete
##   (ParentDeleteSave; the code was the first).
## They go back to MAIN with a short note (the code changed, the save deleted
## or not).
##
## Idle: settings close after IDLE_STEPS with no press, the warning showing
## the seconds left over the last WARNING_STEPS; any press anywhere on them
## restarts the 30 s and hides the warning. The same 30 s cover the change of
## code and the delete confirmation: when they run out there, everything
## closes back to the game. Closing settings (the close button or the 30 s)
## ends the parent's authority: the next action asks for the code again.
# @spec-link [[req_parent_gate_and_access]]
# @spec-link [[req_actor_roles_and_permissions]]

enum Screen { MAIN, CHANGE_CODE, DELETE }

## Settings close after this many simulation steps with no press (30 s:
## specs/tuning.md).
const IDLE_STEPS := 30 * Simulation.TICK_RATE
## The warning shows over the last this many steps (10 s).
const WARNING_STEPS := 10 * Simulation.TICK_RATE
## Settings' background: opaque, they fill the screen.
const BACKGROUND := Color(0.1, 0.1, 0.12)
## The space from the screen's top edge to the header row, mm.
const TOP_MM := 1.0
## A button's height, and the close button's width, mm (at least 9 x 9 mm:
## specs/tuning.md, D109).
const TARGET_MM := 10.0
const CLOSE_WIDTH_MM := 20.0
## A settings entry's width, mm.
const ENTRY_WIDTH_MM := 50.0
## A line of text's height, mm.
const LINE_MM := 5.0
## The space between two rows or two buttons, mm (at least 2 mm: D109).
const GAP_MM := 3.0

## The screen shown.
var screen := Screen.MAIN
## The labels: the time left, the closing-soon warning, the note (a
## confirmation or an error), the delete section's title.
var header: Label = null
var warning: Label = null
var note: Label = null
var delete_title: Label = null
## The buttons (drawn only: the presses come through the gate).
var close: Button = null
var change_code_button: Button = null
## Level ID -> its delete button, for the levels listed.
var level_buttons := {}
## The screens opened from settings.
var change_code: ParentChangeCode = null
var delete_save: ParentDeleteSave = null

var _background: ColorRect = null
## MAIN's controls.
var _main: Control = null
## Simulation steps left before settings close.
var _idle_left := 0


## Settings' controls and screens, all ignoring the mouse.
func _init() -> void:
	name = "Settings"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_background = ParentSettings.add_to(ColorRect.new(), self)
	_background.color = BACKGROUND
	header = ParentSettings.new_label(self)
	warning = ParentSettings.new_label(self)
	note = ParentSettings.new_label(self)
	close = ParentSettings.new_button(self, "close")
	_main = ParentSettings.add_to(Control.new(), self)
	change_code_button = ParentSettings.new_button(_main, "change_code")
	delete_title = ParentSettings.new_label(_main)
	delete_title.text = ParentText.text("delete_save", ParentText.language())
	change_code = ParentSettings.add_to(ParentChangeCode.new("new_code", "new_code_again"), self)
	change_code.matched.connect(_code_changed)
	change_code.back_pressed.connect(show_main.bind(""))
	delete_save = ParentSettings.add_to(ParentDeleteSave.new(self), self)


## Fresh settings: MAIN, no note, the 30 s from the start, the levels listed
## anew (the running level may have changed).
func opened() -> void:
	_idle_left = IDLE_STEPS
	for id in level_buttons:
		level_buttons[id].queue_free()
	level_buttons.clear()
	for id in levels():
		var button := ParentSettings.new_button(_main, "level_name")
		button.text = level_label(id)
		level_buttons[id] = button
	show_main("")


## A press anywhere on settings restarts the 30 s; on the close button it
## closes them (the parent's authority ends); else it is the shown screen's.
# @spec-link [[req_parent_gate_and_access]]
# @spec-link [[req_actor_roles_and_permissions]]
func press(at: Vector2) -> void:
	_idle_left = IDLE_STEPS
	if close_rect().has_point(at):
		gate.close()
		return
	match screen:
		Screen.MAIN:
			_press_main(at)
		Screen.CHANGE_CODE:
			change_code.press(at)
		Screen.DELETE:
			delete_save.press(at)
	_refresh()


## One simulation step: the 30 s run down (at 0 everything closes back to
## the game), the change of code's shake runs, the header and the warning
## follow.
# @spec-link [[req_parent_gate_and_access]]
func step() -> void:
	_idle_left -= 1
	if _idle_left <= 0:
		gate.close()
		return
	change_code.step()
	_refresh()


## Shows MAIN with `note_text` on the note line ("" for none).
func show_main(note_text: String) -> void:
	note.text = note_text
	_show(Screen.MAIN)


## The levels whose save can be deleted: v1 ships one level, so the running
## one only (proposed; the level catalog lists the others in debug builds
## only).
# @spec-link [[req_persistence_and_saves]]
func levels() -> PackedStringArray:
	var running: Level = gate.game.level
	return PackedStringArray() if running == null else PackedStringArray([running.level_id])


## The name the parent sees for level `id`.
func level_label(id: String) -> String:
	return ParentText.text("level_name", ParentText.language()).format({"id": id})


## Level `id`'s delete button (it must be listed).
func level_button(id: String) -> Button:
	assert(level_buttons.has(id), "ParentSettings.level_button: level '%s' isn't listed" % id)
	return level_buttons[id]


## The screen rect of the close button (as laid out).
func close_rect() -> Rect2:
	return ParentSettings.rect_of(close)


## The screen rect of "Change the code" (as laid out).
func change_code_rect() -> Rect2:
	return ParentSettings.rect_of(change_code_button)


## The screen rect of level `id`'s delete button (as laid out).
func level_rect(id: String) -> Rect2:
	return ParentSettings.rect_of(level_button(id))


## The header row (the time left, the close button at the top-right), the
## warning and note lines under it on the left, then the shown screen's
## body; on the change of code, the pad on the right under the close button.
func lay_out(view: ScreenView) -> void:
	var screen_size := view.screen_size
	_background.size = screen_size
	var margin := view.mm_to_px(ParentLayout.PROMPT_MARGIN_MM)
	var target := view.mm_to_px(TARGET_MM)
	var top := view.mm_to_px(TOP_MM)
	var close_width := view.mm_to_px(CLOSE_WIDTH_MM)
	ParentSettings.place(close, Rect2(screen_size.x - margin - close_width, top, close_width, target), view)
	ParentSettings.place(header, Rect2(margin, top, screen_size.x - 3.0 * margin - close_width, target), view)
	var pad_at := Vector2(screen_size.x - margin - ParentPad.size_px(view).x, top + target + view.mm_to_px(GAP_MM))
	var column := Rect2(margin, pad_at.y, pad_at.x - 2.0 * margin, screen_size.y - margin - pad_at.y)
	var line := view.mm_to_px(LINE_MM)
	ParentSettings.place(warning, Rect2(column.position, Vector2(column.size.x, line)), view)
	ParentSettings.place(note, Rect2(column.position + Vector2(0.0, line), Vector2(column.size.x, line)), view)
	var body := column.grow_side(SIDE_TOP, -2.0 * line)
	_lay_out_main(body, view)
	change_code.lay_out(body, pad_at, view)
	delete_save.lay_out(body, view)


## Adds `control` to `to`, ignoring the mouse; returns it.
static func add_to(control: Control, to: Control) -> Control:
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	to.add_child(control)
	return control


## A new wrapping label on `to`.
static func new_label(to: Control) -> Label:
	var label: Label = add_to(Label.new(), to)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


## A new button on `to` showing ParentText's `key` (drawn only).
static func new_button(to: Control, key: String) -> Button:
	var button: Button = add_to(Button.new(), to)
	button.text = ParentText.text(key, ParentText.language())
	button.clip_text = true
	button.focus_mode = Control.FOCUS_NONE
	return button


## Puts `control` on `rect` with the parent surfaces' font size.
static func place(control: Control, rect: Rect2, view: ScreenView) -> void:
	control.position = rect.position
	control.size = rect.size
	control.add_theme_font_size_override("font_size", ParentLayout.font_px(view))


## The screen rect of `control`, a child of a control at the screen's origin.
static func rect_of(control: Control) -> Rect2:
	return Rect2(control.position, control.size)


## MAIN: "Change the code" opens its screen; a level's button opens the
## delete confirmation for that level.
func _press_main(at: Vector2) -> void:
	if change_code_rect().has_point(at):
		note.text = ""
		change_code.begin()
		_show(Screen.CHANGE_CODE)
		return
	for id in level_buttons:
		if level_rect(id).has_point(at):
			note.text = ""
			delete_save.begin(id, level_label(id))
			_show(Screen.DELETE)
			return


## The change of code's two entries matched: `code` becomes the parent code
## at once (the store keeps only its salted hash; the old code stops working,
## the wrong tries reset) and MAIN confirms it.
# @spec-link [[req_parent_gate_and_access]]
# @spec-link [[rule_parent_code_not_stored_plaintext]]
func _code_changed(code: String) -> void:
	gate.store.set_code(code)
	show_main(ParentText.text("code_changed", ParentText.language()))


## Shows `to`'s controls only, laid out.
func _show(to: Screen) -> void:
	screen = to
	_main.visible = to == Screen.MAIN
	change_code.visible = to == Screen.CHANGE_CODE
	delete_save.visible = to == Screen.DELETE
	_refresh()
	if gate != null and gate.simulation != null:
		lay_out(gate.simulation.view)


## MAIN's controls in `body`: the entry, then the delete section's title and
## one button per level listed.
func _lay_out_main(body: Rect2, view: ScreenView) -> void:
	var target := view.mm_to_px(TARGET_MM)
	var gap := view.mm_to_px(GAP_MM)
	var width := minf(view.mm_to_px(ENTRY_WIDTH_MM), body.size.x)
	var y := body.position.y
	ParentSettings.place(change_code_button, Rect2(body.position.x, y, width, target), view)
	y += target + gap
	ParentSettings.place(delete_title, Rect2(body.position.x, y, body.size.x, view.mm_to_px(LINE_MM)), view)
	y += view.mm_to_px(LINE_MM)
	for id in level_buttons:
		ParentSettings.place(level_buttons[id], Rect2(body.position.x, y, width, target), view)
		y += target + gap


## Shows the time left and the warning. The header: the session clock's time
## left in a session (and its wind-down), the time until sunrise at bedtime,
## no session in screensaver mode; it shows here and in the code prompt only,
## behind the code. The warning: the seconds left over the last 10 s.
# @spec-link [[rule_time_left_shown_only_behind_code]]
# @spec-link [[req_parent_gate_and_access]]
func _refresh() -> void:
	var lang := ParentText.language()
	var session: Session = gate.simulation.session
	var time_left := ParentText.time_left(session.time_left_ms())
	match session.phase:
		Session.SESSION, Session.WIND_DOWN:
			header.text = ParentText.text("time_left_session", lang).format({"t": time_left})
		Session.BEDTIME:
			header.text = ParentText.text("time_left_bedtime", lang).format({"t": time_left})
		_:
			header.text = ParentText.text("no_session", lang)
	warning.visible = _idle_left <= WARNING_STEPS
	warning.text = ParentText.text("closing_soon", lang).format({"s": ceili(float(_idle_left) / Simulation.TICK_RATE)}) if warning.visible else ""
