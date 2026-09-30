class_name ShapeInstances
extends Node2D
## Many copies of one shape, each at its own place, drawn in ONE instanced
## draw call (a RenderingServer MultiMesh with translation-only 2D
## transforms), where a draw_circle() or a draw_arc() per copy made one draw
## call each (polygons never batch in the Compatibility renderer).
##
## The shape is a triangle list that reproduces Godot 4.7's own CPU geometry
## around the origin: set_disc() is draw_circle()'s filled disc, set_ring()
## draw_arc()'s full-circle polyline with its feathered edges. The GPU adds
## each copy's translation to the shape's points before the canvas transform
## (the instance transform is folded into the item's identity transform, which
## leaves it exact), so a disc copy lands on draw_circle()'s points bit for bit;
## a ring copy within float rounding (draw_arc() works its geometry out at the
## absolute position).
##
## The colour is this node's self_modulate: exact, where mesh vertex colours
## are stored in 8 bits (rounded down) and MultiMesh instance colours in half
## floats. The shape's vertex colours are white, alpha 0 where a feather fades
## out, as draw_arc() makes them (its colour with alpha 0).
##
## It is a child canvas item, so it draws after its parent's own drawing and
## in scene-tree order among its siblings: the owner orders it through the
## tree. Place it at the parent's origin, with an identity transform chain up
## to the canvas (the world origin), so the translations stay exact.
##
## Each redraw of the owner: set the shape (rebuilt only when its arguments
## change), clear(), add() each copy's place, then commit().
# @spec-link [[req_platform_and_performance_targets]]

## draw_circle()'s segment count (canvas_item_add_ellipse in Godot 4.7): a
## disc is DISC_SEGMENTS + 1 rim points, the last closing the rim, then the
## centre, so DISC_VERTICES points and a fan of DISC_SEGMENTS triangles
## (centre, rim i, rim i + 1).
const DISC_SEGMENTS := 64
const DISC_VERTICES := DISC_SEGMENTS + 2
## RendererCanvasCull's antialiasing feather width, and Godot's CMP_EPSILON
## (the polyline code compares against both).
const FEATHER_SIZE := 1.25
const CMP_EPSILON := 0.00001
## A transparent white: a feather's outer vertex colour, times self_modulate.
const CLEAR_WHITE := Color(1.0, 1.0, 1.0, 0.0)
## Floats per instance in the MultiMesh buffer: a Transform2D as
## (x.x, y.x, 0, origin.x, x.y, y.y, 0, origin.y).
const FLOATS_PER_INSTANCE := 8

## The shape, a triangle list around the origin: its points, one colour per
## point and three indices per triangle (in draw order). Read-only outside.
var points := PackedVector2Array()
var colors := PackedColorArray()
var indices := PackedInt32Array()
## How far the shape reaches from its origin: its farthest point's distance.
var reach := 0.0
## How many copies the last commit() draws (add()s since the last clear()).
var instance_count := 0

## The rim of a unit disc: DISC_SEGMENTS + 1 points, point i at the angle
## i * TAU / DISC_SEGMENTS worked out in single precision, through the same
## float cos and sin draw_circle() uses (Vector2.from_angle), so a rim point
## scaled lands on draw_circle()'s offset bit for bit.
static var _disc_rim := _unit_disc_rim()

## What the shape was last built from ([] before the first), so setting the
## same shape again costs nothing.
var _shape_key: Array = []
var _mesh := RID()
var _multimesh := RID()
## The instance transforms (FLOATS_PER_INSTANCE each, identity basis), room
## for _capacity copies; the MultiMesh is allocated for _allocated.
var _buffer := PackedFloat32Array()
var _capacity := 0
var _allocated := 0


## Makes the (empty) mesh and the MultiMesh that draws it.
func _init() -> void:
	_mesh = RenderingServer.mesh_create()
	_multimesh = RenderingServer.multimesh_create()
	RenderingServer.multimesh_set_mesh(_multimesh, _mesh)


## Frees the MultiMesh and its mesh with the node.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		RenderingServer.free_rid(_multimesh)
		RenderingServer.free_rid(_mesh)


## Adds the instanced draw to this node's canvas item, when there are copies.
func _draw() -> void:
	if instance_count > 0:
		RenderingServer.canvas_item_add_multimesh(get_canvas_item(), _multimesh)


## Makes the shape draw_circle(at, radius, colour) draws for a copy at `at`
## (filled, not antialiased): 64 fan triangles.
func set_disc(radius: float) -> void:
	var key := ["disc", radius]
	if key == _shape_key:
		return
	points.resize(DISC_VERTICES)
	for i in DISC_SEGMENTS + 1:
		points[i] = _disc_rim[i] * radius
	points[DISC_SEGMENTS + 1] = Vector2.ZERO
	indices.resize(DISC_SEGMENTS * 3)
	for i in DISC_SEGMENTS:
		indices[i * 3] = DISC_SEGMENTS + 1
		indices[i * 3 + 1] = i
		indices[i * 3 + 2] = i + 1
	colors.resize(DISC_VERTICES)
	colors.fill(Color.WHITE)
	_shape_key = key
	_upload_shape()


