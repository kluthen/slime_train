extends GutTest
## The hold (chunk 22e, D145, reworked in 22f, D147 (4); Train.steer). When
## a train slime's hop is due it holds (doesn't hop) while its hop corridor's
## occupancy is above TrainHold.HOLD_OCCUPANCY (the crowd check), or while a
## holder is in its corridor outside its stack zone (the holder rule; the
## corridor itself: tests/unit/test_train_hold_corridor.gd). It checks again every
## TrainHold.HOLD_RECHECK_TICKS from its phase and at its period's end, with no
## forced hop (the period, the phase, the hold guard and the stall:
## tests/unit/test_train_hold_period.gd). A holding slime may rest (not while one of its contacts counts toward
## fusion; the celebration spares holders and resting train slimes its
## double hop: tests/unit/test_celebration.gd); a stall or stuck move,
## parking, a call end the hold, and a holder's split parts hold on. The
## hold is in the train's dump only while a slime holds.
##
## The world: a floor slab, its top at y = 0 (y 0 to Crowd.SLAB, x -2000 to
## 2000). The loop runs along it at a base slime's centre height (y = -24) from
## x = -1500 to 1500 and returns at y = 400: loop distance d is x = d - 1500
## on the outgoing part. A crowd (tests/unit/hold_crowd_support.gd) is free
## slimes held still (they never hop), CROWD_COLUMNS base slimes on the floor
## and bigger slimes as far along on their own shelves, one row under the
## floor slab and four above it: none touches another, so they stay put,
## Physics slimes (calm ACTIVE) that never rest. Seen from a slime NEAR px
## before its first column, its occupancy is above the threshold (checked in
## test_train_hold_corridor.gd). The harness (_step) steps the train,
## the bodies, fusion and the train's follow in Simulation.step's order,
## without the free slimes' steering, which would move the crowd.

const Crowd := preload("res://tests/unit/hold_crowd_support.gd")
const DT := Simulation.TICK_SECONDS
## A base slime's centre height when standing on the floor (y = 0).
const STAND_Y := -(SlimeBodies.RING_RADIUS_SIZE_1 + SlimeBodies.EDGE)
const LOOP_START_X := -1500.0
const CROWD_COLUMNS := 8
const CROWD_ABOVE_ROWS := 4
const CROWD_SPECIES := Crowd.SPECIES
const SPECIES_A := 0
## How far the slime nearest a crowd stands from its first column, px, and
## the spacing of a queue of holders: neither touches.
const NEAR := Crowd.NEAR
const STALL_TICKS := int(Train.STALL_SECONDS * Simulation.TICK_RATE)


# --- The harness ---------------------------------------------------------------

## The loop of the world (see the class doc).
func _level() -> LevelData:
	var data := LevelData.new("hold", 1)
	var loop := LoopData.new("t.loop")
	loop.add_segment("t.loop.out", 1, LoopData.OUTGOING, PackedVector2Array([
			Vector2(-1500, -24), Vector2(1500, -24)]))
	loop.add_segment("t.loop.back", 1, LoopData.RETURN, PackedVector2Array([
			Vector2(1500, -24), Vector2(1500, 400), Vector2(-1500, 400), Vector2(-1500, -24)]), "t.gate")
	data.loop = loop
	data.first_slime = {"id": "t.first-slime", "species": "A", "position": Vector2(-1400, -24)}
	return data


## A simulation on the world, its first slime removed, the view on it, with
## a crowd from x = `crowd_x` going `way` (none when `crowd_x` is INF).
func _sim(crowd_x := INF, way := 1.0) -> Simulation:
	var spots: Array[Vector2] = []
	if crowd_x != INF:
		spots = Crowd.spots(crowd_x, way, CROWD_COLUMNS, CROWD_ABOVE_ROWS)
	var sim := Simulation.new(5)
	sim.slimes.terrain = Crowd.terrain(spots)
	sim.load_level(_level())
	for slime_id in sim.slimes.ids():
		sim.slimes.remove(slime_id)
	sim.view.set_to(Vector2(-50, -50), 1.0, ScreenView.DEFAULT_SIZE)
	Crowd.place(sim.slimes, spots)
	return sim


