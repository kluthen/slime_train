extends GutTest
## A scripted scenario for each test-level fixture that only had load-time
## checks (chunk 21): each loads its fixture in test mode, runs ticks (with
## scripted input where the fixture is for one), asserts what the fixture is
## for plays out, and runs it a second time in this process on the same seed
## for the same state hash.
##
## - `stress-moving` (200 size-1 train slimes in section 3's bowl): a
##   measurement, no fps target (D96). The train moves, the population's
##   mass stays 200 in at most 200 slimes, none above size 3, nothing lost,
##   stalled or stuck. The wall time per tick is printed, never asserted.
## - `midair` (four train slimes saved in the air, chunk 19): once loaded they
##   play on, landing between hops (never in the air longer than a hop), the
##   train carries them, none lost, the population whole.
## - `old-version` (a version-1 save, migrated at load, chunk 19): the moved
##   sleeper, put on the train at the loop start, travels the loop; the
##   population stays as loaded and nothing more is lost.
## - `s1-optout` (switch 1 flipped, basket 1 at 3 of 6): a tap on the switch
##   flips it back and the basket lets its slime go.
## - `stress-still` (60 in basket 3, a bedtime pile of 140 in the bowl): the
##   population stays as loaded, in the basket and asleep.
## - `s3-basket-59of60` (basket 3 at 59 of 60, 141 train slimes in the bowl,
##   not at bedtime; chunk 22): with the camera held on basket 3 the train
##   brings the 60th slime, the basket fills, fires and the celebration
##   plays; the population's mass stays 200, none above size 3.
##
## Nothing here saves: no store, no file written.

# @test-link [[req_test_level_and_test_mode]]
# @test-link [[rule_max_200_slimes_per_level]]
# @test-link [[req_persistence_and_saves]]
# @test-link [[rule_released_level_stable_with_migration]]
# @test-link [[rule_saves_never_wiped]]
# @test-link [[req_switch_basket_gate_set]]
# @test-link [[rule_max_size_three]]

const MAIN_SCENE := "res://src/main.tscn"
const SEED := 21
const TICK_RATE := Simulation.TICK_RATE
## The test level's population (chunk 16): the first slime and 199 sleepers.
const POPULATION := 200
## The biggest slime size (master spec: sizes 1 to 3).
const MAX_SIZE := 3
## stress-moving: how long it runs (ticks: about 8 s of wall time a run, the
## bowl's 200 slimes cost about 40 ms a tick headless), how far (px along the
## loop) its slimes advance on average at the least in that time, and the
## share of them that advance at all (a crowd: some wait behind others;
## measured 137 of 179 over 200 ticks).
const STRESS_MOVING_TICKS := 200
const STRESS_MOVING_ADVANCE := 200.0
const STRESS_MOVING_SHARE := 0.5
## midair: the slimes it saves in the air (section 1's first four sleepers,
## awake), how long it runs (ticks), the longest a slime may be off the
## ground in one go once landed (ticks: a hop lasts about half a second),
## and how far along the loop each slime advances at the least (px: a size-1
## slime hops every 1.5 to 3 s, about 150 px a hop; measured 117 to 257).
const MIDAIR_SLIMES := 4
const MIDAIR_TICKS := 300
const LONGEST_HOP := 90
const MIDAIR_ADVANCE := 75.0
## old-version: how long it runs (ticks), and how far along the loop the
## migrated slime advances at the least (px: several hops; measured 573).
const OLD_VERSION_TICKS := 600
const MIGRATED_ADVANCE := 300.0
## s1-optout: frontier set 1 and the camera on its basket (the fixture's
## sidecar point); how long the camera stays there before the tap, and how
## long after it the basket has let its slime go (ticks).
const SWITCH := "s1.switch"
const BASKET := "s1.basket"
const GATE := "s1.gate"
const BASKET_VIEW := Vector2(6.9 * 1152.0, -50.0)
const BEFORE_TAP := TICK_RATE
const RELEASED_WITHIN := 5 * TICK_RATE
## stress-still: how long it runs (ticks), and its population as loaded.
const STRESS_STILL_TICKS := 300
const STILL_IN_BASKET := 60
## s3-basket-59of60: frontier set 3 and the camera where the fixture puts it
## (basket 3's framing zone); how long it runs (ticks: the basket is full
## after about 550, fires 2 s later, the celebration plays 4 s; the rest is
## margin), and the basket's slimes as loaded.
const SWITCH_3 := "s3.switch"
const BASKET_3 := "s3.basket"
const BASKET_3_VIEW := Vector2(15.875 * 1152.0, -150.0)
const ENDGAME_TICKS := 1100
const ENDGAME_IN_BASKET := 59


