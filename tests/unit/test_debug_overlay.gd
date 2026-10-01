extends GutTest
## The debug overlay's pure parts (src/debug/): the accessible-section rule
## and the "woken / available" counter (DebugCounts), the slime counts
## (physics, on screen, in range, parked, resting), the largest awake cluster
## and the fps text, the bar showing
## them at most every STATS_MS, the sped-up session clock (DebugClock), the
## kill tool's slime picking and its move to the start of the loop
## (DebugKill), speed stepping giving the same ticks, and the lint keeping
## src/debug/ out of release builds. The overlay itself, through the game
## scene, is tests/e2e/test_debug_overlay_e2e.gd.

const DEBUG_DIR := "res://src/debug/"
const SRC_ROOT := "res://src/"
const Support := preload("res://tests/unit/slime_test_support.gd")


## A clock whose reading a test sets.
class FakeClock:
	extends RefCounted
	var reading := {}

	func now() -> Dictionary:
		return reading


## A game root as the overlay reads it: its simulation, no parent layer.
class GameHost:
	extends Node
	var simulation: Simulation


## Three sections: s1 and s2 each with an outgoing segment and a return
## route behind their gate, s3 with an outgoing segment and a return route
## without one. Two sleepers each in s1 and s2, one in s3.
func _level() -> LevelData:
	var data := LevelData.new("debug", 1)
	var loop := LoopData.new("start.loop")
	loop.add_segment("s1.loop", 1, LoopData.OUTGOING, PackedVector2Array([Vector2(0, -24), Vector2(2000, -24)]))
	loop.add_segment("s1.slide", 1, LoopData.RETURN, PackedVector2Array([
			Vector2(2000, -24), Vector2(2000, 400), Vector2(0, 400), Vector2(0, -24)]), "s1.gate")
	loop.add_segment("s2.loop", 2, LoopData.OUTGOING, PackedVector2Array([Vector2(2000, -24), Vector2(4000, -24)]))
	loop.add_segment("s2.slide", 2, LoopData.RETURN, PackedVector2Array([
			Vector2(4000, -24), Vector2(4000, 400), Vector2(0, 400), Vector2(0, -24)]), "s2.gate")
	loop.add_segment("s3.loop", 3, LoopData.OUTGOING, PackedVector2Array([Vector2(4000, -24), Vector2(6000, -24)]))
	loop.add_segment("s3.slide", 3, LoopData.RETURN, PackedVector2Array([
			Vector2(6000, -24), Vector2(6000, 400), Vector2(0, 400), Vector2(0, -24)]))
	data.loop = loop
	data.first_slime = {"id": "start.first-slime", "species": "A", "position": Vector2(100, -24)}
	data.add_sleeper("s1.sleeper.01", "A", Vector2(500, -300))
	data.add_sleeper("s1.sleeper.02", "B", Vector2(700, -300))
	data.add_sleeper("s2.sleeper.01", "A", Vector2(2500, -300))
	data.add_sleeper("s2.sleeper.02", "C", Vector2(2700, -300))
	data.add_sleeper("s3.sleeper.01", "A", Vector2(4500, -300))
	return data


func _sim() -> Simulation:
	var sim := Simulation.new(4242)
	sim.load_level(_level())
	return sim


func _id_of(sim: Simulation, stable_id: String) -> int:
	for slime_id in sim.slimes.ids():
		if sim.identities.stable_id_of(slime_id) == stable_id:
			return slime_id
	return -1


# --- Sections and the counter ---------------------------------------------------

func test_section_of_reads_the_stable_id_place() -> void:
	assert_eq(DebugCounts.section_of("s1.sleeper.01"), 1)
	assert_eq(DebugCounts.section_of("s2.basket"), 2)
	assert_eq(DebugCounts.section_of("s10.sleeper.03"), 10)
	assert_eq(DebugCounts.section_of("start.first-slime"), 1, "the start basin is section 1's")
	assert_eq(DebugCounts.section_of("t.first-slime"), 1, "an unknown place counts as section 1")
	assert_eq(DebugCounts.section_of("seed.x"), 1)
	assert_eq(DebugCounts.section_of(""), 1)


func test_accessible_sections_follow_the_open_gates() -> void:
	var loop := _level().loop
	assert_eq(DebugCounts.accessible_sections(loop, []), [1] as Array[int], "section 1 only")
	assert_eq(DebugCounts.accessible_sections(loop, ["s1.gate"]), [1, 2] as Array[int], "gate 1 opens section 2")
	assert_eq(DebugCounts.accessible_sections(loop, ["s1.gate", "s2.gate"]), [1, 2, 3] as Array[int])
	assert_eq(DebugCounts.accessible_sections(loop, ["s2.gate"]), [1] as Array[int],
			"gate 2 alone opens nothing: section 2 isn't reached")
	assert_eq(DebugCounts.accessible_sections(null, []), [1] as Array[int], "no loop: section 1")


