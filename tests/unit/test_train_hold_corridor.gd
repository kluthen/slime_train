extends GutTest
## The hop corridor (chunk 22f step 3, D147 (4)): the hold's crowd check and
## the holder rule (TrainHold). The corridor is an oriented box from a
## hopping slime's centre to its hop's landing point (its target), extended
## TrainHold.CORRIDOR_PAST px past it, TrainHold.CORRIDOR_HALF_WIDTH px either
## side of the line (SlimeBodies.corridor_scan). Every slime with its centre
## in it counts, resting slimes and holders too, but the hopper, parked
## slimes, slimes in a basket and sleepers. The crowd check fails above an
## occupancy (summed areas over the box's) of TrainHold.HOLD_OCCUPANCY; a
## holder in it (read from the snapshot taken at the start of the tick) holds
## the slime at any occupancy, except a holder in its stack zone (its centre
## projecting onto the hop line less than the two radii from the hopper's).
##
## The world (as tests/unit/test_train_hold.gd's): a floor slab, its top at
## y = 0 (y 0 to Crowd.SLAB, x -2000 to 2000). The loop runs along it at a
## base slime's centre height (y = -24) from x = -1500 to 1500 and returns at
## y = 400: loop distance d is x = d - 1500 on the outgoing part. A slime
## off the floor stands on its own small shelf (one row above the floor at
## y = -78, one under the slab at y = 32). A crowd (tests/unit/
## hold_crowd_support.gd) is free slimes held still, base ones on the floor
## and bigger ones on their own shelves. The harness (_step) steps the train, the bodies, fusion and the
## train's follow in Simulation.step's order, without the free slimes'
## steering, which would move the crowd.

const Crowd := preload("res://tests/unit/hold_crowd_support.gd")
const DT := Simulation.TICK_SECONDS
## A base slime's centre height when standing on the floor (y = 0).
const STAND_Y := Crowd.STAND_Y
const LOOP_START_X := -1500.0
## The rows off the floor: on a shelf above it, on a shelf under the slab.
const ABOVE_Y := STAND_Y - 54.0
const UNDER_Y := Crowd.SLAB + 2.0 - STAND_Y
## The columns of the crowd before the hopper.
const CROWD_COLUMNS := 5
## Where the slime under test stands, and where its hop lands (150 px on).
const HOPPER_X := -300.0
## A base slime's area, as the corridor weighs it.
const BASE_AREA := PI * SlimeBodies.RING_RADIUS_SIZE_1 * SlimeBodies.RING_RADIUS_SIZE_1


# --- The harness ---------------------------------------------------------------

## The loop of the world (see the class doc).
func _level() -> LevelData:
	var data := LevelData.new("corridor", 1)
	var loop := LoopData.new("t.loop")
	loop.add_segment("t.loop.out", 1, LoopData.OUTGOING, PackedVector2Array([
			Vector2(-1500, -24), Vector2(1500, -24)]))
	loop.add_segment("t.loop.back", 1, LoopData.RETURN, PackedVector2Array([
			Vector2(1500, -24), Vector2(1500, 400), Vector2(-1500, 400), Vector2(-1500, -24)]), "t.gate")
	data.loop = loop
	data.first_slime = {"id": "t.first-slime", "species": "A", "position": Vector2(-1400, -24)}
	return data


## A simulation on the world with a base slime's shelf under every spot of
## `spots` off the floor and a crowd at `crowd` (Crowd.spots, its shelves
## included), its first slime removed, the view on it.
func _sim(spots: Array[Vector2], crowd: Array[Vector2] = []) -> Simulation:
	var polygons := Crowd.polygons(crowd)
	for at in spots:
		if at.y != STAND_Y:
			polygons.append(Crowd.shelf(at, 1))
	var sim := Simulation.new(5)
	sim.slimes.terrain = TerrainSegments.new(polygons)
	sim.load_level(_level())
	for slime_id in sim.slimes.ids():
		sim.slimes.remove(slime_id)
	sim.view.set_to(Vector2(-50, -50), 1.0, ScreenView.DEFAULT_SIZE)
	Crowd.place(sim.slimes, crowd)
	return sim


## The spots of a crowd from x = `from_x` going right: CROWD_COLUMNS base
## slimes on the floor, big ones under the slab and in one row above the
## floor, the rows within a floor slime's corridor.
func _crowd_spots(from_x: float) -> Array[Vector2]:
	return Crowd.spots(from_x, 1.0, CROWD_COLUMNS, 1)


