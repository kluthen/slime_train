extends GutTest
## The hold's debug counters (chunk 22f step 1, D147 (1) and (8)): the
## Train's cumulative counters (Train.hold_counters(): how each hold began
## and ended, and what kind of train hop each one was) and its snapshot
## (Train.hold_snapshot(): holders, resting holders, train slimes resting
## without a hold, the back of the touching queues of 5 or more), the debug
## bar's "hold n" and the PERF line's fields. Read only: none of them is in
## the dump, the save or the state hash.
##
## The world (as tests/unit/test_train_hold.gd's): a floor slab, its top at
## y = 0, the loop along it at a base slime's centre height from x = -1500
## to 1500 (loop distance d is x = d - 1500), returning at y = 400. A crowd
## (tests/unit/hold_crowd_support.gd) is free slimes held still, base ones
## on the floor and bigger ones on their own shelves, filling the hop
## corridor of a slime NEAR px before its first column above the threshold
## (checked in test_train_hold_corridor.gd).

# @test-link [[req_platform_and_performance_targets]]

const Crowd := preload("res://tests/unit/hold_crowd_support.gd")
const DT := Simulation.TICK_SECONDS
const STAND_Y := Crowd.STAND_Y
const LOOP_START_X := -1500.0
const CROWD_COLUMNS := 8
const CROWD_ABOVE_ROWS := 4
const NEAR := Crowd.NEAR
## Two base slimes this far apart (centres) touch: 1 px between their rings.
const TOUCHING := 2.0 * SlimeBodies.RING_RADIUS_SIZE_1 + 1.0


# --- The harness ---------------------------------------------------------------

func _level() -> LevelData:
	var data := LevelData.new("hold-counters", 1)
	var loop := LoopData.new("t.loop")
	loop.add_segment("t.loop.out", 1, LoopData.OUTGOING, PackedVector2Array([
			Vector2(-1500, -24), Vector2(1500, -24)]))
	loop.add_segment("t.loop.back", 1, LoopData.RETURN, PackedVector2Array([
			Vector2(1500, -24), Vector2(1500, 400), Vector2(-1500, 400), Vector2(-1500, -24)]), "t.gate")
	data.loop = loop
	data.first_slime = {"id": "t.first-slime", "species": "A", "position": Vector2(-1400, -24)}
	return data


## A simulation on the world, its first slime removed, with a crowd whose
## first column is at x = `crowd_x` going right (none when INF).
func _sim(crowd_x := INF) -> Simulation:
	var spots: Array[Vector2] = []
	if crowd_x != INF:
		spots = Crowd.spots(crowd_x, 1.0, CROWD_COLUMNS, CROWD_ABOVE_ROWS)
	var sim := Simulation.new(5)
	sim.slimes.terrain = Crowd.terrain(spots)
	sim.load_level(_level())
	for slime_id in sim.slimes.ids():
		sim.slimes.remove(slime_id)
	sim.view.set_to(Vector2(-50, -50), 1.0, ScreenView.DEFAULT_SIZE)
	Crowd.place(sim.slimes, spots)
	return sim


## A base train slime standing on the floor at x = `x`, its next hop 10 s away.
func _train_slime(sim: Simulation, x: float, slime_species := 0) -> int:
	var slime := sim.slimes.create(slime_species, 1, Vector2(x, STAND_Y), SlimeBodies.TRAIN)
	sim.slimes.set_hop_timer(slime, 10.0)
	sim.train.track(slime, x - LOOP_START_X)
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


func _steps(sim: Simulation, ticks: int) -> void:
	for i in ticks:
		_step(sim)


## Where `slime` aims its next hop (Train.steer's target).
func _target(sim: Simulation, slime: int) -> Vector2:
	return sim.train.hop_target(sim.train.distance_of(slime), Train.hop_reach(sim.slimes.size_of(slime)))


## Whether `slime`'s crowd check fails now: its hop corridor's occupancy
## above the threshold.
func _crowded(sim: Simulation, slime: int) -> bool:
	return TrainHold.occupancy_of(sim.slimes, sim.slimes.centre_of(slime), _target(sim, slime), slime) \
			> TrainHold.HOLD_OCCUPANCY


## Removes crowd slimes (free slimes) in `slime`'s hop corridor, the latest
## first, until its crowd check passes.
func _thin_out(sim: Simulation, slime: int) -> void:
	Crowd.thin(sim.slimes, sim.slimes.centre_of(slime), _target(sim, slime), slime, false)
	assert_false(_crowded(sim, slime), "the crowd thinned")


