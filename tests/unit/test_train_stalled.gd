extends GutTest
## The stalled safety net (D118, D121, build plan item 23.13): a train slime
## whose progress hasn't advanced Train.STALL_ADVANCE px in
## Train.STALL_SECONDS, or whose centre is out of the level's bounds, is
## stalled: Train.follow() moves it to the start of the loop, back on the
## train (LoopStart, the move lost and stuck slimes take too), and logs it in
## `train.stalled` with the reason "stalled" or "out_of_bounds", every time;
## the 60 s count starts again from the move. A slime asleep at bedtime is
## never counted nor moved. The log is in the dump and in saves. The 60 s
## count only runs while the slime is simulated: parked, its clock pauses
## and resumes where it was (D150 (1), O113's default: every parked train
## slime); progress while parked still marks; out of bounds is unchanged.
##
## The world: a floor whose top is at y = 0 from x = -6000 to 6000. The loop
## runs along it at a base slime's centre height (y = -24) from x = -5000 to
## 5000 and returns under the floor (y = 400). Loop distance d is x = d - 5000
## on the outgoing part. The wedge: no slime hops (SlimeBodies.auto_hops off),
## so a train slime's progress can't advance.
# @test-link [[rule_stalled_train_slime_moved_to_start]]
# @test-link [[req_loop_and_world]]
# @test-link [[req_offscreen_simulation]]
# @test-link [[req_persistence_and_saves]]

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


# --- The stall clock pauses while parked (D150 (1), O113's default) ---------

## A Train on the synthetic level's loop and bodies holding one size-1 train
## slime `distance` px along it, followed from there. Nothing ticks the
## bodies: the slime never moves unless a test moves it. Returns
## [train, bodies, slime id].
func _bare(distance := 3000.0) -> Array:
	var train := Train.new(_level().loop)
	var bodies := SlimeBodies.new(Rng.new(7))
	var slime := bodies.create(0, 1, train.position_at(distance), SlimeBodies.TRAIN)
	train.track(slime, distance)
	return [train, bodies, slime]


## Follows ticks `from` to `to` (excluded), as Simulation.step would.
func _follow(train: Train, bodies: SlimeBodies, from: int, to: int) -> void:
	for tick in range(from, to):
		train.follow(bodies, tick)


func test_a_parked_slime_that_never_advances_is_not_stalled() -> void:
	var run := _bare()
	var train: Train = run[0]
	var bodies: SlimeBodies = run[1]
	var slime: int = run[2]
	_follow(train, bodies, 0, 1000)
	assert_eq(train.marked_at_of(slime), 0, "marked at its first follow")
	bodies.park(slime)
	# Parked for 9000 ticks (2.5 min) without moving: the clock doesn't run.
	_follow(train, bodies, 1000, 10000)
	assert_eq(train.stalled, [] as Array[Dictionary], "parked: never stalled")
	assert_eq(9999 - train.marked_at_of(slime), 999, "the time since its mark kept as it was")


func test_simulated_again_it_resumes_and_stalls_after_60_s_of_simulated_ticks() -> void:
	var run := _bare()
	var train: Train = run[0]
	var bodies: SlimeBodies = run[1]
	var slime: int = run[2]
	# 999 simulated ticks since the mark (ticks 1 to 999), then parked.
	_follow(train, bodies, 0, 1000)
	bodies.park(slime)
	_follow(train, bodies, 1000, 10000)
	bodies.unpark(slime)
	# It resumes from 999, not from zero: tick 10000 is its 1000th simulated
	# tick since the mark, so tick 12600 is its 3600th.
	var due := 10000 + STALL_TICKS - 1000
	_follow(train, bodies, 10000, due)
	assert_eq(train.stalled, [] as Array[Dictionary], "not yet")
	_follow(train, bodies, due, due + 1)
	assert_eq(train.stalled, [_entry(slime, due, Train.STALLED)] as Array[Dictionary])


func test_parked_from_its_first_follow_its_clock_never_starts() -> void:
	var run := _bare()
	var train: Train = run[0]
	var bodies: SlimeBodies = run[1]
	var slime: int = run[2]
	bodies.park(slime)
	assert_eq(train.marked_at_of(slime), -1, "a fresh record")
	_follow(train, bodies, 0, 1)
	assert_eq(train.marked_at_of(slime), 0, "marked at its first follow, not moved on")
	_follow(train, bodies, 1, 2 * STALL_TICKS)
	assert_eq(train.marked_at_of(slime), 2 * STALL_TICKS - 1, "no time since its mark")
	assert_eq(train.stalled, [] as Array[Dictionary])


