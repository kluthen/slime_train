extends GutTest
## End-to-end on the test level: the call camera's dead zone (master spec
## §5.6, build plan item 23.1, D101) through the real game scene and test
## mode. A tap inside the box centred on the screen (20 % of its width by
## 20 % of its height) calls the slimes in range and leaves the camera where
## it was until the answering window ends; a tap just outside it drags the
## camera as before; the box holds at every framing zone's zoom (it is
## measured on the screen); a tap inside the box during a drag stops the
## drag where it is.

# @test-link [[req_camera_rails_and_framing]]
# @test-link [[req_call_mechanic]]

const MAIN_SCENE := "res://src/main.tscn"
const SEED := 23
const TICK_RATE := Simulation.TICK_RATE
const SCREEN := ScreenView.DEFAULT_SIZE
## The box's half size on the screen, px.
const HALF := SCREEN * Camera.DEAD_ZONE * 0.5
## How far inside or outside the box's edge the taps land, screen px.
const MARGIN := 8.0


func _boot(fixture := "") -> Node:
	var game: Node = load(MAIN_SCENE).instantiate()
	add_child_autofree(game)
	var run := {"seed": SEED, "time_scale": 0}
	if fixture != "":
		run["fixture"] = fixture
	assert_eq(game.enable_test_mode(run), PackedStringArray())
	return game


## Taps screen point `at` (a touch down and up), dispatched on the next tick,
## which this runs. Returns the tap's record.
func _tap(game: Node, at: Vector2) -> Dictionary:
	var sim: Simulation = game.simulation
	game.sync_view()
	sim.push_input(Simulation.touch_down(0, at))
	sim.push_input(Simulation.touch_up(0, at))
	game.test_mode.run_ticks(1)
	return sim.taps[-1]


## The first of `offsets` (screen px from the screen's middle) where a tap
## lands on open ground, the level's objects where they are now.
func _open_ground(game: Node, offsets: Array) -> Vector2:
	var sim: Simulation = game.simulation
	game.sync_view()
	for offset in offsets:
		var at: Vector2 = SCREEN * 0.5 + offset
		if TapDispatcher.dispatch(at, sim.view, Sleepers.tap_targets(sim))["zone"] == TapDispatcher.ZONE_GROUND:
			return at
	fail_test("no open ground at %s" % [offsets])
	return SCREEN * 0.5


## Just inside the box's corners, then its sides.
func _inside() -> Array:
	var x := HALF.x - MARGIN
	var y := HALF.y - MARGIN
	return [Vector2(x, y), Vector2(-x, y), Vector2(x, -y), Vector2(-x, -y), Vector2(x, 0), Vector2(-x, 0)]


## Just outside the box, on each side.
func _outside() -> Array:
	var x := HALF.x + MARGIN
	var y := HALF.y + MARGIN
	return [Vector2(x, 0), Vector2(-x, 0), Vector2(0, y), Vector2(0, -y)]


func test_a_tap_inside_the_box_calls_and_leaves_the_camera_where_it_was() -> void:
	var game := _boot()
	var sim: Simulation = game.simulation
	var slime: int = sim.slimes.ids()[0]
	game.test_mode.run_ticks(TICK_RATE)
	var from := sim.camera.position
	# Inside the box, on the slime's side of the screen's middle.
	var side := signf(sim.view.world_to_screen(sim.slimes.centre_of(slime)).x - SCREEN.x * 0.5)
	var tap := _tap(game, SCREEN * 0.5 + Vector2(side * (HALF.x - MARGIN), 0))
	assert_eq(tap["zone"], TapDispatcher.ZONE_GROUND)
	assert_true(tap["call"], "the call happens")
	assert_eq(tap["answered"], [slime], "the slime in range answers")
	var window := int(Camera.DRAG_SECONDS * TICK_RATE)
	for i in window + 2 * TICK_RATE:
		game.test_mode.run_ticks(1)
		assert_eq(sim.camera.position, from, "the camera stays, through the answering window and after")
	assert_eq(sim.camera.mode, Camera.RAILS)


func test_a_tap_just_outside_the_box_drags_the_camera() -> void:
	var game := _boot()
	var sim: Simulation = game.simulation
	game.test_mode.run_ticks(TICK_RATE)
	var from := sim.camera.position
	var tap := _tap(game, _open_ground(game, _outside()))
	assert_true(tap["call"])
	assert_eq(sim.camera.mode, Camera.DRAG, "the call drags the camera")
	game.test_mode.run_ticks(TICK_RATE / 2)
	assert_gt(sim.camera.position.distance_to(from), 1.0, "it moves")


func test_the_box_holds_at_every_framing_zone_s_zoom() -> void:
	var game := _boot("gate2-open")
	var sim: Simulation = game.simulation
	var zones := sim.level.framing_zones
	assert_gt(zones.size(), 6, "every section's zones (7 when written), the loop open to section 3")
	var ids: Array = zones.keys()
	ids.sort()
	for id in ids:
		var box: Rect2 = zones[id]["box"]
		sim.camera.start(sim.level.loop, sim.train.open_gates, box.get_center())
		assert_eq(sim.camera.frame_zone, id, "on the rails in %s" % id)
		assert_eq(sim.camera.zoom, float(zones[id]["zoom"]), "at its zoom")
		var from := sim.camera.position
		var inside := _tap(game, _open_ground(game, _inside()))
		assert_eq(inside["zone"], TapDispatcher.ZONE_GROUND, "open ground in %s" % id)
		assert_true(inside["call"], "a call in %s" % id)
		game.test_mode.run_ticks(TICK_RATE)
		assert_eq(sim.camera.mode, Camera.RAILS, "inside the box in %s: no drag" % id)
		assert_eq(sim.camera.position, from, "the camera stays in %s" % id)
		var outside := _tap(game, _open_ground(game, _outside()))
		assert_true(outside["call"], "a call in %s" % id)
		assert_eq(sim.camera.mode, Camera.DRAG, "just outside the box in %s: the drag" % id)


func test_a_tap_inside_the_box_during_a_drag_stops_it() -> void:
	var game := _boot()
	var sim: Simulation = game.simulation
	game.test_mode.run_ticks(TICK_RATE)
	_tap(game, SCREEN * 0.5 + Vector2(-400, -200))
	assert_eq(sim.camera.mode, Camera.DRAG)
	game.test_mode.run_ticks(2 * TICK_RATE)
	var stopped := sim.camera.position
	var tap := _tap(game, SCREEN * 0.5 + Vector2(20, 20))
	assert_true(tap["call"], "the second call happens")
	for i in int(Camera.DRAG_SECONDS * TICK_RATE) - 2:
		assert_eq(sim.camera.position, stopped, "the drag stopped where it was")
		game.test_mode.run_ticks(1)
	game.test_mode.run_ticks(3 * TICK_RATE)
	assert_ne(sim.camera.mode, Camera.DRAG, "then the camera goes back to the rails, as after any call")


func test_a_run_with_calls_in_and_out_of_the_box_is_repeatable() -> void:
	var hashes := []
	for run in 2:
		var game := _boot()
		game.test_mode.run_ticks(TICK_RATE)
		_tap(game, SCREEN * 0.5 + Vector2(-400, -200))
		game.test_mode.run_ticks(2 * TICK_RATE)
		_tap(game, SCREEN * 0.5 + Vector2(20, 20))
		game.test_mode.run_ticks(10 * TICK_RATE)
		hashes.append(game.simulation.state_hash())
	assert_eq(hashes[0], hashes[1], "same seed, same taps: same hash")
