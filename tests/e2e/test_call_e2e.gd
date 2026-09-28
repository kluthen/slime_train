extends GutTest
## End-to-end on the test level (the Meadow): taps and the call through the
## real game scene. A call on the hills pulls the first slime off the loop and
## it rejoins the train; an unreachable call to the tree's high bough ends
## after 8 s, and the slime heads back by the tree's route back when it is in
## the tree's branch, straight to the loop otherwise; a scripted run with taps
## is deterministic.

# @test-link [[req_call_mechanic]]
# @test-link [[req_controls_tap_zones]]
# @test-link [[req_slime_states]]
# @test-link [[rule_exploration_branch_has_route_back]]

const MAIN_SCENE := "res://src/main.tscn"
const SEED := 77
const TICK_RATE := Simulation.TICK_RATE
const TREE_BRANCH := "s1.branch.tree"
const TREE_ROUTE := "s1.route-back.tree"
## Above the middle of the tree's high bough (its top is at y = -640): no
## slime can hop up to it from the ground or from the tree platform.
const BOUGH_POINT := Vector2(6200, -664)
## Where the first slime is after these many seconds (seed 77): on the hills,
## and on the ground at the foot of the tree, under its branch.
const HILLS_SECONDS := 30
const TREE_FOOT_SECONDS := 95


func _boot(config := {}) -> Node:
	var game: Node = load(MAIN_SCENE).instantiate()
	add_child_autofree(game)
	var run := {"seed": SEED, "time_scale": 0}
	run.merge(config, true)
	assert_eq(game.enable_test_mode(run), PackedStringArray())
	return game


## Points the camera so the screen's middle shows level point `centre`.
func _aim_camera(game: Node, centre: Vector2, zoom: float) -> void:
	game.camera.zoom = Vector2(zoom, zoom)
	game.camera.position = centre - game.camera.offset
	game.sync_view()
	assert_lt(game.simulation.view.centre.distance_to(centre), 1.0,
			"the camera's limits leave the view where it was aimed")


## Taps the screen where it shows level point `world`; the tap is dispatched
## on the next tick, which this runs.
func _tap_at(game: Node, world: Vector2) -> void:
	var sim: Simulation = game.simulation
	game.sync_view()
	var screen := sim.view.world_to_screen(world)
	sim.push_input(Simulation.touch_down(0, screen))
	sim.push_input(Simulation.touch_up(0, screen))
	game.test_mode.run_ticks(1)


## Runs ticks until the slime is back on the train, at most `limit` ticks.
## Returns the ticks it took, or -1.
func _run_until_rejoined(game: Node, slime: int, limit: int) -> int:
	var sim: Simulation = game.simulation
	for i in limit:
		if sim.slimes.state_of(slime) == SlimeBodies.TRAIN:
			return i
		game.test_mode.run_ticks(1)
	return -1


func test_a_call_on_the_hills_pulls_the_first_slime_off_the_loop_and_it_rejoins() -> void:
	var game := _boot()
	var sim: Simulation = game.simulation
	var slime := sim.slimes.ids()[0]
	game.test_mode.run_ticks(HILLS_SECONDS * TICK_RATE)
	var from := sim.slimes.centre_of(slime)
	assert_eq(sim.slimes.state_of(slime), SlimeBodies.TRAIN)
	assert_between(from.x / ScreenView.DEFAULT_SIZE.x, 1.2, 1.8, "on the hills")
	var point := from + Vector2(-260, -20)
	_aim_camera(game, from + Vector2(0, -60), 1.0)
	_tap_at(game, point)

	var tap: Dictionary = sim.taps[-1]
	assert_eq(tap["zone"], TapDispatcher.ZONE_GROUND, "open ground")
	assert_true(tap["call"])
	assert_eq(tap["answered"], [slime])
	assert_eq(sim.slimes.state_of(slime), SlimeBodies.FREE, "it leaves the loop")
	assert_false(sim.train.tracks(slime))
	assert_eq(sim.free_slimes.phase_of(slime), FreeSlimes.ANSWERING)
	assert_eq(sim.ripples.size(), 1, "the tap shows a ripple")

	var closest := from.distance_to(point)
	while sim.free_slimes.phase_of(slime) == FreeSlimes.ANSWERING:
		game.test_mode.run_ticks(1)
		closest = minf(closest, sim.slimes.centre_of(slime).distance_to(point))
	assert_lt(closest, FreeSlimes.REACHED + 10.0, "it hops back to the point, against the loop's way")

	# Answering (8 s at most), unsure (15 s at most), then the way back.
	var took := _run_until_rejoined(game, slime, 45 * TICK_RATE)
	assert_gt(took, -1, "it rejoins the train within 45 s")
	assert_true(sim.train.tracks(slime))
	assert_false(sim.free_slimes.tracks(slime))
	var progress := sim.train.progress_of(slime)
	game.test_mode.run_ticks(10 * TICK_RATE)
	assert_gt(sim.train.progress_of(slime), progress + 100.0, "and travels the loop again")


