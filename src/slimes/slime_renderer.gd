class_name SlimeRenderer
extends Node2D
## Draws the slime bodies (a SlimeBodies) every frame. It only reads them:
## drawing never feeds back into the simulation. Place it at the world origin
## (the bodies' points are in world coordinates), above the terrain.
##
## Each ring becomes a triangle fan (ring points around a centre vertex) plus
## a skirt: a strip out to SKIRT px beyond the ring, where the field falls
## from 1 to 0. Only the slimes that can be seen are drawn (is_seen(): not
## parked, and on the part of the world the viewport shows, give or take
## their reach). The painters get a compact vertex array of those slimes
## only (ring points, skirt points, centres), rebuilt when the bodies moved;
## the colours and the painters' index arrays when the seen slimes change or
## the slimes do (SlimeBodies.topology_version). A frame where nothing drawn
## changed hands over nothing: the canvas items keep their last triangles.
## Each painter adds its triangles itself, on every redraw of its canvas item
## (its `draw` signal): the renderer's own when it hands new ones over, and
## the engine's (a viewport resize clears every canvas item in it), which so
## paints the same picture again.
##
## BLEND (the spike's technique, the default): the fields are painted into two
##   SubViewports at `field_scale` of the screen's resolution, one species per
##   colour channel (A-C, D-F), then a full-screen composite thresholds them:
##   same-species slimes that touch melt into one blob, species meet at a seam.
## DIRECT (the cheap fallback, for headless runs and debugging): one mesh,
##   each ring drawn on its own in its species colour with a soft edge.
##
## It draws the state of the last tick (no interpolation between ticks).

const BLEND := 0
const DIRECT := 1

const FIELD_SHADER := preload("res://src/slimes/slime_field.gdshader")
const BLEND_SHADER := preload("res://src/slimes/slime_blend.gdshader")
const DIRECT_SHADER := preload("res://src/slimes/slime_direct.gdshader")
## The skirt's width: the visible edge sits halfway, SlimeBodies.EDGE beyond
## the ring.
const SKIRT := SlimeBodies.EDGE * 2.0
const ONE_HOT: Array[Color] = [Color(1, 0, 0), Color(0, 1, 0), Color(0, 0, 1)]
## How far a slime's centre may be off the shown rect and the slime still be
## drawn, in shares of its ring radius, plus the skirt: a ring point is never
## that far from its centre, however squashed, so nothing pops at the edges.
const CULL_REACH := 2.0

var draw_mode := BLEND:
	set(value):
		if value != draw_mode:
			draw_mode = value
			_pipeline_dirty = true
			_teardown()
## The bodies drawn, or null for none.
var bodies: SlimeBodies = null:
	set(value):
		bodies = value
		_topology = -1
## Resolution of the field viewports relative to the screen (BLEND).
var field_scale := 0.5
## The composite rectangle (BLEND), or null.
var composite: ColorRect = null
## The real time its per-frame drawing (_process) took, microseconds, summed
## until the debug perf log takes it (and sets it back to 0); nothing else
## reads it. Always counted: two clock reads a frame.
# @spec-link [[req_platform_and_performance_targets]]
var frame_cost_usec := 0

