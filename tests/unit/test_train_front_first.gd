extends GutTest
## The front-first order (chunk 22g, experimental, switchable: Train.front_first,
## Train.bucket_length; LoopBuckets). Off (the default), Train.steer processes
## the train slimes by ascending id and the holder rule reads the snapshot
## taken at the start of the tick, as before. On, it processes them front
## first by loop bucket (the bucket at the front of the loop first, ascending
## id inside a bucket), and the holder snapshot is live: each slime's entry
## is refreshed right after it decides (TrainHold.refresh), so a slime behind
## sees this tick's decision of the slimes ahead. The buckets are logical
## only, derived from the records' distances and the loop's length: no save
## key, a save and reload keeps the order.
##
## The world (as tests/unit/test_train_hold.gd's): a floor slab, its top at
## y = 0, the loop along it at a base slime's centre height from x = -1500 to
## 1500 (loop distance d is x = d - 1500), returning at y = 400. A crowd
## (tests/unit/hold_crowd_support.gd) is free slimes held still. The harness
## (_step) steps the train, the bodies, fusion and the train's follow in
## Simulation.step's order, without the free slimes' steering.

const Crowd := preload("res://tests/unit/hold_crowd_support.gd")
const DT := Simulation.TICK_SECONDS
const STAND_Y := Crowd.STAND_Y
const LOOP_START_X := -1500.0
const CROWD_COLUMNS := 8
const CROWD_ABOVE_ROWS := 4
const NEAR := Crowd.NEAR
const WALKER_X := -1200.0
## The live-snapshot pair: the slime behind and the front (100 px apart, not
## touching), in buckets 4 and 5 of the default length (d 1400 and 1500).
const BEHIND_X := -100.0
const FRONT_X := 0.0


# --- The harness ---------------------------------------------------------------

## The loop of the world (see the class doc).
func _level() -> LevelData:
	var data := LevelData.new("front-first", 1)
	var loop := LoopData.new("t.loop")
	loop.add_segment("t.loop.out", 1, LoopData.OUTGOING, PackedVector2Array([
			Vector2(-1500, -24), Vector2(1500, -24)]))
	loop.add_segment("t.loop.back", 1, LoopData.RETURN, PackedVector2Array([
			Vector2(1500, -24), Vector2(1500, 400), Vector2(-1500, 400), Vector2(-1500, -24)]), "t.gate")
	data.loop = loop
	data.first_slime = {"id": "t.first-slime", "species": "A", "position": Vector2(-1400, -24)}
	return data


## Two sections: section 1's loop (outgoing 1000 px, return 1200 px) is 2200
## px long; with its gate open, the loop runs on through section 2 and is 4200
## px long.
func _growing_loop() -> LoopData:
	var loop := LoopData.new("g.loop")
	loop.add_segment("g.s1.out", 1, LoopData.OUTGOING, PackedVector2Array([Vector2(0, 0), Vector2(1000, 0)]))
	loop.add_segment("g.s1.back", 1, LoopData.RETURN, PackedVector2Array([
			Vector2(1000, 0), Vector2(1000, 100), Vector2(0, 100), Vector2(0, 0)]), "g.s1.gate")
	loop.add_segment("g.s2.out", 2, LoopData.OUTGOING, PackedVector2Array([Vector2(1000, 0), Vector2(2000, 0)]))
	loop.add_segment("g.s2.back", 2, LoopData.RETURN, PackedVector2Array([
			Vector2(2000, 0), Vector2(2000, 100), Vector2(0, 100), Vector2(0, 0)]), "g.s2.gate")
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


## The hold tests' crowd, its first column at x = 0.
func _crowd_spots() -> Array[Vector2]:
	return Crowd.spots(0.0, 1.0, CROWD_COLUMNS, CROWD_ABOVE_ROWS)


## A base train slime standing on the floor at x = `x`, its next hop 10 s away.
func _train_slime(sim: Simulation, x: float) -> int:
	var slime := sim.slimes.create(0, 1, Vector2(x, STAND_Y), SlimeBodies.TRAIN)
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


## Steps `ticks` times; returns the [tick, id] of every train hop of `slimes`.
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


## Makes `slime` hold since `began` (as a saved record would).
func _hold(sim: Simulation, slime: int, began: int) -> void:
	var record := sim.train.record_of(slime)
	record["hold"] = began
	sim.train.restore_record(slime, record)


## The occupancy of `slime`'s hop corridor now.
func _occupancy(sim: Simulation, slime: int) -> float:
	var target := sim.train.hop_target(sim.train.distance_of(slime), Train.hop_reach(sim.slimes.size_of(slime)))
	return TrainHold.occupancy_of(sim.slimes, sim.slimes.centre_of(slime), target, slime)


