extends GutTest
## Tilt (src/sim/tilt.gd) and how the slimes feel it (master spec §5.5, DoD 8):
## the dead zone of about 10° around neutral, the ±45° cap, neutral taken at
## level start (the placeholder for the session start), lying flat counting
## as neutral, the sign of the way down, and only free slimes feeling it
## (SlimeBodies: train slimes, sleepers and bedtime-asleep slimes keep plain
## gravity). Also the tilt event through the Simulation, and the state dump.

# @test-link [[req_tilt_input]]
# @test-link [[req_slime_states]]

const Support := preload("res://tests/unit/slime_test_support.gd")
const DT := 1.0 / 60.0


func _tilt(degrees: float, neutral := 0.0, flat := false) -> Tilt:
	var tilt := Tilt.new()
	tilt.set_neutral(neutral)
	tilt.read(degrees, flat)
	return tilt


func test_no_reading_is_plain_down() -> void:
	var tilt := Tilt.new()
	assert_eq(tilt.down(), Vector2.DOWN)
	assert_eq(tilt.gravity_degrees(), 0.0)


func test_inside_the_dead_zone_gravity_stays_plain_down() -> void:
	for degrees in [0.0, 5.0, -5.0, 9.0, -9.0, Tilt.DEAD_ZONE_DEGREES, -Tilt.DEAD_ZONE_DEGREES]:
		assert_eq(_tilt(degrees).down(), Vector2.DOWN, "%.1f° is inside the dead zone" % degrees)


func test_past_the_dead_zone_gravity_turns() -> void:
	var right := _tilt(11.0)
	assert_gt(right.gravity_degrees(), 0.0, "11° turns gravity")
	assert_gt(right.down().x, 0.0)
	var left := _tilt(-11.0)
	assert_lt(left.gravity_degrees(), 0.0)
	assert_lt(left.down().x, 0.0)


func test_gravity_turns_continuously_up_to_the_cap() -> void:
	# From nothing at the dead zone's edge to the cap at the cap, no jump.
	assert_almost_eq(_tilt(10.5).gravity_degrees(), 0.5 * Tilt.CAP_DEGREES / (Tilt.CAP_DEGREES - Tilt.DEAD_ZONE_DEGREES), 1e-6)
	assert_almost_eq(_tilt(45.0).gravity_degrees(), 45.0, 1e-6, "at the cap, gravity turns as much as the phone")
	var last := 0.0
	for degrees in range(0, 50):
		var turned := _tilt(float(degrees)).gravity_degrees()
		assert_true(turned >= last, "never turns back as the phone turns further (%d°)" % degrees)
		last = turned


func test_the_cap() -> void:
	assert_eq(_tilt(60.0).down(), _tilt(45.0).down(), "60° is the same as 45°")
	assert_eq(_tilt(-60.0).down(), _tilt(-45.0).down())
	assert_eq(_tilt(179.0).gravity_degrees(), Tilt.CAP_DEGREES)
	assert_almost_eq(_tilt(45.0).down().angle_to(Vector2.DOWN), deg_to_rad(45.0), 1e-6)


func test_the_way_down_is_a_unit_vector_turned_toward_the_sign() -> void:
	for degrees in [-45.0, -30.0, -11.0, 11.0, 30.0, 45.0]:
		var down := _tilt(degrees).down()
		assert_almost_eq(down.length(), 1.0, 1e-6)
		assert_gt(down.y, 0.0, "still falling down the screen at %.0f°" % degrees)
		assert_eq(signf(down.x), signf(degrees), "positive turns down toward screen-right")


func test_neutral_offsets_the_reading() -> void:
	assert_eq(_tilt(25.0, 20.0).down(), Vector2.DOWN, "neutral 20°, 25° is inside the dead zone")
	assert_eq(_tilt(12.0, 20.0).down(), Vector2.DOWN, "8° the other way too")
	assert_gt(_tilt(35.0, 20.0).down().x, 0.0, "15° past neutral turns")
	assert_lt(_tilt(5.0, 20.0).down().x, 0.0, "15° short of neutral turns the other way")
	assert_eq(_tilt(85.0, 20.0).down(), _tilt(45.0).down(), "the cap is counted from neutral")


func test_angles_wrap_around() -> void:
	assert_almost_eq(_tilt(-175.0, 170.0).relative_degrees(), 15.0, 1e-6)
	assert_almost_eq(_tilt(175.0, -170.0).relative_degrees(), -15.0, 1e-6)


func test_take_neutral_now_uses_the_current_reading() -> void:
	var tilt := Tilt.new()
	tilt.read(20.0)
	tilt.take_neutral_now()
	assert_eq(tilt.neutral, 20.0)
	assert_eq(tilt.down(), Vector2.DOWN, "held as at the start: plain down")
	tilt.read(40.0)
	assert_gt(tilt.down().x, 0.0)


func test_lying_flat_counts_as_neutral() -> void:
	assert_eq(_tilt(30.0, 0.0, true).down(), Vector2.DOWN, "flat, whatever the angle reads")
	assert_eq(_tilt(-80.0, 20.0, true).down(), Vector2.DOWN)
	var tilt := _tilt(30.0, 0.0, true)
	tilt.take_neutral_now()
	assert_eq(tilt.neutral, 0.0, "a session started flat takes the screen's down as neutral")
	tilt.read(30.0)
	assert_gt(tilt.down().x, 0.0, "picked up and tilted: gravity turns")