func test_an_unreachable_call_from_the_ground_ends_after_8_s_and_heads_straight_back() -> void:
	var game := _boot()
	var sim: Simulation = game.simulation
	var slime := sim.slimes.ids()[0]
	game.test_mode.run_ticks(TREE_FOOT_SECONDS * TICK_RATE)
	var from := sim.slimes.centre_of(slime)
	assert_eq(sim.level.branch_at(from), "", "on the ground, outside the tree's branch")
	_aim_camera(game, Vector2(5900, -400), 0.7)
	_tap_at(game, BOUGH_POINT)
	var call_tick := sim.tick - 1
	assert_eq(sim.free_slimes.phase_of(slime), FreeSlimes.ANSWERING)
	assert_lt(sim.free_slimes.point_of(slime).y, -600.0, "the point is on the high bough")

	game.test_mode.run_until(call_tick + FreeSlimes.CALL_SECONDS * TICK_RATE)
	assert_eq(sim.free_slimes.phase_of(slime), FreeSlimes.ANSWERING, "it tries for 8 s")
	game.test_mode.run_ticks(1)
	assert_eq(sim.free_slimes.phase_of(slime), FreeSlimes.UNSURE, "then gives up")
	assert_gt(sim.slimes.centre_of(slime).y, -300.0, "without reaching the bough")

	var unsure_since := sim.free_slimes.phase_since(slime)
	game.test_mode.run_until(unsure_since + FreeSlimes.UNSURE_SECONDS * TICK_RATE + 1)
	assert_eq(sim.free_slimes.phase_of(slime), FreeSlimes.HEADING_BACK)
	var routes := {}
	for i in 60 * TICK_RATE:
		if sim.slimes.state_of(slime) == SlimeBodies.TRAIN:
			break
		routes[sim.free_slimes.route_of(slime)] = true
		game.test_mode.run_ticks(1)
	assert_eq(routes.keys(), [""], "straight to the loop, by no route back")
	assert_eq(sim.slimes.state_of(slime), SlimeBodies.TRAIN, "back on the train")


func test_an_unreachable_call_from_the_tree_platform_heads_back_by_the_tree_route() -> void:
	var game := _boot()
	var sim: Simulation = game.simulation
	for other in sim.slimes.ids():
		sim.slimes.remove(other)
	var slime := sim.slimes.create(Species.from_letter("A"), 1, Vector2(5900, -384), SlimeBodies.FREE)
	game.test_mode.run_ticks(TICK_RATE)
	assert_eq(sim.level.branch_at(sim.slimes.centre_of(slime)), TREE_BRANCH, "on the tree platform")
	_aim_camera(game, Vector2(5900, -400), 0.7)
	_tap_at(game, BOUGH_POINT)
	var call_tick := sim.tick - 1
	assert_eq(sim.free_slimes.phase_of(slime), FreeSlimes.ANSWERING)

	game.test_mode.run_until(call_tick + FreeSlimes.CALL_SECONDS * TICK_RATE + 1)
	assert_eq(sim.free_slimes.phase_of(slime), FreeSlimes.UNSURE, "it gives up after 8 s")
	game.test_mode.run_until(call_tick + (FreeSlimes.CALL_SECONDS + FreeSlimes.UNSURE_SECONDS) * TICK_RATE + 2)
	assert_eq(sim.free_slimes.phase_of(slime), FreeSlimes.HEADING_BACK)
	var used_route := false
	var took := -1
	for i in 60 * TICK_RATE:
		if sim.slimes.state_of(slime) == SlimeBodies.TRAIN:
			took = i
			break
		used_route = used_route or sim.free_slimes.route_of(slime) == TREE_ROUTE
		game.test_mode.run_ticks(1)
	assert_true(used_route, "by the tree's route back")
	assert_gt(took, -1, "it rejoins the train within 60 s")
	assert_gt(sim.slimes.centre_of(slime).x, 6336.0, "past the platform, where the route back meets the loop")


## A run's taps are part of its input: the same seed and scripted taps give
## the same state hash, and taps change it.
func test_a_run_with_taps_is_deterministic() -> void:
	var steps := [
		{"tick": 20, "do": "tap", "at": [760, 420]},
		{"tick": 200, "do": "tap", "at": [300, 450]},
		{"tick": 201, "do": "touch_down", "at": [900, 300], "finger": 1},
		{"tick": 230, "do": "touch_up", "finger": 1},
		{"tick": 600, "do": "tap", "at": [640, 30]},
	]
	var hashes := []
	for config in [{"steps": steps}, {"steps": steps}, {}]:
		var game := _boot(config)
		game.test_mode.run_ticks(20 * TICK_RATE)
		hashes.append(game.simulation.state_hash())
		if not config.is_empty():
			var calls := 0
			for tap in game.simulation.taps:
				calls += 1 if not tap["answered"].is_empty() else 0
			assert_gt(calls, 0, "a scripted tap calls the slime")
	assert_eq(hashes[0], hashes[1], "same seed, same taps: same hash")
	assert_ne(hashes[0], hashes[2], "the taps change the run")
