extends GutTest
## TestModeScript: the data-driven input script of test mode. A script is an
## array of steps such as {"tick": 10, "do": "tap", "at": [400, 300]}; it
## turns them into simulation input events, tick by tick.


func _parse(steps: Array) -> TestModeScript:
	return TestModeScript.parse(steps)


func _assert_error(steps: Array, fragment: String) -> void:
	var parsed := _parse(steps)
	assert_false(parsed.errors.is_empty(), "expected an error for %s" % [steps])
	var found := false
	for e in parsed.errors:
		if fragment in e:
			found = true
	assert_true(found, "expected an error containing '%s', got %s" % [fragment, parsed.errors])


func test_empty_script_is_valid() -> void:
	var parsed := _parse([])
	assert_eq(parsed.errors, PackedStringArray())
	assert_eq(parsed.last_tick, -1)
	assert_eq(parsed.events_at(0), [])


func test_tap_is_a_touch_down_and_up_on_the_same_tick() -> void:
	var parsed := _parse([{"tick": 10, "do": "tap", "at": [400, 300]}])
	assert_eq(parsed.errors, PackedStringArray())
	assert_eq(parsed.events_at(10), [
		Simulation.touch_down(0, Vector2(400, 300)),
		Simulation.touch_up(0, Vector2(400, 300)),
	])
	assert_eq(parsed.events_at(9), [])
	assert_eq(parsed.events_at(11), [])
	assert_eq(parsed.last_tick, 10)


func test_second_finger_and_tilt() -> void:
	var parsed := _parse([
		{"tick": 5, "do": "touch_down", "at": Vector2(1, 2)},
		{"tick": 6, "do": "touch_down", "at": [3, 4], "finger": 1},
		{"tick": 6, "do": "tilt", "degrees": -20},
		{"tick": 8, "do": "touch_up", "finger": 1},
		{"tick": 9, "do": "touch_up", "at": [1, 2]},
	])
	assert_eq(parsed.errors, PackedStringArray())
	assert_eq(parsed.events_at(5), [Simulation.touch_down(0, Vector2(1, 2))])
	assert_eq(parsed.events_at(6), [Simulation.touch_down(1, Vector2(3, 4)), Simulation.tilt(-20.0)])
	assert_eq(parsed.events_at(8), [Simulation.touch_up(1, null)])
	assert_eq(parsed.events_at(9), [Simulation.touch_up(0, Vector2(1, 2))])


func test_steps_are_ordered_by_tick_keeping_script_order_within_a_tick() -> void:
	var parsed := _parse([
		{"tick": 20, "do": "tilt", "degrees": 1},
		{"tick": 3, "do": "tilt", "degrees": 2},
		{"tick": 20, "do": "tilt", "degrees": 3},
	])
	assert_eq(parsed.events_at(20), [Simulation.tilt(1.0), Simulation.tilt(3.0)])
	assert_eq(parsed.last_tick, 20)


func test_json_numbers_are_accepted() -> void:
	# JSON has no integers: ticks and fingers arrive as whole floats.
	var steps = JSON.parse_string('[{"tick": 4, "do": "tap", "at": [10, 20], "finger": 1}]')
	var parsed := _parse(steps)
	assert_eq(parsed.errors, PackedStringArray())
	assert_eq(parsed.events_at(4)[0], Simulation.touch_down(1, Vector2(10, 20)))


func test_errors_name_the_step() -> void:
	_assert_error([{"do": "tap", "at": [1, 1]}], "step 0")
	_assert_error([{"do": "tap", "at": [1, 1]}], "tick")
	_assert_error([{"tick": -1, "do": "tilt", "degrees": 0}], "tick")
	_assert_error([{"tick": 1.5, "do": "tilt", "degrees": 0}], "tick")
	_assert_error([{"tick": 1, "do": "wiggle"}], "wiggle")
	_assert_error([{"tick": 1, "do": "tap"}], "at")
	_assert_error([{"tick": 1, "do": "tap", "at": [1]}], "at")
	_assert_error([{"tick": 1, "do": "tilt"}], "degrees")
	_assert_error([{"tick": 1, "do": "tilt", "degrees": "x"}], "degrees")
	_assert_error([{"tick": 1, "do": "tap", "at": [1, 1], "finger": -1}], "finger")
	_assert_error([{"tick": 1, "do": "tap", "at": [1, 1], "fingr": 1}], "fingr")
	_assert_error(["tap"], "step 0")
	_assert_error([{"tick": 1, "do": "tilt", "degrees": 0}, {"tick": 1}], "step 1")
