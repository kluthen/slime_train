extends GutTest
## Crowd detail (Offscreen, SlimeBodies): the more slimes cost physics on a
## tick (calm ACTIVE, not sleepers), the fewer points their rings get:
## detail level 1 from 20, 2 from 30, 3 from 40, back down only 5 below each
## threshold; zoomed out gives at least level 2; pile slimes (in a basket,
## asleep at bedtime) stop at level 2. Only ACTIVE slimes are
## reshaped: a resting pile and a parked slime keep their rings until they
## are simulated again, then take the level on that tick. A save keeps it
## all; same seed, same hash.
##
## The world: a floor whose top is at y = 0 from x = -3000 to 3000, the loop
## along it at a base slime's centre height; the view on (0, -200).
# @test-link [[req_offscreen_simulation]]

const DT := Simulation.TICK_SECONDS
const LOOK := Vector2(0, -200)


func _level() -> LevelData:
	var data := LevelData.new("crowd", 1)
	var loop := LoopData.new("c.loop")
	loop.add_segment("c.loop.out", 1, LoopData.OUTGOING, PackedVector2Array([
			Vector2(-2900, -24), Vector2(2900, -24)]))
	data.loop = loop
	data.first_slime = {"id": "c.first-slime", "species": "A", "position": Vector2(-2800, -24)}
	return data


func _terrain() -> TerrainSegments:
	return TerrainSegments.new([
		PackedVector2Array([Vector2(-3000, 0), Vector2(3000, 0), Vector2(3000, 300), Vector2(-3000, 300)]),
	])


## A simulation on the flat world, off-screen simulation on, no slime.
func _sim(master_seed := 3) -> Simulation:
	var sim := Simulation.new(master_seed)
	sim.slimes.terrain = _terrain()
	sim.load_level(_level())
	for slime_id in sim.slimes.ids():
		sim.slimes.remove(slime_id)
	sim.offscreen.enabled = true
	_look(sim, LOOK)
	return sim


func _look(sim: Simulation, at: Vector2, zoom := 1.0) -> void:
	sim.view.set_to(at, zoom, ScreenView.DEFAULT_SIZE)


## `count` size-1 free slimes in the air over x 0 to 500, on screen, 12 a row.
func _crowd(sim: Simulation, count: int) -> Array[int]:
	var out: Array[int] = []
	for k in count:
		var at := Vector2(20.0 + 50.0 * (k % 12), -60.0 - 50.0 * (k / 12))
		out.append(sim.slimes.create(k % 3, 1, at, SlimeBodies.FREE))
	return out


## Four bedtime-asleep slimes on the floor at x -420, run until they rest.
func _pile(sim: Simulation) -> Array[int]:
	var out: Array[int] = []
	for i in 4:
		out.append(sim.slimes.create(0, 1, Vector2(-486 + 44 * i, -24), SlimeBodies.BEDTIME_ASLEEP))
	sim.run(120)
	for slime_id in out:
		assert_eq(sim.slimes.calm_of(slime_id), SlimeBodies.RESTING, "the pile rests")
	return out


func _points(sim: Simulation, slime_id: int) -> int:
	return sim.slimes.points_of(slime_id).size()


# --- The level choice -----------------------------------------------------------------

func test_points_per_detail_level_and_size() -> void:
	var expected := [[12, 15, 18], [10, 12, 15], [8, 10, 12], [6, 8, 9]]
	for level in 4:
		for size in range(1, 4):
			assert_eq(SlimeBodies.detail_points_for(size, level), expected[level][size - 1],
					"level %d size %d" % [level, size])
	assert_eq(SlimeBodies.LOW_DETAIL, 2, "zoomed out is level 2")
	for size in range(1, 4):
		assert_eq(SlimeBodies.detail_points_for(size, 0), SlimeBodies.points_for(size))


func test_the_crowd_level_rises_at_20_30_40() -> void:
	var cases := [[0, 0], [19, 0], [20, 1], [29, 1], [30, 2], [39, 2], [40, 3], [200, 3]]
	for c in cases:
		assert_eq(Offscreen.crowd_level_for(c[0], 0), c[1], "%d from level 0" % c[0])
	assert_eq(Offscreen.crowd_level_for(45, 1), 3, "several levels up at once")


func test_it_comes_down_only_5_below_each_threshold() -> void:
	var cases := [[1, 16, 1], [1, 15, 0], [2, 26, 2], [2, 25, 1], [3, 36, 3], [3, 35, 2],
			[3, 39, 3], [2, 29, 2], [1, 19, 1], [3, 10, 0], [3, 20, 1]]
	for c in cases:
		assert_eq(Offscreen.crowd_level_for(c[1], c[0]), c[2], "%d at level %d" % [c[1], c[0]])


