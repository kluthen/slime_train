extends GutTest
## SlimeRenderer (src/slimes/): draws the slime bodies from the simulation's
## data every frame, as blended species fields (the spike's technique) or,
## the cheap fallback, as one directly drawn mesh. It only reads the data.


func _bodies() -> SlimeBodies:
	var bodies := SlimeBodies.new(Rng.new(3))
	bodies.create(0, 1, Vector2(100, 100))
	bodies.create(3, 2, Vector2(200, 100))
	bodies.create(5, 3, Vector2(320, 100))
	return bodies


func _renderer(bodies: SlimeBodies, mode: int) -> SlimeRenderer:
	var renderer := SlimeRenderer.new()
	renderer.draw_mode = mode
	renderer.bodies = bodies
	add_child_autofree(renderer)
	return renderer


func test_direct_draw_is_one_mesh_of_every_ring() -> void:
	var bodies := _bodies()
	var renderer := _renderer(bodies, SlimeRenderer.DIRECT)
	await wait_process_frames(2)
	assert_eq(renderer.vertex_count(), bodies.pos.size() * 2 + bodies.slime_count, "ring, skirt and centre")
	assert_eq(renderer.field_viewports().size(), 0)


func test_blend_draws_fields_into_two_viewports() -> void:
	var bodies := _bodies()
	var renderer := _renderer(bodies, SlimeRenderer.BLEND)
	await wait_process_frames(2)
	assert_eq(renderer.field_viewports().size(), 2, "species A-C and D-F")
	assert_not_null(renderer.composite)
	assert_eq(renderer.vertex_count(), bodies.pos.size() * 2 + bodies.slime_count)


func test_switching_modes() -> void:
	var renderer := _renderer(_bodies(), SlimeRenderer.BLEND)
	await wait_process_frames(1)
	renderer.draw_mode = SlimeRenderer.DIRECT
	await wait_process_frames(2)
	assert_eq(renderer.field_viewports().size(), 0)
	assert_null(renderer.composite)


func test_drawing_never_changes_the_simulation() -> void:
	var bodies := _bodies()
	var before := StateHash.of(bodies.dump())
	var positions := bodies.pos.duplicate()
	_renderer(bodies, SlimeRenderer.BLEND)
	await wait_process_frames(3)
	assert_eq(StateHash.of(bodies.dump()), before)
	assert_eq(bodies.pos, positions)


func test_follows_merges_and_splits() -> void:
	var bodies := _bodies()
	var renderer := _renderer(bodies, SlimeRenderer.DIRECT)
	await wait_process_frames(1)
	bodies.split(bodies.ids()[2])
	await wait_process_frames(1)
	assert_eq(renderer.vertex_count(), bodies.pos.size() * 2 + bodies.slime_count)
	assert_eq(bodies.slime_count, 5)


func test_without_bodies_it_draws_nothing() -> void:
	var renderer := _renderer(null, SlimeRenderer.DIRECT)
	await wait_process_frames(2)
	assert_eq(renderer.vertex_count(), 0)


# --- Culling: only the slimes that can be seen are drawn -----------------------

const SHOWN := Rect2(0, 0, 1000, 600)


func _one_slime(at: Vector2, slime_size := 1) -> SlimeBodies:
	var bodies := SlimeBodies.new(Rng.new(3))
	bodies.create(0, slime_size, at)
	return bodies


func test_a_slime_in_the_view_is_seen() -> void:
	assert_true(SlimeRenderer.is_seen(_one_slime(Vector2(500, 300)), 0, SHOWN))


func test_a_parked_slime_is_not_seen_even_in_the_view() -> void:
	var bodies := _one_slime(Vector2(500, 300))
	bodies.park(bodies.ids()[0])
	assert_false(SlimeRenderer.is_seen(bodies, 0, SHOWN))


func test_a_slime_far_off_the_view_is_not_seen() -> void:
	assert_false(SlimeRenderer.is_seen(_one_slime(Vector2(3000, 300)), 0, SHOWN))
	assert_false(SlimeRenderer.is_seen(_one_slime(Vector2(500, -2000)), 0, SHOWN))


func test_a_slime_straddling_the_edge_is_seen() -> void:
	for slime_size in [1, 3]:
		var r := SlimeBodies.ring_radius_for(slime_size)
		for at in [Vector2(-r * 0.9, 300), Vector2(1000 + r * 0.9, 300), Vector2(500, -r * 0.9),
				Vector2(500, 600 + r * 0.9)]:
			assert_true(SlimeRenderer.is_seen(_one_slime(at, slime_size), 0, SHOWN), "size %d at %s" % [slime_size, at])