func test_progress_while_parked_still_marks() -> void:
	var run := _bare()
	var train: Train = run[0]
	var bodies: SlimeBodies = run[1]
	var slime: int = run[2]
	_follow(train, bodies, 0, 500)
	bodies.park(slime)
	_follow(train, bodies, 500, 700)
	bodies.translate(slime, Vector2(Train.STALL_ADVANCE + 1.0, 0))
	_follow(train, bodies, 700, 701)
	assert_eq(train.marked_at_of(slime), 700, "an advance marks as today")


func test_a_parked_slime_out_of_bounds_is_moved_at_once() -> void:
	var run := _bare()
	var train: Train = run[0]
	var bodies: SlimeBodies = run[1]
	var slime: int = run[2]
	train.bounds = Rect2(-6000, -3000, 12000, 3500)
	_follow(train, bodies, 0, 10)
	bodies.park(slime)
	_follow(train, bodies, 10, 20)
	bodies.translate(slime, Vector2(0, 5000))
	_follow(train, bodies, 20, 21)
	assert_eq(train.stalled, [_entry(slime, 20, Train.OUT_OF_BOUNDS)] as Array[Dictionary])
	assert_almost_eq(train.distance_of(slime), 0.0, 0.001, "at the start of the loop")


## A simulation with off-screen simulation on and a wedged, simulated front
## train slime 3000 px along the loop (x = -2000), 370 px left of the view
## (between the margins: it stays simulated), and a parked train slime of
## the same size just behind it (beyond the park margin), waiting in the
## single-file line. Returns [sim, front, behind].
func _parked_line(master_seed := 5) -> Array:
	var sim := Simulation.new(master_seed)
	sim.slimes.terrain = _terrain()
	sim.load_level(_level())
	for slime_id in sim.slimes.ids():
		sim.slimes.remove(slime_id)
	sim.offscreen.enabled = true
	sim.slimes.auto_hops = false
	var left := -2000.0 + 370.0
	sim.view.set_to(Vector2(left + ScreenView.DEFAULT_SIZE.x * 0.5, -200), 1.0, ScreenView.DEFAULT_SIZE)
	var front := sim.spawn_train_slime(0, 1, 3000.0)
	var widths := 2.0 * (SlimeBodies.ring_radius_for(1) + SlimeBodies.EDGE)
	var behind := sim.spawn_train_slime(1, 1, 3000.0 - widths - 5.0)
	return [sim, front, behind]


func test_a_parked_line_behind_a_wedged_front_waits_without_its_clock_running() -> void:
	var run := _parked_line()
	var sim: Simulation = run[0]
	var front: int = run[1]
	var behind: int = run[2]
	sim.run(STALL_TICKS)
	assert_false(sim.slimes.is_parked(front), "the front is simulated")
	assert_true(sim.slimes.is_parked(behind), "the one behind is parked")
	assert_eq(sim.train.stalled, [] as Array[Dictionary], "not yet")
	assert_lt(sim.train.distance_of(behind), sim.train.distance_of(front), "waiting behind it")
	assert_eq(sim.tick - 1 - sim.train.marked_at_of(behind), 0, "no time on its clock")
	# The simulated front's clock ran: it is stalled at 60 s, the parked one not.
	sim.run(1)
	assert_eq(sim.train.stalled, [_entry(front, STALL_TICKS, Train.STALLED)] as Array[Dictionary])
	sim.run(120)
	assert_eq(sim.train.stalled.size(), 1, "the parked one is never stalled")
	assert_gt(sim.train.distance_of(behind), 3000.0, "the line moves on once its front has gone")


func test_a_save_during_a_parked_stretch_reloads_the_same_and_carries_on_the_same() -> void:
	var run := _parked_line(9)
	var sim: Simulation = run[0]
	var behind: int = run[2]
	sim.run(STALL_TICKS / 2)
	assert_true(sim.slimes.is_parked(behind))
	var text := SaveData.to_text(sim.to_save())
	var copy := Simulation.from_save(JSON.parse_string(text), _level(), _terrain())
	assert_not_null(copy)
	copy.offscreen.enabled = true
	copy.slimes.auto_hops = false
	assert_eq(copy.state_hash(), sim.state_hash(), "the reloaded state")
	assert_eq(copy.train.marked_at_of(behind), sim.train.marked_at_of(behind))
	sim.run(STALL_TICKS)
	copy.run(STALL_TICKS)
	assert_eq(sim.train.stalled.size(), 1, "the front only")
	assert_eq(copy.train.stalled, sim.train.stalled)
	assert_eq(copy.state_hash(), sim.state_hash(), "and it carries on the same")


func test_the_log_keeps_the_last_cases() -> void:
	var run := _wedged()
	var sim: Simulation = run[0]
	var slime: int = run[1]
	for k in Train.STALL_LOG_SIZE + 3:
		sim.slimes.translate(slime, Vector2(0, 3000))
		sim.run(1)
	assert_eq(sim.train.stalled.size(), Train.STALL_LOG_SIZE)
	assert_eq(sim.train.stalled.back()["tick"], sim.tick - 1, "the latest kept")