var _pipeline_dirty := true
var _topology := -1
var _painters: Array[Node2D] = []
var _painter_indices: Array[PackedInt32Array] = []
var _field_views: Array[SubViewport] = []
## Every point's colour in the full layout (n ring points, n skirt points,
## one centre per slime), rebuilt with the topology; _colors is cut from it.
var _all_colors := PackedColorArray()
## The colours handed to the painters, in the compact layout of _verts.
var _colors := PackedColorArray()
## The vertices handed to the painters, compact: the seen slimes' ring
## points (slime order), then their skirt points, then their centres.
var _verts := PackedVector2Array()
var _vertex_count := 0
var _drawn_count := 0
## Which slimes are drawn (1 per slime index, is_seen()).
var _seen := PackedByteArray()
## The next seen mask, filled in place and swapped with _seen when it differs.
# @spec-link [[req_platform_and_performance_targets]]
var _seen_next := PackedByteArray()
## The seen slimes' indices, in slime order, and where each one's ring
## points start in _verts.
# @spec-link [[req_platform_and_performance_targets]]
var _seen_slimes := PackedInt32Array()
var _seen_ring_start := PackedInt32Array()
## The seen slimes' point ranges in bodies.pos, adjacent ones joined: start,
## end, start, end...; how many ring points they hold in all.
# @spec-link [[req_platform_and_performance_targets]]
var _seen_runs := PackedInt32Array()
var _seen_points := 0
## What the painters' triangles were last built from: copies of the bodies'
## pos, calm and centre (the seen mask's and the vertices' inputs).
# @spec-link [[req_platform_and_performance_targets]]
var _drawn_pos := PackedVector2Array()
var _drawn_calm := PackedByteArray()
var _drawn_centre := PackedVector2Array()
## The screen the field viewports, the composite and the seen mask last
## followed: the viewport's canvas and final transforms, size and visible rect.
# @spec-link [[req_platform_and_performance_targets]]
var _screen_canvas := Transform2D()
var _screen_final := Transform2D()
var _screen_size := Vector2i(-1, -1)
var _screen_rect := Rect2()
var _screen_field_scale := -1.0
var _upload_count := 0
var _paint_count := 0

## BLEND on a display, DIRECT when headless (nothing is seen, so the cheapest).
static func default_mode() -> int:
	return DIRECT if DisplayServer.get_name() == "headless" else BLEND


## Vertices drawn last frame: ring points, skirt points and one centre per
## slime drawn.
func vertex_count() -> int:
	return _vertex_count


## Slimes drawn last frame (the seen ones, is_seen()).
func drawn_count() -> int:
	return _drawn_count


## The world rect `viewport` shows: its visible rect through its canvas
## transform (the camera).
static func shown_rect(viewport: Viewport) -> Rect2:
	return viewport.get_canvas_transform().affine_inverse() * viewport.get_visible_rect()


## Whether slime index `s` of `slimes` can be seen on world rect `shown`: not
## parked (Offscreen: off screen, not simulated), and its centre within
## CULL_REACH of its ring radius plus the skirt of `shown`, so a slime
## straddling the edge is drawn.
static func is_seen(slimes: SlimeBodies, s: int, shown: Rect2) -> bool:
	if slimes.calm[s] == SlimeBodies.PARKED:
		return false
	return shown.grow(slimes.ring_radius[s] * CULL_REACH + SKIRT).has_point(slimes.centre[s])


## The field viewports (two in BLEND, none in DIRECT).
func field_viewports() -> Array[SubViewport]:
	return _field_views.duplicate()


## The vertices last handed to the painters (a copy): the seen slimes' ring
## points in slime order, then their skirt points, then their centres.
func painted_vertices() -> PackedVector2Array:
	return _verts.duplicate()


## Painter `painter`'s triangles as last handed over, corner by corner in
## draw order (three per triangle); painter 0 is species A-C in BLEND.
func painted_triangles(painter: int) -> PackedVector2Array:
	var corners := PackedVector2Array()
	for i in _painter_indices[painter]:
		corners.append(_verts[i])
	return corners


## The colours of painted_triangles(`painter`)'s corners, in the same order.
func painted_colors(painter: int) -> PackedColorArray:
	var colors := PackedColorArray()
	for i in _painter_indices[painter]:
		colors.append(_colors[i])
	return colors


## How many times the painters were handed new triangles (a frame where
## nothing drawn changed hands over nothing: their last picture stays).
# @spec-link [[req_platform_and_performance_targets]]
func upload_count() -> int:
	return _upload_count


## How many times a painter's canvas item was given its triangles (_paint()):
## once per redraw of a painter that has some, the engine's redraws included.
# @spec-link [[req_platform_and_performance_targets]]
func paint_count() -> int:
	return _paint_count


## Draws this frame's slimes (_render_frame()), adding the time it took to
## frame_cost_usec.
# @spec-link [[req_platform_and_performance_targets]]
func _process(_delta: float) -> void:
	var start_usec := Time.get_ticks_usec()
	_render_frame()
	frame_cost_usec += Time.get_ticks_usec() - start_usec


