extends GutTest
## End-to-end on the test level (the Meadow): fusion and bumping through the
## real game scene. From the `bump` fixture four slimes of species C, sizes
## 2, 2, 3 and 1, on the fusion dip's floor make both bumps, a 2 + 2 and a
## 3 + 1, and never fuse [DoD 6, bump; four slimes since chunk 16];
## two base slimes of one species put on the dip's rim fuse within a bounded
## time (the dip nudges fusion, level rule 5), and the run is repeatable; a
## 2 + 2 and a 3 + 1 pair on the dip bump and stay apart in size. In a mixed
## queue (species alternating, as the train leaves the split zone) the dip
## doesn't stall the train, and two neighbours of one species still fuse
## there (chunk 16f).

# @test-link [[rule_fusion_contact_time]]
# @test-link [[rule_max_size_three]]
# @test-link [[rule_dip_may_nudge_fusion]]

const MAIN_SCENE := "res://src/main.tscn"
const SEED := 5
const TICK_RATE := Simulation.TICK_RATE
const SCREEN := 1152.0
## The fusion dip (test level 1.3): the camera on its bottom, and the rim
## where the scripted slimes start, x in screens.
const DIP_VIEW := Vector2(3456, 150)
const RIM := [2.58, 2.68]
## The fusion on the rim happens within this (seconds). Probes over 20 seeds
## fused in 7.5-11.6 s; the rest is margin.
const FUSE_WITHIN := 20
const BUMP_SECONDS := 10
## A mixed queue on the rim and the dip's floor, front first, about a
## slime apart: the species alternate, as the train leaves the split zone,
## so no two neighbours may fuse. Every slime of it (or what it fused into)
## is past the floor within MIXED_CLEAR_WITHIN s. Probes on seeds 1 to 10
## (chunk 16f): 33 to 58 s (seed 5: 43 s), 0 to 3 fusions, none stalled;
## before 16f, 9 of the 10 were still on the floor after 120 s and 7 had
## train slimes stalled.
const MIXED_QUEUE := ["A", "B", "C", "A", "B", "C", "A", "B"]
const MIXED_XS := [2.93, 2.87, 2.81, 2.75, 2.69, 2.63, 2.57, 2.51]
const MIXED_CLEAR_WITHIN := 75
## A mixed queue with two neighbours of species C: they fuse on the dip.
const NEIGHBOURS_QUEUE := ["A", "C", "C", "B"]
const NEIGHBOURS_XS := [2.80, 2.72, 2.64, 2.56]
## How long the bump fixture is watched (seconds). Probes on seeds 1 to 8
## since chunk 16f (the dip's limited wait): within 20 s, 3 + 1 bumped once
## on every seed, 2 + 2 once or twice on seeds 1 and 3 to 7 (seed 5: once
## each), and nothing fused. Before, 3 + 1 bumped six times: the size 1
## never left the floor.
const BUMP_FIXTURE_SECONDS := 20


func _boot(config := {}) -> Node:
	var game: Node = load(MAIN_SCENE).instantiate()
	add_child_autofree(game)
	var run := {"seed": SEED, "time_scale": 0}
	run.merge(config, true)
	assert_eq(game.enable_test_mode(run), PackedStringArray())
	return game


## Points the camera at the dip (the simulation's camera; the scene copies
## it into Simulation.view every tick).
func _aim_at_dip(game: Node) -> void:
	game.simulation.camera.place(DIP_VIEW, 1.0)
	game.sync_view()


## Puts train slimes of species C, `sizes`, on the loop where it passes
## closest to the rim points `xs` (screens). Returns their ids.
func _spawn_on_dip(game: Node, sizes: Array, xs: Array) -> Array[int]:
	var sim: Simulation = game.simulation
	var ids: Array[int] = []
	for k in sizes.size():
		var at := Vector2(float(xs[k]) * SCREEN, 100.0)
		var distance: float = sim.level.loop.closest(at, sim.train.open_gates)["distance"]
		ids.append(sim.spawn_train_slime(Species.from_letter("C"), sizes[k], distance))
	return ids


## Puts a queue of base train slimes of species `letters` on the loop where
## it passes closest to the points `xs` (screens), front first. Returns their
## ids.
func _spawn_queue(game: Node, letters: Array, xs: Array) -> Array[int]:
	var sim: Simulation = game.simulation
	var ids: Array[int] = []
	for k in letters.size():
		var at := Vector2(float(xs[k]) * SCREEN, 100.0)
		var distance: float = sim.level.loop.closest(at, sim.train.open_gates)["distance"]
		ids.append(sim.spawn_train_slime(Species.from_letter(letters[k]), 1, distance))
	return ids


