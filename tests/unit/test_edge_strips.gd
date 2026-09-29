extends GutTest
## The edge buttons as whole-height strips (chunk 23B, item 23.2, D99) and a
## thumb resting on one (item 23.8, D110), through the Simulation: a tap
## anywhere in a strip (10% of the screen's width from its edge, from the
## parent zone down to the bottom) moves the camera, never calls and
## operates no object under it; the parent zone wins in the top corners; a
## strip tap doesn't start a session; at bedtime a strip tap is an ordinary
## tap and moves nothing. A strip touch held longer than about 5 s keeps
## moving the camera but stops counting as the first touch.
##
## The world: a floor whose top is at y = 0 from x = -2000 to 2000; the loop
## runs along it at a base slime's centre height (y = -24) from x = -1500 to
## 0 (section 1, returning under the floor while gate t.gate is closed) and
## on to x = 1500 (section 2). Switch t.switch (box x -1150 to -1100, y -100
## to -50) sends the flow into basket t.basket. The first slime starts at
## x = -1000, so the camera starts 500 px along the loop.

# @test-link [[req_controls_tap_zones]]
# @test-link [[req_camera_rails_and_framing]]
# @test-link [[req_session_lifecycle]]
# @test-link [[req_denial_and_stepup_behavior]]

const Support := preload("res://tests/unit/slime_test_support.gd")
const SCREEN := ScreenView.DEFAULT_SIZE
const TICK_RATE := Simulation.TICK_RATE
const SWITCH := "t.switch"
const SWITCH_BOX := Rect2(-1150, -100, 50, 50)
const BASKET := "t.basket"
const GATE := "t.gate"
const FIRST_SPOT := Vector2(-1000, -24)
## Open ground above the floor, on screen when the view is on the first slime.
const GROUND := FIRST_SPOT + Vector2(300, -200)
const WALL := 1_700_000_000_000
## Enough ticks for a short press's one step to finish (it eases to a stop).
const SETTLE := 3 * TICK_RATE


func _level() -> LevelData:
	var data := LevelData.new("strips", 1)
	var loop := LoopData.new("t.loop")
	loop.add_segment("t.s1.out", 1, LoopData.OUTGOING, PackedVector2Array([Vector2(-1500, -24), Vector2(0, -24)]))
	loop.add_segment("t.s1.back", 1, LoopData.RETURN, PackedVector2Array([
			Vector2(0, -24), Vector2(0, 400), Vector2(-1500, 400), Vector2(-1500, -24)]), GATE)
	loop.add_segment("t.s2.out", 2, LoopData.OUTGOING, PackedVector2Array([Vector2(0, -24), Vector2(1500, -24)]))
	loop.add_segment("t.s2.back", 2, LoopData.RETURN, PackedVector2Array([
			Vector2(1500, -24), Vector2(1500, 400), Vector2(-1500, 400), Vector2(-1500, -24)]))
	data.loop = loop
	data.first_slime = {"id": "t.first-slime", "species": "A", "position": FIRST_SPOT}
	data.add_switch(SWITCH, SWITCH_BOX, BASKET, Rect2(-1100, -10, 100, 10))
	data.add_basket(BASKET, Rect2(-900, -200, 300, 200), 3,
			FrontierSets.onward_outlet(loop, GATE, 200.0, Vector2.ZERO))
	data.add_gate(GATE, Rect2(300, -200, 20, 200), Rect2(-30, -5, 60, 10))
	data.add_tap_target(SWITCH, TapDispatcher.KIND_SWITCH, SWITCH_BOX)
	data.rules.append({"when": {"object": BASKET, "event": "full"}, "then": {"object": GATE, "action": "open"}})
	return data


## The synthetic level, untimed, the view on the first slime.
func _sim(master_seed := 7) -> Simulation:
	var sim := Simulation.new(master_seed)
	sim.slimes.terrain = TerrainSegments.new([Support.floor_polygon()])
	sim.load_level(_level())
	sim.view.set_to(FIRST_SPOT, 1.0, SCREEN)
	_read(sim, 0)
	return sim


func _read(sim: Simulation, ms: int) -> void:
	sim.session.read_clock(Session.reading(WALL + ms, ms, "a"))


