class_name ParentPad
extends Control
## The code prompt's digit pad (ux D6: an in-game pad, never the phone's
## keyboard): 0-9 and a delete key, laid out like a phone's pad, three keys a
## row, every key KEY_MM square (at least 9 x 9 mm) and GAP_MM apart (at
## least 2 mm: specs/tuning.md, D109). It only draws the keys and says which
## key is under a point: the code prompt (ParentCodePrompt) gets the presses
## from the gate and decides what a key does. Its controls ignore the mouse.
# @spec-link [[req_parent_gate_and_access]]

## The delete key's name in KEYS (and its ParentText key).
const DELETE := "delete"
## The keys row by row, three a row; "" is an empty place.
const KEYS := ["1", "2", "3", "4", "5", "6", "7", "8", "9", "", "0", DELETE]
const COLUMNS := 3
## A key's side, mm.
const KEY_MM := 10.0
## The space between two keys, mm.
const GAP_MM := 2.5

## Key -> its Button (drawn only).
var keys := {}


## The pad's keys, one Button each, all ignoring the mouse.
func _init() -> void:
	name = "Pad"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for key in KEYS:
		if key == "":
			continue
		var button := Button.new()
		button.name = "Key%s" % key.to_pascal_case()
		button.text = ParentText.text(DELETE, ParentText.language()) if key == DELETE else key
		button.clip_text = true
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		keys[key] = button
		add_child(button)


## The pad's size on `view`'s screen, viewport pixels.
static func size_px(view: ScreenView) -> Vector2:
	var rows := KEYS.size() / COLUMNS
	var key := view.mm_to_px(KEY_MM)
	var gap := view.mm_to_px(GAP_MM)
	return Vector2(COLUMNS * key + (COLUMNS - 1) * gap, rows * key + (rows - 1) * gap)


## The screen rect of `key` (a digit or DELETE), the pad being laid out.
func key_rect(key: String) -> Rect2:
	var index := KEYS.find(key)
	assert(key != "" and index >= 0, "ParentPad.key_rect: no key '%s'" % key)
	var button: Button = keys[key]
	return Rect2(position + button.position, button.size)


## The key under screen point `at`, or "" (between keys, or off the pad).
func key_at(at: Vector2) -> String:
	for key in keys:
		if key_rect(key).has_point(at):
			return key
	return ""


## Dims the digit keys while they refuse digits (the wrong-code wait).
func set_refusing(refusing: bool) -> void:
	for key in keys:
		keys[key].disabled = refusing


## Places the pad with its top-left corner at `origin` (screen pixels, the
## surface filling the screen from 0, 0) for `view`'s screen.
func lay_out(origin: Vector2, view: ScreenView) -> void:
	position = origin
	size = size_px(view)
	var key := view.mm_to_px(KEY_MM)
	var step := key + view.mm_to_px(GAP_MM)
	for index in KEYS.size():
		if KEYS[index] == "":
			continue
		var button: Button = keys[KEYS[index]]
		button.position = Vector2(index % COLUMNS, index / COLUMNS) * step
		button.size = Vector2(key, key)
		button.add_theme_font_size_override("font_size", ParentLayout.font_px(view))
