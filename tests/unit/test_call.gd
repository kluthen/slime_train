extends GutTest
## The call and the free slimes (src/sim/free_slimes.gd), through the
## Simulation: the call radius, train slimes answering and becoming free, a
## new tap replacing the point, the three phases (answering up to 8 s, unsure
## up to 15 s near the point, heading back) and rejoining the train, by the
## branch's route back or straight to the loop.
##
## The synthetic world: a floor whose top is at y = 0 from x = -2000 to 2000;
## the loop runs along it at a base slime's centre height (y = -24) from
## x = -1500 to 1500 and returns under the floor. A platform (top y = -300,
## x 300 to 700) lies inside an exploration branch whose route back runs left
## along the platform and down to the floor at x = 200. A shelf (top y =
## -200, x -900 to -500) is in no branch.

# @test-link [[req_call_mechanic]]
# @test-link [[req_slime_states]]
# @test-link [[rule_exploration_branch_has_route_back]]
# @test-link [[req_controls_tap_zones]]

const Support := preload("res://tests/unit/slime_test_support.gd")
const ROUTE := "t.route-back.platform"
const BRANCH := "t.branch.platform"
const TICKS_8S := 8 * Simulation.TICK_RATE
const TICKS_15S := 15 * Simulation.TICK_RATE


func _level() -> LevelData:
	var data := LevelData.new("call", 1)
	var loop := LoopData.new("t.loop")
	loop.add_segment("t.loop.out", 1, LoopData.OUTGOING, PackedVector2Array([
			Vector2(-1500, -24), Vector2(1500, -24)]))
	loop.add_segment("t.loop.back", 1, LoopData.RETURN, PackedVector2Array([
			Vector2(1500, -24), Vector2(1500, 400), Vector2(-1500, 400), Vector2(-1500, -24)]), "t.gate")
	data.loop = loop
	data.add_branch(BRANCH, Rect2(250, -420, 500, 160))
	data.add_route_back(ROUTE, BRANCH, PackedVector2Array([
			Vector2(680, -324), Vector2(300, -324), Vector2(200, -24)]))
	return data


func _sim(master_seed := 11) -> Simulation:
	var sim := Simulation.new(master_seed)
	sim.slimes.terrain = TerrainSegments.new([
		Support.floor_polygon(),
		PackedVector2Array([Vector2(300, -300), Vector2(700, -300), Vector2(700, -260), Vector2(300, -260)]),
		PackedVector2Array([Vector2(-900, -200), Vector2(-500, -200), Vector2(-500, -160), Vector2(-900, -160)]),
	])
	sim.load_level(_level())
	sim.view.set_to(Vector2(0, -200), 1.0, ScreenView.DEFAULT_SIZE)
	return sim


## A train slime resting on the floor at `x`.
func _train_slime(sim: Simulation, x: float) -> int:
	return sim.spawn_train_slime(0, 1, x + 1500.0)


## Centres the view on level point `world` (clear of the parent zone and the
## edge buttons) and taps the screen there.
func _call(sim: Simulation, world: Vector2) -> void:
	sim.view.set_to(world, sim.view.zoom, sim.view.screen_size)
	var at := sim.view.world_to_screen(world)
	sim.push_input(Simulation.touch_down(0, at))
	sim.push_input(Simulation.touch_up(0, at))
	sim.step()


## Runs until slime `slime` is back on the train, at most `limit` ticks.
## Returns the routes it chose on the way.
func _run_until_rejoined(sim: Simulation, slime: int, limit: int) -> Array:
	var routes := []
	for i in limit:
		sim.step()
		if sim.slimes.state_of(slime) == SlimeBodies.TRAIN:
			break
		var route := sim.free_slimes.route_of(slime)
		if route not in routes:
			routes.append(route)
	return routes


func test_the_call_radius_is_half_the_screen_width() -> void:
	var sim := _sim()
	assert_eq(sim.call_radius(), 576.0)
	sim.view.set_to(Vector2(0, -200), 0.5, ScreenView.DEFAULT_SIZE)
	assert_eq(sim.call_radius(), 1152.0, "it follows the zoom")


func test_train_slimes_in_range_answer_and_become_free() -> void:
	var sim := _sim()
	var inside := _train_slime(sim, -566)
	var outside := _train_slime(sim, 586)
	_call(sim, Vector2(0, -24))
	assert_eq(sim.slimes.state_of(inside), SlimeBodies.FREE, "566 px away: just inside")
	assert_eq(sim.free_slimes.phase_of(inside), FreeSlimes.ANSWERING)
	assert_false(sim.train.tracks(inside), "it left the train")
	assert_eq(sim.slimes.state_of(outside), SlimeBodies.TRAIN, "586 px away: just outside")
	assert_true(sim.train.tracks(outside))
	assert_eq(sim.taps.back()["answered"], [inside])


