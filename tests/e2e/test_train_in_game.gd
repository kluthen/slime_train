extends GutTest
## End-to-end on the test level: the game wakes the first slime at the start
## by itself; slimes of every size travel the loop; the split zone at the
## start splits every slime entering it into base slimes, which stay on the
## train; nothing else splits.

# @test-link [[req_slime_states]]
# @test-link [[rule_all_sizes_travel_loop_v1]]
# @test-link [[rule_split_zone_only_splitter]]
# @test-link [[rule_start_carries_split_zone]]
# @test-link [[req_loop_and_world]]

const MAIN_SCENE := "res://src/main.tscn"
const SEED := 77


func _boot() -> Node:
	var game: Node = load(MAIN_SCENE).instantiate()
	add_child_autofree(game)
	assert_eq(game.enable_test_mode({"seed": SEED, "time_scale": 0}), PackedStringArray())
	return game


## The distance along the loop where it leaves the start's split zone.
func _past_split_zone(game: Node) -> float:
	var train: Train = game.simulation.train
	var zones: Dictionary = game.level.data.split_zones
	var distance := 0.0
	while distance < train.length():
		var inside := false
		for zone in zones.values():
			if zone.has_point(train.position_at(distance)):
				inside = true
		if not inside:
			return distance
		distance += 4.0
	return 0.0


func _clear(game: Node) -> void:
	var slimes: SlimeBodies = game.simulation.slimes
	for slime in slimes.ids():
		slimes.remove(slime)


## The awake slimes: every slime but the level's sleepers.
func _awake(slimes: SlimeBodies) -> Array[int]:
	var awake: Array[int] = []
	for slime_id in slimes.ids():
		if slimes.state_of(slime_id) != SlimeBodies.SLEEPER:
			awake.append(slime_id)
	return awake


func test_the_game_wakes_the_first_slime() -> void:
	var game := _boot()
	var sim: Simulation = game.simulation
	var slimes: SlimeBodies = sim.slimes
	var awake := _awake(slimes)
	assert_eq(awake.size(), 1, "one awake slime, with no call (the rest are sleepers)")
	var slime := awake[0]
	assert_eq(slimes.species_of(slime), Species.from_letter("A"))
	assert_eq(slimes.size_of(slime), 1)
	assert_eq(slimes.state_of(slime), SlimeBodies.TRAIN)
	assert_lt(slimes.centre_of(slime).distance_to(game.level.start_position()), 1.0,
			"at the first slime's marker")
	assert_true(sim.train.tracks(slime))
	var start: float = sim.train.progress_of(slime)
	game.test_mode.run_ticks(10 * Simulation.TICK_RATE)
	assert_gt(sim.train.progress_of(slime), start + 100.0, "it hops forward along the loop")
	assert_eq(sim.train.lost, [])


func test_a_restored_simulation_does_not_wake_a_second_slime() -> void:
	var game := _boot()
	var sim: Simulation = game.simulation
	game.test_mode.run_ticks(5)
	var count := sim.slimes.slime_count
	sim.load_level(game.level.data)
	assert_eq(sim.slimes.slime_count, count,
			"only a fresh state wakes the first slime and places the sleepers")


## One size per game: several slimes at once would test the crowd at the
## start basin, which is chunk 9's (sleepers joining the train).
func test_slimes_of_every_size_travel_the_loop() -> void:
	for size in [1, 2, 3]:
		var game := _boot()
		_clear(game)
		var sim: Simulation = game.simulation
		var start := _past_split_zone(game) + 60.0
		var slime := sim.spawn_train_slime(Species.from_letter("B"), size, start)
		var from: float = sim.train.progress_of(slime)
		var split_at := -1.0
		var limit := 8 * 60 * Simulation.TICK_RATE
		while sim.tick < limit and sim.train.progress_of(slime) < from + sim.train.length():
			game.test_mode.run_ticks(30)
			if not sim.train.lost.is_empty():
				break
			if split_at < 0.0 and sim.slimes.size_of(slime) != size:
				split_at = sim.train.progress_of(slime) - from
		gut.p("size %d: lap at tick %d, split %.0f px in" % [size, sim.tick, split_at])
		assert_eq(sim.train.lost, [], "no slime lost (size %d)" % size)
		assert_gte(sim.train.progress_of(slime), from + sim.train.length(),
				"the size-%d slime completed a lap" % size)
		if size > 1:
			# It stays whole until the split zone at the start of the loop,
			# which it reaches after the whole loop but the part it started on.
			assert_gt(split_at, sim.train.length() - start - 600.0,
					"the size-%d slime split only in the split zone" % size)
		for part in sim.slimes.ids():
			assert_eq(sim.slimes.size_of(part), 1, "the size-%d slime came back as base slimes" % size)
		game.queue_free()


func test_slimes_entering_the_split_zone_leave_as_base_slimes_on_the_train() -> void:
	var game := _boot()
	_clear(game)
	var sim: Simulation = game.simulation
	var slide_end := sim.train.length()
	var big := sim.spawn_train_slime(Species.from_letter("C"), 3, slide_end - 500.0)
	var medium := sim.spawn_train_slime(Species.from_letter("D"), 2, slide_end - 350.0)
	assert_eq(sim.slimes.slime_count, 2)
	game.test_mode.run_ticks(6 * Simulation.TICK_RATE)
	assert_eq(sim.slimes.slime_count, 5, "3 + 2 base slimes")
	for slime in sim.slimes.ids():
		assert_eq(sim.slimes.size_of(slime), 1)
		assert_eq(sim.slimes.state_of(slime), SlimeBodies.TRAIN)
		assert_true(sim.train.tracks(slime), "part %d is on the train" % slime)
	var species_count := {}
	for slime in sim.slimes.ids():
		var kind := sim.slimes.species_of(slime)
		species_count[kind] = species_count.get(kind, 0) + 1
	assert_eq(species_count, {Species.from_letter("C"): 3, Species.from_letter("D"): 2})
	assert_true(sim.slimes.has(big) and sim.slimes.has(medium), "the originals are the first parts")
	# The parts carry on along the loop, out of the zone and on.
	var past := _past_split_zone(game)
	game.test_mode.run_ticks(40 * Simulation.TICK_RATE)
	for slime in sim.slimes.ids():
		var progress: float = sim.train.progress_of(slime)
		assert_gt(fposmod(progress, sim.train.length()), past, "part %d left the zone forward" % slime)
	assert_eq(sim.train.lost, [])
