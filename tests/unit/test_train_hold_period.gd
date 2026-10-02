extends GutTest
## The hold's period, its re-check phase and the hold guard (chunk 22f,
## D147 (2) and (3); TrainHold.check_at, TrainHold.guard). A hold's period is
## TrainHold.HOLD_CAP_TICKS plus a seeded extra (0 to HOLD_EXTRA_MAX ticks);
## at its end the checks run again and, still blocked, the slime holds on
## for a new period: no forced hop, for a crowd hold and a holder-only hold
## alike (O109's default). Its re-checks start HOLD_RECHECK_TICKS plus a
## seeded phase after the hold began. The draws come from derived streams
## `hold:<id>:<period start>`, rebuilt after a load from the saved hold
## alone. The hold guard releases the front-most holder once the whole train
## has waited HOLD_GUARD_TICKS. Hold time counts toward a stall (O110's
## default).
##
## The world (as tests/unit/test_train_hold.gd's): a floor slab, its top at
## y = 0, the loop along it at a base slime's centre height from x = -1500
## to 1500 (loop distance d is x = d - 1500), returning at y = 400. A crowd
## (tests/unit/hold_crowd_support.gd) is free slimes held still, base ones
## on the floor and bigger ones on their own shelves, filling the hop
## corridor of a slime NEAR px before its first column above the threshold
## (checked in test_train_hold_corridor.gd). A walker is a train slime far behind with its next hop 1000 s away: free to
## hop (not holding, not resting, not held), it keeps the hold guard from
## firing. The harness (_step) steps the train, the bodies, fusion and the
## train's follow in Simulation.step's order, without the free slimes'
## steering, which would move the crowd.

const Crowd := preload("res://tests/unit/hold_crowd_support.gd")
const DT := Simulation.TICK_SECONDS
const STAND_Y := Crowd.STAND_Y
const LOOP_START_X := -1500.0
const CROWD_COLUMNS := 8
const CROWD_ABOVE_ROWS := 4
const NEAR := Crowd.NEAR
const WALKER_X := -1200.0
const STALL_TICKS := int(Train.STALL_SECONDS * Simulation.TICK_RATE)


# --- The harness ---------------------------------------------------------------

## The loop of the world (see the class doc).
func _level() -> LevelData:
	var data := LevelData.new("hold-period", 1)
	var loop := LoopData.new("t.loop")
	loop.add_segment("t.loop.out", 1, LoopData.OUTGOING, PackedVector2Array([
			Vector2(-1500, -24), Vector2(1500, -24)]))
	loop.add_segment("t.loop.back", 1, LoopData.RETURN, PackedVector2Array([
			Vector2(1500, -24), Vector2(1500, 400), Vector2(-1500, 400), Vector2(-1500, -24)]), "t.gate")
	data.loop = loop
	data.first_slime = {"id": "t.first-slime", "species": "A", "position": Vector2(-1400, -24)}
	return data


## The centres of a crowd whose first column is at x = 0.
func _crowd_spots() -> Array[Vector2]:
	return Crowd.spots(0.0, 1.0, CROWD_COLUMNS, CROWD_ABOVE_ROWS)


## A simulation (seed `seed_value`) on the world, its first slime removed,
## the view on it, with the crowd (`crowd`) or none.
func _sim(crowd := true, seed_value := 5) -> Simulation:
	var spots: Array[Vector2] = _crowd_spots() if crowd else ([] as Array[Vector2])
	var sim := Simulation.new(seed_value)
	sim.slimes.terrain = Crowd.terrain(spots)
	sim.load_level(_level())
	for slime_id in sim.slimes.ids():
		sim.slimes.remove(slime_id)
	sim.view.set_to(Vector2(-50, -50), 1.0, ScreenView.DEFAULT_SIZE)
	Crowd.place(sim.slimes, spots)
	return sim


## A base train slime standing on the floor at x = `x`, its next hop 10 s away.
func _train_slime(sim: Simulation, x: float) -> int:
	var slime := sim.slimes.create(0, 1, Vector2(x, STAND_Y), SlimeBodies.TRAIN)
	sim.slimes.set_hop_timer(slime, 10.0)
	sim.train.track(slime, x - LOOP_START_X)
	return slime


## A walker (see the class doc).
func _walker(sim: Simulation) -> int:
	var walker := _train_slime(sim, WALKER_X)
	sim.slimes.set_hop_timer(walker, 1000.0)
	return walker


## One tick in Simulation.step's order: the train steers, the bodies tick,
## fusion counts, the train follows.
func _step(sim: Simulation) -> void:
	sim.train.steer(sim.slimes, DT, sim.tick, sim.fusion)
	sim.slimes.tick(DT)
	sim.fusion.step(sim)
	sim.train.follow(sim.slimes, sim.tick)
	sim.tick += 1


