extends GutTest
## The test level's fixtures (levels/test/fixtures/), loaded by test mode's
## "fixture" setting: `fresh` is the level as new; `bump` has a size-3 and a
## size-2 train slime of one species a little apart on the fusion dip's
## floor (plus the first slime and the level's sleepers), and points the
## camera at them. Every fixture in the directory loads.

# @test-link [[req_test_level_and_test_mode]]
# @test-link [[req_persistence_and_saves]]

const MAIN_SCENE := "res://src/main.tscn"
const SEED := 5
## The fusion dip's floor, in level pixels (x: 2.8 to 3.2 screens).
const DIP_LEFT := 2.8 * 1152.0
const DIP_RIGHT := 3.2 * 1152.0


func _boot(config := {}) -> Node:
	var game: Node = load(MAIN_SCENE).instantiate()
	add_child_autofree(game)
	var run := {"seed": SEED, "time_scale": 0}
	run.merge(config, true)
	assert_eq(game.enable_test_mode(run), PackedStringArray())
	return game


func test_bump_has_a_size_three_and_a_size_two_slime_of_one_species_on_the_dip_floor() -> void:
	var game := _boot({"fixture": "bump"})
	var sim: Simulation = game.simulation
	var dip := []
	var awake := 0
	for slime_id in sim.slimes.ids():
		if sim.slimes.state_of(slime_id) == SlimeBodies.SLEEPER:
			continue
		awake += 1
		if sim.slimes.species_of(slime_id) != Species.from_letter("A"):
			dip.append(slime_id)
	assert_eq(dip.size(), 2)
	if dip.size() != 2:
		return
	var a: int = dip[0]
	var b: int = dip[1]
	assert_eq(sim.slimes.species_of(a), sim.slimes.species_of(b), "one species")
	var sizes := [sim.slimes.size_of(a), sim.slimes.size_of(b)]
	sizes.sort()
	assert_eq(sizes, [2, 3])
	for slime_id in dip:
		assert_eq(sim.slimes.state_of(slime_id), SlimeBodies.TRAIN)
		assert_true(sim.train.tracks(slime_id))
		var centre := sim.slimes.centre_of(slime_id)
		assert_between(centre.x, DIP_LEFT, DIP_RIGHT, "on the dip's floor")
		assert_eq(sim.identities.members_of(slime_id).size(), sim.slimes.size_of(slime_id),
				"one member per base slime")
	var gap := sim.slimes.centre_of(a).distance_to(sim.slimes.centre_of(b))
	var touching := sim.slimes.radius_of(a) + sim.slimes.radius_of(b) + 2.0 * SlimeBodies.EDGE
	assert_between(gap, touching, touching + 120.0, "a little apart")
	assert_eq(awake, 3, "and the first slime; the rest are sleepers")


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


func test_every_fixture_loads() -> void:
	var names := PackedStringArray()
	for file in DirAccess.get_files_at(TestMode.FIXTURES_DIR):
		if file.ends_with(TestMode.SIDECAR_EXTENSION):
			names.append(file.trim_suffix(TestMode.SIDECAR_EXTENSION))
	assert_true("fresh" in names)
	assert_true("bump" in names)
	for name in names:
		var game: Node = load(MAIN_SCENE).instantiate()
		add_child_autofree(game)
		assert_eq(game.enable_test_mode({"seed": SEED, "time_scale": 0, "fixture": name}),
				PackedStringArray(), name)