## A tap (down and up on the same tick) at screen point `at`, then a step.
func _tap(sim: Simulation, at: Vector2, finger := 0) -> void:
	sim.push_input(Simulation.touch_down(finger, at))
	sim.push_input(Simulation.touch_up(finger, at))
	sim.step()


func _band(sim: Simulation) -> float:
	return TapDispatcher.parent_zone_height(sim.view)


## The x of a point in the left (-1) or right (1) strip, `inset` px from
## the screen's edge.
func _strip_x(side: int, inset := 10.0) -> float:
	return inset if side < 0 else SCREEN.x - inset


## The first slime's runtime id.
func _first(sim: Simulation) -> int:
	return sim.slimes.ids()[0]


## Asserts the last tap was a press of the `side` strip that called no one,
## and the camera moved one step that way from `from`.
func _assert_pressed(sim: Simulation, side: int, from: float, what: String) -> void:
	var tap: Dictionary = sim.taps[-1]
	assert_eq(tap["zone"], TapDispatcher.ZONE_EDGE, what)
	assert_eq(tap["side"], side, what)
	assert_false(tap["call"], "%s: no call" % what)
	assert_eq(tap["answered"], [], what)
	assert_eq(tap["object"], "", what)
	sim.run(SETTLE)
	assert_almost_eq(sim.camera.distance, from + side * Camera.STEP, 1e-3, "%s: one step" % what)
	assert_eq(sim.slimes.state_of(_first(sim)), SlimeBodies.TRAIN, "%s: the first slime stays on the train" % what)


# --- 23.2: whole-height strips -------------------------------------------------------

func test_a_tap_at_the_top_middle_or_bottom_of_a_strip_moves_the_camera_and_never_calls() -> void:
	for side in [-1, 1]:
		for where in ["top", "middle", "bottom"]:
			var sim := _sim()
			var y: float = {"top": _band(sim) + 1.0, "middle": SCREEN.y * 0.5, "bottom": SCREEN.y - 1.0}[where]
			var from := sim.camera.distance
			_tap(sim, Vector2(_strip_x(side), y))
			_assert_pressed(sim, side, from, "side %d, %s" % [side, where])
			assert_eq(sim.ripples.size(), 0, "its ripple showed, then faded")


func test_a_strip_tap_leaves_a_ripple() -> void:
	var sim := _sim()
	_tap(sim, Vector2(_strip_x(1), SCREEN.y - 1.0))
	assert_eq(sim.ripples.size(), 1)
	assert_eq(sim.ripples[0]["at"], sim.view.screen_to_world(Vector2(_strip_x(1), SCREEN.y - 1.0)))


func test_the_strip_ends_a_tenth_of_the_screens_width_from_its_edge() -> void:
	var inner := SCREEN.x * 0.1
	for side in [-1, 1]:
		var inside := _sim()
		var from := inside.camera.distance
		var inset := inner - 1.0
		_tap(inside, Vector2(_strip_x(side, inset), SCREEN.y * 0.5))
		_assert_pressed(inside, side, from, "side %d, 1 px inside the inner edge" % side)
		var past := _sim()
		_tap(past, Vector2(_strip_x(side, inner + 1.0), SCREEN.y * 0.5))
		assert_eq(past.taps[-1]["zone"], TapDispatcher.ZONE_GROUND, "side %d, 1 px past it" % side)
		assert_true(past.taps[-1]["call"], "side %d: a call" % side)


func test_the_parent_zone_wins_in_the_top_corners() -> void:
	for side in [-1, 1]:
		var sim := _sim()
		var from := sim.camera.distance
		_tap(sim, Vector2(_strip_x(side), _band(sim) - 1.0))
		assert_eq(sim.taps[-1]["zone"], TapDispatcher.ZONE_PARENT, "side %d" % side)
		assert_false(sim.taps[-1]["call"])
		sim.run(SETTLE)
		assert_eq(sim.camera.distance, from, "side %d: the camera stays" % side)


