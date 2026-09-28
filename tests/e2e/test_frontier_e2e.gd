extends GutTest
## End-to-end on the test level: frontier set 1 (switch, basket, gate)
## through the real game scene and test mode, with the camera on basket 1.
## From `s1-basket-5of6` the first slime drops through the open trapdoor,
## the basket fills, plays its reward, fires, opens gate 1 (the loop grows
## into section 2, slide 1's entrance closes) and lets its slimes go back to
## the loop [DoD 9]; with the camera away it waits and fires once the basket
## comes into view [DoD 10]; from `s1-optout` a tap on the switch flips it
## back and the basket lets its slime go [DoD 11]; no run here tilts [DoD
## 12]; once the gate is open a tap on the switch does nothing and the
## basket takes no more slimes [DoD 13]; the celebration plays once, is
## saved, and a reload doesn't play it again [DoD 14]. The run is the same
## in this process and in a child process (same seed, same hash).

# @test-link [[req_switch_basket_gate_set]]
# @test-link [[req_interactive_objects_general]]
# @test-link [[rule_gate_opens_via_switch_basket_set]]
# @test-link [[rule_frontier_set_inert_after_gate_open]]
# @test-link [[rule_tilt_never_required]]
# @test-link [[req_level_completion_celebration]]

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
## From s1-basket-5of6 the basket fires within this (seconds). Probes: the
## first slime drops in about 5 s after the start, the reward plays 2 s.
const FIRE_WITHIN := 30
## The basket's slimes are all back on the train within this after it fires
## (seconds): five slimes, one every 0.3 s at the least, each once the outlet
## is clear.
const RELEASED_WITHIN := 30
## The child run's length, ticks: past the fire and the releases.
const CHILD_TICKS := 1500
const DIR := "user://test-frontier-e2e/"


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))


func _boot(config := {}) -> Node:
	var game: Node = load(MAIN_SCENE).instantiate()
	add_child_autofree(game)
	var run := {"seed": SEED, "time_scale": 0}
	run.merge(config, true)
	assert_eq(game.enable_test_mode(run), PackedStringArray())
	return game


func _aim(game: Node, at: Vector2) -> void:
	game.simulation.camera.place(at, 1.0)
	game.sync_view()


func _basket(game: Node) -> Dictionary:
	return game.simulation.object_states[BASKET]


## Runs until basket 1 is in `phase`, at most `limit` ticks, re-aiming the
## camera at `aim` each tick when given. Returns the ticks it took, or -1.
func _run_until_phase(game: Node, phase: String, limit: int, aim: Variant = BASKET_VIEW) -> int:
	for i in limit:
		if _basket(game)["phase"] == phase:
			return i
		if aim != null:
			_aim(game, aim)
		game.test_mode.run_ticks(1)
	return -1 if _basket(game)["phase"] != phase else limit


func _count(game: Node, state: int) -> int:
	var n := 0
	for slime_id in game.simulation.slimes.ids():
		if game.simulation.slimes.state_of(slime_id) == state:
			n += 1
	return n


## Taps the middle of switch 1 on the screen.
func _tap_switch(game: Node) -> void:
	var sim: Simulation = game.simulation
	var box: Rect2 = sim.level.switches[SWITCH]["box"]
	var at := sim.view.world_to_screen(box.get_center())
	sim.push_input(Simulation.touch_down(0, at))
	sim.push_input(Simulation.touch_up(0, at))
	game.test_mode.run_ticks(1)


# --- DoD 9: switch, basket, gate, the loop grows --------------------------------------