func test_sleepers_do_not_answer() -> void:
	var sim := _sim()
	var sleeper := sim.slimes.create(0, 1, Vector2(100, -24), SlimeBodies.SLEEPER)
	_call(sim, Vector2(0, -24))
	assert_eq(sim.slimes.state_of(sleeper), SlimeBodies.SLEEPER, "waking comes with chunk 9")
	assert_false(sim.free_slimes.tracks(sleeper))


func test_a_held_slime_is_let_go() -> void:
	var sim := _sim()
	var slime := _train_slime(sim, 0)
	sim.slimes.set_hop_held(slime, true)
	_call(sim, Vector2(100, -24))
	assert_false(sim.slimes.held[sim.slimes.index_of(slime)] != 0)


func test_an_answering_slime_hops_toward_the_point_soon_and_often() -> void:
	var sim := _sim()
	var slime := _train_slime(sim, 0)
	sim.run(30)
	_call(sim, Vector2(400, -24))
	var hops := []
	for i in 4 * Simulation.TICK_RATE:
		sim.step()
		if slime in sim.slimes.hopped:
			hops.append(sim.tick)
			assert_lte(sim.slimes.hop_timer_of(slime), 3.0 * FreeSlimes.ANSWER_PACE + 0.001,
					"a bit more often than on the train")
	assert_gt(hops.size(), 0)
	assert_lte(hops[0] - (sim.tick - 4 * Simulation.TICK_RATE), int(FreeSlimes.FIRST_HOP_SECONDS * 60) + 2,
			"the first hop comes soon after the call")
	assert_gt(sim.slimes.centre_of(slime).x, 150.0, "it moved toward the point")
	assert_eq(sim.facing[slime], Vector2.RIGHT, "it looks the way it hops")


func test_it_jumps_up_toward_a_higher_point() -> void:
	var sim := _sim()
	var slime := _train_slime(sim, -200)
	_call(sim, Vector2(-200, -500))
	var top := 0.0
	for i in 3 * Simulation.TICK_RATE:
		sim.step()
		top = minf(top, sim.slimes.centre_of(slime).y)
	assert_lt(top, -24.0 - 120.0, "it jumps well above its usual hop")
	assert_gt(FreeSlimes.max_rise(2, 1400.0), FreeSlimes.max_rise(1, 1400.0), "bigger slimes jump higher")
	assert_gt(FreeSlimes.max_rise(3, 1400.0), FreeSlimes.max_rise(2, 1400.0))


func test_a_new_tap_replaces_the_point() -> void:
	var sim := _sim()
	var slime := _train_slime(sim, 0)
	_call(sim, Vector2(0, -500))
	sim.run(60)
	# Far out of the slime's range: it still takes the new point.
	var called := sim.tick
	_call(sim, Vector2(1300, -24))
	assert_eq(sim.free_slimes.point_of(slime), Vector2(1300, -24))
	assert_eq(sim.free_slimes.phase_since(slime), called, "its 8 s start again")
	assert_eq(sim.free_slimes.phase_of(slime), FreeSlimes.ANSWERING)


func test_it_gives_up_after_8_seconds() -> void:
	var sim := _sim()
	var slime := _train_slime(sim, 0)
	var called := sim.tick
	_call(sim, Vector2(0, -560))  # far above open floor: out of reach
	sim.run(TICKS_8S - 1)
	assert_eq(sim.free_slimes.phase_of(slime), FreeSlimes.ANSWERING, "still trying at 7.98 s")
	sim.step()
	assert_eq(sim.free_slimes.phase_of(slime), FreeSlimes.UNSURE, "unsure at 8 s")
	assert_eq(sim.free_slimes.phase_since(slime), called + TICKS_8S)


func test_reaching_the_point_ends_the_call() -> void:
	var sim := _sim()
	var slime := _train_slime(sim, 0)
	var called := sim.tick
	_call(sim, Vector2(200, -24))
	for i in TICKS_8S:
		sim.step()
		if sim.free_slimes.phase_of(slime) != FreeSlimes.ANSWERING:
			break
	assert_eq(sim.free_slimes.phase_of(slime), FreeSlimes.UNSURE)
	assert_lt(sim.free_slimes.phase_since(slime) - called, TICKS_8S, "before the 8 s")
	assert_lt(sim.slimes.centre_of(slime).distance_to(Vector2(200, -24)), FreeSlimes.REACHED + 1.0)


