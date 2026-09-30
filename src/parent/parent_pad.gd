class_name ParentPad
extends Control
## The code prompt's digit pad (ux D6: an in-game pad, never the phone's
## keyboard): 0-9 and a delete key, laid out like a phone's pad, three keys a
## row, every key KEY_MM square and GAP_MM apart. It only draws the keys and
## says which key is under a point: the code prompt (ParentCodePrompt) gets
## the presses from the gate and decides what a key does. Its controls ignore
## the mouse.
##
## Short screens (chunk 20): its owner gives it the height it has
## (lay_out()); when the preferred sizes don't fit it, the keys and the gaps
## shrink together just enough (proposed), never below the floors (keys
## MIN_KEY_MM square, MIN_GAP_MM apart: at least 9 x 9 mm and 2 mm,
## specs/tuning.md, D109). Below that the pad keeps its floors and overflows:
## its owner makes room (ParentLayout.rows_over_pad).
# @spec-link [[req_parent_gate_and_access]]

## The delete key's name in KEYS (and its ParentText key).
const DELETE := "delete"
## The keys row by row, three a row; "" is an empty place.
const KEYS := ["1", "2", "3", "4", "5", "6", "7", "8", "9", "", "0", DELETE]
## KEYS' columns and rows.
const COLUMNS := 3
const ROWS := 4
## A key's side, mm: preferred, and the floor.
const KEY_MM := 10.0
const MIN_KEY_MM := 9.0
## The space between two keys, mm: preferred, and the floor.
const GAP_MM := 2.5
const MIN_GAP_MM := 2.0

## Key -> its Button (drawn only).
var keys := {}
## A key's side and the space between two keys as laid out, viewport px.
var key_px := 0.0
var gap_px := 0.0


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


## A key's side and the space between two keys, mm, for a pad at most
## `height_mm` tall: KEY_MM and GAP_MM when they fit, else both shrunk
## together (the same share of the way to their floors) so the pad is
## exactly that tall, never below MIN_KEY_MM and MIN_GAP_MM.
# @spec-link [[req_parent_gate_and_access]]
static func sizes_mm(height_mm: float) -> Vector2:
	var preferred := ROWS * KEY_MM + (ROWS - 1) * GAP_MM
	var floor_mm := ROWS * MIN_KEY_MM + (ROWS - 1) * MIN_GAP_MM
	var share := clampf((height_mm - floor_mm) / (preferred - floor_mm), 0.0, 1.0)
	return Vector2(lerpf(MIN_KEY_MM, KEY_MM, share), lerpf(MIN_GAP_MM, GAP_MM, share))


## The pad's size on `view`'s screen, viewport pixels, for a pad at most
## `height_px` tall (sizes_mm(); INF: the preferred size, 0: the floors).
static func size_px(view: ScreenView, height_px := INF) -> Vector2:
	var sizes := sizes_mm(height_px / view.px_per_mm)
	var key := view.mm_to_px(sizes.x)
	var gap := view.mm_to_px(sizes.y)
	return Vector2(COLUMNS * key + (COLUMNS - 1) * gap, ROWS * key + (ROWS - 1) * gap)


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
## surface filling the screen from 0, 0) for `view`'s screen, at most
## `height_px` tall if it can (sizes_mm()).
# @spec-link [[req_parent_gate_and_access]]
func lay_out(origin: Vector2, view: ScreenView, height_px := INF) -> void:
	var sizes := sizes_mm(height_px / view.px_per_mm)
	key_px = view.mm_to_px(sizes.x)
	gap_px = view.mm_to_px(sizes.y)
	position = origin
	size = size_px(view, height_px)
	var step := key_px + gap_px
	for index in KEYS.size():
		if KEYS[index] == "":
			continue
		var button: Button = keys[KEYS[index]]
		button.position = Vector2(index % COLUMNS, index / COLUMNS) * step
		button.size = Vector2(key_px, key_px)
		button.add_theme_font_size_override("font_size", ParentLayout.font_px(view))
