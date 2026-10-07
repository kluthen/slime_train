extends GutTest
## The camera (src/sim/camera.gd, master spec §5.6, DoD 18 in part): rails
## along the loop, the edge buttons with O70's proposed press and hold (one
## fixed step at least; a steady pace while held; easing to a stop after the
## finger lifts), the call drag and the return to the rails, and a zoom no
## input changes. Also its place in the Simulation: an edge-button tap moves
## it and never calls, a call drags it, and it is in the dump.
##
## The synthetic loop: an outgoing rail from (0, 0) to (3000, 0), running
## left to right, then the section's return route (a slide) down to
## (3000, 400), right to left along y = 400 back to (0, 400), and up to the
## start. 6800 px in all; the frontier is at 3000 px.

# @test-link [[req_camera_rails_and_framing]]
# @test-link [[req_controls_tap_zones]]
# @test-link [[rule_return_route_per_section]]

const Support := preload("res://tests/unit/slime_test_support.gd")
const DT := Simulation.TICK_SECONDS
const TICK_RATE := Simulation.TICK_RATE
const LENGTH := 6800.0
const FRONTIER := 3000.0
const SCREEN := ScreenView.DEFAULT_SIZE

var _tick := 0


func before_each() -> void:
	_tick = 0


func _loop() -> LoopData:
	var loop := LoopData.new("t.loop")
	loop.add_segment("t.loop.out", 1, LoopData.OUTGOING, PackedVector2Array([
			Vector2(0, 0), Vector2(3000, 0)]))
	loop.add_segment("t.slide", 1, LoopData.RETURN, PackedVector2Array([
			Vector2(3000, 0), Vector2(3000, 400), Vector2(0, 400), Vector2(0, 0)]), "t.gate")
	return loop


func _camera(loop: LoopData, near: Vector2) -> Camera:
	var camera := Camera.new()
	camera.start(loop, [], near)
	return camera


func _run(camera: Camera, loop: LoopData, ticks: int, gates: Array = []) -> void:
	for i in ticks:
		camera.step(loop, gates, DT, _tick)
		_tick += 1


## A press and a lift on the same tick: the shortest press there is.
func _tap(camera: Camera, side: int) -> void:
	camera.press(side, 0)
	camera.release(0)


# --- Rails --------------------------------------------------------------------

func test_it_starts_on_the_rail_nearest_the_given_point() -> void:
	var loop := _loop()
	var camera := _camera(loop, Vector2(1000, 50))
	assert_eq(camera.mode, Camera.RAILS)
	assert_almost_eq(camera.distance, 1000.0, 1e-6)
	assert_eq(camera.position, Vector2(1000, 0) + Camera.RAIL_OFFSET, "on the rail, a little above the loop")
	assert_eq(camera.zoom, 1.0)


func test_a_short_press_on_the_right_button_moves_one_step_forward() -> void:
	var loop := _loop()
	var camera := _camera(loop, Vector2(1000, 0))
	_tap(camera, 1)
	var last := camera.distance
	for i in 3 * TICK_RATE:
		_run(camera, loop, 1)
		assert_true(camera.distance >= last, "never back")
		last = camera.distance
	assert_almost_eq(camera.distance, 1000.0 + Camera.STEP, 1e-6, "one fixed step")
	assert_almost_eq(camera.position.x, 1000.0 + Camera.STEP, 1e-3, "rightwards on this rail")
	assert_eq(camera.rail_left, 0.0, "and it stopped")


func test_a_press_moves_at_least_one_step() -> void:
	var loop := _loop()
	var camera := _camera(loop, Vector2(1000, 0))
	camera.press(1, 0)
	_run(camera, loop, 5)
	camera.release(0)
	_run(camera, loop, 3 * TICK_RATE)
	assert_gt(camera.distance, 1000.0 + Camera.STEP, "held 5 ticks: more than one step")
	assert_lt(camera.distance, 1000.0 + Camera.STEP + 5 * Camera.PACE * DT + 1e-6)


func test_the_left_button_moves_backward_and_wraps_round_the_loop() -> void:
	var loop := _loop()
	var camera := _camera(loop, Vector2(100, 0))
	_tap(camera, -1)
	_run(camera, loop, 3 * TICK_RATE)
	# Positions are Vector2 (single precision): millipixel tolerances.
	assert_almost_eq(camera.distance, LENGTH - (Camera.STEP - 100.0), 1e-3,
			"back past the start of the loop, onto the end of the return route")
	# The return route's last leg climbs from (0, 400) to (0, 0): STEP - 100
	# px before its end is that high above y = 0.
	assert_almost_eq(camera.position.x, 0.0, 1e-3)
	assert_almost_eq(camera.position.y, (Camera.STEP - 100.0) + Camera.RAIL_OFFSET.y, 1e-3)