func test_a_slime_just_beyond_its_reach_is_not_seen() -> void:
	var r := SlimeBodies.ring_radius_for(1)
	var beyond := r * SlimeRenderer.CULL_REACH + SlimeRenderer.SKIRT + 1.0
	assert_false(SlimeRenderer.is_seen(_one_slime(Vector2(-beyond, 300)), 0, SHOWN))


func test_the_shown_rect_is_what_the_viewport_shows() -> void:
	var renderer := _renderer(null, SlimeRenderer.DIRECT)
	var viewport := renderer.get_viewport()
	var shown := SlimeRenderer.shown_rect(viewport)
	var to_screen := viewport.get_canvas_transform()
	assert_almost_eq((to_screen * shown.position).distance_to(Vector2.ZERO), 0.0, 0.01)
	assert_almost_eq((to_screen * shown.end).distance_to(viewport.get_visible_rect().end), 0.0, 0.01)


func _seen_vertices(bodies: SlimeBodies, slimes: Array) -> int:
	var out := 0
	for s in slimes:
		out += bodies.npts[s] * 2 + 1
	return out


func test_only_seen_slimes_are_drawn_in_both_modes() -> void:
	for mode in [SlimeRenderer.DIRECT, SlimeRenderer.BLEND]:
		var bodies := _bodies()
		bodies.create(1, 1, Vector2(100000, 100))
		var parked := bodies.create(2, 1, Vector2(400, 200))
		bodies.park(parked)
		var renderer := _renderer(bodies, mode)
		await wait_process_frames(2)
		var shown := SlimeRenderer.shown_rect(renderer.get_viewport())
		assert_true(shown.has_point(Vector2(400, 200)), "the test's slimes are in the viewport")
		assert_eq(renderer.drawn_count(), 3, "mode %d: the far and the parked slimes are culled" % mode)
		assert_eq(renderer.vertex_count(), _seen_vertices(bodies, [0, 1, 2]))


func test_a_slime_coming_into_view_is_drawn() -> void:
	var bodies := _bodies()
	bodies.create(1, 1, Vector2(100000, 100))
	var renderer := _renderer(bodies, SlimeRenderer.BLEND)
	await wait_process_frames(2)
	assert_eq(renderer.drawn_count(), 3)
	bodies.translate(bodies.ids()[3], Vector2(500 - 100000, 100))
	await wait_process_frames(1)
	assert_eq(renderer.drawn_count(), 4, "the same slimes, a new seen set")
	assert_eq(renderer.vertex_count(), bodies.pos.size() * 2 + bodies.slime_count)


# --- Redraw on change, compact vertices ------------------------------------------

## Slimes 0, 2 and 4 seen; 1 far off the view and 3 parked in it, between
## them, so the compact layout shifts the later slimes.
func _mixed_bodies() -> SlimeBodies:
	var bodies := SlimeBodies.new(Rng.new(3))
	bodies.create(0, 1, Vector2(100, 100))
	bodies.create(1, 1, Vector2(100000, 100))
	bodies.create(3, 2, Vector2(200, 100))
	bodies.park(bodies.create(2, 1, Vector2(400, 200)))
	bodies.create(5, 3, Vector2(320, 100))
	return bodies


## What the full-array drawing painted (every ring point, then every skirt
## point, then every centre; each seen slime's fan and skirt in slime order),
## worked out from `bodies` alone: per painter, [corners, colours].
func _full_layout_picture(bodies: SlimeBodies, seen: Array, mode: int) -> Array:
	var pos := bodies.pos
	var n := pos.size()
	var verts := pos.duplicate()
	verts.resize(n * 2 + bodies.slime_count)
	var colors := PackedColorArray()
	colors.resize(n * 2 + bodies.slime_count)
	for s in bodies.slime_count:
		var sp: int = bodies.species[s]
		var tint: Color = Species.color(sp) if mode == SlimeRenderer.DIRECT else SlimeRenderer.ONE_HOT[sp % 3]
		var f: int = bodies.first[s]
		var count: int = bodies.npts[s]
		var sum := Vector2.ZERO
		for i in count:
			var before: Vector2 = pos[f + (i + count - 1) % count]
			var after: Vector2 = pos[f + (i + 1) % count]
			var d := after - before
			verts[n + f + i] = pos[f + i] + Vector2(d.y, -d.x).normalized() * SlimeRenderer.SKIRT
			sum += pos[f + i]
			colors[f + i] = Color(tint, 1.0)
			colors[n + f + i] = Color(tint, 0.0)
		verts[2 * n + s] = sum / count
		colors[2 * n + s] = Color(tint, 1.0)
	var painters := [[PackedVector2Array(), PackedColorArray()], [PackedVector2Array(), PackedColorArray()]]
	for s in seen:
		var painter: Array = painters[0 if mode == SlimeRenderer.DIRECT or bodies.species[s] / 3 == 0 else 1]
		var f: int = bodies.first[s]
		var count: int = bodies.npts[s]
		for i in count:
			var a := f + i
			var b := f + (i + 1) % count
			for v in [2 * n + s, a, b, a, n + a, n + b, a, n + b, b]:
				painter[0].append(verts[v])
				painter[1].append(colors[v])
	return painters if mode == SlimeRenderer.BLEND else [painters[0]]


