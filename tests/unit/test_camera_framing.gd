extends GutTest
## Framing zones (master spec §5.6 "Automatic framing", DoD 18, rule 19):
## a level component that sets the camera's zoom and shifts its place while
## the camera's rail point is inside it. Entering one reframes the camera
## smoothly; leaving one through the edge buttons takes a longer push (O70's
## proposed default: about 1 s of holding); a short press stays inside. The
## child never sets the zoom: the zone does. Also Level.build() collecting
## the zones into LevelData.
##
## The synthetic loop (as in test_camera.gd): an outgoing rail from (0, 0) to
## (3000, 0), left to right, then a slide back along y = 400. The rail point
## is the loop's point plus Camera.RAIL_OFFSET (y = -120 on the way out). The
## zone covers x 1000-2000 of the way out, above the loop, not the slide.

# @test-link [[req_camera_rails_and_framing]]
# @test-link [[rule_framing_zone_wherever_wider_view_needed]]

const DT := Simulation.TICK_SECONDS
const TICK_RATE := Simulation.TICK_RATE
const ZONE := "t.frame.wide"
const ZONE_BOX := Rect2(1000, -400, 1000, 400)
const ZONE_ZOOM := 0.8
const ZONE_OFFSET := Vector2(0, -100)

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


func _zones(exit_hold := -1.0) -> Dictionary:
	var data := LevelData.new("t", 1)
	data.add_framing_zone(ZONE, ZONE_BOX, ZONE_ZOOM, ZONE_OFFSET, exit_hold)
	return data.framing_zones


func _camera(loop: LoopData, near: Vector2, exit_hold := -1.0) -> Camera:
	var camera := Camera.new()
	camera.zones = _zones(exit_hold)
	camera.start(loop, [], near)
	return camera


func _run(camera: Camera, loop: LoopData, ticks: int) -> void:
	for i in ticks:
		camera.step(loop, [], DT, _tick)
		_tick += 1


func _tap(camera: Camera, side: int) -> void:
	camera.press(side, 0)
	camera.release(0)


## The rail point the camera is at (its place on the rails, before framing).
func _rail_x(camera: Camera, loop: LoopData) -> float:
	return Camera.rail_point(loop, [], camera.distance).x


# --- Level data ------------------------------------------------------------------

func test_level_build_collects_the_framing_zones() -> void:
	var level := Level.new()
	level.level_id = "unit"
	level.level_version = 1
	var loop := Loop.new()
	loop.stable_id = "start.loop"
	var segment := LoopSegment.new()
	segment.stable_id = "s1.loop"
	segment.curve = Curve2D.new()
	segment.curve.add_point(Vector2(0, 0))
	segment.curve.add_point(Vector2(500, 0))
	loop.add_child(segment)
	level.add_child(loop)
	var zone := FramingZone.new()
	zone.stable_id = "s1.frame.wide"
	zone.position = Vector2(300, -100)
	zone.size = Vector2(400, 200)
	zone.zoom = 0.75
	zone.offset = Vector2(0, -80)
	zone.exit_hold = 1.5
	level.add_child(zone)
	var plain := FramingZone.new()
	plain.stable_id = "s1.frame.plain"
	level.add_child(plain)
	autofree(level)
	assert_eq(level.build(), PackedStringArray())
	var zones := level.data.framing_zones
	assert_eq(zones.keys().size(), 2)
	assert_eq(zones["s1.frame.wide"]["box"], Rect2(100, -200, 400, 200), "its box in level px")
	assert_eq(zones["s1.frame.wide"]["zoom"], 0.75)
	assert_eq(zones["s1.frame.wide"]["offset"], Vector2(0, -80))
	assert_eq(zones["s1.frame.wide"]["exit_hold"], 1.5)
	assert_eq(zones["s1.frame.plain"]["exit_hold"], -1.0, "no exit hold of its own: the camera's")
	assert_eq(LevelData.new().framing_zones, {})


# --- Entering a zone -------------------------------------------------------------

