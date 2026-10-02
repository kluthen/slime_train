extends GutTest
## The Train's bucket loads (chunk 22i, D151 point 1: Train.rebuild_loads,
## Train.bucket_loads(), Train.hop_landing_distance; BucketLoads). Kept
## always, read only by the bucket cap (off by default) and the debug
## counters: each loop bucket's load is the summed sizes of the train slimes
## whose recorded distance along the loop is in it, parked ones included;
## slimes in a basket, sleepers, bedtime-asleep and free slimes don't count.
## Simulation rebuilds them at the start of each tick and after a load; through
## the tick they follow the recorded distances, and a hop let through counts
## in its landing bucket until the slime's next follow().
##
## The world (as tests/unit/test_train_front_first.gd's): a floor slab, its
## top at y = 0, the loop along it at a base slime's centre height from
## x = -1500 to 1500 (loop distance d is x = d - 1500), returning at y = 400;
## 6848 px long, so 23 buckets of 300 px. The harness (_step) steps the
## train, the bodies, fusion and the train's follow in Simulation.step's
## order, the loads rebuilt first.

const Crowd := preload("res://tests/unit/hold_crowd_support.gd")
const DT := Simulation.TICK_SECONDS
const STAND_Y := Crowd.STAND_Y
const LOOP_START_X := -1500.0
## A train slime 250 px along the loop (bucket 0): its 150 px hop lands at
## 400 px, in bucket 1.
const HOPPER_X := -1250.0


# --- The harness ---------------------------------------------------------------

## The loop of the world (see the class doc).
func _level() -> LevelData:
	var data := LevelData.new("train-loads", 1)
	var loop := LoopData.new("t.loop")
	loop.add_segment("t.loop.out", 1, LoopData.OUTGOING, PackedVector2Array([
			Vector2(-1500, -24), Vector2(1500, -24)]))
	loop.add_segment("t.loop.back", 1, LoopData.RETURN, PackedVector2Array([
			Vector2(1500, -24), Vector2(1500, 400), Vector2(-1500, 400), Vector2(-1500, -24)]), "t.gate")
	data.loop = loop
	data.first_slime = {"id": "t.first-slime", "species": "A", "position": Vector2(-1400, -24)}
	return data


## Two sections: section 1's loop is 2200 px long; with its gate open, the
## loop runs on through section 2 and is 4200 px long.
func _growing_loop() -> LoopData:
	var loop := LoopData.new("g.loop")
	loop.add_segment("g.s1.out", 1, LoopData.OUTGOING, PackedVector2Array([Vector2(0, 0), Vector2(1000, 0)]))
	loop.add_segment("g.s1.back", 1, LoopData.RETURN, PackedVector2Array([
			Vector2(1000, 0), Vector2(1000, 100), Vector2(0, 100), Vector2(0, 0)]), "g.s1.gate")
	loop.add_segment("g.s2.out", 2, LoopData.OUTGOING, PackedVector2Array([Vector2(1000, 0), Vector2(2000, 0)]))
	loop.add_segment("g.s2.back", 2, LoopData.RETURN, PackedVector2Array([
			Vector2(2000, 0), Vector2(2000, 100), Vector2(0, 100), Vector2(0, 0)]), "g.s2.gate")
	return loop


## The loop of tests/unit/test_train_progress.gd: a step at 400 px (up 100
## px), a drop at 900 px into the return route; 1920 px long.
func _step_loop() -> LoopData:
	var loop := LoopData.new("start.loop")
	loop.add_segment("s1.loop", 1, LoopData.OUTGOING, PackedVector2Array([
			Vector2(0, 0), Vector2(400, 0), Vector2(400, -100), Vector2(800, -100)]))
	loop.add_segment("s1.slide", 1, LoopData.RETURN, PackedVector2Array([
			Vector2(800, -100), Vector2(800, 60), Vector2(0, 60), Vector2(0, 0)]), "s1.gate")
	return loop


## A simulation (seed 5) on the world, its first slime removed, the view on
## it, with a crowd at `spots`.
func _sim(spots: Array[Vector2] = []) -> Simulation:
	var sim := Simulation.new(5)
	sim.slimes.terrain = Crowd.terrain(spots)
	sim.load_level(_level())
	for slime_id in sim.slimes.ids():
		sim.slimes.remove(slime_id)
	sim.view.set_to(Vector2(-50, -50), 1.0, ScreenView.DEFAULT_SIZE)
	Crowd.place(sim.slimes, spots)
	return sim