## A base train slime at `at`, its next hop 10 s away.
func _train_slime(sim: Simulation, at: Vector2) -> int:
	var slime := sim.slimes.create(0, 1, at, SlimeBodies.TRAIN)
	sim.slimes.set_hop_timer(slime, 10.0)
	sim.train.track(slime, at.x - LOOP_START_X)
	return slime


## Makes `slime` hold since `began` (as a saved record would).
func _hold(sim: Simulation, slime: int, began: int) -> void:
	var record := sim.train.record_of(slime)
	record["hold"] = began
	sim.train.restore_record(slime, record)


## One tick in Simulation.step's order.
func _step(sim: Simulation) -> void:
	sim.train.steer(sim.slimes, DT, sim.tick, sim.fusion)
	sim.slimes.tick(DT)
	sim.fusion.step(sim)
	sim.train.follow(sim.slimes, sim.tick)
	sim.tick += 1


## Steps 30 ticks: the slimes settle where they were put.
func _settle(sim: Simulation) -> void:
	for i in 30:
		_step(sim)


## Where `slime` aims its next hop (Train.steer's target).
func _target(sim: Simulation, slime: int) -> Vector2:
	return sim.train.hop_target(sim.train.distance_of(slime), Train.hop_reach(sim.slimes.size_of(slime)))


## The occupancy of `slime`'s corridor now.
func _occupancy(sim: Simulation, slime: int) -> float:
	return TrainHold.occupancy_of(sim.slimes, sim.slimes.centre_of(slime), _target(sim, slime), slime)


## The ids in the corridor from `from` to `target`, all but `except_id`.
func _in_corridor(bodies: SlimeBodies, from: Vector2, target: Vector2, except_id := -1) -> Array[int]:
	var ids: Array[int] = []
	bodies.corridor_scan(from, target, TrainHold.CORRIDOR_PAST, TrainHold.CORRIDOR_HALF_WIDTH, except_id, ids)
	return ids


## [is holding, hopped this tick] for each of `slimes`.
func _outcomes(sim: Simulation, slimes: Array) -> Array:
	var out := []
	for slime in slimes:
		out.append([sim.train.is_holding(slime), sim.slimes.train_hopped.has(slime)])
	return out


# --- The box ---------------------------------------------------------------------

# @test-link [[req_hopping_behavior]]
func test_the_corridor_counts_a_slime_in_the_box_up_to_100_px_past_the_landing_point() -> void:
	var bodies := SlimeBodies.new(Rng.new(1))
	var from := Vector2(-300, STAND_Y)
	var target := Vector2(-150, STAND_Y)
	var me := bodies.create(0, 1, from)
	var inside := [
		bodies.create(1, 1, Vector2(-200, STAND_Y)),
		bodies.create(2, 1, Vector2(-60, STAND_Y)),
		bodies.create(3, 1, Vector2(-200, STAND_Y - 70)),
		bodies.create(4, 1, Vector2(-290, STAND_Y + 70)),
	]
	bodies.create(1, 1, Vector2(-40, STAND_Y))
	bodies.create(2, 1, Vector2(-200, STAND_Y - 80))
	bodies.create(3, 1, Vector2(-200, STAND_Y + 80))
	bodies.create(4, 1, Vector2(-310, STAND_Y))
	var ids: Array[int] = []
	var area := bodies.corridor_scan(from, target, TrainHold.CORRIDOR_PAST, TrainHold.CORRIDOR_HALF_WIDTH, me, ids)
	assert_eq(ids, inside, "on the way, 90 px past the landing, 70 px aside; not 110 px past it,"
			+ " 80 px aside, nor behind the start")
	assert_almost_eq(area, inside.size() * BASE_AREA, 0.01, "their summed areas")
	assert_true(_in_corridor(bodies, from, target).has(me), "the hopper is left out by its id only")


# @test-link [[req_hopping_behavior]]
func test_the_corridor_turns_with_the_hop() -> void:
	var bodies := SlimeBodies.new(Rng.new(1))
	var from := Vector2(0, 0)
	var target := Vector2(100, -100)
	var way := (target - from).normalized()
	var aside := Vector2(way.y, -way.x)
	var inside := bodies.create(1, 1, from + way * 200.0 + aside * 70.0)
	bodies.create(2, 1, from + way * 200.0 + aside * 80.0)
	bodies.create(3, 1, from + way * (target.length() + 110.0))
	bodies.create(4, 1, Vector2(200, 0))
	assert_eq(_in_corridor(bodies, from, target), [inside] as Array[int], "a box along a hop up and right")
	assert_eq(_in_corridor(bodies, from, from), [] as Array[int], "a hop going nowhere has no box")


