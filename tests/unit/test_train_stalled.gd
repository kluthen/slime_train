extends GutTest
## The stalled safety net (D118, D121, build plan item 23.13): a train slime
## whose progress hasn't advanced Train.STALL_ADVANCE px in
## Train.STALL_SECONDS, or whose centre is out of the level's bounds, is
## stalled: Train.follow() moves it to the start of the loop, back on the
## train (LoopStart, the move lost and stuck slimes take too), and logs it in
## `train.stalled` with the reason "stalled" or "out_of_bounds", every time;
## the 60 s count starts again from the move. A slime asleep at bedtime is
## never counted nor moved. The log is in the dump and in saves.
##
## The world: a floor whose top is at y = 0 from x = -6000 to 6000. The loop
## runs along it at a base slime's centre height (y = -24) from x = -5000 to
## 5000 and returns under the floor (y = 400). Loop distance d is x = d - 5000
## on the outgoing part. The wedge: no slime hops (SlimeBodies.auto_hops off),
## so a train slime's progress can't advance.
# @test-link [[rule_stalled_train_slime_moved_to_start]]
# @test-link [[req_loop_and_world]]

const START := Vector2(-5000, -24)
const STALL_TICKS := int(Train.STALL_SECONDS * Simulation.TICK_RATE)


func _level() -> LevelData:
	var data := LevelData.new("stalled", 1)
	var loop := LoopData.new("t.loop")
	loop.add_segment("t.loop.out", 1, LoopData.OUTGOING, PackedVector2Array([
			Vector2(-5000, -24), Vector2(5000, -24)]))
	loop.add_segment("t.loop.back", 1, LoopData.RETURN, PackedVector2Array([
			Vector2(5000, -24), Vector2(5000, 400), Vector2(-5000, 400), Vector2(-5000, -24)]), "t.gate")
	data.loop = loop
	data.first_slime = {"id": "t.first-slime", "species": "A", "position": Vector2(-4900, -24)}
	return data


func _terrain() -> TerrainSegments:
	return TerrainSegments.new([
		PackedVector2Array([Vector2(-6000, 0), Vector2(6000, 0), Vector2(6000, 300), Vector2(-6000, 300)]),
	])


## A simulation on the synthetic level with one wedged size-`size` train
## slime 3000 px along the loop (the first slime is removed). Returns it as
## [sim, slime id].
func _wedged(master_seed := 5, size := 1) -> Array:
	var sim := Simulation.new(master_seed)
	sim.slimes.terrain = _terrain()
	sim.load_level(_level())
	for slime_id in sim.slimes.ids():
		sim.slimes.remove(slime_id)
	sim.view.set_to(Vector2(-2000, -200), 1.0, ScreenView.DEFAULT_SIZE)
	sim.slimes.auto_hops = false
	return [sim, sim.spawn_train_slime(0, size, 3000.0)]


func _entry(slime_id: int, tick: int, reason: String) -> Dictionary:
	return {"id": slime_id, "tick": tick, "reason": reason}


func _at_start(sim: Simulation, slime_id: int) -> void:
	assert_eq(sim.slimes.state_of(slime_id), SlimeBodies.TRAIN, "back on the train")
	assert_almost_eq(sim.train.distance_of(slime_id), 0.0, 0.001, "at the start of the loop")
	var lift := Offscreen.lift(sim.slimes.size_of(slime_id))
	assert_almost_eq(sim.slimes.centre_of(slime_id), START + Vector2(0, -lift), Vector2(0.5, 0.5))


func test_a_wedged_train_slime_goes_to_the_start_after_60_s_and_is_logged() -> void:
	var run := _wedged()
	var sim: Simulation = run[0]
	var slime: int = run[1]
	# The first follow (tick 0) marks its progress: the 60 s count starts there.
	sim.run(STALL_TICKS)
	assert_eq(sim.train.stalled, [] as Array[Dictionary], "not yet")
	assert_almost_eq(sim.slimes.centre_of(slime).x, -2000.0, 5.0, "wedged where it was")
	sim.run(1)
	assert_eq(sim.train.stalled, [_entry(slime, STALL_TICKS, Train.STALLED)] as Array[Dictionary])
	_at_start(sim, slime)
	assert_eq(sim.offscreen.lost, [] as Array[Dictionary], "stalled is not lost")


