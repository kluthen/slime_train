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
## their reach). The vertex array (ring points, skirt points, centres) is
## refreshed every frame for those slimes only; the colour array and each
## slime's own indices when the slimes change (SlimeBodies.topology_version),
## the painters' index arrays when the seen slimes change.
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

var _pipeline_dirty := true
var _topology := -1
var _painters: Array[Node2D] = []
var _painter_indices: Array[PackedInt32Array] = []
var _field_views: Array[SubViewport] = []
var _colors := PackedColorArray()
var _verts := PackedVector2Array()
var _vertex_count := 0
var _drawn_count := 0
## Each slime's fan and skirt indices (by slime index), rebuilt with the topology.
var _slime_indices: Array[PackedInt32Array] = []
## Which slimes were drawn last frame (1 per slime index, is_seen()).
var _seen := PackedByteArray()


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


func _process(_delta: float) -> void:
	if _pipeline_dirty:
		_build_pipeline()
	if bodies == null:
		_clear()
		return
	var topology_changed := bodies.topology_version != _topology
	if topology_changed:
		_rebuild_topology()
	if draw_mode == BLEND:
		_follow_screen()
	var seen := _seen_mask(shown_rect(get_viewport()))
	if topology_changed or seen != _seen:
		_seen = seen
		_rebuild_indices()
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


## The colour array and each slime's indices, rebuilt when slimes appear, go
## or change size; the painters' indices follow (_rebuild_indices()).
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
	_slime_indices.clear()
	for s in bodies.slime_count:
		_slime_indices.append(_indices_of(s, n))


## A fan inside slime index `s`'s ring and a quad strip for its skirt, for a
## vertex array of `n` ring points (then n skirt points, then the centres).
func _indices_of(s: int, n: int) -> PackedInt32Array:
	var indices := PackedInt32Array()
	var f: int = bodies.first[s]
	var count: int = bodies.npts[s]
	var c: int = 2 * n + s
	for i in count:
		var a := f + i
		var b := f + (i + 1) % count
		indices.append_array([c, a, b, a, n + a, n + b, a, n + b, b])
	return indices


## 1 for each slime index that can be seen on world rect `shown` (is_seen()), else 0.
func _seen_mask(shown: Rect2) -> PackedByteArray:
	var mask := PackedByteArray()
	mask.resize(bodies.slime_count)
	for s in bodies.slime_count:
		mask[s] = 1 if is_seen(bodies, s, shown) else 0
	return mask


## The painters' index arrays for the seen slimes (_seen): one for every
## species in DIRECT, species group A-C then D-F in BLEND.
func _rebuild_indices() -> void:
	var group_a := PackedInt32Array()
	var group_b := PackedInt32Array()
	_drawn_count = 0
	_vertex_count = 0
	for s in bodies.slime_count:
		if _seen[s] == 0:
			continue
		if draw_mode == DIRECT or bodies.species[s] / 3 == 0:
			group_a.append_array(_slime_indices[s])
		else:
			group_b.append_array(_slime_indices[s])
		_drawn_count += 1
		_vertex_count += bodies.npts[s] * 2 + 1
	_painter_indices.clear()
	_painter_indices.append(group_a)
	if draw_mode == BLEND:
		_painter_indices.append(group_b)


## Refreshes the seen slimes' vertices (the others' skirt and centre
## vertices are left stale: no index points at them) and hands each
## painter its triangles.
func _draw_bodies() -> void:
	var pos: PackedVector2Array = bodies.pos
	var n := pos.size()
	_verts = pos.duplicate()
	_verts.resize(n * 2 + bodies.slime_count)
	for s in bodies.slime_count:
		if _seen[s] == 0:
			continue
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
	for i in _painters.size():
		var item := _painters[i].get_canvas_item()
		RenderingServer.canvas_item_clear(item)
		if not _painter_indices[i].is_empty():
			RenderingServer.canvas_item_add_triangle_array(item, _painter_indices[i], _verts, _colors)


func _clear() -> void:
	_vertex_count = 0
	_drawn_count = 0
	for painter in _painters:
		RenderingServer.canvas_item_clear(painter.get_canvas_item())