# @test-link [[req_platform_and_performance_targets]]
func test_a_frame_where_nothing_changed_hands_nothing_over() -> void:
	for mode in [SlimeRenderer.DIRECT, SlimeRenderer.BLEND]:
		var bodies := _bodies()
		var renderer := _renderer(bodies, mode)
		await wait_process_frames(2)
		var uploads := renderer.upload_count()
		await wait_process_frames(3)
		assert_eq(renderer.upload_count(), uploads, "mode %d: no tick, same view: nothing handed over" % mode)
		bodies.tick(1.0 / 60.0)
		await wait_process_frames(2)
		assert_eq(renderer.upload_count(), uploads + 1, "mode %d: the tick moved them: handed over once" % mode)


# @test-link [[req_platform_and_performance_targets]]
func test_a_view_change_keeping_the_seen_slimes_only_follows_the_screen() -> void:
	var bodies := _bodies()
	var renderer := _renderer(bodies, SlimeRenderer.BLEND)
	await wait_process_frames(2)
	var viewport := renderer.get_viewport()
	var home := viewport.canvas_transform
	var uploads := renderer.upload_count()
	var moved := home.translated(Vector2(7, 3))
	viewport.canvas_transform = moved
	await wait_process_frames(1)
	var followed := renderer.field_viewports()[0].canvas_transform
	viewport.canvas_transform = home
	var scale := Vector2(renderer.field_scale, renderer.field_scale)
	assert_eq(renderer.upload_count(), uploads, "the same slimes seen: their triangles stay")
	assert_eq(followed, Transform2D().scaled(scale) * viewport.get_final_transform() * moved, "the fields follow the view")


# @test-link [[req_platform_and_performance_targets]]
func test_after_a_tick_the_picture_is_the_full_layout_one() -> void:
	for mode in [SlimeRenderer.DIRECT, SlimeRenderer.BLEND]:
		var bodies := _mixed_bodies()
		var renderer := _renderer(bodies, mode)
		await wait_process_frames(2)
		bodies.tick(1.0 / 60.0)
		await wait_process_frames(1)
		assert_eq(renderer.drawn_count(), 3, "mode %d: slimes 0, 2 and 4" % mode)
		var expected := _full_layout_picture(bodies, [0, 2, 4], mode)
		for i in expected.size():
			assert_eq(renderer.painted_triangles(i), expected[i][0], "mode %d painter %d: the same corners" % [mode, i])
			assert_eq(renderer.painted_colors(i), expected[i][1], "mode %d painter %d: the same colours" % [mode, i])


# @test-link [[req_platform_and_performance_targets]]
func test_unseen_slimes_hand_over_no_vertices() -> void:
	var bodies := _mixed_bodies()
	var renderer := _renderer(bodies, SlimeRenderer.BLEND)
	await wait_process_frames(2)
	var painted := renderer.painted_vertices()
	assert_eq(painted.size(), _seen_vertices(bodies, [0, 2, 4]), "the seen slimes' vertices only")
	for s in [1, 3]:
		var f: int = bodies.first[s]
		for j in range(f, f + bodies.npts[s]):
			assert_false(painted.has(bodies.pos[j]), "slime %d's point %d is not handed over" % [s, j])


## The painter nodes of `renderer`: its own in DIRECT, one per field viewport
## in BLEND.
func _painters(renderer: SlimeRenderer) -> Array[Node2D]:
	var out: Array[Node2D] = []
	if renderer.draw_mode == SlimeRenderer.DIRECT:
		out.append(renderer.get_node("Painter"))
	for view in renderer.field_viewports():
		out.append(view.get_node("Painter"))
	return out


## Counts each painter's `draw` emissions (its redraws) in `draws`.
func _count_draws(painters: Array[Node2D], draws: Array[int]) -> void:
	draws.resize(painters.size())
	draws.fill(0)
	for i in painters.size():
		painters[i].draw.connect(func() -> void: draws[i] += 1)