func test_open_gates_come_from_the_train_or_the_gate_states() -> void:
	var sim := _sim()
	sim.train.set_open_gates(["s1.gate"])
	assert_eq(DebugCounts.open_gates(sim), ["s1.gate"])
	var bare := Simulation.new(1)
	bare.gate_states = {"s1.gate": {"open": true}, "s2.gate": {"open": false}}
	assert_eq(DebugCounts.open_gates(bare), ["s1.gate"])


func test_fresh_level_counts_the_first_slime_woken_and_section_1_available() -> void:
	var counts := DebugCounts.count(_sim())
	assert_eq(counts, {"woken": 1, "available": 3}, "the first slime and s1's two sleepers")


func test_opening_a_gate_adds_its_section_sleepers() -> void:
	var sim := _sim()
	sim.train.set_open_gates(["s1.gate"])
	assert_eq(DebugCounts.count(sim), {"woken": 1, "available": 5})
	sim.train.set_open_gates(["s1.gate", "s2.gate"])
	assert_eq(DebugCounts.count(sim), {"woken": 1, "available": 6})


func test_every_awake_state_counts_as_woken() -> void:
	var sim := _sim()
	sim.train.set_open_gates(["s1.gate"])
	sim.slimes.set_state(_id_of(sim, "s1.sleeper.01"), SlimeBodies.FREE)
	sim.slimes.set_state(_id_of(sim, "s1.sleeper.02"), SlimeBodies.IN_BASKET)
	sim.slimes.set_state(_id_of(sim, "s2.sleeper.01"), SlimeBodies.BEDTIME_ASLEEP)
	assert_eq(DebugCounts.count(sim), {"woken": 4, "available": 5}, "only s2.sleeper.02 still a sleeper")


func test_counts_are_in_base_slimes() -> void:
	var sim := _sim()
	var fused := sim.slimes.create(Species.from_letter("A"), 2, Vector2(300, -200), SlimeBodies.TRAIN)
	sim.identities.assign(fused, PackedStringArray(["s1.sleeper.03", "s1.sleeper.04"]))
	var anonymous := sim.slimes.create(Species.from_letter("B"), 3, Vector2(900, -200), SlimeBodies.FREE)
	assert_gt(anonymous, 0)
	var hidden := sim.slimes.create(Species.from_letter("A"), 1, Vector2(3000, -200), SlimeBodies.TRAIN)
	sim.identities.assign(hidden, PackedStringArray(["s2.sleeper.09"]))
	assert_eq(DebugCounts.count(sim), {"woken": 1 + 2 + 3, "available": 3 + 2 + 3},
			"a fused slime counts its members, one without identity its size, s2 not reached")


# --- The slime counts and the fps --------------------------------------------------

## The level's simulation with its own slimes removed and five sleepers (they
## stay put) placed around the view on (0, 0), zoom 1 (x -576 to 576): two
## on screen, one within NEAR_MARGIN of the view, one between NEAR_MARGIN and
## PARK_MARGIN, one far off. Off-screen simulation on, not stepped yet.
func _placed_sim() -> Simulation:
	var sim := _sim()
	for slime_id in sim.slimes.ids():
		sim.slimes.remove(slime_id)
	var half := ScreenView.DEFAULT_SIZE.x * 0.5
	var band := (Offscreen.NEAR_MARGIN + Offscreen.PARK_MARGIN) * 0.5
	for at in [Vector2(0, 0), Vector2(400, 100), Vector2(half + 100.0, 0), Vector2(half + band, 0),
			Vector2(3000, 0)]:
		sim.slimes.create(Species.from_letter("A"), 1, at, SlimeBodies.SLEEPER)
	sim.offscreen.enabled = true
	sim.view.set_to(Vector2.ZERO, 1.0, ScreenView.DEFAULT_SIZE)
	return sim


func _slimes(physics: int, on_screen: int, in_range: int, parked: int, resting: int) -> Dictionary:
	return {"physics": physics, "on_screen": on_screen, "in_range": in_range, "parked": parked,
			"resting": resting}