func test_a_count_wavering_at_a_threshold_never_goes_back_and_forth() -> void:
	var level := 0
	var levels := []
	for count in [19, 20, 19, 20, 18, 21, 16, 20, 30, 29, 26, 30, 40, 38, 36, 40]:
		level = Offscreen.crowd_level_for(count, level)
		levels.append(level)
	assert_eq(levels, [0, 1, 1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3])


# --- The rings ---------------------------------------------------------------------------

func test_a_crowd_of_active_slimes_thins_their_rings() -> void:
	var sim := _sim()
	var few := _crowd(sim, 19)
	sim.run(1)
	assert_eq(sim.offscreen.crowd_level, 0)
	assert_eq(_points(sim, few[0]), 12)
	var more := _crowd(sim, 21)
	sim.run(1)
	assert_eq(sim.offscreen.crowd_level, 3, "40 active slimes")
	for slime_id in few + more:
		assert_eq(sim.slimes.detail_of(slime_id), 3)
		assert_eq(_points(sim, slime_id), 6)
	for slime_id in more.slice(0, 14):
		sim.slimes.remove(slime_id)
	sim.run(1)
	assert_eq(sim.offscreen.crowd_level, 2, "26 active slimes: down from 3 (35) but not from 2 (25)")
	assert_eq(_points(sim, few[0]), 8)


func test_sleepers_resting_and_parked_slimes_are_not_the_crowd() -> void:
	var sim := _sim()
	_pile(sim)
	for k in 10:
		sim.slimes.create(1, 1, Vector2(-300 + 40 * k, -300), SlimeBodies.SLEEPER)
	for k in 10:
		sim.slimes.create(0, 1, Vector2(2500 + 60 * k, -24), SlimeBodies.FREE)
	_crowd(sim, 19)
	sim.run(1)
	assert_eq(sim.slimes.crowd_count(), 19, "only the active free slimes on screen")
	assert_eq(sim.offscreen.crowd_level, 0)


func test_resting_slimes_keep_their_rings_and_rest() -> void:
	var sim := _sim()
	var pile := _pile(sim)
	_crowd(sim, 40)
	sim.run(1)
	assert_eq(sim.offscreen.crowd_level, 3)
	for slime_id in pile:
		assert_eq(sim.slimes.calm_of(slime_id), SlimeBodies.RESTING, "the reshape wakes no pile")
		assert_eq(_points(sim, slime_id), 12, "a resting ring keeps its points")
		assert_eq(sim.slimes.detail_of(slime_id), 0)


## A woken pile slime takes the crowd level on its next tick; the local wake
## (D156) leaves the rest of its pile resting.
# @test-link [[req_offscreen_simulation]]
func test_a_waking_slime_takes_the_level_on_its_next_tick() -> void:
	var sim := _sim()
	var pile := _pile(sim)
	_crowd(sim, 40)
	sim.run(1)
	sim.slimes.wake(pile[0])
	assert_eq(_points(sim, pile[0]), 12, "not before it ticks")
	sim.run(1)
	assert_eq(sim.slimes.detail_of(pile[0]), SlimeBodies.PILE_MAX_DETAIL,
			"it woke and took level 3, as far as a pile goes")
	assert_eq(_points(sim, pile[0]), 8)
	# The local wake (D156): the rest of the pile rests on, rings kept.
	for slime_id in pile.slice(1):
		assert_eq(sim.slimes.calm_of(slime_id), SlimeBodies.RESTING)
		assert_eq(_points(sim, slime_id), 12)


func test_pile_slimes_stop_at_level_2() -> void:
	var sim := _sim()
	var basket := sim.slimes.create(0, 1, Vector2(-400, -24), SlimeBodies.IN_BASKET)
	var asleep := sim.slimes.create(1, 3, Vector2(-500, -60), SlimeBodies.BEDTIME_ASLEEP)
	var crowd := _crowd(sim, 40)
	sim.run(1)
	assert_eq(sim.offscreen.detail_level(), 3)
	assert_eq(_points(sim, crowd[0]), 6)
	assert_eq(_points(sim, basket), 8, "in a basket: level 2")
	assert_eq(_points(sim, asleep), 12, "asleep at bedtime, size 3: level 2")
	sim.slimes.set_state(asleep, SlimeBodies.TRAIN)
	sim.run(1)
	assert_eq(_points(sim, asleep), 9, "no longer a pile slime: level 3")


func test_an_unparked_slime_takes_the_level_on_the_tick_it_comes_back() -> void:
	var sim := _sim()
	var far := sim.slimes.create(0, 1, Vector2(1800, -24), SlimeBodies.FREE)
	_crowd(sim, 40)
	sim.run(1)
	assert_true(sim.slimes.is_parked(far))
	assert_eq(sim.offscreen.crowd_level, 3)
	assert_eq(_points(sim, far), 12, "a parked ring keeps its points")
	# The view moves so that it comes near and most of the crowd is still
	# simulated (between the margins: 36 of 40 and it).
	_look(sim, Vector2(1000, -200))
	sim.run(1)
	assert_false(sim.slimes.is_parked(far))
	assert_eq(sim.offscreen.crowd_level, 3)
	assert_eq(sim.slimes.detail_of(far), 3)
	assert_eq(_points(sim, far), 6)


