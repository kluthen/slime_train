extends GutTest
## The test level's fixtures (levels/test/fixtures/), loaded by test mode's
## "fixture" setting: `fresh` is the level as new; `bump` has four train
## slimes of one species, sizes 2, 2, 3 and 1, about a slime apart on the
## fusion dip's floor (plus the first slime and the level's sleepers), and
## points the camera at them; `gate1-open` and `gate2-open` open the gates
## and spread 20 awake train slimes along the grown loop; `stress-still`
## wakes the whole population (60 in basket 3, full; 140 asleep at bedtime in
## section 3's bowl, a pile that comes to rest); `stress-moving` has all 200
## as train slimes in the bowl (chunk 16); `stress-dense` has all 200 as
## train slimes on the loop line, at most 9 per loop bucket but 12 in the
## two at the bottom of the bowl, none past switch 3 (chunk 22j, D153,
## rebuilt 2026-10-02). Every fixture in the directory
## loads, and none is older than the level (chunk LD3: its save holds every
## slime of the level, its sleepers where the level has them), but
## old-version, older on purpose. midair and old-version (chunk 19) are
## tested in tests/e2e/test_persistence_e2e.gd.

# @test-link [[req_test_level_and_test_mode]]
# @test-link [[req_persistence_and_saves]]

const MAIN_SCENE := "res://src/main.tscn"
const SEED := 5
const S := 1152.0
## The fusion dip's floor, in level pixels (x: 2.8 to 3.2 screens).
const DIP_LEFT := 2.8 * S
const DIP_RIGHT := 3.2 * S
## bump's slimes, left to right: their sizes, and how far apart they start
## (0.05 screens).
const BUMP_SIZES := [2, 2, 3, 1]
const BUMP_STEP := 0.05 * S
## The level's population (chunk 16): the first slime and 199 sleepers.
const POPULATION := 200
## The gate fixtures' awake slimes.
const GATE_AWAKE := 20
## Section 3's bowl, where the stress fixtures put their slimes (x, px).
const BOWL_LEFT := 13.3 * S
const BOWL_RIGHT := 15.4 * S
## stress-still's pile comes to rest within this after loading (ticks): it
## rests at about 410 since chunk 19 (670 before, 490 before chunk 16d's
## terrain corner fix); the rest is margin. tools/bench_level.gd waits for
## the same rest, within the same bound.
const PILE_RESTS_WITHIN := 900
## stress-dense (chunk 22j, D153, rebuilt 2026-10-02): the most weight a
## loop bucket holds as saved (the bucket cap's 12 per 300 px less 25 %),
## and in the two loop buckets at the bottom of the bowl (the cap itself),
## those two as the fixture's description records; how many slimes are in
## the bowl (x DENSE_BOWL_FROM to DENSE_BOWL_TO), as it records too; switch
## 3, which no slime is past; how long its save-and-reload run goes after
## the reload (ticks).
const DENSE_PER_BUCKET := 9
const DENSE_BOTTOM_PER_BUCKET := 12
const DENSE_BOTTOM_BUCKETS := [55, 56]
const DENSE_IN_BOWL := 70
const DENSE_BOWL_FROM := 13.5 * S
const DENSE_BOWL_TO := 15.33 * S
const SWITCH_3 := "s3.switch"
const DENSE_RELOAD_TICKS := 200
## The fixtures older than the level on purpose, exempt from
## test_no_fixture_is_older_than_the_level: old-version is a save of the
## test level's version 1 with a sleeper where version 1 had it, to test the
## save migration (chunk 19; tests/e2e/test_persistence_e2e.gd).
const OLDER_ON_PURPOSE := ["old-version"]
## The fixture maker's generic fixtures, and stale() (chunk LD3).
const LEVEL_FIXTURES := preload("res://tools/make_fixture/level_fixtures.gd")
## When a loaded bedtime pile rests: the criterion the bench shares (D131).
const PILE_REST := preload("res://tools/bench_level/pile_rest.gd")