func test_the_basket_fills_fires_opens_the_gate_and_releases() -> void:
	var game := _boot({"fixture": "s1-basket-5of6"})
	var sim: Simulation = game.simulation
	assert_true(sim.object_states[SWITCH]["flipped"], "the fixture's switch is flipped")
	assert_eq(_basket(game)["weight"], 5)
	var outlines_seen := [5]
	var fired := -1
	for i in FIRE_WITHIN * TICK_RATE:
		_aim(game, BASKET_VIEW)
		game.test_mode.run_ticks(1)
		var weight: int = _basket(game)["weight"]
		if weight != outlines_seen[-1]:
			outlines_seen.append(weight)
		if _basket(game)["phase"] == FrontierSets.FIRED:
			fired = i
			break
	gut.p("fired after %d ticks; weights %s" % [fired, outlines_seen])
	assert_gt(fired, 0, "fires within %d s" % FIRE_WITHIN)
	assert_eq(outlines_seen.slice(0, 2), [5, 6], "the outlines fill by weight: 5, then 6")
	assert_true(sim.gate_states[GATE]["open"], "gate 1 opens")
	assert_true(GATE in sim.train.open_gates)
	var current := sim.level.loop.current_segments(sim.train.open_gates).map(func(s): return s["id"])
	assert_eq(current, ["s1.loop", "s2.loop", "s2.slide"], "the loop grows into section 2; slide 1 unused")
	var released := -1
	for i in RELEASED_WITHIN * TICK_RATE:
		_aim(game, BASKET_VIEW)
		game.test_mode.run_ticks(1)
		if _count(game, SlimeBodies.IN_BASKET) == 0:
			released = i
			break
	assert_gt(released, 0, "the basket lets its slimes go")
	assert_eq(_basket(game)["weight"], 0, "empty")
	assert_true(sim.gate_states[GATE]["entrance_closed"], "slide 1's entrance closes")
	assert_eq(sim.train.lost, [], "no slime lost")
	assert_eq(_count(game, SlimeBodies.TRAIN), 3, "the size 3, the size 2 and the first slime ride on")


# --- DoD 10: a full basket off screen waits for the view -------------------------

func test_a_full_basket_off_screen_fires_when_it_comes_into_view() -> void:
	var game := _boot({"fixture": "s1-basket-5of6"})
	var full := _run_until_phase(game, FrontierSets.FULL, FIRE_WITHIN * TICK_RATE, BASKET_VIEW)
	assert_gt(full, 0, "full")
	_aim(game, AWAY_VIEW)
	for i in 5 * TICK_RATE:
		_aim(game, AWAY_VIEW)
		game.test_mode.run_ticks(1)
	assert_eq(_basket(game)["phase"], FrontierSets.FULL, "waits while off screen")
	assert_false(game.simulation.gate_states[GATE]["open"])
	var fired := _run_until_phase(game, FrontierSets.FIRED, 5 * TICK_RATE, BASKET_VIEW)
	assert_between(fired, 1, int(FrontierSets.REWARD_SECONDS * TICK_RATE) + 2, "the reward, then fires")
	assert_true(game.simulation.gate_states[GATE]["open"])


# --- DoD 11: opting out -------------------------------------------------------------

func test_flipping_the_switch_back_releases_and_empties_the_basket() -> void:
	var game := _boot({"fixture": "s1-optout"})
	var sim: Simulation = game.simulation
	_aim(game, BASKET_VIEW)
	game.test_mode.run_ticks(TICK_RATE)
	assert_eq(_basket(game)["weight"], 3)
	assert_eq(_count(game, SlimeBodies.IN_BASKET), 1)
	_tap_switch(game)
	assert_false(sim.object_states[SWITCH]["flipped"], "the tap flips it back")
	for i in 5 * TICK_RATE:
		_aim(game, BASKET_VIEW)
		game.test_mode.run_ticks(1)
	assert_eq(_count(game, SlimeBodies.IN_BASKET), 0, "released")
	assert_eq(_basket(game)["weight"], 0, "empty")
	assert_eq(_basket(game)["phase"], FrontierSets.FILLING, "not full, nothing fired")
	assert_true(sim.object_states[SWITCH]["trapdoor_shut"], "the flow goes on again")
	assert_false(sim.gate_states[GATE]["open"])
	assert_eq(sim.tilt_degrees, 0.0, "no tilt [DoD 12]")


# --- DoD 13: inert once the gate is open ------------------------------------------