## A game in test mode on SEED with `fixture`, added to the tree; no store.
func _boot(fixture: String) -> Node:
	var game: Node = load(MAIN_SCENE).instantiate()
	add_child_autofree(game)
	var run := {"seed": SEED, "time_scale": 0, "fixture": fixture}
	assert_eq(game.enable_test_mode(run), PackedStringArray(), fixture + " loads")
	return game


## The weight of every slime of `sim` (their sizes summed).
static func _weight(sim: Simulation) -> int:
	var out := 0
	for slime_id in sim.slimes.ids():
		out += sim.slimes.size_of(slime_id)
	return out


## The biggest slime of `sim`, by size.
static func _biggest(sim: Simulation) -> int:
	var out := 0
	for slime_id in sim.slimes.ids():
		out = maxi(out, sim.slimes.size_of(slime_id))
	return out


## How many slimes of `sim` are in `state`.
static func _count(sim: Simulation, state: int) -> int:
	var n := 0
	for slime_id in sim.slimes.ids():
		if sim.slimes.state_of(slime_id) == state:
			n += 1
	return n


## The ids of `sim`'s slimes that are awake (not sleepers).
static func _awake(sim: Simulation) -> Array:
	var out := []
	for slime_id in sim.slimes.ids():
		if sim.slimes.state_of(slime_id) != SlimeBodies.SLEEPER:
			out.append(slime_id)
	return out


## The loop progress (laps included) of each slime in `ids` the train of
## `sim` follows: slime id -> px.
static func _progress(sim: Simulation, ids: Array) -> Dictionary:
	var out := {}
	for slime_id in ids:
		if sim.train.tracks(slime_id):
			out[slime_id] = sim.train.progress_of(slime_id)
	return out


## The safety nets' logs of `sim` (lost, stalled, stuck), their sizes: a
## case logged since shows as a bigger count.
static func _nets(sim: Simulation) -> Dictionary:
	return {"lost": sim.offscreen.lost.size(), "stalled": sim.train.stalled.size(),
			"stuck": sim.stuck_slimes.stuck.size()}


## Keeps the camera of `game` on `at` (the scripted runs hold it there).
func _aim(game: Node, at: Vector2) -> void:
	game.simulation.camera.place(at, 1.0)
	game.sync_view()


## Taps the middle of switch 1 on the screen, the camera aimed at it first
## (as tests/e2e/test_frontier_e2e.gd does), and returns the tap's record.
func _tap_switch(game: Node) -> Dictionary:
	var sim: Simulation = game.simulation
	var box: Rect2 = sim.level.switches[SWITCH]["box"]
	_aim(game, box.get_center())
	var at := sim.view.world_to_screen(box.get_center())
	sim.push_input(Simulation.touch_down(0, at))
	sim.push_input(Simulation.touch_up(0, at))
	game.test_mode.run_ticks(1)
	return sim.taps[-1]


# --- stress-moving -----------------------------------------------------------------

