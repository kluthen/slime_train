extends GutTest
## End-to-end on the test level (the Meadow): the camera through the real
## game scene and test mode's scripted input. Holding the right edge button
## carries the camera forward through section 1, round the frontier turn,
## back along slide 1 (right to left on screen) and out into the start
## basin; the left button goes the other way. A call to the tree, off the
## loop, drags the camera toward it and the camera comes back to the rails.
## The scene's Camera2D shows what the simulation's camera says, the zoom
## never changes (DoD 18, in part), and a scripted run is repeatable.

# @test-link [[req_camera_rails_and_framing]]
# @test-link [[req_controls_tap_zones]]
# @test-link [[rule_return_route_per_section]]

const MAIN_SCENE := "res://src/main.tscn"
const SEED := 91
const TICK_RATE := Simulation.TICK_RATE
const SCREEN := ScreenView.DEFAULT_SIZE
const HOLD_FROM := 10
## Open air by the tree, off the loop: above the climb to its lower platform
## (x 4.72-4.9 screens, top at y = -360), left of the platform's sleepers,
## and low enough on screen to miss the parent's top band.
const TREE_POINT := Vector2(5500, -440)


func _boot(steps: Array = []) -> Node:
	var game: Node = load(MAIN_SCENE).instantiate()
	add_child_autofree(game)
	assert_eq(game.enable_test_mode({"seed": SEED, "time_scale": 0, "steps": steps}), PackedStringArray())
	return game


func _button(side: int) -> Array:
	var at := TapDispatcher.edge_button_rect(side, SCREEN).get_center()
	return [at.x, at.y]


## A scripted hold on the edge button of `side` from HOLD_FROM for `ticks`.
func _hold(side: int, ticks: int) -> Array:
	return [
		{"tick": HOLD_FROM, "do": "touch_down", "at": _button(side)},
		{"tick": HOLD_FROM + ticks, "do": "touch_up"},
	]


## The loop's length, its frontier and where the camera starts on it.
func _rail() -> Dictionary:
	var game := _boot()
	var sim: Simulation = game.simulation
	var loop := sim.level.loop
	var gates := sim.train.open_gates
	return {"length": loop.length(gates), "frontier": loop.frontier(gates), "start": sim.camera.distance}


func _ticks_for(distance: float) -> int:
	return ceili(distance / Camera.PACE * TICK_RATE)


func _assert_scene_mirrors(game: Node) -> void:
	var sim: Simulation = game.simulation
	assert_eq(game.camera.position, sim.view.centre, "the Camera2D shows the simulation's view")
	assert_eq(game.camera.zoom, Vector2.ONE)
	assert_eq(sim.view.zoom, 1.0)


func test_the_camera_starts_on_the_rails_by_the_first_slime() -> void:
	var game := _boot()
	var sim: Simulation = game.simulation
	assert_eq(sim.camera.mode, Camera.RAILS)
	assert_almost_eq(sim.camera.distance, 0.0, 1.0, "the first slime starts at the start of the loop")
	_assert_scene_mirrors(game)


func test_holding_the_right_button_goes_round_the_loop_through_the_frontier_turn() -> void:
	var rail := _rail()
	var length: float = rail["length"]
	var frontier: Dictionary = rail["frontier"]
	var hold := _ticks_for(length - float(rail["start"]) + 600.0)
	var game := _boot(_hold(1, hold))
	var sim: Simulation = game.simulation
	var loop := sim.level.loop
	game.test_mode.run_ticks(HOLD_FROM + 1)
	var last_distance := sim.camera.distance
	var last_x := sim.camera.position.x
	var max_x := -INF
	var slide_ticks := 0
	var slide_leftward := 0
	var wrapped_at := Vector2.INF
	for i in hold:
		game.test_mode.run_ticks(1)
		var d := sim.camera.distance
		var x := sim.camera.position.x
		max_x = maxf(max_x, x)
		if d < last_distance:
			assert_gt(last_distance - d, length * 0.5, "only backward once: the wrap")
			if wrapped_at == Vector2.INF:
				wrapped_at = sim.camera.position
		elif d > float(frontier["distance"]) + 800.0 and wrapped_at == Vector2.INF:
			slide_ticks += 1
			slide_leftward += 1 if x < last_x else 0
		last_distance = d
		last_x = x
	# Sampled once a tick, PACE / TICK_RATE px apart: the corner itself may fall between two ticks.
	assert_almost_eq(max_x, (frontier["position"] as Vector2).x, Camera.PACE / TICK_RATE + 1.0,
			"through section 1 up to the frontier turn")
	assert_gt(slide_ticks, TICK_RATE, "then along slide 1")
	assert_eq(slide_leftward, slide_ticks, "forward along the slide moves the view left on screen")
	assert_ne(wrapped_at, Vector2.INF, "and round to the start of the loop")
	assert_lt(wrapped_at.x / LevelData.SCREEN, 1.0, "out into the start basin")
	assert_eq(loop.closest(sim.camera.position - Camera.RAIL_OFFSET)["segment"], "s1.loop", "on section 1 again")
	assert_eq(sim.taps.size(), 1, "one press")
	assert_eq(sim.taps[0]["zone"], TapDispatcher.ZONE_EDGE)
	assert_eq(sim.taps[0]["answered"], [], "an edge button never calls")
	_assert_scene_mirrors(game)


