extends GutTest
## Fusion and splitting as ring operations (SlimeBodies.merge and split).
## When two slimes fuse (the 3 s contact trigger is chunk 10) and where they
## split (the split zone is chunk 6) is decided elsewhere; these are the
## operations those chunks call.
# @test-link [[rule_max_size_three]]
# @test-link [[rule_fusion_contact_time]]
# @test-link [[rule_split_zone_only_splitter]]
# @test-link [[req_species_and_colour]]

const Support := preload("res://tests/unit/slime_test_support.gd")


func _bodies() -> SlimeBodies:
	var bodies := SlimeBodies.new(Rng.new(7))
	bodies.gravity = Vector2.ZERO
	return bodies


# --- Merge ------------------------------------------------------------------

func test_merge_sums_the_sizes_into_one_ring() -> void:
	var bodies := _bodies()
	var a := bodies.create(2, 1, Vector2(0, 0))
	var b := bodies.create(2, 1, Vector2(40, 0))
	var merged := bodies.merge(a, b)
	assert_eq(merged, a, "the lower id survives")
	assert_eq(bodies.slime_count, 1)
	assert_false(bodies.has(b))
	assert_eq(bodies.size_of(merged), 2)
	assert_eq(bodies.species_of(merged), 2)
	assert_eq(bodies.points_of(merged).size(), 15)
	assert_eq(Support.layout_problems(bodies), PackedStringArray())


func test_merge_up_to_three() -> void:
	var bodies := _bodies()
	var a := bodies.create(0, 1, Vector2(0, 0))
	var b := bodies.create(0, 2, Vector2(60, 0))
	assert_true(bodies.can_merge(a, b))
	var merged := bodies.merge(a, b)
	assert_eq(bodies.size_of(merged), 3)
	assert_eq(bodies.points_of(merged).size(), 18)


func test_merge_refused_when_the_sizes_add_up_to_more_than_three() -> void:
	var bodies := _bodies()
	var a := bodies.create(0, 2, Vector2(0, 0))
	var b := bodies.create(0, 2, Vector2(80, 0))
	var c := bodies.create(0, 1, Vector2(200, 0))
	var d := bodies.create(0, 3, Vector2(300, 0))
	var before := bodies.dump()
	assert_false(bodies.can_merge(a, b))
	assert_eq(bodies.merge(a, b), -1, "2 + 2")
	assert_eq(bodies.merge(c, d), -1, "1 + 3")
	assert_eq(bodies.dump(), before, "a refused merge changes nothing")


func test_merge_refused_across_species() -> void:
	var bodies := _bodies()
	var a := bodies.create(0, 1, Vector2(0, 0))
	var b := bodies.create(1, 1, Vector2(40, 0))
	assert_false(bodies.can_merge(a, b))
	assert_eq(bodies.merge(a, b), -1)
	assert_eq(bodies.slime_count, 2)


func test_merge_refused_with_itself_or_a_missing_slime() -> void:
	var bodies := _bodies()
	var a := bodies.create(0, 1, Vector2(0, 0))
	assert_eq(bodies.merge(a, a), -1)
	assert_eq(bodies.merge(a, 999), -1)
	assert_eq(bodies.slime_count, 1)


func test_merge_keeps_the_area_and_the_centre_of_mass() -> void:
	var bodies := _bodies()
	var a := bodies.create(3, 1, Vector2(0, 0))
	var b := bodies.create(3, 2, Vector2(60, 30))
	var area_before := bodies.rest_area_of(a) + bodies.rest_area_of(b)
	var expected_centre := (bodies.centre_of(a) * 1.0 + bodies.centre_of(b) * 2.0) / 3.0
	var merged := bodies.merge(a, b)
	assert_almost_eq(bodies.rest_area_of(merged) / area_before, 1.0, 0.03)
	assert_almost_eq(bodies.area_of(merged) / area_before, 1.0, 0.03)
	assert_almost_eq(bodies.centre_of(merged), expected_centre, Vector2(0.01, 0.01))


func test_merge_keeps_the_momentum() -> void:
	var bodies := _bodies()
	var a := bodies.create(0, 1, Vector2(0, 0))
	var b := bodies.create(0, 2, Vector2(60, 0))
	bodies.set_velocity(a, Vector2(90, 0))
	bodies.set_velocity(b, Vector2(-60, 30))
	var merged := bodies.merge(a, b)
	var expected := (Vector2(90, 0) * 1.0 + Vector2(-60, 30) * 2.0) / 3.0
	assert_almost_eq(bodies.velocity_of(merged), expected, Vector2(0.05, 0.05))


