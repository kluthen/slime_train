class_name SlimeRenderer
extends Node2D
## Draws the slime bodies (a SlimeBodies) every frame. It only reads them:
## drawing never feeds back into the simulation. Place it at the world origin
## (the bodies' points are in world coordinates), above the terrain.
##
## Each ring becomes a triangle fan (ring points around a centre vertex) plus
## a skirt: a strip out to SKIRT px beyond the ring, where the field falls
## from 1 to 0. The vertex array (ring points, skirt points, centres) is
## rebuilt every frame; the index and colour arrays only when the slimes
## change (SlimeBodies.topology_version).
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

var _pipeline_dirty := true
var _topology := -1
var _painters: Array[Node2D] = []
var _painter_indices: Array[PackedInt32Array] = []
var _field_views: Array[SubViewport] = []
var _colors := PackedColorArray()
var _verts := PackedVector2Array()
var _vertex_count := 0


## BLEND on a display, DIRECT when headless (nothing is seen, so the cheapest).
static func default_mode() -> int:
	return DIRECT if DisplayServer.get_name() == "headless" else BLEND


## Vertices drawn last frame: ring points, skirt points and one centre per slime.
func vertex_count() -> int:
	return _vertex_count


## The field viewports (two in BLEND, none in DIRECT).
func field_viewports() -> Array[SubViewport]:
	return _field_views.duplicate()


func _process(_delta: float) -> void:
	if _pipeline_dirty:
		_build_pipeline()
	if bodies == null:
		_clear()
		return
	if bodies.topology_version != _topology:
		_rebuild_topology()
	if draw_mode == BLEND:
		_follow_screen()
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
	_follow_screen()


func _new_painter(shader: Shader, parent: Node) -> Node2D:
	var painter := Node2D.new()
	painter.name = "Painter"
	var material := ShaderMaterial.new()
	material.shader = shader
	painter.material = material
	parent.add_child(painter)
	return painter


## Keeps the field viewports and the composite on the visible part of the
## world: same world-to-screen mapping as this node's viewport, at
## field_scale resolution.
func _follow_screen() -> void:
	var viewport := get_viewport()
	if viewport == null:
		return
	var screen := viewport.get_canvas_transform()
	var field_size := Vector2i((Vector2(viewport.size) * field_scale).round().max(Vector2.ONE))
	var to_field := Transform2D().scaled(Vector2(field_scale, field_scale)) * viewport.get_final_transform() * screen
	for view in _field_views:
		if view.size != field_size:
			view.size = field_size
		view.canvas_transform = to_field
	if composite != null:
		var to_world := screen.affine_inverse()
		composite.position = to_world * Vector2.ZERO
		composite.size = viewport.get_visible_rect().size * to_world.get_scale()


## Index and colour arrays, rebuilt when slimes appear, go or change size.
func _rebuild_topology() -> void:
	_topology = bodies.topology_version
	var n := bodies.pos.size()
	_colors.resize(n * 2 + bodies.slime_count)
	for s in bodies.slime_count:
		var sp: int = bodies.species[s]
		var c: Color = Species.color(sp) if draw_mode == DIRECT else ONE_HOT[sp % 3]
		var f: int = bodies.first[s]
		for j in range(f, f + bodies.npts[s]):
			_colors[j] = Color(c, 1.0)
			_colors[n + j] = Color(c, 0.0)
		_colors[2 * n + s] = Color(c, 1.0)
	_painter_indices.clear()
	if draw_mode == DIRECT:
		_painter_indices.append(_indices_for(-1))
	else:
		_painter_indices.append(_indices_for(0))
		_painter_indices.append(_indices_for(1))


## A fan inside each ring and a quad strip for its skirt, for the slimes of
## species group `group` (0: A-C, 1: D-F), or all of them for -1.
func _indices_for(group: int) -> PackedInt32Array:
	var indices := PackedInt32Array()
	var n := bodies.pos.size()
	for s in bodies.slime_count:
		if group >= 0 and bodies.species[s] / 3 != group:
			continue
		var f: int = bodies.first[s]
		var count: int = bodies.npts[s]
		var c: int = 2 * n + s
		for i in count:
			var a := f + i
			var b := f + (i + 1) % count
			indices.append_array([c, a, b, a, n + a, n + b, a, n + b, b])
	return indices


func _draw_bodies() -> void:
	var pos: PackedVector2Array = bodies.pos
	var n := pos.size()
	_verts = pos.duplicate()
	_verts.resize(n * 2 + bodies.slime_count)
	for s in bodies.slime_count:
		var f: int = bodies.first[s]
		var last: int = f + bodies.npts[s] - 1
		var pp: Vector2 = pos[last]
		var cur: Vector2 = pos[f]
		var c := Vector2.ZERO
		for j in range(f, last + 1):
			var nx: Vector2 = pos[j + 1] if j < last else pos[f]
			var d := nx - pp
			_verts[n + j] = cur + Vector2(d.y, -d.x).normalized() * SKIRT
			c += cur
			pp = cur
			cur = nx
		_verts[2 * n + s] = c / bodies.npts[s]
	_vertex_count = _verts.size()
	for i in _painters.size():
		var item := _painters[i].get_canvas_item()
		RenderingServer.canvas_item_clear(item)
		if not _painter_indices[i].is_empty():
			RenderingServer.canvas_item_add_triangle_array(item, _painter_indices[i], _verts, _colors)


func _clear() -> void:
	_vertex_count = 0
	for painter in _painters:
		RenderingServer.canvas_item_clear(painter.get_canvas_item())
