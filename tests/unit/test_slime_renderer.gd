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