## The sleepers cost no physics and never rest; On screen and In range
## overlap, parking moves a slime from In range to Parked.
func test_slime_counts_follow_the_view_and_the_parking() -> void:
	var sim := _placed_sim()
	assert_eq(DebugCounts.count_slimes(sim), _slimes(0, 2, 5, 0, 0), "nothing parked before a step")
	sim.step()
	assert_eq(DebugCounts.count_slimes(sim), _slimes(0, 2, 4, 1, 0),
			"the near and the in-between one stay in range, the far one parks")
	sim.view.set_to(Vector2(3000, 0), 1.0, ScreenView.DEFAULT_SIZE)
	assert_eq(DebugCounts.count_slimes(sim), _slimes(0, 1, 4, 1, 0),
			"a parked slime whose centre is in the view counts on screen and parked")
	sim.step()
	assert_eq(DebugCounts.count_slimes(sim), _slimes(0, 1, 1, 4, 0), "the four far from the new view park")
	sim.view.set_to(Vector2.ZERO, 1.0, ScreenView.DEFAULT_SIZE)
	sim.step()
	assert_eq(DebugCounts.count_slimes(sim), _slimes(0, 2, 3, 2, 0),
			"back: the near one is in range again, the in-between one stays parked")


func test_slime_counts_with_the_offscreen_simulation_off_never_count_parked() -> void:
	var sim := _placed_sim()
	sim.offscreen.enabled = false
	sim.step()
	assert_eq(DebugCounts.count_slimes(sim), _slimes(0, 2, 5, 0, 0))


func test_slime_counts_count_bodies_not_base_slimes() -> void:
	var sim := _placed_sim()
	var fused := sim.slimes.create(Species.from_letter("B"), 3, Vector2(-200, 0), SlimeBodies.TRAIN)
	sim.identities.assign(fused, PackedStringArray(["s1.sleeper.07", "s1.sleeper.08", "s1.sleeper.09"]))
	assert_eq(DebugCounts.count_slimes(sim), _slimes(1, 3, 6, 0, 0), "a size-3 slime counts once")


## Physics is what the solver integrates (SlimeBodies.crowd_count()): calm
## active and not a sleeper, so a slime in a basket and one asleep at bedtime
## still settling count; a sleeper, a resting or a parked slime don't. On
## screen and In range take every state; Resting every state too.
# @test-link [[req_platform_and_performance_targets]]
func test_slime_counts_physics_on_screen_in_range_parked_and_resting() -> void:
	var sim := Simulation.new(7)
	sim.view.set_to(Vector2.ZERO, 1.0, ScreenView.DEFAULT_SIZE)
	var bodies := sim.slimes
	bodies.create(0, 1, Vector2(0, 0), SlimeBodies.SLEEPER)
	var pile := [bodies.create(1, 1, Vector2(100, 0), SlimeBodies.IN_BASKET),
			bodies.create(1, 1, Vector2(140, 0), SlimeBodies.IN_BASKET)]
	bodies.create(2, 1, Vector2(200, 0), SlimeBodies.IN_BASKET)
	bodies.create(0, 1, Vector2(300, 0), SlimeBodies.BEDTIME_ASLEEP)
	bodies.create(1, 1, Vector2(-200, 0), SlimeBodies.TRAIN)
	bodies.create(2, 1, Vector2(1000, 0), SlimeBodies.TRAIN)
	var parked_far := bodies.create(0, 1, Vector2(3000, 0), SlimeBodies.TRAIN)
	var parked_shown := bodies.create(1, 1, Vector2(-300, 0), SlimeBodies.FREE)
	for slime_id in pile:
		bodies.calm[bodies.index_of(slime_id)] = SlimeBodies.RESTING
	bodies.park(parked_far)
	bodies.park(parked_shown)
	var hash_before := sim.state_hash()
	var counts := DebugCounts.count_slimes(sim)
	assert_eq(counts, _slimes(4, 7, 7, 2, 2),
			"physics: basket, bedtime, train, off-view train; on screen: all but the far two")
	assert_eq(counts[DebugCounts.PHYSICS], bodies.crowd_count(), "the crowd detail's own count")
	DebugCounts.largest_cluster(bodies)
	assert_eq(sim.state_hash(), hash_before, "read only")


func test_the_stats_texts() -> void:
	assert_eq(DebugCounts.slimes_text(_slimes(18, 12, 30, 63, 9)),
			"Physics 18 : on screen 12 : in range 30 : parked 63")
	assert_eq(DebugCounts.fps_text(59.6), "60 fps", "a whole number")
	assert_eq(DebugCounts.fps_text(0.0), "0 fps")


