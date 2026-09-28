extends GutTest
## Simulation: the fixed-step core. It advances one tick at a time, consumes
## queued input at the next step, and dumps its state for comparisons.


func test_starts_at_tick_zero_with_its_seed() -> void:
	var sim := Simulation.new(77)
	assert_eq(sim.tick, 0)
	assert_eq(sim.rng.seed_value, 77)
	assert_eq(sim.slimes.slime_count, 0, "no slimes yet")


func test_step_advances_one_tick() -> void:
	var sim := Simulation.new(1)
	sim.step()
	assert_eq(sim.tick, 1)
	sim.run(9)
	assert_eq(sim.tick, 10)


func test_input_is_consumed_at_the_next_step() -> void:
	var sim := Simulation.new(1)
	sim.run(5)
	sim.push_input(Simulation.touch_down(0, Vector2(10, 20)))
	assert_eq(sim.fingers_down, {}, "queued input waits for the next step")
	sim.step()
	assert_eq(sim.fingers_down, {0: Vector2(10, 20)})
	assert_eq(sim.input_log.back()["tick"], 5, "stamped with the tick that consumed it")
	sim.push_input(Simulation.touch_up(0, Vector2(12, 20)))
	sim.step()
	assert_eq(sim.fingers_down, {})


func test_second_finger_is_recorded() -> void:
	# The rule "the first touch wins" comes with chunk 7; the core already
	# carries every finger so that tests can exercise it.
	var sim := Simulation.new(1)
	sim.push_input(Simulation.touch_down(0, Vector2(1, 1)))
	sim.push_input(Simulation.touch_down(1, Vector2(2, 2)))
	sim.step()
	assert_eq(sim.fingers_down.size(), 2)


func test_tilt_is_recorded() -> void:
	var sim := Simulation.new(1)
	sim.push_input(Simulation.tilt(12.5))
	sim.step()
	assert_eq(sim.tilt_degrees, 12.5)


func test_input_log_is_bounded() -> void:
	var sim := Simulation.new(1)
	for i in Simulation.INPUT_LOG_SIZE + 10:
		sim.push_input(Simulation.tilt(float(i)))
		sim.step()
	assert_eq(sim.input_log.size(), Simulation.INPUT_LOG_SIZE)
	assert_eq(sim.input_log.back()["degrees"], float(Simulation.INPUT_LOG_SIZE + 9))


func test_unknown_input_is_refused() -> void:
	var sim := Simulation.new(1)
	sim.push_input({"kind": "wiggle"})
	assert_push_error("unknown input kind")
	sim.step()
	assert_eq(sim.input_log, [])


func test_dump_holds_the_state() -> void:
	var sim := Simulation.new(9)
	sim.run(3)
	var dump := sim.dump()
	assert_eq(dump["tick"], 3)
	assert_eq(dump["seed"], "9")
	assert_eq(dump["rng_state"], str(sim.rng.state))
	assert_eq(dump["slimes"], [])
	assert_has(dump, "input")


func test_same_seed_and_input_give_same_hash() -> void:
	var a := Simulation.new(5)
	var b := Simulation.new(5)
	for sim in [a, b]:
		sim.run(10)
		sim.push_input(Simulation.touch_down(0, Vector2(3, 4)))
		sim.run(10)
	assert_eq(a.state_hash(), b.state_hash())
	assert_eq(a.state_hash(), StateHash.of(a.dump()))


func test_seed_input_and_time_change_the_hash() -> void:
	var base := Simulation.new(5)
	base.run(10)
	var other_seed := Simulation.new(6)
	other_seed.run(10)
	var other_time := Simulation.new(5)
	other_time.run(11)
	var other_input := Simulation.new(5)
	other_input.push_input(Simulation.tilt(3.0))
	other_input.run(10)
	assert_ne(base.state_hash(), other_seed.state_hash())
	assert_ne(base.state_hash(), other_time.state_hash())
	assert_ne(base.state_hash(), other_input.state_hash())


func test_the_slimes_move_with_the_simulation() -> void:
	var sim := Simulation.new(3)
	var slime := sim.slimes.create(0, 1, Vector2.ZERO)
	sim.run(30)
	assert_gt(sim.slimes.centre_of(slime).y, 50.0, "the slime fell for half a second")


func test_the_slimes_are_in_the_dump_and_the_hash() -> void:
	var sim := Simulation.new(3)
	sim.slimes.create(2, 3, Vector2(10, 20), SlimeBodies.SLEEPER)
	var dump := sim.dump()
	assert_eq(dump["slimes"].size(), 1)
	assert_eq(dump["slimes"][0]["species"], 2)
	assert_eq(dump["slimes"][0]["size"], 3)
	assert_eq(dump["slimes"][0]["state"], "sleeper")
	assert_has(dump, "next_slime_id")
	var before := sim.state_hash()
	sim.step()
	assert_ne(sim.state_hash(), before, "a falling slime changes the hash")


func test_same_seed_and_slimes_give_the_same_hash() -> void:
	var hashes := []
	for i in 2:
		var sim := Simulation.new(8)
		sim.slimes.terrain = TerrainSegments.new([PackedVector2Array([
				Vector2(-1000, 0), Vector2(1000, 0), Vector2(1000, 100), Vector2(-1000, 100)])])
		for k in 5:
			sim.slimes.create(k, 1 + k % 3, Vector2(-400 + 200 * k, -40))
		sim.run(300)
		hashes.append(sim.state_hash())
	assert_eq(hashes[0], hashes[1])