func test_holding_keeps_moving_at_a_steady_pace_then_eases_to_a_stop() -> void:
	var loop := _loop()
	var camera := _camera(loop, Vector2(0, 0))
	camera.press(1, 0)
	_run(camera, loop, TICK_RATE)
	var last := camera.distance
	for i in TICK_RATE:
		_run(camera, loop, 1)
		assert_almost_eq(camera.distance - last, Camera.PACE * DT, 1e-6, "a steady pace while held")
		last = camera.distance
	camera.release(0)
	var released_at := camera.distance
	var speed := Camera.PACE * DT
	for i in 3 * TICK_RATE:
		_run(camera, loop, 1)
		var moved := camera.distance - last
		assert_true(moved >= 0.0, "still forward")
		assert_true(moved <= speed + 1e-6, "never faster: it eases")
		speed = moved
		last = camera.distance
	assert_eq(speed, 0.0, "stopped")
	assert_gt(camera.distance, released_at, "it glides on after the finger lifts")
	assert_true(camera.distance <= released_at + Camera.STEP + 1e-6, "by one step at most")


func test_a_press_the_other_way_turns_back() -> void:
	var loop := _loop()
	var camera := _camera(loop, Vector2(1000, 0))
	_tap(camera, 1)
	_run(camera, loop, 10)
	var turned_at := camera.distance
	_tap(camera, -1)
	_run(camera, loop, 3 * TICK_RATE)
	assert_almost_eq(camera.distance, turned_at - Camera.STEP, 1e-6)


func test_the_right_button_is_forward_on_a_rail_running_right_to_left() -> void:
	# The slide's bottom runs right to left: forward moves the view left.
	var loop := _loop()
	var camera := _camera(loop, Vector2(2000, 400))
	assert_almost_eq(camera.distance, FRONTIER + 400.0 + 1000.0, 1e-6)
	camera.press(1, 0)
	var last_distance := camera.distance
	var last_x := camera.position.x
	for i in TICK_RATE:
		_run(camera, loop, 1)
		assert_gt(camera.distance, last_distance, "the loop distance grows")
		assert_lt(camera.position.x, last_x, "the view moves left on screen")
		last_distance = camera.distance
		last_x = camera.position.x
	camera.release(0)
	camera.press(-1, 0)
	_run(camera, loop, 1)
	assert_lt(camera.distance, last_distance, "the left button is backward")
	assert_gt(camera.position.x, last_x, "which is rightwards on this rail")


func test_forward_on_the_return_route_rounds_the_frontier_and_heads_back_to_the_start() -> void:
	var loop := _loop()
	var camera := _camera(loop, Vector2(2500, 0))
	camera.press(1, 0)
	var ticks := ceili((LENGTH - 2500.0 + 200.0) / Camera.PACE * TICK_RATE)
	var max_x := -INF
	var on_slide_at := -1
	var wrapped_at := -1
	var last := camera.distance
	for i in ticks:
		_run(camera, loop, 1)
		max_x = maxf(max_x, camera.position.x)
		if on_slide_at < 0 and camera.distance > FRONTIER + 100.0:
			on_slide_at = i
		if wrapped_at < 0 and camera.distance < last:
			wrapped_at = i
		last = camera.distance
	assert_almost_eq(max_x, FRONTIER, 1e-3, "right up to the frontier turn")
	assert_gt(on_slide_at, -1, "then onto the return route")
	assert_gt(wrapped_at, on_slide_at, "and round to the start of the loop")
	assert_lt(camera.distance, 400.0, "on the outgoing rail again")
	assert_almost_eq(camera.position.y, Camera.RAIL_OFFSET.y, 1e-3)


