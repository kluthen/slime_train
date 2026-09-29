extends GutTest
## Showing a gate open (master spec §5.6, build plan item 23.10): when a
## basket fires and its gate is off screen, the camera glides to the gate
## (about 1.5 s) to show it opening, then stays there under normal control.
## Input stays live: a touch takes control back and does its normal job. A
## gate already in view: nothing moves.
##
## The synthetic loop: section 1 runs from (0, 0) to (3000, 0) and returns
## by its slide under it while gate t.gate1 is closed; section 2 runs on to
## (5000, 0). Gate t.gate1 stands on the loop at x = 3000.

# @test-link [[req_camera_shows_gate_opening]]
# @test-link [[req_switch_basket_gate_set]]

const Support := preload("res://tests/unit/slime_test_support.gd")
const DT := Simulation.TICK_SECONDS
const TICK_RATE := Simulation.TICK_RATE
const SCREEN := ScreenView.DEFAULT_SIZE
const GATE := "t.gate1"
const GATE_BOX := Rect2(2980, -160, 40, 160)
const SHOW_TICKS := int(Camera.SHOW_SECONDS * TICK_RATE)

var _tick := 0


func before_each() -> void:
	_tick = 0


func _loop() -> LoopData:
	var loop := LoopData.new("t.loop")
	loop.add_segment("t.s1.out", 1, LoopData.OUTGOING, PackedVector2Array([Vector2(0, 0), Vector2(3000, 0)]))
	loop.add_segment("t.s1.slide", 1, LoopData.RETURN, PackedVector2Array([
			Vector2(3000, 0), Vector2(3000, 400), Vector2(0, 400), Vector2(0, 0)]), GATE)
	loop.add_segment("t.s2.out", 2, LoopData.OUTGOING, PackedVector2Array([Vector2(3000, 0), Vector2(5000, 0)]))
	loop.add_segment("t.s2.slide", 2, LoopData.RETURN, PackedVector2Array([
			Vector2(5000, 0), Vector2(5000, 400), Vector2(0, 400), Vector2(0, 0)]))
	return loop


func _camera(loop: LoopData, near: Vector2, zones := {}) -> Camera:
	var camera := Camera.new()
	camera.zones = zones
	camera.start(loop, [], near)
	return camera


func _view(camera: Camera) -> ScreenView:
	var view := ScreenView.new()
	camera.apply_to(view, SCREEN)
	return view


## `ticks` ticks with gate 1 open (it opened as the basket fired).
func _run(camera: Camera, loop: LoopData, ticks: int) -> void:
	for i in ticks:
		camera.step(loop, [GATE], DT, _tick)
		_tick += 1


## The gate fires open with `camera` showing what it shows now.
func _fire(camera: Camera, loop: LoopData) -> void:
	camera.show_gate(GATE_BOX, _view(camera), loop, [GATE], _tick)


func _gate_in_view(camera: Camera) -> bool:
	return Fusion.view_rect(_view(camera)).encloses(GATE_BOX)


# --- Off screen: the glide -------------------------------------------------------------

func test_a_gate_off_screen_is_shown_within_1_5_s() -> void:
	assert_eq(Camera.SHOW_SECONDS, 1.5)
	var loop := _loop()
	var camera := _camera(loop, Vector2(1000, 0))
	assert_false(_gate_in_view(camera))
	_fire(camera, loop)
	assert_eq(camera.mode, Camera.SHOW)
	var from := camera.position
	var target := Vector2(3000, 0) + Camera.RAIL_OFFSET
	var last := from
	for i in SHOW_TICKS:
		_run(camera, loop, 1)
		assert_lt(camera.position.distance_to(last), from.distance_to(target) / SHOW_TICKS + 1e-3, "a glide, no jump")
		assert_lt(camera.position.distance_to(target), last.distance_to(target) + 1e-3, "toward the gate")
		last = camera.position
	assert_eq(camera.mode, Camera.RAILS, "there after 1.5 s, under normal control")
	assert_eq(camera.position, target, "on the rail point nearest the gate")
	assert_almost_eq(camera.distance, 3000.0, 1e-6)
	assert_true(_gate_in_view(camera), "the gate in view")


func test_after_the_glide_it_stays_there() -> void:
	var loop := _loop()
	var camera := _camera(loop, Vector2(1000, 0))
	_fire(camera, loop)
	_run(camera, loop, SHOW_TICKS)
	var shown := camera.position
	_run(camera, loop, 10 * TICK_RATE)
	assert_eq(camera.position, shown, "it doesn't glide back")
	_tap(camera, 1)
	_run(camera, loop, 3 * TICK_RATE)
	assert_almost_eq(camera.distance, 3000.0 + Camera.STEP, 1e-6, "the edge buttons move it on from there")


