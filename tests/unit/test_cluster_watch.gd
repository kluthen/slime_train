extends GutTest
## ClusterWatch (tools/level_check/cluster_watch.gd), level rule 23's measure
## (chunk 24, item 24.7): its samples, the largest cluster, the seconds above
## the limit in all and in a row, the verdict at the hold's edge, and that
## watch() samples only every SAMPLE_TICKS ticks, read only; and that a
## basket's own fill doesn't count, the pile outside its box does (user,
## 2026-10-07).
# @test-link [[req_level_design_rules]]
# @test-link [[rule_no_spot_where_slimes_gather_awake]]

const Support := preload("res://tests/unit/slime_test_support.gd")
const ABOVE := ClusterWatch.LIMIT + 1
## The samples making HOLD_SECONDS.
const HOLD_SAMPLES := int(ClusterWatch.HOLD_SECONDS * Simulation.TICK_RATE) / ClusterWatch.SAMPLE_TICKS


func _samples(watch: ClusterWatch, cluster: int, count: int) -> void:
	for i in count:
		watch.sample(cluster)


func test_the_proposed_limit() -> void:
	assert_eq(ClusterWatch.LIMIT, 20, "rule 23: above 20 slimes")
	assert_eq(ClusterWatch.HOLD_SECONDS, 5.0, "for more than 5 s in a row")
	assert_eq(ClusterWatch.SAMPLE_TICKS, 6, "a sample every 0.1 s")


func test_a_run_never_above_the_limit_passes() -> void:
	var watch := ClusterWatch.new()
	_samples(watch, ClusterWatch.LIMIT, 200)
	_samples(watch, 3, 5)
	assert_eq(watch.largest, ClusterWatch.LIMIT)
	assert_eq(watch.samples, 205)
	assert_eq(watch.above_limit_s(), 0.0, "at the limit is not above it")
	assert_true(watch.passes())
	assert_eq(watch.fields(), "largest_cluster=20 above_limit_s=0.0 longest_above_s=0.0")


func test_above_the_limit_for_the_hold_exactly_passes_and_a_sample_more_fails() -> void:
	var watch := ClusterWatch.new()
	_samples(watch, ABOVE, HOLD_SAMPLES)
	assert_almost_eq(watch.longest_above_s(), ClusterWatch.HOLD_SECONDS, 0.001)
	assert_true(watch.passes(), "5 s in a row is not more than 5 s")
	watch.sample(ABOVE)
	assert_false(watch.passes(), "5.1 s in a row fails")
	assert_string_contains(watch.report(), "rule 23 FAIL")


func test_short_stretches_add_up_but_do_not_fail() -> void:
	var watch := ClusterWatch.new()
	for stretch in 4:
		_samples(watch, 40 + stretch, 30)
		_samples(watch, 5, 1)
	assert_eq(watch.largest, 43)
	assert_almost_eq(watch.above_limit_s(), 12.0, 0.001, "4 stretches of 3 s in all")
	assert_almost_eq(watch.longest_above_s(), 3.0, 0.001, "the longest in a row")
	assert_true(watch.passes())
	assert_string_contains(watch.report(), "rule 23 PASS")


func test_watch_samples_every_sample_ticks_and_changes_nothing() -> void:
	var data := LevelData.new("watch", 1)
	data.loop = LoopData.new("w.loop")
	data.loop.add_segment("w.out", 1, LoopData.OUTGOING, PackedVector2Array([Vector2(-1500, -24), Vector2(1500, -24)]))
	data.loop.add_segment("w.back", 1, LoopData.RETURN, PackedVector2Array([
			Vector2(1500, -24), Vector2(1500, 400), Vector2(-1500, 400), Vector2(-1500, -24)]))
	data.first_slime = {"id": "w.first-slime", "species": "A", "position": Vector2(-1400, -24)}
	var sim := Simulation.new(4)
	sim.slimes.terrain = TerrainSegments.new([Support.floor_polygon()])
	sim.load_level(data)
	for i in 3:
		sim.slimes.create(i, 1, Vector2(40.0 * i, -24), SlimeBodies.TRAIN)
	var watch := ClusterWatch.new()
	for t in 3 * ClusterWatch.SAMPLE_TICKS:
		sim.step()
		var before := sim.state_hash()
		watch.watch(sim)
		assert_eq(sim.state_hash(), before, "read only")
	assert_eq(watch.samples, 3, "a sample every %d ticks" % ClusterWatch.SAMPLE_TICKS)
	assert_gt(watch.largest, 0)
	assert_true(watch.largest >= DebugCounts.largest_cluster(sim.slimes), "the last tick was sampled")