## A train slime of `size` standing on the floor at x = `x`, its next hop
## 10 s away.
func _train_slime(sim: Simulation, x: float, slime_species := SPECIES_A, size := 1) -> int:
	var at := Vector2(x, -SlimeBodies.ring_radius_for(size) - SlimeBodies.EDGE)
	var slime := sim.slimes.create(slime_species, size, at, SlimeBodies.TRAIN)
	sim.slimes.set_hop_timer(slime, 10.0)
	sim.train.track(slime, x - LOOP_START_X)
	return slime


## One tick in Simulation.step's order: the train steers, the bodies tick,
## fusion counts, the train follows.
func _step(sim: Simulation) -> void:
	sim.train.steer(sim.slimes, DT, sim.tick, sim.fusion)
	sim.slimes.tick(DT)
	sim.fusion.step(sim)
	sim.train.follow(sim.slimes, sim.tick)
	sim.tick += 1


## Steps `ticks` times; returns the ticks at which `slime` took a train hop.
func _hops(sim: Simulation, slime: int, ticks: int) -> Array:
	var out := []
	for i in ticks:
		var tick := sim.tick
		_step(sim)
		if sim.slimes.train_hopped.has(slime):
			out.append(tick)
	return out


## Where `slime` aims its next hop (Train.steer's target).
func _target(sim: Simulation, slime: int) -> Vector2:
	var reach := Train.hop_reach(sim.slimes.size_of(slime))
	return sim.train.hop_target(sim.train.distance_of(slime), reach)


## The occupancy of `slime`'s hop corridor now (the crowd check's).
func _occupancy(sim: Simulation, slime: int) -> float:
	return TrainHold.occupancy_of(sim.slimes, sim.slimes.centre_of(slime), _target(sim, slime), slime)


## Whether `slime`'s crowd check fails now.
func _crowded(sim: Simulation, slime: int) -> bool:
	return _occupancy(sim, slime) > TrainHold.HOLD_OCCUPANCY


## Removes crowd slimes (free slimes) in `slime`'s hop corridor, the latest
## first: until its crowd check passes, or (`crowded`) while it would still
## fail without one more (the fewest that fail it).
func _thin_to(sim: Simulation, slime: int, crowded: bool) -> void:
	Crowd.thin(sim.slimes, sim.slimes.centre_of(slime), _target(sim, slime), slime, crowded)
	assert_eq(_crowded(sim, slime), crowded, "the crowd thinned")


## Steps until every slime of `slimes` rests (at most `limit` ticks);
## whether they all did.
func _until_resting(sim: Simulation, slimes: Array, limit: int) -> bool:
	for i in limit:
		if slimes.all(func(id): return sim.slimes.calm_of(id) == SlimeBodies.RESTING):
			return true
		_step(sim)
	return slimes.all(func(id): return sim.slimes.calm_of(id) == SlimeBodies.RESTING)


## The first tick from `from` on at which holder `slime` checks again
## (TrainHold.check_at: a re-check or its period's end).
func _next_check(sim: Simulation, slime: int, from: int) -> int:
	assert_true(sim.train.is_holding(slime), "a holder")
	var tick := from
	while sim.train.hold().check_at(sim.slimes, slime, tick) == TrainHold.NO_CHECK and tick < from + 1000:
		tick += 1
	return tick


## Steps 30 ticks: the slimes settle where they were put.
func _settle(sim: Simulation) -> void:
	for i in 30:
		_step(sim)


# --- The crowd check -----------------------------------------------------------

