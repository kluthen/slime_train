extends GutTest
## The phone's tilt sensor through the real game scene (master spec §5.5,
## chunk 20), on a fake sensor (TiltFeed.sensor): in normal play a reading
## reaches the simulation's tilt before the tick and turns the free slimes'
## gravity only; test mode's runs ignore the sensor (their script is their
## only tilt); the desktop's zero reading pushes nothing; a session's start
## and a resumed session take the latest reading as neutral; and tilting
## never holds off the idle camera.

# @test-link [[req_tilt_input]]
# @test-link [[req_slime_states]]

const MAIN_SCENE := "res://src/main.tscn"
const SEED := 77
const G := 9.81
## A world point: below the parent zone, between the edge strips.
const WORLD_POINT := Vector2(576, 400)
## The tap that calls the first slime in test mode (test_tilt_e2e.gd's).
const CALL := {"tick": 20, "do": "tap", "at": [760, 420]}


## A fake sensor the test turns: reads whatever `degrees` says (the right
## edge dipped), or `gravity` when set.
class FakeSensor:
	extends RefCounted
	var degrees := 0.0
	var gravity: Variant = null

	func read() -> Vector3:
		if gravity != null:
			return gravity
		var roll := deg_to_rad(degrees)
		return Vector3(G * sin(roll), -G * cos(roll), 0.0)


## A game in normal play (no stores: it never writes) reading `sensor`.
func _game(sensor: FakeSensor) -> Node:
	var game: Node = load(MAIN_SCENE).instantiate()
	game.tilt_feed.sensor = sensor.read
	add_child_autofree(game)
	assert_null(game.test_mode, "normal play")
	return game


func _press(game: Node, at: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 0
		event.pressed = pressed
		event.position = at
		game._unhandled_input(event)


func _tilt_events(sim: Simulation) -> Array:
	return sim.input_log.filter(func(event: Dictionary) -> bool: return event["kind"] == Simulation.INPUT_TILT)


func test_normal_play_feeds_the_sensor_to_the_free_slimes_only() -> void:
	var sensor := FakeSensor.new()
	sensor.degrees = 30.0
	var game := _game(sensor)
	var sim: Simulation = game.simulation
	game.step_simulation()
	assert_almost_eq(sim.phone_tilt.degrees, 30.0, 1e-4)
	assert_false(sim.phone_tilt.flat)
	assert_gt(sim.slimes.free_down.x, 0.0, "the way down turns toward screen-right")
	var free := sim.slimes.gravity_for(SlimeBodies.FREE)
	assert_gt(free.x, 0.0, "a free slime feels it")
	assert_almost_eq(free.length(), sim.slimes.gravity.length(), 1e-3, "same strength")
	assert_eq(sim.slimes.gravity_for(SlimeBodies.TRAIN), sim.slimes.gravity, "a train slime doesn't")
	sensor.gravity = Vector3(0, 0, -G)
	game.step_simulation()
	assert_true(sim.phone_tilt.flat, "lying flat")
	assert_eq(sim.slimes.free_down, Vector2.DOWN, "flat is neutral")


func test_a_steady_phone_is_one_input() -> void:
	var sensor := FakeSensor.new()
	sensor.degrees = -25.0
	var game := _game(sensor)
	for i in 30:
		game.step_simulation()
	assert_eq(_tilt_events(game.simulation).size(), 1)


func test_the_desktop_reading_pushes_nothing() -> void:
	assert_eq(Input.get_accelerometer(), Vector3.ZERO, "no sensor on the desktop")
	var game: Node = load(MAIN_SCENE).instantiate()
	add_child_autofree(game)
	var sim: Simulation = game.simulation
	var before := sim.phone_tilt.dump()
	for i in 10:
		game.step_simulation()
	assert_eq(_tilt_events(sim), [])
	assert_eq(sim.phone_tilt.dump(), before)


func test_test_mode_ignores_the_sensor() -> void:
	var hashes := []
	for degrees in [0.0, 30.0]:
		var sensor := FakeSensor.new()
		sensor.degrees = degrees
		var game := _game(sensor)
		assert_eq(game.enable_test_mode({"seed": SEED, "time_scale": 0, "steps": [CALL]}), PackedStringArray())
		game.test_mode.run_ticks(3 * Simulation.TICK_RATE)
		assert_eq(_tilt_events(game.simulation), [], "tilted %s°: no tilt input" % degrees)
		assert_eq(game.simulation.phone_tilt.degrees, 0.0)
		hashes.append(game.simulation.state_hash())
	assert_eq(hashes[0], hashes[1], "the same run, sensor or not")


func test_a_session_start_takes_the_held_reading_as_neutral() -> void:
	var sensor := FakeSensor.new()
	sensor.degrees = 20.0
	var game := _game(sensor)
	var sim: Simulation = game.simulation
	game.step_simulation()
	assert_eq(sim.session.phase, Session.SCREENSAVER)
	_press(game, WORLD_POINT)
	game.step_simulation()
	assert_eq(sim.session.phase, Session.SESSION, "the world tap started a session")
	assert_almost_eq(sim.phone_tilt.neutral, 20.0, 1e-4)
	assert_eq(sim.phone_tilt.gravity_degrees(), 0.0, "held as at the start: plain down")


func test_a_resumed_session_takes_the_latest_reading_as_neutral() -> void:
	var sensor := FakeSensor.new()
	var game := _game(sensor)
	var sim: Simulation = game.simulation
	_press(game, WORLD_POINT)
	game.step_simulation()
	assert_eq(sim.session.phase, Session.SESSION)
	sensor.degrees = 35.0
	game.propagate_notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	game.step_simulation()
	assert_almost_eq(sim.phone_tilt.neutral, 35.0, 1e-4, "the reading pushed before the tick that takes it")


func test_tilting_never_holds_off_the_idle_camera() -> void:
	var sensor := FakeSensor.new()
	var game := _game(sensor)
	var sim: Simulation = game.simulation
	_press(game, WORLD_POINT)
	game.step_simulation()
	var quiet: int = sim.camera.quiet
	for i in 10:
		sensor.degrees = 30.0 if i % 2 == 0 else -30.0
		game.step_simulation()
	assert_eq(_tilt_events(sim).size(), 11, "every swing is an input")
	assert_eq(sim.camera.quiet, quiet + 10, "the idle clock ran on")
