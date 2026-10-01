extends GutTest
## The hold (chunk 22e, D145; Train.steer). When a train slime's hop is due
## it holds (doesn't hop) while more than Train.HOLD_CROWD Physics slimes out
## of a basket are within Train.HOLD_CROWD_RADIUS of its hop's target and
## ahead of it (the crowd check), or while its hop would come within the two
## radii plus Train.JAM_GAP of the rearmost holding train slime ahead of it
## along the loop (the jam check). It checks again every
## Train.HOLD_RECHECK_TICKS and hops anyway after Train.HOLD_CAP_TICKS. A
## holding slime may rest (not while one of its contacts counts toward
## fusion); the celebration wakes a resting holder for its double hop; a
## stall or stuck move, parking and a call end the hold. The hold is in the
## train's dump only while a slime holds.
##
## The world: a floor slab, its top at y = 0 (y 0 to SLAB, x -2000 to 2000).
## The loop runs along it at a base slime's centre height (y = -24) from
## x = -1500 to 1500 and returns at y = 400: loop distance d is x = d - 1500
## on the outgoing part. A crowd is a grid of free slimes held still (they
## never hop), CROWD_COLUMNS columns CROWD_SPACING px apart, one row under the
## floor slab, one on the floor and four above it, every slime off the floor
## on its own small shelf: none touches another, so they stay put, Physics
## slimes (calm ACTIVE) that never rest. The harness (_step) steps the train,
## the bodies, fusion and the train's follow in Simulation.step's order,
## without the free slimes' steering, which would move the crowd.

const F := preload("res://tests/unit/frontier_test_support.gd")
const DT := Simulation.TICK_SECONDS
## A base slime's centre height when standing on the floor (y = 0).
const STAND_Y := -(SlimeBodies.RING_RADIUS_SIZE_1 + SlimeBodies.EDGE)
const LOOP_START_X := -1500.0
const SLAB := 6.0
const CROWD_COLUMNS := 8
const CROWD_SPACING := 50.0
const ROW_HEIGHT := 54.0
const SHELF_HALF_WIDTH := 22.0
const SHELF_THICKNESS := 4.0
const CROWD_SPECIES := 2
const SPECIES_A := 0
## How far the slime nearest a crowd stands from its first column, px, and
## the spacing of a queue of holders: neither touches.
const NEAR := 60.0
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


