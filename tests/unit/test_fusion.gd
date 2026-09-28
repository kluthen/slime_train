extends GutTest
## Fusion and bumping (src/sim/fusion.gd, wired into Simulation.step): two
## awake slimes of one species whose rings touch for 180 ticks (3 s) in a
## row fuse when their sizes add up to 3 at most, and bump apart otherwise.
## A broken contact starts the count again; different species never count;
## off screen nothing counts; the fused slime keeps the survivor's state.
## Also: what a dip's floor is, the counts in saves, and determinism.
##
## Most tests put two slimes side by side on a flat floor with automatic hops
## off (SlimeBodies.auto_hops), so they rest touching and nothing else
## moves them, and point the view at them by hand (the scene copies the
## camera into Simulation.view every tick; here there is no scene).

# @test-link [[rule_fusion_contact_time]]
# @test-link [[rule_max_size_three]]
# @test-link [[rule_dip_may_nudge_fusion]]

const Support := preload("res://tests/unit/slime_test_support.gd")
const TICKS := Fusion.CONTACT_TICKS


func _sim(master_seed := 11) -> Simulation:
	var sim := Simulation.new(master_seed)
	sim.slimes.terrain = TerrainSegments.new([Support.floor_polygon()])
	sim.slimes.auto_hops = false
	sim.view.set_to(Vector2(0, -100), 1.0, ScreenView.DEFAULT_SIZE)
	return sim


## Two slimes resting side by side on the floor, their rings touching (the
## centres a sum of ring radii apart). Returns their ids.
func _pair(sim: Simulation, species_a: int, size_a: int, species_b: int, size_b: int,
		state := SlimeBodies.TRAIN) -> Array[int]:
	var ra := SlimeBodies.ring_radius_for(size_a)
	var rb := SlimeBodies.ring_radius_for(size_b)
	var a := sim.slimes.create(species_a, size_a, Vector2(-ra, -ra - SlimeBodies.EDGE), state)
	var b := sim.slimes.create(species_b, size_b, Vector2(rb, -rb - SlimeBodies.EDGE), state)
	return [a, b]


# --- 3 s of contact -----------------------------------------------------------

func test_179_ticks_of_contact_do_not_fuse_and_180_do() -> void:
	var sim := _sim()
	var ids := _pair(sim, 2, 1, 2, 1)
	for i in TICKS - 1:
		sim.step()
		assert_true(sim.slimes.touching(ids[0], ids[1]), "touching at tick %d" % sim.tick)
	assert_eq(sim.fusion.contact_ticks(ids[0], ids[1]), TICKS - 1)
	assert_eq(sim.slimes.slime_count, 2, "no fusion after 179 ticks")
	sim.step()
	assert_eq(sim.slimes.slime_count, 1, "fused at 180")
	assert_true(sim.slimes.has(ids[0]), "the lower id survives")
	assert_false(sim.slimes.has(ids[1]))
	assert_eq(sim.slimes.size_of(ids[0]), 2, "the sizes add up")
	assert_eq(sim.slimes.species_of(ids[0]), 2)


func test_3_s_is_180_ticks() -> void:
	assert_eq(Fusion.CONTACT_TICKS, int(round(Fusion.CONTACT_SECONDS * Simulation.TICK_RATE)))


func test_a_hop_that_breaks_the_contact_starts_the_count_again() -> void:
	var sim := _sim()
	var ids := _pair(sim, 2, 1, 2, 1)
	sim.run(100)
	assert_eq(sim.fusion.contact_ticks(ids[0], ids[1]), 100)
	assert_true(sim.slimes.hop(ids[1], Vector2.UP, 0.3), "b hops (a small hop) at tick 100")
	# Runs until they fuse, noting the last tick they were apart.
	var last_apart := -1
	var fused_at := -1
	for i in 600:
		sim.step()
		if not sim.slimes.has(ids[1]):
			fused_at = sim.tick
			break
		if not sim.slimes.touching(ids[0], ids[1]):
			last_apart = sim.tick
			assert_eq(sim.fusion.contact_ticks(ids[0], ids[1]), 0, "apart: no count")
		if sim.tick == TICKS:
			assert_eq(sim.slimes.slime_count, 2, "no fusion at 180: the count started again")
	assert_gt(last_apart, 100, "the hop broke the contact")
	assert_eq(fused_at, last_apart + TICKS, "fused 180 ticks after the contact came back")
	assert_between(fused_at, 280, 280 + 60, "about 280, plus the time in the air")


