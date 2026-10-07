class_name ParentDeleteSave
extends Control
## Settings' second confirmation of a level save's delete (a screen of
## ParentSettings, under its header and its 30 s; the code, entered to open
## settings, was the first): it says the level's progress will be erased and
## that the session goes on. Yes: the game deletes the running level's save,
## reloads the level fresh at once and saves it, the session carrying on
## (main.gd delete_level_save, D104); settings then show MAIN with a
## confirmation, or an error line when the delete failed (proposed). No:
## back to settings, nothing deleted. The parent store (the code, the wrong
## tries) is not a level save and stays. Its controls ignore the mouse:
## settings give it its presses.
# @spec-link [[req_persistence_and_saves]]

## The confirmation text's height, mm (two lines).
const TEXT_MM := 12.0
## A button's width, mm, and the space between yes and no, mm (at least 2 mm).
const BUTTON_WIDTH_MM := 30.0
const BUTTON_GAP_MM := 4.0

## The settings this screen belongs to.
var settings: ParentSettings = null
## The level whose save the parent picked, and its name as shown.
var level_id := ""
var level_label := ""
## The confirmation's text and its buttons (drawn only).
var text: Label = null
var yes: Button = null
var no: Button = null


## The screen's controls, for `owning_settings`, all ignoring the mouse.
func _init(owning_settings: ParentSettings) -> void:
	settings = owning_settings
	name = "DeleteSave"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	text = ParentSettings.new_label(self)
	yes = ParentSettings.new_button(self, "delete_yes")
	no = ParentSettings.new_button(self, "delete_no")


## Asks to confirm the delete of level `id`'s save (`label`: its name).
# @spec-link [[req_parent_gate_and_access]]
func begin(id: String, label: String) -> void:
	level_id = id
	level_label = label
	text.text = ParentText.text("delete_confirm", ParentText.language()).format({"level": label})


## A press on the screen: yes deletes, no goes back.
# @spec-link [[req_parent_gate_and_access]]
func press(at: Vector2) -> void:
	if yes_rect().has_point(at):
		_delete()
	elif no_rect().has_point(at):
		settings.show_main("")


## The screen rect of yes (as laid out).
func yes_rect() -> Rect2:
	return ParentSettings.rect_of(yes)


## The screen rect of no (as laid out).
func no_rect() -> Rect2:
	return ParentSettings.rect_of(no)


## In `body`: the text, then yes and no side by side under it.
func lay_out(body: Rect2, view: ScreenView) -> void:
	var height := view.mm_to_px(TEXT_MM)
	ParentSettings.place(text, Rect2(body.position, Vector2(body.size.x, height)), view)
	var y := body.position.y + height + view.mm_to_px(ParentSettings.GAP_MM)
	var width := view.mm_to_px(BUTTON_WIDTH_MM)
	var button_height := view.mm_to_px(ParentSettings.TARGET_MM)
	ParentSettings.place(yes, Rect2(body.position.x, y, width, button_height), view)
	ParentSettings.place(no, Rect2(body.position.x + width + view.mm_to_px(BUTTON_GAP_MM), y, width, button_height), view)


## Deletes the running level's save through the game (reloaded fresh, the
## session going on) and goes back to settings with the outcome. Only the
## running level is ever listed (ParentSettings.levels).
# @spec-link [[req_persistence_and_saves]]
func _delete() -> void:
	var running: Level = settings.gate.game.level
	assert(running != null and running.level_id == level_id,
			"ParentDeleteSave: only the running level's save is deleted here, not '%s'" % level_id)
	var why: String = settings.gate.game.delete_level_save()
	if why != "":
		printerr("Settings: deleting level %s's save failed: %s" % [level_id, why])
		settings.show_main(ParentText.text("delete_failed", ParentText.language()))
		return
	settings.show_main(ParentText.text("save_deleted", ParentText.language()).format({"level": level_label}))