func test_the_glide_eases_into_the_framing_of_a_zone_at_the_gate() -> void:
	var data := LevelData.new("t", 1)
	data.add_framing_zone("t.frame.gate", Rect2(2700, -400, 600, 500), 0.8, Vector2(0, -60))
	var loop := _loop()
	var camera := _camera(loop, Vector2(1000, 0), data.framing_zones)
	_fire(camera, loop)
	var last_zoom := camera.zoom
	for i in SHOW_TICKS:
		_run(camera, loop, 1)
		assert_lt(absf(camera.zoom - last_zoom), 0.01, "no jump in zoom")
		last_zoom = camera.zoom
	assert_eq(camera.frame_zone, "t.frame.gate")
	assert_true(_gate_in_view(camera))
	_run(camera, loop, 5 * TICK_RATE)
	assert_almost_eq(camera.zoom, 0.8, 1e-6, "the zone's zoom")
	assert_almost_eq(camera.position.y, Camera.RAIL_OFFSET.y - 60.0, 1e-3, "and its offset")
	assert_true(_gate_in_view(camera))


# --- Already in view: nothing moves ---------------------------------------------------

func test_a_gate_already_in_view_moves_nothing() -> void:
	var loop := _loop()
	var camera := _camera(loop, Vector2(2600, 0))
	assert_true(_gate_in_view(camera))
	var from := camera.position
	_fire(camera, loop)
	assert_eq(camera.mode, Camera.RAILS)
	_run(camera, loop, 3 * TICK_RATE)
	assert_eq(camera.position, from, "the camera doesn't move")


func test_a_gate_partly_in_view_is_shown() -> void:
	var loop := _loop()
	var camera := _camera(loop, Vector2(2420, 0))
	var view := Fusion.view_rect(_view(camera))
	assert_true(view.intersects(GATE_BOX) and not view.encloses(GATE_BOX), "half the gate shows")
	_fire(camera, loop)
	assert_eq(camera.mode, Camera.SHOW, "the whole gate is shown opening")


# --- Input stays live ----------------------------------------------------------------------

func test_a_call_during_the_glide_takes_the_camera_back() -> void:
	var loop := _loop()
	var camera := _camera(loop, Vector2(1000, 0))
	_fire(camera, loop)
	_run(camera, loop, SHOW_TICKS / 2)
	var view := _view(camera)
	var point := view.screen_to_world(SCREEN * 0.5 + Vector2(-400, -200))
	camera.touched()
	camera.on_call(point, _tick, view)
	assert_eq(camera.mode, Camera.DRAG, "the call drags it, as usual")
	var from := camera.position
	_run(camera, loop, TICK_RATE)
	assert_lt(camera.position.distance_to(point), from.distance_to(point), "toward the call point")


func test_a_touch_during_the_glide_stops_it() -> void:
	var loop := _loop()
	var camera := _camera(loop, Vector2(1000, 0))
	_fire(camera, loop)
	_run(camera, loop, SHOW_TICKS / 3)
	camera.touched()
	assert_eq(camera.mode, Camera.RETURN, "the child has it back: back to the rails as after a call")
	_run(camera, loop, 10 * TICK_RATE)
	assert_eq(camera.mode, Camera.RAILS)
	assert_lt(camera.distance, 2500.0, "it didn't carry on to the gate")


func test_an_edge_press_during_the_glide_moves_on_from_the_nearest_rail_point() -> void:
	var loop := _loop()
	var camera := _camera(loop, Vector2(1000, 0))
	_fire(camera, loop)
	_run(camera, loop, SHOW_TICKS / 2)
	var nearest: float = loop.closest(camera.position - Camera.RAIL_OFFSET, [GATE])["distance"]
	camera.touched()
	_tap(camera, -1)
	_run(camera, loop, 3 * TICK_RATE)
	assert_eq(camera.mode, Camera.RAILS)
	assert_almost_eq(camera.distance, nearest - Camera.STEP, 1e-6)


func test_no_glide_while_an_edge_button_is_held() -> void:
	var loop := _loop()
	var camera := _camera(loop, Vector2(1000, 0))
	camera.press(1, 0)
	_run(camera, loop, 1)
	_fire(camera, loop)
	assert_eq(camera.mode, Camera.RAILS, "the child is moving the camera: it stays hers")


# --- The idle clock ---------------------------------------------------------------------