# @test-link [[req_hopping_behavior]]
func test_a_slime_with_its_corridor_over_the_occupancy_threshold_holds_and_checks_again_every_half_second() -> void:
	var sim := _sim(0.0)
	var slime := _train_slime(sim, -NEAR)
	_settle(sim)
	assert_true(_crowded(sim, slime), "a crowd in its hop corridor")
	_thin_to(sim, slime, true)
	sim.slimes.set_hop_timer(slime, 0.0)
	var began := sim.tick
	assert_eq(_hops(sim, slime, 1), [], "it holds")
	assert_true(sim.train.is_holding(slime))
	assert_eq(sim.train.hold_began_at(slime), began, "the hold is the tick it began")
	var phase: int = sim.train.hold().phase_of(sim.slimes, slime)
	assert_between(phase, 0, TrainHold.HOLD_RECHECK_TICKS - 1, "its phase")
	var first := began + TrainHold.HOLD_RECHECK_TICKS + phase
	var second := first + TrainHold.HOLD_RECHECK_TICKS
	assert_eq(_next_check(sim, slime, began), first, "the first re-check: 0.5 s plus its phase on")
	assert_eq(_next_check(sim, slime, first + 1), second, "the next, 0.5 s later")
	assert_eq(_hops(sim, slime, first + 1 - sim.tick), [], "at its first re-check, still crowded")
	assert_true(sim.train.is_holding(slime))
	_thin_to(sim, slime, false)
	assert_eq(_hops(sim, slime, second + 1 - sim.tick), [second],
			"no hop between the checks; it hops at the first re-check at or below the threshold")
	assert_false(sim.train.is_holding(slime), "the hold ended")


# @test-link [[req_hopping_behavior]]
func test_an_occupancy_at_or_below_the_threshold_or_a_crowd_behind_only_does_not_hold_it() -> void:
	var sim := _sim(0.0)
	var slime := _train_slime(sim, -NEAR)
	_settle(sim)
	_thin_to(sim, slime, false)
	sim.slimes.set_hop_timer(slime, 0.0)
	var due := sim.tick
	assert_eq(_hops(sim, slime, 1), [due], "at or below the threshold: it hops when due")
	assert_false(sim.train.is_holding(slime))
	var behind := _sim(0.0, -1.0)
	var front := _train_slime(behind, NEAR)
	_settle(behind)
	assert_gt(behind.slimes.crowd_count() - 1, 15, "a crowd")
	assert_eq(_occupancy(behind, front), 0.0, "all of it behind the slime")
	behind.slimes.set_hop_timer(front, 0.0)
	due = behind.tick
	assert_eq(_hops(behind, front, 1), [due], "a crowd behind it only: it hops when due")
	assert_false(behind.train.is_holding(front))


# The front (its corridor clear) hops; the slime behind it holds for the
# crowd; the one further behind, due a tick later, holds for the holder
# ahead of it (the holder rule), at low occupancy.
# @test-link [[req_hopping_behavior]]
func test_a_queues_front_whose_way_is_clear_hops_first_while_the_slimes_behind_it_hold() -> void:
	var sim := _sim(0.0)
	var behind := _train_slime(sim, -NEAR)
	var further_behind := _train_slime(sim, -2.0 * NEAR)
	var front := _train_slime(sim, Crowd.last_x(0.0, 1.0, CROWD_COLUMNS) + NEAR)
	_settle(sim)
	assert_eq(_occupancy(sim, front), 0.0, "the front's way is clear, the crowd behind it")
	for slime in [behind, front]:
		sim.slimes.set_hop_timer(slime, 0.0)
	sim.slimes.set_hop_timer(further_behind, 2.0 * DT)
	_step(sim)
	assert_true(sim.slimes.train_hopped.has(front), "the front hops")
	assert_false(sim.train.is_holding(front))
	assert_false(sim.slimes.train_hopped.has(behind), "the slime behind it doesn't")
	assert_true(sim.train.is_holding(behind), "it holds")
	assert_false(_crowded(sim, further_behind), "the one further behind isn't crowded")
	_step(sim)
	assert_false(sim.slimes.train_hopped.has(further_behind), "it doesn't hop either")
	assert_true(sim.train.is_holding(further_behind), "it holds behind the holder")
	assert_eq(sim.train.hold_counters()["holder_holds"], 1)
	assert_eq(sim.train.hold_counters()["crowd_holds"], 1)


# --- The holder rule -----------------------------------------------------------

