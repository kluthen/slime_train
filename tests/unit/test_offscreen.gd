extends GutTest
## Offscreen (src/sim/offscreen.gd) on a synthetic level: slimes far from the
## view park and near ones simulate again; a parked train slime is a position
## along the loop at the off-screen pace (the slide's speed on a slide), drops
## into a basket through an open trapdoor, and the basket fills there; a
## parked free slime follows its area's route back (or goes straight to a
## near loop) and rejoins the train; one with nothing near is left alone at
## 10 s and lost at 1 min 10 s, moved to the start of the loop; one kept on
## screen never is; zoomed out, rings use fewer points; a call, a tilt change
## and a door wake the resting piles; a save keeps it all; same seed, same
## hash.
##
## The world: a floor whose top is at y = 0 from x = -6000 to 6000. The loop
## runs along it at a base slime's centre height (y = -24) from x = -5000 to
## 5000 and returns under the floor (y = 400), its return route (a slide).
## Branch t.branch.cave is the box x 2000 to 3200, y -900 to -300; its route
## back runs from (2100, -624) to (3000, -624) and down to the loop at
## (3300, -24). The floor has a pit from x -3800 to -3400, 200 deep: basket
## t.basket (quota 3), under switch t.switch's trapdoor. A cup at x -3000,
## y -1000 holds a slime far from any route.
# @test-link [[req_offscreen_simulation]]
# @test-link [[rule_left_alone_and_lost]]
# @test-link [[req_switch_basket_gate_set]]
# @test-link [[req_persistence_and_saves]]

const BRANCH := "t.branch.cave"
const ROUTE := "t.route-back.cave"
const ROUTE_POINTS := [Vector2(2100, -624), Vector2(3000, -624), Vector2(3300, -24)]
const SWITCH := "t.switch"
const BASKET := "t.basket"
const GATE := "t.gate"
const TRAPDOOR := Rect2(-3800, -10, 400, 10)
const BASKET_BOX := Rect2(-3800, 0, 400, 200)
const QUOTA := 3
const CUP := Vector2(-3000, -1000)
const LOOP_LENGTH := 10000.0 + 424.0 + 10000.0 + 424.0
const DT := Simulation.TICK_SECONDS


func _level() -> LevelData:
	var data := LevelData.new("offscreen", 1)
	var loop := LoopData.new("t.loop")
	loop.add_segment("t.loop.out", 1, LoopData.OUTGOING, PackedVector2Array([
			Vector2(-5000, -24), Vector2(5000, -24)]))
	loop.add_segment("t.loop.back", 1, LoopData.RETURN, PackedVector2Array([
			Vector2(5000, -24), Vector2(5000, 400), Vector2(-5000, 400), Vector2(-5000, -24)]), GATE)
	data.loop = loop
	data.first_slime = {"id": "t.first-slime", "species": "A", "position": Vector2(-4900, -24)}
	data.add_branch(BRANCH, Rect2(2000, -900, 1200, 600))
	data.add_route_back(ROUTE, BRANCH, PackedVector2Array(ROUTE_POINTS))
	data.add_switch(SWITCH, Rect2(-3900, -100, 50, 50), BASKET, TRAPDOOR)
	data.add_basket(BASKET, BASKET_BOX, QUOTA, Vector2(-3000, -24))
	data.add_gate(GATE, Rect2(4800, -200, 20, 200))
	data.rules.append({"when": {"object": BASKET, "event": "full"}, "then": {"object": GATE, "action": "open"}})
	return data


func _terrain() -> TerrainSegments:
	var cup_floor := CUP.y + 60.0
	return TerrainSegments.new([
		PackedVector2Array([Vector2(-6000, 0), Vector2(-3800, 0), Vector2(-3800, 300), Vector2(-6000, 300)]),
		PackedVector2Array([Vector2(-3400, 0), Vector2(6000, 0), Vector2(6000, 300), Vector2(-3400, 300)]),
		PackedVector2Array([Vector2(-3800, 200), Vector2(-3400, 200), Vector2(-3400, 300), Vector2(-3800, 300)]),
		# The cup: a floor and two walls, 200 px apart.
		PackedVector2Array([Vector2(CUP.x - 140, cup_floor), Vector2(CUP.x + 140, cup_floor),
				Vector2(CUP.x + 140, cup_floor + 40), Vector2(CUP.x - 140, cup_floor + 40)]),
		PackedVector2Array([Vector2(CUP.x - 140, cup_floor - 300), Vector2(CUP.x - 100, cup_floor - 300),
				Vector2(CUP.x - 100, cup_floor), Vector2(CUP.x - 140, cup_floor)]),
		PackedVector2Array([Vector2(CUP.x + 100, cup_floor - 300), Vector2(CUP.x + 140, cup_floor - 300),
				Vector2(CUP.x + 140, cup_floor), Vector2(CUP.x + 100, cup_floor)]),
	])