## `sim`'s state as the state hash reads it, its identities aside (_sim()
## removes the level's first slime outside the game's paths, leaving its
## identity behind, which a save drops).
func _state(sim: Simulation) -> String:
	var dump := sim.dump()
	dump.erase("identities")
	return StateHash.canonical_json(dump)


## A queue of `count` holders before the crowd, front first (the front for
## the crowd, the others for the holder ahead), and a walker far behind
## (free to hop, its next hop 1000 s away) unless `walker` is false.
func _queue(sim: Simulation, count: int, walker := true) -> Array:
	if walker:
		sim.slimes.set_hop_timer(_train_slime(sim, WALKER_X), 1000.0)
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


## A simulation with the queue (_queue()) before the crowd. The train's
## switch is set to `on` first, and its bucket length to `bucket_length`
## when positive; with `on` null neither is touched.
func _queue_sim(on: Variant, bucket_length := -1.0) -> Simulation:
	var sim := _sim(_crowd_spots())
	if on != null:
		sim.train.front_first = on
		if bucket_length > 0.0:
			sim.train.bucket_length = bucket_length
	_queue(sim, 3)
	return sim


## Steps `sim` `ticks_before` ticks with the crowd, then removes it and steps
## `ticks_after` more. Returns `sim`.
func _run_then_clear(sim: Simulation, ticks_before: int, ticks_after: int) -> Simulation:
	for i in ticks_before:
		_step(sim)
	_remove_free(sim)
	for i in ticks_after:
		_step(sim)
	return sim


## Removes every free slime (the crowd).
func _remove_free(sim: Simulation) -> void:
	for slime_id in sim.slimes.ids():
		if sim.slimes.state_of(slime_id) == SlimeBodies.FREE:
			sim.slimes.remove(slime_id)


## A Train on the world's loop following `distances` (id -> px), ids ascending.
func _train(distances: Dictionary) -> Train:
	var train := Train.new(_level().loop)
	var ids := distances.keys()
	ids.sort()
	for slime_id: int in ids:
		train.track(slime_id, distances[slime_id])
	return train


# --- The order -------------------------------------------------------------------

# Off, the order is ascending id. On, the front of the loop first: the
# highest bucket first, ascending id inside a bucket; the bucket length
# picks the buckets.
# @test-link [[req_hopping_behavior]]
func test_off_the_order_is_by_id_on_it_is_front_first_by_bucket_then_id() -> void:
	var train := _train({1: 100.0, 2: 1550.0, 3: 1400.0, 4: 1510.0, 5: 6800.0, 6: 50.0})
	assert_false(train.front_first, "off by default")
	assert_eq(train.bucket_length, LoopBuckets.DEFAULT_BUCKET_LENGTH)
	assert_eq(train.processing_order(), PackedInt32Array([1, 2, 3, 4, 5, 6]), "off: by id")
	train.front_first = true
	assert_eq(train.processing_order(), PackedInt32Array([5, 2, 4, 3, 1, 6]),
			"on: buckets 22, 5 (ids 2, 4), 4, 0 (ids 1, 6)")
	train.bucket_length = 1000.0
	assert_eq(train.processing_order(), PackedInt32Array([5, 2, 3, 4, 1, 6]),
			"1000 px buckets: 6, 1 (ids 2, 3, 4), 0 (ids 1, 6)")


# A slime that advances into the next bucket moves there; one that leaves
# the train leaves the order.
# @test-link [[req_hopping_behavior]]
func test_a_slime_advancing_into_the_next_bucket_moves_there_and_one_leaving_the_train_leaves_the_order() -> void:
	var train := _train({1: 1490.0, 2: 1520.0, 3: 200.0})
	train.front_first = true
	assert_eq(train.processing_order(), PackedInt32Array([2, 1, 3]), "1 in bucket 4, 2 in bucket 5")
	train.advance(1, train.position_at(1530.0), 0)
	assert_almost_eq(train.distance_of(1), 1530.0, 0.01)
	assert_eq(train.processing_order(), PackedInt32Array([1, 2, 3]), "1 advanced into bucket 5, before 2 by id")
	var sim := _sim()
	sim.train.front_first = true
	var a := _train_slime(sim, -1300.0)
	var b := _train_slime(sim, 0.0)
	_step(sim)
	assert_eq(sim.train.processing_order(), PackedInt32Array([b, a]))
	sim.slimes.remove(b)
	_step(sim)
	assert_eq(sim.train.processing_order(), PackedInt32Array([a]), "gone from the records, gone from the order")


