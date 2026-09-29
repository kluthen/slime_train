extends GutTest
## StuckSlimes (src/sim/stuck_slimes.gd), the stuck safety net (D100, build
## plan item 23.3): every CHECK_TICKS the simulated slimes are checked in
## pairs; two that can't fuse whose centres are closer than a quarter of the
## smaller one's radius on CHECKS checks in a row are stuck: the smaller one
## (a train or free slime; on a tie the higher id) goes to the start of the
## loop, back on the train (LoopStart), and the case is logged as "stuck".
## A pair that can fuse is left to fuse, a pair touching normally is never
## counted, a pair neither of which may move is only logged; parked slimes
## aren't checked. The log and the counts are in the dump and in saves.
##
## Two rings put on one centre never come apart (O91, the reason for the net):
## the tests make stuck pairs that way.
##
## The world: a floor whose top is at y = 0 from x = -6000 to 6000. The loop
## runs along it at a base slime's centre height (y = -24) from x = -5000 to
## 5000 and returns under the floor (y = 400). Loop distance d is x = d - 5000
## on the outgoing part.
# @test-link [[rule_stuck_slimes_moved_to_start]]
# @test-link [[req_slime_states]]

const OVERLAP := Vector2(0, -40)
const START := Vector2(-5000, -24)
## The checks run on ticks 0, 30, 60, 90: the fourth one moves the slime.
const STUCK_TICK := StuckSlimes.CHECK_TICKS * (StuckSlimes.CHECKS - 1)


func _level() -> LevelData:
	var data := LevelData.new("stuck", 1)
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


## A simulation on the synthetic level, every slime simulated (the first slime
## is removed: tests place their own), the view on `look`.
func _sim(master_seed := 5, look := Vector2(0, -200)) -> Simulation:
	var sim := Simulation.new(master_seed)
	sim.slimes.terrain = _terrain()
	sim.load_level(_level())
	for slime_id in sim.slimes.ids():
		sim.slimes.remove(slime_id)
	sim.view.set_to(look, 1.0, ScreenView.DEFAULT_SIZE)
	return sim


## A slime of `species` and `size` in `state` at `at`; a train slime is
## followed from where the loop passes.
func _slime(sim: Simulation, species: int, size: int, state := SlimeBodies.TRAIN, at := OVERLAP) -> int:
	var slime_id := sim.slimes.create(species, size, at, state)
	if state == SlimeBodies.TRAIN:
		sim.train.track(slime_id, at.x + 5000.0)
	return slime_id


## Where a slime of `size` moved to the start of the loop has its centre.
func _start_of(size: int) -> Vector2:
	return START + Vector2(0, -Offscreen.lift(size))


func _entry(slime_id: int, other: int, tick: int, moved := true) -> Dictionary:
	return {"id": slime_id, "other": other, "tick": tick, "reason": StuckSlimes.STUCK, "moved": moved}


# --- Stuck pairs ------------------------------------------------------------------

func test_two_species_on_one_centre_the_smaller_goes_to_the_start_after_about_2_s() -> void:
	var sim := _sim()
	var big := _slime(sim, 0, 2)
	var small := _slime(sim, 1, 1)
	sim.run(STUCK_TICK)
	assert_eq(sim.stuck_slimes.stuck, [] as Array[Dictionary], "three checks: not yet")
	assert_lt(sim.slimes.centre_of(small).distance_to(sim.slimes.centre_of(big)), 3.0, "still on one centre")
	sim.run(1)
	assert_eq(sim.stuck_slimes.stuck, [_entry(small, big, STUCK_TICK)] as Array[Dictionary], "logged as stuck")
	assert_eq(sim.slimes.state_of(small), SlimeBodies.TRAIN, "back on the train")
	assert_almost_eq(sim.train.distance_of(small), 0.0, 0.001, "at the start of the loop")
	assert_almost_eq(sim.slimes.centre_of(small), _start_of(1), Vector2(0.5, 0.5))
	assert_almost_eq(sim.slimes.centre_of(big).x, 0.0, 30.0, "the bigger one stays")
	assert_eq(sim.offscreen.lost, [] as Array[Dictionary], "stuck is not lost")
	sim.run(120)
	assert_eq(sim.stuck_slimes.stuck.size(), 1, "moved once")
	assert_eq(sim.slimes.state_of(small), SlimeBodies.TRAIN, "it rides on")