func test_the_bar_shows_the_fps_and_the_slime_counts_at_most_every_stats_ms() -> void:
	var host := Node.new()
	add_child_autofree(host)
	var overlay := DebugOverlay.new()
	host.add_child(overlay)
	assert_eq(overlay.fps_label.get_parent(), overlay.bar)
	assert_eq(overlay.slimes_label.get_parent(), overlay.bar)
	var sim := _placed_sim()
	assert_true(overlay.update_stats(sim, 58.7, 1000))
	assert_eq(overlay.fps_label.text, "59 fps")
	assert_eq(overlay.slimes_label.text, "Physics 0 : on screen 2 : in range 5 : parked 0")
	sim.step()
	assert_false(overlay.update_stats(sim, 30.0, 1000 + DebugOverlay.STATS_MS - 1), "too soon")
	assert_eq(overlay.fps_label.text, "59 fps")
	assert_eq(overlay.slimes_label.text, "Physics 0 : on screen 2 : in range 5 : parked 0")
	assert_true(overlay.update_stats(sim, 30.0, 1000 + DebugOverlay.STATS_MS))
	assert_eq(overlay.fps_label.text, "30 fps")
	assert_eq(overlay.slimes_label.text, "Physics 0 : on screen 2 : in range 4 : parked 1")
	assert_true(overlay.update_stats(sim, 30.2, 1000 + 2 * DebugOverlay.STATS_MS))
	assert_eq(overlay.fps_label.text, "30 fps", "unchanged")
	assert_eq(overlay.slimes_label.text, "Physics 0 : on screen 2 : in range 4 : parked 1", "unchanged")


# --- The largest awake cluster --------------------------------------------------

func _cluster(pairs: Array, physics_ids: Array) -> int:
	return DebugCounts.largest_cluster_in(pairs, PackedInt32Array(physics_ids))


# @test-link [[req_platform_and_performance_targets]]
func test_largest_cluster_in_takes_the_biggest_touching_group() -> void:
	var three := [Vector2i(1, 2), Vector2i(2, 3)]
	var five := [Vector2i(10, 11), Vector2i(11, 12), Vector2i(12, 13), Vector2i(13, 14)]
	assert_eq(_cluster(three + five, [1, 2, 3, 10, 11, 12, 13, 14]), 5)
	assert_eq(_cluster(five + three, [1, 2, 3, 10, 11, 12, 13, 14]), 5, "whatever the order")


# @test-link [[req_platform_and_performance_targets]]
func test_largest_cluster_in_joins_a_chain_given_in_any_order() -> void:
	assert_eq(_cluster([Vector2i(3, 4), Vector2i(1, 2), Vector2i(2, 3)], [1, 2, 3, 4]), 4)
	assert_eq(_cluster([Vector2i(2, 3), Vector2i(3, 4), Vector2i(1, 2)], [4, 3, 2, 1]), 4)


# @test-link [[req_platform_and_performance_targets]]
func test_largest_cluster_in_keeps_only_pairs_of_physics_slimes() -> void:
	assert_eq(_cluster([Vector2i(1, 2), Vector2i(2, 3)], [1, 3]), 1,
			"a resting or parked slime between two physics slimes doesn't join them")
	assert_eq(_cluster([Vector2i(1, 99), Vector2i(5, 6)], [1, 2]), 1, "an id not in physics is ignored")
	assert_eq(_cluster([Vector2i(5, 6)], []), 0, "no physics slime")


# @test-link [[req_platform_and_performance_targets]]
func test_largest_cluster_in_lone_and_empty() -> void:
	assert_eq(_cluster([], [4, 7, 9]), 1, "a lone physics slime is a group of 1")
	assert_eq(_cluster([], []), 0)


## Three touching in a row and two touching elsewhere: 3 (before the first
## tick by distance, then from the contact list). The middle one
## resting breaks the chain (the pair left: 2); parking one of the pair
## leaves it out (1). Read only.
# @test-link [[req_platform_and_performance_targets]]
func test_largest_cluster_reads_the_last_ticks_contacts() -> void:
	var bodies := Support.bodies_on_floor()
	bodies.auto_hops = false
	var row: Array[int] = []
	for i in 3:
		row.append(bodies.create(i % Species.COUNT, 1, Vector2(40.0 * i, -24), SlimeBodies.TRAIN))
	var pair: Array[int] = []
	for i in 2:
		pair.append(bodies.create(i % Species.COUNT, 1, Vector2(600.0 + 40.0 * i, -24), SlimeBodies.TRAIN))
	assert_eq(DebugCounts.largest_cluster(bodies), 3, "before any tick: no contact list, by distance")
	bodies.tick(1.0 / 60.0)
	assert_true(bodies.touching(row[0], row[1]) and bodies.touching(row[1], row[2]), "the row touches")
	assert_true(bodies.touching(pair[0], pair[1]), "the pair touches")
	var hash_before := StateHash.of(bodies.dump())
	assert_eq(DebugCounts.largest_cluster(bodies), 3)
	assert_eq(StateHash.of(bodies.dump()), hash_before, "read only")
	bodies.calm[bodies.index_of(row[1])] = SlimeBodies.RESTING
	assert_eq(DebugCounts.largest_cluster(bodies), 2, "the resting middle one breaks the row")
	bodies.park(pair[0])
	assert_eq(DebugCounts.largest_cluster(bodies), 1, "a parked slime is left out")


