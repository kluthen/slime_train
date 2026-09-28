extends GutTest
## The soft-body solver (SlimeBodies.tick): Verlet with position constraints,
## contacts between rings, and contacts with the baked terrain segments (O78).
## Resting slimes settle, rings push each other apart, and two runs with the
## same seed and the same operations end in the same state. The test bodies are
## bedtime-asleep: simulated but never hopping (a sleeper doesn't simulate).
# @test-link [[req_slime_states]]

const Support := preload("res://tests/unit/slime_test_support.gd")
const DT := 1.0 / 60.0


func _run(bodies: SlimeBodies, ticks: int) -> void:
	for i in ticks:
		bodies.tick(DT)


func _deepest(bodies: SlimeBodies) -> float:
	var worst := 0.0
	for p in bodies.pos:
		worst = maxf(worst, bodies.terrain.depth(p))
	return worst


func test_a_resting_slime_settles_on_a_flat_floor() -> void:
	for size in [1, 2, 3]:
		var bodies := Support.bodies_on_floor()
		var slime := bodies.create(0, size, Vector2(0, -80), SlimeBodies.BEDTIME_ASLEEP)
		_run(bodies, 180)
		var y1 := bodies.centre_of(slime).y
		_run(bodies, 60)
		var y2 := bodies.centre_of(slime).y
		var radius := bodies.radius_of(slime)
		gut.p("size %d: centre y %.2f then %.2f (radius %.1f)" % [size, y1, y2, radius])
		assert_almost_eq(y2, y1, 0.2, "size %d: the height has converged" % size)
		# The ring stays terrain_skin (EDGE) off the ground, so the drawn body
		# (ring + EDGE) rests on it.
		var skin := bodies.terrain_skin
		assert_between(-y2, radius * 0.6 + skin, radius * 1.01 + skin, "size %d: resting on the floor, a little squashed" % size)
		assert_lt(bodies.velocity_of(slime).length(), 2.0, "size %d: at rest" % size)
		assert_lt(_deepest(bodies), 1.0, "size %d: no point sinks into the floor" % size)
		assert_almost_eq(bodies.area_of(slime) / bodies.rest_area_of(slime), 1.0, 0.1, "size %d: keeps its area" % size)
		assert_almost_eq(bodies.centre_of(slime).x, 0.0, 0.5, "size %d: doesn't drift sideways" % size)


func test_a_slime_on_a_curved_slope_settles_in_the_valley() -> void:
	# A valley baked by the Terrain component's own bake (chunk 4).
	var curve := Curve2D.new()
	curve.add_point(Vector2(-500, -300), Vector2.ZERO, Vector2(250, 400))
	curve.add_point(Vector2(500, -300), Vector2(-250, 400))
	curve.add_point(Vector2(500, 200))
	curve.add_point(Vector2(-500, 200))
	var bodies := SlimeBodies.new(Rng.new(1))
	bodies.terrain = TerrainSegments.new([Terrain.bake_polygon(curve, 2.0)])
	var slime := bodies.create(1, 2, Vector2(-330, -260), SlimeBodies.BEDTIME_ASLEEP)
	var moved := 0.0
	for i in 60 * 8:
		bodies.tick(DT)
		moved = maxf(moved, absf(bodies.centre_of(slime).x + 330.0))
	var centre := bodies.centre_of(slime)
	gut.p("settled at %s after moving %.0f px" % [centre, moved])
	assert_gt(moved, 100.0, "it went down the slope")
	assert_lt(absf(centre.x), 40.0, "it came to rest at the bottom")
	assert_lt(bodies.velocity_of(slime).length(), 5.0, "at rest")
	assert_lt(_deepest(bodies), 1.5, "no point sinks into the terrain")
	for p in bodies.points_of(slime):
		assert_lt(p.y, 5.0, "above the valley floor")


func test_a_slime_rests_against_a_wall() -> void:
	var bodies := SlimeBodies.new(Rng.new(1))
	bodies.terrain = TerrainSegments.new(Support.box_polygons(200))
	var slime := bodies.create(0, 1, Vector2(150, -40), SlimeBodies.BEDTIME_ASLEEP)
	bodies.set_velocity(slime, Vector2(600, 0))
	_run(bodies, 240)
	assert_lt(bodies.centre_of(slime).x, 200.0 - bodies.radius_of(slime) * 0.6, "held by the wall")
	assert_lt(_deepest(bodies), 1.0)


