extends GutTest
## SplitZones (src/sim/split_zones.gd): every slime inside a split zone is
## split into base slimes at once, which keep its species and state. Slimes
## outside every split zone are never split.

# @test-link [[rule_split_zone_only_splitter]]
# @test-link [[rule_start_carries_split_zone]]

const Support := preload("res://tests/unit/slime_test_support.gd")


func _zones() -> SplitZones:
	return SplitZones.new({"start.split-zone": Rect2(-150, -200, 300, 200)})


func test_a_slime_inside_a_split_zone_splits_into_base_slimes() -> void:
	var bodies := Support.bodies_on_floor()
	var big := bodies.create(2, 3, Vector2(0, -40), SlimeBodies.TRAIN)
	var splits := _zones().apply(bodies)
	assert_eq(splits.size(), 1)
	var parts: PackedInt32Array = splits[0]
	assert_eq(parts.size(), 3)
	assert_eq(parts[0], big, "the original id is the first part")
	for part in parts:
		assert_eq(bodies.size_of(part), 1)
		assert_eq(bodies.species_of(part), 2)
		assert_eq(bodies.state_of(part), SlimeBodies.TRAIN)
	assert_eq(Support.layout_problems(bodies), PackedStringArray())


func test_slimes_outside_split_zones_are_left_alone() -> void:
	var bodies := Support.bodies_on_floor()
	var outside := bodies.create(1, 2, Vector2(400, -30), SlimeBodies.TRAIN)
	var base := bodies.create(1, 1, Vector2(0, -24), SlimeBodies.TRAIN)
	assert_eq(_zones().apply(bodies), [])
	assert_eq(bodies.size_of(outside), 2)
	assert_eq(bodies.size_of(base), 1)
	assert_eq(bodies.slime_count, 2)


func test_every_big_slime_in_the_zone_splits_in_one_pass() -> void:
	var bodies := Support.bodies_on_floor()
	bodies.create(0, 2, Vector2(-90, -30), SlimeBodies.TRAIN)
	bodies.create(0, 3, Vector2(80, -40), SlimeBodies.TRAIN)
	var splits := _zones().apply(bodies)
	assert_eq(splits.size(), 2)
	assert_eq(bodies.slime_count, 5)
	for slime_id in bodies.ids():
		assert_eq(bodies.size_of(slime_id), 1)


func test_no_zones_no_splits() -> void:
	var bodies := Support.bodies_on_floor()
	bodies.create(0, 3, Vector2(0, -40), SlimeBodies.TRAIN)
	assert_eq(SplitZones.new({}).apply(bodies), [])
	assert_eq(bodies.slime_count, 1)
