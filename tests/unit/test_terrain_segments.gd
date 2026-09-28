extends GutTest
## TerrainSegments: the static terrain the slime rings collide with, as a
## list of segments with outward normals and a grid to find the ones near a
## point (O78: the simulation tests ring points against baked terrain itself).

## A block whose top is at y = 0, from x = -100 to 100, 50 px deep.
const BLOCK := [Vector2(-100, 0), Vector2(100, 0), Vector2(100, 50), Vector2(-100, 50)]


func _block(reverse := false) -> TerrainSegments:
	var polygon := PackedVector2Array(BLOCK)
	if reverse:
		polygon.reverse()
	return TerrainSegments.new([polygon])


func test_normals_point_out_of_the_solid_whatever_the_winding() -> void:
	for reverse in [false, true]:
		var terrain := _block(reverse)
		assert_eq(terrain.segment_count(), 4)
		for i in terrain.segment_count():
			var mid: Vector2 = (terrain.seg_a[i] + terrain.seg_b[i]) * 0.5
			var outside: Vector2 = mid + terrain.seg_n[i] * 2.0
			assert_false(Geometry2D.is_point_in_polygon(outside, PackedVector2Array(BLOCK)),
					"segment %d's normal points into the block (reverse=%s)" % [i, reverse])


func test_a_point_inside_is_pushed_to_the_nearest_surface() -> void:
	var terrain := _block()
	var hit := terrain.resolve(Vector2(10, 6))
	assert_true(hit["hit"])
	assert_almost_eq(hit["position"], Vector2(10, 0), Vector2(0.001, 0.001))
	assert_almost_eq(hit["normal"], Vector2(0, -1), Vector2(0.001, 0.001))
	# Near a side, the side is nearer.
	hit = terrain.resolve(Vector2(97, 20))
	assert_almost_eq(hit["position"], Vector2(100, 20), Vector2(0.001, 0.001))


func test_a_point_outside_is_left_alone() -> void:
	var terrain := _block()
	assert_false(terrain.resolve(Vector2(10, -3))["hit"], "just above the top")
	assert_false(terrain.resolve(Vector2(104, -4))["hit"], "outside a corner")
	assert_false(terrain.resolve(Vector2(5000, 5000))["hit"], "far from any terrain")


func test_depth_measures_penetration() -> void:
	var terrain := _block()
	assert_almost_eq(terrain.depth(Vector2(0, 7)), 7.0, 0.001)
	assert_eq(terrain.depth(Vector2(0, -7)), 0.0)


func test_curved_terrain_from_the_component_bake() -> void:
	# The same bake the Terrain component does at load (chunk 4).
	var curve := Curve2D.new()
	curve.add_point(Vector2(-300, -200), Vector2.ZERO, Vector2(150, 250))
	curve.add_point(Vector2(300, -200), Vector2(-150, 250))
	curve.add_point(Vector2(300, 100))
	curve.add_point(Vector2(-300, 100))
	var polygon := Terrain.bake_polygon(curve, 2.0)
	var terrain := TerrainSegments.new([polygon])
	assert_gt(terrain.segment_count(), 10, "the curve is baked into many segments")
	# A point just below the curve's lowest part is inside and comes out upward.
	var bottom := Vector2(0, -INF)
	for p in polygon:
		if absf(p.x) < 60.0 and p.y < 90.0 and p.y > bottom.y:
			bottom = p
	var hit := terrain.resolve(bottom + Vector2(0, 4))
	assert_true(hit["hit"])
	assert_lt(hit["normal"].y, -0.9, "pushed up out of the valley floor")
	assert_false(terrain.is_empty())
	assert_true(TerrainSegments.new([]).is_empty())