# A gate opening grows the loop: the buckets are cut again (more of them),
# every slime placed again by its distance.
# @test-link [[req_hopping_behavior]]
func test_a_gate_opening_cuts_the_buckets_again_for_the_longer_loop() -> void:
	var train := Train.new(_growing_loop())
	train.front_first = true
	train.bucket_length = 1000.0
	assert_almost_eq(train.length(), 2200.0, 0.01)
	train.track(1, 2150.0)
	train.track(2, 500.0)
	assert_eq(train.processing_order(), PackedInt32Array([1, 2]), "3 buckets: 1 in the last, 2 in the first")
	train.set_open_gates(["g.s1.gate"])
	assert_almost_eq(train.length(), 4200.0, 0.01)
	train.track(3, 3500.0)
	assert_eq(train.processing_order(), PackedInt32Array([3, 1, 2]),
			"5 buckets: 3 in bucket 3, ahead of 1 in bucket 2 (with the old 3 buckets both were in the last)")


# --- The live holder snapshot --------------------------------------------------

# The front holder lets go at its check (the way clear) on the tick the slime
# behind it is due: on, the slime behind (steered after it, though its id is
# lower) no longer sees it as a holder and hops too; off, it reads the start
# of the tick's snapshot and holds.
# @test-link [[req_hopping_behavior]]
func test_on_a_front_holder_letting_go_is_no_holder_for_the_slime_behind_that_tick_off_it_still_is() -> void:
	var outcomes := {}
	for on in [false, true]:
		var sim := _sim()
		sim.train.front_first = on
		var behind := _train_slime(sim, BEHIND_X)
		var front := _train_slime(sim, FRONT_X)
		_settle(sim)
		_hold(sim, front, sim.tick - 10)
		sim.slimes.set_hop_timer(front, TrainHold.HOLD_TIMER_SECONDS)
		var check := sim.tick
		while sim.train.hold().check_at(sim.slimes, front, check) == TrainHold.NO_CHECK:
			check += 1
		assert_eq(_hops(sim, [front, behind], check - sim.tick), [], "the front holds until its check")
		assert_true(sim.train.is_holding(front))
		sim.slimes.set_hop_timer(behind, 0.0)
		var hops := _hops(sim, [front, behind], 1)
		assert_has(hops, [check, front], "the front lets go and hops at its check (on: %s)" % on)
		outcomes[on] = [sim.train.is_holding(behind), hops.has([check, behind])]
	assert_eq(outcomes[false], [true, false], "off: the slime behind holds for the front's tick-start hold")
	assert_eq(outcomes[true], [false, true], "on: the slime behind sees the front let go, and hops")


# The front starts holding (a crowd ahead of it) on the tick the slime behind
# it is due: on, the slime behind sees the new holder and holds that tick;
# off, it doesn't yet and hops.
# @test-link [[req_hopping_behavior]]
func test_on_a_front_hold_started_this_tick_holds_the_slime_behind_that_tick_off_it_does_not() -> void:
	var outcomes := {}
	for on in [false, true]:
		var sim := _sim(Crowd.spots(FRONT_X + 50.0, 1.0, 5, 1))
		sim.train.front_first = on
		var behind := _train_slime(sim, BEHIND_X)
		var front := _train_slime(sim, FRONT_X)
		_settle(sim)
		assert_gt(_occupancy(sim, front), TrainHold.HOLD_OCCUPANCY, "a crowd ahead of the front")
		assert_lte(_occupancy(sim, behind), TrainHold.HOLD_OCCUPANCY, "not ahead of the one behind")
		for slime in [front, behind]:
			sim.slimes.set_hop_timer(slime, 0.0)
		var tick := sim.tick
		var hops := _hops(sim, [front, behind], 1)
		assert_true(sim.train.is_holding(front), "the front holds (on: %s)" % on)
		outcomes[on] = [sim.train.is_holding(behind), hops.has([tick, behind])]
	assert_eq(outcomes[false], [false, true], "off: the slime behind hops")
	assert_eq(outcomes[true], [true, false], "on: the slime behind holds behind the new holder")


# --- Off is today's path; on is deterministic and survives a save --------------

# The switch off (set explicitly, with another bucket length) gives the very
# state of a run that never touched it, tick for tick.
# @test-link [[req_offscreen_simulation]]
func test_off_the_state_matches_a_run_that_never_touched_the_switch() -> void:
	var untouched := _queue_sim(null)
	var off := _queue_sim(false, 500.0)
	assert_eq(_state(off), _state(untouched), "after the queue formed")
	for k in 4:
		for i in 60:
			_step(untouched)
			_step(off)
		assert_eq(_state(off), _state(untouched), "after %d s" % (k + 1))
	_remove_free(untouched)
	_remove_free(off)
	for i in 240:
		_step(untouched)
		_step(off)
	assert_eq(_state(off), _state(untouched), "after the crowd went and the queue hopped on")


