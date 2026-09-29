class_name ParentCodeSlots
extends Control
## The digit slots of a parent code being typed on the pad (ParentPad): one
## slot per digit, shown as a dot once its digit is entered, never the digit.
## A wrong or mismatched entry shakes the row sideways (SHAKE_STEPS, visual
## only). Used by the code prompt (ParentCodePrompt) and by settings' change
## of the code (ParentChangeCode); the surface counts the steps (step()) and
## places the row (lay_out()). Its controls ignore the mouse.
# @spec-link [[req_parent_gate_and_access]]

## A shake, simulation steps (0.4 s).
const SHAKE_STEPS := 24
## The shake's reach to either side, mm, and its back-and-forths.
const SHAKE_MM := 2.0
const SHAKE_SWINGS := 3.0
## A slot's side and the space between two, mm.
const SLOT_MM := 3.5
const SLOT_GAP_MM := 2.0
## The slots' colours: a digit entered, none yet.
const SLOT_FILLED := Color(1.0, 1.0, 1.0)
const SLOT_EMPTY := Color(1.0, 1.0, 1.0, 0.2)

var _slots: Array[ColorRect] = []
## Simulation steps left of the shake.
var _shake_left := 0


## One empty slot per digit of a parent code, all ignoring the mouse.
func _init() -> void:
	name = "Slots"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in ParentStore.CODE_DIGITS:
		var slot := ColorRect.new()
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.color = SLOT_EMPTY
		_slots.append(slot)
		add_child(slot)


## Shows `count` dots, from the left.
func show_digits(count: int) -> void:
	for i in _slots.size():
		_slots[i].color = SLOT_FILLED if i < count else SLOT_EMPTY


## How many slots show a dot.
func filled() -> int:
	var count := 0
	for slot in _slots:
		count += 1 if slot.color == SLOT_FILLED else 0
	return count


## Starts a shake (a wrong or mismatched entry).
func shake() -> void:
	_shake_left = SHAKE_STEPS


## Stops any shake at once (the surface opens afresh).
func calm() -> void:
	_shake_left = 0


## One simulation step: the shake runs down.
func step() -> void:
	_shake_left = maxi(_shake_left - 1, 0)


## Whether a shake is still running.
func shaking() -> bool:
	return _shake_left > 0


## How far the row is shaken sideways now on `view`'s screen, viewport pixels
## (0 at rest): a few swings, dying down over SHAKE_STEPS.
func shake_offset(view: ScreenView) -> float:
	if _shake_left <= 0:
		return 0.0
	var done := 1.0 - float(_shake_left) / SHAKE_STEPS
	var reach := view.mm_to_px(SHAKE_MM) * (1.0 - done)
	return reach * sin(TAU * SHAKE_SWINGS * done)


## Places the row at `at` in a `box`-sized space, shaken by shake_offset(),
## the slots centred vertically.
func lay_out(at: Vector2, box: Vector2, view: ScreenView) -> void:
	var slot := view.mm_to_px(SLOT_MM)
	var step_px := slot + view.mm_to_px(SLOT_GAP_MM)
	position = at + Vector2(shake_offset(view), 0.0)
	size = box
	for i in _slots.size():
		_slots[i].position = Vector2(i * step_px, (box.y - slot) * 0.5)
		_slots[i].size = Vector2(slot, slot)