func test_zoomed_out_gives_at_least_level_2() -> void:
	var sim := _sim()
	var few := _crowd(sim, 5)
	_look(sim, LOOK, 0.7)
	sim.run(1)
	assert_true(sim.offscreen.zoomed_out)
	assert_eq(sim.offscreen.detail_level(), 2)
	assert_eq(_points(sim, few[0]), 8)
	var more := _crowd(sim, 40)
	sim.run(1)
	assert_eq(sim.offscreen.detail_level(), 3, "a crowd zoomed out: the crowd's level")
	assert_eq(_points(sim, few[0]), 6)
	_look(sim, LOOK, 1.0)
	sim.run(1)
	assert_eq(sim.offscreen.detail_level(), 3, "zoomed in, the crowd's level stays")
	for slime_id in more:
		sim.slimes.remove(slime_id)
	_look(sim, LOOK, 0.7)
	sim.run(1)
	assert_eq(sim.offscreen.crowd_level, 0)
	assert_eq(sim.offscreen.detail_level(), 2, "the crowd gone, zoomed out again: level 2")
	assert_eq(_points(sim, few[0]), 8)
	_look(sim, LOOK, 0.9)
	sim.run(1)
	assert_eq(sim.offscreen.detail_level(), 0)
	assert_eq(_points(sim, few[0]), 12)


func test_a_crowd_keeps_its_mass_through_fusion_and_split() -> void:
	var sim := _sim()
	_crowd(sim, 40)
	sim.run(1)
	var a := sim.slimes.create(4, 1, Vector2(-300, -24), SlimeBodies.FREE)
	var b := sim.slimes.create(4, 1, Vector2(-240, -24), SlimeBodies.FREE)
	sim.run(1)
	var merged := sim.slimes.merge(a, b)
	assert_eq(_points(sim, merged), SlimeBodies.detail_points_for(2, 3), "fused at its level")
	var parts := sim.slimes.split(merged)
	sim.run(1)
	for part in parts:
		assert_eq(sim.slimes.size_of(part), 1)
		assert_eq(_points(sim, part), 6, "the parts take the level")


# --- Saves and determinism ------------------------------------------------------------

## A pile resting and a crowd of 42 (level 3, fusing), settled on the floor
## without hops until every slime is supported: a save then holds no slime
## in mid-air (loaded, it would be put down: MidairLanding).
func _busy(master_seed: int) -> Simulation:
	var sim := _sim(master_seed)
	sim.slimes.auto_hops = false
	_pile(sim)
	_crowd(sim, 42)
	sim.run(200)
	for tick in 600:
		if sim.slimes.supported.count(0) == 0:
			return sim
		sim.run(1)
	assert_eq(sim.slimes.supported.count(0), 0, "the crowd settles")
	return sim


# @test-link [[req_persistence_and_saves]]
func test_a_save_keeps_the_crowd_level_and_the_rings() -> void:
	var sim := _busy(8)
	assert_gt(sim.offscreen.crowd_level, 0)
	var text := SaveData.to_text(sim.to_save())
	var copy := Simulation.from_save(JSON.parse_string(text), _level(), _terrain())
	assert_not_null(copy)
	copy.offscreen.enabled = true
	copy.slimes.auto_hops = false
	assert_eq(copy.offscreen.crowd_level, sim.offscreen.crowd_level)
	assert_eq(copy.state_hash(), sim.state_hash(), "the reloaded state")
	sim.run(60)
	copy.run(60)
	assert_eq(copy.state_hash(), sim.state_hash(), "and it goes on the same way")


# @test-link [[req_persistence_and_saves]]
# @test-link [[rule_saves_never_wiped]]
func test_an_old_save_with_low_rings_still_loads() -> void:
	var sim := _sim()
	var few := _crowd(sim, 3)
	_look(sim, LOOK, 0.7)
	sim.run(1)
	var save := sim.to_save()
	for slime in save["slimes"]:
		assert_eq(slime["body"]["detail"], 2)
		slime["body"].erase("detail")
		slime["body"]["low"] = true
	var copy := Simulation.from_save(JSON.parse_string(SaveData.to_text(save)), _level(), _terrain())
	assert_not_null(copy)
	assert_eq(copy.slimes.detail_of(few[0]), 2, "\"low\": true is level 2")
	assert_eq(copy.slimes.points_of(few[0]).size(), 8)


func test_the_same_seed_gives_the_same_hash() -> void:
	assert_eq(_busy(4).state_hash(), _busy(4).state_hash())