## A simulation on the synthetic level, off-screen simulation on, the view
## on `look` (the first slime is removed: tests place their own).
func _sim(look := Vector2(0, -200), master_seed := 5) -> Simulation:
	var sim := Simulation.new(master_seed)
	sim.slimes.terrain = _terrain()
	sim.load_level(_level())
	for slime_id in sim.slimes.ids():
		sim.slimes.remove(slime_id)
	sim.offscreen.enabled = true
	_look(sim, look)
	return sim


func _look(sim: Simulation, at: Vector2, zoom := 1.0) -> void:
	sim.view.set_to(at, zoom, ScreenView.DEFAULT_SIZE)


## A free slime (heading back) at `at`.
func _free(sim: Simulation, at: Vector2, size := 1) -> int:
	return sim.slimes.create(Species.from_letter("D"), size, at, SlimeBodies.FREE)


## x of the outgoing loop at `distance` (on the outgoing part).
func _distance_at(x: float) -> float:
	return x + 5000.0


# --- Pace and parking -------------------------------------------------------------

func test_the_pace_is_a_hop_reach_per_mean_hop_interval() -> void:
	assert_almost_eq(Offscreen.pace(1), 150.0 / 2.25, 0.001)
	assert_almost_eq(Offscreen.pace(2), 180.0 / (2.25 * 1.15), 0.001)
	assert_almost_eq(Offscreen.pace(3), 210.0 / (2.25 * 1.3), 0.001)
	assert_almost_eq(Offscreen.pace(1, 0.5), 75.0 / 2.25, 0.001, "slower hops, slower pace")
	assert_almost_eq(Offscreen.lift(1), 0.0, 0.001)
	assert_almost_eq(Offscreen.lift(3), SlimeBodies.ring_radius_for(3) - 21.0, 0.001)


func test_off_by_default_nothing_parks() -> void:
	var sim := _sim()
	sim.offscreen.enabled = false
	var far := sim.spawn_train_slime(0, 1, _distance_at(3000))
	sim.run(10)
	assert_false(sim.slimes.is_parked(far), "the core simulates every slime")
	sim.offscreen.enabled = true
	sim.run(1)
	assert_true(sim.slimes.is_parked(far))
	sim.offscreen.enabled = false
	sim.run(1)
	assert_false(sim.slimes.is_parked(far), "turned off, parked slimes simulate again")


func test_far_slimes_park_and_near_ones_simulate() -> void:
	var sim := _sim()
	var half := ScreenView.DEFAULT_SIZE.x * 0.5
	var on_screen := sim.spawn_train_slime(0, 1, _distance_at(0))
	var near := sim.spawn_train_slime(0, 1, _distance_at(half + Offscreen.NEAR_MARGIN - 40.0))
	var between := sim.spawn_train_slime(0, 1, _distance_at(-(half + Offscreen.NEAR_MARGIN + 40.0)))
	var far := sim.spawn_train_slime(0, 1, _distance_at(half + Offscreen.PARK_MARGIN + 200.0))
	var sleeper := sim.slimes.create(0, 1, Vector2(-4000, -200), SlimeBodies.SLEEPER)
	sim.run(1)
	assert_false(sim.slimes.is_parked(on_screen))
	assert_false(sim.slimes.is_parked(near))
	assert_false(sim.slimes.is_parked(between), "between the margins it keeps what it was")
	assert_true(sim.slimes.is_parked(far))
	assert_true(sim.slimes.is_parked(sleeper), "sleepers park too")
	assert_eq(sim.slimes.dump()[sim.slimes.index_of(far)]["calm"], "parked")


# --- Train slimes off screen ----------------------------------------------------------