## Makes the shape draw_arc(at, radius, 0, TAU, segments, colour, width,
## antialiased) draws for a copy at `at`: the polyline's strip, then (when
## antialiased) its outer and inner feather strips, each strip turned into
## triangles in strip order; the width is compensated for antialiasing as
## Godot does. A full circle only (the polyline closes into a loop).
func set_ring(radius: float, width: float, segments: int, antialiased: bool) -> void:
	var key := ["ring", radius, width, segments, antialiased]
	if key == _shape_key:
		return
	assert(segments >= 3 and width > 0.0, "ShapeInstances: a ring needs 3 points and a width")
	var arc := _arc_points(radius, segments)
	assert(arc[0].is_equal_approx(arc[segments - 1]), "ShapeInstances: a ring must close")
	var line_width := _compensated_width(width) if antialiased else width
	var strips := _loop_strips(arc, line_width, antialiased)
	points.resize(0)
	colors.resize(0)
	indices.resize(0)
	var feather := false
	for strip: PackedVector2Array in strips:
		var base := points.size()
		points.append_array(strip)
		for k in strip.size():
			colors.append(CLEAR_WHITE if feather and k % 2 == 1 else Color.WHITE)
		for k in strip.size() - 2:
			# GL's strip order: triangle k is (k, k+1, k+2), odd ones swapped.
			var even := k % 2 == 0
			indices.append(base + k if even else base + k + 1)
			indices.append(base + k + 1 if even else base + k)
			indices.append(base + k + 2)
		feather = true
	_shape_key = key
	_upload_shape()


## Forgets the copies: the next commit() draws none unless add()ed again.
func clear() -> void:
	instance_count = 0


## Adds a copy of the shape at `at` (its origin moved there).
func add(at: Vector2) -> void:
	if instance_count == _capacity:
		_grow()
	var base := instance_count * FLOATS_PER_INSTANCE
	_buffer[base + 3] = at.x
	_buffer[base + 7] = at.y
	instance_count += 1


## Where copy `k` (0 <= k < instance_count) is drawn.
func instance_at(k: int) -> Vector2:
	assert(k >= 0 and k < instance_count, "ShapeInstances: no copy %d" % k)
	var base := k * FLOATS_PER_INSTANCE
	return Vector2(_buffer[base + 3], _buffer[base + 7])


## Hands the copies to the MultiMesh (the whole buffer, the visible count)
## and redraws this node, so its canvas item's bounds follow them.
func commit() -> void:
	if _allocated != _capacity:
		RenderingServer.multimesh_allocate_data(_multimesh, _capacity, RenderingServer.MULTIMESH_TRANSFORM_2D)
		_allocated = _capacity
	if _capacity > 0:
		RenderingServer.multimesh_set_buffer(_multimesh, _buffer)
	RenderingServer.multimesh_set_visible_instances(_multimesh, instance_count)
	queue_redraw()


## Doubles the room for copies (8 at first); a new copy's basis is the
## identity, so only its translation is ever written.
func _grow() -> void:
	var grown := maxi(8, _capacity * 2)
	_buffer.resize(grown * FLOATS_PER_INSTANCE)
	for k in range(_capacity, grown):
		var base := k * FLOATS_PER_INSTANCE
		_buffer[base] = 1.0
		_buffer[base + 1] = 0.0
		_buffer[base + 2] = 0.0
		_buffer[base + 4] = 0.0
		_buffer[base + 5] = 1.0
		_buffer[base + 6] = 0.0
	_capacity = grown


## Rebuilds the mesh from points, colors and indices (one surface, so one
## draw call), and works out reach.
func _upload_shape() -> void:
	reach = 0.0
	for p in points:
		reach = maxf(reach, p.length())
	var arrays := []
	arrays.resize(RenderingServer.ARRAY_MAX)
	arrays[RenderingServer.ARRAY_VERTEX] = points
	arrays[RenderingServer.ARRAY_COLOR] = colors
	arrays[RenderingServer.ARRAY_INDEX] = indices
	RenderingServer.mesh_clear(_mesh)
	RenderingServer.mesh_add_surface_from_arrays(_mesh, RenderingServer.PRIMITIVE_TRIANGLES, arrays,
			[], {}, RenderingServer.ARRAY_FLAG_USE_2D_VERTICES)


## draw_arc(Vector2.ZERO, radius, 0, TAU, count, ...)'s points
## (CanvasItem::draw_ellipse_arc in Godot 4.7), in single precision as it
## works them out: theta = (i / (count - 1.0f)) * TAU_f, then
## Vector2(radius * cos theta, radius * sin theta) with the float cos and sin.
static func _arc_points(radius: float, count: int) -> PackedVector2Array:
	var arc := PackedVector2Array()
	arc.resize(count)
	var delta := _f32(TAU)
	var last := _f32(count - 1.0)
	for i in count:
		arc[i] = Vector2.from_angle(_f32(_f32(i / last) * delta)) * radius
	return arc