func test_once_the_gate_is_open_the_switch_does_nothing_and_the_basket_takes_nothing() -> void:
	var game := _boot({"fixture": "s1-basket-5of6"})
	var sim: Simulation = game.simulation
	assert_gt(_run_until_phase(game, FrontierSets.FIRED, FIRE_WITHIN * TICK_RATE), 0)
	assert_eq(sim.tilt_degrees, 0.0, "the gate opened without tilt [DoD 12]")
	var before: Dictionary = sim.object_states[SWITCH].duplicate()
	_aim(game, BASKET_VIEW)
	_tap_switch(game)
	assert_eq(sim.object_states[SWITCH]["flipped"], before["flipped"], "the tap does nothing")
	# A slime dropped straight into the basket is let go again.
	var box: Rect2 = sim.level.baskets[BASKET]["box"]
	var dropped := sim.slimes.create(Species.from_letter("D"), 1, box.get_center(), SlimeBodies.TRAIN)
	for i in RELEASED_WITHIN * TICK_RATE:
		_aim(game, BASKET_VIEW)
		game.test_mode.run_ticks(1)
		if _count(game, SlimeBodies.IN_BASKET) == 0:
			break
	assert_eq(_count(game, SlimeBodies.IN_BASKET), 0, "the basket takes no more slimes")
	assert_eq(sim.slimes.state_of(dropped), SlimeBodies.TRAIN)
	assert_eq(_basket(game)["phase"], FrontierSets.FIRED, "still fired")
	assert_true(sim.gate_states[GATE]["open"], "still open")


# --- DoD 14: the celebration, once --------------------------------------------------

func test_the_celebration_plays_once_and_a_reload_does_not_replay_it() -> void:
	var game := _boot({"fixture": "s1-basket-5of6"})
	var sim: Simulation = game.simulation
	assert_false(sim.frontier.celebration_done)
	assert_gt(_run_until_phase(game, FrontierSets.FIRED, FIRE_WITHIN * TICK_RATE), 0)
	assert_true(sim.frontier.celebration_done, "the last basket fired: the celebration")
	assert_true(sim.frontier.celebration_playing(sim.tick))
	var since := sim.frontier.celebration_since
	game.test_mode.run_ticks(int(FrontierSets.CELEBRATION_SECONDS * TICK_RATE) + 1)
	assert_false(sim.frontier.celebration_playing(sim.tick), "it ends")
	assert_eq(sim.frontier.celebration_since, since, "played once")
	var path := ProjectSettings.globalize_path(DIR + "celebrated.json")
	assert_eq(SaveStore.write_file(path, sim.to_save()), "")
	var reloaded := _boot({"load": path})
	var again: Simulation = reloaded.simulation
	assert_true(again.frontier.celebration_done, "recorded in the save")
	# The same world (the first-play hint restarts its count when the reloaded
	# world shows, by design, so the whole hash isn't compared here).
	var was := sim.dump()
	var now := again.dump()
	for key in ["tick", "objects", "gates", "frontier", "slimes", "train"]:
		assert_eq(StateHash.of(now[key]), StateHash.of(was[key]), "the same %s" % key)
	reloaded.test_mode.run_ticks(10 * TICK_RATE)
	assert_false(again.frontier.celebration_playing(again.tick), "not replayed")
	assert_eq(again.frontier.celebration_since, since)
	assert_eq(again.object_states[BASKET]["phase"], FrontierSets.FIRED, "the world keeps running")


# --- Same seed, same hash -------------------------------------------------------------

func test_the_fixture_run_is_the_same_in_a_child_process() -> void:
	var args := PackedStringArray([
		"--headless", "--quit-after", "6000", "--path", ProjectSettings.globalize_path("res://"), "--",
		"--test-mode", "--seed=%d" % SEED, "--fixture=s1-basket-5of6", "--run-ticks=%d" % CHILD_TICKS,
	])
	var output := []
	var code := OS.execute(OS.get_executable_path(), args, output, true)
	var text := "\n".join(output)
	var line := RegEx.create_from_string("STATE tick=(\\d+) hash=([0-9a-f]{64})").search(text)
	assert_eq(code, 0, "child exit code")
	assert_not_null(line, "no STATE line in:\n%s" % text)
	if line == null:
		return
	var game := _boot({"fixture": "s1-basket-5of6"})
	game.test_mode.run_ticks(CHILD_TICKS)
	var sim: Simulation = game.simulation
	gut.p("child run: basket %s, gate %s" % [sim.object_states[BASKET], sim.gate_states[GATE]])
	assert_eq(sim.object_states[BASKET]["phase"], FrontierSets.FIRED, "the run reaches the fire")
	assert_eq(line.get_string(1).to_int(), CHILD_TICKS)
	assert_eq(line.get_string(2), sim.state_hash(), "same seed, same hash across processes")
