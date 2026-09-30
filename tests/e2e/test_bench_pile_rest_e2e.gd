extends GutTest
## tools/bench_level.gd's stress-still lead-in (chunk 22, D131): the pile
## rest detection (tools/bench_level/pile_rest.gd) on the test level's
## stress-still fixture, loaded and stepped the way the bench loads and steps
## it (its save, the camera where the fixture puts it, off-screen simulation
## on, the view following the camera before each tick). The pile rests
## within the bench's bound (about 410 ticks since chunk 19), RESTING at the
## tick found; with too small a bound the detection says NEVER.

const PILE_REST := preload("res://tools/bench_level/pile_rest.gd")
const BENCH := preload("res://tools/bench_level.gd")
const SEED := 909
## The rest tick found must be in this open range: the pile doesn't rest at
## once (it settles for seconds), and rests within the bench's bound.
const RESTS_AFTER := 300


## The stress-still fixture as the bench loads it (bench_level.gd's
## _from_fixture): its save on the test level, the camera where the fixture
## puts it, off-screen simulation on.
func _stress_still() -> Simulation:
	var level: Level = load(LevelCatalog.scene_path(LevelCatalog.DEFAULT_ID)).instantiate()
	autofree(level)
	assert_eq(level.build(), PackedStringArray(), "the test level builds")
	var loaded := TestMode.load_fixture("stress-still")
	assert_true(loaded["ok"], str(loaded["error"]))
	var sim := Simulation.from_save(loaded["save"], level.data, SlimeWorld.terrain_from(level), SEED)
	assert_not_null(sim, "stress-still loads on the test level")
	assert_true(loaded["camera"] is Vector2, "stress-still puts the camera at a level point")
	sim.camera.start(level.data.loop, sim.train.open_gates, loaded["camera"])
	sim.offscreen.enabled = true
	sim.hint.world_shown(sim.tick)
	return sim


## One tick as the bench runs it: the view follows the camera first.
func _step(sim: Simulation) -> void:
	sim.camera.apply_to(sim.view, ScreenView.DEFAULT_SIZE)
	sim.step()


# @test-link [[req_platform_and_performance_targets]]
func test_stress_still_pile_rests_within_the_bench_bound_and_is_resting_then() -> void:
	var sim := _stress_still()
	var pile: Array[int] = PILE_REST.pile_of(sim)
	assert_eq(pile.size(), 140, "the pile: the 140 slimes asleep for the night in the bowl")
	assert_false(PILE_REST.rests(sim, pile), "loaded, the pile doesn't rest yet")
	var rested_at: int = PILE_REST.ticks_to_rest(sim, pile, BENCH.REST_WITHIN, _step.bind(sim))
	gut.p("bench stress-still: the pile rests %d ticks after loading" % rested_at)
	assert_between(rested_at, RESTS_AFTER + 1, BENCH.REST_WITHIN - 1, "rests within (%d, %d)" % [RESTS_AFTER,
			BENCH.REST_WITHIN])
	for slime_id in pile:
		assert_eq(sim.slimes.calm_of(slime_id), SlimeBodies.RESTING, "slime %d resting at the tick found" % slime_id)


# @test-link [[req_platform_and_performance_targets]]
func test_a_pile_not_resting_within_the_bound_is_never() -> void:
	var sim := _stress_still()
	var pile: Array[int] = PILE_REST.pile_of(sim)
	var loaded_at := sim.tick
	assert_eq(PILE_REST.ticks_to_rest(sim, pile, 10, _step.bind(sim)), PILE_REST.NEVER,
			"10 ticks after loading, the pile still settles")
	assert_eq(sim.tick - loaded_at, 10, "it stepped exactly the bound")