# Replaces 22e's jam check (D147 (4)): a slime arriving behind a resting
# queue of holders holds once the rear holder is in its hop corridor, short
# of the queue, and wakes none of it.
# @test-link [[req_hopping_behavior]]
# @test-link [[req_offscreen_simulation]]
func test_a_slime_arriving_behind_a_resting_queue_stops_short_of_it_and_wakes_none_of_it() -> void:
	var sim := _sim(0.0)
	var queue := [_train_slime(sim, -NEAR), _train_slime(sim, -2.0 * NEAR), _train_slime(sim, -3.0 * NEAR)]
	var corridor := Train.hop_reach(1) + TrainHold.CORRIDOR_PAST
	var arriving := _train_slime(sim, -3.0 * NEAR - corridor - NEAR)
	_settle(sim)
	# Front first, a tick apart: each one behind holds for the holder ahead.
	var began := sim.tick
	for slime in queue:
		sim.slimes.set_hop_timer(slime, 0.0)
		_step(sim)
	for slime in queue:
		assert_true(sim.train.is_holding(slime), "the queue holds")
	assert_true(_until_resting(sim, queue, 60), "and rests")
	sim.slimes.set_hop_timer(arriving, 0.0)
	var hops := []
	var woken := 0
	while sim.tick < began + TrainHold.HOLD_CAP_TICKS - 10:
		hops.append_array(_hops(sim, arriving, 1))
		for slime in queue:
			woken += 0 if sim.slimes.calm_of(slime) == SlimeBodies.RESTING else 1
	assert_eq(hops.size(), 1, "one hop, then it holds")
	assert_true(sim.train.is_holding(arriving), "it holds behind the queue")
	assert_false(_crowded(sim, arriving), "not for a crowd")
	var rear: int = queue[-1]
	var left := sim.train.distance_of(rear) - sim.train.distance_of(arriving)
	assert_gt(left, 2.0 * SlimeBodies.ring_radius_for(1), "it stopped short of the queue")
	assert_lte(left, corridor, "the rear holder is in its corridor")
	assert_eq(woken, 0, "every queue slime rests on throughout")


# --- Holders rest --------------------------------------------------------------

# @test-link [[req_offscreen_simulation]]
func test_a_holding_slime_rests_then_wakes_and_hops_when_its_hold_ends_its_neighbours_resting_on() -> void:
	var sim := _sim(0.0)
	var front := _train_slime(sim, -NEAR)
	var neighbour := _train_slime(sim, -2.0 * NEAR)
	_settle(sim)
	var physics := sim.slimes.crowd_count()
	sim.slimes.set_hop_timer(front, 0.0)
	sim.slimes.set_hop_timer(neighbour, 0.1)
	var began := sim.tick
	assert_true(_until_resting(sim, [front, neighbour], 70), "both holders rest")
	assert_true(sim.train.is_holding(front) and sim.train.is_holding(neighbour))
	assert_eq(sim.slimes.crowd_count(), physics - 2, "the Physics count drops")
	while sim.tick < began + 75:
		_step(sim)
	_thin_to(sim, front, false)
	var end := _next_check(sim, front, sim.tick)
	assert_eq(_hops(sim, front, end - sim.tick), [], "resting, holding")
	assert_eq(sim.slimes.calm_of(front), SlimeBodies.RESTING)
	assert_eq(_hops(sim, front, 1), [end], "its hold ends: it wakes and hops")
	assert_ne(sim.slimes.calm_of(front), SlimeBodies.RESTING)
	assert_eq(sim.slimes.calm_of(neighbour), SlimeBodies.RESTING, "its neighbour rests on")
	_step(sim)
	assert_eq(sim.slimes.calm_of(neighbour), SlimeBodies.RESTING, "still")


# The slime holds behind a holder that holds for a crowd (the fused slime's
# longer corridor keeps that holder in it, so it holds on after the fusion).
# @test-link [[rule_fusion_contact_time]]
func test_a_holding_slime_touching_a_slime_it_may_fuse_with_does_not_rest_until_they_fuse() -> void:
	var sim := _sim(200.0)
	var ahead := _train_slime(sim, 200.0 - NEAR)
	var holder := _train_slime(sim, -NEAR)
	var partner := _train_slime(sim, -NEAR - 2.0 * SlimeBodies.ring_radius_for(1) - 1.0)
	_settle(sim)
	assert_true(sim.slimes.touching(holder, partner), "they touch")
	assert_true(sim.fusion.counts_toward_fusion(holder), "their contact counts")
	sim.slimes.set_hop_timer(ahead, 0.0)
	sim.slimes.set_hop_timer(holder, 2.0 * DT)
	var rested_before := false
	for i in Fusion.CONTACT_TICKS:
		_step(sim)
		if not sim.slimes.has(partner):
			break
		rested_before = rested_before or sim.slimes.calm_of(holder) == SlimeBodies.RESTING
	assert_false(sim.slimes.has(partner), "they fused")
	assert_false(rested_before, "it didn't rest while its contact counted")
	assert_eq(sim.slimes.size_of(holder), 2)
	assert_true(sim.train.is_holding(holder), "the fused slime holds on")
	assert_true(_until_resting(sim, [holder], 90), "then it may rest")
	assert_true(sim.train.is_holding(holder))