func test_showing_a_gate_restarts_the_idle_clock_and_stops_the_cue() -> void:
	var loop := _loop()
	var camera := _camera(loop, Vector2(1000, 0))
	var bodies := SlimeBodies.new(Rng.new(5))
	bodies.gravity = Vector2.ZERO
	bodies.auto_hops = false
	bodies.create(0, 1, Vector2(1100, -24), SlimeBodies.TRAIN)
	var cue_from := int((Camera.IDLE_SECONDS - Camera.CUE_SECONDS) * TICK_RATE)
	for i in cue_from + TICK_RATE:
		camera.watch(bodies, false, false, false)
		_run(camera, loop, 1)
	assert_lt(camera.zoom, 1.0, "the cue is on")
	_fire(camera, loop)
	assert_eq(camera.quiet, 0)
	assert_eq(camera.cue_from, -1.0)
	for i in SHOW_TICKS + 3 * TICK_RATE:
		camera.watch(bodies, false, false, false)
		_run(camera, loop, 1)
	assert_eq(camera.mode, Camera.RAILS, "no idle camera right after: it stays at the gate")
	assert_almost_eq(camera.zoom, 1.0, 1e-6, "the zoom back")


func test_the_idle_camera_following_a_slime_shows_the_gate_too() -> void:
	var loop := _loop()
	var camera := _camera(loop, Vector2(1000, 0))
	var bodies := SlimeBodies.new(Rng.new(5))
	bodies.gravity = Vector2.ZERO
	bodies.auto_hops = false
	bodies.create(0, 1, Vector2(1100, -24), SlimeBodies.TRAIN)
	camera.watch(bodies, false, true, false)
	_run(camera, loop, 1)
	assert_eq(camera.mode, Camera.FOLLOW)
	_fire(camera, loop)
	assert_eq(camera.mode, Camera.SHOW)
	assert_eq(camera.follow_id, -1)


# --- State ----------------------------------------------------------------------------------

func test_a_glide_in_the_dump_restores_and_carries_on_the_same() -> void:
	var loop := _loop()
	var a := _camera(loop, Vector2(1000, 0))
	_fire(a, loop)
	_run(a, loop, 20)
	var b := Camera.new()
	b.restore(JSON.parse_string(StateHash.canonical_json(a.dump())))
	assert_eq(b.mode, Camera.SHOW)
	var tick := _tick
	_run(a, loop, SHOW_TICKS)
	_tick = tick
	_run(b, loop, SHOW_TICKS)
	assert_eq(b.mode, Camera.RAILS)
	assert_almost_eq(b.position.x, a.position.x, 1e-3)
	assert_almost_eq(b.position.y, a.position.y, 1e-3)


# --- In the Simulation: the basket fires ---------------------------------------------------

## The frontier test world (as tests/unit/test_frontier_sets.gd), moved
## right so the view isn't held at the level's left edge: basket t.basket
## (quota 3, x 600 to 900) opens gate t.gate at x 1800; its switch is flipped
## and a size-3 slime is in it, so it is full.
func _sim() -> Simulation:
	var sim := Simulation.new(3)
	sim.slimes.terrain = TerrainSegments.new([Support.floor_polygon()])
	var data := LevelData.new("show", 1)
	var loop := LoopData.new("t.loop")
	loop.add_segment("t.s1.out", 1, LoopData.OUTGOING, PackedVector2Array([Vector2(0, -24), Vector2(1500, -24)]))
	loop.add_segment("t.s1.back", 1, LoopData.RETURN, PackedVector2Array([
			Vector2(1500, -24), Vector2(1500, 400), Vector2(0, 400), Vector2(0, -24)]), "t.gate")
	loop.add_segment("t.s2.out", 2, LoopData.OUTGOING, PackedVector2Array([Vector2(1500, -24), Vector2(3000, -24)]))
	loop.add_segment("t.s2.back", 2, LoopData.RETURN, PackedVector2Array([
			Vector2(3000, -24), Vector2(3000, 400), Vector2(0, 400), Vector2(0, -24)]))
	data.loop = loop
	data.first_slime = {"id": "t.first-slime", "species": "A", "position": Vector2(100, -24)}
	data.add_switch("t.switch", Rect2(350, -100, 50, 50), "t.basket", Rect2(400, -10, 100, 10))
	data.add_basket("t.basket", Rect2(600, -200, 300, 200), 3, Vector2(1300, -24))
	data.add_gate("t.gate", Rect2(1800, -200, 20, 200), Rect2(1470, -5, 60, 10))
	data.rules.append({"when": {"object": "t.basket", "event": "full"}, "then": {"object": "t.gate", "action": "open"}})
	sim.load_level(data)
	sim.frontier.tap_switch(sim, "t.switch")
	var size := 3
	sim.slimes.create(Species.from_letter("B"), size, Vector2(750, -SlimeBodies.ring_radius_for(size) - SlimeBodies.EDGE),
			SlimeBodies.TRAIN)
	return sim