func _boot(config := {}) -> Node:
	var game: Node = load(MAIN_SCENE).instantiate()
	add_child_autofree(game)
	var run := {"seed": SEED, "time_scale": 0}
	run.merge(config, true)
	assert_eq(game.enable_test_mode(run), PackedStringArray())
	return game


## The awake slimes of `sim` other than the first slime (species A), left
## to right.
func _awake_but_the_first(sim: Simulation) -> Array:
	var out := []
	for slime_id in sim.slimes.ids():
		if sim.slimes.state_of(slime_id) == SlimeBodies.SLEEPER:
			continue
		if sim.identities.stable_id_of(slime_id) != "start.first-slime":
			out.append(slime_id)
	out.sort_custom(func(a, b): return sim.slimes.centre_of(a).x < sim.slimes.centre_of(b).x)
	return out


## How many slimes of `sim` are in `state`.
func _count(sim: Simulation, state: int) -> int:
	var n := 0
	for slime_id in sim.slimes.ids():
		if sim.slimes.state_of(slime_id) == state:
			n += 1
	return n


func test_bump_has_four_slimes_of_one_species_sizes_2_2_3_1_on_the_dip_floor() -> void:
	var game := _boot({"fixture": "bump"})
	var sim: Simulation = game.simulation
	var dip := _awake_but_the_first(sim)
	assert_eq(sim.slimes.slime_count - _count(sim, SlimeBodies.SLEEPER), 5,
			"five awake: the four and the first slime; the rest are sleepers")
	assert_eq(dip.size(), 4)
	if dip.size() != 4:
		return
	var sizes := []
	for slime_id in dip:
		sizes.append(sim.slimes.size_of(slime_id))
		assert_eq(Species.letter(sim.slimes.species_of(slime_id)), "C", "one species")
		assert_eq(sim.slimes.state_of(slime_id), SlimeBodies.TRAIN)
		assert_true(sim.train.tracks(slime_id))
		var centre := sim.slimes.centre_of(slime_id)
		assert_between(centre.x, DIP_LEFT, DIP_RIGHT, "on the dip's floor")
		assert_eq(sim.identities.members_of(slime_id).size(), sim.slimes.size_of(slime_id),
				"one member per base slime")
	assert_eq(sizes, BUMP_SIZES, "sizes left to right: both bumps (2 + 2, 3 + 1) can happen")
	for k in range(1, dip.size()):
		var step := sim.slimes.centre_of(dip[k]).x - sim.slimes.centre_of(dip[k - 1]).x
		assert_almost_eq(step, BUMP_STEP, 1.0, "about a slime apart")


func test_bump_points_the_camera_at_the_dip() -> void:
	var game := _boot({"fixture": "bump"})
	game.sync_view()
	assert_between(game.simulation.view.centre.x, DIP_LEFT, DIP_RIGHT)


func test_bump_runs_the_same_twice() -> void:
	var first := _boot({"fixture": "bump"})
	var second := _boot({"fixture": "bump"})
	first.test_mode.run_ticks(300)
	second.test_mode.run_ticks(300)
	assert_eq(first.simulation.state_hash(), second.simulation.state_hash())


func test_fresh_is_the_level_as_new() -> void:
	var fixture := _boot({"fixture": "fresh"})
	var plain := _boot()
	fixture.test_mode.run_ticks(60)
	plain.test_mode.run_ticks(60)
	assert_eq(fixture.simulation.state_hash(), plain.simulation.state_hash())
	assert_eq(fixture.simulation.slimes.slime_count, 1 + fixture.level.data.sleepers.size(),
			"the first slime and the sleepers")


func test_a_fixture_camera_does_not_stick_to_the_next_run() -> void:
	var game := _boot({"fixture": "bump"})
	var plain := _boot()
	assert_eq(game.enable_test_mode({"seed": SEED, "time_scale": 0}), PackedStringArray())
	assert_eq(game.camera.position, plain.camera.position)