# --- Other ends of a hold ------------------------------------------------------

## A simulation with a holding train slime at x = -500 (its hold set from a
## record, tick 5000) and no crowd. Returns [sim, the slime].
func _holder() -> Array:
	var sim := _sim()
	sim.tick = 5000
	var slime := _train_slime(sim, -500.0)
	_settle(sim)
	var record := sim.train.record_of(slime)
	record["hold"] = sim.tick - 10
	sim.train.restore_record(slime, record)
	assert_true(sim.train.is_holding(slime))
	return [sim, slime]


# @test-link [[req_hopping_behavior]]
# @test-link [[rule_stalled_train_slime_moved_to_start]]
func test_a_stall_or_stuck_move_ends_the_hold() -> void:
	var run := _holder()
	var sim: Simulation = run[0]
	var slime: int = run[1]
	var record := sim.train.record_of(slime)
	record["marked_at"] = sim.tick - STALL_TICKS
	sim.train.restore_record(slime, record)
	_step(sim)
	assert_eq(sim.train.stalled.size(), 1, "moved to the start, stalled")
	assert_false(sim.train.is_holding(slime), "the move ends the hold")
	run = _holder()
	sim = run[0]
	slime = run[1]
	LoopStart.move(sim.slimes, sim.train, slime)
	assert_false(sim.train.is_holding(slime), "a stuck move too")


# A resting holder moved to the loop's start (the stall or stuck net) is
# woken: its hold ends there, and it hops on, not hanging as a wall.
# @test-link [[rule_stalled_train_slime_moved_to_start]]
# @test-link [[req_offscreen_simulation]]
func test_a_resting_holder_moved_to_the_start_wakes_and_hops_on() -> void:
	var sim := _sim(0.0)
	var front := _train_slime(sim, -NEAR)
	_settle(sim)
	sim.slimes.set_hop_timer(front, 0.0)
	assert_true(_until_resting(sim, [front], 70), "the holder rests")
	LoopStart.move(sim.slimes, sim.train, front)
	assert_eq(sim.slimes.calm_of(front), SlimeBodies.ACTIVE, "moved, it is woken")
	assert_false(sim.train.is_holding(front), "its hold ended")
	assert_false(_hops(sim, front, 600).is_empty(), "it hops on from the start")


# A resting holder whose steering progress reaches a slide (the return route
# starts at x = 1500) holds no more: it is woken, only it, and carried; its
# resting neighbour, a holder of another species touching it, rests on.
# @test-link [[req_hopping_behavior]]
func test_a_resting_holder_reaching_a_slide_ends_its_hold_and_wakes_its_neighbours_resting_on() -> void:
	var sim := _sim()
	var holder := _train_slime(sim, 1490.0)
	var neighbour := _train_slime(sim, 1490.0 - 2.0 * SlimeBodies.ring_radius_for(1) - 1.0, CROWD_SPECIES)
	_settle(sim)
	assert_true(sim.slimes.touching(holder, neighbour), "they touch")
	for slime in [holder, neighbour]:
		var record := sim.train.record_of(slime)
		record["hold"] = sim.tick - 10
		sim.train.restore_record(slime, record)
		sim.slimes.set_may_rest(slime, true)
	for i in 120:
		if [holder, neighbour].all(func(id): return sim.slimes.calm_of(id) == SlimeBodies.RESTING):
			break
		sim.slimes.tick(DT)
	assert_eq(sim.slimes.calm_of(holder), SlimeBodies.RESTING, "a resting holder")
	assert_eq(sim.slimes.calm_of(neighbour), SlimeBodies.RESTING, "its neighbour rests too")
	# Its progress just past the slide's start, its centre still at it.
	var record := sim.train.record_of(holder)
	record["distance"] = 3005.0
	sim.train.restore_record(holder, record)
	var centre := sim.slimes.centre_of(holder)
	assert_true(sim.train.is_slide_at(sim.train.steering_distance(3005.0, centre)), "it steers from a slide")
	sim.train.steer(sim.slimes, DT, sim.tick, sim.fusion)
	assert_false(sim.train.is_holding(holder), "the slide ends its hold")
	assert_ne(sim.slimes.calm_of(holder), SlimeBodies.RESTING, "it is woken")
	assert_true(sim.train.is_holding(neighbour), "its neighbour holds on")
	assert_eq(sim.slimes.calm_of(neighbour), SlimeBodies.RESTING, "and rests on")


