extends GutTest
## TapFeedback (src/taps/tap_feedback.gd) draws each slime's eye only when
## the slime can be seen (SlimeRenderer.is_seen): not parked and on the
## shown part of the world, give or take its reach. The eyes of one radius
## are one instanced draw (ShapeInstances, each eye the disc draw_circle()
## draws), and it redraws only when what it draws may have changed. Drawing
## only: the simulation doesn't change.

const SHOWN := Rect2(0, 0, 1000, 600)


func test_only_seen_slimes_get_an_eye() -> void:
	var slimes := SlimeBodies.new(Rng.new(3))
	var near := slimes.create(0, 1, Vector2(500, 300))
	var edge := slimes.create(1, 2, Vector2(-10, 300))
	var far := slimes.create(2, 1, Vector2(5000, 300))
	var parked := slimes.create(3, 1, Vector2(600, 300))
	slimes.park(parked)
	var eyed := TapFeedback.eyed_slimes(slimes, SHOWN)
	assert_true(slimes.index_of(near) in eyed)
	assert_true(slimes.index_of(edge) in eyed, "a slime straddling the edge keeps its eye")
	assert_false(slimes.index_of(far) in eyed, "off the view")
	assert_false(slimes.index_of(parked) in eyed, "parked")
	assert_eq(eyed.size(), 2)


func test_no_slimes_no_eyes() -> void:
	assert_eq(TapFeedback.eyed_slimes(SlimeBodies.new(Rng.new(3)), SHOWN).size(), 0)


## The eye groups (ShapeInstances children) of `feedback`, by eye radius
## (single precision: a disc's first rim point is (radius, 0)).
func _eye_groups(feedback: TapFeedback) -> Dictionary:
	var out := {}
	for child in feedback.get_children():
		if child is ShapeInstances:
			out[(child as ShapeInstances).points[0].x] = child
	return out


# @test-link [[req_platform_and_performance_targets]]
func test_eyes_of_one_radius_share_one_instanced_draw() -> void:
	var feedback: TapFeedback = add_child_autofree(TapFeedback.new())
	var sim := Simulation.new(3)
	var small := [sim.slimes.create(0, 1, Vector2(100, 100)), sim.slimes.create(1, 1, Vector2(300, 100))]
	var middle := sim.slimes.create(2, 2, Vector2(500, 100))
	var big := sim.slimes.create(0, 3, Vector2(700, 200))
	feedback.simulation = sim
	await wait_process_frames(2)
	var groups := _eye_groups(feedback)
	assert_eq(groups.size(), 3, "one draw per slime size's eye radius")
	var expected := {}
	for slime_id: int in small + [middle, big]:
		var r := sim.slimes.radius_of(slime_id)
		var at := sim.slimes.centre_of(slime_id) + Vector2.RIGHT * r * TapFeedback.EYE_OUT + Vector2(0.0, -r * 0.2)
		var radius := r * TapFeedback.EYE_SIZE
		if not expected.has(radius):
			expected[radius] = []
		expected[radius].append(at)
	for radius: float in expected:
		var group: ShapeInstances = groups[PackedFloat32Array([radius])[0]]
		assert_eq(group.self_modulate, TapFeedback.EYE_COLOR)
		assert_eq(group.instance_count, expected[radius].size(), "eyes of radius %s" % radius)
		for k in group.instance_count:
			assert_eq(group.instance_at(k), expected[radius][k], "in slime order")
	sim.slimes.translate(big, Vector2(5000, 0))
	await wait_process_frames(2)
	groups = _eye_groups(feedback)
	assert_eq(groups.size(), 3, "a radius with no eye left keeps its (empty) draw")
	var counts := groups.values().map(func(g: ShapeInstances) -> int: return g.instance_count)
	counts.sort()
	assert_eq(counts, [0, 1, 2], "the big slime went off the view")


# @test-link [[req_platform_and_performance_targets]]
func test_redraws_only_when_what_it_draws_may_have_changed() -> void:
	var feedback: TapFeedback = add_child_autofree(TapFeedback.new())
	var sim := Simulation.new(3)
	var slime := sim.slimes.create(0, 1, Vector2(100, 100))
	feedback.simulation = sim
	assert_true(feedback.refresh(), "the first frame draws")
	assert_false(feedback.refresh(), "nothing changed: the picture stays")
	sim.tick += 1
	assert_true(feedback.refresh(), "a tick: slimes, ripples and the hint may have moved")
	assert_false(feedback.refresh())
	sim.slimes.translate(slime, Vector2(5, 0))
	assert_true(feedback.refresh(), "a slime moved between ticks (the debug tools)")
	assert_false(feedback.refresh())
	sim.view.zoom *= 2.0
	assert_true(feedback.refresh(), "the view zoomed")
	feedback.simulation = Simulation.new(3)
	assert_true(feedback.refresh(), "another simulation")
	assert_false(feedback.refresh())
	feedback.simulation = sim
	await wait_process_frames(2)
	assert_false(feedback.refresh(), "drawn in a real frame, nothing new since")