## Steps `ticks` times; returns the ticks at which any of `slimes` took a
## train hop, as [tick, id] pairs.
func _hops(sim: Simulation, slimes: Array, ticks: int) -> Array:
	var out := []
	for i in ticks:
		var tick := sim.tick
		_step(sim)
		for slime in slimes:
			if sim.slimes.train_hopped.has(slime):
				out.append([tick, slime])
	return out


## Steps 30 ticks: the slimes settle where they were put.
func _settle(sim: Simulation) -> void:
	for i in 30:
		_step(sim)


## Whether `slime`'s crowd check fails now.
func _crowded(sim: Simulation, slime: int) -> bool:
	var target := sim.train.hop_target(sim.train.distance_of(slime), Train.hop_reach(sim.slimes.size_of(slime)))
	return TrainHold.occupancy_of(sim.slimes, sim.slimes.centre_of(slime), target, slime) > TrainHold.HOLD_OCCUPANCY


## `sim`'s state as the state hash reads it (Simulation.dump, canonical),
## its identities aside: _sim() removes the level's first slime outside the
## game's paths, leaving its identity behind, which a save drops.
func _state(sim: Simulation) -> String:
	var dump := sim.dump()
	dump.erase("identities")
	return StateHash.canonical_json(dump)


## Holder `slime`'s current period, Vector2i(start, end).
func _period(sim: Simulation, slime: int) -> Vector2i:
	return sim.train.hold().period_at(sim.slimes, slime, sim.tick)


## A queue of holders before the crowd, front first, each one's hold begun a
## tick after the one ahead (the front for the crowd, the others for the
## holder ahead: the holder rule). Returns the queue.
func _queue(sim: Simulation, count: int) -> Array:
	var queue := []
	for k in count:
		queue.append(_train_slime(sim, -NEAR * (k + 1)))
	_settle(sim)
	for slime in queue:
		sim.slimes.set_hop_timer(slime, 0.0)
		_step(sim)
	for slime in queue:
		assert_true(sim.train.is_holding(slime), "the queue holds")
	return queue


# --- The period ----------------------------------------------------------------

# The front holds for the crowd, the one behind it for the holder ahead (a
# holder-only hold); past each one's period end (5 s plus its extra) both
# hold on, a new period begun at the old one's end: no hop.
# @test-link [[req_hopping_behavior]]
func test_a_crowd_hold_and_a_holder_only_hold_past_their_period_end_hold_on_for_a_new_period() -> void:
	var sim := _sim()
	var walker := _walker(sim)
	var queue := _queue(sim, 2)
	var front: int = queue[0]
	var behind: int = queue[1]
	assert_true(_crowded(sim, front), "the front holds for the crowd")
	assert_false(_crowded(sim, behind), "the one behind for the holder ahead only")
	assert_eq(sim.train.hold_counters()["holder_holds"], 1)
	var ends := []
	for slime in queue:
		var period := _period(sim, slime)
		var began := sim.train.hold_began_at(slime)
		assert_eq(period.x, began, "the first period begins with the hold")
		assert_between(period.y - began, TrainHold.HOLD_CAP_TICKS, TrainHold.HOLD_CAP_TICKS + TrainHold.HOLD_EXTRA_MAX,
				"5 s plus an extra of 0 to 1 s")
		assert_eq(sim.train.hold().check_at(sim.slimes, slime, period.y), TrainHold.PERIOD_END)
		ends.append(period.y)
	var last: int = ends.max()
	assert_eq(_hops(sim, queue + [walker], last + 2 - sim.tick), [], "no hop at a period's end")
	for k in queue.size():
		assert_true(sim.train.is_holding(queue[k]), "slime %d holds on" % k)
		assert_eq(_period(sim, queue[k]).x, ends[k], "a new period, begun at the old one's end")
		assert_gt(_period(sim, queue[k]).y, ends[k])
	assert_eq(sim.train.hold_counters()["hold_ends_cap"], 0)
	assert_eq(sim.train.hold_counters()["hold_ends_clear"], 0)
	assert_eq(sim.train.hold_counters()["crowded_hops"], 0)
	assert_eq(sim.train.hold_counters()["guard_releases"], 0, "the walker is free to hop: no guard")