## canvas_item_add_polyline's strips for the closed polyline `arc` of width
## `width` (already compensated), in Godot 4.7's order: the line's strip,
## then when antialiased the strip out along each vertex's offset (left) and
## the one in (right), their odd vertices the feather's outer edge. Each
## strip has two vertices per arc point.
static func _loop_strips(arc: PackedVector2Array, width: float, antialiased: bool) -> Array[PackedVector2Array]:
	var count := arc.size()
	var first_dir := Vector2.ZERO
	for i in range(1, count):
		first_dir = (arc[i] - arc[i - 1]).normalized()
		if not first_dir.is_zero_approx():
			break
	var last_dir := Vector2.ZERO
	for i in range(count - 1, 0, -1):
		last_dir = (arc[i] - arc[i - 1]).normalized()
		if not last_dir.is_zero_approx():
			break
	var border_size := FEATHER_SIZE
	if width < 1.0:
		border_size = _f32(border_size * width)
	var half_width := _f32(width * 0.5)
	var line := PackedVector2Array()
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	line.resize(count * 2)
	left.resize(count * 2)
	right.resize(count * 2)
	var prev_dir := Vector2.ZERO
	for i in count:
		var dir := prev_dir
		if i < count - 1:
			dir = (arc[i + 1] - arc[i]).normalized()
			if dir.is_zero_approx():
				dir = prev_dir
		if i == 0:
			prev_dir = last_dir
		elif i == count - 1:
			prev_dir = first_dir
		var offset := _edge_offset_clamped(dir, prev_dir)
		var edge := offset * half_width
		var border := offset * border_size
		var pos := arc[i]
		line[i * 2] = pos + edge
		line[i * 2 + 1] = pos - edge
		left[i * 2] = pos + edge
		left[i * 2 + 1] = pos + edge + border
		right[i * 2] = pos - edge
		right[i * 2 + 1] = pos - edge - border
		prev_dir = dir
	if antialiased:
		return [line, left, right]
	return [line]


## compute_polyline_edge_offset_clamped (Godot 4.7): the offset from a
## polyline vertex to its edges, along the bisector of the segments before
## (`prev_dir`) and after (`dir`), lengthened by 1 / sin of their half angle
## (at most 3); in single precision, atan2 and sin the float ones.
static func _edge_offset_clamped(dir: Vector2, prev_dir: Vector2) -> Vector2:
	var length := 1.0
	var bisector := (prev_dir * dir.length() - dir * prev_dir.length()).normalized()
	var angle := Vector2(bisector.dot(prev_dir), bisector.cross(prev_dir)).angle()
	var sin_angle := Vector2.from_angle(angle).y
	if not is_zero_approx(sin_angle) and not dir.is_equal_approx(prev_dir):
		length = clampf(_f32(1.0 / sin_angle), -3.0, 3.0)
	else:
		bisector = dir.orthogonal()
	if bisector.is_zero_approx():
		bisector = dir.orthogonal()
	return bisector * length


## canvas_item_get_compensated_antialiasing_width (Godot 4.7): the line
## width an antialiased polyline actually uses for `width`, its feathers
## making up the rest.
static func _compensated_width(width: float) -> float:
	if width <= 0.0:
		return width
	if width <= FEATHER_SIZE * 2.0 + CMP_EPSILON:
		return _f32(width * 0.5)
	var half_feather := _f32(FEATHER_SIZE * 0.5)
	if width <= FEATHER_SIZE * 4.0 + CMP_EPSILON:
		# Math::remap(width, 2F, 4F, width / 2, width - F / 2), in floats.
		var from := FEATHER_SIZE * 2.0
		var weight := _f32(_f32(width - from) / _f32(FEATHER_SIZE * 4.0 - from))
		var low := _f32(width * 0.5)
		var high := _f32(width - half_feather)
		return _f32(low + _f32(_f32(high - low) * weight))
	return _f32(width - half_feather)


## `value` rounded to single precision, as a float operation in the engine
## rounds it.
static func _f32(value: float) -> float:
	return Vector2(value, 0.0).x


## _disc_rim's points: angle i * TAU / DISC_SEGMENTS rounded to single
## precision as draw_circle()'s float step and product round it (the step is
## a float, times i exact in double, then rounded once), and its cos and sin
## through Vector2.from_angle, which takes a float angle and uses the engine's
## float cos and sin, as draw_circle() does.
static func _unit_disc_rim() -> PackedVector2Array:
	var step := _f32(TAU / DISC_SEGMENTS)
	var rim := PackedVector2Array()
	rim.resize(DISC_SEGMENTS + 1)
	for i in DISC_SEGMENTS + 1:
		rim[i] = Vector2.from_angle(i * step)
	return rim
