extends GutTest
## End-to-end on the test level: physics only on or near the screen (chunk
## 15), through the real game scene and test mode. From `s2-basket-offscreen`,
## with the camera held on switch 2, the first slime rides on off screen,
## drops through trapdoor 2 and fills basket 2 there; the basket waits FULL
## until the camera shows it, then plays its reward, fires and opens gate 2
## [DoD 10]. From `s2-cave-return`, with the camera away, the cave's three
## free slimes follow the route back at the off-screen pace, are left alone
## after 10 s and rejoin the train before they could be lost [DoD 5]; the
## camera coming back simulates one again where it got to. From `lost`, a
## free slime with no route back near is left alone at 10 s and lost 1 min
## later, moved to the start of the loop; followed by the camera it is never
## lost [DoD 5]. Saves keep the off-screen state; same seed, same hash, in
## this process and in a child process.

# @test-link [[req_offscreen_simulation]]
# @test-link [[rule_left_alone_and_lost]]
# @test-link [[req_switch_basket_gate_set]]

const MAIN_SCENE := "res://src/main.tscn"
const SEED := 14
const TICK_RATE := Simulation.TICK_RATE
const S := 1152.0
const BASKET_2 := "s2.basket"
const GATE_2 := "s2.gate"
const CAVE_ROUTE := "s2.route-back.cave"
## The camera on switch 2 (the s2-basket-offscreen sidecar point): basket 2
## is more than a screen to the right, off screen.
const SWITCH_2_VIEW := Vector2(10.97 * S, -150.0)
## The camera on basket 2.
const BASKET_2_VIEW := Vector2(12.4 * S, -50.0)
## Far from section 2: the start basin.
const AWAY_VIEW := Vector2(0.4 * S, 400.0)
## Basket 2 is full within this (seconds). Probes: about 26 s.
const FULL_WITHIN := 45
## Once the camera shows basket 2, it fires within this (seconds). Probes:
## about 2 s (the reward plays 2 s).
const FIRE_WITHIN := 10
## The cave's slimes are back on the train within this (seconds). Probes:
## about 33 s from their shelf; they'd be lost at 70 s.
const REJOIN_WITHIN := 60
## A lost slime is back this close to the start of the loop, px (lifted by
## its size; it has not moved yet).
const AT_LOOP_START := 24.0
## The lost fixture's slime is followed this long by the camera (seconds).
const FOLLOW_FOR := 80
## The child runs' lengths, ticks: past basket 2's fill, past the loss.
const CHILD_BASKET_TICKS := 1700
const CHILD_LOST_TICKS := 4300
const DIR := "user://test-offscreen-e2e/"


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))


func _boot(config := {}) -> Node:
	var game: Node = load(MAIN_SCENE).instantiate()
	game.save_store = null
	add_child_autofree(game)
	var run := {"seed": SEED, "time_scale": 0}
	run.merge(config, true)
	assert_eq(game.enable_test_mode(run), PackedStringArray())
	return game


func _aim(game: Node, at: Vector2) -> void:
	game.simulation.camera.place(at, 1.0)
	game.sync_view()


## Runs `ticks` ticks with the camera held on `at`.
func _hold(game: Node, at: Vector2, ticks: int) -> void:
	for i in ticks:
		_aim(game, at)
		game.test_mode.run_ticks(1)


func _ids_in(sim: Simulation, state: int) -> Array:
	var ids := []
	for slime_id in sim.slimes.ids():
		if sim.slimes.state_of(slime_id) == state:
			ids.append(slime_id)
	return ids


func _shown(sim: Simulation) -> Rect2:
	return Fusion.view_rect(sim.view)


func _run_child(fixture: String, ticks: int) -> RegExMatch:
	var args := PackedStringArray([
		"--headless", "--quit-after", "20000", "--path", ProjectSettings.globalize_path("res://"), "--",
		"--test-mode", "--seed=%d" % SEED, "--fixture=%s" % fixture, "--run-ticks=%d" % ticks,
	])
	var output := []
	var code := OS.execute(OS.get_executable_path(), args, output, true)
	var text := "\n".join(output)
	assert_eq(code, 0, "child exit code")
	var line := RegEx.create_from_string("STATE tick=(\\d+) hash=([0-9a-f]{64})").search(text)
	assert_not_null(line, "no STATE line in:\n%s" % text)
	return line