## Checks a gate fixture: the gates `gates` open (and the loop grown
## through them), GATE_AWAKE awake size-1 train slimes on it, the other
## base slimes asleep, the camera at x `camera_x` (screens).
func _check_gate_fixture(name: String, gates: Array, camera_x: float) -> void:
	var game := _boot({"fixture": name})
	var sim: Simulation = game.simulation
	assert_eq(sim.train.open_gates, gates, "%s: the loop runs through %s" % [name, gates])
	for gate in ["s1.gate", "s2.gate"]:
		assert_eq(sim.gate_states[gate]["open"], gate in gates, "%s: %s" % [name, gate])
	assert_eq(_count(sim, SlimeBodies.TRAIN), GATE_AWAKE, name)
	assert_eq(_count(sim, SlimeBodies.SLEEPER), POPULATION - GATE_AWAKE, name)
	for slime_id in sim.slimes.ids():
		if sim.slimes.state_of(slime_id) == SlimeBodies.TRAIN:
			assert_eq(sim.slimes.size_of(slime_id), 1, name)
			assert_true(sim.train.tracks(slime_id), name)
	game.sync_view()
	assert_almost_eq(sim.view.centre.x / S, camera_x, 0.5, "%s: the camera" % name)


func test_gate1_open_opens_gate_1_with_20_train_slimes() -> void:
	_check_gate_fixture("gate1-open", ["s1.gate"], 8.3)


func test_gate2_open_opens_gates_1_and_2_with_20_train_slimes() -> void:
	_check_gate_fixture("gate2-open", ["s1.gate", "s2.gate"], 13.0)


# @test-link [[rule_max_200_slimes_per_level]]
func test_stress_still_has_60_in_basket_3_and_a_bowl_pile_that_rests() -> void:
	var game := _boot({"fixture": "stress-still"})
	var sim: Simulation = game.simulation
	assert_eq(sim.slimes.slime_count, POPULATION, "the whole population, awake")
	assert_eq(_count(sim, SlimeBodies.SLEEPER), 0)
	assert_eq(_count(sim, SlimeBodies.IN_BASKET), 60)
	assert_eq(_count(sim, SlimeBodies.BEDTIME_ASLEEP), POPULATION - 60)
	assert_eq(sim.object_states["s3.basket"]["phase"], FrontierSets.FULL, "basket 3 full")
	assert_eq(int(sim.object_states["s3.basket"]["weight"]), 60)
	assert_eq(sim.session.phase, Session.BEDTIME)
	var pile: Array[int] = PILE_REST.pile_of(sim)
	for slime_id in pile:
		assert_between(sim.slimes.centre_of(slime_id).x, BOWL_LEFT, BOWL_RIGHT, "in the bowl")
	var rested_at: int = PILE_REST.ticks_to_rest(sim, pile, PILE_RESTS_WITHIN, game.test_mode.run_ticks.bind(1))
	gut.p("stress-still: the pile rests %d ticks after loading" % rested_at)
	assert_gt(rested_at, 0, "the whole pile rests (on screen: resting, not parked)")
	game.test_mode.run_ticks(60)
	assert_true(PILE_REST.rests(sim, pile), "and stays resting")


func test_stress_moving_has_200_train_slimes_in_the_bowl() -> void:
	var game := _boot({"fixture": "stress-moving"})
	var sim: Simulation = game.simulation
	assert_eq(sim.slimes.slime_count, POPULATION)
	assert_eq(_count(sim, SlimeBodies.TRAIN), POPULATION, "every one a train slime")
	assert_eq(sim.train.open_gates, ["s1.gate", "s2.gate"])
	for slime_id in sim.slimes.ids():
		assert_eq(sim.slimes.size_of(slime_id), 1)
		assert_true(sim.train.tracks(slime_id))
		assert_between(sim.slimes.centre_of(slime_id).x, BOWL_LEFT, BOWL_RIGHT, "in the bowl")