func test_a_gate_opening_keeps_the_camera_where_it_is() -> void:
	var loop := LoopData.new("t.loop")
	loop.add_segment("t.s1.out", 1, LoopData.OUTGOING, PackedVector2Array([Vector2(0, 0), Vector2(3000, 0)]))
	loop.add_segment("t.s1.slide", 1, LoopData.RETURN, PackedVector2Array([
			Vector2(3000, 0), Vector2(3000, 400), Vector2(0, 400), Vector2(0, 0)]), "t.gate1")
	loop.add_segment("t.s2.out", 2, LoopData.OUTGOING, PackedVector2Array([Vector2(3000, 0), Vector2(5000, 0)]))
	loop.add_segment("t.s2.slide", 2, LoopData.RETURN, PackedVector2Array([
			Vector2(5000, 0), Vector2(5000, 400), Vector2(0, 400), Vector2(0, 0)]))
	var on_rail := _camera(loop, Vector2(2000, 0))
	var on_slide := _camera(loop, Vector2(1000, 400))
	var slide_point := on_slide.position
	_run(on_rail, loop, 1, ["t.gate1"])
	_run(on_slide, loop, 1, ["t.gate1"])
	assert_almost_eq(on_rail.distance, 2000.0, 1e-6)
	assert_eq(on_rail.position, Vector2(2000, 0) + Camera.RAIL_OFFSET)
	assert_eq(on_slide.position, slide_point, "the camera doesn't jump")
	assert_almost_eq(on_slide.distance, 5000.0 + 400.0 + 4000.0, 1e-6, "on the new section's return route")


# --- Call drag ----------------------------------------------------------------

func test_a_call_drags_the_camera_slowly_toward_the_call_point() -> void:
	var loop := _loop()
	var camera := _camera(loop, Vector2(1000, 0))
	var point := Vector2(1300, -600)
	camera.follow_call(point, _tick)
	var last := camera.position
	for i in TICK_RATE:
		_run(camera, loop, 1)
		assert_almost_eq(camera.position.distance_to(last), Camera.DRAG_PACE * DT, 1e-3, "slow and steady")
		assert_lt(camera.position.distance_to(point), last.distance_to(point), "toward the point")
		last = camera.position
	assert_eq(camera.mode, Camera.DRAG)
	_run(camera, loop, 3 * TICK_RATE)
	assert_eq(camera.position, point, "until it is centred on the point")
	assert_eq(camera.zoom, 1.0)


func test_after_the_call_it_glides_back_to_the_nearest_rail_point() -> void:
	var loop := _loop()
	var camera := _camera(loop, Vector2(1000, 0))
	var point := Vector2(1300, -600)
	camera.follow_call(point, _tick)
	_run(camera, loop, int(Camera.DRAG_SECONDS * TICK_RATE))
	assert_eq(camera.mode, Camera.DRAG, "pulled for the call's whole 8 s")
	_run(camera, loop, 1)
	assert_eq(camera.mode, Camera.RETURN, "the call is over: back to the rails")
	var target := Vector2(1300, 0) + Camera.RAIL_OFFSET
	var last := camera.position
	var ticks := 0
	while camera.mode == Camera.RETURN and ticks < 10 * TICK_RATE:
		_run(camera, loop, 1)
		ticks += 1
		assert_true(camera.position.distance_to(last) <= Camera.DRAG_PACE * DT + 1e-3, "at the same slow pace")
		last = camera.position
	assert_eq(camera.mode, Camera.RAILS)
	assert_eq(camera.position, target, "on the rail point nearest where the call left it")
	assert_almost_eq(camera.distance, 1300.0, 1e-6)
	assert_almost_eq(float(ticks), ceilf((point.distance_to(target)) / (Camera.DRAG_PACE * DT)), 1.0)


# A zoom of 0 or less can only be a caller bug: place() refuses it loudly and
# leaves the camera as it was.
func test_place_refuses_a_zoom_of_0_or_less_loudly() -> void:
	var loop := _loop()
	var camera := _camera(loop, Vector2(1000, 0))
	var before := camera.position
	var mode := camera.mode
	var zoom := camera.zoom
	for bad in [0.0, -0.5]:
		camera.place(Vector2(1500, -400), bad)
		assert_push_error("zoom must be above 0")
		assert_eq(camera.position, before, "zoom %s: the camera stays put" % bad)
		assert_eq(camera.zoom, zoom, "zoom %s: the old zoom is kept" % bad)
		assert_eq(camera.mode, mode, "zoom %s: the mode is kept" % bad)


func test_a_new_call_replaces_the_point_and_restarts_the_drag() -> void:
	var loop := _loop()
	var camera := _camera(loop, Vector2(1000, 0))
	camera.follow_call(Vector2(1300, -600), _tick)
	_run(camera, loop, 5 * TICK_RATE)
	var second := Vector2(700, -500)
	camera.follow_call(second, _tick)
	_run(camera, loop, 5 * TICK_RATE)
	assert_eq(camera.mode, Camera.DRAG, "10 s after the first call, 5 s after the second")
	assert_eq(camera.drag_point, second)
	_run(camera, loop, 3 * TICK_RATE + 1)
	assert_eq(camera.mode, Camera.RETURN)