# --- DoD 10: a basket fills off screen, fires in view ---------------------------------

func test_a_basket_fills_off_screen_and_fires_once_it_comes_into_view() -> void:
	var game := _boot({"fixture": "s2-basket-offscreen"})
	var sim: Simulation = game.simulation
	var first: int = _ids_in(sim, SlimeBodies.TRAIN)[0]
	var basket: Dictionary = sim.level.baskets[BASKET_2]
	var centre := (basket["box"] as Rect2).get_center()
	var was_parked := false
	var full_at := -1
	for i in FULL_WITHIN * TICK_RATE:
		_aim(game, SWITCH_2_VIEW)
		game.test_mode.run_ticks(1)
		was_parked = was_parked or sim.slimes.is_parked(first)
		if sim.object_states[BASKET_2]["phase"] == FrontierSets.FULL:
			full_at = sim.tick
			break
	gut.p("basket 2 full at tick %d" % full_at)
	assert_gt(full_at, 0, "basket 2 filled")
	assert_true(was_parked, "the first slime rode on off screen")
	assert_false(_shown(sim).has_point(centre), "basket 2 is off screen")
	assert_eq(sim.slimes.state_of(first), SlimeBodies.IN_BASKET, "the first slime is in the basket")
	assert_gte(int(sim.object_states[BASKET_2]["weight"]), int(basket["quota"]), "weighed off screen")
	_hold(game, SWITCH_2_VIEW, 5 * TICK_RATE)
	assert_eq(sim.object_states[BASKET_2]["phase"], FrontierSets.FULL, "it waits, full, out of view")
	assert_false(sim.gate_states[GATE_2]["open"], "gate 2 still closed")
	var fired_in := -1
	var saw_reward := false
	for i in FIRE_WITHIN * TICK_RATE:
		_aim(game, BASKET_2_VIEW)
		game.test_mode.run_ticks(1)
		saw_reward = saw_reward or sim.object_states[BASKET_2]["phase"] == FrontierSets.REWARD
		if sim.object_states[BASKET_2]["phase"] == FrontierSets.FIRED:
			fired_in = i + 1
			break
	gut.p("fired %d ticks after the camera came" % fired_in)
	assert_gt(fired_in, 0, "in view, it fires")
	assert_true(saw_reward, "after its reward")
	assert_true(sim.gate_states[GATE_2]["open"], "gate 2 opens")
	var grown := []
	for segment in sim.level.loop.current_segments(sim.train.open_gates):
		grown.append(segment["id"])
	assert_true("s3.loop" in grown, "the loop grows into section 3")


# --- DoD 5: back by the route, left alone, lost ---------------------------------------

func test_free_slimes_off_screen_follow_the_route_back_and_rejoin_before_they_are_lost() -> void:
	var game := _boot({"fixture": "s2-cave-return"})
	var sim: Simulation = game.simulation
	var free := _ids_in(sim, SlimeBodies.FREE)
	assert_eq(free.size(), 3, "the cave's three free slimes")
	_hold(game, AWAY_VIEW, 1)
	for slime_id in free:
		assert_true(sim.slimes.is_parked(slime_id), "%d is parked" % slime_id)
		assert_true(sim.offscreen.proxies.has(slime_id), "%d follows a way back" % slime_id)
		if sim.offscreen.proxies.has(slime_id):
			assert_eq(sim.offscreen.proxies[slime_id]["route"], CAVE_ROUTE, "the cave's route back")
	_hold(game, AWAY_VIEW, Offscreen.LEFT_ALONE_TICKS)
	for slime_id in free:
		assert_eq(sim.slimes.state_of(slime_id), SlimeBodies.FREE)
		assert_true(sim.offscreen.is_left_alone(slime_id, sim.tick), "%d left alone after 10 s" % slime_id)
	var rejoined := {}
	for i in (REJOIN_WITHIN * TICK_RATE):
		_aim(game, AWAY_VIEW)
		game.test_mode.run_ticks(1)
		for slime_id in free:
			if not rejoined.has(slime_id) and sim.slimes.state_of(slime_id) == SlimeBodies.TRAIN:
				rejoined[slime_id] = sim.tick
		if rejoined.size() == free.size():
			break
	gut.p("rejoined at %s" % rejoined)
	assert_eq(rejoined.size(), free.size(), "all back on the train")
	for slime_id in rejoined:
		assert_lt(rejoined[slime_id], Offscreen.LEFT_ALONE_TICKS + Offscreen.LOST_TICKS, "before being lost")
	assert_eq(sim.offscreen.lost, [] as Array[Dictionary], "none lost")