func test_merge_does_not_depend_on_the_argument_order() -> void:
	var one := _bodies()
	var two := _bodies()
	for bodies in [one, two]:
		bodies.create(0, 1, Vector2(0, 0))
		bodies.create(0, 1, Vector2(40, 5))
	one.merge(1, 2)
	two.merge(2, 1)
	assert_eq(one.dump(), two.dump())


func test_merge_keeps_later_slimes_intact() -> void:
	var bodies := _bodies()
	var a := bodies.create(0, 1, Vector2(0, 0))
	var b := bodies.create(1, 3, Vector2(200, 0))
	var c := bodies.create(0, 1, Vector2(40, 0))
	var d := bodies.create(2, 2, Vector2(400, 0))
	var b_points := bodies.points_of(b)
	var d_points := bodies.points_of(d)
	bodies.merge(c, a)
	assert_eq(Support.layout_problems(bodies), PackedStringArray())
	assert_eq(bodies.ids(), PackedInt32Array([a, b, d]))
	assert_eq(bodies.points_of(b), b_points)
	assert_eq(bodies.points_of(d), d_points)


# --- Split ------------------------------------------------------------------

func test_split_gives_base_slimes_of_the_same_species() -> void:
	var bodies := _bodies()
	var slime := bodies.create(4, 3, Vector2(100, -50), SlimeBodies.FREE)
	var parts := bodies.split(slime)
	assert_eq(parts.size(), 3)
	assert_eq(parts[0], slime, "the first part keeps the id")
	for part in parts:
		assert_eq(bodies.size_of(part), 1)
		assert_eq(bodies.species_of(part), 4)
		assert_eq(bodies.state_of(part), SlimeBodies.FREE)
		assert_eq(bodies.points_of(part).size(), 12)
	assert_eq(bodies.slime_count, 3)
	assert_eq(Support.layout_problems(bodies), PackedStringArray())


func test_split_places_the_parts_apart_without_overlap() -> void:
	for size in [2, 3]:
		var bodies := _bodies()
		var slime := bodies.create(0, size, Vector2(0, 0))
		var parts := bodies.split(slime)
		assert_eq(parts.size(), size)
		var mean := Vector2.ZERO
		for i in parts.size():
			mean += bodies.centre_of(parts[i])
			for j in range(i + 1, parts.size()):
				var gap := bodies.centre_of(parts[i]).distance_to(bodies.centre_of(parts[j]))
				assert_gt(gap, 2.0 * SlimeBodies.RING_RADIUS_SIZE_1 + 2.0 * SlimeBodies.EDGE,
						"size %d: parts %d and %d overlap" % [size, i, j])
		assert_almost_eq(mean / parts.size(), Vector2.ZERO, Vector2(0.01, 0.01), "centred on the slime")


func test_split_keeps_the_velocity() -> void:
	var bodies := _bodies()
	var slime := bodies.create(0, 2, Vector2(0, 0))
	bodies.set_velocity(slime, Vector2(50, -20))
	for part in bodies.split(slime):
		assert_almost_eq(bodies.velocity_of(part), Vector2(50, -20), Vector2(0.05, 0.05))


func test_split_of_a_base_slime_changes_nothing() -> void:
	var bodies := _bodies()
	var slime := bodies.create(0, 1, Vector2(0, 0))
	var before := bodies.dump()
	assert_eq(bodies.split(slime), PackedInt32Array([slime]))
	assert_eq(bodies.dump(), before)
	assert_eq(bodies.split(999), PackedInt32Array(), "a missing slime")


func test_split_in_the_middle_keeps_the_arrays_consistent() -> void:
	var bodies := _bodies()
	var a := bodies.create(0, 1, Vector2(0, 0))
	var b := bodies.create(1, 3, Vector2(300, 0))
	var c := bodies.create(2, 2, Vector2(600, 0))
	var c_points := bodies.points_of(c)
	var parts := bodies.split(b)
	assert_eq(Support.layout_problems(bodies), PackedStringArray())
	assert_eq(bodies.ids(), PackedInt32Array([a, b, c, parts[1], parts[2]]))
	assert_eq(bodies.points_of(c), c_points)


func test_split_then_merge_back() -> void:
	var bodies := _bodies()
	var slime := bodies.create(5, 3, Vector2(0, 0))
	var parts := bodies.split(slime)
	var two := bodies.merge(parts[0], parts[1])
	var three := bodies.merge(two, parts[2])
	assert_eq(three, slime)
	assert_eq(bodies.size_of(three), 3)
	assert_eq(bodies.slime_count, 1)
	assert_eq(Support.layout_problems(bodies), PackedStringArray())