func test_an_object_under_a_strip_is_not_operated() -> void:
	var sim := _sim()
	# The switch's centre shown 40 px from the screen's left edge.
	var centre := SWITCH_BOX.get_center()
	sim.view.set_to(centre + Vector2(SCREEN.x * 0.5 - 40.0, 0.0), 1.0, SCREEN)
	var at := sim.view.world_to_screen(centre)
	assert_almost_eq(at.x, 40.0, 1e-3)
	var from := sim.camera.distance
	_tap(sim, at)
	assert_false(sim.object_states[SWITCH]["flipped"], "the strip takes the whole tap")
	_assert_pressed(sim, -1, from, "on the switch, under the left strip")
	# The same switch brought inward flips: the setup can operate it.
	sim.view.set_to(centre, 1.0, SCREEN)
	_tap(sim, sim.view.world_to_screen(centre))
	assert_eq(sim.taps[-1]["kind"], TapDispatcher.KIND_SWITCH)
	assert_true(sim.object_states[SWITCH]["flipped"])


func test_on_the_reference_phone_8_mm_down_a_strip_moves_the_camera() -> void:
	var sim := _sim()
	sim.view.set_to(FIRST_SPOT, 1.0, ScreenView.REFERENCE_PHONE_SIZE)
	var from := sim.camera.distance
	_tap(sim, Vector2(20.0, sim.view.mm_to_px(8.0)))
	_assert_pressed(sim, -1, from, "8 mm down the left strip")
	_tap(sim, Vector2(20.0, sim.view.mm_to_px(6.0)))
	assert_eq(sim.taps[-1]["zone"], TapDispatcher.ZONE_PARENT, "6 mm down: the parent zone")


func test_a_strip_tap_in_screensaver_mode_does_not_start_a_session() -> void:
	var sim := _sim()
	sim.session.open(sim)
	sim.step()
	assert_eq(sim.session.phase, Session.SCREENSAVER)
	for y in [_band(sim) + 1.0, SCREEN.y * 0.5, SCREEN.y - 1.0]:
		for side in [-1, 1]:
			_tap(sim, Vector2(_strip_x(side), y))
			assert_eq(sim.taps[-1]["zone"], TapDispatcher.ZONE_EDGE, "side %d at y %s" % [side, y])
			assert_eq(sim.session.phase, Session.SCREENSAVER, "no session")
			assert_true(sim.screensaver)
			assert_eq(sim.camera.hold_side, 0, "pressed, then lifted")
	_tap(sim, sim.view.world_to_screen(GROUND))
	assert_eq(sim.session.phase, Session.SESSION, "a tap on the world still starts one")


func test_at_bedtime_a_strip_tap_moves_nothing() -> void:
	var tapped := _at_bedtime()
	var twin := _at_bedtime()
	var at := Vector2(_strip_x(1), SCREEN.y * 0.5)
	_tap(tapped, at)
	twin.step()
	var tap: Dictionary = tapped.taps[-1]
	assert_eq(tap["zone"], TapDispatcher.ZONE_GROUND, "the strips are hidden: an ordinary tap")
	assert_false(tap["call"], "and at bedtime it doesn't call")
	assert_eq(tapped.ripples.size(), twin.ripples.size() + 1, "it still ripples")
	assert_eq(tapped.ripples[-1]["tick"], tapped.tick - 1)
	tapped.run(SETTLE)
	twin.run(SETTLE)
	assert_eq(tapped.camera.distance, twin.camera.distance, "the camera didn't move for it")
	assert_eq(tapped.camera.position, twin.camera.position)
	assert_eq(tapped.camera.hold_side, 0)


## The synthetic level in a session started on open ground, at bedtime.
func _at_bedtime() -> Simulation:
	var sim := _sim()
	sim.session.open(sim)
	sim.step()
	_tap(sim, sim.view.world_to_screen(GROUND))
	assert_eq(sim.session.phase, Session.SESSION)
	_read(sim, Session.BEDTIME_MS)
	sim.step()
	assert_eq(sim.session.phase, Session.BEDTIME)
	return sim


# --- 23.8: a resting thumb --------------------------------------------------------------

## A thumb down on the right strip on the next step, held (no lift).
func _rest_thumb(sim: Simulation) -> void:
	sim.push_input(Simulation.touch_down(0, Vector2(_strip_x(1), SCREEN.y * 0.5)))
	sim.step()
	assert_eq(sim.taps[-1]["zone"], TapDispatcher.ZONE_EDGE)