func test_entering_a_zone_reframes_the_camera_smoothly() -> void:
	var loop := _loop()
	var camera := _camera(loop, Vector2(700, 0))
	assert_eq(camera.frame_zone, "")
	assert_eq(camera.zoom, 1.0)
	_tap(camera, 1)
	var entered := -1
	var last_zoom := camera.zoom
	var last_position := camera.position
	for i in 8 * TICK_RATE:
		_run(camera, loop, 1)
		if entered < 0 and camera.frame_zone == ZONE:
			entered = i
		assert_lte(camera.zoom, last_zoom, "the zoom only goes out, toward the zone's")
		assert_lt(last_zoom - camera.zoom, 0.01, "gently: no jump")
		assert_lt(camera.position.distance_to(last_position), Camera.PACE * DT + 10.0, "no jump in place")
		last_zoom = camera.zoom
		last_position = camera.position
	assert_gt(entered, 0, "the press carried the rail point into the zone")
	assert_almost_eq(camera.distance, 700.0 + Camera.STEP, 1e-6, "the press moved one step as usual")
	assert_almost_eq(camera.zoom, ZONE_ZOOM, 1e-6, "the zone's zoom")
	var framed := Camera.rail_point(loop, [], camera.distance) + ZONE_OFFSET
	assert_almost_eq(camera.position.x, framed.x, 1e-3)
	assert_almost_eq(camera.position.y, framed.y, 1e-3, "shifted by the zone's offset")


func test_it_takes_a_while_to_settle_on_the_zone_s_framing() -> void:
	var loop := _loop()
	var camera := _camera(loop, Vector2(700, 0))
	_tap(camera, 1)
	_run(camera, loop, TICK_RATE / 2)
	assert_eq(camera.frame_zone, ZONE)
	assert_gt(camera.zoom, ZONE_ZOOM + 0.05, "not there yet half a second in")


func test_a_camera_started_in_a_zone_shows_its_framing_at_once() -> void:
	var loop := _loop()
	var camera := _camera(loop, Vector2(1500, 0))
	assert_eq(camera.frame_zone, ZONE)
	assert_eq(camera.zoom, ZONE_ZOOM)
	assert_eq(camera.position, Camera.rail_point(loop, [], 1500.0) + ZONE_OFFSET)


func test_the_slide_under_the_zone_is_not_framed() -> void:
	var loop := _loop()
	var camera := _camera(loop, Vector2(1500, 400))
	assert_eq(camera.frame_zone, "", "the zone's box covers the way out only")
	assert_eq(camera.zoom, 1.0)


# --- Leaving a zone ----------------------------------------------------------------

func test_a_short_press_inside_a_zone_stays_inside() -> void:
	var loop := _loop()
	var camera := _camera(loop, Vector2(1800, 0))
	for press in 4:
		_tap(camera, 1)
		_run(camera, loop, 2 * TICK_RATE)
		assert_eq(camera.frame_zone, ZONE, "press %d: still framed by the zone" % press)
		assert_lt(_rail_x(camera, loop), ZONE_BOX.end.x, "the rail point never left the zone")
		assert_eq(camera.rail_left, 0.0, "and the press is spent")
	assert_gt(_rail_x(camera, loop), ZONE_BOX.end.x - Camera.PACE * DT - 1.0, "up against the zone's edge")
	assert_eq(camera.zoom, ZONE_ZOOM)


func test_a_short_press_backward_stays_inside_too() -> void:
	var loop := _loop()
	var camera := _camera(loop, Vector2(1100, 0))
	_tap(camera, -1)
	_run(camera, loop, 2 * TICK_RATE)
	assert_eq(camera.frame_zone, ZONE)
	assert_gte(_rail_x(camera, loop), ZONE_BOX.position.x)


func test_holding_about_1_s_leaves_the_zone() -> void:
	var loop := _loop()
	var camera := _camera(loop, Vector2(1950, 0))
	camera.press(1, 0)
	var left_at := -1
	for i in 3 * TICK_RATE:
		_run(camera, loop, 1)
		if _rail_x(camera, loop) >= ZONE_BOX.end.x:
			left_at = i + 1
			break
	camera.release(0)
	var exit_ticks := int(Camera.EXIT_HOLD * TICK_RATE)
	assert_between(left_at, exit_ticks, exit_ticks + 2, "held against the edge for about 1 s, then out")
	assert_almost_eq(Camera.EXIT_HOLD, 1.0, 1e-9, "O70's proposed default")
	_run(camera, loop, 6 * TICK_RATE)
	assert_eq(camera.frame_zone, "", "out of the zone's framing")
	assert_almost_eq(camera.zoom, 1.0, 1e-6, "back to the normal zoom, smoothly")
	assert_almost_eq(camera.position.y, Camera.RAIL_OFFSET.y, 1e-3, "and the normal place on the rail")