# @test-link [[rule_max_200_slimes_per_level]]
# @test-link [[req_test_level_and_test_mode]]
func test_stress_dense_has_200_train_slimes_along_the_loop_at_most_9_per_bucket_12_at_the_bowls_bottom() -> void:
	var game := _boot({"fixture": "stress-dense"})
	var sim: Simulation = game.simulation
	assert_eq(sim.slimes.slime_count, POPULATION)
	assert_eq(_count(sim, SlimeBodies.TRAIN), POPULATION, "every one a train slime")
	assert_eq(sim.train.open_gates, ["s1.gate", "s2.gate"])
	assert_ne(sim.session.phase, Session.BEDTIME, "not at bedtime")
	assert_false(sim.object_states[SWITCH_3]["flipped"], "switch 3 untouched")
	assert_eq(int(sim.object_states["s3.basket"]["weight"]), 0, "basket 3 empty")
	var box: Rect2 = sim.level.switches[SWITCH_3]["box"]
	var stop: float = sim.level.loop.closest(Vector2(box.position.x, box.get_center().y),
			sim.train.open_gates)["distance"]
	var in_bowl := 0
	for slime_id in sim.slimes.ids():
		assert_eq(sim.slimes.size_of(slime_id), 1)
		assert_true(sim.train.tracks(slime_id))
		var centre := sim.slimes.centre_of(slime_id)
		assert_lt(sim.level.loop.closest(centre, sim.train.open_gates)["distance"], stop, "none past switch 3")
		if centre.x >= DENSE_BOWL_FROM and centre.x <= DENSE_BOWL_TO:
			in_bowl += 1
	assert_eq(in_bowl, DENSE_IN_BOWL, "in the bowl, as the fixture's description records")
	# The placement, as saved: each slime in the loop bucket of its saved
	# train distance, cut as the bucket cap cuts the loop (D153), and on the
	# loop there (its saved centre the loop's point, a size-1 slime riding
	# the route).
	var buckets := BucketLoads.new()
	buckets.configure(sim.train.length(), sim.train.bucket_length, BucketLoads.DEFAULT_DENSITY, 0)
	for slime: Dictionary in TestMode.load_fixture("stress-dense")["save"]["slimes"]:
		var distance := SaveData.real(slime["train"]["distance"])
		assert_lt(distance, stop, "none saved past switch 3")
		assert_almost_eq(SaveData.vector_from(slime["centre"]), sim.train.position_at(distance),
				Vector2(0.02, 0.02), "saved on the loop line")
		buckets.add(buckets.bucket_index(distance), int(slime["size"]))
	var loads := buckets.loads()
	var used := []
	var total := 0
	for b in loads.size():
		var most := DENSE_BOTTOM_PER_BUCKET if b in DENSE_BOTTOM_BUCKETS else DENSE_PER_BUCKET
		assert_lte(loads[b], most, "loop bucket %d at most %d" % [b, most])
		total += loads[b]
		if loads[b] > 0:
			used.append(b)
	assert_eq(total, POPULATION, "every slime counted in a loop bucket")
	assert_eq(used.size(), used[-1] - used[0] + 1, "the buckets used are side by side")
	for b in DENSE_BOTTOM_BUCKETS:
		assert_eq(loads[b], DENSE_BOTTOM_PER_BUCKET, "bottom bucket %d at the cap" % b)
	var short := used.filter(func(b): return loads[b] < DENSE_PER_BUCKET)
	assert_lte(short.size(), 2, "every other bucket used at 9 but the last and the one switch 3 cuts: %s" % [short])
	# The two buckets at 12 are at the bowl's bottom: the loop is at its
	# lowest through the bowl at both their middles.
	var lowest := -INF
	var distance := 0.0
	while distance < sim.train.outgoing_length():
		var at := sim.train.position_at(distance)
		if at.x >= DENSE_BOWL_FROM and at.x <= DENSE_BOWL_TO:
			lowest = maxf(lowest, at.y)
		distance += 4.0
	for b in DENSE_BOTTOM_BUCKETS:
		assert_almost_eq(sim.train.position_at((b + 0.5) * sim.train.bucket_length).y, lowest, 0.5,
				"bucket %d at the bowl's bottom" % b)
	gut.p("stress-dense: loop buckets %d to %d (%s at 12, %d short); %d in the bowl" % [used[0], used[-1],
			DENSE_BOTTOM_BUCKETS, short.size(), in_bowl])
	game.sync_view()
	assert_between(sim.view.centre.x, BOWL_LEFT, BOWL_RIGHT, "the camera on the bowl")