## Runs until slime `gone` no longer exists, at most `limit` ticks. Returns
## the ticks it took, or -1.
func _run_until_fused(game: Node, gone: int, limit: int) -> int:
	for i in limit:
		if not game.simulation.slimes.has(gone):
			return i
		game.test_mode.run_ticks(1)
	return -1 if game.simulation.slimes.has(gone) else limit


## Runs `seconds` and reports what the pair (a, b) did: whether they
## touched, the longest count, and whether both stayed their size.
func _watch_pair(game: Node, a: int, b: int, seconds: int) -> Dictionary:
	var sim: Simulation = game.simulation
	var sizes := [sim.slimes.size_of(a), sim.slimes.size_of(b)]
	var out := {"touched": 0, "longest": 0, "bumps": 0, "kept": true}
	var last := 0
	for i in seconds * TICK_RATE:
		game.test_mode.run_ticks(1)
		if not sim.slimes.has(a) or not sim.slimes.has(b):
			out["kept"] = false
			break
		if sim.slimes.touching(a, b):
			out["touched"] += 1
		var count := sim.fusion.contact_ticks(a, b)
		out["longest"] = maxi(out["longest"], count)
		if last == Fusion.CONTACT_TICKS - 1 and count == 0:
			out["bumps"] += 1
		last = count
		if [sim.slimes.size_of(a), sim.slimes.size_of(b)] != sizes:
			out["kept"] = false
	return out


# --- The bump fixture [DoD 6, bump] ---------------------------------------------------

func test_bump_both_bumps_happen_and_nothing_fuses() -> void:
	var game := _boot({"fixture": "bump"})
	var sim: Simulation = game.simulation
	var four: Array[int] = []
	for slime_id in sim.slimes.ids():
		# The fixture's four: the train slimes of species C (the first slime
		# is A; the level's sleepers may be of species C too).
		if sim.slimes.species_of(slime_id) == Species.from_letter("C") \
				and sim.slimes.state_of(slime_id) == SlimeBodies.TRAIN:
			four.append(slime_id)
	assert_eq(four.size(), 4)
	if four.size() != 4:
		return
	var sizes := {}
	for slime_id in four:
		sizes[slime_id] = sim.slimes.size_of(slime_id)
	_aim_at_dip(game)
	var bumps := {}
	var last := {}
	var kept := true
	for i in BUMP_FIXTURE_SECONDS * TICK_RATE:
		game.test_mode.run_ticks(1)
		for slime_id in four:
			if not sim.slimes.has(slime_id) or sim.slimes.size_of(slime_id) != sizes[slime_id]:
				kept = false
		if not kept:
			break
		for a in four.size():
			for b in range(a + 1, four.size()):
				var pair := Vector2i(four[a], four[b])
				var count := sim.fusion.contact_ticks(pair.x, pair.y)
				if last.get(pair, 0) == Fusion.CONTACT_TICKS - 1 and count == 0:
					var key := "%d+%d" % [maxi(sizes[pair.x], sizes[pair.y]), mini(sizes[pair.x], sizes[pair.y])]
					bumps[key] = bumps.get(key, 0) + 1
				last[pair] = count
	gut.p("bump fixture, %d s: bumps %s" % [BUMP_FIXTURE_SECONDS, bumps])
	assert_true(kept, "all four still there, sizes 2, 2, 3 and 1: nothing fused")
	assert_gt(bumps.get("2+2", 0), 0, "a 2 + 2 bump")
	assert_gt(bumps.get("3+1", 0), 0, "a 3 + 1 bump")


# --- The dip nudges fusion (level rule 5) -------------------------------------------

func test_two_base_slimes_on_the_dip_rim_fuse() -> void:
	var game := _boot()
	_aim_at_dip(game)
	var ids := _spawn_on_dip(game, [1, 1], RIM)
	var ticks := _run_until_fused(game, ids[1], FUSE_WITHIN * TICK_RATE)
	gut.p("rim fusion after %d ticks" % ticks)
	assert_between(ticks, 0, FUSE_WITHIN * TICK_RATE - 1, "fused within %d s" % FUSE_WITHIN)
	var sim: Simulation = game.simulation
	assert_eq(sim.slimes.size_of(ids[0]), 2)
	assert_eq(sim.slimes.state_of(ids[0]), SlimeBodies.TRAIN)
	assert_true(sim.train.tracks(ids[0]), "the fused slime stays on the train")
	var at := sim.slimes.centre_of(ids[0])
	assert_between(at.x, 2.75 * SCREEN, 3.25 * SCREEN, "at the bottom of the dip")