func test_different_species_never_fuse() -> void:
	var sim := _sim()
	var ids := _pair(sim, 0, 1, 1, 1)
	sim.run(TICKS * 3)
	assert_true(sim.slimes.touching(ids[0], ids[1]))
	assert_eq(sim.slimes.slime_count, 2)
	assert_eq(sim.fusion.contact_ticks(ids[0], ids[1]), 0, "never counted")
	assert_eq(sim.slimes.size_of(ids[0]), 1)
	assert_eq(sim.slimes.size_of(ids[1]), 1)


func test_free_slimes_fuse_too() -> void:
	var sim := _sim()
	var ids := _pair(sim, 3, 1, 3, 1, SlimeBodies.FREE)
	sim.run(TICKS)
	assert_eq(sim.slimes.slime_count, 1)
	assert_eq(sim.slimes.size_of(ids[0]), 2)
	assert_eq(sim.slimes.state_of(ids[0]), SlimeBodies.FREE)


func test_sleepers_never_count() -> void:
	var sim := _sim()
	var ids := _pair(sim, 2, 1, 2, 1, SlimeBodies.SLEEPER)
	sim.run(TICKS * 2)
	assert_eq(sim.slimes.slime_count, 2)
	assert_eq(sim.fusion.contact_ticks(ids[0], ids[1]), 0)


# --- Sizes: fuse up to 3, bump past it ------------------------------------------

func test_1_and_2_fuse_into_3() -> void:
	var sim := _sim()
	var ids := _pair(sim, 4, 1, 4, 2)
	sim.run(TICKS)
	assert_eq(sim.slimes.slime_count, 1)
	assert_eq(sim.slimes.size_of(ids[0]), 3)


func _assert_bumps(size_a: int, size_b: int) -> void:
	var sim := _sim()
	var ids := _pair(sim, 5, size_a, 5, size_b)
	# Until one tick before the bump (a big and a small slime settle against
	# each other first, which may break the contact once).
	for i in TICKS * 4:
		if sim.fusion.contact_ticks(ids[0], ids[1]) == TICKS - 1:
			break
		sim.step()
	assert_eq(sim.fusion.contact_ticks(ids[0], ids[1]), TICKS - 1)
	var gap := sim.slimes.centre_of(ids[0]).distance_to(sim.slimes.centre_of(ids[1]))
	sim.step()
	var label := "%d + %d" % [size_a, size_b]
	assert_eq(sim.slimes.slime_count, 2, label + ": both remain")
	assert_eq(sim.slimes.size_of(ids[0]), size_a, label)
	assert_eq(sim.slimes.size_of(ids[1]), size_b, label)
	assert_eq(sim.fusion.contact_ticks(ids[0], ids[1]), 0, label + ": the count starts again")
	var va := sim.slimes.velocity_of(ids[0])
	var vb := sim.slimes.velocity_of(ids[1])
	assert_lt(va.x, 0.0, label + ": a is pushed left")
	assert_gt(vb.x, 0.0, label + ": b is pushed right")
	assert_lt(va.y, 0.0, label + ": and lifted")
	assert_lt(vb.y, 0.0, label + ": and lifted")
	sim.run(30)
	var apart := sim.slimes.centre_of(ids[0]).distance_to(sim.slimes.centre_of(ids[1]))
	assert_gt(apart, gap + 10.0, label + ": pushed apart")
	assert_false(sim.slimes.touching(ids[0], ids[1]), label + ": no longer touching")


func test_2_and_2_bump() -> void:
	_assert_bumps(2, 2)


func test_3_and_1_bump() -> void:
	_assert_bumps(3, 1)


func test_a_bump_moves_the_smaller_slime_more() -> void:
	var sim := _sim()
	var ids := _pair(sim, 5, 3, 5, 1)
	sim.run(TICKS)
	assert_gt(absf(sim.slimes.velocity_of(ids[1]).x), absf(sim.slimes.velocity_of(ids[0]).x))


func test_slimes_that_stay_together_bump_every_3_s() -> void:
	var sim := _sim()
	var ids := _pair(sim, 5, 2, 5, 2)
	var bumps := 0
	var last := 0
	for i in TICKS * 6:
		sim.step()
		var count := sim.fusion.contact_ticks(ids[0], ids[1])
		if last == TICKS - 1 and count == 0:
			bumps += 1
		last = count
	assert_eq(sim.slimes.slime_count, 2, "never fused")
	assert_gt(bumps, 0)
	assert_lte(bumps, 6, "at most once every 3 s")


# --- On screen only ---------------------------------------------------------------

