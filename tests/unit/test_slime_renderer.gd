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