func test_unsure_lingers_near_the_point_for_15_seconds() -> void:
	var sim := _sim()
	var slime := _train_slime(sim, 0)
	_call(sim, Vector2(0, -560))
	sim.run(TICKS_8S)
	var since := sim.free_slimes.phase_since(slime)
	assert_eq(sim.free_slimes.phase_of(slime), FreeSlimes.UNSURE)
	var hops := 0
	var spread := 0.0
	var unsure_all_along := true
	while sim.tick < since + TICKS_15S:
		sim.step()
		if slime in sim.slimes.hopped:
			hops += 1
		spread = maxf(spread, absf(sim.slimes.centre_of(slime).x))
		unsure_all_along = unsure_all_along and sim.free_slimes.phase_of(slime) == FreeSlimes.UNSURE
	assert_true(unsure_all_along, "unsure until 15 s")
	sim.step()
	assert_gt(hops, 2, "small lazy hops")
	assert_lt(spread, FreeSlimes.UNSURE_RANGE + 150.0, "near the last call point")
	assert_eq(sim.free_slimes.phase_of(slime), FreeSlimes.HEADING_BACK, "then it heads back")
	assert_eq(sim.free_slimes.phase_since(slime), since + TICKS_15S)


func test_on_the_loop_it_rejoins_as_soon_as_it_heads_back() -> void:
	var sim := _sim()
	var slime := _train_slime(sim, 0)
	_call(sim, Vector2(0, -560))
	sim.run(TICKS_8S + TICKS_15S + 2)
	assert_eq(sim.slimes.state_of(slime), SlimeBodies.TRAIN)
	assert_true(sim.train.tracks(slime), "the train follows it again")
	assert_false(sim.free_slimes.tracks(slime))
	assert_almost_eq(sim.train.distance_of(slime), sim.slimes.centre_of(slime).x + 1500.0, 30.0,
			"its progress is where it rejoined")


func test_outside_any_branch_it_heads_straight_for_the_loop() -> void:
	var sim := _sim()
	var slime := sim.slimes.create(0, 1, Vector2(-700, -224), SlimeBodies.FREE)
	sim.step()
	assert_eq(sim.free_slimes.phase_of(slime), FreeSlimes.HEADING_BACK, "an uncalled free slime heads back")
	var routes := _run_until_rejoined(sim, slime, 20 * Simulation.TICK_RATE)
	assert_eq(sim.slimes.state_of(slime), SlimeBodies.TRAIN, "back on the train within 20 s")
	assert_eq(routes, [""], "no route back: straight for the loop")
	assert_gt(sim.slimes.centre_of(slime).y, -60.0, "down on the floor")


func test_inside_a_branch_it_follows_the_route_back() -> void:
	var sim := _sim()
	var slime := sim.slimes.create(0, 1, Vector2(600, -324), SlimeBodies.FREE)
	var routes := _run_until_rejoined(sim, slime, 25 * Simulation.TICK_RATE)
	assert_eq(sim.slimes.state_of(slime), SlimeBodies.TRAIN, "back on the train within 25 s")
	assert_has(routes, ROUTE)
	assert_lt(sim.slimes.centre_of(slime).x, 300.0,
			"it went left along the route, not straight down to the right")


func test_a_called_slime_goes_through_every_phase_back_to_the_train() -> void:
	var sim := _sim()
	var slime := _train_slime(sim, 250)
	_call(sim, Vector2(400, -330))  # on the platform, out of reach from the floor
	var phases := []
	for i in 40 * Simulation.TICK_RATE:
		sim.step()
		var phase := sim.free_slimes.phase_of(slime)
		if phase != "" and phase not in phases:
			phases.append(phase)
		if sim.slimes.state_of(slime) == SlimeBodies.TRAIN:
			break
	assert_eq(phases, [FreeSlimes.ANSWERING, FreeSlimes.UNSURE, FreeSlimes.HEADING_BACK])
	assert_eq(sim.slimes.state_of(slime), SlimeBodies.TRAIN, "and back on the train")


func test_calls_are_deterministic() -> void:
	var hashes := []
	for run in 2:
		var sim := _sim(99)
		_train_slime(sim, 0)
		_train_slime(sim, 60)
		sim.run(20)
		_call(sim, Vector2(100, -300))
		sim.run(600)
		_call(sim, Vector2(-100, -24))
		sim.run(1200)
		hashes.append(sim.state_hash())
	assert_eq(hashes[0], hashes[1])
	var other := _sim(99)
	_train_slime(other, 0)
	_train_slime(other, 60)
	other.run(20 + 1 + 600 + 1 + 1200)
	assert_ne(hashes[0], other.state_hash(), "the calls changed the run")