## The counters that aren't 0, by name.
func _nonzero(sim: Simulation) -> Dictionary:
	var out := {}
	var counters := sim.train.hold_counters()
	for name: String in counters:
		if counters[name] != 0:
			out[name] = counters[name]
	return out


# --- The counters --------------------------------------------------------------

func test_the_counters_are_named_in_the_perf_lines_order_and_start_at_0() -> void:
	var sim := _sim()
	assert_eq(sim.train.hold_counters().keys(), ["hold_ends_clear", "hold_ends_cap", "guard_releases",
			"hold_ends_other", "front_hops", "queue_hops", "holder_holds", "crowd_holds", "crowded_hops"])
	assert_eq(_nonzero(sim), {})


## A crowd hold whose crowd thins ends at a re-check: a clear end, then a
## front hop through no crowd.
func test_a_crowd_hold_ending_at_a_re_check_counts_a_clear_end_and_a_front_hop() -> void:
	var sim := _sim(0.0)
	var slime := _train_slime(sim, -NEAR)
	_steps(sim, 30)
	assert_true(_crowded(sim, slime))
	sim.slimes.set_hop_timer(slime, 0.0)
	_step(sim)
	assert_true(sim.train.is_holding(slime))
	assert_eq(_nonzero(sim), {"crowd_holds": 1}, "a hold the crowd check started")
	_thin_out(sim, slime)
	# Its first re-check: HOLD_RECHECK_TICKS plus its phase (under
	# HOLD_RECHECK_TICKS) after the hold began.
	_steps(sim, 2 * TrainHold.HOLD_RECHECK_TICKS)
	assert_false(sim.train.is_holding(slime))
	assert_eq(sim.train.hops_taken, 1)
	assert_eq(_nonzero(sim), {"crowd_holds": 1, "hold_ends_clear": 1, "front_hops": 1},
			"ended by its checks, then a lone slime's hop: its own front")


## A crowd hold past its period's end, the crowd still there (a train slime
## far behind free to hop, so the hold guard doesn't fire): no hop, so no cap
## end and no crowded hop (D147 (2), no forced hop; 22e's cap end and crowded
## hop gone).
func test_a_crowd_hold_past_its_periods_end_counts_no_cap_end_and_no_crowded_hop() -> void:
	var sim := _sim(0.0)
	var slime := _train_slime(sim, -NEAR)
	var walker := _train_slime(sim, -1200.0)
	sim.slimes.set_hop_timer(walker, 1000.0)
	_steps(sim, 30)
	assert_true(_crowded(sim, slime))
	sim.slimes.set_hop_timer(slime, 0.0)
	_step(sim)
	var end: int = sim.train.hold().period_at(sim.slimes, slime, sim.tick).y
	_steps(sim, end + 1 - sim.tick)
	assert_eq(sim.train.hops_taken, 0, "no hop at its period's end")
	assert_true(sim.train.is_holding(slime))
	assert_true(_crowded(sim, slime), "the crowd still there")
	assert_eq(_nonzero(sim), {"crowd_holds": 1})


## A slime due behind a holder in its hop corridor (the holder rule) holds
## with its crowd check passing: a holder hold.
func test_a_hold_the_holder_rule_starts_counts_a_holder_hold() -> void:
	var sim := _sim()
	var ahead := _train_slime(sim, 0.0)
	var behind := _train_slime(sim, -NEAR)
	_steps(sim, 30)
	_hold(sim, ahead, sim.tick - 10)
	sim.slimes.set_hop_timer(behind, 0.0)
	_step(sim)
	assert_true(sim.train.is_holding(behind))
	assert_eq(_nonzero(sim), {"holder_holds": 1})


## A train hop taken behind a holder it touches, within reach: a queue hop,
## not a front hop. Alone, the same hop is a front hop. The hop is set
## directly in bodies.train_hopped, as a tick leaves it (since 22f no hold
## ends at a cap, and the holder rule keeps a slime behind a holder holding),
## and counted as Train.follow counts it (TrainHold.count_hops).
func test_a_hop_behind_a_touching_holder_is_a_queue_hop_a_lone_one_a_front_hop() -> void:
	for alone in [false, true]:
		var sim := _sim()
		var behind := _train_slime(sim, -TOUCHING)
		var ahead := -1 if alone else _train_slime(sim, 0.0)
		_steps(sim, 30)
		if not alone:
			assert_true(sim.slimes.touching(ahead, behind), "they touch")
			_hold(sim, ahead, sim.tick - 10)
		sim.slimes.train_hopped = PackedInt32Array([behind])
		sim.train.hold().count_hops(sim.slimes, sim.train.length())
		if alone:
			assert_eq(_nonzero(sim), {"front_hops": 1}, "alone: its own front")
		else:
			assert_eq(_nonzero(sim), {"queue_hops": 1}, "behind a holder")


