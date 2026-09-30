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


## Chunk 19 (SaveMigration): inside or not, however deep, whatever the
## winding; two outlines one inside the other are both solid.
func test_is_solid_sees_points_deep_inside() -> void:
	for reverse in [false, true]:
		var terrain := _block(reverse)
		assert_true(terrain.is_solid(Vector2(0, 25)), "25 px deep, beyond MARGIN")
		assert_true(terrain.is_solid(Vector2(-99, 1)), "just inside a corner")
		assert_false(terrain.is_solid(Vector2(0, -1)), "just above")
		assert_false(terrain.is_solid(Vector2(150, 25)), "beside it")
		assert_false(terrain.is_solid(Vector2(-150, 25)), "on the other side")
	var nested := TerrainSegments.new([PackedVector2Array(BLOCK),
			PackedVector2Array([Vector2(-10, 10), Vector2(-10, 40), Vector2(10, 40), Vector2(10, 10)])])
	assert_true(nested.is_solid(Vector2(0, 25)), "inside both")
	assert_true(nested.is_solid(Vector2(-50, 25)), "inside the outer one only")


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


## A lip like the test level's dip hollows: a slope up to a sharp top
## corner at (92, -170), then a vertical outer face. The corner's two edges
## are equally near a point past it; the plane of the slope alone would put
## a wedge outside the corner inside the terrain (chunk 16d).
const LIP := [Vector2(0, -130), Vector2(69, -150), Vector2(92, -170), Vector2(92, -130)]


func test_outside_a_sharp_corner_is_outside_whichever_edge_is_listed_first() -> void:
	for reverse in [false, true]:
		var polygon := PackedVector2Array(LIP)
		if reverse:
			polygon.reverse()
		var terrain := TerrainSegments.new([polygon])
		for point in [Vector2(100, -175), Vector2(95, -172), Vector2(105.7, -177), Vector2(110.8, -186)]:
			assert_false(terrain.resolve(point)["hit"], "%s is past the corner (reverse=%s)" % [point, reverse])
		for point in [Vector2(90, -166), Vector2(80, -155), Vector2(91, -140)]:
			assert_true(terrain.resolve(point)["hit"], "%s is inside the lip (reverse=%s)" % [point, reverse])