## Steps `sim` with its view showing its camera, as the scene does, until
## `done` holds, at most `limit` ticks. Returns the ticks it took, or -1.
func _step_until(sim: Simulation, done: Callable, limit: int) -> int:
	for i in limit:
		if done.call():
			return i
		sim.camera.apply_to(sim.view, SCREEN)
		sim.step()
	return -1


func test_the_gates_a_basket_fired_open_are_read_on_that_tick_only() -> void:
	var sim := _sim()
	sim.view.set_to(Vector2(750, -100), 1.0, SCREEN)
	var reward_ticks := FrontierSets.ticks(FrontierSets.REWARD_SECONDS)
	sim.frontier.step(sim)
	assert_eq(sim.object_states["t.basket"]["phase"], FrontierSets.FULL)
	for i in reward_ticks + 1:
		assert_eq(sim.frontier.gates_fired_open(sim), PackedStringArray(), "not yet fired")
		sim.tick += 1
		sim.frontier.step(sim)
	assert_eq(sim.object_states["t.basket"]["phase"], FrontierSets.FIRED)
	assert_eq(sim.frontier.gates_fired_open(sim), PackedStringArray(["t.gate"]), "the basket fired: its gate")
	sim.tick += 1
	assert_eq(sim.frontier.gates_fired_open(sim), PackedStringArray(), "on the tick it fired only")


func test_a_basket_saved_fired_shows_nothing_after_a_load() -> void:
	var sim := _sim()
	# As a save restores it (fixtures save "since": 0, and a load starts at
	# tick 0): the basket fired, its gate open.
	sim.object_states["t.basket"]["phase"] = FrontierSets.FIRED
	sim.object_states["t.basket"]["since"] = sim.tick
	sim.gate_states["t.gate"]["open"] = true
	sim.frontier.start(sim)
	assert_eq(sim.train.open_gates, ["t.gate"])
	assert_eq(sim.frontier.gates_fired_open(sim), PackedStringArray(), "no firing in this run")
	sim.camera.start(sim.level.loop, sim.train.open_gates, Vector2(750, -24))
	sim.camera.apply_to(sim.view, SCREEN)
	sim.step()
	assert_ne(sim.camera.mode, Camera.SHOW, "nothing to show")


func test_in_the_simulation_a_basket_firing_shows_its_gate() -> void:
	var sim := _sim()
	sim.camera.start(sim.level.loop, [], Vector2(750, -24))
	var box: Rect2 = sim.level.gates["t.gate"]["box"]
	sim.camera.apply_to(sim.view, SCREEN)
	assert_false(Fusion.view_rect(sim.view).encloses(box), "the gate is off screen")
	var fired := func() -> bool: return sim.object_states["t.basket"]["phase"] == FrontierSets.FIRED
	assert_gt(_step_until(sim, fired, 10 * TICK_RATE), 0, "the basket fires")
	assert_eq(sim.camera.mode, Camera.SHOW)
	var shown := func() -> bool: return Fusion.view_rect(sim.view).encloses(box)
	var took := _step_until(sim, shown, 3 * TICK_RATE)
	assert_between(took, 1, SHOW_TICKS + 1, "the gate in view within about 1.5 s")


func test_in_the_simulation_a_gate_in_view_keeps_the_camera_still() -> void:
	var sim := _sim()
	sim.camera.start(sim.level.loop, [], Vector2(1290, -24))
	var box: Rect2 = sim.level.gates["t.gate"]["box"]
	sim.camera.apply_to(sim.view, SCREEN)
	assert_true(Fusion.view_rect(sim.view).encloses(box), "basket and gate both in view")
	var from := sim.camera.position
	var fired := func() -> bool: return sim.object_states["t.basket"]["phase"] == FrontierSets.FIRED
	assert_gt(_step_until(sim, fired, 10 * TICK_RATE), 0, "the basket fires")
	for i in 3 * TICK_RATE:
		sim.camera.apply_to(sim.view, SCREEN)
		sim.step()
		assert_ne(sim.camera.mode, Camera.SHOW)
	assert_eq(sim.camera.position, from, "the camera doesn't move")


## A press and a lift on the same tick.
func _tap(camera: Camera, side: int) -> void:
	camera.press(side, 0)
	camera.release(0)