## Parking, a call, a slide and a stall move each end a hold as another
## end; a record restored over a holding one (a gate opening) ends none.
func test_parking_a_call_a_slide_and_a_move_count_other_ends_a_restore_none() -> void:
	for end in ["park", "call", "slide", "move", "restore"]:
		var sim := _sim()
		var slime := _train_slime(sim, 1490.0 if end == "slide" else -500.0)
		_steps(sim, 30)
		_hold(sim, slime, sim.tick - 10)
		match end:
			"park":
				sim.slimes.park(slime)
			"call":
				sim.slimes.set_state(slime, SlimeBodies.FREE)
			"slide":
				var record := sim.train.record_of(slime)
				record["distance"] = 3005.0
				sim.train.restore_record(slime, record)
			"move":
				LoopStart.move(sim.slimes, sim.train, slime)
			"restore":
				_hold(sim, slime, sim.tick - 5)
		_step(sim)
		if end == "restore":
			assert_true(sim.train.is_holding(slime), end)
			assert_eq(_nonzero(sim), {}, end)
		else:
			assert_false(sim.train.is_holding(slime), end)
			assert_eq(_nonzero(sim), {"hold_ends_other": 1}, end)


# --- The snapshot, the bar and the PERF line -----------------------------------

## A touching queue of 5 at x = -500 + k * TOUCHING (its front the last), its
## back three and its front holding, the second resting; a train slime
## resting with no hold, far behind; a touching queue of 3 with one holder.
## Returns the simulation.
func _built() -> Simulation:
	var sim := _sim()
	var queue := []
	for k in 5:
		queue.append(_train_slime(sim, -500.0 + k * TOUCHING))
	for k in [0, 1, 2, 4]:
		_hold(sim, queue[k], sim.tick - 10)
	sim.slimes.calm[sim.slimes.index_of(queue[1])] = SlimeBodies.RESTING
	var lone := _train_slime(sim, -1200.0)
	sim.slimes.calm[sim.slimes.index_of(lone)] = SlimeBodies.RESTING
	var short := [_train_slime(sim, 400.0), _train_slime(sim, 400.0 + TOUCHING),
			_train_slime(sim, 400.0 + 2.0 * TOUCHING)]
	_hold(sim, short[0], sim.tick - 10)
	return sim


func test_the_snapshot_counts_holders_resting_slimes_and_the_back_of_queues_of_5_or_more() -> void:
	var sim := _built()
	var hash_before := sim.state_hash()
	assert_eq(sim.train.hold_snapshot(sim.slimes), {"holding": 5, "holding_resting": 1, "contact_resting": 1,
			"queue_back": 4, "queue_back_held": 3})
	assert_eq(sim.state_hash(), hash_before, "read only")


func test_the_bar_shows_the_holders() -> void:
	var sim := _built()
	var counts := DebugCounts.count_slimes(sim)
	assert_eq(counts[DebugCounts.HOLDING], 5)
	assert_string_ends_with(DebugCounts.slimes_text(counts), " : parked 0 : hold 5")


func test_the_perf_line_holds_the_snapshot_and_the_windows_counters() -> void:
	var sim := _built()
	var ticking := PerfLog.tick_stats(PackedFloat64Array([0.02]), PackedInt32Array([1]), PackedInt64Array([0]),
			PackedInt32Array([0]), PackedInt32Array([0]))
	var parts := PackedFloat64Array()
	parts.resize(PerfLog.PART_FIELDS.size())
	var period := PackedInt32Array([1, 2, 3, 4, 5, 6, 7, 8, 9])
	var hash_before := sim.state_hash()
	var text := PerfLog.line(1.0, PerfLog.window_stats(PackedFloat64Array([0.02])), ticking, 1.0, 1, 10, 3,
			sim, parts, period)
	assert_string_contains(text, " hops=10 short_hops=3 holding=5 holding_resting=1 contact_resting=1"
			+ " queue_back=4 queue_back_held=3 hold_ends_clear=1 hold_ends_cap=2 guard_releases=3"
			+ " hold_ends_other=4 front_hops=5 queue_hops=6 holder_holds=7 crowd_holds=8 crowded_hops=9 bodies=")
	assert_eq(sim.state_hash(), hash_before, "read only")