## This frame's drawing: builds the pipeline when due, follows the screen
## when it changed, then redoes only what the change reaches. The painters'
## canvas items keep their last triangles, in world coordinates, so:
## - nothing changed (no tick, no move, same screen): nothing is done;
## - only the screen changed: the seen mask is redone, the triangles only if
##   the seen slimes changed;
## - the bodies moved: the vertices are rebuilt and handed over again.
# @spec-link [[req_platform_and_performance_targets]]
func _render_frame() -> void:
	if _pipeline_dirty:
		_build_pipeline()
	if bodies == null:
		_clear()
		return
	var topology_changed := bodies.topology_version != _topology
	if topology_changed:
		_rebuild_topology()
	var viewport := get_viewport()
	var screen_changed := _screen_changed(viewport)
	if screen_changed:
		_follow_screen(viewport)
	var moved := bodies.pos != _drawn_pos
	var seen_inputs_changed := moved or bodies.calm != _drawn_calm or bodies.centre != _drawn_centre
	if not (topology_changed or screen_changed or seen_inputs_changed):
		return
	if seen_inputs_changed:
		_drawn_calm = bodies.calm.duplicate()
		_drawn_centre = bodies.centre.duplicate()
	_fill_seen(shown_rect(viewport))
	var seen_changed := topology_changed or _seen_next != _seen
	if seen_changed:
		var swap := _seen
		_seen = _seen_next
		_seen_next = swap
		_rebuild_layout()
	if moved or seen_changed:
		_drawn_pos = bodies.pos.duplicate()
		_draw_bodies()


func _teardown() -> void:
	for painter in _painters:
		painter.queue_free()
	for view in _field_views:
		view.queue_free()
	if composite != null:
		composite.queue_free()
	_painters.clear()
	_painter_indices.clear()
	_field_views.clear()
	composite = null


func _build_pipeline() -> void:
	_teardown()
	_pipeline_dirty = false
	_topology = -1
	_screen_size = Vector2i(-1, -1)
	if draw_mode == DIRECT:
		_painters.append(_new_painter(DIRECT_SHADER, self))
		return
	var palette := PackedVector3Array()
	for c in Species.COLORS:
		palette.append(Vector3(c.r, c.g, c.b))
	for group in 2:
		var view := SubViewport.new()
		view.name = "Field%d" % group
		view.transparent_bg = true
		view.disable_3d = true
		view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(view)
		_field_views.append(view)
		_painters.append(_new_painter(FIELD_SHADER, view))
	composite = ColorRect.new()
	composite.name = "Composite"
	composite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = BLEND_SHADER
	material.set_shader_parameter("field_a", _field_views[0].get_texture())
	material.set_shader_parameter("field_b", _field_views[1].get_texture())
	material.set_shader_parameter("palette", palette)
	composite.material = material
	add_child(composite)


func _new_painter(shader: Shader, parent: Node) -> Node2D:
	var painter := Node2D.new()
	painter.name = "Painter"
	var material := ShaderMaterial.new()
	material.shader = shader
	painter.material = material
	painter.draw.connect(_paint.bind(painter))
	parent.add_child(painter)
	return painter


## Adds `painter`'s current triangles (its index array into _verts and
## _colors) to its canvas item. Run on its `draw` signal, inside each redraw
## of it, after the engine cleared the canvas item: the renderer's redraws
## (_draw_bodies(), _clear()) and the engine's own (a viewport resize), so the
## canvas item always holds the last picture. Nothing for a painter with no
## triangles or no longer in the pipeline (torn down, not yet freed). Its time
## is added to frame_cost_usec.
# @spec-link [[req_platform_and_performance_targets]]
func _paint(painter: Node2D) -> void:
	var start_usec := Time.get_ticks_usec()
	var i := _painters.find(painter)
	if i >= 0 and i < _painter_indices.size() and not _painter_indices[i].is_empty():
		RenderingServer.canvas_item_add_triangle_array(painter.get_canvas_item(), _painter_indices[i], _verts, _colors)
		_paint_count += 1
	frame_cost_usec += Time.get_ticks_usec() - start_usec