# @test-link [[req_hopping_behavior]]
func test_resting_slimes_count_parked_basket_and_sleeper_slimes_do_not() -> void:
	var bodies := SlimeBodies.new(Rng.new(1))
	bodies.auto_hops = false
	var from := Vector2(-300, STAND_Y)
	var target := Vector2(-150, STAND_Y)
	var counted := [
		bodies.create(1, 1, Vector2(-250, STAND_Y)),
		bodies.create(2, 1, Vector2(-200, STAND_Y), SlimeBodies.FREE),
	]
	var resting := bodies.create(3, 1, Vector2(-150, STAND_Y))
	var body := bodies.body_of(resting)
	body["calm"] = SlimeBodies.RESTING
	assert_true(bodies.set_body(resting, body))
	assert_eq(bodies.calm_of(resting), SlimeBodies.RESTING)
	counted.append(resting)
	bodies.create(4, 1, Vector2(-100, STAND_Y), SlimeBodies.IN_BASKET)
	bodies.create(5, 1, Vector2(-80, STAND_Y), SlimeBodies.SLEEPER)
	var parked := bodies.create(0, 1, Vector2(-120, STAND_Y))
	bodies.park(parked)
	assert_eq(_in_corridor(bodies, from, target), counted, "train, free and resting; not basket, sleeper, parked")


# @test-link [[req_hopping_behavior]]
func test_the_occupancy_weighs_a_fused_slime_by_its_area() -> void:
	var bodies := SlimeBodies.new(Rng.new(1))
	var from := Vector2(-300, STAND_Y)
	var target := Vector2(-150, STAND_Y)
	var base := bodies.create(1, 1, Vector2(-200, STAND_Y))
	var box := TrainHold.corridor_area(from, target)
	assert_almost_eq(box, (150.0 + TrainHold.CORRIDOR_PAST) * 2.0 * TrainHold.CORRIDOR_HALF_WIDTH, 0.001)
	var one := TrainHold.occupancy_of(bodies, from, target, -1)
	assert_almost_eq(one, BASE_AREA / box, 0.000001)
	bodies.remove(base)
	bodies.create(1, 3, Vector2(-200, STAND_Y))
	assert_almost_eq(TrainHold.occupancy_of(bodies, from, target, -1), 3.0 * one, 0.000001,
			"a size-3 slime weighs three base slimes")


# The debug overlay outlines the corridor from its corners.
# @test-link [[req_platform_and_performance_targets]]
func test_the_corridors_corners() -> void:
	var corners := TrainHold.corridor_corners(Vector2(0, 0), Vector2(150, 0))
	var expected := PackedVector2Array([Vector2(0, -75), Vector2(250, -75), Vector2(250, 75), Vector2(0, 75)])
	assert_eq(corners.size(), 4)
	for k in 4:
		assert_almost_eq(corners[k].distance_to(expected[k]), 0.0, 0.001, "corner %d" % k)


# --- The crowd check -------------------------------------------------------------

# The hold tests' crowd (tests/unit/hold_crowd_support.gd), seen from a base
# slime Crowd.NEAR px before its first column (test_train_hold.gd's,
# test_train_hold_period.gd's and test_hold_counters.gd's), fills its hop
# corridor above the threshold, every crowd slime staying where it was put
# (none fused, slid or fell). A new calibration of TrainHold.HOLD_OCCUPANCY
# the crowd can't reach fails here.
# @test-link [[req_hopping_behavior]]
func test_the_hold_tests_crowd_fills_a_corridor_above_the_threshold_and_stays_put() -> void:
	var spots := Crowd.spots(HOPPER_X + Crowd.NEAR, 1.0, 8, 4)
	var sim := _sim([], spots)
	var crowd := sim.slimes.ids()
	assert_eq(crowd.size(), spots.size(), "one crowd slime per spot")
	var slime := _train_slime(sim, Vector2(HOPPER_X, STAND_Y))
	_settle(sim)
	var occupancy := _occupancy(sim, slime)
	assert_gt(occupancy, TrainHold.HOLD_OCCUPANCY, ("the hold tests' crowd fills a hop corridor to %.3f, not above"
			+ " TrainHold.HOLD_OCCUPANCY (%.3f): rework tests/unit/hold_crowd_support.gd") \
			% [occupancy, TrainHold.HOLD_OCCUPANCY])
	for k in spots.size():
		assert_true(sim.slimes.has(crowd[k]), "crowd slime %d is still there (not fused)" % k)
		if sim.slimes.has(crowd[k]):
			assert_lt(sim.slimes.centre_of(crowd[k]).distance_to(spots[k]), 3.0, "crowd slime %d stayed put" % k)


