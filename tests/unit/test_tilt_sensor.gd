extends GutTest
## The tilt sensor's readings (src/platform/tilt_sensor.gd): Godot's
## accelerometer vector (screen axes, pointing down along gravity, m/s²)
## turned into the in-plane angle (positive when the phone's right edge dips)
## and "flat"; and TiltFeed (src/platform/tilt_feed.gd) pushing them to a
## simulation only when they change, never a zero reading.

# @test-link [[req_tilt_input]]

const G := 9.81


## What Godot reads for a phone held in landscape with its right edge
## dipped `degrees` (negative: the left edge), the screen `back` degrees back
## from vertical (0: upright, 90: flat screen up).
static func _held(degrees: float, back := 0.0) -> Vector3:
	var roll := deg_to_rad(degrees)
	var lean := deg_to_rad(back)
	var in_plane := G * cos(lean)
	return Vector3(in_plane * sin(roll), -in_plane * cos(roll), -G * sin(lean))


func _feed_with(reading: Vector3) -> TiltFeed:
	var feed := TiltFeed.new()
	feed.sensor = func() -> Vector3: return reading
	return feed


# --- TiltSensor ------------------------------------------------------------------

func test_upright_landscape_is_zero() -> void:
	var reading := TiltSensor.reading(Vector3(0, -G, 0))
	assert_almost_eq(reading["degrees"], 0.0, 1e-6)
	assert_false(reading["flat"])


func test_the_right_edge_dipped_is_positive() -> void:
	# Right edge down: gravity leans toward screen-right, the reading's x > 0.
	var reading := TiltSensor.reading(_held(30.0))
	assert_gt(_held(30.0).x, 0.0)
	assert_almost_eq(reading["degrees"], 30.0, 1e-4)
	assert_false(reading["flat"])


func test_the_left_edge_dipped_is_negative() -> void:
	assert_almost_eq(TiltSensor.reading(_held(-30.0))["degrees"], -30.0, 1e-4)


func test_the_angle_ignores_how_far_the_screen_leans_back() -> void:
	for back in [0.0, 30.0, 60.0]:
		assert_almost_eq(TiltSensor.degrees_of(_held(25.0, back)), 25.0, 1e-4, "leaning %s°" % back)


func test_upside_down_is_half_a_turn() -> void:
	assert_almost_eq(absf(TiltSensor.degrees_of(Vector3(0, G, 0))), 180.0, 1e-4)


func test_lying_flat_is_flat_and_zero() -> void:
	for gravity in [Vector3(0, 0, -G), Vector3(0, 0, G), _held(40.0, 90.0)]:
		assert_eq(TiltSensor.reading(gravity), {"degrees": 0.0, "flat": true}, str(gravity))


func test_flat_below_the_threshold_and_not_above() -> void:
	var edge := 90.0 - TiltSensor.FLAT_DEGREES
	assert_true(TiltSensor.is_flat(_held(30.0, edge + 1.0)), "screen 19° from horizontal")
	assert_false(TiltSensor.is_flat(_held(30.0, edge - 1.0)), "screen 21° from horizontal")
	assert_almost_eq(TiltSensor.reading(_held(30.0, edge - 1.0))["degrees"], 30.0, 1e-3)


func test_no_sensor_is_flat() -> void:
	assert_true(TiltSensor.is_flat(Vector3.ZERO), "desktop: Vector3.ZERO")
	assert_true(TiltSensor.is_flat(Vector3(0, -0.5, 0)), "free fall: next to nothing")
	assert_false(TiltSensor.is_flat(Vector3(0, -TiltSensor.MIN_MAGNITUDE, 0)))


func test_a_readings_scale_does_not_matter() -> void:
	assert_almost_eq(TiltSensor.degrees_of(_held(-15.0) * 1.3), -15.0, 1e-4, "shaken: longer")
	assert_almost_eq(TiltSensor.degrees_of(_held(-15.0) * 0.7), -15.0, 1e-4)


# --- TiltFeed --------------------------------------------------------------------

func test_the_feed_pushes_a_reading_to_the_simulation() -> void:
	var sim := Simulation.new(1)
	assert_true(_feed_with(_held(30.0)).feed(sim))
	sim.step()
	assert_almost_eq(sim.phone_tilt.degrees, 30.0, 1e-4)
	assert_false(sim.phone_tilt.flat)


func test_the_feed_pushes_nothing_for_a_zero_reading() -> void:
	var sim := Simulation.new(1)
	assert_false(_feed_with(Vector3.ZERO).feed(sim), "desktop: no sensor")
	sim.step()
	assert_eq(sim.input_log, [] as Array[Dictionary])


func test_the_feed_pushes_only_changes() -> void:
	var sim := Simulation.new(1)
	var at := [_held(20.0)]
	var feed := TiltFeed.new()
	feed.sensor = func() -> Vector3: return at[0]
	assert_true(feed.feed(sim), "the first reading")
	assert_false(feed.feed(sim), "the same reading")
	at[0] = _held(20.0 + TiltFeed.CHANGE_DEGREES * 0.5)
	assert_false(feed.feed(sim), "under CHANGE_DEGREES")
	at[0] = _held(20.0 + TiltFeed.CHANGE_DEGREES * 1.1)
	assert_true(feed.feed(sim), "past CHANGE_DEGREES")
	at[0] = Vector3(0, 0, -G)
	assert_true(feed.feed(sim), "gone flat")
	at[0] = Vector3(0.1, 0, -G)
	assert_false(feed.feed(sim), "still flat")
	assert_true(feed.feed(Simulation.new(2)), "a new simulation gets the reading at once")


func test_changed_wraps_around_half_a_turn() -> void:
	var before := {"degrees": 179.8, "flat": false}
	assert_false(TiltFeed.changed(before, {"degrees": -179.9, "flat": false}), "0.3° across ±180°")
	assert_true(TiltFeed.changed(before, {"degrees": -178.0, "flat": false}))
	assert_true(TiltFeed.changed({}, {"degrees": 0.0, "flat": true}), "nothing read yet")