func test_dump_and_restore() -> void:
	var tilt := _tilt(33.0, 12.0, true)
	var copy := Tilt.new()
	copy.restore(tilt.dump())
	assert_eq(copy.dump(), tilt.dump())
	assert_eq(tilt.dump(), {"degrees": 33.0, "neutral": 12.0, "flat": true})


func test_the_tilt_event_reaches_the_bodies() -> void:
	var sim := Simulation.new(1)
	sim.push_input(Simulation.tilt(30.0))
	sim.step()
	assert_eq(sim.phone_tilt.degrees, 30.0)
	assert_eq(sim.tilt_degrees, 30.0)
	assert_eq(sim.slimes.free_down, _tilt(30.0).down())
	sim.push_input(Simulation.tilt(30.0, true))
	sim.step()
	assert_true(sim.phone_tilt.flat)
	assert_eq(sim.slimes.free_down, Vector2.DOWN, "flat: plain down")


func test_the_tilt_is_in_the_dump() -> void:
	var sim := Simulation.new(1)
	sim.push_input(Simulation.tilt(-20.0))
	sim.step()
	assert_eq(sim.dump()["input"]["tilt"], {"degrees": -20.0, "neutral": 0.0, "flat": false})
	var other := Simulation.new(1)
	other.push_input(Simulation.tilt(-20.0))
	other.step()
	other.phone_tilt.set_neutral(5.0)
	assert_ne(sim.state_hash(), other.state_hash(), "the neutral is state")


func test_loading_a_level_takes_neutral() -> void:
	# Placeholder for the session start (chunk 17).
	var sim := Simulation.new(1)
	sim.push_input(Simulation.tilt(20.0))
	sim.step()
	sim.load_level(null)
	assert_eq(sim.phone_tilt.neutral, 20.0)
	sim.step()
	assert_eq(sim.slimes.free_down, Vector2.DOWN, "held as at the start: plain down")


## Settles one slime of each state on a flat floor, far apart, then tilts
## free slimes' gravity by `degrees` for `ticks`. Returns how far each moved
## sideways, by state.
func _drift(degrees: float, ticks: int) -> Dictionary:
	var bodies := Support.bodies_on_floor()
	bodies.auto_hops = false
	var slimes := {
		SlimeBodies.FREE: bodies.create(0, 1, Vector2(-600, -30), SlimeBodies.FREE),
		SlimeBodies.TRAIN: bodies.create(0, 1, Vector2(-200, -30), SlimeBodies.TRAIN),
		SlimeBodies.SLEEPER: bodies.create(0, 1, Vector2(200, -30), SlimeBodies.SLEEPER),
		SlimeBodies.BEDTIME_ASLEEP: bodies.create(0, 1, Vector2(600, -30), SlimeBodies.BEDTIME_ASLEEP),
	}
	for i in 120:
		bodies.tick(DT)
	var before := {}
	for state in slimes:
		before[state] = bodies.centre_of(slimes[state]).x
	bodies.free_down = _tilt(degrees).down()
	for i in ticks:
		bodies.tick(DT)
	var moved := {}
	for state in slimes:
		moved[state] = bodies.centre_of(slimes[state]).x - before[state]
	return moved


func test_only_free_slimes_feel_tilt() -> void:
	var moved := _drift(30.0, 3 * 60)
	gut.p("30° for 3 s: %s" % moved)
	assert_gt(moved[SlimeBodies.FREE], 50.0, "the free slime rolls toward screen-right")
	for state in [SlimeBodies.TRAIN, SlimeBodies.SLEEPER, SlimeBodies.BEDTIME_ASLEEP]:
		assert_almost_eq(moved[state], 0.0, 0.5, "a %s slime doesn't feel tilt" % SlimeBodies.STATE_NAMES[state])
	var left := _drift(-30.0, 3 * 60)
	assert_lt(left[SlimeBodies.FREE], -50.0, "the other way, it rolls left")


func test_gravity_for_each_state() -> void:
	var bodies := SlimeBodies.new(Rng.new(1))
	bodies.free_down = _tilt(45.0).down()
	for state in [SlimeBodies.TRAIN, SlimeBodies.SLEEPER, SlimeBodies.BEDTIME_ASLEEP]:
		assert_eq(bodies.gravity_for(state), bodies.gravity)
	var free := bodies.gravity_for(SlimeBodies.FREE)
	assert_almost_eq(free.length(), bodies.gravity.length(), 1e-3, "same strength")
	assert_almost_eq(free.angle_to(bodies.gravity), deg_to_rad(45.0), 1e-6)
	bodies.free_down = Vector2.DOWN
	assert_eq(bodies.gravity_for(SlimeBodies.FREE), bodies.gravity, "untilted: exactly the plain gravity")


func test_the_script_tilt_step_may_say_flat() -> void:
	var parsed := TestModeScript.parse([
		{"tick": 3, "do": "tilt", "degrees": 20, "flat": true},
		{"tick": 4, "do": "tilt", "degrees": 20},
	])
	assert_eq(parsed.errors, PackedStringArray())
	assert_eq(parsed.events_at(3), [Simulation.tilt(20.0, true)])
	assert_eq(parsed.events_at(4), [Simulation.tilt(20.0, false)])
	var wrong := TestModeScript.parse([{"tick": 3, "do": "tilt", "degrees": 20, "flat": 1}])
	assert_eq(wrong.errors.size(), 1)
	assert_string_contains(wrong.errors[0], "flat")