## The centres of a crowd whose first column is at x = `from_x`, its columns
## going `way` (1 right, -1 left).
func _crowd_spots(from_x: float, way: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for row in range(-1, 5):
		var y := STAND_Y - ROW_HEIGHT * row if row >= 0 else SLAB + 2.0 - STAND_Y
		for column in CROWD_COLUMNS:
			out.append(Vector2(from_x + way * CROWD_SPACING * column, y))
	return out


## A simulation on the world, its first slime removed, the view on it, with
## a crowd from x = `crowd_x` going `way` (none when `crowd_x` is INF).
func _sim(crowd_x := INF, way := 1.0) -> Simulation:
	var spots: Array[Vector2] = []
	if crowd_x != INF:
		spots = _crowd_spots(crowd_x, way)
	var polygons := [PackedVector2Array([Vector2(-2000, 0), Vector2(2000, 0), Vector2(2000, SLAB),
			Vector2(-2000, SLAB)])]
	for at in spots:
		if at.y == STAND_Y:
			continue
		var top := at.y - STAND_Y
		polygons.append(PackedVector2Array([Vector2(at.x - SHELF_HALF_WIDTH, top),
				Vector2(at.x + SHELF_HALF_WIDTH, top), Vector2(at.x + SHELF_HALF_WIDTH, top + SHELF_THICKNESS),
				Vector2(at.x - SHELF_HALF_WIDTH, top + SHELF_THICKNESS)]))
	var sim := Simulation.new(5)
	sim.slimes.terrain = TerrainSegments.new(polygons)
	sim.load_level(_level())
	for slime_id in sim.slimes.ids():
		sim.slimes.remove(slime_id)
	sim.view.set_to(Vector2(-50, -50), 1.0, ScreenView.DEFAULT_SIZE)
	for at in spots:
		var slime := sim.slimes.create(CROWD_SPECIES, 1, at, SlimeBodies.FREE)
		sim.slimes.set_hop_held(slime, true)
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


## Whether the centre `c` is in `slime`'s crowd check: within the radius of
## its hop's target, ahead of it.
func _ahead(sim: Simulation, slime: int, c: Vector2) -> bool:
	var target := _target(sim, slime)
	var from := sim.slimes.centre_of(slime)
	return c.distance_to(target) < Train.HOLD_CROWD_RADIUS and (c - from).dot(target - from) > 0.0


## The crowd check's count for `slime`.
func _count_ahead(sim: Simulation, slime: int) -> int:
	return sim.slimes.awake_count_ahead(_target(sim, slime), Train.HOLD_CROWD_RADIUS,
			sim.slimes.centre_of(slime), slime)


## Removes crowd slimes (free slimes) counted in `slime`'s crowd check, the
## latest first, until it counts `wanted`.
func _thin_to(sim: Simulation, slime: int, wanted: int) -> void:
	var ids := Array(sim.slimes.ids())
	ids.reverse()
	for other in ids:
		if _count_ahead(sim, slime) <= wanted:
			break
		if sim.slimes.state_of(other) == SlimeBodies.FREE and _ahead(sim, slime, sim.slimes.centre_of(other)):
			sim.slimes.remove(other)
	assert_eq(_count_ahead(sim, slime), wanted, "the crowd thinned")


## Steps until every slime of `slimes` rests (at most `limit` ticks);
## whether they all did.
func _until_resting(sim: Simulation, slimes: Array, limit: int) -> bool:
	for i in limit:
		if slimes.all(func(id): return sim.slimes.calm_of(id) == SlimeBodies.RESTING):
			return true
		_step(sim)
	return slimes.all(func(id): return sim.slimes.calm_of(id) == SlimeBodies.RESTING)


## Steps 30 ticks: the slimes settle where they were put.
func _settle(sim: Simulation) -> void:
	for i in 30:
		_step(sim)


# --- The crowd check -----------------------------------------------------------

# @test-link [[req_hopping_behavior]]
func test_a_slime_with_more_than_30_physics_slimes_ahead_holds_and_checks_again_every_half_second() -> void:
	var sim := _sim(0.0)
	var slime := _train_slime(sim, -NEAR)
	_settle(sim)
	assert_gt(_count_ahead(sim, slime), Train.HOLD_CROWD, "a crowd ahead of its hop")
	_thin_to(sim, slime, Train.HOLD_CROWD + 1)
	sim.slimes.set_hop_timer(slime, 0.0)
	var began := sim.tick
	assert_eq(_hops(sim, slime, 45), [], "it holds, and at the re-check 0.5 s on, 31 still ahead")
	assert_true(sim.train.is_holding(slime))
	assert_eq(sim.train.hold_began_at(slime), began, "the hold is the tick it began")
	_thin_to(sim, slime, Train.HOLD_CROWD)
	assert_eq(_hops(sim, slime, 16), [began + 2 * Train.HOLD_RECHECK_TICKS],
			"no hop between the checks; it hops at the first re-check with 30 ahead")
	assert_false(sim.train.is_holding(slime), "the hold ended")


# @test-link [[req_hopping_behavior]]
func test_30_or_fewer_ahead_or_a_crowd_behind_only_does_not_hold_it() -> void:
	var sim := _sim(0.0)
	var slime := _train_slime(sim, -NEAR)
	_settle(sim)
	_thin_to(sim, slime, Train.HOLD_CROWD)
	sim.slimes.set_hop_timer(slime, 0.0)
	var due := sim.tick
	assert_eq(_hops(sim, slime, 1), [due], "30 ahead: it hops when due")
	assert_false(sim.train.is_holding(slime))
	var behind := _sim(0.0, -1.0)
	var front := _train_slime(behind, NEAR)
	_settle(behind)
	assert_gt(behind.slimes.crowd_count() - 1, Train.HOLD_CROWD, "a crowd")
	assert_eq(_count_ahead(behind, front), 0, "all of it behind the slime")
	behind.slimes.set_hop_timer(front, 0.0)
	due = behind.tick
	assert_eq(_hops(behind, front, 1), [due], "a crowd behind it only: it hops when due")
	assert_false(behind.train.is_holding(front))


# @test-link [[req_hopping_behavior]]
func test_a_queues_front_whose_way_is_clear_hops_first_while_the_slimes_behind_it_hold() -> void:
	var sim := _sim(0.0)
	var behind := _train_slime(sim, -NEAR)
	var further_behind := _train_slime(sim, -2.0 * NEAR)
	var front := _train_slime(sim, CROWD_SPACING * (CROWD_COLUMNS - 1) + NEAR)
	_settle(sim)
	assert_eq(_count_ahead(sim, front), 0, "the front's way is clear, the crowd behind it")
	for slime in [behind, further_behind, front]:
		sim.slimes.set_hop_timer(slime, 0.0)
	_step(sim)
	assert_true(sim.slimes.train_hopped.has(front), "the front hops")
	assert_false(sim.train.is_holding(front))
	for slime in [behind, further_behind]:
		assert_false(sim.slimes.train_hopped.has(slime), "the slimes behind it don't")
		assert_true(sim.train.is_holding(slime), "they hold")


# --- The jam check -------------------------------------------------------------

# @test-link [[req_hopping_behavior]]
# @test-link [[req_offscreen_simulation]]
func test_a_slime_arriving_behind_a_resting_queue_stops_short_of_it_and_wakes_none_of_it() -> void:
	var sim := _sim(0.0)
	var queue := [_train_slime(sim, -NEAR), _train_slime(sim, -2.0 * NEAR), _train_slime(sim, -3.0 * NEAR)]
	var gap := Train.hop_reach(1) + 2.0 * SlimeBodies.ring_radius_for(1) + Train.JAM_GAP
	var arriving := _train_slime(sim, -3.0 * NEAR - gap - NEAR)
	_settle(sim)
	for slime in queue:
		sim.slimes.set_hop_timer(slime, 0.0)
	var began := sim.tick
	_step(sim)
	for slime in queue:
		assert_true(sim.train.is_holding(slime), "the queue holds")
	assert_true(_until_resting(sim, queue, 60), "and rests")
	sim.slimes.set_hop_timer(arriving, 0.0)
	var hops := []
	var woken := 0
	while sim.tick < began + Train.HOLD_CAP_TICKS - 10:
		hops.append_array(_hops(sim, arriving, 1))
		for slime in queue:
			woken += 0 if sim.slimes.calm_of(slime) == SlimeBodies.RESTING else 1
	assert_eq(hops.size(), 1, "one hop, then it holds")
	assert_true(sim.train.is_holding(arriving), "it holds behind the jam")
	assert_lte(_count_ahead(sim, arriving), Train.HOLD_CROWD, "not for a crowd")
	var rear: int = queue[-1]
	var left := sim.train.distance_of(rear) - sim.train.distance_of(arriving)
	assert_gt(left, 2.0 * SlimeBodies.ring_radius_for(1) + Train.JAM_GAP, "it stopped short of the jam")
	assert_lte(left, gap, "its hop would have come within the gap")
	assert_eq(woken, 0, "every queue slime rests on throughout")


# --- The cap -------------------------------------------------------------------

# @test-link [[req_hopping_behavior]]
func test_a_holder_hops_at_5_s_whatever_the_crowd() -> void:
	var sim := _sim(0.0)
	var slime := _train_slime(sim, -NEAR)
	_settle(sim)
	assert_gt(_count_ahead(sim, slime), Train.HOLD_CROWD)
	sim.slimes.set_hop_timer(slime, 0.0)
	var began := sim.tick
	assert_eq(_hops(sim, slime, Train.HOLD_CAP_TICKS + 1), [began + Train.HOLD_CAP_TICKS], "at the cap")
	assert_gt(_count_ahead(sim, slime), Train.HOLD_CROWD, "the crowd still there")
	assert_false(sim.train.is_holding(slime))


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
	_thin_to(sim, front, Train.HOLD_CROWD)
	var end := began + 3 * Train.HOLD_RECHECK_TICKS
	assert_eq(_hops(sim, front, end - sim.tick), [], "resting, holding")
	assert_eq(sim.slimes.calm_of(front), SlimeBodies.RESTING)
	assert_eq(_hops(sim, front, 1), [end], "its hold ends: it wakes and hops")
	assert_ne(sim.slimes.calm_of(front), SlimeBodies.RESTING)
	assert_eq(sim.slimes.calm_of(neighbour), SlimeBodies.RESTING, "its neighbour rests on")
	_step(sim)
	assert_eq(sim.slimes.calm_of(neighbour), SlimeBodies.RESTING, "still")


# @test-link [[rule_fusion_contact_time]]
func test_a_holding_slime_touching_a_slime_it_may_fuse_with_does_not_rest_until_they_fuse() -> void:
	var sim := _sim(0.0)
	var holder := _train_slime(sim, -NEAR)
	var partner := _train_slime(sim, -NEAR - 2.0 * SlimeBodies.ring_radius_for(1) - 1.0)
	_settle(sim)
	assert_true(sim.slimes.touching(holder, partner), "they touch")
	assert_true(sim.fusion.counts_toward_fusion(holder), "their contact counts")
	sim.slimes.set_hop_timer(holder, 0.0)
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


# --- The celebration -----------------------------------------------------------

# @test-link [[req_level_completion_celebration]]
func test_a_resting_holder_on_screen_does_the_celebrations_double_hop() -> void:
	var sim := F.sim(3)
	sim.frontier.tap_switch(sim, F.SWITCH)
	F.slime(sim, 3, -750, SlimeBodies.IN_BASKET)
	sim.slimes.auto_hops = false
	var holder := sim.spawn_train_slime(Species.from_letter("A"), 1, 300.0)
	for i in 30:
		sim.slimes.tick(DT)
	var hold := sim.tick
	var record := sim.train.record_of(holder)
	record["hold"] = hold
	sim.train.restore_record(holder, record)
	sim.slimes.set_may_rest(holder, true)
	for i in 60:
		sim.slimes.tick(DT)
	assert_eq(sim.slimes.calm_of(holder), SlimeBodies.RESTING, "a resting holder")
	F.frontier_steps(sim, F.REWARD_TICKS + 1)
	assert_false(sim.frontier.celebration_done, "the burst is about to begin")
	# Its next re-check, where its hold would end (no crowd, no jam) and wake it.
	var recheck := hold + Train.HOLD_RECHECK_TICKS * ((sim.tick - hold) / Train.HOLD_RECHECK_TICKS + 1)
	var hops := []
	var holds_on := false
	for i in F.CELEBRATION_TICKS + 2:
		var tick := sim.tick
		sim.step()
		if sim.slimes.hopped.has(holder):
			holds_on = holds_on or (hops.is_empty() and sim.train.is_holding(holder))
			hops.append(tick)
	gut.p("hops at %s, the burst from tick %d, the re-check at %d" % [hops, sim.frontier.celebration_since, recheck])
	assert_true(sim.frontier.celebration_done, "the burst played")
	assert_eq(hops.size(), CelebrationHops.HOPS, "the double hop")
	assert_lt(hops[0] if not hops.is_empty() else recheck, recheck,
			"woken by the burst's start, it hops before its hold could end")
	assert_true(holds_on, "its hold goes on")


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