# The extra and the phase: a pure function of the seed, the slime's id and
# the period's start (the stream `hold:<id>:<start>`: its first draw the
# extra, the first period's second its phase), drawing nothing from the
# master Rng; the same for the same seed, different across seeds and ids.
# @test-link [[req_hopping_behavior]]
func test_the_extra_and_the_phase_repeat_for_a_seed_and_differ_across_seeds_and_ids() -> void:
	var start := 1000
	var draws := {}
	for seed_value in [1, 2, 1]:
		var master := Rng.new(seed_value)
		var state_before := master.state
		var bodies := SlimeBodies.new(master)
		var records := {}
		for slime_id in range(1, 9):
			records[slime_id] = {"distance": 0.0, "hold": start}
		var hold := TrainHold.new(records)
		var sample := []
		for slime_id in range(1, 9):
			var phase := hold.phase_of(bodies, slime_id)
			var first := hold.period_at(bodies, slime_id, start + 1)
			var second := hold.period_at(bodies, slime_id, first.y + 1)
			assert_between(phase, 0, TrainHold.HOLD_RECHECK_TICKS - 1)
			assert_eq(second.x, first.y, "a period begins at the last one's end")
			var stream := Rng.new(Rng.derive_seed(seed_value, "hold:%d:%d" % [slime_id, start]))
			assert_eq(first.y - start - TrainHold.HOLD_CAP_TICKS, stream.randi_range(0, TrainHold.HOLD_EXTRA_MAX),
					"the extra: the stream's first draw")
			assert_eq(phase, stream.randi_range(0, TrainHold.HOLD_RECHECK_TICKS - 1), "the phase: its second")
			var later := Rng.new(Rng.derive_seed(seed_value, "hold:%d:%d" % [slime_id, first.y]))
			assert_eq(second.y - second.x - TrainHold.HOLD_CAP_TICKS, later.randi_range(0, TrainHold.HOLD_EXTRA_MAX),
					"the next period's extra: its own stream's first draw")
			sample.append([phase, first.y, second.y])
		assert_eq(master.state, state_before, "no draw from the master")
		if draws.has(seed_value):
			assert_eq(sample, draws[seed_value], "the same seed: the same draws")
		draws[seed_value] = sample
	assert_ne(draws[1], draws[2], "another seed: other draws")
	var phases := {}
	var extras := {}
	for entry: Array in draws[1]:
		phases[entry[0]] = true
		extras[entry[1]] = true
	assert_gt(phases.size(), 1, "the ids' phases differ")
	assert_gt(extras.size(), 1, "the ids' extras differ")


# A save mid-hold, past the first re-check, reloads with no new save key: the
# phase and the periods are rebuilt from the saved hold start; both runs
# cross a period end, then the crowd thins in both and the slime hops on the
# same tick; the state hashes match throughout.
# @test-link [[req_hopping_behavior]]
# @test-link [[req_persistence_and_saves]]
func test_a_save_and_reload_mid_hold_gives_the_same_later_hops_and_state_hash() -> void:
	var sim := _sim()
	var walker := _walker(sim)
	var front: int = _queue(sim, 1)[0]
	var began := sim.train.hold_began_at(front)
	for i in TrainHold.HOLD_RECHECK_TICKS * 3:
		_step(sim)
	assert_true(sim.train.is_holding(front), "mid-hold")
	var json := JSON.new()
	assert_eq(json.parse(SaveData.to_text(sim.to_save())), OK)
	var save: Dictionary = json.data
	assert_eq(SaveData.problems(save, _level()), PackedStringArray())
	var reloaded := Simulation.from_save(save, _level(), Crowd.terrain(_crowd_spots()))
	assert_not_null(reloaded)
	if reloaded == null:
		return
	assert_eq(reloaded.train.hold_began_at(front), began)
	assert_eq(_state(reloaded), _state(sim), "equal after the load")
	assert_eq(reloaded.train.hold().phase_of(reloaded.slimes, front), sim.train.hold().phase_of(sim.slimes, front),
			"the phase rebuilt")
	var end := _period(sim, front).y
	assert_eq(_period(reloaded, front).y, end, "the period rebuilt")
	var runs := [sim, reloaded]
	var hops := [[], []]
	for k in 2:
		hops[k].append_array(_hops(runs[k], [front, walker], end + 1 - runs[k].tick))
		assert_true(runs[k].train.is_holding(front), "past its period's end, it holds on")
		for slime_id in runs[k].slimes.ids():
			if runs[k].slimes.state_of(slime_id) == SlimeBodies.FREE:
				runs[k].slimes.remove(slime_id)
		hops[k].append_array(_hops(runs[k], [front, walker], 2 * TrainHold.HOLD_RECHECK_TICKS))
	assert_eq(hops[1], hops[0], "the same hops after the load")
	assert_eq(hops[0].size(), 1, "the front hops once, at a re-check, the crowd gone")
	assert_eq(_state(reloaded), _state(sim), "equal past the period's end and the hop")