## A slime gone since the tick (a fusion) joins nothing: the removal wipes the
## list, and by distance the row's two ends are too far apart to touch.
# @test-link [[req_platform_and_performance_targets]]
func test_largest_cluster_skips_slimes_gone_since_the_tick() -> void:
	var bodies := Support.bodies_on_floor()
	bodies.auto_hops = false
	var row: Array[int] = []
	for i in 3:
		row.append(bodies.create(i % Species.COUNT, 1, Vector2(40.0 * i, -24), SlimeBodies.TRAIN))
	bodies.tick(1.0 / 60.0)
	bodies.remove(row[1])
	var reach := bodies.radius_of(row[0]) + bodies.radius_of(row[2]) + DebugCounts.TOUCH_GAP
	assert_gt(bodies.centre_of(row[0]).distance_to(bodies.centre_of(row[2])), reach, "the ends don't touch")
	assert_eq(DebugCounts.largest_cluster(bodies), 1)


## A removal since the tick (a fusion) wipes the contact list: the count then
## measures by distance and still finds the row of 3. Read only.
# @test-link [[req_platform_and_performance_targets]]
func test_largest_cluster_measures_by_distance_once_a_removal_wiped_the_list() -> void:
	var bodies := Support.bodies_on_floor()
	bodies.auto_hops = false
	for i in 3:
		bodies.create(i % Species.COUNT, 1, Vector2(40.0 * i, -24), SlimeBodies.TRAIN)
	for i in 2:
		bodies.create(i % Species.COUNT, 1, Vector2(600.0 + 40.0 * i, -24), SlimeBodies.TRAIN)
	var far := bodies.create(0, 1, Vector2(1500, -24), SlimeBodies.TRAIN)
	bodies.tick(1.0 / 60.0)
	assert_eq(DebugCounts.largest_cluster(bodies), 3, "from the contact list")
	bodies.remove(far)
	assert_eq(bodies.touching_pairs().size(), 0, "the removal wiped the contact list")
	var hash_before := StateHash.of(bodies.dump())
	assert_eq(DebugCounts.largest_cluster(bodies), 3, "by distance: the row is still there")
	assert_eq(StateHash.of(bodies.dump()), hash_before, "read only")


## Two Physics slimes touch when their centres are closer than the sum of
## their ring radii + TOUCH_GAP; each pair once, (lower id, higher id).
# @test-link [[req_platform_and_performance_targets]]
func test_touching_by_distance_uses_the_radii_plus_the_gap() -> void:
	var bodies := Support.bodies_on_floor()
	var r := bodies.radius_of(bodies.create(0, 1, Vector2(-2000, -24), SlimeBodies.TRAIN))
	var near_a := bodies.create(0, 1, Vector2(0, -24), SlimeBodies.TRAIN)
	var near_b := bodies.create(1, 1, Vector2(2.0 * r + DebugCounts.TOUCH_GAP - 1.0, -24), SlimeBodies.TRAIN)
	bodies.create(0, 1, Vector2(300, -24), SlimeBodies.TRAIN)
	bodies.create(1, 1, Vector2(300.0 + 2.0 * r + DebugCounts.TOUCH_GAP + 1.0, -24), SlimeBodies.TRAIN)
	var hash_before := StateHash.of(bodies.dump())
	var pairs := DebugCounts.touching_by_distance(bodies, DebugCounts.physics_slime_ids(bodies))
	assert_eq(pairs, [Vector2i(near_a, near_b)], "only the near pair, once")
	assert_eq(StateHash.of(bodies.dump()), hash_before, "read only")
	assert_eq(DebugCounts.TOUCH_GAP, SlimeBodies.TOUCH_SKIN, "the solver's skin")


## A chain of 4 (no tick) is one group of 4; slimes of any size, anywhere.
# @test-link [[req_platform_and_performance_targets]]
func test_touching_by_distance_joins_a_chain() -> void:
	var bodies := Support.bodies_on_floor()
	for i in 4:
		bodies.create(i % Species.COUNT, 1, Vector2(-5000.0 + 40.0 * i, 3000), SlimeBodies.FREE)
	bodies.create(0, SlimeBodies.MAX_SIZE, Vector2(800, -24), SlimeBodies.FREE)
	var physics := DebugCounts.physics_slime_ids(bodies)
	var pairs := DebugCounts.touching_by_distance(bodies, physics)
	assert_eq(pairs.size(), 3)
	assert_eq(DebugCounts.largest_cluster_in(pairs, physics), 4)