func test_a_parked_train_slime_moves_along_the_loop_at_the_pace() -> void:
	var sim := _sim()
	var slime := sim.spawn_train_slime(0, 1, _distance_at(2000))
	var big := sim.spawn_train_slime(0, 3, _distance_at(3000))
	sim.run(1)
	var start := sim.train.progress_of(slime)
	var start_big := sim.train.progress_of(big)
	sim.run(120)
	assert_true(sim.slimes.is_parked(slime))
	assert_almost_eq(sim.train.progress_of(slime) - start, Offscreen.pace(1) * 2.0, 1.0, "2 s at the pace")
	assert_almost_eq(sim.train.progress_of(big) - start_big, Offscreen.pace(3) * 2.0, 1.0)
	var on := sim.train.position_at(sim.train.distance_of(big))
	assert_almost_eq(sim.slimes.centre_of(big), on + Vector2(0, -Offscreen.lift(3)), Vector2(0.01, 0.01),
			"lifted by its size above the loop")
	assert_eq(sim.slimes.velocity_of(slime), Vector2.ZERO, "no physics")
	assert_eq(sim.train.lost, [], "never stalled")


func test_a_parked_train_slime_slides_at_the_slide_speed_and_laps() -> void:
	# The view high above: nothing on the loop comes near it.
	var sim := _sim(Vector2(0, -2500))
	var slime := sim.spawn_train_slime(0, 1, _distance_at(5000) + 1.0)
	sim.run(1)
	var start := sim.train.progress_of(slime)
	sim.run(600)
	var moved := sim.train.progress_of(slime) - start
	assert_almost_eq(moved, Train.SLIDE_SPEED * 10.0, 1.0, "on the return route, the slide's speed")
	sim.run(60 * 21)
	assert_eq(sim.train.laps_of(slime), 1, "round the loop")
	assert_true(sim.slimes.is_parked(slime))
	assert_eq(sim.train.lost, [])


func test_the_view_coming_near_brings_a_train_slime_back_just_outside_it() -> void:
	var sim := _sim()
	var slime := sim.spawn_train_slime(0, 1, _distance_at(1800))
	sim.run(60)
	assert_true(sim.slimes.is_parked(slime))
	var x := sim.slimes.centre_of(slime).x
	# The view moves so the slime is just past NEAR_MARGIN beyond its right edge.
	_look(sim, Vector2(x - ScreenView.DEFAULT_SIZE.x * 0.5 - Offscreen.NEAR_MARGIN + 10.0, -200))
	sim.run(1)
	assert_false(sim.slimes.is_parked(slime), "physics takes over")
	assert_false(Fusion.view_rect(sim.view).has_point(sim.slimes.centre_of(slime)), "just outside the view")
	sim.run(240)
	assert_eq(sim.slimes.state_of(slime), SlimeBodies.TRAIN)
	assert_gt(sim.train.progress_of(slime), _distance_at(1800) + 60.0, "and hops on along the loop")
	assert_eq(sim.train.lost, [])


func test_a_parked_train_slime_drops_into_a_basket_that_fills_off_screen() -> void:
	var sim := _sim()
	sim.object_states[SWITCH]["flipped"] = true
	var slimes: Array[int] = []
	for i in QUOTA:
		slimes.append(sim.spawn_train_slime(1, 1, _distance_at(-4200 - 150 * i)))
	sim.run(60 * 25)
	for slime_id in slimes:
		assert_eq(sim.slimes.state_of(slime_id), SlimeBodies.IN_BASKET, "slime %d in the basket" % slime_id)
		assert_true(BASKET_BOX.has_point(sim.slimes.centre_of(slime_id)))
		assert_true(sim.slimes.is_parked(slime_id), "still off screen")
	assert_eq(sim.object_states[BASKET]["weight"], QUOTA, "weighed off screen")
	assert_eq(sim.object_states[BASKET]["phase"], FrontierSets.FULL, "full, waiting for the view")
	var centres := {}
	for slime_id in slimes:
		centres[sim.slimes.centre_of(slime_id)] = true
	assert_eq(centres.size(), QUOTA, "each in its own slot")
	_look(sim, BASKET_BOX.get_center())
	sim.run(1)
	assert_eq(sim.object_states[BASKET]["phase"], FrontierSets.REWARD, "the reward once in view")
	sim.run(int(FrontierSets.REWARD_SECONDS * Simulation.TICK_RATE) + 1)
	assert_eq(sim.object_states[BASKET]["phase"], FrontierSets.FIRED)
	assert_true(sim.gate_states[GATE]["open"])