func test_the_rim_fusion_run_is_repeatable() -> void:
	var hashes := []
	for run in 2:
		var game := _boot()
		_aim_at_dip(game)
		_spawn_on_dip(game, [1, 1], RIM)
		game.test_mode.run_ticks(FUSE_WITHIN * TICK_RATE)
		hashes.append(game.simulation.state_hash())
	assert_eq(hashes[0], hashes[1])


func test_a_fused_slime_hops_on_along_the_loop() -> void:
	var game := _boot()
	_aim_at_dip(game)
	var ids := _spawn_on_dip(game, [1, 1], RIM)
	assert_gte(_run_until_fused(game, ids[1], FUSE_WITHIN * TICK_RATE), 0)
	var sim: Simulation = game.simulation
	var progress := sim.train.distance_of(ids[0])
	game.test_mode.run_ticks(20 * TICK_RATE)
	assert_gt(sim.train.distance_of(ids[0]), progress + 300.0, "it left the dip")
	assert_true(sim.train.tracks(ids[0]))


func test_two_and_two_on_the_dip_bump() -> void:
	var game := _boot()
	_aim_at_dip(game)
	var ids := _spawn_on_dip(game, [2, 2], RIM)
	var seen := _watch_pair(game, ids[0], ids[1], BUMP_SECONDS)
	gut.p("2 + 2: %s" % seen)
	assert_true(seen["kept"], "both remain, size 2 each")
	assert_gt(seen["touched"], 0, "they meet")


func test_three_and_one_on_the_dip_bump() -> void:
	var game := _boot()
	_aim_at_dip(game)
	var ids := _spawn_on_dip(game, [3, 1], RIM)
	var seen := _watch_pair(game, ids[0], ids[1], BUMP_SECONDS)
	gut.p("3 + 1: %s" % seen)
	assert_true(seen["kept"], "both remain, sizes 3 and 1")
	assert_gt(seen["touched"], 0, "they meet")


# --- A mixed queue on the dip (chunk 16f) ----------------------------------------------

# @test-link [[rule_dip_may_nudge_fusion]]
# @test-link [[rule_loop_travelable_with_no_input]]
func test_a_mixed_queue_passes_through_the_dip() -> void:
	var game := _boot()
	_aim_at_dip(game)
	var sim: Simulation = game.simulation
	var floors := Fusion.dip_floors(sim.train.loop, sim.train.open_gates)
	assert_eq(floors.size(), 1, "the Meadow has one fusion dip")
	if floors.is_empty():
		return
	var ids := _spawn_queue(game, MIXED_QUEUE, MIXED_XS)
	var cleared := -1
	for tick in MIXED_CLEAR_WITHIN * TICK_RATE:
		game.test_mode.run_ticks(1)
		var behind := false
		for slime_id in ids:
			if sim.slimes.has(slime_id) and sim.train.distance_of(slime_id) <= floors[0].y:
				behind = true
		if not behind:
			cleared = tick + 1
			break
	var at := []
	for slime_id in ids:
		at.append(roundi(sim.train.distance_of(slime_id)) if sim.slimes.has(slime_id) else "fused")
	gut.p("mixed queue: cleared the floor (to %.0f) after %d ticks; at %s" % [floors[0].y, cleared, at])
	assert_gt(cleared, 0, "every slime of the queue is past the dip's floor within %d s" % MIXED_CLEAR_WITHIN)
	assert_eq(sim.train.stalled, [] as Array[Dictionary], "none stalled")


# @test-link [[rule_dip_may_nudge_fusion]]
# @test-link [[rule_fusion_contact_time]]
func test_two_neighbours_of_one_species_in_a_mixed_queue_fuse_on_the_dip() -> void:
	var game := _boot()
	_aim_at_dip(game)
	var ids := _spawn_queue(game, NEIGHBOURS_QUEUE, NEIGHBOURS_XS)
	var ticks := _run_until_fused(game, ids[2], FUSE_WITHIN * TICK_RATE)
	gut.p("neighbours' fusion after %d ticks" % ticks)
	assert_between(ticks, 0, FUSE_WITHIN * TICK_RATE - 1, "the two C slimes fused within %d s" % FUSE_WITHIN)
	var sim: Simulation = game.simulation
	assert_eq(sim.slimes.size_of(ids[1]), 2)
	assert_true(sim.train.tracks(ids[1]), "the fused slime stays on the train")
	for slime_id in [ids[0], ids[3]]:
		assert_eq(sim.slimes.size_of(slime_id), 1, "the others stay base slimes")
