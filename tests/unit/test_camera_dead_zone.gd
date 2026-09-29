extends GutTest
## The call camera's dead zone (master spec §5.6, build plan item 23.1, D101):
## a call whose point is already inside a box centred on the screen, 20 % of
## its width by 20 % of its height, happens as usual but doesn't move the
## camera; such a call during a drag stops the drag where it is. Outside the
## box the call drag is unchanged. The box is measured on the screen, so it
## holds at any zoom.
##
## The camera is driven through Camera.on_call(point, tick, view), the call
## as the Simulation hands it over, with the view the camera shows.

# @test-link [[req_camera_rails_and_framing]]
# @test-link [[req_call_mechanic]]

const DT := Simulation.TICK_SECONDS
const TICK_RATE := Simulation.TICK_RATE
const SCREEN := ScreenView.DEFAULT_SIZE
## The box's half size on the screen, px.
const HALF := SCREEN * Camera.DEAD_ZONE * 0.5

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


func _view(camera: Camera) -> ScreenView:
	var view := ScreenView.new()
	camera.apply_to(view, SCREEN)
	return view


func _run(camera: Camera, loop: LoopData, ticks: int) -> void:
	for i in ticks:
		camera.step(loop, [], DT, _tick)
		_tick += 1


## The level point shown `screen_offset` screen px from the screen's middle.
func _point(camera: Camera, screen_offset: Vector2) -> Vector2:
	var view := _view(camera)
	return view.screen_to_world(SCREEN * 0.5 + screen_offset)


func test_the_box_is_20_percent_of_the_screen_each_way() -> void:
	assert_eq(Camera.DEAD_ZONE, 0.2)
	var view := ScreenView.new(Vector2(1000, 0), 1.0, SCREEN)
	assert_true(Camera.in_dead_zone(view.screen_to_world(SCREEN * 0.5), view), "the middle")
	assert_true(Camera.in_dead_zone(view.screen_to_world(SCREEN * 0.5 + HALF - Vector2.ONE), view), "a corner, inside")
	assert_false(Camera.in_dead_zone(view.screen_to_world(SCREEN * 0.5 + Vector2(HALF.x + 1.0, 0)), view), "just right of it")
	assert_false(Camera.in_dead_zone(view.screen_to_world(SCREEN * 0.5 - Vector2(0, HALF.y + 1.0)), view), "just above it")


func test_the_box_is_measured_on_the_screen_at_any_zoom() -> void:
	for zoom in [0.5, 0.7, 0.8, 1.0 / 1.15, 1.0, 1.5]:
		var view := ScreenView.new(Vector2(1000, 0), zoom, SCREEN)
		var inside := view.screen_to_world(SCREEN * 0.5 + Vector2(HALF.x - 1.0, HALF.y - 1.0))
		var outside := view.screen_to_world(SCREEN * 0.5 + Vector2(HALF.x + 1.0, 0))
		assert_true(Camera.in_dead_zone(inside, view), "inside at zoom %s" % zoom)
		assert_false(Camera.in_dead_zone(outside, view), "outside at zoom %s" % zoom)


func test_a_call_inside_the_box_leaves_the_camera_where_it_was() -> void:
	var loop := _loop()
	var camera := _camera(loop, Vector2(1000, 0))
	var from := camera.position
	camera.on_call(_point(camera, Vector2(HALF.x - 5.0, -HALF.y + 5.0)), _tick, _view(camera))
	for i in int(Camera.DRAG_SECONDS * TICK_RATE) + 2 * TICK_RATE:
		_run(camera, loop, 1)
		assert_eq(camera.position, from, "no drag, through the answering window and after")
	assert_eq(camera.mode, Camera.RAILS, "still on the rails")


func test_a_call_just_outside_the_box_drags_as_before() -> void:
	var loop := _loop()
	var camera := _camera(loop, Vector2(1000, 0))
	var point := _point(camera, Vector2(HALF.x + 5.0, 0))
	camera.on_call(point, _tick, _view(camera))
	assert_eq(camera.mode, Camera.DRAG)
	assert_eq(camera.drag_point, point)
	var from := camera.position
	_run(camera, loop, 10)
	assert_almost_eq(camera.position.distance_to(from), Camera.DRAG_PACE * 10 * DT, 1e-2, "pulled at the drag's pace")


func test_a_call_inside_the_box_during_a_drag_stops_it_where_it_is() -> void:
	var loop := _loop()
	var camera := _camera(loop, Vector2(1000, 0))
	var far := _point(camera, Vector2(500, -250))
	camera.on_call(far, _tick, _view(camera))
	_run(camera, loop, 2 * TICK_RATE)
	assert_eq(camera.mode, Camera.DRAG)
	var stopped := camera.position
	var call_tick := _tick
	camera.on_call(_point(camera, Vector2(10, 10)), _tick, _view(camera))
	var window := int(Camera.DRAG_SECONDS * TICK_RATE)
	while _tick < call_tick + window:
		_run(camera, loop, 1)
		assert_eq(camera.position, stopped, "the drag stopped where it was, for the new call's window")
	assert_eq(camera.mode, Camera.DRAG)
	_run(camera, loop, 2)
	assert_eq(camera.mode, Camera.RETURN, "then back to the rails, as after any call")


func test_a_call_inside_the_box_while_returning_stops_the_return() -> void:
	var loop := _loop()
	var camera := _camera(loop, Vector2(1000, 0))
	camera.place(Vector2(1000, -500))
	_run(camera, loop, 1)
	assert_eq(camera.mode, Camera.RETURN)
	var stopped := camera.position
	camera.on_call(_point(camera, Vector2.ZERO), _tick, _view(camera))
	_run(camera, loop, TICK_RATE)
	assert_eq(camera.position, stopped, "held where it is")


func test_the_simulation_calls_through_the_dead_zone() -> void:
	var sim := Simulation.new(3)
	sim.slimes.terrain = TerrainSegments.new([load("res://tests/unit/slime_test_support.gd").floor_polygon()])
	var data := LevelData.new("dead-zone", 1)
	var loop := LoopData.new("t.loop")
	loop.add_segment("t.loop.out", 1, LoopData.OUTGOING, PackedVector2Array([
			Vector2(-1500, -24), Vector2(1500, -24)]))
	loop.add_segment("t.slide", 1, LoopData.RETURN, PackedVector2Array([
			Vector2(1500, -24), Vector2(1500, 400), Vector2(-1500, 400), Vector2(-1500, -24)]), "t.gate")
	data.loop = loop
	sim.load_level(data)
	# In the middle of the view: the view is held at the level's left edge.
	var slime := sim.spawn_train_slime(0, 1, 1500.0 + SCREEN.x * 0.5)
	sim.run(10)
	sim.camera.apply_to(sim.view, SCREEN)
	var from := sim.camera.position
	var at := SCREEN * 0.5 + Vector2(HALF.x - 10.0, 0)
	assert_lt(sim.view.screen_to_world(at).distance_to(sim.slimes.centre_of(slime)), sim.call_radius(),
			"the slime is in range")
	sim.push_input(Simulation.touch_down(0, at))
	sim.push_input(Simulation.touch_up(0, at))
	sim.step()
	var tap: Dictionary = sim.taps.back()
	assert_true(tap["call"], "the call happens as usual")
	assert_eq(tap["answered"], [slime], "the slimes in range answer")
	sim.run(3 * TICK_RATE)
	assert_eq(sim.camera.position, from, "but the camera stays")