# A crowd thinned, the latest first, to the fewest slimes above the threshold
# holds a due slime; one slime fewer, at or below it, doesn't.
# @test-link [[req_hopping_behavior]]
func test_an_occupancy_above_the_threshold_holds_a_due_slime_one_at_or_below_it_does_not() -> void:
	var spots := _crowd_spots(HOPPER_X + 50.0)
	var counted := []
	for crowded in [true, false]:
		var sim := _sim([], spots)
		var slime := _train_slime(sim, Vector2(HOPPER_X, STAND_Y))
		_settle(sim)
		var target := _target(sim, slime)
		var occupancy := Crowd.thin(sim.slimes, sim.slimes.centre_of(slime), target, slime, crowded)
		assert_almost_eq(occupancy, _occupancy(sim, slime), 0.000001)
		counted.append(_in_corridor(sim.slimes, sim.slimes.centre_of(slime), target, slime).size())
		if crowded:
			assert_gt(occupancy, TrainHold.HOLD_OCCUPANCY, "the fewest crowd slimes above the threshold")
		else:
			assert_lte(occupancy, TrainHold.HOLD_OCCUPANCY, "one crowd slime fewer")
		sim.slimes.set_hop_timer(slime, 0.0)
		_step(sim)
		assert_eq(sim.train.is_holding(slime), crowded, "it holds only above the threshold")
		assert_eq(sim.slimes.train_hopped.has(slime), not crowded)
		assert_eq(sim.train.hold_counters()["crowd_holds"], 1 if crowded else 0)
	assert_eq(counted[0] - counted[1], 1, "one crowd slime apart, either side of the threshold")


# --- The holder rule -------------------------------------------------------------

# A holder 70 px past the landing point (in the corridor's extra 100 px)
# holds a due slime at low occupancy; one 110 px past it doesn't.
# @test-link [[req_hopping_behavior]]
func test_a_holder_in_the_corridor_even_past_the_landing_point_holds_a_slime_at_low_occupancy() -> void:
	for past in [70.0, 110.0]:
		var sim := _sim([])
		var slime := _train_slime(sim, Vector2(HOPPER_X, STAND_Y))
		var holder := _train_slime(sim, Vector2(HOPPER_X + Train.hop_reach(1) + past, STAND_Y))
		_settle(sim)
		_hold(sim, holder, sim.tick - 10)
		assert_lt(_occupancy(sim, slime), 0.1, "low occupancy")
		sim.slimes.set_hop_timer(slime, 0.0)
		_step(sim)
		assert_eq(sim.train.is_holding(slime), past < TrainHold.CORRIDOR_PAST, "%d px past the landing" % past)
		assert_eq(sim.train.hold_counters()["holder_holds"], 1 if past < TrainHold.CORRIDOR_PAST else 0)
		assert_eq(sim.train.hold_counters()["crowd_holds"], 0)


# A queue of three holders whose holds began on the same tick: the front's
# corridor has no holder, so it hops at its first re-check; the one behind it
# sees it as a holder (the start of the tick's snapshot) up to the tick it
# hops, and goes at its own first check after that, and the last one at its
# first check after the middle one's hop (each re-checks from its own phase,
# TrainHold.check_at).
# @test-link [[req_hopping_behavior]]
func test_in_a_queue_the_front_hops_first_and_each_slime_behind_goes_after_the_one_ahead() -> void:
	var sim := _sim([])
	var queue := [_train_slime(sim, Vector2(HOPPER_X + 120.0, STAND_Y)),
			_train_slime(sim, Vector2(HOPPER_X + 60.0, STAND_Y)), _train_slime(sim, Vector2(HOPPER_X, STAND_Y))]
	_settle(sim)
	var began := sim.tick - 10
	for slime in queue:
		_hold(sim, slime, began)
		sim.slimes.set_hop_timer(slime, TrainHold.HOLD_TIMER_SECONDS)
	var expected := []
	var after := sim.tick
	for slime in queue:
		var tick := after
		while sim.train.hold().check_at(sim.slimes, slime, tick) == TrainHold.NO_CHECK:
			tick += 1
		expected.append(tick)
		after = tick + 1
	var hops := {}
	while sim.tick <= expected[-1]:
		var tick := sim.tick
		_step(sim)
		for slime in queue:
			if sim.slimes.train_hopped.has(slime):
				hops[slime] = hops.get(slime, []) + [tick]
	for k in queue.size():
		assert_eq(hops.get(queue[k], []), [expected[k]], "slime %d from the front hops once, after the one ahead" % k)
	assert_eq(sim.train.hold_counters()["hold_ends_clear"], 3)


# --- The stack zone --------------------------------------------------------------