func test_off_screen_nothing_fuses() -> void:
	var sim := _sim()
	var ids := _pair(sim, 2, 1, 2, 1)
	sim.view.set_to(Vector2(3000, -100), 1.0, ScreenView.DEFAULT_SIZE)
	sim.run(TICKS * 2)
	assert_true(sim.slimes.touching(ids[0], ids[1]))
	assert_eq(sim.slimes.slime_count, 2, "no fusion off screen after 6 s")
	assert_eq(sim.fusion.contact_ticks(ids[0], ids[1]), 0)


func test_half_off_screen_nothing_fuses() -> void:
	# The view's left edge between the two centres: b is on screen, a isn't.
	var sim := _sim()
	var ids := _pair(sim, 2, 1, 2, 1)
	var half := ScreenView.DEFAULT_SIZE.x * 0.5
	sim.view.set_to(Vector2(half, -100), 1.0, ScreenView.DEFAULT_SIZE)
	sim.run(TICKS * 2)
	assert_eq(sim.slimes.slime_count, 2)


func test_near_the_edge_is_not_on_screen() -> void:
	var view := ScreenView.new()
	view.set_to(Vector2.ZERO, 1.0, Vector2(1000, 600))
	assert_true(Fusion.on_screen(view, Vector2(0, 0)))
	assert_true(Fusion.on_screen(view, Vector2(500 - Fusion.VIEW_MARGIN - 1, 0)))
	assert_false(Fusion.on_screen(view, Vector2(500 - Fusion.VIEW_MARGIN + 1, 0)), "inside the margin")
	assert_false(Fusion.on_screen(view, Vector2(0, 310)))
	view.set_to(Vector2.ZERO, 2.0, Vector2(1000, 600))
	assert_false(Fusion.on_screen(view, Vector2(260, 0)), "zoomed in: a smaller box")


func test_going_off_screen_drops_the_count() -> void:
	var sim := _sim()
	var ids := _pair(sim, 2, 1, 2, 1)
	sim.run(150)
	sim.view.set_to(Vector2(3000, -100), 1.0, ScreenView.DEFAULT_SIZE)
	sim.step()
	assert_eq(sim.fusion.contact_ticks(ids[0], ids[1]), 0, "dropped, not paused")
	sim.view.set_to(Vector2(0, -100), 1.0, ScreenView.DEFAULT_SIZE)
	sim.run(TICKS - 1)
	assert_eq(sim.slimes.slime_count, 2, "a fresh count")
	sim.step()
	assert_eq(sim.slimes.slime_count, 1)


# --- The survivor's state -------------------------------------------------------------

## A flat loop along the floor, as in test_save_data.gd, with no split zone.
func _flat_level() -> LevelData:
	var data := LevelData.new("fusion", 1)
	var loop := LoopData.new("t.loop")
	loop.add_segment("t.loop.out", 1, LoopData.OUTGOING, PackedVector2Array([
			Vector2(-1500, -24), Vector2(1500, -24)]))
	loop.add_segment("t.loop.back", 1, LoopData.RETURN, PackedVector2Array([
			Vector2(1500, -24), Vector2(1500, 400), Vector2(-1500, 400), Vector2(-1500, -24)]), "t.gate")
	data.loop = loop
	return data


func test_a_fused_train_slime_keeps_following_the_loop() -> void:
	var sim := Simulation.new(11)
	sim.slimes.terrain = TerrainSegments.new([Support.floor_polygon()])
	sim.load_level(_flat_level())
	sim.view.set_to(Vector2(0, -100), 1.0, ScreenView.DEFAULT_SIZE)
	sim.slimes.auto_hops = false
	var gap := 2.0 * SlimeBodies.ring_radius_for(1)
	var a := sim.spawn_train_slime(2, 1, 1500.0)
	var b := sim.spawn_train_slime(2, 1, 1500.0 + gap)
	sim.run(TICKS - 1)
	var progress := sim.train.distance_of(a)
	sim.step()
	assert_eq(sim.slimes.size_of(a), 2, "fused")
	assert_true(sim.train.tracks(a), "the survivor stays on the train")
	assert_false(sim.train.tracks(b), "the other's record is gone")
	assert_eq(sim.slimes.state_of(a), SlimeBodies.TRAIN)
	assert_almost_eq(sim.train.distance_of(a), progress, gap, "with its progress")
	sim.slimes.auto_hops = true
	sim.view.set_to(Vector2(0, -100), 1.0, Vector2(10000, 4000))
	sim.run(Simulation.TICK_RATE * 10)
	assert_gt(sim.train.distance_of(a), progress + 300.0, "and hops on along the loop")
	assert_eq(sim.train.lost, [], "never lost")