## A slime of `size` in `state` standing on the floor at x = `x`, its next
## hop 10 s away; a train slime is followed at its distance along the loop.
func _slime(sim: Simulation, x: float, size := 1, state := SlimeBodies.TRAIN) -> int:
	var lift := SlimeBodies.ring_radius_for(size) - SlimeBodies.ring_radius_for(1)
	var slime := sim.slimes.create(0, size, Vector2(x, STAND_Y - lift), state)
	sim.slimes.set_hop_timer(slime, 10.0)
	if state == SlimeBodies.TRAIN:
		sim.train.track(slime, x - LOOP_START_X)
	return slime


## One tick in Simulation.step's order: the loads rebuilt, the train steers,
## the bodies tick, fusion counts, the train follows.
func _step(sim: Simulation) -> void:
	sim.train.rebuild_loads(sim.slimes)
	sim.train.steer(sim.slimes, DT, sim.tick, sim.fusion)
	sim.slimes.tick(DT)
	sim.fusion.step(sim)
	sim.train.follow(sim.slimes, sim.tick)
	sim.tick += 1


## Steps 30 ticks: the slimes settle where they were put.
func _settle(sim: Simulation) -> void:
	for i in 30:
		_step(sim)


## The summed loads.
func _total(loads: BucketLoads) -> int:
	var total := 0
	for value in loads.loads():
		total += value
	return total


# --- Who counts ----------------------------------------------------------------

# Weighted by size, parked train slimes included; a slime in a basket, a
# bedtime-asleep one (records not yet dropped by follow()), a sleeper and a
# free slime not counted.
# @test-link [[req_hopping_behavior]]
func test_the_loads_weigh_train_slimes_by_size_parked_ones_included_and_nothing_else() -> void:
	var sim := _sim()
	_slime(sim, -1400.0, 1)
	_slime(sim, -1350.0, 2)
	_slime(sim, -1000.0, 3)
	var parked := _slime(sim, -500.0, 1)
	sim.slimes.park(parked)
	var in_basket := _slime(sim, -450.0, 2)
	sim.slimes.set_state(in_basket, SlimeBodies.IN_BASKET)
	var asleep := _slime(sim, -440.0, 3)
	sim.slimes.set_state(asleep, SlimeBodies.BEDTIME_ASLEEP)
	_slime(sim, -1450.0, 2, SlimeBodies.FREE)
	_slime(sim, -1300.0, 3, SlimeBodies.SLEEPER)
	sim.train.rebuild_loads(sim.slimes)
	var loads := sim.train.bucket_loads()
	assert_eq(loads.count(), 23, "6848 px in 300 px buckets")
	assert_eq(loads.load(0), 3, "sizes 1 and 2 at 100 and 150 px")
	assert_eq(loads.load(1), 3, "a size 3 at 500 px")
	assert_eq(loads.load(3), 1, "the parked size 1 at 1000 px; the basket's and the asleep one not")
	assert_eq(_total(loads), 7, "the free slime and the sleeper not counted")
	assert_eq(loads.bucket_of(in_basket), -1)


# Simulation.load_level sets the level's base slimes (the first slime and
# the sleepers) and counts the first slime; Simulation.step rebuilds the
# loads at the start of each tick.
# @test-link [[req_hopping_behavior]]
func test_the_simulation_sets_the_base_slimes_and_rebuilds_the_loads() -> void:
	var sim := Simulation.new(5)
	sim.slimes.terrain = Crowd.terrain([])
	sim.load_level(_level())
	assert_eq(sim.train.base_slimes, 1, "the first slime, no sleeper")
	assert_eq(sim.train.bucket_loads().load(0), 1, "the first slime, 100 px along the loop")
	var other := _slime(sim, 0.0, 2)
	sim.view.set_to(Vector2(-50, -50), 1.0, ScreenView.DEFAULT_SIZE)
	sim.step()
	assert_eq(sim.train.bucket_loads().bucket_of(other), 5, "counted from the next tick, at 1500 px")
	assert_eq(_total(sim.train.bucket_loads()), 3)
	var empty := _level()
	empty.first_slime = {}
	var bare := Simulation.new(5)
	bare.load_level(empty)
	assert_eq(bare.train.base_slimes, 0, "no first slime, no sleeper")


