extends GutTest
## Stable slime identities (src/sim/slime_identities.gd): each slime carries
## the stable IDs of the placed base slimes it is made of (its "members"), so
## a save can name it across level versions. A placed slime has one member;
## a fused slime has the union (kept by the lower runtime id); a split gives
## each part one member, in sorted order, the original runtime id taking the
## first. The first slime is `start.first-slime`.

# @test-link [[req_persistence_and_saves]]

const Support := preload("res://tests/unit/slime_test_support.gd")


func test_a_placed_slime_is_named_by_its_one_member() -> void:
	var ids := SlimeIdentities.new()
	ids.assign(4, PackedStringArray(["s1.sleeper.07"]))
	assert_eq(ids.members_of(4), PackedStringArray(["s1.sleeper.07"]))
	assert_eq(ids.stable_id_of(4), "s1.sleeper.07")
	assert_eq(ids.stable_id_of(5), "", "a slime with no placed origin has no stable id")
	assert_eq(ids.members_of(5), PackedStringArray())


func test_members_are_kept_sorted() -> void:
	var ids := SlimeIdentities.new()
	ids.assign(1, PackedStringArray(["s1.sleeper.09", "s1.sleeper.02"]))
	assert_eq(ids.members_of(1), PackedStringArray(["s1.sleeper.02", "s1.sleeper.09"]))
	assert_eq(ids.stable_id_of(1), "s1.sleeper.02", "the first member in sorted order")


func test_a_fused_slime_takes_both_members_under_the_lower_id() -> void:
	var ids := SlimeIdentities.new()
	ids.assign(3, PackedStringArray(["s1.sleeper.05"]))
	ids.assign(7, PackedStringArray(["s1.sleeper.01", "s1.sleeper.04"]))
	ids.merge(7, 3)
	assert_eq(ids.members_of(3), PackedStringArray(["s1.sleeper.01", "s1.sleeper.04", "s1.sleeper.05"]))
	assert_eq(ids.members_of(7), PackedStringArray(), "the higher id is gone")
	assert_eq(ids.stable_id_of(3), "s1.sleeper.01")


func test_a_split_gives_each_part_one_member_in_order() -> void:
	var ids := SlimeIdentities.new()
	ids.assign(2, PackedStringArray(["s1.sleeper.08", "s1.sleeper.03", "start.first-slime"]))
	ids.split(PackedInt32Array([2, 11, 12]))
	assert_eq(ids.members_of(2), PackedStringArray(["s1.sleeper.03"]), "the original id keeps the first")
	assert_eq(ids.members_of(11), PackedStringArray(["s1.sleeper.08"]))
	assert_eq(ids.members_of(12), PackedStringArray(["start.first-slime"]))


func test_a_split_of_a_slime_without_members_gives_parts_without_members() -> void:
	var ids := SlimeIdentities.new()
	ids.assign(2, PackedStringArray(["s1.sleeper.03"]))
	ids.split(PackedInt32Array([2, 5]))
	assert_eq(ids.members_of(2), PackedStringArray(["s1.sleeper.03"]))
	assert_eq(ids.members_of(5), PackedStringArray(), "no member left for the second part")
	ids.split(PackedInt32Array([9, 10]))
	assert_eq(ids.members_of(9), PackedStringArray())
	assert_eq(ids.members_of(10), PackedStringArray())


func test_tidy_forgets_the_slimes_that_are_gone() -> void:
	var bodies := Support.bodies_on_floor()
	var a := bodies.create(0, 1, Vector2(0, -24))
	var ids := SlimeIdentities.new()
	ids.assign(a, PackedStringArray(["s1.sleeper.01"]))
	ids.assign(99, PackedStringArray(["s1.sleeper.02"]))
	ids.tidy(bodies)
	assert_eq(ids.members_of(a), PackedStringArray(["s1.sleeper.01"]))
	assert_eq(ids.members_of(99), PackedStringArray())