func test_the_fused_slime_keeps_both_identities() -> void:
	var sim := _sim()
	var ids := _pair(sim, 2, 1, 2, 1)
	sim.identities.assign(ids[0], PackedStringArray(["s1.sleeper.01"]))
	sim.identities.assign(ids[1], PackedStringArray(["s1.sleeper.02"]))
	sim.run(TICKS)
	assert_eq(sim.identities.members_of(ids[0]), PackedStringArray(["s1.sleeper.01", "s1.sleeper.02"]))


# --- Determinism and saves ---------------------------------------------------------

func _busy(master_seed: int) -> Simulation:
	var sim := _sim(master_seed)
	sim.slimes.auto_hops = true
	_pair(sim, 2, 1, 2, 1)
	for k in 4:
		sim.slimes.create(2, 1, Vector2(-300 + 150 * k, -200), SlimeBodies.TRAIN)
	return sim


func test_the_same_seed_gives_the_same_run() -> void:
	var first := _busy(4)
	var second := _busy(4)
	for i in 8:
		first.run(60)
		second.run(60)
		assert_eq(first.state_hash(), second.state_hash(), "at tick %d" % first.tick)
	assert_eq(first.fusion.dump(), second.fusion.dump())


func test_the_counts_are_state() -> void:
	var sim := _sim()
	var ids := _pair(sim, 2, 1, 2, 1)
	sim.run(50)
	assert_eq(sim.dump()["fusion"], [[ids[0], ids[1], 50]])


func test_the_counts_survive_a_save() -> void:
	var sim := Simulation.new(11)
	sim.slimes.terrain = TerrainSegments.new([Support.floor_polygon()])
	var level := _flat_level()
	sim.load_level(level)
	sim.view.set_to(Vector2(0, -100), 1.0, ScreenView.DEFAULT_SIZE)
	sim.slimes.auto_hops = false
	var gap := 2.0 * SlimeBodies.ring_radius_for(1)
	var a := sim.spawn_train_slime(2, 1, 1500.0)
	var b := sim.spawn_train_slime(2, 1, 1500.0 + gap)
	sim.run(120)
	var json := JSON.new()
	assert_eq(json.parse(SaveData.to_text(sim.to_save())), OK)
	var reloaded := Simulation.from_save(json.data, level, TerrainSegments.new([Support.floor_polygon()]))
	reloaded.slimes.auto_hops = false
	assert_eq(reloaded.fusion.contact_ticks(a, b), sim.fusion.contact_ticks(a, b))
	assert_eq(reloaded.state_hash(), sim.state_hash())
	sim.run(60)
	reloaded.run(60)
	assert_eq(reloaded.slimes.slime_count, sim.slimes.slime_count, "they fuse on the same tick")
	assert_eq(reloaded.state_hash(), sim.state_hash())


# --- Dip floors ------------------------------------------------------------------

## A loop with a deep dip (150 px, a flat bottom from x 300 to 400) and a
## shallow one (50 px) on its outgoing route. Down is +y.
func _dip_loop() -> LoopData:
	var loop := LoopData.new("d.loop")
	loop.add_segment("d.loop.out", 1, LoopData.OUTGOING, PackedVector2Array([
			Vector2(0, 0), Vector2(200, 0), Vector2(300, 150), Vector2(400, 150), Vector2(500, 0),
			Vector2(700, 0), Vector2(800, 50), Vector2(900, 0)]))
	loop.add_segment("d.loop.back", 1, LoopData.RETURN, PackedVector2Array([
			Vector2(900, 0), Vector2(900, 400), Vector2(0, 400), Vector2(0, 0)]), "d.gate")
	return loop


func test_a_dip_floor_is_the_bottom_of_a_deep_dip() -> void:
	var floors := Fusion.dip_floors(_dip_loop(), [])
	assert_eq(floors.size(), 1, "the shallow dip and the return route have none")
	if floors.is_empty():
		return
	# The slopes are 180.28 px long; the floor ends 30 px (a fifth) up each.
	var slope := Vector2(100, 150).length()
	assert_almost_eq(floors[0].x, 200.0 + slope * 0.8, 0.01)
	assert_almost_eq(floors[0].y, 200.0 + slope + 100.0 + slope * 0.2, 0.01)


func test_a_flat_loop_has_no_dip() -> void:
	assert_eq(Fusion.dip_floors(_flat_level().loop, []), [] as Array[Vector2])
	assert_eq(Fusion.dip_floors(null, []), [] as Array[Vector2])