# A gate opening grows the loop: the next rebuild cuts it again (more
# buckets) and places every slime again by its distance.
# @test-link [[req_hopping_behavior]]
func test_a_gate_opening_cuts_the_loop_again_and_every_slime_is_placed_again() -> void:
	var sim := Simulation.new(5)
	var train := Train.new(_growing_loop())
	var a := sim.slimes.create(0, 1, Vector2(100, -24))
	var b := sim.slimes.create(0, 2, Vector2(900, -24))
	train.track(a, 2150.0)
	train.track(b, 900.0)
	train.rebuild_loads(sim.slimes)
	var loads := train.bucket_loads()
	assert_eq(loads.count(), 8, "2200 px")
	assert_eq(loads.loads()[7], 1)
	assert_eq(loads.loads()[3], 2)
	train.set_open_gates(["g.s1.gate"])
	train.rebuild_loads(sim.slimes)
	assert_eq(loads.count(), 14, "4200 px")
	assert_eq(loads.bucket_of(a), 7)
	assert_eq(loads.bucket_of(b), 3)
	assert_eq(_total(loads), 3, "every slime counted once")
	train.bucket_length = 1000.0
	train.rebuild_loads(sim.slimes)
	assert_eq(loads.count(), 5, "a new bucket length cuts again too")
	assert_eq(loads.bucket_of(a), 2)


# --- Through a tick --------------------------------------------------------------

# A hop let through counts in its landing bucket from the steer that aims
# it; after the slime's follow() it counts where its progress is.
# @test-link [[req_hopping_behavior]]
func test_a_hop_let_through_counts_in_its_landing_bucket_until_its_follow() -> void:
	var sim := _sim()
	var hopper := _slime(sim, HOPPER_X)
	_settle(sim)
	var loads := sim.train.bucket_loads()
	sim.slimes.set_hop_timer(hopper, 0.0)
	sim.train.rebuild_loads(sim.slimes)
	assert_eq(loads.bucket_of(hopper), 0)
	sim.train.steer(sim.slimes, DT, sim.tick, sim.fusion)
	assert_false(sim.train.is_holding(hopper))
	assert_eq(loads.bucket_of(hopper), 1, "its hop lands at 400 px")
	assert_eq(loads.load(1), 1)
	assert_eq(loads.load(0), 0)
	sim.slimes.tick(DT)
	sim.train.follow(sim.slimes, sim.tick)
	assert_true(sim.slimes.train_hopped.has(hopper), "it took off")
	assert_eq(loads.bucket_of(hopper), loads.bucket_index(sim.train.distance_of(hopper)),
			"after its follow it counts where its progress is")
	assert_eq(_total(loads), 1)


# D151 (1): while in the air a slime counts where its progress is. An
# airborne train slime whose hop timer is due is aimed but can't take off
# (SlimeBodies._auto_hops hops a supported slime only), so its weight
# stays in its progress's bucket.
# @test-link [[req_hopping_behavior]]
func test_an_airborne_slime_with_a_due_hop_counts_where_its_progress_is() -> void:
	var sim := _sim()
	var hopper := _slime(sim, HOPPER_X)
	_settle(sim)
	var loads := sim.train.bucket_loads()
	sim.slimes.set_hop_timer(hopper, 0.0)
	sim.slimes.supported[sim.slimes.index_of(hopper)] = 0
	sim.train.rebuild_loads(sim.slimes)
	assert_eq(loads.bucket_of(hopper), 0)
	sim.train.steer(sim.slimes, DT, sim.tick, sim.fusion)
	assert_false(sim.train.is_holding(hopper))
	assert_eq(loads.bucket_of(hopper), 0, "in the air: still at its progress's bucket")
	assert_eq(loads.load(0), 1)
	assert_eq(loads.load(1), 0)


# A hop held (a crowd in the hop corridor) moves no weight.
# @test-link [[req_hopping_behavior]]
func test_a_held_hop_counts_where_the_slime_is() -> void:
	var sim := _sim(Crowd.spots(HOPPER_X + 50.0, 1.0, 5, 1))
	var hopper := _slime(sim, HOPPER_X)
	_settle(sim)
	sim.slimes.set_hop_timer(hopper, 0.0)
	_step(sim)
	assert_true(sim.train.is_holding(hopper), "the crowd holds it")
	sim.train.rebuild_loads(sim.slimes)
	sim.train.steer(sim.slimes, DT, sim.tick, sim.fusion)
	assert_true(sim.train.is_holding(hopper))
	assert_eq(sim.train.bucket_loads().bucket_of(hopper), 0, "still in its own bucket")