func test_dump_lists_the_named_slimes_in_id_order() -> void:
	var ids := SlimeIdentities.new()
	ids.assign(8, PackedStringArray(["s1.sleeper.02"]))
	ids.assign(3, PackedStringArray(["start.first-slime"]))
	ids.assign(5, PackedStringArray())
	assert_eq(ids.dump(), [
		{"id": 3, "members": ["start.first-slime"]},
		{"id": 8, "members": ["s1.sleeper.02"]},
	])


# --- Through the Simulation ---------------------------------------------------

func _level() -> LevelData:
	var data := LevelData.new("ids", 1)
	var loop := LoopData.new("t.loop")
	loop.add_segment("t.loop.out", 1, LoopData.OUTGOING, PackedVector2Array([
			Vector2(-1500, -24), Vector2(1500, -24)]))
	loop.add_segment("t.loop.back", 1, LoopData.RETURN, PackedVector2Array([
			Vector2(1500, -24), Vector2(1500, 400), Vector2(-1500, 400), Vector2(-1500, -24)]), "t.gate")
	data.loop = loop
	data.first_slime = {"id": "start.first-slime", "species": "A", "position": Vector2(-1400, -24)}
	data.add_split_zone("t.split-zone", Rect2(-900, -200, 200, 200))
	return data


func _sim() -> Simulation:
	var sim := Simulation.new(5)
	sim.slimes.terrain = TerrainSegments.new([Support.floor_polygon()])
	sim.load_level(_level())
	return sim


func test_the_first_slime_is_named_by_its_marker() -> void:
	var sim := _sim()
	var first := sim.slimes.ids()[0]
	assert_eq(sim.identities.members_of(first), PackedStringArray(["start.first-slime"]))


func test_a_slime_split_by_a_split_zone_hands_its_members_to_its_parts() -> void:
	var sim := _sim()
	var slime := sim.spawn_train_slime(1, 2, 540.0)
	sim.identities.assign(slime, PackedStringArray(["s1.sleeper.04", "s1.sleeper.02"]))
	var parts := []
	for i in 30 * Simulation.TICK_RATE:
		sim.step()
		if not sim.slimes.has(slime) or sim.slimes.size_of(slime) == 1:
			break
	assert_eq(sim.slimes.size_of(slime), 1, "split in the zone")
	for other in sim.slimes.ids():
		if other != slime and sim.slimes.species_of(other) == 1:
			parts.append(other)
	assert_eq(parts.size(), 1)
	assert_eq(sim.identities.members_of(slime), PackedStringArray(["s1.sleeper.02"]))
	assert_eq(sim.identities.members_of(parts[0]), PackedStringArray(["s1.sleeper.04"]))


func test_fuse_merges_the_bodies_and_the_members() -> void:
	var sim := _sim()
	var a := sim.spawn_train_slime(2, 1, 1500.0)
	var b := sim.spawn_train_slime(2, 1, 1560.0)
	sim.identities.assign(a, PackedStringArray(["s1.sleeper.06"]))
	sim.identities.assign(b, PackedStringArray(["s1.sleeper.05"]))
	var fused := sim.fuse(b, a)
	assert_eq(fused, a, "the lower id survives")
	assert_eq(sim.slimes.size_of(a), 2)
	assert_false(sim.slimes.has(b))
	assert_eq(sim.identities.members_of(a), PackedStringArray(["s1.sleeper.05", "s1.sleeper.06"]))
	assert_eq(sim.fuse(a, 999), -1, "a refused fusion changes nothing")
	assert_eq(sim.identities.members_of(a), PackedStringArray(["s1.sleeper.05", "s1.sleeper.06"]))


func test_identities_are_in_the_dump() -> void:
	var sim := _sim()
	assert_eq(sim.dump()["identities"], [{"id": sim.slimes.ids()[0], "members": ["start.first-slime"]}])
