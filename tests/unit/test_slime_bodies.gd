extends GutTest
## SlimeBodies: the soft-body store. Each slime is a ring of points in packed
## arrays (struct of arrays); these tests cover creating, reading and removing
## slimes, and the state each slime is in.
# @test-link [[req_slime_states]]

const Support := preload("res://tests/unit/slime_test_support.gd")


func _bodies() -> SlimeBodies:
	return SlimeBodies.new(Rng.new(1))


func test_ring_point_count_per_size() -> void:
	var bodies := _bodies()
	var expected := {1: 12, 2: 15, 3: 18}
	for size in expected:
		var slime := bodies.create(0, size, Vector2(100 * size, 0))
		assert_eq(bodies.points_of(slime).size(), expected[size], "size %d" % size)
		assert_eq(SlimeBodies.points_for(size), expected[size])


func test_ring_radius_and_area() -> void:
	var bodies := _bodies()
	var slime := bodies.create(0, 1, Vector2(50, -40))
	assert_eq(bodies.radius_of(slime), SlimeBodies.RING_RADIUS_SIZE_1)
	assert_almost_eq(bodies.centre_of(slime), Vector2(50, -40), Vector2(0.01, 0.01))
	for point in bodies.points_of(slime):
		assert_almost_eq(point.distance_to(Vector2(50, -40)), SlimeBodies.RING_RADIUS_SIZE_1, 0.01)
	assert_almost_eq(bodies.area_of(slime), bodies.rest_area_of(slime), 0.5)
	# The area is proportional to the size (within the polygon's rounding).
	var one := SlimeBodies.rest_area_for(1)
	for size in [2, 3]:
		assert_almost_eq(SlimeBodies.rest_area_for(size) / one, float(size), 0.05 * size, "size %d" % size)
		assert_almost_eq(SlimeBodies.ring_radius_for(size), SlimeBodies.RING_RADIUS_SIZE_1 * sqrt(size), 0.001)


func test_create_reads_back_species_size_and_state() -> void:
	var bodies := _bodies()
	var slime := bodies.create(4, 2, Vector2.ZERO, SlimeBodies.SLEEPER)
	assert_eq(bodies.species_of(slime), 4)
	assert_eq(bodies.size_of(slime), 2)
	assert_eq(bodies.state_of(slime), SlimeBodies.SLEEPER)
	assert_eq(bodies.state_of(bodies.create(0, 1, Vector2(200, 0))), SlimeBodies.TRAIN, "train by default")


func test_create_refuses_a_bad_species_or_size() -> void:
	var bodies := _bodies()
	assert_eq(bodies.create(6, 1, Vector2.ZERO), -1)
	assert_push_error("species")
	assert_eq(bodies.create(0, 4, Vector2.ZERO), -1)
	assert_push_error("size")
	assert_eq(bodies.create(0, 1, Vector2.ZERO, 9), -1)
	assert_push_error("state")
	assert_eq(bodies.slime_count, 0)


func test_the_four_states() -> void:
	var bodies := _bodies()
	var slime := bodies.create(0, 1, Vector2.ZERO)
	for state in [SlimeBodies.SLEEPER, SlimeBodies.TRAIN, SlimeBodies.FREE, SlimeBodies.BEDTIME_ASLEEP]:
		bodies.set_state(slime, state)
		assert_eq(bodies.state_of(slime), state)
	assert_eq(SlimeBodies.STATE_NAMES, PackedStringArray(["sleeper", "train", "free", "bedtime_asleep"]))


func test_ids_are_ascending_and_never_reused() -> void:
	var bodies := _bodies()
	var a := bodies.create(0, 1, Vector2(0, 0))
	var b := bodies.create(1, 2, Vector2(100, 0))
	assert_gt(b, a)
	assert_true(bodies.remove(b))
	var c := bodies.create(2, 1, Vector2(200, 0))
	assert_gt(c, b, "a removed slime's id isn't handed out again")
	assert_false(bodies.has(b))
	assert_false(bodies.remove(b), "removing twice")
	assert_eq(bodies.ids(), PackedInt32Array([a, c]))


func test_remove_compacts_the_arrays() -> void:
	var bodies := _bodies()
	var a := bodies.create(0, 1, Vector2(0, 0))
	var b := bodies.create(1, 3, Vector2(200, 0))
	var c := bodies.create(2, 2, Vector2(400, 0))
	var c_points := bodies.points_of(c)
	bodies.remove(b)
	assert_eq(Support.layout_problems(bodies), PackedStringArray())
	assert_eq(bodies.slime_count, 2)
	assert_eq(bodies.pos.size(), 12 + 15)
	assert_eq(bodies.points_of(c), c_points, "the later slime's points moved down unchanged")
	assert_eq(bodies.species_of(c), 2)
	assert_eq(bodies.index_of(a), 0)
	assert_eq(bodies.index_of(c), 1)
	assert_eq(bodies.index_of(b), -1)


func test_a_slime_falls_under_gravity() -> void:
	var bodies := _bodies()
	var slime := bodies.create(0, 1, Vector2.ZERO)
	for i in 30:
		bodies.tick(1.0 / 60.0)
	assert_gt(bodies.centre_of(slime).y, 50.0, "half a second of free fall")
	assert_gt(bodies.velocity_of(slime).y, 500.0)


func test_set_velocity() -> void:
	var bodies := _bodies()
	bodies.gravity = Vector2.ZERO
	var slime := bodies.create(0, 1, Vector2.ZERO)
	bodies.set_velocity(slime, Vector2(120, 0))
	assert_almost_eq(bodies.velocity_of(slime), Vector2(120, 0), Vector2(0.01, 0.01))
	for i in 60:
		bodies.tick(1.0 / 60.0)
	assert_almost_eq(bodies.centre_of(slime).x, 120.0, 6.0, "about a second at 120 px/s, lightly damped")


func test_dump_lists_the_slimes_in_id_order() -> void:
	var bodies := _bodies()
	var a := bodies.create(3, 2, Vector2(10.123456, -5.5), SlimeBodies.FREE)
	var b := bodies.create(5, 1, Vector2(200, 0))
	var dump := bodies.dump()
	assert_eq(dump.size(), 2)
	assert_eq(dump[0]["id"], a)
	assert_eq(dump[1]["id"], b)
	assert_eq(dump[0]["species"], 3)
	assert_eq(dump[0]["size"], 2)
	assert_eq(dump[0]["state"], "free")
	assert_almost_eq(dump[0]["centre"], Vector2(10.12, -5.5), Vector2(0.006, 0.006))
	assert_has(dump[0], "hop_timer")
	assert_has(dump[0], "rng_state")
	assert_typeof(dump[0]["rng_state"], TYPE_STRING)