# A parked slime's advance and a move to the loop start carry its weight
# to its new bucket; a slime that leaves the train stops counting at its
# follow().
# @test-link [[req_hopping_behavior]]
# @test-link [[req_offscreen_simulation]]
func test_an_advance_and_a_move_to_the_loop_start_carry_the_weight_and_leaving_the_train_drops_it() -> void:
	var sim := _sim()
	var slime := _slime(sim, -1210.0, 2)
	var leaver := _slime(sim, -900.0, 3)
	sim.train.rebuild_loads(sim.slimes)
	var loads := sim.train.bucket_loads()
	assert_eq(loads.bucket_of(slime), 0, "290 px")
	sim.train.advance(slime, sim.train.position_at(320.0), sim.tick)
	assert_eq(loads.bucket_of(slime), 1, "advanced to 320 px")
	assert_eq(loads.load(1), 2)
	sim.train.track(slime, 6800.0)
	assert_eq(loads.bucket_of(slime), 22, "moved to 6800 px, the last bucket")
	assert_eq(loads.load(1), 0)
	sim.slimes.set_state(leaver, SlimeBodies.FREE)
	sim.train.follow(sim.slimes, sim.tick)
	assert_eq(loads.bucket_of(leaver), -1, "no longer a train slime")
	assert_eq(_total(loads), 2)


# --- The landing distance ---------------------------------------------------------

# hop_landing_distance mirrors hop_target: on flat ground, to a step's foot,
# over a step, round the loop's end, the target is the loop point at the
# landing distance; at a drop the landing distance is the drop's top, the
# target DROP_OVER px past it.
# @test-link [[req_hopping_behavior]]
func test_the_landing_distance_agrees_with_the_hop_target() -> void:
	var train := Train.new(_step_loop())
	var reach := Train.hop_reach(1)
	assert_almost_eq(train.hop_landing_distance(100.0, reach), 100.0 + reach, 0.001, "flat")
	assert_almost_eq(train.hop_landing_distance(250.0, 200.0), 400.0 - Train.STEP_FOOT, 0.001, "a step's foot")
	assert_almost_eq(train.hop_landing_distance(390.0, reach), 500.0 + Train.STEP_LANDING, 0.001, "over the step")
	assert_almost_eq(train.hop_landing_distance(750.0, reach), 900.0, 0.001, "a drop's top")
	assert_eq(train.hop_target(750.0, reach), train.position_at(900.0) + Vector2(Train.DROP_OVER, 0))
	for size in [1, 2, 3]:
		var size_reach := Train.hop_reach(size)
		for k in 192:
			var progress := k * 10.0
			var landing := train.hop_landing_distance(progress, size_reach)
			var target := train.hop_target(progress, size_reach)
			var at := train.position_at(landing)
			if at.is_equal_approx(target):
				continue
			assert_almost_eq(target.distance_to(at), Train.DROP_OVER, 0.001,
					"only a drop's target leaves the loop (size %d at %.0f)" % [size, progress])
			assert_almost_eq(landing, 900.0, 0.001, "the drop's top")


# --- Not state ------------------------------------------------------------------

# The loads are not state: rebuilding and carrying them changes no dump,
# and a save holds no bucket; a reload rebuilds the same loads.
# @test-link [[req_platform_and_performance_targets]]
# @test-link [[req_persistence_and_saves]]
func test_the_loads_change_no_state_and_a_reload_rebuilds_them() -> void:
	var sim := _sim()
	for x in [-1400.0, -1300.0, -800.0, 200.0]:
		_slime(sim, x, 2)
	_settle(sim)
	var before := StateHash.canonical_json(sim.dump())
	sim.train.bucket_length = 100.0
	sim.train.rebuild_loads(sim.slimes)
	assert_eq(StateHash.canonical_json(sim.dump()), before, "a rebuild with a new cut changes no state")
	sim.train.bucket_length = LoopBuckets.DEFAULT_BUCKET_LENGTH
	sim.train.rebuild_loads(sim.slimes)
	var json := JSON.new()
	assert_eq(json.parse(SaveData.to_text(sim.to_save())), OK)
	var save: Dictionary = json.data
	assert_false(JSON.stringify(save).contains("bucket"), "no bucket in the save")
	var reloaded := Simulation.from_save(save, _level(), Crowd.terrain([]))
	assert_not_null(reloaded)
	if reloaded == null:
		return
	assert_eq(reloaded.train.bucket_loads().loads(), sim.train.bucket_loads().loads(), "the same loads after a load")