const BASKET_BOX := Rect2(-600, -300, 600, 300)
## A full basket's fill, and a pile outside it: both above the limit.
const FILL := ClusterWatch.LIMIT + 5
## The centres' spacing in a pile: touching by distance, as the debug
## overlay's tests space a row.
const PILE_STEP := 40.0


## A simulation of a level with one basket (box BASKET_BOX, quota FILL) on
## the floor, before any tick (touching is by distance).
func _basket_sim() -> Simulation:
	var data := LevelData.new("watch-basket", 1)
	data.loop = LoopData.new("w.loop")
	data.loop.add_segment("w.out", 1, LoopData.OUTGOING, PackedVector2Array([Vector2(-1500, -24), Vector2(1500, -24)]))
	data.loop.add_segment("w.back", 1, LoopData.RETURN, PackedVector2Array([
			Vector2(1500, -24), Vector2(1500, 400), Vector2(-1500, 400), Vector2(-1500, -24)]))
	data.first_slime = {"id": "w.first-slime", "species": "A", "position": Vector2(-1400, -24)}
	data.add_basket("w.basket", BASKET_BOX, FILL, Vector2(1000, -24))
	var sim := Simulation.new(4)
	sim.slimes.terrain = TerrainSegments.new([Support.floor_polygon()])
	sim.load_level(data)
	return sim


## Piles `count` base slimes in state `state`, 5 a row from x `left` up from
## the floor, each touching its neighbours.
func _pile(sim: Simulation, left: float, count: int, state: int) -> void:
	for i in count:
		sim.slimes.create(i % Species.COUNT, 1, Vector2(left + (i % 5) * PILE_STEP, -24 - (i / 5) * PILE_STEP),
				state)


## The watch of HOLD_SAMPLES + 1 samples of `sim` as it stands, rule 23's
## count: more than the hold in a row when above the limit.
func _held(sim: Simulation) -> ClusterWatch:
	var watch := ClusterWatch.new()
	for i in HOLD_SAMPLES + 1:
		watch.sample(ClusterWatch.largest_cluster(sim))
	return watch


func test_a_full_basket_above_the_limit_does_not_fail_rule_23() -> void:
	var sim := _basket_sim()
	_pile(sim, BASKET_BOX.position.x + 100, FILL, SlimeBodies.IN_BASKET)
	assert_eq(ClusterWatch.basket_boxes(sim.level), [BASKET_BOX] as Array[Rect2])
	assert_eq(DebugCounts.largest_cluster(sim.slimes), FILL, "the debug overlay's count still sees the fill")
	assert_eq(ClusterWatch.largest_cluster(sim), 1,
			"rule 23 leaves out the slimes inside the basket's box: the level's first slime alone")
	var watch := _held(sim)
	assert_true(watch.passes(), "a basket's own fill doesn't count: %s" % watch.report())


func test_a_pile_above_the_limit_outside_the_basket_fails_rule_23() -> void:
	var sim := _basket_sim()
	_pile(sim, BASKET_BOX.end.x + 200, FILL, SlimeBodies.TRAIN)
	assert_eq(ClusterWatch.largest_cluster(sim), FILL, "the pile outside the box counts")
	var watch := _held(sim)
	assert_false(watch.passes(), "rule 23 fails: %s" % watch.report())


func test_a_pile_against_a_full_basket_counts_only_its_own_slimes() -> void:
	var sim := _basket_sim()
	# The fill's right column and the pile's left one a step apart, across
	# the box's right edge: one cluster for the overlay.
	_pile(sim, BASKET_BOX.end.x - 5 * PILE_STEP, FILL, SlimeBodies.IN_BASKET)
	_pile(sim, BASKET_BOX.end.x, FILL, SlimeBodies.TRAIN)
	assert_eq(DebugCounts.largest_cluster(sim.slimes), 2 * FILL, "the overlay: one cluster, fill and pile")
	assert_eq(ClusterWatch.largest_cluster(sim), FILL, "rule 23: the pile outside the box alone")


func test_without_a_level_rule_23_counts_as_the_overlay() -> void:
	assert_true(ClusterWatch.basket_boxes(null).is_empty())
	var sim := Simulation.new(4)
	sim.slimes.terrain = TerrainSegments.new([Support.floor_polygon()])
	_pile(sim, 0, FILL, SlimeBodies.TRAIN)
	assert_eq(ClusterWatch.largest_cluster(sim), DebugCounts.largest_cluster(sim.slimes))
	assert_eq(ClusterWatch.largest_cluster(sim), FILL)