func test_an_edge_press_off_the_rails_snaps_back_to_the_rails_smoothly() -> void:
	var loop := _loop()
	var camera := _camera(loop, Vector2(1000, 0))
	camera.follow_call(Vector2(1300, -600), _tick)
	_run(camera, loop, 2 * TICK_RATE)
	var off := camera.position
	var nearest := loop.closest(off - Camera.RAIL_OFFSET)["distance"] as float
	_tap(camera, 1)
	var last := camera.position
	_run(camera, loop, 1)
	assert_eq(camera.mode, Camera.RAILS, "the press takes it back to the rails")
	for i in 3 * TICK_RATE:
		assert_true(camera.position.distance_to(last) <= (Camera.CATCH_UP + Camera.PACE) * DT + 1e-3,
				"without a jump")
		last = camera.position
		_run(camera, loop, 1)
	assert_eq(camera.rail_gap, Vector2.ZERO)
	assert_almost_eq(camera.distance, nearest + Camera.STEP, 1e-6, "one step on from the nearest rail point")
	assert_eq(camera.position, loop.position_at(camera.distance) + Camera.RAIL_OFFSET)


# --- Zoom, the buttons, the view ------------------------------------------------

func test_no_input_changes_the_zoom() -> void:
	var loop := _loop()
	var camera := _camera(loop, Vector2(1000, 0))
	_tap(camera, 1)
	_run(camera, loop, 30)
	camera.press(-1, 0)
	_run(camera, loop, 90)
	camera.release(0)
	camera.follow_call(Vector2(1300, -600), _tick)
	_run(camera, loop, 12 * TICK_RATE)
	_tap(camera, 1)
	_run(camera, loop, 60)
	assert_eq(camera.zoom, 1.0, "the child never controls the zoom (DoD 18)")


func test_the_edge_buttons_show_by_default() -> void:
	assert_true(Camera.new().edge_buttons_visible, "hidden only at bedtime (chunk 17)")


func test_the_view_follows_the_camera_and_stops_at_the_level_s_left_edge() -> void:
	var loop := _loop()
	var camera := _camera(loop, Vector2(1000, 0))
	var view := ScreenView.new()
	camera.apply_to(view, SCREEN)
	assert_eq(view.centre, camera.position)
	assert_eq(view.zoom, 1.0)
	assert_eq(view.screen_size, SCREEN)
	var at_start := _camera(loop, Vector2(0, 0))
	at_start.apply_to(view, SCREEN)
	assert_eq(view.centre, Vector2(SCREEN.x * 0.5, Camera.RAIL_OFFSET.y), "the view never shows left of x = 0")
	at_start.zoom = 0.5
	at_start.apply_to(view, SCREEN)
	assert_eq(view.centre.x, SCREEN.x, "half the zoom, twice the width")


# --- Determinism and the dump ----------------------------------------------------

func _scripted(camera: Camera, loop: LoopData) -> void:
	camera.press(1, 0)
	_run(camera, loop, 70)
	camera.release(0)
	_run(camera, loop, 20)
	camera.follow_call(Vector2(900, -300), _tick)
	_run(camera, loop, 200)
	_tap(camera, -1)
	_run(camera, loop, 45)


func test_the_same_input_gives_the_same_camera() -> void:
	var loop := _loop()
	var a := _camera(loop, Vector2(500, 0))
	_scripted(a, loop)
	_tick = 0
	var b := _camera(loop, Vector2(500, 0))
	_scripted(b, loop)
	assert_eq(StateHash.canonical_json(a.dump()), StateHash.canonical_json(b.dump()))


func test_a_restored_camera_carries_on_the_same() -> void:
	var loop := _loop()
	var a := _camera(loop, Vector2(500, 0))
	a.press(1, 0)
	_run(a, loop, 30)
	a.follow_call(Vector2(900, -300), _tick)
	_run(a, loop, 30)
	var b := Camera.new()
	b.restore(a.dump())
	assert_eq(StateHash.canonical_json(b.dump()), StateHash.canonical_json(a.dump()))
	# The JSON form (vectors as [x, y]) restores too, to its printed precision.
	var c := Camera.new()
	c.restore(JSON.parse_string(StateHash.canonical_json(a.dump())))
	assert_eq(c.mode, a.mode)
	assert_almost_eq(c.distance, a.distance, 1e-9)
	assert_eq(c.position, a.position)
	assert_eq(c.drag_point, a.drag_point)
	var tick := _tick
	_run(a, loop, 700)
	_tick = tick
	_run(b, loop, 700)
	assert_eq(StateHash.canonical_json(b.dump()), StateHash.canonical_json(a.dump()))