func test_wedged_again_it_is_moved_and_logged_again() -> void:
	var run := _wedged()
	var sim: Simulation = run[0]
	var slime: int = run[1]
	sim.run(STALL_TICKS + 1)
	# The count starts again from the move: the next follow marks it.
	var again := STALL_TICKS + 1 + STALL_TICKS
	sim.run(again - sim.tick)
	assert_eq(sim.train.stalled.size(), 1, "not before 60 s from the move")
	sim.run(1)
	assert_eq(sim.train.stalled, [_entry(slime, STALL_TICKS, Train.STALLED),
			_entry(slime, again, Train.STALLED)] as Array[Dictionary], "each case is logged")
	_at_start(sim, slime)


func test_a_slime_out_of_the_level_bounds_is_moved_and_logged() -> void:
	var run := _wedged(5, 2)
	var sim: Simulation = run[0]
	var slime: int = run[1]
	sim.run(10)
	assert_true(sim.train.bounds.has_area())
	sim.slimes.translate(slime, Vector2(-2000, 2000) - sim.slimes.centre_of(slime))
	var tick := sim.tick
	sim.run(1)
	assert_eq(sim.train.stalled, [_entry(slime, tick, Train.OUT_OF_BOUNDS)] as Array[Dictionary])
	_at_start(sim, slime)


func test_a_slime_asleep_at_bedtime_is_never_counted_nor_moved() -> void:
	var run := _wedged()
	var sim: Simulation = run[0]
	var slime: int = run[1]
	sim.run(STALL_TICKS / 2)
	sim.slimes.set_state(slime, SlimeBodies.BEDTIME_ASLEEP)
	var asleep_at := sim.slimes.centre_of(slime)
	sim.run(2 * STALL_TICKS)
	assert_eq(sim.train.stalled, [] as Array[Dictionary], "asleep: never stalled")
	assert_false(sim.train.tracks(slime))
	assert_almost_eq(sim.slimes.centre_of(slime), asleep_at, Vector2(1, 1), "nor moved")
	# Sunrise: a train slime again, its count starts from its waking.
	sim.slimes.set_state(slime, SlimeBodies.TRAIN)
	var woke := sim.tick
	sim.run(STALL_TICKS)
	assert_eq(sim.train.stalled, [] as Array[Dictionary], "a fresh count")
	sim.run(1)
	assert_eq(sim.train.stalled, [_entry(slime, woke + STALL_TICKS, Train.STALLED)] as Array[Dictionary])


func test_a_save_during_the_count_reloads_the_same_and_carries_on_the_same() -> void:
	var run := _wedged(9)
	var sim: Simulation = run[0]
	var slime: int = run[1]
	sim.run(STALL_TICKS + 1)
	sim.run(STALL_TICKS / 2)
	var text := SaveData.to_text(sim.to_save())
	var copy := Simulation.from_save(JSON.parse_string(text), _level(), _terrain())
	assert_not_null(copy)
	copy.slimes.auto_hops = false
	assert_eq(copy.train.stalled, sim.train.stalled, "the log is saved")
	assert_eq(copy.state_hash(), sim.state_hash(), "the reloaded state")
	sim.run(STALL_TICKS)
	copy.run(STALL_TICKS)
	assert_eq(sim.train.stalled.size(), 2)
	assert_eq(copy.state_hash(), sim.state_hash(), "and it carries on the same")
	assert_eq(copy.train.stalled, sim.train.stalled)
	assert_almost_eq(copy.slimes.centre_of(slime), sim.slimes.centre_of(slime), Vector2(0.001, 0.001))


func test_same_seed_same_hash() -> void:
	var hashes := []
	for master_seed in [3, 3, 4]:
		var run := _wedged(master_seed)
		var sim: Simulation = run[0]
		sim.slimes.auto_hops = true
		sim.spawn_train_slime(1, 2, 3200.0)
		sim.slimes.translate(run[1], Vector2(0, 3000))
		sim.run(STALL_TICKS + 60)
		assert_eq(sim.train.stalled.size(), 1)
		hashes.append(sim.state_hash())
	assert_eq(hashes[0], hashes[1])
	assert_ne(hashes[0], hashes[2])


func test_the_log_keeps_the_last_cases() -> void:
	var run := _wedged()
	var sim: Simulation = run[0]
	var slime: int = run[1]
	for k in Train.STALL_LOG_SIZE + 3:
		sim.slimes.translate(slime, Vector2(0, 3000))
		sim.run(1)
	assert_eq(sim.train.stalled.size(), Train.STALL_LOG_SIZE)
	assert_eq(sim.train.stalled.back()["tick"], sim.tick - 1, "the latest kept")