func test_a_shut_trapdoor_lets_parked_slimes_pass() -> void:
	var sim := _sim()
	var slime := sim.spawn_train_slime(1, 1, _distance_at(-4200))
	sim.run(60 * 15)
	assert_eq(sim.slimes.state_of(slime), SlimeBodies.TRAIN)
	assert_gt(sim.slimes.centre_of(slime).x, -3600.0, "past the trapdoor")


# --- Free slimes off screen -----------------------------------------------------------

func test_a_free_slime_follows_its_areas_route_back_and_rejoins() -> void:
	var sim := _sim()
	var slime := _free(sim, Vector2(2400, -700))
	sim.run(1)
	assert_true(sim.slimes.is_parked(slime))
	var way: Dictionary = sim.offscreen.proxies[slime]
	assert_eq(way["route"], ROUTE)
	var on := Polyline.closest(PackedVector2Array(ROUTE_POINTS), Polyline.cumulative_lengths(PackedVector2Array(ROUTE_POINTS)),
			Vector2(2400, -700))
	assert_almost_eq(way["along"], on["distance"] + Offscreen.pace(1) * DT, 0.001, "placed on the nearest point")
	assert_almost_eq(sim.slimes.centre_of(slime).y, -624.0, 0.5, "on the route")
	var length := 900.0 + Vector2(3000, -624).distance_to(Vector2(3300, -24))
	var ticks := int(ceil((length - on["distance"]) / (Offscreen.pace(1) * DT)))
	# It rejoins within REJOIN_DISTANCE of the loop (FreeSlimes.follow), or at
	# the route's end; the last leg falls 2 px per px across, so that is up to
	# REJOIN_DISTANCE * sqrt(5) / 2 px before the end along the route.
	var early := int(FreeSlimes.REJOIN_DISTANCE * 1.2 / (Offscreen.pace(1) * DT)) + 1
	var taken := 0
	while sim.slimes.state_of(slime) == SlimeBodies.FREE and taken < ticks + 10:
		sim.run(1)
		taken += 1
	assert_between(taken, ticks - early, ticks, "rejoined the train by the route's end")
	assert_eq(sim.slimes.state_of(slime), SlimeBodies.TRAIN)
	assert_true(sim.train.tracks(slime))
	assert_almost_eq(sim.train.distance_of(slime), _distance_at(3300), FreeSlimes.REJOIN_DISTANCE + 2.0)
	sim.run(1)
	assert_false(sim.offscreen.proxies.has(slime), "its way is dropped")
	assert_true(sim.slimes.is_parked(slime), "never on screen")
	assert_eq(sim.offscreen.lost, [])


func test_free_slimes_leaving_together_follow_the_route_in_single_file() -> void:
	var sim := _sim()
	# Both nearest the same point of the route (straight under them).
	var first := _free(sim, Vector2(2400, -700))
	var second := _free(sim, Vector2(2400, -760))
	sim.run(1)
	var spacing := 2.0 * (SlimeBodies.ring_radius_for(1) + SlimeBodies.EDGE)
	var ahead: float = sim.offscreen.proxies[first]["along"]
	var behind: float = sim.offscreen.proxies[second]["along"]
	# Queued behind where the first stood once it had moved on this tick.
	var apart := spacing - Offscreen.pace(1) * DT
	assert_almost_eq(ahead - behind, apart, 0.001, "about a slime's width behind, not on one point")
	sim.run(120)
	var gap := sim.slimes.centre_of(first).distance_to(sim.slimes.centre_of(second))
	assert_almost_eq(gap, apart, 0.5, "and it keeps its place")


func test_queueing_ends_when_rounding_leaves_a_proxy_a_hair_too_close() -> void:
	# a - (a - s) can come out below s in floating point: the queue must not
	# chase the same proxy forever (reviewer finding on chunk 15).
	var sim := _sim()
	var spacing := 65.397
	sim.offscreen.proxies[7] = {"route": "r", "along": 511.9773, "from": Vector2.ZERO, "to": Vector2.ZERO}
	sim.offscreen.proxies[8] = {"route": "r", "along": 511.9773 - spacing, "from": Vector2.ZERO, "to": Vector2.ZERO}
	var way := {"route": "r", "along": 511.9773, "from": Vector2.ZERO, "to": Vector2.ZERO}
	sim.offscreen._queue(way, spacing)
	assert_true(float(way["along"]) <= 511.9773 - 2.0 * spacing + Offscreen.QUEUE_TOLERANCE, "behind both")
	sim.offscreen.proxies.clear()