## A resting, a parked or a sleeping slime isn't a Physics slime: it's left
## out of the pairs and joins nothing.
# @test-link [[req_platform_and_performance_targets]]
func test_touching_by_distance_ignores_slimes_that_arent_physics() -> void:
	var bodies := Support.bodies_on_floor()
	var chain: Array[int] = []
	for i in 7:
		chain.append(bodies.create(i % Species.COUNT, 1, Vector2(40.0 * i, -24), SlimeBodies.TRAIN))
	bodies.calm[bodies.index_of(chain[2])] = SlimeBodies.RESTING
	bodies.set_state(chain[4], SlimeBodies.SLEEPER)
	bodies.park(chain[6])
	var physics := DebugCounts.physics_slime_ids(bodies)
	assert_eq(physics, PackedInt32Array([chain[0], chain[1], chain[3], chain[5]]))
	var pairs := DebugCounts.touching_by_distance(bodies, physics)
	assert_eq(pairs, [Vector2i(chain[0], chain[1])])
	assert_eq(DebugCounts.largest_cluster(bodies), 2, "no tick yet: by distance")


func test_the_woken_counter_refreshes_with_the_stats_at_most_every_stats_ms() -> void:
	var host := Node.new()
	add_child_autofree(host)
	var overlay := DebugOverlay.new()
	host.add_child(overlay)
	var sim := _placed_sim()
	assert_true(overlay.update_stats(sim, 60.0, 1000))
	assert_eq(overlay.counter_label.text, "Woken 0 / available 5")
	sim.slimes.set_state(sim.slimes.ids()[0], SlimeBodies.FREE)
	assert_false(overlay.update_stats(sim, 60.0, 1000 + DebugOverlay.STATS_MS - 1), "too soon")
	assert_eq(overlay.counter_label.text, "Woken 0 / available 5")
	assert_true(overlay.update_stats(sim, 60.0, 1000 + DebugOverlay.STATS_MS))
	assert_eq(overlay.counter_label.text, "Woken 1 / available 5")


# --- The slime labels -----------------------------------------------------------

func test_the_labels_only_process_while_shown() -> void:
	var labels := DebugSlimeLabels.new()
	labels.visible = false
	add_child_autofree(labels)
	assert_false(labels.is_processing(), "no redraw while hidden")
	labels.visible = true
	assert_true(labels.is_processing())
	labels.visible = false
	assert_false(labels.is_processing())


func test_the_labels_are_drawn_for_seen_slimes_only() -> void:
	var sim := _placed_sim()
	sim.step()
	var shown := Fusion.view_rect(sim.view)
	var labelled := DebugSlimeLabels.labelled_slimes(sim.slimes, shown, 1.0)
	assert_eq(labelled.size(), 3, "the two on screen and the one just off its edge, not the far ones")
	sim.view.set_to(Vector2(20000, 0), 1.0, ScreenView.DEFAULT_SIZE)
	assert_eq(DebugSlimeLabels.labelled_slimes(sim.slimes, Fusion.view_rect(sim.view), 1.0).size(), 0)


# @test-link [[req_platform_and_performance_targets]]
func test_the_labels_text_is_cached_and_rebuilt_every_text_refresh_ms() -> void:
	var sim := _placed_sim()
	var labels: DebugSlimeLabels = autofree(DebugSlimeLabels.new())
	labels.simulation = sim
	var slime_id := sim.slimes.ids()[0]
	assert_true(labels.refresh_text(1000), "the first call builds")
	var text := labels.text_lines(slime_id)
	assert_eq(text.lines, DebugSlimeLabels.lines_for(sim, slime_id))
	assert_eq(text.widths.size(), text.lines.size())
	assert_gt(text.widths[0], 0.0)
	assert_same(labels.text_lines(slime_id), text, "cached")
	sim.slimes.set_state(slime_id, SlimeBodies.FREE)
	assert_false(labels.refresh_text(1000 + DebugSlimeLabels.TEXT_REFRESH_MS - 1), "too soon")
	assert_eq(labels.text_lines(slime_id).lines, text.lines, "the old text, within the refresh period")
	assert_true(labels.refresh_text(1000 + DebugSlimeLabels.TEXT_REFRESH_MS))
	assert_eq(labels.text_lines(slime_id).lines, DebugSlimeLabels.lines_for(sim, slime_id), "rebuilt")
	assert_ne(labels.text_lines(slime_id).lines[0], text.lines[0], "the new state shows")


# @test-link [[req_platform_and_performance_targets]]
func test_the_labels_text_is_rebuilt_at_once_for_another_simulation() -> void:
	var labels: DebugSlimeLabels = autofree(DebugSlimeLabels.new())
	labels.simulation = _placed_sim()
	labels.refresh_text(1000)
	assert_false(labels.refresh_text(1001))
	labels.simulation = _placed_sim()
	assert_true(labels.refresh_text(1002), "a new simulation drops the old text")
	assert_false(labels.refresh_text(1003))


# --- The bar's per-frame refresh --------------------------------------------------