## Runs stress-moving STRESS_MOVING_TICKS and checks it; returns the game.
## Prints the wall time per tick (a measurement only, never asserted).
func _run_stress_moving(label: String) -> Node:
	var game := _boot("stress-moving")
	var sim: Simulation = game.simulation
	var train := _awake(sim)
	assert_eq(train.size(), POPULATION, label + ": every slime awake")
	var before := _progress(sim, train)
	assert_eq(before.size(), POPULATION, label + ": the train follows all 200")
	var nets := _nets(sim)
	var most := sim.slimes.slime_count
	var biggest := _biggest(sim)
	var started := Time.get_ticks_usec()
	for i in STRESS_MOVING_TICKS:
		game.test_mode.run_ticks(1)
		most = maxi(most, sim.slimes.slime_count)
		biggest = maxi(biggest, _biggest(sim))
	var per_tick := (Time.get_ticks_usec() - started) / 1000.0 / STRESS_MOVING_TICKS
	gut.p("%s: %.2f ms of wall time per tick over %d ticks (%d slimes at the end)"
			% [label, per_tick, STRESS_MOVING_TICKS, sim.slimes.slime_count])
	assert_lte(most, POPULATION, label + ": never more than 200 slimes")
	assert_lte(biggest, MAX_SIZE, label + ": none above size 3")
	assert_eq(_weight(sim), POPULATION, label + ": the mass kept")
	assert_eq(_count(sim, SlimeBodies.TRAIN), sim.slimes.slime_count, label + ": all still on the train")
	assert_eq(_nets(sim), nets, label + ": nothing lost, stalled or stuck")
	var after := _progress(sim, train)
	var advanced := 0.0
	var moved := 0
	for slime_id in after:
		var step: float = after[slime_id] - before[slime_id]
		advanced += step
		if step > 0.0:
			moved += 1
	assert_gt(after.size(), 0, label + ": slimes still followed")
	var mean := advanced / maxf(after.size(), 1.0)
	gut.p("%s: %d of %d slimes advanced, %.0f px on average" % [label, moved, after.size(), mean])
	assert_gt(mean, STRESS_MOVING_ADVANCE, label + ": the train moves along the loop")
	assert_gte(moved, int(STRESS_MOVING_SHARE * after.size()), label + ": most slimes advanced")
	return game


# @test-link [[rule_max_200_slimes_per_level]]
# @test-link [[rule_max_size_three]]
# @test-link [[req_test_level_and_test_mode]]
func test_stress_moving_moves_keeping_its_200_and_runs_the_same_twice() -> void:
	var first := _run_stress_moving("first run")
	var second := _run_stress_moving("second run")
	assert_eq(first.simulation.state_hash(), second.simulation.state_hash(), "same seed, same state")


# --- midair ------------------------------------------------------------------------

## Runs midair MIDAIR_TICKS and checks it; returns the game.
func _run_midair(label: String) -> Node:
	var game := _boot("midair")
	var sim: Simulation = game.simulation
	var awake := _awake(sim).filter(
			func(slime_id): return sim.identities.stable_id_of(slime_id) != "start.first-slime")
	assert_eq(awake.size(), MIDAIR_SLIMES, label + ": the slimes saved in the air")
	var before := _progress(sim, awake)
	assert_eq(before.size(), awake.size(), label + ": the train follows them")
	var nets := _nets(sim)
	assert_eq(nets["lost"], 0, label + ": none lost at load")
	var landed := {}
	var in_air := {}
	var longest := {}
	for slime_id in awake:
		landed[slime_id] = false
		in_air[slime_id] = 0
		longest[slime_id] = 0
	for i in MIDAIR_TICKS:
		game.test_mode.run_ticks(1)
		for slime_id in awake:
			if sim.slimes.body_of(slime_id)["supported"]:
				landed[slime_id] = true
				in_air[slime_id] = 0
			elif landed[slime_id]:
				in_air[slime_id] += 1
				longest[slime_id] = maxi(longest[slime_id], in_air[slime_id])
	gut.p("%s: longest time in the air per slime (ticks): %s" % [label, longest.values()])
	for slime_id in awake:
		var what := "%s: %s" % [label, ", ".join(sim.identities.members_of(slime_id))]
		assert_true(landed[slime_id], what + " lands")
		assert_lte(longest[slime_id], LONGEST_HOP, what + " is never in the air longer than a hop")
		assert_gt(sim.train.progress_of(slime_id) - before[slime_id], MIDAIR_ADVANCE, what + " plays on")
	assert_eq(sim.slimes.slime_count, POPULATION, label + ": every slime")
	assert_eq(_weight(sim), POPULATION, label + ": the population whole")
	assert_eq(_nets(sim), nets, label + ": nothing lost, stalled or stuck")
	return game


# @test-link [[req_persistence_and_saves]]
# @test-link [[req_test_level_and_test_mode]]
func test_midair_slimes_land_and_play_on_the_same_twice() -> void:
	var first := _run_midair("first run")
	var second := _run_midair("second run")
	assert_eq(first.simulation.state_hash(), second.simulation.state_hash(), "same seed, same state")