# D147 (7): a resting holder carried onto a slide stops holding, is woken,
# and is carried (held from hopping, its speed pulled along the slide toward
# Train.SLIDE_SPEED), on that same steer.
# @test-link [[req_hopping_behavior]]
func test_a_resting_holder_on_a_slide_stops_holding_is_woken_and_is_carried() -> void:
	var sim := _sim()
	var holder := _train_slime(sim, 1490.0)
	_settle(sim)
	var record := sim.train.record_of(holder)
	record["hold"] = sim.tick - 10
	sim.train.restore_record(holder, record)
	sim.slimes.set_may_rest(holder, true)
	for i in 120:
		if sim.slimes.calm_of(holder) == SlimeBodies.RESTING:
			break
		sim.slimes.tick(DT)
	assert_eq(sim.slimes.calm_of(holder), SlimeBodies.RESTING, "a resting holder")
	record = sim.train.record_of(holder)
	record["distance"] = 3005.0
	sim.train.restore_record(holder, record)
	var tangent := sim.train.direction_at(3005.0)
	var along := sim.slimes.velocity_of(holder).dot(tangent)
	sim.train.steer(sim.slimes, DT, sim.tick, sim.fusion)
	assert_false(sim.train.is_holding(holder), "it stops holding")
	assert_ne(sim.slimes.calm_of(holder), SlimeBodies.RESTING, "it is woken")
	assert_true(sim.train.record_of(holder)["on_slide"], "it is on the slide")
	assert_ne(sim.slimes.held[sim.slimes.index_of(holder)], 0, "held from hopping, as the slide holds")
	var carried := along + (Train.SLIDE_SPEED - along) * Train.SLIDE_GRIP
	assert_almost_eq(sim.slimes.velocity_of(holder).dot(tangent), carried, 0.001,
			"carried: its speed pulled along the slide toward SLIDE_SPEED")


# @test-link [[req_hopping_behavior]]
func test_parking_or_a_call_ends_the_hold() -> void:
	var run := _holder()
	var sim: Simulation = run[0]
	var slime: int = run[1]
	sim.slimes.park(slime)
	_step(sim)
	assert_false(sim.train.is_holding(slime), "parked")
	sim.slimes.unpark(slime)
	run = _holder()
	sim = run[0]
	slime = run[1]
	sim.slimes.set_state(slime, SlimeBodies.FREE)
	_step(sim)
	assert_false(sim.train.is_holding(slime), "called")