# @test-link [[req_platform_and_performance_targets]]
func test_the_bar_follows_what_changes_and_keeps_what_does_not() -> void:
	var host := GameHost.new()
	host.simulation = _placed_sim()
	add_child_autofree(host)
	var overlay := DebugOverlay.new()
	host.add_child(overlay)
	overlay._process(0.0)
	assert_eq(overlay.labels.simulation, host.simulation)
	var top := TapDispatcher.parent_zone_height(host.simulation.view) + DebugOverlay.BAR_GAP
	assert_eq(overlay.bar.position, Vector2(DebugOverlay.BAR_X, top))
	assert_eq(overlay.status_label.text, "")
	overlay._process(0.0)
	assert_eq(overlay.bar.position, Vector2(DebugOverlay.BAR_X, top), "unchanged")
	overlay.status = "done"
	host.simulation = _placed_sim()
	overlay._process(0.0)
	top = TapDispatcher.parent_zone_height(host.simulation.view) + DebugOverlay.BAR_GAP
	assert_eq(overlay.labels.simulation, host.simulation, "the new simulation")
	assert_eq(overlay.bar.position, Vector2(DebugOverlay.BAR_X, top))
	assert_eq(overlay.status_label.text, "done")
	host.simulation.view.px_per_mm *= 2.0
	overlay._process(0.0)
	assert_almost_eq(overlay.bar.position.y,
			TapDispatcher.parent_zone_height(host.simulation.view) + DebugOverlay.BAR_GAP, 0.001,
			"the bar moves with the parent zone")


# --- The sped-up clock ----------------------------------------------------------

func test_clock_at_1x_passes_the_reading_through() -> void:
	var inner := FakeClock.new()
	var clock := DebugClock.new(inner)
	inner.reading = Session.reading(1_000_000, 500, "e")
	assert_eq(clock.now(), Session.reading(1_000_000, 500, "e"))
	inner.reading = Session.reading(1_001_000, 1500, "e")
	assert_eq(clock.now(), Session.reading(1_001_000, 1500, "e"))


func test_clock_at_10x_adds_nine_ms_per_real_ms_to_both_clocks() -> void:
	var inner := FakeClock.new()
	var clock := DebugClock.new(inner)
	clock.speed = 10
	inner.reading = Session.reading(1_000_000, 500, "e")
	assert_eq(clock.now(), Session.reading(1_000_000, 500, "e"), "the first reading has no offset")
	inner.reading = Session.reading(1_000_100, 600, "e")
	assert_eq(clock.now(), Session.reading(1_001_000, 1500, "e"), "100 real ms read as 1000")
	clock.speed = 1
	inner.reading = Session.reading(1_000_200, 700, "e")
	assert_eq(clock.now(), Session.reading(1_001_100, 1600, "e"), "back to 1x keeps the offset")
	assert_eq(clock.extra_ms, 900)


func test_clock_never_runs_backwards_and_passes_an_empty_reading() -> void:
	var inner := FakeClock.new()
	var clock := DebugClock.new(inner)
	clock.speed = 5
	inner.reading = {}
	assert_eq(clock.now(), {})
	inner.reading = Session.reading(0, 1000, "e")
	clock.now()
	inner.reading = Session.reading(0, 900, "e")
	assert_eq(clock.now()["mono_ms"], 900, "a monotonic step back adds nothing")
	assert_eq(clock.extra_ms, 0)


# --- The kill tool --------------------------------------------------------------

func test_slime_at_picks_the_slime_under_the_tap() -> void:
	var sim := _sim()
	sim.view.set_to(Vector2(600, -300), 1.0, ScreenView.DEFAULT_SIZE)
	var first := _id_of(sim, "s1.sleeper.01")
	var at := sim.view.world_to_screen(sim.slimes.centre_of(first))
	assert_eq(DebugKill.slime_at(sim, at), first, "on its centre")
	var reach := sim.slimes.radius_of(first) + SlimeBodies.EDGE + DebugKill.TAP_MARGIN
	assert_eq(DebugKill.slime_at(sim, at + Vector2(0, reach - 1)), first, "just inside the margin")
	assert_eq(DebugKill.slime_at(sim, at + Vector2(0, reach + 1)), -1, "just outside")
	var second := _id_of(sim, "s1.sleeper.02")
	var between := sim.view.world_to_screen(Vector2(640, -300))
	assert_eq(DebugKill.slime_at(sim, between), -1, "between two, out of both reaches")
	var nearer := sim.view.world_to_screen(Vector2(660, -300))
	assert_eq(DebugKill.slime_at(sim, nearer, 20.0), second, "the nearer centre wins")