func test_the_camera_coming_back_simulates_a_returning_slime_where_it_got_to() -> void:
	var game := _boot({"fixture": "s2-cave-return"})
	var sim: Simulation = game.simulation
	var free := _ids_in(sim, SlimeBodies.FREE)
	var start := sim.slimes.centre_of(free[0])
	_hold(game, AWAY_VIEW, 15 * TICK_RATE)
	var slime: int = free[0]
	var there := sim.slimes.centre_of(slime)
	assert_true(sim.slimes.is_parked(slime))
	assert_gt(there.distance_to(start), 300.0, "it went some way along the route")
	_hold(game, there, 1)
	assert_false(sim.slimes.is_parked(slime), "simulated again in view")
	assert_eq(sim.slimes.state_of(slime), SlimeBodies.FREE, "still free")
	assert_false(sim.offscreen.proxies.has(slime), "no longer a proxy")
	assert_false(sim.offscreen.is_left_alone(slime, sim.tick), "on screen: not left alone")
	_hold(game, there, 2 * TICK_RATE)
	assert_lt(sim.slimes.centre_of(slime).distance_to(there), 200.0, "where it got to")
	assert_eq(sim.offscreen.lost, [] as Array[Dictionary])


func test_with_no_route_near_a_free_slime_is_left_alone_then_lost_to_the_loop_start() -> void:
	var game := _boot({"fixture": "lost"})
	var sim: Simulation = game.simulation
	var free := _ids_in(sim, SlimeBodies.FREE)
	assert_eq(free.size(), 1)
	var slime: int = free[0]
	var start := sim.slimes.centre_of(slime)
	var alone_at := -1
	var lose_at := Offscreen.LEFT_ALONE_TICKS + Offscreen.LOST_TICKS
	while sim.tick < lose_at - 1:
		_aim(game, AWAY_VIEW)
		game.test_mode.run_ticks(1)
		if alone_at < 0 and sim.offscreen.is_left_alone(slime, sim.tick):
			alone_at = sim.tick
	gut.p("left alone at tick %d" % alone_at)
	assert_between(alone_at, Offscreen.LEFT_ALONE_TICKS - 1, Offscreen.LEFT_ALONE_TICKS + 1, "left alone at 10 s")
	assert_eq(sim.slimes.state_of(slime), SlimeBodies.FREE, "not yet lost at %d" % sim.tick)
	assert_lt(sim.slimes.centre_of(slime).distance_to(start), 1.0, "no way back: it stayed put")
	var ticks := 0
	while sim.slimes.state_of(slime) == SlimeBodies.FREE and ticks < 2 * TICK_RATE:
		_aim(game, AWAY_VIEW)
		game.test_mode.run_ticks(1)
		ticks += 1
	# Offscreen steps at the start of a tick: the loss is logged with the tick
	# that just ran (sim.tick - 1).
	var lost_at := sim.tick - 1
	gut.p("lost at tick %d" % lost_at)
	assert_lte(absi(lost_at - lose_at), 1, "lost 1 min after being left alone")
	assert_eq(sim.slimes.state_of(slime), SlimeBodies.TRAIN, "back on the train")
	var loop_start := sim.train.position_at(0.0) + Vector2(0.0, -Offscreen.lift(sim.slimes.size_of(slime)))
	assert_lt(sim.slimes.centre_of(slime).distance_to(loop_start), AT_LOOP_START, "at the start of the loop")
	assert_eq(sim.offscreen.lost.size(), 1, "logged")
	if sim.offscreen.lost.size() == 1:
		assert_eq(sim.offscreen.lost[0], {"id": slime, "tick": lost_at, "reason": Offscreen.LOST})