# --- old-version -------------------------------------------------------------------

## The slime old-version's migration put on the train: the one in the lost
## log (its reason LOST), alone; -1 when not exactly one.
func _migrated(sim: Simulation, label: String) -> int:
	var lost := sim.offscreen.lost.filter(func(entry): return entry["reason"] == Offscreen.LOST)
	assert_eq(lost.size(), 1, label + ": the migration lost one slime")
	return lost[0]["id"] if lost.size() == 1 else -1


## Runs old-version OLD_VERSION_TICKS and checks it; returns the game.
func _run_old_version(label: String) -> Node:
	var game := _boot("old-version")
	var sim: Simulation = game.simulation
	var slime := _migrated(sim, label)
	if slime == -1:
		return game
	assert_eq(sim.slimes.state_of(slime), SlimeBodies.TRAIN, label + ": on the train")
	var count := sim.slimes.slime_count
	var weight := _weight(sim)
	assert_eq(count, POPULATION, label + ": every slime after the migration")
	var members := sim.identities.members_of(slime)
	var start := sim.train.progress_of(slime)
	var nets := _nets(sim)
	game.test_mode.run_ticks(OLD_VERSION_TICKS)
	assert_eq(sim.identities.members_of(slime), members, label + ": still the same slime")
	var advanced := sim.train.progress_of(slime) - start
	gut.p("%s: the migrated slime advanced %.0f px" % [label, advanced])
	assert_gt(advanced, MIGRATED_ADVANCE, label + ": it travels the loop")
	assert_eq(sim.slimes.slime_count, count, label + ": no slime wiped")
	assert_eq(_weight(sim), weight, label + ": every base slime kept")
	assert_eq(_nets(sim), nets, label + ": nothing newly lost, stalled or stuck")
	return game


# @test-link [[rule_released_level_stable_with_migration]]
# @test-link [[rule_saves_never_wiped]]
# @test-link [[req_test_level_and_test_mode]]
func test_old_version_migrated_plays_on_the_same_twice() -> void:
	var first := _run_old_version("first run")
	var second := _run_old_version("second run")
	assert_eq(first.simulation.state_hash(), second.simulation.state_hash(), "same seed, same state")


# --- s1-optout ---------------------------------------------------------------------

## Runs s1-optout's scripted opt-out (the camera on the basket, a tap on the
## switch, the basket lets go) and checks it; returns the game.
func _run_optout(label: String) -> Node:
	var game := _boot("s1-optout")
	var sim: Simulation = game.simulation
	for i in BEFORE_TAP:
		_aim(game, BASKET_VIEW)
		game.test_mode.run_ticks(1)
	assert_eq(sim.object_states[BASKET]["weight"], 3, label + ": basket 1 at 3 of 6")
	assert_eq(_count(sim, SlimeBodies.IN_BASKET), 1, label + ": the size 3 in it")
	assert_true(sim.object_states[SWITCH]["flipped"], label + ": the switch flipped")
	assert_eq(_tap_switch(game)["kind"], TapDispatcher.KIND_SWITCH, label + ": the tap lands on the switch")
	assert_false(sim.object_states[SWITCH]["flipped"], label + ": the tap flips it back")
	for i in RELEASED_WITHIN:
		_aim(game, BASKET_VIEW)
		game.test_mode.run_ticks(1)
	assert_eq(_count(sim, SlimeBodies.IN_BASKET), 0, label + ": released")
	assert_eq(sim.object_states[BASKET]["weight"], 0, label + ": empty")
	assert_false(sim.gate_states[GATE]["open"], label + ": the gate stays shut")
	assert_eq(sim.slimes.slime_count, POPULATION - 2, label + ": the size 3 still whole")
	assert_eq(_weight(sim), POPULATION, label + ": the population whole")
	return game


# @test-link [[req_switch_basket_gate_set]]
# @test-link [[req_test_level_and_test_mode]]
func test_s1_optout_flipping_back_releases_the_same_twice() -> void:
	var first := _run_optout("first run")
	var second := _run_optout("second run")
	assert_eq(first.simulation.state_hash(), second.simulation.state_hash(), "same seed, same state")


# --- stress-still ------------------------------------------------------------------