## stress-dense loaded as a bare simulation on SEED, saved at once,
## reloaded from the save's text and both run on: the same state hash after
## the reload and after the run. (Saved later, a slime mid-hop would be put
## down on reload, D12, so the run would not reload exactly.)
# @test-link [[req_test_level_and_test_mode]]
# @test-link [[req_persistence_and_saves]]
func test_stress_dense_runs_the_same_across_a_save_and_reload() -> void:
	var game := _boot({"fixture": "stress-dense"})
	var data: LevelData = game.level.data
	var loaded := TestMode.load_fixture("stress-dense")
	assert_true(loaded["ok"], loaded["error"])
	var sim := Simulation.from_save(loaded["save"], data, game._terrain, SEED)
	assert_not_null(sim)
	if sim == null:
		return
	var json := JSON.new()
	assert_eq(json.parse(SaveData.to_text(sim.to_save())), OK)
	var reloaded := Simulation.from_save(json.data, data, game._terrain, SEED)
	assert_not_null(reloaded)
	if reloaded == null:
		return
	assert_eq(reloaded.state_hash(), sim.state_hash(), "the same after the reload")
	for i in DENSE_RELOAD_TICKS:
		sim.step()
		reloaded.step()
	assert_eq(reloaded.state_hash(), sim.state_hash(), "and after running on")


## Chunk LD3: a fixture saved before the level changed still loads, without
## what the level gained since; LevelFixtures.stale() says so. Exempt:
## OLDER_ON_PURPOSE, older by design.
func test_no_fixture_is_older_than_the_level() -> void:
	var level: Level = load(LevelCatalog.scene_path(LevelCatalog.DEFAULT_ID)).instantiate()
	add_child_autofree(level)
	for file in DirAccess.get_files_at(LevelCatalog.fixtures_dir(LevelCatalog.DEFAULT_ID)):
		if not file.ends_with(TestMode.SIDECAR_EXTENSION):
			continue
		var name := file.trim_suffix(TestMode.SIDECAR_EXTENSION)
		var loaded := TestMode.load_fixture(name)
		assert_true(loaded["ok"], "%s: %s" % [name, loaded["error"]])
		if name in OLDER_ON_PURPOSE and loaded["ok"]:
			assert_lt(int(loaded["save"]["level"]["version"]), level.level_version,
					"%s is a save of an older version of the level" % name)
		elif loaded["ok"] and not loaded["save"].is_empty():
			var stale := LEVEL_FIXTURES.stale(loaded["save"], level.data)
			assert_eq(stale, PackedStringArray(), "fixture %s is older than the level: rerun " % name
					+ "tools/level.sh fixture %s (%s)" % [name, "; ".join(stale)])


func test_every_fixture_loads() -> void:
	var names := PackedStringArray()
	for file in DirAccess.get_files_at(LevelCatalog.fixtures_dir(LevelCatalog.DEFAULT_ID)):
		if file.ends_with(TestMode.SIDECAR_EXTENSION):
			names.append(file.trim_suffix(TestMode.SIDECAR_EXTENSION))
	assert_true("fresh" in names)
	assert_true("bump" in names)
	for name in ["gate1-open", "gate2-open", "stress-still", "stress-moving", "stress-dense", "midair", "old-version"]:
		assert_true(name in names, name)
	for name in names:
		var game: Node = load(MAIN_SCENE).instantiate()
		add_child_autofree(game)
		assert_eq(game.enable_test_mode({"seed": SEED, "time_scale": 0, "fixture": name}),
				PackedStringArray(), name)