func test_a_free_slime_outside_any_branch_goes_straight_to_a_near_loop() -> void:
	var sim := _sim()
	var slime := _free(sim, Vector2(-2000, -250))
	sim.run(1)
	var way: Dictionary = sim.offscreen.proxies[slime]
	assert_eq(way["route"], "")
	assert_eq(way["to"], Vector2(-2000, -24))
	sim.run(int(226.0 / (Offscreen.pace(1) * DT)) + 3)
	assert_eq(sim.slimes.state_of(slime), SlimeBodies.TRAIN)


func test_a_free_slime_with_no_route_near_is_left_alone_then_lost() -> void:
	var sim := _sim()
	var slime := _free(sim, CUP)
	sim.run(1)
	assert_true(sim.slimes.is_parked(slime))
	assert_false(sim.offscreen.proxies.has(slime), "nothing near: it stays")
	assert_eq(sim.offscreen.away[slime], 0)
	sim.run(Offscreen.LEFT_ALONE_TICKS - 2)
	assert_false(sim.offscreen.is_left_alone(slime, sim.tick))
	sim.run(1)
	assert_true(sim.offscreen.is_left_alone(slime, sim.tick), "left alone at 10 s")
	# The count is checked at the start of each tick: the one numbered
	# LEFT_ALONE_TICKS + LOST_TICKS moves it.
	sim.run(Offscreen.LOST_TICKS)
	assert_eq(sim.slimes.state_of(slime), SlimeBodies.FREE, "not yet")
	sim.run(1)
	assert_eq(sim.slimes.state_of(slime), SlimeBodies.TRAIN, "lost at 1 min 10 s")
	assert_eq(sim.offscreen.lost, [{"id": slime, "tick": Offscreen.LEFT_ALONE_TICKS + Offscreen.LOST_TICKS,
			"reason": Offscreen.LOST}])
	assert_almost_eq(sim.slimes.centre_of(slime), Vector2(-5000, -24), Vector2(1, 1), "at the start of the loop")
	assert_lt(sim.train.distance_of(slime), 2.0)
	assert_false(sim.offscreen.away.has(slime))


func test_a_free_slime_kept_on_screen_is_never_lost() -> void:
	var sim := _sim(CUP)
	var slime := _free(sim, CUP)
	sim.run(Offscreen.LEFT_ALONE_TICKS + Offscreen.LOST_TICKS + 120)
	assert_eq(sim.slimes.state_of(slime), SlimeBodies.FREE, "it can't reach the loop from the cup")
	assert_false(sim.slimes.is_parked(slime))
	assert_eq(sim.offscreen.lost, [])
	assert_false(sim.offscreen.away.has(slime))


func test_coming_back_on_screen_restarts_the_count() -> void:
	var sim := _sim()
	var slime := _free(sim, CUP)
	sim.run(500)
	assert_eq(sim.offscreen.away[slime], 0)
	_look(sim, CUP)
	sim.run(1)
	assert_false(sim.offscreen.away.has(slime), "on screen: no count")
	_look(sim, Vector2(0, -200))
	sim.run(1)
	assert_eq(sim.offscreen.away[slime], 501, "a fresh count")


# --- Zoomed out -----------------------------------------------------------------------

func test_zoomed_out_rings_use_fewer_points() -> void:
	var sim := _sim()
	var slimes := [sim.spawn_train_slime(0, 1, _distance_at(0)), sim.spawn_train_slime(0, 3, _distance_at(200))]
	sim.run(1)
	assert_false(sim.slimes.is_low_detail(slimes[0]))
	_look(sim, Vector2(0, -200), 0.7)
	sim.run(1)
	assert_true(sim.offscreen.zoomed_out)
	assert_eq(sim.slimes.points_of(slimes[0]).size(), SlimeBodies.low_points_for(1))
	assert_eq(sim.slimes.points_of(slimes[1]).size(), SlimeBodies.low_points_for(3))
	var late := sim.spawn_train_slime(0, 2, _distance_at(-200))
	_look(sim, Vector2(0, -200), 0.82)
	sim.run(1)
	assert_true(sim.slimes.is_low_detail(late), "between the thresholds the detail stays, new slimes too")
	_look(sim, Vector2(0, -200), 0.9)
	sim.run(1)
	for slime_id in sim.slimes.ids():
		assert_false(sim.slimes.is_low_detail(slime_id))
		assert_eq(sim.slimes.points_of(slime_id).size(), SlimeBodies.points_for(sim.slimes.size_of(slime_id)))