# --- In the Simulation ---------------------------------------------------------------

## A simulation on a floor at y = 0 with the synthetic loop's outgoing rail
## at a base slime's centre height.
func _sim() -> Simulation:
	var sim := Simulation.new(3)
	sim.slimes.terrain = TerrainSegments.new([Support.floor_polygon()])
	var data := LevelData.new("camera", 1)
	var loop := LoopData.new("t.loop")
	loop.add_segment("t.loop.out", 1, LoopData.OUTGOING, PackedVector2Array([
			Vector2(-1500, -24), Vector2(1500, -24)]))
	loop.add_segment("t.slide", 1, LoopData.RETURN, PackedVector2Array([
			Vector2(1500, -24), Vector2(1500, 400), Vector2(-1500, 400), Vector2(-1500, -24)]), "t.gate")
	data.loop = loop
	sim.load_level(data)
	return sim


func _right_button() -> Vector2:
	return TapDispatcher.edge_button_rect(1, ScreenView.new(Vector2.ZERO, 1.0, SCREEN)).get_center()


func test_the_simulation_starts_its_camera_on_the_rails() -> void:
	var sim := _sim()
	assert_eq(sim.camera.mode, Camera.RAILS)
	assert_eq(sim.camera.position, Vector2(-1500, -24) + Camera.RAIL_OFFSET, "no first slime: the loop's start")


func test_an_edge_button_tap_moves_the_camera_and_never_calls() -> void:
	var sim := _sim()
	var slime := sim.spawn_train_slime(0, 1, 100.0)
	sim.camera.apply_to(sim.view, SCREEN)
	var from := sim.camera.distance
	sim.push_input(Simulation.touch_down(0, _right_button()))
	sim.push_input(Simulation.touch_up(0, null))
	sim.run(3 * TICK_RATE)
	assert_almost_eq(sim.camera.distance, from + Camera.STEP, 1e-6, "one step forward")
	var tap: Dictionary = sim.taps.back()
	assert_eq(tap["zone"], TapDispatcher.ZONE_EDGE)
	assert_false(tap["call"], "an edge button never calls")
	assert_eq(tap["answered"], [])
	assert_eq(sim.slimes.state_of(slime), SlimeBodies.TRAIN)
	assert_eq(sim.ripples.size(), 0, "the ripple has faded")


func test_holding_an_edge_button_keeps_the_camera_moving_until_the_finger_lifts() -> void:
	var sim := _sim()
	var from := sim.camera.distance
	sim.push_input(Simulation.touch_down(0, _right_button()))
	sim.run(TICK_RATE)
	assert_almost_eq(sim.camera.distance, from + Camera.PACE, 1e-6, "a second at a steady pace")
	sim.push_input(Simulation.touch_up(0, null))
	sim.run(3 * TICK_RATE)
	assert_between(sim.camera.distance, from + Camera.PACE, from + Camera.PACE + Camera.STEP)
	var stopped := sim.camera.distance
	sim.run(TICK_RATE)
	assert_eq(sim.camera.distance, stopped, "stopped once the finger lifted")


func test_a_second_finger_on_an_edge_button_does_nothing() -> void:
	var sim := _sim()
	var from := sim.camera.distance
	sim.push_input(Simulation.touch_down(0, Vector2(600, 600)))
	sim.push_input(Simulation.touch_down(1, _right_button()))
	sim.run(TICK_RATE)
	assert_eq(sim.camera.distance, from, "the first touch wins")


func test_a_call_in_the_simulation_drags_the_camera() -> void:
	var sim := _sim()
	sim.camera.apply_to(sim.view, SCREEN)
	var at := Vector2(700, 200)
	sim.push_input(Simulation.touch_down(0, at))
	sim.push_input(Simulation.touch_up(0, at))
	sim.step()
	assert_true(sim.taps.back()["call"])
	assert_eq(sim.camera.mode, Camera.DRAG)
	assert_eq(sim.camera.drag_point, sim.view.screen_to_world(at))
	assert_eq(sim.camera.zoom, 1.0)


func test_the_camera_is_in_the_dump() -> void:
	var sim := _sim()
	var other := _sim()
	assert_eq(sim.state_hash(), other.state_hash())
	other.push_input(Simulation.touch_down(0, _right_button()))
	other.push_input(Simulation.touch_up(0, null))
	sim.step()
	other.step()
	assert_eq(other.dump()["camera"]["mode"], Camera.RAILS)
	# The input log differs too; compare the camera alone.
	assert_ne(StateHash.canonical_json(sim.dump()["camera"]), StateHash.canonical_json(other.dump()["camera"]))