## Runs stress-still STRESS_STILL_TICKS and checks it; returns the game.
func _run_stress_still(label: String) -> Node:
	var game := _boot("stress-still")
	var sim: Simulation = game.simulation
	assert_eq(sim.slimes.slime_count, POPULATION, label + ": the whole population, awake")
	assert_eq(_count(sim, SlimeBodies.IN_BASKET), STILL_IN_BASKET, label)
	var nets := _nets(sim)
	game.test_mode.run_ticks(STRESS_STILL_TICKS)
	assert_eq(sim.slimes.slime_count, POPULATION, label + ": the count unchanged")
	assert_eq(_weight(sim), POPULATION, label + ": the mass unchanged")
	assert_eq(_count(sim, SlimeBodies.IN_BASKET), STILL_IN_BASKET, label + ": the basket keeps its 60")
	assert_eq(_count(sim, SlimeBodies.BEDTIME_ASLEEP), POPULATION - STILL_IN_BASKET,
			label + ": the pile still asleep")
	assert_eq(_nets(sim), nets, label + ": nothing lost, stalled or stuck")
	return game


# @test-link [[rule_max_200_slimes_per_level]]
# @test-link [[req_test_level_and_test_mode]]
func test_stress_still_keeps_its_population_the_same_twice() -> void:
	var first := _run_stress_still("first run")
	var second := _run_stress_still("second run")
	assert_eq(first.simulation.state_hash(), second.simulation.state_hash(), "same seed, same state")


# --- s3-basket-59of60 --------------------------------------------------------------

## Runs s3-basket-59of60 ENDGAME_TICKS with the camera held on basket 3 and
## checks it: the basket fills, fires, and the celebration plays and ends;
## returns the game.
func _run_endgame(label: String) -> Node:
	var game := _boot("s3-basket-59of60")
	var sim: Simulation = game.simulation
	var basket: Dictionary = sim.object_states[BASKET_3]
	assert_eq(sim.slimes.slime_count, POPULATION, label + ": the whole population, awake")
	assert_eq(_count(sim, SlimeBodies.IN_BASKET), ENDGAME_IN_BASKET, label + ": 59 in basket 3")
	assert_eq(basket["weight"], ENDGAME_IN_BASKET, label + ": basket 3 at 59 of 60")
	assert_ne(sim.session.phase, Session.BEDTIME, label + ": not at bedtime")
	var biggest := _biggest(sim)
	var most := sim.slimes.slime_count
	var full_at := -1
	var fired_at := -1
	for i in ENDGAME_TICKS:
		_aim(game, BASKET_3_VIEW)
		game.test_mode.run_ticks(1)
		biggest = maxi(biggest, _biggest(sim))
		most = maxi(most, sim.slimes.slime_count)
		if full_at < 0 and basket["phase"] != FrontierSets.FILLING:
			full_at = i + 1
		if fired_at < 0 and basket["phase"] == FrontierSets.FIRED:
			fired_at = i + 1
	gut.p("%s: basket 3 full at tick %d, fired at tick %d" % [label, full_at, fired_at])
	assert_gt(full_at, 0, label + ": basket 3 fills")
	assert_gt(fired_at, full_at, label + ": then fires")
	assert_true(sim.frontier.celebration_done, label + ": the celebration played")
	assert_false(sim.frontier.celebration_playing(sim.tick), label + ": and ended")
	assert_true(sim.gate_states["s1.gate"]["open"] and sim.gate_states["s2.gate"]["open"],
			label + ": gates 1 and 2 still open")
	assert_true(sim.object_states[SWITCH_3]["flipped"], label + ": switch 3 still flipped")
	assert_lte(most, POPULATION, label + ": never more than 200 slimes")
	assert_lte(biggest, MAX_SIZE, label + ": none above size 3")
	assert_eq(_weight(sim), POPULATION, label + ": the mass kept")
	return game


# @test-link [[req_switch_basket_gate_set]]
# @test-link [[req_level_completion_celebration]]
# @test-link [[req_test_level_and_test_mode]]
func test_s3_basket_59of60_fills_the_last_basket_and_celebrates_the_same_twice() -> void:
	var first := _run_endgame("first run")
	var second := _run_endgame("second run")
	assert_eq(first.simulation.state_hash(), second.simulation.state_hash(), "same seed, same state")