func test_a_touch_after_a_strip_touch_held_5_s_calls() -> void:
	var sim := _sim()
	_rest_thumb(sim)
	sim.run(Simulation.RESTING_THUMB_TICKS)
	var before := sim.camera.position
	sim.run(TICK_RATE)
	assert_ne(sim.camera.position, before, "6 s in, the held strip still moves the camera")
	assert_eq(sim.camera.hold_side, 1)
	_tap(sim, sim.view.world_to_screen(GROUND), 1)
	assert_eq(sim.taps.size(), 2, "the second touch counts")
	var tap: Dictionary = sim.taps[-1]
	assert_eq(tap["finger"], 1)
	assert_eq(tap["zone"], TapDispatcher.ZONE_GROUND)
	assert_true(tap["call"], "it calls")
	assert_eq(sim.ripples.size(), 1, "with its ripple")
	assert_eq(sim.ripples[0]["tick"], sim.tick - 1)
	assert_true(sim.fingers_down.has(0), "the thumb is still down")
	assert_eq(sim.camera.hold_finger, 0, "and still holds the strip")


func test_a_touch_before_the_strip_touch_has_rested_5_s_gets_nothing() -> void:
	var sim := _sim()
	_rest_thumb(sim)
	sim.run(Simulation.RESTING_THUMB_TICKS - 2)
	_tap(sim, sim.view.world_to_screen(GROUND), 1)
	assert_eq(sim.taps.size(), 1, "not a tap")
	assert_eq(sim.ripples.size(), 0, "not even a ripple")
	assert_eq(sim.active_finger, 0)


func test_a_touch_that_started_before_5_s_stays_ignored_after() -> void:
	var sim := _sim()
	_rest_thumb(sim)
	sim.run(4 * TICK_RATE)
	sim.push_input(Simulation.touch_down(1, sim.view.world_to_screen(GROUND)))
	sim.run(2 * TICK_RATE)
	assert_eq(sim.taps.size(), 1, "finger 1 started at 4 s: ignored")
	_tap(sim, sim.view.world_to_screen(GROUND + Vector2(50, 0)), 2)
	assert_eq(sim.taps.size(), 1, "finger 1 is still down and still counts as down: the first-touch rule holds")
	sim.push_input(Simulation.touch_up(1, null))
	sim.step()
	_tap(sim, sim.view.world_to_screen(GROUND), 3)
	assert_eq(sim.taps.size(), 2, "with only the resting thumb down, the next touch counts")
	assert_eq(sim.taps[-1]["finger"], 3)


func test_the_touch_after_a_resting_thumb_is_the_first_touch_again() -> void:
	var sim := _sim()
	_rest_thumb(sim)
	sim.run(Simulation.RESTING_THUMB_TICKS + 1)
	sim.push_input(Simulation.touch_down(1, sim.view.world_to_screen(GROUND)))
	sim.step()
	assert_eq(sim.active_finger, 1, "the new touch counts")
	_tap(sim, sim.view.world_to_screen(GROUND + Vector2(50, 0)), 2)
	assert_eq(sim.taps.size(), 2, "while it is down, other touches get nothing")


func test_a_held_touch_that_is_not_on_a_strip_keeps_blocking() -> void:
	var sim := _sim()
	sim.push_input(Simulation.touch_down(0, sim.view.world_to_screen(GROUND)))
	sim.run(Simulation.RESTING_THUMB_TICKS + TICK_RATE)
	_tap(sim, sim.view.world_to_screen(GROUND + Vector2(50, 0)), 1)
	assert_eq(sim.taps.size(), 1, "only a strip touch rests")


func test_a_resting_thumb_is_in_the_state_and_goes_when_it_lifts() -> void:
	var sim := _sim()
	_rest_thumb(sim)
	assert_eq(sim.dump()["input"]["edge_holds"], {"0": 0}, "finger 0 pressed a strip at tick 0")
	sim.push_input(Simulation.touch_up(0, null))
	sim.step()
	assert_eq(sim.dump()["input"]["edge_holds"], {})