func test_slime_at_scales_the_margin_with_zoom() -> void:
	var sim := _sim()
	sim.view.set_to(Vector2(600, -300), 0.5, ScreenView.DEFAULT_SIZE)
	var first := _id_of(sim, "s1.sleeper.01")
	var reach := sim.slimes.radius_of(first) + SlimeBodies.EDGE + DebugKill.TAP_MARGIN / 0.5
	var at := sim.view.world_to_screen(sim.slimes.centre_of(first) + Vector2(0, reach - 1))
	assert_eq(DebugKill.slime_at(sim, at), first)


func test_send_to_start_moves_a_free_slime_as_a_lost_one() -> void:
	var sim := _sim()
	var slime := _id_of(sim, "s1.sleeper.01")
	sim.slimes.set_state(slime, SlimeBodies.FREE)
	assert_true(DebugKill.send_to_start(sim, slime))
	assert_eq(sim.slimes.state_of(slime), SlimeBodies.TRAIN, "back on the train")
	assert_true(sim.train.tracks(slime))
	# The first slime sits at the start: the next free spot along the loop
	# (LoopStart.move), one width on.
	var width := 2.0 * (SlimeBodies.ring_radius_for(1) + SlimeBodies.EDGE)
	var distance := sim.train.distance_of(slime)
	assert_true(is_equal_approx(fmod(distance, width), 0.0), "on a spot")
	assert_lt(distance, LoopStart.SPOTS * width, "at the start of the loop")
	var start := sim.train.position_at(distance) + Vector2(0.0, -Offscreen.lift(1))
	assert_almost_eq(sim.slimes.centre_of(slime).distance_to(start), 0.0, 0.5)
	assert_eq(sim.offscreen.lost.back()["id"], slime, "logged as lost")
	sim.run(30)
	assert_eq(sim.slimes.state_of(slime), SlimeBodies.TRAIN, "it rides on")


func test_send_to_start_refuses_a_missing_slime_or_no_train() -> void:
	var sim := _sim()
	assert_false(DebugKill.send_to_start(sim, 999))
	var bare := Simulation.new(1)
	var slime := bare.slimes.create(Species.from_letter("A"), 1, Vector2.ZERO, SlimeBodies.FREE)
	assert_false(DebugKill.send_to_start(bare, slime))


# --- Speed ------------------------------------------------------------------------

func test_each_speed_runs_that_many_ticks_per_60hz_frame() -> void:
	for speed in [1, 2, 5, 10]:
		var clock := FixedStep.new()
		var total := 0
		for frame in 60:
			total += clock.advance(Simulation.TICK_SECONDS * speed, 8 * speed)
		assert_eq(total, 60 * speed, "%dx" % speed)


func test_ticks_run_in_batches_give_the_same_hash() -> void:
	var one := _sim()
	var ten := _sim()
	for frame in 240:
		one.step()
	for frame in 24:
		for k in 10:
			ten.step()
	assert_eq(ten.tick, one.tick)
	assert_eq(ten.state_hash(), one.state_hash())


# --- Release guard lint -----------------------------------------------------------

## src/debug/ stays strippable: nothing outside it names a debug class; the
## game root loads the overlay by path, after the guard (add_debug_overlay()).
func test_code_outside_debug_never_names_it() -> void:
	var offenders := PackedStringArray()
	var pattern := RegEx.create_from_string(
			"\\b(DebugOverlay|DebugCounts|DebugClock|DebugKill|DebugSlimeLabels|PerfLog)\\b")
	for path in _gd_files(SRC_ROOT):
		if path.begins_with(DEBUG_DIR):
			continue
		var lines := FileAccess.get_file_as_string(path).split("\n")
		for i in lines.size():
			var code := lines[i].split("#")[0]
			if pattern.search(code):
				offenders.append("%s:%d" % [path, i + 1])
	assert_eq(offenders, PackedStringArray())


func test_main_loads_the_overlay_only_after_the_guard() -> void:
	var text := FileAccess.get_file_as_string("res://src/main.gd")
	var loads := text.count("load(DEBUG_OVERLAY_SCRIPT)")
	assert_eq(loads, 1, "one place loads it")
	var body := text.get_slice("func add_debug_overlay()", 1).get_slice("\nfunc ", 0)
	assert_true(body.find("test_mode_guard.allows()") >= 0
			and body.find("test_mode_guard.allows()") < body.find("load(DEBUG_OVERLAY_SCRIPT)"),
			"add_debug_overlay() asks the guard before loading")


func _gd_files(dir_path: String) -> PackedStringArray:
	var files := PackedStringArray()
	for sub in DirAccess.get_directories_at(dir_path):
		files.append_array(_gd_files(dir_path.path_join(sub)))
	for file in DirAccess.get_files_at(dir_path):
		if file.ends_with(".gd"):
			files.append(dir_path.path_join(file))
	return files