## Whether `viewport`'s screen differs from the one last followed
## (_follow_screen()): its canvas or final transform, size, visible rect, or
## field_scale.
# @spec-link [[req_platform_and_performance_targets]]
func _screen_changed(viewport: Viewport) -> bool:
	return (viewport.get_canvas_transform() != _screen_canvas or viewport.get_final_transform() != _screen_final
			or viewport.size != _screen_size or viewport.get_visible_rect() != _screen_rect
			or field_scale != _screen_field_scale)


## Keeps the field viewports and the composite (BLEND; none in DIRECT) on
## the visible part of the world: same world-to-screen mapping as
## `viewport`, at field_scale resolution. Records the screen followed.
func _follow_screen(viewport: Viewport) -> void:
	var screen := viewport.get_canvas_transform()
	_screen_canvas = screen
	_screen_final = viewport.get_final_transform()
	_screen_size = viewport.size
	_screen_rect = viewport.get_visible_rect()
	_screen_field_scale = field_scale
	var field_size := Vector2i((Vector2(viewport.size) * field_scale).round().max(Vector2.ONE))
	var to_field := Transform2D().scaled(Vector2(field_scale, field_scale)) * _screen_final * screen
	for view in _field_views:
		if view.size != field_size:
			view.size = field_size
		view.canvas_transform = to_field
	if composite != null:
		var to_world := screen.affine_inverse()
		composite.position = to_world * Vector2.ZERO
		composite.size = _screen_rect.size * to_world.get_scale()


## Every point's colour in the full layout (_all_colors), rebuilt when
## slimes appear, go or change size; the seen slimes' layout follows
## (_rebuild_layout(), from _render_frame()).
func _rebuild_topology() -> void:
	_topology = bodies.topology_version
	var n := bodies.pos.size()
	_all_colors.resize(n * 2 + bodies.slime_count)
	for s in bodies.slime_count:
		var sp: int = bodies.species[s]
		var c: Color = Species.color(sp) if draw_mode == DIRECT else ONE_HOT[sp % 3]
		var f: int = bodies.first[s]
		for j in range(f, f + bodies.npts[s]):
			_all_colors[j] = Color(c, 1.0)
			_all_colors[n + j] = Color(c, 0.0)
		_all_colors[2 * n + s] = Color(c, 1.0)


## Fills _seen_next: 1 for each slime index that can be seen on world rect
## `shown`, else 0. The same test as is_seen(), inlined (the call per slime
## cost more than the test); the buffer is reused frame to frame.
# @spec-link [[req_platform_and_performance_targets]]
func _fill_seen(shown: Rect2) -> void:
	var count := bodies.slime_count
	if _seen_next.size() != count:
		_seen_next.resize(count)
	var calm := bodies.calm
	var radius := bodies.ring_radius
	var centre := bodies.centre
	for s in count:
		if calm[s] == SlimeBodies.PARKED:
			_seen_next[s] = 0
		else:
			_seen_next[s] = 1 if shown.grow(radius[s] * CULL_REACH + SKIRT).has_point(centre[s]) else 0


## The compact layout of the seen slimes (_seen): their list, their point
## runs, where each one's ring starts, the colours cut from _all_colors, and
## the painters' index arrays (one for every species in DIRECT, species
## group A-C then D-F in BLEND). Each slime's triangles, in slime order:
## per ring point a fan triangle (centre, point, next) then the two skirt
## triangles, as the full layout drew them.
# @spec-link [[req_platform_and_performance_targets]]
func _rebuild_layout() -> void:
	_seen_slimes.clear()
	_seen_ring_start.clear()
	_seen_runs.clear()
	_seen_points = 0
	_vertex_count = 0
	for s in bodies.slime_count:
		if _seen[s] == 0:
			continue
		var f: int = bodies.first[s]
		var count: int = bodies.npts[s]
		_seen_slimes.append(s)
		_seen_ring_start.append(_seen_points)
		if not _seen_runs.is_empty() and _seen_runs[_seen_runs.size() - 1] == f:
			_seen_runs[_seen_runs.size() - 1] = f + count
		else:
			_seen_runs.append_array([f, f + count])
		_seen_points += count
		_vertex_count += count * 2 + 1
	_drawn_count = _seen_slimes.size()
	_cut_colors()
	var group_a := PackedInt32Array()
	var group_b := PackedInt32Array()
	for k in _seen_slimes.size():
		var s := _seen_slimes[k]
		if draw_mode == DIRECT or bodies.species[s] / 3 == 0:
			_append_indices(group_a, k)
		else:
			_append_indices(group_b, k)
	_painter_indices.clear()
	_painter_indices.append(group_a)
	if draw_mode == BLEND:
		_painter_indices.append(group_b)