func test_holding_the_left_button_goes_the_other_way() -> void:
	var rail := _rail()
	var length: float = rail["length"]
	var frontier: Dictionary = rail["frontier"]
	var hold := _ticks_for(length - float(frontier["distance"]) + float(rail["start"]) + 1200.0)
	var game := _boot(_hold(-1, hold))
	var sim: Simulation = game.simulation
	game.test_mode.run_ticks(HOLD_FROM + 1)
	assert_gt(sim.camera.distance, length * 0.5, "straight back past the start, onto the end of slide 1")
	var last_distance := sim.camera.distance
	var last_x := sim.camera.position.x
	var slide_ticks := 0
	var slide_rightward := 0
	var past_frontier := false
	for i in hold:
		game.test_mode.run_ticks(1)
		var d := sim.camera.distance
		var x := sim.camera.position.x
		assert_lt(d, last_distance, "always backward")
		if d > float(frontier["distance"]) + 800.0 and d < length - 800.0:
			slide_ticks += 1
			slide_rightward += 1 if x > last_x else 0
		past_frontier = past_frontier or d < float(frontier["distance"])
		last_distance = d
		last_x = x
	assert_gt(slide_ticks, TICK_RATE)
	assert_eq(slide_rightward, slide_ticks, "backward along the slide moves the view right on screen")
	assert_true(past_frontier, "up the chute and back onto section 1")
	assert_lt(sim.camera.position.x, (frontier["position"] as Vector2).x - 600.0, "heading back left")
	_assert_scene_mirrors(game)


func test_a_call_to_the_tree_drags_the_camera_and_it_comes_back_to_the_rails() -> void:
	var rail := _rail()
	var probe := _boot()
	var tree_distance: float = probe.simulation.level.loop.closest(TREE_POINT)["distance"]
	var hold := _ticks_for(tree_distance - float(rail["start"]) - Camera.STEP)
	var game := _boot(_hold(1, hold))
	var sim: Simulation = game.simulation
	game.test_mode.run_ticks(HOLD_FROM + hold + 3 * TICK_RATE)
	assert_lt(absf(sim.camera.distance - tree_distance), LevelData.SCREEN * 0.4, "at the tree")
	game.sync_view()
	var screen := sim.view.world_to_screen(TREE_POINT)
	sim.push_input(Simulation.touch_down(0, screen))
	sim.push_input(Simulation.touch_up(0, screen))
	var call_tick := sim.tick
	game.test_mode.run_ticks(1)
	var tap: Dictionary = sim.taps.back()
	assert_eq(tap["zone"], TapDispatcher.ZONE_GROUND, "open ground")
	assert_true(tap["call"], "a call off the loop")
	assert_eq(sim.camera.mode, Camera.DRAG)
	var left_rail_at := sim.camera.position
	var closest := left_rail_at.distance_to(TREE_POINT)
	game.test_mode.run_until(call_tick + int(Camera.DRAG_SECONDS * TICK_RATE))
	assert_eq(sim.camera.mode, Camera.DRAG, "pulled for the whole call")
	assert_lt(sim.camera.position.distance_to(TREE_POINT), closest - 100.0, "toward the tree")
	game.test_mode.run_ticks(1)
	assert_eq(sim.camera.mode, Camera.RETURN, "then back toward the rails")
	var took := 0
	while sim.camera.mode != Camera.RAILS and took < 10 * TICK_RATE:
		game.test_mode.run_ticks(1)
		took += 1
	assert_eq(sim.camera.mode, Camera.RAILS, "back on the rails")
	var loop := sim.level.loop
	assert_eq(sim.camera.position, loop.position_at(sim.camera.distance, sim.train.open_gates) + Camera.RAIL_OFFSET)
	assert_lt(absf(sim.camera.distance - tree_distance), LevelData.SCREEN * 0.5, "by the tree")
	_assert_scene_mirrors(game)


func test_a_scripted_camera_run_is_repeatable() -> void:
	var steps := [
		{"tick": 10, "do": "touch_down", "at": _button(1)},
		{"tick": 200, "do": "touch_up"},
		{"tick": 400, "do": "tap", "at": [700, 250]},
		{"tick": 700, "do": "touch_down", "at": _button(-1)},
		{"tick": 760, "do": "touch_up"},
		{"tick": 900, "do": "tap", "at": _button(1)},
	]
	var hashes := []
	var cameras := []
	for config_steps in [steps, steps, []]:
		var game := _boot(config_steps)
		game.test_mode.run_ticks(1200)
		hashes.append(game.simulation.state_hash())
		cameras.append(StateHash.canonical_json(game.simulation.dump()["camera"]))
	assert_eq(hashes[0], hashes[1], "same seed, same presses: same hash")
	assert_eq(cameras[0], cameras[1])
	assert_ne(cameras[0], cameras[2], "the presses move the camera")
