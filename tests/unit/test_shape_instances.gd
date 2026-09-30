extends GutTest
## ShapeInstances (src/draw/shape_instances.gd): many copies of one shape in
## one instanced draw. Its shapes reproduce Godot 4.7's CPU geometry around
## the origin (draw_circle()'s disc bit for bit, draw_arc()'s antialiased
## full-circle polyline: strip, then outer and inner feather), and its copies
## are translations, kept in order.


func _shapes() -> ShapeInstances:
	var shapes := ShapeInstances.new()
	autofree(shapes)
	return shapes


# @test-link [[req_platform_and_performance_targets]]
func test_a_disc_is_the_disc_draw_circle_draws() -> void:
	var shapes := _shapes()
	var at := Vector2(123.4, -56.7)
	var radius := 17.0 * TapFeedback.EYE_SIZE
	shapes.set_disc(radius)
	var points := shapes.points
	assert_eq(points.size(), 66, "64 segments: 65 rim points and the centre")
	assert_eq(points[65], Vector2.ZERO, "the centre last")
	assert_eq(points[0], Vector2(radius, 0.0), "the rim starts at angle 0")
	assert_almost_eq(points[16], Vector2(0.0, radius), Vector2(0.0001, 0.0001))
	assert_almost_eq(points[32], Vector2(-radius, 0.0), Vector2(0.0001, 0.0001))
	assert_almost_eq(points[64], points[0], Vector2(0.0001, 0.0001), "the last rim point closes it")
	# canvas_item_add_ellipse (Godot 4.7): float step = TAU / 64, float angle
	# = i * step, point = Vector2(cos(angle) * r, sin(angle) * r) + pos, all
	# single precision, cos and sin the engine's float ones (from_angle's);
	# the copy's translation is added to the offset, in single precision too.
	var step := PackedFloat32Array([TAU / 64.0])[0]
	for i in 65:
		var angle := PackedFloat32Array([i * step])[0]
		assert_eq(points[i] + at, Vector2.from_angle(angle) * radius + at, "rim point %d" % i)
	assert_almost_eq(shapes.reach, radius, 0.0001)
	assert_eq(shapes.colors.size(), 66, "a colour per point")
	for c in shapes.colors:
		assert_eq(c, Color.WHITE, "white: the colour is the node's self_modulate")


# @test-link [[req_platform_and_performance_targets]]
func test_disc_triangles_fan_from_the_centre() -> void:
	var shapes := _shapes()
	shapes.set_disc(3.0)
	var indices := shapes.indices
	assert_eq(indices.size(), 64 * 3, "64 triangles")
	assert_eq(indices.slice(0, 3), PackedInt32Array([65, 0, 1]))
	assert_eq(indices.slice(63 * 3, 64 * 3), PackedInt32Array([65, 63, 64]))


# @test-link [[req_platform_and_performance_targets]]
func test_a_ring_is_the_polyline_draw_arc_draws() -> void:
	# draw_arc(ZERO, 10, 0, TAU, 5, colour, 2.0, true) in Godot 4.7: a closed
	# polyline through (10, 0), (0, 10), (-10, 0), (0, -10), (10, 0); width 2
	# antialiased is compensated to 1; each corner's offset is the bisector
	# lengthened by 1 / sin 45 degrees (sqrt 2), half the width out and in,
	# then the feather (1.25) beyond each edge.
	var shapes := _shapes()
	shapes.set_ring(10.0, 2.0, 5, true)
	var corners := [Vector2(10, 0), Vector2(0, 10), Vector2(-10, 0), Vector2(0, -10), Vector2(10, 0)]
	var edge := 0.5 * sqrt(2.0)
	var feather := 1.25 * sqrt(2.0)
	var expected := PackedVector2Array()
	for c: Vector2 in corners:
		var out := c.normalized()
		expected.append_array([c + out * edge, c - out * edge])
	for c: Vector2 in corners:
		var out := c.normalized()
		expected.append_array([c + out * edge, c + out * (edge + feather)])
	for c: Vector2 in corners:
		var out := c.normalized()
		expected.append_array([c - out * edge, c - out * (edge + feather)])
	assert_eq(shapes.points.size(), 30, "three strips of two points per corner")
	for i in 30:
		assert_almost_eq(shapes.points[i], expected[i], Vector2(0.0001, 0.0001), "point %d" % i)
	for i in 10:
		assert_eq(shapes.colors[i], Color.WHITE, "the line's strip: colour %d" % i)
	for i in range(10, 30):
		var feather_edge := i % 2 == 1
		assert_eq(shapes.colors[i], Color(1, 1, 1, 0) if feather_edge else Color.WHITE,
				"a feather strip: its outer edge transparent (%d)" % i)
	assert_eq(shapes.indices.size(), 3 * 8 * 3, "each strip of 10 points is 8 triangles")
	assert_eq(shapes.indices.slice(0, 9), PackedInt32Array([0, 1, 2, 2, 1, 3, 2, 3, 4]),
			"strip order, odd triangles swapped")
	assert_eq(shapes.indices.slice(24, 30), PackedInt32Array([10, 11, 12, 12, 11, 13]),
			"then the outer feather's strip")
	assert_eq(shapes.indices.slice(48, 51), PackedInt32Array([20, 21, 22]), "then the inner one")
	assert_almost_eq(shapes.reach, 10.0 + edge + feather, 0.0001)


# @test-link [[req_platform_and_performance_targets]]
func test_a_ring_width_is_compensated_as_godot_does() -> void:
	# canvas_item_get_compensated_antialiasing_width: up to 2.5 halved, up to
	# 5 blended towards width - 0.625, beyond width - 0.625; not antialiased,
	# as given and no feathers.
	var widths := {2.0: 1.0, 4.0: 2.825, 6.0: 5.375}
	for width: float in widths:
		var shapes := _shapes()
		shapes.set_ring(10.0, width, 5, true)
		var line := shapes.points[0].distance_to(shapes.points[1]) / sqrt(2.0)
		assert_almost_eq(line, widths[width], 0.0001, "width %s" % width)
	var plain := _shapes()
	plain.set_ring(10.0, 2.0, 5, false)
	assert_eq(plain.points.size(), 10, "the line's strip only")
	assert_almost_eq(plain.points[0].distance_to(plain.points[1]) / sqrt(2.0), 2.0, 0.0001)


# @test-link [[req_platform_and_performance_targets]]
func test_the_outline_ring_has_the_draw_arc_point_count() -> void:
	var shapes := _shapes()
	shapes.set_ring(14.0, 2.0, 24, true)
	assert_eq(shapes.points.size(), 3 * 48, "24 points: three strips of 48")
	assert_eq(shapes.indices.size(), 3 * 46 * 3)
	assert_almost_eq(shapes.reach, 14.0 + 1.75, 0.05, "half the line and the feather out")


# @test-link [[req_platform_and_performance_targets]]
func test_copies_are_kept_in_order_and_cleared() -> void:
	var shapes := _shapes()
	shapes.set_disc(2.0)
	for k in 20:
		shapes.add(Vector2(k * 10.5, -k))
	shapes.commit()
	assert_eq(shapes.instance_count, 20, "room grows past the first 8")
	for k in 20:
		assert_eq(shapes.instance_at(k), Vector2(k * 10.5, -k))
	shapes.clear()
	assert_eq(shapes.instance_count, 0)
	shapes.add(Vector2(1, 2))
	shapes.commit()
	assert_eq(shapes.instance_count, 1)
	assert_eq(shapes.instance_at(0), Vector2(1, 2), "rewritten in place")