## _colors for the compact layout: the seen runs' ring colours, their skirt
## colours, then each seen slime's centre colour.
# @spec-link [[req_platform_and_performance_targets]]
func _cut_colors() -> void:
	var n := bodies.pos.size()
	_colors = PackedColorArray()
	for skirt in [0, n]:
		for r in range(0, _seen_runs.size(), 2):
			_colors.append_array(_all_colors.slice(skirt + _seen_runs[r], skirt + _seen_runs[r + 1]))
	for s in _seen_slimes:
		_colors.append(_all_colors[2 * n + s])


## Appends to `indices` the fan inside seen slime `k`'s ring and the quad
## strip of its skirt, in the compact layout.
# @spec-link [[req_platform_and_performance_targets]]
func _append_indices(indices: PackedInt32Array, k: int) -> void:
	var count: int = bodies.npts[_seen_slimes[k]]
	var ring: int = _seen_ring_start[k]
	var m := _seen_points
	var c := 2 * m + k
	var w := indices.size()
	indices.resize(w + count * 9)
	for i in count:
		var a := ring + i
		var b := ring + (i + 1) % count
		indices[w] = c
		indices[w + 1] = a
		indices[w + 2] = b
		indices[w + 3] = a
		indices[w + 4] = m + a
		indices[w + 5] = m + b
		indices[w + 6] = a
		indices[w + 7] = m + b
		indices[w + 8] = b
		w += 9


## Rebuilds the compact vertices of the seen slimes (their ring points cut
## from bodies.pos run by run, their skirt points and centres computed) and
## hands each painter its triangles: a redraw, where _paint() adds them.
# @spec-link [[req_platform_and_performance_targets]]
func _draw_bodies() -> void:
	var pos: PackedVector2Array = bodies.pos
	var m := _seen_points
	_verts = PackedVector2Array()
	for r in range(0, _seen_runs.size(), 2):
		_verts.append_array(pos.slice(_seen_runs[r], _seen_runs[r + 1]))
	_verts.resize(2 * m + _seen_slimes.size())
	for k in _seen_slimes.size():
		var s := _seen_slimes[k]
		var f: int = bodies.first[s]
		var last: int = f + bodies.npts[s] - 1
		var skirt: int = m + _seen_ring_start[k] - f
		var pp: Vector2 = pos[last]
		var cur: Vector2 = pos[f]
		var c := Vector2.ZERO
		for j in range(f, last + 1):
			var nx: Vector2 = pos[j + 1] if j < last else pos[f]
			var d := nx - pp
			_verts[skirt + j] = cur + Vector2(d.y, -d.x).normalized() * SKIRT
			c += cur
			pp = cur
			cur = nx
		_verts[2 * m + k] = c / bodies.npts[s]
	for painter in _painters:
		painter.queue_redraw()
	_upload_count += 1


## Draws nothing (no bodies): the painters' redraw adds no triangles
## (_paint()); forgets what was drawn, so the next bodies are drawn in full.
func _clear() -> void:
	_vertex_count = 0
	_drawn_count = 0
	_verts = PackedVector2Array()
	_colors = PackedColorArray()
	_painter_indices.clear()
	_seen = PackedByteArray()
	_drawn_pos = PackedVector2Array()
	for painter in _painters:
		painter.queue_redraw()
