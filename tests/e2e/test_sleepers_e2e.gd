extends GutTest
## End-to-end on the test level (the Meadow), from the `fresh` fixture:
## every sleeper starts asleep; with no call, the first-play hint shows next
## to the first sleeper after 10 s [DoD 16]; after a call it never shows,
## not even after a reload; a scripted call on the first sleeper brings the
## first slime onto its ledge, wakes it, and both rejoin the train [DoD 2];
## no sleeper wakes during a lap without calls; the whole run is repeatable.

# @test-link [[req_waking_sleepers]]
# @test-link [[req_first_play_hint]]
# @test-link [[req_slime_states]]

const MAIN_SCENE := "res://src/main.tscn"
const SEED := 909
const TICK_RATE := Simulation.TICK_RATE
const FIRST_SLEEPER := "s1.sleeper.01"
const DIR := "user://test-sleepers-e2e/"
const LEVEL := "test"
const DUE_TICKS := 10 * TICK_RATE
## The test level's sleepers: section 1's 29, section 2's 40 and section
## 3's 130 (chunk 16); with the first slime, the level's 200.
const SLEEPERS := 199


func before_each() -> void:
	_clear(DIR)


func after_all() -> void:
	_clear(DIR)


func _clear(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)


func _boot(config := {}, store: SaveStore = null) -> Node:
	var game: Node = load(MAIN_SCENE).instantiate()
	game.save_store = store
	add_child_autofree(game)
	var run := {"seed": SEED, "time_scale": 0, "fixture": "fresh"}
	if config.has("load"):
		run.erase("fixture")
	run.merge(config, true)
	assert_eq(game.enable_test_mode(run), PackedStringArray())
	return game


## The runtime id of the slime whose stable ID is `stable_id`, or -1.
func _slime(sim: Simulation, stable_id: String) -> int:
	for slime_id in sim.slimes.ids():
		if stable_id in sim.identities.members_of(slime_id):
			return slime_id
	return -1


func _count(sim: Simulation, state: int) -> int:
	var count := 0
	for slime_id in sim.slimes.ids():
		if sim.slimes.state_of(slime_id) == state:
			count += 1
	return count


## Taps the screen where it shows level point `world`; the tap is dispatched
## on the next tick, which this runs.
func _tap_at(game: Node, world: Vector2) -> void:
	var sim: Simulation = game.simulation
	game.sync_view()
	var screen := sim.view.world_to_screen(world)
	sim.push_input(Simulation.touch_down(0, screen))
	sim.push_input(Simulation.touch_up(0, screen))
	game.test_mode.run_ticks(1)


## Taps the first sleeper at tick 60 and runs until the first slime and the
## sleeper are both back on the train (at most 90 s). Returns what happened.
func _wake_the_first_sleeper(game: Node) -> Dictionary:
	var sim: Simulation = game.simulation
	var first := sim.slimes.ids()[0]
	var sleeper := _slime(sim, FIRST_SLEEPER)
	var spot := sim.slimes.centre_of(sleeper)
	game.test_mode.run_ticks(60)
	_tap_at(game, spot)
	var out := {"tap": sim.taps[-1], "woke_at": -1, "waker_state": -1, "rejoined_at": -1, "first": first,
			"sleeper": sleeper, "spot": spot}
	for i in 90 * TICK_RATE:
		game.test_mode.run_ticks(1)
		if out["woke_at"] < 0 and sim.slimes.state_of(sleeper) != SlimeBodies.SLEEPER:
			out["woke_at"] = sim.tick
			out["waker_state"] = sim.slimes.state_of(first)
			out["woke_phase"] = sim.free_slimes.phase_of(sleeper)
			out["first_at"] = sim.slimes.centre_of(first)
		if (out["woke_at"] >= 0 and sim.slimes.state_of(sleeper) == SlimeBodies.TRAIN
				and sim.slimes.state_of(first) == SlimeBodies.TRAIN):
			out["rejoined_at"] = sim.tick
			break
	out["hash"] = sim.state_hash()
	return out


func test_every_sleeper_starts_asleep_and_the_first_slime_awake() -> void:
	var game := _boot()
	var sim: Simulation = game.simulation
	var by_species := {}
	for slime_id in sim.slimes.ids():
		if sim.slimes.state_of(slime_id) != SlimeBodies.SLEEPER:
			continue
		var letter := Species.letter(sim.slimes.species_of(slime_id))
		by_species[letter] = by_species.get(letter, 0) + 1
		assert_eq(sim.identities.members_of(slime_id).size(), 1, "one stable ID each")
	# S1 A 9, B 9, C 11; S2 A 7, B 7, C 7, D 19; S3 (chunk 16) A 20, B 20,
	# C 20, D 20, E 50.
	assert_eq(by_species, {"A": 36, "B": 36, "C": 38, "D": 39, "E": 50})
	var first := sim.slimes.ids()[0]
	assert_eq(sim.slimes.state_of(first), SlimeBodies.TRAIN)
	assert_eq(Species.letter(sim.slimes.species_of(first)), "A")
	assert_eq(sim.slimes.slime_count, SLEEPERS + 1)


