extends GutTest
## Chunk LD1: decoration (O96's proposed default, D123) never collides, never
## takes a tap and draws behind the level unless asked to be in front.


func _square(at: Vector2, half: float) -> Curve2D:
	var curve := Curve2D.new()
	for corner in [Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half),
			Vector2(-half, -half)]:
		curve.add_point(at + corner)
	return curve


func _level_with(decoration: Decoration) -> Level:
	var level := Level.new()
	level.level_id = "unit"
	var loop := Loop.new()
	loop.stable_id = "start.loop"
	var segment := LoopSegment.new()
	segment.stable_id = "s1.loop"
	segment.curve = Curve2D.new()
	segment.curve.add_point(Vector2(0, 0))
	segment.curve.add_point(Vector2(500, 0))
	loop.add_child(segment)
	level.add_child(loop)
	level.add_child(decoration)
	return level


func test_a_decoration_is_not_a_level_thing_nor_a_tap_target() -> void:
	var decoration := Decoration.new()
	decoration.curve = _square(Vector2(100, -50), 40.0)
	var level := _level_with(decoration)
	add_child_autofree(level)
	assert_eq(level.load_errors, PackedStringArray())
	assert_false(decoration.is_in_group(Level.THINGS_GROUP))
	assert_true(decoration.is_in_group(Decoration.GROUP))
	assert_eq(level.data.tap_targets, {})


func test_a_decoration_never_collides() -> void:
	var decoration := Decoration.new()
	decoration.curve = _square(Vector2(100, -50), 40.0)
	var level := _level_with(decoration)
	add_child_autofree(level)
	assert_eq(decoration.baked_polygon.size(), 4, "baked into a fill")
	assert_eq(decoration.fill.polygon, decoration.baked_polygon)
	assert_eq(decoration.find_children("*", "CollisionPolygon2D", true, false).size(), 0)
	var terrain := SlimeWorld.terrain_from(level)
	assert_false(terrain.resolve(Vector2(100, -50))["hit"], "the slimes don't see it")


func test_behind_by_default_in_front_on_request() -> void:
	var decoration := Decoration.new()
	assert_eq(decoration.z_index, Decoration.Z_BEHIND)
	decoration.in_front = true
	assert_eq(decoration.z_index, Decoration.Z_IN_FRONT)
	decoration.in_front = false
	assert_eq(decoration.z_index, Decoration.Z_BEHIND)
	decoration.free()


func test_its_outline_in_level_coordinates() -> void:
	var decoration := Decoration.new()
	decoration.curve = _square(Vector2.ZERO, 10.0)
	decoration.position = Vector2(300, 20)
	var level := _level_with(decoration)
	autofree(level)
	var outline := decoration.level_polygon(level)
	assert_eq(outline.size(), 4)
	assert_true(Geometry2D.is_point_in_polygon(Vector2(300, 20), outline))