# --- Disturbing resting piles -----------------------------------------------------------

## Bedtime-asleep slimes piled on the floor at x = 0, run until they rest.
func _pile(sim: Simulation) -> Array[int]:
	var out: Array[int] = []
	for i in 4:
		out.append(sim.slimes.create(0, 1, Vector2(-66 + 44 * i, -24), SlimeBodies.BEDTIME_ASLEEP))
	sim.run(120)
	for slime_id in out:
		assert_eq(sim.slimes.calm_of(slime_id), SlimeBodies.RESTING, "the pile rests")
	return out


func test_a_call_wakes_a_resting_pile_in_its_radius() -> void:
	var sim := _sim()
	var pile := _pile(sim)
	sim.push_input(Simulation.touch_down(0, sim.view.world_to_screen(Vector2(300, -200))))
	sim.push_input(Simulation.touch_up(0, null))
	sim.run(1)
	for slime_id in pile:
		assert_eq(sim.slimes.calm_of(slime_id), SlimeBodies.ACTIVE)


func test_a_tilt_change_wakes_the_resting_piles() -> void:
	var sim := _sim()
	var pile := _pile(sim)
	sim.push_input(Simulation.tilt(0.0))
	sim.run(1)
	assert_eq(sim.slimes.calm_of(pile[0]), SlimeBodies.RESTING, "the same way down")
	sim.push_input(Simulation.tilt(30.0))
	sim.run(1)
	for slime_id in pile:
		assert_eq(sim.slimes.calm_of(slime_id), SlimeBodies.ACTIVE)


func test_a_trapdoor_opening_wakes_the_pile_on_it() -> void:
	var sim := _sim(Vector2(-3700, -200))
	var pile: Array[int] = []
	for i in 3:
		pile.append(sim.slimes.create(0, 1, Vector2(-3760 + 44 * i, -24), SlimeBodies.BEDTIME_ASLEEP))
	sim.run(120)
	assert_eq(sim.slimes.calm_of(pile[0]), SlimeBodies.RESTING)
	sim.frontier.tap_switch(sim, SWITCH)
	sim.run(2)
	assert_false(sim.object_states[SWITCH]["trapdoor_shut"])
	for slime_id in pile:
		assert_eq(sim.slimes.calm_of(slime_id), SlimeBodies.ACTIVE, "slime %d woke" % slime_id)
	sim.run(60)
	assert_gt(sim.slimes.centre_of(pile[1]).y, 0.0, "and falls through")


# --- Saves and determinism ------------------------------------------------------------

## A run with every off-screen case going: train proxies, a free slime on
## its route back, one left alone, the basket filling, a zoom.
func _busy(master_seed: int) -> Simulation:
	var sim := _sim(Vector2(0, -200), master_seed)
	sim.object_states[SWITCH]["flipped"] = true
	for i in 6:
		sim.spawn_train_slime(i % 3, 1 + i % 2, _distance_at(-4300 + 700 * i))
	_free(sim, Vector2(2400, -700))
	_free(sim, CUP)
	_pile(sim)
	sim.run(300)
	_look(sim, Vector2(-500, -200), 0.75)
	sim.run(300)
	return sim


func test_a_save_keeps_the_offscreen_state() -> void:
	var sim := _busy(8)
	assert_false(sim.offscreen.away.is_empty())
	assert_false(sim.offscreen.proxies.is_empty())
	var text := SaveData.to_text(sim.to_save())
	var copy := Simulation.from_save(JSON.parse_string(text), _level(), _terrain())
	assert_not_null(copy)
	copy.offscreen.enabled = true
	assert_eq(copy.offscreen.dump(), sim.offscreen.dump())
	assert_eq(copy.state_hash(), sim.state_hash(), "the reloaded state")
	sim.run(900)
	copy.run(900)
	assert_eq(copy.state_hash(), sim.state_hash(), "and it carries on the same")


func test_same_seed_same_hash() -> void:
	var a := _busy(21)
	var b := _busy(21)
	var c := _busy(22)
	assert_eq(a.state_hash(), b.state_hash())
	assert_ne(a.state_hash(), c.state_hash())