# On: two runs give the same state; a save after n ticks (mid-hold, every
# slime on the ground: a save puts a slime in the air down, MidairLanding),
# reloaded into a fresh simulation with the switch on, runs m more to the
# state of a straight n + m run (the buckets need no save key).
# @test-link [[req_offscreen_simulation]]
# @test-link [[req_persistence_and_saves]]
func test_on_runs_repeat_and_a_save_and_reload_gives_the_straight_runs_state() -> void:
	var straight := _run_then_clear(_queue_sim(true), 120, 240)
	var again := _run_then_clear(_queue_sim(true), 120, 240)
	assert_eq(_state(again), _state(straight), "the same state twice")
	var first := _queue_sim(true)
	for i in 120:
		_step(first)
	var json := JSON.new()
	assert_eq(json.parse(SaveData.to_text(first.to_save())), OK)
	var save: Dictionary = json.data
	assert_false(JSON.stringify(save).contains("bucket"), "no bucket in the save")
	var reloaded := Simulation.from_save(save, _level(), Crowd.terrain(_crowd_spots()))
	assert_not_null(reloaded)
	if reloaded == null:
		return
	assert_eq(_state(reloaded), _state(first), "equal after the load")
	assert_false(reloaded.train.front_first, "the switch isn't saved")
	reloaded.train.front_first = true
	assert_eq(reloaded.train.processing_order(), first.train.processing_order(), "the same order after the load")
	_run_then_clear(reloaded, 0, 240)
	assert_eq(_state(reloaded), _state(straight), "the reloaded run reaches the straight run's state")


# --- The hold guard ------------------------------------------------------------

# On, a queue of three before a crowd that never thins, no other train
# slime: HOLD_GUARD_TICKS after the most recent hold began, the guard still
# releases the front-most holder, which hops on that tick.
# @test-link [[rule_loop_travelable_with_no_input]]
func test_on_the_guard_still_releases_the_front_most_holder_of_a_waiting_train() -> void:
	var sim := _sim(_crowd_spots())
	sim.train.front_first = true
	var queue := _queue(sim, 3, false)
	var latest := sim.train.hold_began_at(queue[-1])
	assert_eq(_hops(sim, queue, latest + TrainHold.HOLD_GUARD_TICKS - sim.tick), [], "the whole train waits")
	var hops := _hops(sim, queue, 1)
	assert_has(hops, [latest + TrainHold.HOLD_GUARD_TICKS, queue[0]], "the front, released at 4 s, hops")
	assert_eq(sim.train.hold_counters()["guard_releases"], 1)
	assert_false(sim.train.is_holding(queue[0]))


# --- The command-line flags ------------------------------------------------------

## The main scene, its build a debug build or not (TestModeGuard).
func _game(is_debug_build: bool) -> Node:
	var game: Node = load("res://src/main.tscn").instantiate()
	game.test_mode_guard = TestModeGuard.new(is_debug_build)
	add_child_autofree(game)
	return game


# --loop-buckets turns the switch on, --loop-bucket-length=PX sets the
# bucket length, on the running simulation's train and on every simulation
# the game takes after (a test-mode run, a fresh restart).
# @test-link [[req_platform_and_performance_targets]]
func test_the_flags_set_the_switch_on_every_simulations_train() -> void:
	var game := _game(true)
	assert_eq(game.use_loop_buckets(PackedStringArray()), PackedStringArray(), "not asked: nothing")
	assert_false(game.simulation.train.front_first)
	assert_eq(game.use_loop_buckets(PackedStringArray(["--loop-buckets", "--loop-bucket-length=500"])),
			PackedStringArray())
	var trains: Array[Train] = [game.simulation.train]
	assert_eq(game.enable_test_mode({"seed": 1}), PackedStringArray())
	trains.append(game.simulation.train)
	trains.append(game.restart_fresh().train)
	for train in trains:
		assert_true(train.front_first)
		assert_eq(train.bucket_length, 500.0)


# A malformed length or a flag given twice is an error, nothing set; a
# release build refuses the flags.
# @test-link [[req_platform_and_performance_targets]]
func test_the_flags_reject_a_bad_length_and_a_release_build() -> void:
	for args in [["--loop-buckets", "--loop-bucket-length=0"], ["--loop-buckets", "--loop-bucket-length=x"],
			["--loop-buckets", "--loop-buckets"]]:
		var game := _game(true)
		assert_eq(game.use_loop_buckets(PackedStringArray(args)).size(), 1, "%s" % [args])
		assert_false(game.simulation.train.front_first)
	var release := _game(false)
	assert_eq(release.use_loop_buckets(PackedStringArray(["--loop-buckets"])).size(), 1, "refused")


# Test mode leaves the flags to the game root: a scripted run takes them.
# @test-link [[req_platform_and_performance_targets]]
func test_test_mode_leaves_the_flags_to_the_game_root() -> void:
	var parsed: Dictionary = load("res://src/test_mode/test_mode.gd").config_from_args(PackedStringArray([
			"--test-mode", "--seed=1", "--loop-buckets", "--loop-bucket-length=500"]))
	assert_eq(parsed["errors"], PackedStringArray())