func test_a_free_slime_that_stays_on_screen_is_never_lost() -> void:
	var game := _boot({"fixture": "lost"})
	var sim: Simulation = game.simulation
	var slime: int = _ids_in(sim, SlimeBodies.FREE)[0]
	var alone := false
	for i in FOLLOW_FOR * TICK_RATE:
		_aim(game, sim.slimes.centre_of(slime))
		game.test_mode.run_ticks(1)
		alone = alone or sim.offscreen.is_left_alone(slime, sim.tick)
	assert_false(alone, "never left alone")
	assert_eq(sim.offscreen.lost, [] as Array[Dictionary], "never lost")
	assert_eq(sim.slimes.state_of(slime), SlimeBodies.FREE, "still free where it was")


# --- Saves and determinism ------------------------------------------------------------

func test_a_save_keeps_the_off_screen_state() -> void:
	var game := _boot({"fixture": "s2-cave-return"})
	var sim: Simulation = game.simulation
	_hold(game, AWAY_VIEW, 12 * TICK_RATE)
	assert_false(sim.offscreen.proxies.is_empty(), "slimes are on their way back")
	var path := ProjectSettings.globalize_path(DIR + "offscreen.json")
	assert_eq(SaveStore.write_file(path, sim.to_save()), "")
	var reloaded := _boot({"load": path})
	var again: Simulation = reloaded.simulation
	assert_eq(StateHash.of(again.offscreen.dump()), StateHash.of(sim.offscreen.dump()), "the same off-screen state")
	for slime_id in sim.offscreen.proxies:
		assert_true(again.slimes.is_parked(slime_id), "%d parked again" % slime_id)
	_hold(game, AWAY_VIEW, 20 * TICK_RATE)
	_hold(reloaded, AWAY_VIEW, 20 * TICK_RATE)
	# The first-play hint restarts its count when a reloaded world shows (by
	# design), so the whole hash isn't compared.
	var was := sim.dump()
	var now := again.dump()
	for key in ["tick", "slimes", "train", "offscreen"]:
		assert_eq(StateHash.of(now[key]), StateHash.of(was[key]), "the same %s" % key)


func test_the_same_seed_gives_the_same_hash_in_process() -> void:
	var hashes := []
	for run in 2:
		var game := _boot({"fixture": "s2-cave-return"})
		_hold(game, AWAY_VIEW, 40 * TICK_RATE)
		hashes.append(game.simulation.state_hash())
	assert_eq(hashes[0], hashes[1])


func test_the_basket_run_is_the_same_in_a_child_process() -> void:
	var line := _run_child("s2-basket-offscreen", CHILD_BASKET_TICKS)
	if line == null:
		return
	var game := _boot({"fixture": "s2-basket-offscreen"})
	game.test_mode.run_ticks(CHILD_BASKET_TICKS)
	var sim: Simulation = game.simulation
	gut.p("child run: basket 2 %s" % sim.object_states[BASKET_2])
	assert_gt(int(sim.object_states[BASKET_2]["weight"]), 14, "the first slime reached basket 2")
	assert_eq(line.get_string(1).to_int(), CHILD_BASKET_TICKS)
	assert_eq(line.get_string(2), sim.state_hash(), "same seed, same hash across processes")


func test_the_lost_run_is_the_same_in_a_child_process() -> void:
	var line := _run_child("lost", CHILD_LOST_TICKS)
	if line == null:
		return
	var game := _boot({"fixture": "lost"})
	game.test_mode.run_ticks(CHILD_LOST_TICKS)
	var sim: Simulation = game.simulation
	assert_eq(sim.offscreen.lost.size(), 1, "the run reaches the loss")
	assert_eq(line.get_string(1).to_int(), CHILD_LOST_TICKS)
	assert_eq(line.get_string(2), sim.state_hash(), "same seed, same hash across processes")