func test_contact_between_two_rings_pushes_them_apart() -> void:
	var bodies := SlimeBodies.new(Rng.new(1))
	bodies.gravity = Vector2.ZERO
	var a := bodies.create(0, 1, Vector2(0, 0), SlimeBodies.BEDTIME_ASLEEP)
	var b := bodies.create(1, 1, Vector2(30, 0), SlimeBodies.BEDTIME_ASLEEP)
	bodies.tick(DT)
	assert_true(bodies.touching(a, b), "overlapping rings are in contact")
	_run(bodies, 60)
	var gap := bodies.centre_of(a).distance_to(bodies.centre_of(b))
	assert_gt(gap, 2.0 * SlimeBodies.RING_RADIUS_SIZE_1 - 2.0, "pushed apart")
	var mid := (bodies.centre_of(a) + bodies.centre_of(b)) * 0.5
	assert_almost_eq(mid, Vector2(15, 0), Vector2(1.0, 1.0), "evenly: momentum is kept")
	assert_lt(bodies.centre_of(a).x, 0.0)
	assert_gt(bodies.centre_of(b).x, 30.0)


func test_rings_far_apart_are_not_in_contact() -> void:
	var bodies := SlimeBodies.new(Rng.new(1))
	bodies.gravity = Vector2.ZERO
	var a := bodies.create(0, 1, Vector2(0, 0))
	var b := bodies.create(0, 1, Vector2(300, 0))
	bodies.tick(DT)
	assert_false(bodies.touching(a, b))
	assert_eq(bodies.touching_pairs(), [])


func test_a_small_slime_rests_on_two_big_ones() -> void:
	# In the hollow between two big slimes held by walls. (Balanced on the
	# top of one round slime would be an unstable equilibrium: it rolls off.)
	var bodies := SlimeBodies.new(Rng.new(1))
	# The contact solver itself: the resting-pile rule (chunk 15) would turn
	# the settled pile into walls, and walls are never paired.
	bodies.rest_enabled = false
	bodies.terrain = TerrainSegments.new(Support.box_polygons(76))
	var left := bodies.create(0, 3, Vector2(-38, -40), SlimeBodies.BEDTIME_ASLEEP)
	var right := bodies.create(0, 3, Vector2(38, -40), SlimeBodies.BEDTIME_ASLEEP)
	var small := bodies.create(1, 1, Vector2(0, -130), SlimeBodies.BEDTIME_ASLEEP)
	_run(bodies, 300)
	var top := minf(bodies.centre_of(left).y, bodies.centre_of(right).y)
	assert_lt(bodies.centre_of(small).y, top - bodies.radius_of(left) * 0.6, "on top")
	assert_true(bodies.touching(left, small))
	assert_true(bodies.touching(right, small))
	assert_lt(Support.max_speed(bodies), 3.0)


func test_a_pile_stays_stable() -> void:
	var bodies := SlimeBodies.new(Rng.new(9))
	bodies.terrain = TerrainSegments.new(Support.box_polygons(200))
	for i in 24:
		var size := 1 + i % 3
		bodies.create(i % 6, size, Vector2(-160 + (i % 4) * 100, -60 - 90 * (i / 4)), SlimeBodies.BEDTIME_ASLEEP)
	_run(bodies, 600)
	assert_lt(Support.max_speed(bodies), 20.0, "the pile has come to rest")
	assert_lt(_deepest(bodies), 1.5, "nothing sinks into the terrain")
	for slime in bodies.ids():
		var c := bodies.centre_of(slime)
		assert_true(is_finite(c.x) and is_finite(c.y))
		assert_between(c.x, -200.0, 200.0, "inside the walls")
		assert_lt(c.y, 0.0, "above the floor")
		assert_almost_eq(bodies.area_of(slime) / bodies.rest_area_of(slime), 1.0, 0.15, "slime %d keeps its area" % slime)


func test_same_seed_and_operations_give_the_same_dump() -> void:
	var dumps := []
	for master_seed in [21, 21, 22]:
		var bodies := SlimeBodies.new(Rng.new(master_seed))
		bodies.terrain = TerrainSegments.new(Support.box_polygons(400))
		for i in 10:
			var slime := bodies.create(i % 3, 1 + i % 2, Vector2(-350 + i * 75, -40))
			bodies.set_heading(slime, [-1.0, 0.0, 1.0][i % 3])
		_run(bodies, 240)
		bodies.merge(bodies.ids()[0], bodies.ids()[3])
		bodies.split(bodies.ids()[1])
		_run(bodies, 240)
		dumps.append(StateHash.of(bodies.dump()))
	assert_eq(dumps[0], dumps[1], "same seed and operations")
	assert_ne(dumps[0], dumps[2], "another seed")
