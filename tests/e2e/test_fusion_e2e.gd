extends GutTest
## End-to-end on the test level (the Meadow): fusion and bumping through the
## real game scene. From the `bump` fixture a size-3 and a size-2 slime of
## species C meet on the fusion dip's floor and never fuse [DoD 6, bump];
## two base slimes of one species put on the dip's rim fuse within a bounded
## time (the dip nudges fusion, level rule 5), and the run is repeatable; a
## 2 + 2 and a 3 + 1 pair on the dip bump and stay apart in size.

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

func test_bump_the_size_three_and_size_two_meet_and_never_fuse() -> void:
	var game := _boot({"fixture": "bump"})
	var sim: Simulation = game.simulation
	var pair: Array[int] = []
	for slime_id in sim.slimes.ids():
		# The fixture's pair: the train slimes of species C (the level's
		# sleepers may be of species C too).
		if sim.slimes.species_of(slime_id) == Species.from_letter("C") \
				and sim.slimes.state_of(slime_id) == SlimeBodies.TRAIN:
			pair.append(slime_id)
	assert_eq(pair.size(), 2)
	if pair.size() != 2:
		return
	_aim_at_dip(game)
	var seen := _watch_pair(game, pair[0], pair[1], BUMP_SECONDS)
	gut.p("bump fixture: %s" % seen)
	assert_true(seen["kept"], "both still there after 10 s, sizes 3 and 2")
	assert_gt(seen["touched"], 0, "they meet")
	var sizes := [sim.slimes.size_of(pair[0]), sim.slimes.size_of(pair[1])]
	sizes.sort()
	assert_eq(sizes, [2, 3])


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