func test_on_a_tie_the_higher_id_moves() -> void:
	var sim := _sim()
	var low := _slime(sim, 0, 1)
	var high := _slime(sim, 1, 1)
	sim.run(STUCK_TICK + 1)
	assert_eq(sim.stuck_slimes.stuck, [_entry(high, low, STUCK_TICK)] as Array[Dictionary])
	assert_almost_eq(sim.slimes.centre_of(high), _start_of(1), Vector2(0.5, 0.5))


func test_a_free_slime_is_moved_back_on_the_train() -> void:
	var sim := _sim()
	var train_slime := _slime(sim, 0, 3)
	var free := _slime(sim, 1, 1, SlimeBodies.FREE)
	sim.run(STUCK_TICK + 1)
	assert_eq(sim.stuck_slimes.stuck, [_entry(free, train_slime, STUCK_TICK)] as Array[Dictionary])
	assert_eq(sim.slimes.state_of(free), SlimeBodies.TRAIN)
	assert_true(sim.train.tracks(free))
	assert_almost_eq(sim.train.distance_of(free), 0.0, 0.001)


func test_a_same_species_pair_too_big_to_fuse_is_stuck() -> void:
	var sim := _sim()
	var a := _slime(sim, 2, 2)
	var b := _slime(sim, 2, 2)
	assert_false(sim.slimes.can_merge(a, b), "sizes add up to 4")
	sim.run(STUCK_TICK + 1)
	assert_eq(sim.stuck_slimes.stuck, [_entry(b, a, STUCK_TICK)] as Array[Dictionary])


func test_a_same_species_pair_that_can_fuse_is_left_to_fuse() -> void:
	var sim := _sim()
	var a := _slime(sim, 0, 1)
	var b := _slime(sim, 0, 2)
	sim.run(Fusion.CONTACT_TICKS + 30)
	assert_eq(sim.stuck_slimes.stuck, [] as Array[Dictionary], "never counted")
	assert_false(sim.slimes.has(b), "they fused")
	assert_eq(sim.slimes.size_of(a), 3)


func test_a_pair_touching_normally_is_never_moved() -> void:
	var sim := _sim()
	var width := 2.0 * (SlimeBodies.ring_radius_for(1) + SlimeBodies.EDGE)
	var a := _slime(sim, 0, 1, SlimeBodies.TRAIN, OVERLAP)
	var b := _slime(sim, 1, 1, SlimeBodies.TRAIN, OVERLAP + Vector2(width - 2.0, 0))
	var c := _slime(sim, 2, 2, SlimeBodies.TRAIN, OVERLAP + Vector2(2.0 * width, 0))
	sim.run(600)
	assert_eq(sim.stuck_slimes.stuck, [] as Array[Dictionary])
	for slime_id in [a, b, c]:
		assert_gt(sim.train.distance_of(slime_id), 4000.0, "slime %d rode on from where it was" % slime_id)


func test_only_a_train_or_free_slime_moves_even_when_bigger() -> void:
	var sim := _sim()
	var asleep := _slime(sim, 0, 1, SlimeBodies.BEDTIME_ASLEEP)
	var train_slime := _slime(sim, 1, 2)
	sim.run(STUCK_TICK + 1)
	assert_eq(sim.stuck_slimes.stuck, [_entry(train_slime, asleep, STUCK_TICK)] as Array[Dictionary])
	assert_eq(sim.slimes.state_of(asleep), SlimeBodies.BEDTIME_ASLEEP, "the asleep one is never moved")
	assert_almost_eq(sim.slimes.centre_of(train_slime), _start_of(2), Vector2(0.5, 0.5))


func test_a_pair_neither_of_which_may_move_is_only_logged_once() -> void:
	var sim := _sim()
	var a := _slime(sim, 0, 1, SlimeBodies.BEDTIME_ASLEEP)
	var b := _slime(sim, 1, 1, SlimeBodies.IN_BASKET)
	var before := [sim.slimes.centre_of(a), sim.slimes.centre_of(b)]
	sim.run(STUCK_TICK + 1)
	assert_eq(sim.stuck_slimes.stuck, [_entry(b, a, STUCK_TICK, false)] as Array[Dictionary], "logged, not moved")
	sim.run(10 * StuckSlimes.CHECK_TICKS)
	assert_eq(sim.stuck_slimes.stuck.size(), 1, "once while they stay so")
	assert_eq(sim.slimes.state_of(a), SlimeBodies.BEDTIME_ASLEEP)
	assert_eq(sim.slimes.state_of(b), SlimeBodies.IN_BASKET)
	assert_almost_eq(sim.slimes.centre_of(a), before[0], Vector2(30, 30), "neither went to the start")
	assert_almost_eq(sim.slimes.centre_of(b), before[1], Vector2(30, 30))


