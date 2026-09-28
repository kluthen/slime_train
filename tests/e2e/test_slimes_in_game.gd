extends GutTest
## The game root hands the level's terrain to the slime bodies (baked terrain
## segments, O78) and draws the slimes with a SlimeRenderer. A slime placed at
## the first slime's spot in the test level's start basin comes to rest on the
## basin floor.

const MAIN_SCENE := "res://src/main.tscn"


func _boot() -> Node:
	var game: Node = load(MAIN_SCENE).instantiate()
	add_child_autofree(game)
	return game


func test_the_slimes_get_the_level_terrain() -> void:
	var game := _boot()
	var terrain: TerrainSegments = game.simulation.slimes.terrain
	assert_not_null(terrain)
	assert_gt(terrain.segment_count(), 50)
	assert_eq(game.enable_test_mode({"seed": 5, "time_scale": 0}), PackedStringArray())
	assert_eq(game.simulation.slimes.terrain, terrain, "a fresh simulation shares the same static terrain")


func test_a_slime_rests_on_the_start_basin_floor() -> void:
	var game := _boot()
	assert_eq(game.enable_test_mode({"seed": 5, "time_scale": 0}), PackedStringArray())
	var spot: Vector2 = game.level.start_position()
	var slimes: SlimeBodies = game.simulation.slimes
	# The game wakes the first slime on that spot (chunk 6) and places the
	# sleepers (chunk 9): make room. A bedtime-asleep slime falls and rests
	# without hopping (a sleeper doesn't simulate).
	for awake in slimes.ids():
		slimes.remove(awake)
	var slime := slimes.create(0, 1, spot + Vector2(0, -60), SlimeBodies.BEDTIME_ASLEEP)
	game.test_mode.run_ticks(240)
	# The first slime's spot is at a size-1 slime's centre height above the
	# ground (PlaceholderArt.SLIME_RADIUS, 24 px, the drawn radius).
	var centre := slimes.centre_of(slime)
	gut.p("first slime spot %s, slime at rest at %s" % [spot, centre])
	assert_almost_eq(centre.x, spot.x, 4.0)
	assert_almost_eq(centre.y, spot.y, 10.0)
	assert_lt(slimes.velocity_of(slime).length(), 2.0)


func test_the_renderer_follows_the_current_simulation() -> void:
	var game := _boot()
	var renderer: SlimeRenderer = game.slime_renderer
	assert_not_null(renderer)
	assert_eq(renderer.bodies, game.simulation.slimes)
	game.enable_test_mode({"seed": 5, "time_scale": 0})
	assert_eq(renderer.bodies, game.simulation.slimes)