# --- The hold guard ------------------------------------------------------------

# A queue of three before a crowd that never thins, no other train slime:
# the whole train waits. HOLD_GUARD_TICKS after the most recent hold began,
# the guard releases the front-most holder, the queue's front (the longest
# gap to the next train slime ahead: round the loop to the queue's back),
# which hops on that tick through the crowd; once, the others hold on.
# @test-link [[req_hopping_behavior]]
# @test-link [[rule_loop_travelable_with_no_input]]
func test_the_guard_releases_the_front_most_holder_of_a_waiting_train_once_after_4_s() -> void:
	var sim := _sim()
	var queue := _queue(sim, 3)
	var latest := sim.train.hold_began_at(queue[-1])
	var hops := _hops(sim, queue, latest + TrainHold.HOLD_GUARD_TICKS - sim.tick)
	assert_eq(hops, [], "the whole train waits")
	assert_true(_crowded(sim, queue[0]), "the front's crowd still there")
	hops = _hops(sim, queue, 1)
	assert_eq(hops, [[latest + TrainHold.HOLD_GUARD_TICKS, queue[0]]], "the front, released at 4 s, hops")
	assert_eq(sim.train.hold_counters()["guard_releases"], 1)
	assert_false(sim.train.is_holding(queue[0]))
	assert_true(sim.train.is_holding(queue[1]) and sim.train.is_holding(queue[2]), "the others hold on")
	assert_eq(sim.train.hold_counters()["crowded_hops"], 0, "a guard release is no crowded hop")
	assert_eq(sim.train.hold_counters()["hold_ends_clear"], 0)
	for i in 30:
		_step(sim)
	assert_eq(sim.train.hold_counters()["guard_releases"], 1, "one release per firing")


# The same queue with a walker free to hop: the guard never fires, past 4 s
# and past the periods' ends.
# @test-link [[req_hopping_behavior]]
# @test-link [[rule_loop_travelable_with_no_input]]
func test_the_guard_does_not_fire_while_a_train_slime_is_free_to_hop() -> void:
	var sim := _sim()
	_walker(sim)
	var queue := _queue(sim, 3)
	var latest := sim.train.hold_began_at(queue[-1])
	assert_eq(_hops(sim, queue, latest + TrainHold.HOLD_GUARD_TICKS + 60 - sim.tick), [])
	assert_eq(sim.train.hold_counters()["guard_releases"], 0)
	for slime in queue:
		assert_true(sim.train.is_holding(slime))


## A train slime far behind (x = WALKER_X + 100) pinned by the dip nudge: its
## hop timer at Fusion.DIP_HOLD_SECONDS, kept there by _step_pinned as the
## nudge does after fusion counts. Not a holder.
func _pinned(sim: Simulation) -> int:
	var pinned := _train_slime(sim, WALKER_X + 100.0)
	sim.slimes.set_hop_timer(pinned, Fusion.DIP_HOLD_SECONDS)
	return pinned


## Steps `ticks` times as _hops() does, `pinned`'s timer kept at the dip
## nudge's pin after fusion (Simulation.step's order: the nudge is fusion's
## last part); returns the ticks at which any of `slimes` took a train hop.
func _hops_pinned(sim: Simulation, pinned: int, slimes: Array, ticks: int) -> Array:
	var out := []
	for i in ticks:
		var tick := sim.tick
		sim.train.steer(sim.slimes, DT, sim.tick, sim.fusion)
		sim.slimes.tick(DT)
		sim.fusion.step(sim)
		sim.slimes.set_hop_timer(pinned, maxf(sim.slimes.hop_timer_of(pinned), Fusion.DIP_HOLD_SECONDS))
		sim.train.follow(sim.slimes, sim.tick)
		sim.tick += 1
		for slime in slimes:
			if sim.slimes.train_hopped.has(slime):
				out.append([tick, slime])
	return out


# A queue of three before a crowd that never thins and one more train slime,
# not holding but pinned by the dip nudge: it waits too, so the whole train
# waits, and the guard releases the queue's front 4 s after the latest hold
# began, as with no other slime.
# @test-link [[req_hopping_behavior]]
# @test-link [[rule_loop_travelable_with_no_input]]
func test_the_guard_counts_a_slime_pinned_by_the_dip_nudge_as_waiting() -> void:
	var sim := _sim()
	var queue := _queue(sim, 3)
	var pinned := _pinned(sim)
	var latest := sim.train.hold_began_at(queue[-1])
	var hops := _hops_pinned(sim, pinned, queue + [pinned], latest + TrainHold.HOLD_GUARD_TICKS - sim.tick)
	assert_eq(hops, [], "the whole train waits")
	assert_false(sim.train.is_holding(pinned), "the pinned slime doesn't hold")
	hops = _hops_pinned(sim, pinned, queue + [pinned], 1)
	assert_eq(hops, [[latest + TrainHold.HOLD_GUARD_TICKS, queue[0]]], "the front, released at 4 s, hops")
	assert_eq(sim.train.hold_counters()["guard_releases"], 1)