func test_parked_slimes_are_not_checked() -> void:
	# Far from the view and from any route back: parked, and they stay put.
	var sim := _sim(5, Vector2(3000, -200))
	sim.offscreen.enabled = true
	var at := Vector2(-2000, -1000)
	var a := _slime(sim, 0, 1, SlimeBodies.FREE, at)
	var b := _slime(sim, 1, 1, SlimeBodies.FREE, at)
	sim.run(2 * StuckSlimes.CHECKS * StuckSlimes.CHECK_TICKS)
	assert_true(sim.slimes.is_parked(a) and sim.slimes.is_parked(b))
	assert_eq(sim.stuck_slimes.stuck, [] as Array[Dictionary])
	assert_eq(sim.stuck_slimes.dump()["counts"], [])


func test_a_moved_slime_does_not_land_on_one_already_at_the_start() -> void:
	var sim := _sim()
	var waiting := sim.slimes.create(3, 1, _start_of(1), SlimeBodies.SLEEPER)
	var big := _slime(sim, 0, 2)
	var small := _slime(sim, 1, 1)
	sim.run(STUCK_TICK + 1)
	assert_eq(sim.stuck_slimes.stuck, [_entry(small, big, STUCK_TICK)] as Array[Dictionary])
	var room := 2.0 * (SlimeBodies.ring_radius_for(1) + SlimeBodies.EDGE)
	assert_gte(sim.slimes.centre_of(small).distance_to(sim.slimes.centre_of(waiting)), room - 0.5,
			"the next free spot along the loop")
	assert_lt(sim.train.distance_of(small), LoopStart.SPOTS * room, "still at the start")


# --- Dump, saves, determinism -----------------------------------------------------

func test_the_counts_and_the_log_are_in_the_dump() -> void:
	var sim := _sim()
	var big := _slime(sim, 0, 2)
	var small := _slime(sim, 1, 1)
	sim.run(StuckSlimes.CHECK_TICKS + 1)
	assert_eq(sim.dump()["stuck_slimes"]["counts"], [[big, small, 2]], "two checks so far")
	sim.run(StuckSlimes.CHECK_TICKS * 2)
	assert_eq(sim.dump()["stuck_slimes"]["stuck"], [_entry(small, big, STUCK_TICK)])
	assert_eq(sim.dump()["stuck_slimes"]["counts"], [], "the count goes with the move")


func test_a_save_during_the_count_reloads_the_same_and_carries_on_the_same() -> void:
	var sim := _sim()
	_slime(sim, 0, 2)
	var small := _slime(sim, 1, 1)
	_slime(sim, 2, 1, SlimeBodies.BEDTIME_ASLEEP, Vector2(1000, -40))
	_slime(sim, 3, 1, SlimeBodies.BEDTIME_ASLEEP, Vector2(1000, -40))
	sim.run(STUCK_TICK - 10)
	var text := SaveData.to_text(sim.to_save())
	var copy := Simulation.from_save(JSON.parse_string(text), _level(), _terrain())
	assert_not_null(copy)
	assert_eq(copy.stuck_slimes.dump(), sim.stuck_slimes.dump())
	assert_eq(copy.state_hash(), sim.state_hash(), "the reloaded state")
	sim.run(300)
	copy.run(300)
	assert_eq(sim.stuck_slimes.stuck.size(), 2, "the move and the logged pair")
	assert_eq(copy.stuck_slimes.dump(), sim.stuck_slimes.dump())
	assert_eq(copy.state_hash(), sim.state_hash(), "and it carries on the same")
	assert_almost_eq(copy.train.distance_of(small), sim.train.distance_of(small), 0.001)


func test_same_seed_same_hash() -> void:
	var runs := []
	for master_seed in [11, 11, 12]:
		var sim := _sim(master_seed)
		_slime(sim, 0, 2)
		_slime(sim, 1, 1)
		_slime(sim, 2, 1, SlimeBodies.FREE, Vector2(600, -40))
		_slime(sim, 3, 2, SlimeBodies.FREE, Vector2(600, -40))
		sim.run(400)
		assert_eq(sim.stuck_slimes.stuck.size(), 2)
		runs.append(sim.state_hash())
	assert_eq(runs[0], runs[1])
	assert_ne(runs[0], runs[2])