# The dip nudge wins at a hold's end (D147 (7)): a holder pinned by the dip
# nudge on tick T (after the step's fusion, as Fusion._nudge sets it), whose
# hold ends at its re-check on T + 1 (its corridor clear), keeps the pin: it
# doesn't hop on T + 1 but when the pin runs out. The pin is set the tick
# BEFORE the hold's end: Simulation.step runs fusion after the train steers.
# @test-link [[rule_dip_may_nudge_fusion]]
# @test-link [[req_hopping_behavior]]
func test_a_dip_nudge_pin_set_the_tick_before_a_holds_end_wins_and_the_slime_hops_when_it_runs_out() -> void:
	var run := _holder()
	var sim: Simulation = run[0]
	var slime: int = run[1]
	# As a hold begins in play: its hop came due (the next steer keeps it at
	# the hold's floor).
	sim.slimes.set_hop_timer(slime, 0.0)
	var recheck := _next_check(sim, slime, sim.tick + 1)
	while sim.tick < recheck - 1:
		_step(sim)
	assert_true(sim.train.is_holding(slime), "it holds up to its re-check")
	# Tick T = recheck - 1, with the pin set after the step's fusion.
	sim.train.steer(sim.slimes, DT, sim.tick, sim.fusion)
	sim.slimes.tick(DT)
	sim.fusion.step(sim)
	sim.slimes.set_hop_timer(slime, maxf(sim.slimes.hop_timer_of(slime), Fusion.DIP_HOLD_SECONDS))
	sim.train.follow(sim.slimes, sim.tick)
	sim.tick += 1
	assert_eq(sim.tick, recheck)
	# When an untouched timer of DIP_HOLD_SECONDS from tick T runs out.
	var expected := recheck
	var left := Fusion.DIP_HOLD_SECONDS - DT
	while left > 0.0:
		left -= DT
		expected += 1
	var hops := _hops(sim, slime, 1)
	assert_false(sim.train.is_holding(slime), "its hold ended at the re-check")
	assert_eq(hops, [], "the pin is kept: no hop on T + 1")
	hops.append_array(_hops(sim, slime, expected - sim.tick + 10))
	assert_eq(hops, [expected], "it hops when the pin runs out")


# --- A holder that splits ------------------------------------------------------

# A holder split (in a split zone) hands its hold on to its parts
# (Train.inherit, as Simulation.step calls it). Each part's hold ends as any
# holder's: clear at a check, it hops then, not when the hop timer the part
# was created with (here a long one) runs out: only the dip nudge raises a
# holder's timer above the floor (D147 (7), TrainHold._let_go).
# @test-link [[req_hopping_behavior]]
func test_a_split_holders_parts_hop_when_their_inherited_hold_ends_clear() -> void:
	var sim := _sim()
	var slime := _train_slime(sim, -500.0, SPECIES_A, 2)
	_settle(sim)
	var record := sim.train.record_of(slime)
	record["hold"] = sim.tick - 10
	sim.train.restore_record(slime, record)
	# Its timer at the floor, as a holder's (TrainHold.keep_timer).
	sim.slimes.set_hop_timer(slime, TrainHold.HOLD_TIMER_SECONDS)
	var parts := sim.slimes.split(slime)
	assert_eq(parts.size(), 2, "two base parts")
	for k in range(1, parts.size()):
		sim.slimes.set_hop_timer(parts[k], 3.0)
	sim.train.inherit(parts, sim.slimes)
	for part in parts:
		assert_true(sim.train.is_holding(part), "part %d holds on" % part)
	var ended := {}
	var hopped := {}
	for i in 240:
		var tick := sim.tick
		var before := {}
		for part in parts:
			before[part] = sim.train.is_holding(part)
		_step(sim)
		for part in parts:
			if before[part] and not sim.train.is_holding(part) and not ended.has(part):
				ended[part] = tick
			if sim.slimes.train_hopped.has(part) and not hopped.has(part):
				hopped[part] = tick
	gut.p("holds ended %s, first hops %s" % [ended, hopped])
	for part in parts:
		assert_true(ended.has(part), "part %d's hold ended" % part)
		assert_true(hopped.has(part), "part %d hopped" % part)
		assert_between(hopped.get(part, 10000) - ended.get(part, 0), 0, 20,
				"part %d hops at its hold's end (on landing at worst), not on its own timer" % part)


# --- The dump ------------------------------------------------------------------

# @test-link [[req_hopping_behavior]]
func test_the_hold_is_in_the_dump_and_the_record_only_while_a_slime_holds() -> void:
	var run := _holder()
	var sim: Simulation = run[0]
	var slime: int = run[1]
	var entry: Dictionary = sim.train.dump()["slimes"][0]
	assert_eq(entry["hold"], sim.tick - 10, "the tick it began")
	assert_eq(sim.train.record_of(slime)["hold"], entry["hold"])
	var record := sim.train.record_of(slime)
	record.erase("hold")
	sim.train.restore_record(slime, record)
	assert_false(sim.train.is_holding(slime), "a record without it: no hold")
	assert_false(sim.train.dump()["slimes"][0].has("hold"), "left out of the dump")
	assert_false(sim.train.record_of(slime).has("hold"))