# Holders 10 px ahead of the hopper's centre along the hop, on a shelf above
# it and on one under the slab (within the two radii: its stack zone), don't
# hold it, though they count toward the occupancy; one 50 px ahead does.
# @test-link [[req_hopping_behavior]]
func test_a_holder_in_the_stack_zone_does_not_hold_the_slime_but_counts_one_just_ahead_does() -> void:
	for ahead in [10.0, 50.0]:
		var spots: Array[Vector2] = [Vector2(HOPPER_X + 10.0, ABOVE_Y), Vector2(HOPPER_X + ahead, UNDER_Y)]
		var sim := _sim(spots)
		var slime := _train_slime(sim, Vector2(HOPPER_X, STAND_Y))
		var holders := [_train_slime(sim, spots[0]), _train_slime(sim, spots[1])]
		_settle(sim)
		for holder in holders:
			_hold(sim, holder, sim.tick - 10)
		assert_almost_eq(_occupancy(sim, slime), 2.0 * BASE_AREA
				/ TrainHold.corridor_area(sim.slimes.centre_of(slime), _target(sim, slime)), 0.000001,
				"both holders count toward the occupancy")
		sim.slimes.set_hop_timer(slime, 0.0)
		_step(sim)
		var stacked: bool = ahead < 2.0 * SlimeBodies.RING_RADIUS_SIZE_1
		assert_eq(sim.train.is_holding(slime), not stacked, "a holder %d px ahead" % ahead)
		assert_eq(sim.slimes.train_hopped.has(slime), stacked)


# Two stacked train slimes (one on the floor, one on a shelf 10 px further
# along, above it) due on the same tick: the same outcome whichever was
# created (so steered) first, with the way clear (both hop) or a holder ahead
# (both hold).
# @test-link [[req_hopping_behavior]]
func test_two_stacked_train_slimes_due_on_the_same_tick_get_the_same_outcome_in_either_order() -> void:
	var low_at := Vector2(HOPPER_X, STAND_Y)
	var high_at := Vector2(HOPPER_X + 10.0, ABOVE_Y)
	for blocked in [false, true]:
		var seen := []
		for low_first in [true, false]:
			var spots: Array[Vector2] = [high_at]
			var sim := _sim(spots)
			var low: int
			var high: int
			if low_first:
				low = _train_slime(sim, low_at)
				high = _train_slime(sim, high_at)
			else:
				high = _train_slime(sim, high_at)
				low = _train_slime(sim, low_at)
			var holder := _train_slime(sim, Vector2(HOPPER_X + 100.0, STAND_Y)) if blocked else -1
			_settle(sim)
			if blocked:
				_hold(sim, holder, sim.tick - 10)
			for slime in [low, high]:
				sim.slimes.set_hop_timer(slime, 0.0)
			_step(sim)
			seen.append(_outcomes(sim, [low, high]))
		assert_eq(seen[0], seen[1], "the same outcome in either order (blocked: %s)" % blocked)
		var each := [true, false] if blocked else [false, true]
		assert_eq(seen[0], [each, each], "both hold behind a holder, both hop with the way clear")


# A slime starting its hold on a tick (before a crowd) isn't a holder yet
# for the slime behind it on that tick, whichever steers first: the holder
# rule reads the snapshot taken at the start of the tick. On the next due
# tick it is.
# @test-link [[req_hopping_behavior]]
func test_a_hold_started_this_tick_does_not_hold_the_slime_behind_until_the_next_in_either_order() -> void:
	var front_at := Vector2(HOPPER_X + 100.0, STAND_Y)
	var spots := _crowd_spots(front_at.x + 50.0)
	var seen := []
	for front_first in [true, false]:
		var sim := _sim([], spots)
		var front: int
		var behind: int
		if front_first:
			front = _train_slime(sim, front_at)
			behind = _train_slime(sim, Vector2(HOPPER_X, STAND_Y))
		else:
			behind = _train_slime(sim, Vector2(HOPPER_X, STAND_Y))
			front = _train_slime(sim, front_at)
		_settle(sim)
		assert_gt(_occupancy(sim, front), TrainHold.HOLD_OCCUPANCY, "a crowd ahead of the front")
		assert_lte(_occupancy(sim, behind), TrainHold.HOLD_OCCUPANCY, "not ahead of the one behind")
		for slime in [front, behind]:
			sim.slimes.set_hop_timer(slime, 0.0)
		_step(sim)
		seen.append(_outcomes(sim, [front, behind]))
	assert_eq(seen[0], seen[1], "the same outcome in either order")
	assert_eq(seen[0], [[true, false], [false, true]], "the front holds; the one behind hops that tick")