# @test-link [[req_platform_and_performance_targets]]
func test_an_engine_redraw_of_a_painter_paints_its_triangles_again() -> void:
	for mode in [SlimeRenderer.DIRECT, SlimeRenderer.BLEND]:
		var renderer := _renderer(_bodies(), mode)
		await wait_process_frames(2)
		var painters := _painters(renderer)
		var draws: Array[int] = []
		_count_draws(painters, draws)
		var uploads := renderer.upload_count()
		var paints := renderer.paint_count()
		var picture := renderer.painted_triangles(0)
		assert_false(picture.is_empty(), "mode %d: painter 0 has slimes" % mode)
		painters[0].queue_redraw()
		await wait_process_frames(1)
		assert_eq(draws[0], 1, "mode %d: the engine redrew painter 0 (its canvas item cleared)" % mode)
		assert_eq(renderer.paint_count(), paints + 1, "mode %d: its triangles were added again" % mode)
		assert_eq(renderer.painted_triangles(0), picture, "mode %d: the same picture" % mode)
		assert_eq(renderer.upload_count(), uploads, "mode %d: nothing moved: nothing new handed over" % mode)


# @test-link [[req_platform_and_performance_targets]]
func test_a_screen_size_change_in_blend_still_shows_the_slimes() -> void:
	var screen := SubViewport.new()
	screen.size = Vector2i(1000, 600)
	add_child_autofree(screen)
	var renderer := SlimeRenderer.new()
	renderer.draw_mode = SlimeRenderer.BLEND
	renderer.bodies = _bodies()
	screen.add_child(renderer)
	await wait_process_frames(2)
	var painters := _painters(renderer)
	var draws: Array[int] = []
	_count_draws(painters, draws)
	var uploads := renderer.upload_count()
	var paints := renderer.paint_count()
	var pictures := [renderer.painted_triangles(0), renderer.painted_triangles(1)]
	screen.size = Vector2i(800, 500)
	await wait_process_frames(2)
	assert_eq(renderer.field_viewports()[0].size, Vector2i(400, 250), "the fields follow the screen size")
	for i in painters.size():
		assert_false(pictures[i].is_empty(), "painter %d has slimes" % i)
		assert_gt(draws[i], 0, "painter %d was redrawn (its canvas item cleared)" % i)
		assert_eq(renderer.painted_triangles(i), pictures[i], "painter %d: the same picture" % i)
	assert_eq(renderer.paint_count(), paints + draws[0] + draws[1], "every redraw added the triangles again")
	assert_eq(renderer.upload_count(), uploads, "the slimes did not move: nothing new handed over")


# --- The celebration's drawn bounce ----------------------------------------------

## A stand-in for the celebration's double hop (CelebrationHops) whose drawn
## bounce lifts slime `spared` by `lift` px while `lift` is above 0.
class Bounce extends CelebrationHops:
	var spared := -1
	var lift := 0.0

	func bouncing() -> bool:
		return lift > 0.0

	func lift_of(slime_id: int) -> float:
		return lift if slime_id == spared and bouncing() else 0.0


# D147 (6): the renderer lifts the drawn shape (ring, skirt and centre) of a
# slime the celebration spares by its bounce, no other slime's; it hands the
# picture over every frame while the bounce plays, once more when it ends
# (back down), then no more; the bodies are untouched.
# @test-link [[req_level_completion_celebration]]
func test_a_slime_the_celebration_spares_bounces_in_the_drawing_only() -> void:
	for mode in [SlimeRenderer.DIRECT, SlimeRenderer.BLEND]:
		var bodies := _bodies()
		var renderer := _renderer(bodies, mode)
		var burst := Bounce.new()
		burst.spared = bodies.id[1]
		renderer.celebration = burst
		await wait_process_frames(2)
		var flat := renderer.painted_vertices()
		var pos := bodies.pos.duplicate()
		var uploads := renderer.upload_count()
		burst.lift = 10.0
		var frame := Engine.get_process_frames()
		await wait_process_frames(3)
		var frames := Engine.get_process_frames() - frame
		assert_gte(frames, 3)
		assert_eq(renderer.upload_count(), uploads + frames, "mode %d: handed over every frame while it bounces" % mode)
		uploads = renderer.upload_count()
		var m := bodies.pos.size()
		var expected := flat.duplicate()
		for j in range(bodies.first[1], bodies.first[1] + bodies.npts[1]):
			expected[j] += Vector2(0.0, -10.0)
			expected[m + j] += Vector2(0.0, -10.0)
		expected[2 * m + 1] += Vector2(0.0, -10.0)
		assert_eq(renderer.painted_vertices(), expected, "mode %d: slime 1 lifted, ring, skirt and centre" % mode)
		assert_eq(bodies.pos, pos, "mode %d: the bodies untouched" % mode)
		burst.lift = 0.0
		await wait_process_frames(1)
		assert_eq(renderer.upload_count(), uploads + 1, "mode %d: once more when it ends" % mode)
		assert_eq(renderer.painted_vertices(), flat, "mode %d: back down" % mode)
		await wait_process_frames(3)
		assert_eq(renderer.upload_count(), uploads + 1, "mode %d: then nothing handed over" % mode)
