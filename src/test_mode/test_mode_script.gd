class_name TestModeScript
extends RefCounted
## A test-mode input script: plain data, so end-to-end tests are data plus
## assertions. A script is an array of steps, each a dictionary (from GDScript
## or from JSON):
##
##   {"tick": 10, "do": "tap", "at": [400, 300]}
##   {"tick": 30, "do": "touch_down", "at": [200, 200]}
##   {"tick": 31, "do": "touch_down", "at": [900, 500], "finger": 1}
##   {"tick": 40, "do": "touch_up", "finger": 1}
##   {"tick": 60, "do": "tilt", "degrees": 20}
##
## - "tick": the simulation tick the step happens on (a whole number >= 0).
##   Its events are consumed by the step that advances that tick.
## - "do": tap (a touch down and up on the same tick), touch_down, touch_up or
##   tilt.
## - "at": a screen position in viewport pixels, [x, y] or a Vector2. Needed
##   for tap and touch_down; optional for touch_up (the finger lifts where it
##   was).
## - "finger": 0 for the first finger (the default), 1 for a second one.
## - "degrees": the phone's tilt, for tilt.
##
## Steps may come in any order; steps on the same tick keep their order.
## Mistakes (a typo in a key, a missing position) are reported in `errors`
## with the step's index, and that step is left out.

const ACTIONS := {
	"tap": ["tick", "do", "at", "finger"],
	"touch_down": ["tick", "do", "at", "finger"],
	"touch_up": ["tick", "do", "at", "finger"],
	"tilt": ["tick", "do", "degrees"],
}

## What is wrong with the script, one line per problem. Empty when valid.
var errors := PackedStringArray()
## The last tick with an event, or -1 for an empty script.
var last_tick := -1

var _events := {}  # tick -> Array of Simulation input events


## Parses `steps` (an array of step dictionaries).
static func parse(steps: Array) -> TestModeScript:
	var parsed := TestModeScript.new()
	for i in steps.size():
		parsed._parse_step(i, steps[i])
	return parsed


## The Simulation input events for `tick`, in script order.
func events_at(tick: int) -> Array:
	return _events.get(tick, []).duplicate(true)


func _parse_step(index: int, step: Variant) -> void:
	if typeof(step) != TYPE_DICTIONARY:
		_error(index, "expected a dictionary such as {\"tick\": 10, \"do\": \"tap\", \"at\": [400, 300]}")
		return
	var count_before := errors.size()
	var action: Variant = step.get("do")
	if not ACTIONS.has(action):
		_error(index, "unknown action '%s' (expected tap, touch_down, touch_up or tilt)" % [action])
		return
	for key in step:
		if key not in ACTIONS[action]:
			_error(index, "unknown key '%s' for %s" % [key, action])
	var tick: Variant = _whole_number(step.get("tick"))
	if tick == null or tick < 0:
		_error(index, "'tick' must be a whole number >= 0")
	var finger: Variant = _whole_number(step.get("finger", 0))
	if finger == null or finger < 0:
		_error(index, "'finger' must be a whole number >= 0")
	var at: Variant = null
	if step.has("at") or action in ["tap", "touch_down"]:
		at = _position(step.get("at"))
		if at == null:
			_error(index, "'at' must be a screen position [x, y]")
	var degrees: Variant = null
	if action == "tilt":
		degrees = step.get("degrees")
		if typeof(degrees) not in [TYPE_INT, TYPE_FLOAT]:
			_error(index, "'degrees' must be a number")
	if errors.size() > count_before:
		return
	var events: Array = _events.get_or_add(tick, [])
	match action:
		"tap":
			events.append(Simulation.touch_down(finger, at))
			events.append(Simulation.touch_up(finger, at))
		"touch_down":
			events.append(Simulation.touch_down(finger, at))
		"touch_up":
			events.append(Simulation.touch_up(finger, at))
		"tilt":
			events.append(Simulation.tilt(float(degrees)))
	last_tick = maxi(last_tick, tick)


func _error(index: int, message: String) -> void:
	errors.append("step %d: %s" % [index, message])


## An int from an int or a whole float (JSON numbers are floats), else null.
static func _whole_number(value: Variant) -> Variant:
	if typeof(value) == TYPE_INT:
		return value
	if typeof(value) == TYPE_FLOAT and is_finite(value) and value == floorf(value):
		return int(value)
	return null


static func _position(value: Variant) -> Variant:
	if typeof(value) == TYPE_VECTOR2:
		return value
	if typeof(value) == TYPE_VECTOR2I:
		return Vector2(value)
	if typeof(value) == TYPE_ARRAY and value.size() == 2:
		if typeof(value[0]) in [TYPE_INT, TYPE_FLOAT] and typeof(value[1]) in [TYPE_INT, TYPE_FLOAT]:
			return Vector2(value[0], value[1])
	return null