# @test-link [[rule_first_sleeper_near_first_awake_slime]]
# @test-link [[user_story_newcomer_p1]]
func test_with_no_call_the_hint_shows_next_to_the_first_sleeper_after_10_s() -> void:
	# DoD 16.
	var game := _boot()
	var sim: Simulation = game.simulation
	game.test_mode.run_ticks(DUE_TICKS - 1)
	assert_false(sim.hint.visible, "not before 10 s")
	game.test_mode.run_ticks(1)
	assert_true(sim.hint.visible, "at 10 s")
	var sleeper := sim.slimes.centre_of(_slime(sim, FIRST_SLEEPER))
	assert_lt(sim.hint.position.distance_to(sleeper), 1.0, "next to the first sleeper")
	var first := sim.slimes.centre_of(sim.slimes.ids()[0])
	assert_lt(sleeper.distance_to(first), 0.5 * LevelData.SCREEN, "which is near the first slime")
	game.sync_view()
	var on_screen := Rect2(sim.view.centre - sim.view.screen_size * 0.5 / sim.view.zoom,
			sim.view.screen_size / sim.view.zoom)
	assert_true(on_screen.has_point(sim.hint.position), "and on screen")


func test_after_a_call_at_5_s_the_hint_never_shows_not_even_after_a_reload() -> void:
	var store := SaveStore.new(DIR)
	var game := _boot({}, store)
	var sim: Simulation = game.simulation
	game.test_mode.run_ticks(5 * TICK_RATE)
	game.sync_view()
	_tap_at(game, sim.view.centre + Vector2(0, 40))
	assert_true(sim.taps[-1]["call"])
	var shown := false
	for i in 20 * TICK_RATE:
		game.test_mode.run_ticks(1)
		shown = shown or sim.hint.visible
	assert_false(shown, "never shown")
	assert_eq(game.save_now(), "")
	var reloaded := _boot({"load": store.path_for(LEVEL)})
	var again: Simulation = reloaded.simulation
	assert_true(again.hint.done, "the save says it's done")
	for i in 20 * TICK_RATE:
		reloaded.test_mode.run_ticks(1)
		shown = shown or again.hint.visible
	assert_false(shown, "not after the reload either")


func test_a_reload_while_the_hint_is_due_counts_10_s_again() -> void:
	var store := SaveStore.new(DIR)
	var game := _boot({}, store)
	game.test_mode.run_ticks(5 * TICK_RATE)
	assert_eq(game.save_now(), "")
	var reloaded := _boot({"load": store.path_for(LEVEL)})
	var sim: Simulation = reloaded.simulation
	assert_false(sim.hint.done)
	reloaded.test_mode.run_ticks(DUE_TICKS - 1)
	assert_false(sim.hint.visible, "10 s from the world showing again")
	reloaded.test_mode.run_ticks(1)
	assert_true(sim.hint.visible)


func test_a_call_on_the_first_sleeper_wakes_it_and_both_rejoin_the_train() -> void:
	# DoD 2.
	var game := _boot()
	var run := _wake_the_first_sleeper(game)
	var tap: Dictionary = run["tap"]
	assert_eq(tap["object"], FIRST_SLEEPER, "the tap is on the sleeper")
	assert_true(tap["call"], "and calls")
	assert_true(run["first"] in tap["answered"], "the first slime answers")
	assert_gt(run["woke_at"], 0, "the sleeper woke")
	if run["woke_at"] < 0:
		return
	gut.p("woke at tick %d, both back on the train at tick %d" % [run["woke_at"], run["rejoined_at"]])
	assert_eq(run["waker_state"], SlimeBodies.FREE, "woken by the free first slime")
	assert_eq(run["woke_phase"], FreeSlimes.UNSURE, "woken unsure")
	# Up by the sleeper on its ledge (within a slime radius of its height),
	# not on the ground under the ledge, 125 px lower.
	gut.p("the first slime woke it from %s, the sleeper at %s" % [run["first_at"], run["spot"]])
	assert_lt((run["first_at"] as Vector2).y, (run["spot"] as Vector2).y + PlaceholderArt.SLIME_RADIUS,
			"the first slime was up on the ledge")
	assert_gt(run["rejoined_at"], 0, "both rejoined the train")
	var sim: Simulation = game.simulation
	assert_true(sim.train.stalled.is_empty(), "no slime lost")
	assert_eq(sim.identities.members_of(run["sleeper"]), PackedStringArray([FIRST_SLEEPER]))


func test_no_sleeper_wakes_during_a_lap_without_calls() -> void:
	var game := _boot()
	var sim: Simulation = game.simulation
	var first := sim.slimes.ids()[0]
	var woke := []
	for i in range(0, 10 * 60 * TICK_RATE, 30):
		game.test_mode.run_ticks(30)
		if _count(sim, SlimeBodies.SLEEPER) != SLEEPERS:
			woke.append(sim.tick)
			break
		if sim.train.laps_of(first) >= 1:
			break
	assert_gte(sim.train.laps_of(first), 1, "a full lap")
	assert_eq(woke, [], "no sleeper woke")
	assert_true(sim.train.stalled.is_empty())


func test_waking_runs_are_repeatable() -> void:
	var first := _wake_the_first_sleeper(_boot())
	var second := _wake_the_first_sleeper(_boot())
	assert_eq(first["woke_at"], second["woke_at"])
	assert_eq(first["rejoined_at"], second["rejoined_at"])
	assert_eq(first["hash"], second["hash"])
