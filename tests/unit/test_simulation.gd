extends GutTest
## Simulation: the fixed-step core. It advances one tick at a time, consumes
## queued input at the next step, and dumps its state for comparisons.


func test_starts_at_tick_zero_with_its_seed() -> void:
	var sim := Simulation.new(77)
	assert_eq(sim.tick, 0)
	assert_eq(sim.rng.seed_value, 77)
	assert_eq(sim.slimes, [])


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
