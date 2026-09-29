extends GutTest
## Baskets at bedtime (item 23.5, D105; master spec §5.4, §5.7) through the
## real game scene and test mode, on the test level's frontier set 1. From
## `bedtime`, basket 1 letting two slimes go (its switch not flipped, the
## opt-out) releases none until sunrise, and they stay in it through sunrise,
## then leave one by one. From `s1-basket-5of6`, a basket full and in view at
## bedtime plays no reward and opens no gate until sunrise, then both happen;
## a save taken during bedtime reloads the same. The runs are repeatable.

# @test-link [[req_switch_basket_gate_set]]
# @test-link [[req_session_lifecycle]]
# @test-link [[req_slime_states]]
# @test-link [[req_persistence_and_saves]]

const MAIN_SCENE := "res://src/main.tscn"
const SEED := 14
const TICK_RATE := Simulation.TICK_RATE
const SWITCH := "s1.switch"
const BASKET := "s1.basket"
const GATE := "s1.gate"
## The camera on basket 1 (the fixtures' sidecar point).
const BASKET_VIEW := Vector2(6.9 * 1152.0, -50.0)
## Far from basket 1: the start basin.
const AWAY_VIEW := Vector2(0.4 * 1152.0, 400.0)
## How long the tests watch bedtime, seconds.
const WATCH := 10
const DIR := "user://test-frontier-bedtime-e2e/"


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))


func _boot(config := {}) -> Node:
	var game: Node = load(MAIN_SCENE).instantiate()
	add_child_autofree(game)
	var run := {"seed": SEED, "time_scale": 0}
	run.merge(config, true)
	assert_eq(game.enable_test_mode(run), PackedStringArray())
	return game


## Runs `ticks` ticks with the camera held at `at`.
func _watch(game: Node, at: Vector2, ticks: int) -> void:
	for i in ticks:
		game.simulation.camera.place(at, 1.0)
		game.sync_view()
		game.test_mode.run_ticks(1)


func _in_basket(sim: Simulation) -> PackedInt32Array:
	var out := PackedInt32Array()
	for slime_id in sim.slimes.ids():
		if sim.slimes.state_of(slime_id) == SlimeBodies.IN_BASKET:
			out.append(slime_id)
	return out


## From `bedtime`: two slimes put in basket 1, whose switch isn't flipped, so
## the basket is letting them go (as after an opt-out).
func _bedtime_with_a_releasing_basket() -> Node:
	var game := _boot({"fixture": "bedtime"})
	var sim: Simulation = game.simulation
	assert_eq(sim.session.phase, Session.BEDTIME)
	assert_false(sim.object_states[SWITCH]["flipped"])
	var box: Rect2 = sim.level.baskets[BASKET]["box"]
	for dx in [-60.0, 60.0]:
		sim.slimes.create(Species.from_letter("C"), 1, box.get_center() + Vector2(dx, 0.0), SlimeBodies.IN_BASKET)
	return game


# --- Releases pause at bedtime ----------------------------------------------------

func test_from_bedtime_a_releasing_basket_lets_no_slime_go_until_sunrise() -> void:
	var game := _bedtime_with_a_releasing_basket()
	var sim: Simulation = game.simulation
	var caught := _in_basket(sim)
	assert_eq(caught.size(), 2)
	_watch(game, BASKET_VIEW, WATCH * TICK_RATE)
	assert_eq(sim.session.phase, Session.BEDTIME)
	assert_eq(_in_basket(sim), caught, "no slime released at bedtime")
	sim.session.jump(sim, Session.SUNRISE_MS)
	assert_eq(sim.session.phase, Session.SCREENSAVER, "sunrise")
	assert_eq(_in_basket(sim), caught, "sunrise doesn't move them out of the basket")
	var left := {}
	for i in 5 * TICK_RATE:
		_watch(game, BASKET_VIEW, 1)
		for slime_id in caught:
			if not left.has(slime_id) and sim.slimes.state_of(slime_id) == SlimeBodies.TRAIN:
				left[slime_id] = sim.tick
	assert_eq(left.size(), 2, "then the releases resume: both leave")
	if left.size() == 2:
		assert_lt(left[caught[0]], left[caught[1]], "one at a time, the lowest id first")
	assert_eq(sim.object_states[BASKET]["weight"], 0, "the basket is empty")


func test_a_bedtime_run_with_a_releasing_basket_is_repeatable() -> void:
	var hashes := []
	for run in 2:
		var game := _bedtime_with_a_releasing_basket()
		var sim: Simulation = game.simulation
		_watch(game, BASKET_VIEW, 2 * TICK_RATE)
		sim.session.jump(sim, Session.SUNRISE_MS)
		_watch(game, BASKET_VIEW, 3 * TICK_RATE)
		hashes.append(sim.state_hash())
	assert_eq(hashes[0], hashes[1], "same seed, same hash")


# --- A reward due waits for sunrise ------------------------------------------------

func test_a_full_basket_in_view_at_bedtime_waits_for_sunrise_to_fire_and_open_its_gate() -> void:
	var game := _boot({"fixture": "s1-basket-5of6"})
	var sim: Simulation = game.simulation
	# The first slime drops in about 5 s after the start and the basket is
	# full; the camera then goes away, so its reward is due, not playing.
	for i in 30 * TICK_RATE:
		if sim.object_states[BASKET]["phase"] == FrontierSets.FULL:
			break
		_watch(game, BASKET_VIEW, 1)
	_watch(game, AWAY_VIEW, 1)
	assert_eq(sim.object_states[BASKET]["phase"], FrontierSets.FULL, "full, off screen")
	var caught := _in_basket(sim)
	sim.session.start(sim)
	sim.session.jump(sim, Session.BEDTIME_MS)
	assert_eq(sim.session.phase, Session.BEDTIME)
	_watch(game, BASKET_VIEW, WATCH * TICK_RATE)
	assert_eq(sim.object_states[BASKET]["phase"], FrontierSets.FULL, "in view at bedtime: no reward")
	assert_false(sim.gate_states[GATE]["open"], "no gate opens during bedtime")
	assert_eq(_in_basket(sim), caught, "its slimes stay in it")
	# A save taken now reloads the same.
	var path := ProjectSettings.globalize_path(DIR + "bedtime-full.json")
	assert_eq(SaveStore.write_file(path, sim.to_save()), "")
	var reloaded := _boot({"load": path})
	var again: Simulation = reloaded.simulation
	assert_eq(again.session.phase, Session.BEDTIME)
	var was := sim.dump()
	var now := again.dump()
	for key in ["tick", "objects", "gates", "frontier", "slimes", "train", "session"]:
		assert_eq(StateHash.of(now[key]), StateHash.of(was[key]), "the reload has the same %s" % key)
	for run: Node in [game, reloaded]:
		var played: Simulation = run.simulation
		played.session.jump(played, Session.SUNRISE_MS)
		assert_eq(_in_basket(played), caught, "sunrise doesn't move them out")
		var fired := -1
		for i in 5 * TICK_RATE:
			_watch(run, BASKET_VIEW, 1)
			if played.object_states[BASKET]["phase"] == FrontierSets.FIRED:
				fired = i
				break
		assert_between(fired, 1, int(FrontierSets.REWARD_SECONDS * TICK_RATE) + 2, "at sunrise: the reward, then it fires")
		assert_true(played.gate_states[GATE]["open"], "and gate 1 opens")
	for key in ["tick", "objects", "gates", "frontier", "slimes", "train", "session"]:
		assert_eq(StateHash.of(again.dump()[key]), StateHash.of(sim.dump()[key]), "and goes on the same: %s" % key)