# The same queue and pinned slime with a walker free to hop (awake, not
# pinned): the guard never fires.
# @test-link [[req_hopping_behavior]]
# @test-link [[rule_loop_travelable_with_no_input]]
func test_the_guard_does_not_fire_with_a_pinned_slime_while_another_is_free_to_hop() -> void:
	var sim := _sim()
	_walker(sim)
	var queue := _queue(sim, 3)
	var pinned := _pinned(sim)
	var latest := sim.train.hold_began_at(queue[-1])
	assert_eq(_hops_pinned(sim, pinned, queue + [pinned], latest + TrainHold.HOLD_GUARD_TICKS + 60 - sim.tick), [])
	assert_eq(sim.train.hold_counters()["guard_releases"], 0)


# Front-most: the longest gap to the next train slime ahead (a parked one
# counts), by the records' distances round the loop; a tie to the lower id;
# at the same distance the lower id is ahead.
# @test-link [[req_hopping_behavior]]
# @test-link [[rule_loop_travelable_with_no_input]]
func test_the_front_most_holder_has_the_longest_gap_ahead_a_tie_going_to_the_lower_id() -> void:
	var bodies := SlimeBodies.new(Rng.new(1))
	var ids := []
	for k in 3:
		ids.append(bodies.create(0, 1, Vector2(100.0 * k, 0.0), SlimeBodies.TRAIN))
	var length := 1000.0
	var records := {ids[0]: {"distance": 0.0}, ids[1]: {"distance": 500.0}}
	assert_eq(TrainHold.front_most(records, bodies, [ids[1], ids[0]], length), ids[0], "a tie: the lower id")
	records = {ids[0]: {"distance": 500.0}, ids[1]: {"distance": 0.0}}
	assert_eq(TrainHold.front_most(records, bodies, [ids[1], ids[0]], length), ids[0], "either way round")
	records = {ids[0]: {"distance": 0.0}, ids[1]: {"distance": 500.0}, ids[2]: {"distance": 200.0}}
	bodies.park(ids[2])
	assert_eq(TrainHold.front_most(records, bodies, [ids[0], ids[1]], length), ids[1],
			"a parked slime ahead counts: 0 -> 200 against 500 -> 0 round the loop")
	records[ids[2]]["distance"] = 600.0
	assert_eq(TrainHold.front_most(records, bodies, [ids[0], ids[1]], length), ids[0],
			"0 -> 500 against 500 -> 600")
	records = {ids[0]: {"distance": 300.0}, ids[1]: {"distance": 300.0}}
	assert_eq(TrainHold.front_most(records, bodies, [ids[0], ids[1]], length), ids[0],
			"the same distance: the lower id ahead, a whole loop to the next")
	assert_eq(TrainHold.front_most({ids[0]: {"distance": 10.0}}, bodies, [ids[0]], length), ids[0], "alone")


# --- The stall -----------------------------------------------------------------

# Hold time doesn't count toward a stall (D152, O110 flipped): a holder
# before a crowd that never thins, its hold and its last stall mark both
# 60 s old less 40 ticks, a walker free to hop (so no guard): each tick it
# holds moves its mark on by one, so the stall net doesn't move it at 60 s
# (nor 20 ticks later).
# @test-link [[rule_stalled_train_slime_moved_to_start]]
# @test-link [[req_hopping_behavior]]
func test_a_holder_with_no_progress_for_60_s_is_not_moved_by_the_stall_net() -> void:
	var sim := _sim()
	sim.tick = 5000
	_walker(sim)
	var front: int = _queue(sim, 1)[0]
	var record := sim.train.record_of(front)
	var mark := sim.tick - STALL_TICKS + 40
	record["hold"] = mark
	record["marked_at"] = mark
	sim.train.restore_record(front, record)
	for i in 60:
		_step(sim)
		assert_true(sim.train.is_holding(front), "it holds")
		assert_eq(sim.train.marked_at_of(front), mark + i + 1, "its stall mark moves on with the hold")
	assert_eq(sim.train.stalled, [] as Array[Dictionary], "not moved")