func test_a_hold_shorter_than_the_exit_time_stays_inside() -> void:
	var loop := _loop()
	var camera := _camera(loop, Vector2(1950, 0))
	camera.press(1, 0)
	_run(camera, loop, int(Camera.EXIT_HOLD * TICK_RATE) - 10)
	camera.release(0)
	_run(camera, loop, 3 * TICK_RATE)
	assert_eq(camera.frame_zone, ZONE)
	assert_lt(_rail_x(camera, loop), ZONE_BOX.end.x)


func test_a_hold_through_a_zone_is_not_slowed_down() -> void:
	# Crossing 1000 px at PACE takes longer than the exit hold: the push is
	# long enough by the time the rail point reaches the far edge.
	var loop := _loop()
	var camera := _camera(loop, Vector2(500, 0))
	camera.press(1, 0)
	_run(camera, loop, TICK_RATE / 2)
	var last := camera.distance
	for i in 2 * TICK_RATE:
		_run(camera, loop, 1)
		assert_almost_eq(camera.distance - last, Camera.PACE * DT, 1e-6, "a steady pace all through")
		last = camera.distance
	assert_gt(_rail_x(camera, loop), ZONE_BOX.end.x, "through and out")


func test_a_long_hold_let_go_near_the_edge_eases_on_out() -> void:
	var loop := _loop()
	var camera := _camera(loop, Vector2(1050, 0))
	camera.press(1, 0)
	_run(camera, loop, TICK_RATE + 2)
	assert_lt(_rail_x(camera, loop), ZONE_BOX.end.x, "held over 1 s, let go short of the edge")
	camera.release(0)
	_run(camera, loop, 3 * TICK_RATE)
	assert_gt(_rail_x(camera, loop), ZONE_BOX.end.x, "the hold earned the exit: the ease carries it out")


func test_a_zone_can_ask_for_a_longer_exit_hold() -> void:
	var loop := _loop()
	var camera := _camera(loop, Vector2(1950, 0), 2.0)
	camera.press(1, 0)
	var left_at := -1
	for i in 4 * TICK_RATE:
		_run(camera, loop, 1)
		if left_at < 0 and _rail_x(camera, loop) >= ZONE_BOX.end.x:
			left_at = i + 1
	assert_between(left_at, 2 * TICK_RATE, 2 * TICK_RATE + 2)


func test_only_the_zone_sets_the_zoom() -> void:
	var loop := _loop()
	var camera := _camera(loop, Vector2(100, 0))
	_tap(camera, 1)
	_run(camera, loop, 2 * TICK_RATE)
	camera.press(-1, 0)
	_run(camera, loop, 30)
	camera.release(0)
	_run(camera, loop, 2 * TICK_RATE)
	assert_eq(camera.zoom, 1.0, "no input outside a zone changes the zoom")
	camera.follow_call(Vector2(600, -500), _tick)
	_run(camera, loop, 12 * TICK_RATE)
	assert_eq(camera.zoom, 1.0)


func test_a_call_from_inside_a_zone_keeps_its_framing_and_comes_back_to_it() -> void:
	var loop := _loop()
	var camera := _camera(loop, Vector2(1500, 0))
	camera.follow_call(Vector2(1500, -700), _tick)
	_run(camera, loop, 3 * TICK_RATE)
	assert_eq(camera.zoom, ZONE_ZOOM, "the drag keeps the zone's zoom")
	_run(camera, loop, 20 * TICK_RATE)
	assert_eq(camera.mode, Camera.RAILS)
	assert_eq(camera.frame_zone, ZONE)
	assert_almost_eq(camera.position.y, (Camera.RAIL_OFFSET + ZONE_OFFSET).y, 1e-3, "back on the framed rail")


# --- State ---------------------------------------------------------------------------

func test_the_framing_is_in_the_dump_and_restores() -> void:
	var loop := _loop()
	var a := _camera(loop, Vector2(700, 0))
	_tap(a, 1)
	_run(a, loop, 20)
	a.press(1, 0)
	_run(a, loop, 10)
	var b := Camera.new()
	b.zones = _zones()
	b.restore(a.dump())
	assert_eq(StateHash.canonical_json(b.dump()), StateHash.canonical_json(a.dump()))
	assert_eq(b.frame_zone, ZONE)
	var tick := _tick
	_run(a, loop, 200)
	_tick = tick
	_run(b, loop, 200)
	assert_eq(StateHash.canonical_json(b.dump()), StateHash.canonical_json(a.dump()))
