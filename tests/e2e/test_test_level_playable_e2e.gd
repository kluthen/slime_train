extends GutTest
## Chunk TL1: the test level is playable from a fresh game by calls alone
## (level rule 12's proposed line, D127; specs/levels/test/README.md,
## "Planned change (chunk TL1)"). Played through the real game scene in test
## mode, headless, time held (only run_ticks() moves it), no tilt:
## - section 1 from `fresh` (the first slime alone): calls wake the sleepers
##   a called base slime reaches, a tap flips switch 1, basket 1 fills to its
##   quota, fires, and gate 1 opens;
## - section 2 from `gate1-open`, the same until gate 2 opens;
## - section 3 from `gate2-open`, the same until basket 3 fires and the
##   level's celebration plays.
## Which sleepers to call is the progress estimate's (LevelProgress, the
## level-rules checker's rule 12) with the train never fusing (max size 1):
## a call's slimes don't have to fuse for the level to be finished. Each
## call is made the way a player would: the camera on the spot, a tap on a
## sleeper when a train slime is at the loop point its called hop takes off
## from (LevelProgress.take_off); a woken sleeper wakes the ones lined up
## touching it (LevelProgress.chain), so one call wakes the whole line. It
## also checks that the level-rules checker gives the test level no warning.
##
## Before chunk TL1 section 1 held only two sleepers a called base slime
## could reach, so basket 1 (quota 6) could never fill from fresh.
##
## About 3 minutes in all (docs/dev/README.md, "Chunk TL1").
# @test-link [[req_test_level_and_test_mode]]
# @test-link [[rule_gate_opens_via_switch_basket_set]]
# @test-link [[req_switch_basket_gate_set]]
# @test-link [[req_waking_sleepers]]
# @test-link [[req_level_design_rules]]
# @test-link [[req_call_mechanic]]
# @test-link [[req_level_completion_celebration]]

const LEVEL_ID := "test"
const MAIN_SCENE := "res://src/main.tscn"
const SEED := 1
const TICK_RATE := Simulation.TICK_RATE
## Each section's starting fixture.
const FIXTURES := {1: "fresh", 2: "gate1-open", 3: "gate2-open"}
## The longest wait for a train slime at a call's take-off point: about a
## lap of the longest loop (size 1, 340 s).
const LAP_TICKS := 360 * TICK_RATE
## How long a call has to wake its line of sleepers.
const CALL_TICKS := 15 * TICK_RATE
## Passes over the sleepers to call (a call can miss: the next pass tries
## again).
const WAKE_TRIES := 3
## How close to the take-off point a train slime must be, px.
const NEAR := 40.0
## How long the basket has to fill and fire once its switch is flipped: a
## lap and a half of the longest loop.
const FILL_TICKS := 510 * TICK_RATE
## The camera's zoom while calling: wide enough to hold a long line of
## sleepers (the bowl's ledge, 0.9 screens) and its take-off point.
const CALL_ZOOM := 0.7


func test_section_1_from_fresh_fills_basket_1_and_opens_gate_1() -> void:
	_play(1)


func test_section_2_from_gate1_open_fills_basket_2_and_opens_gate_2() -> void:
	_play(2)


func test_section_3_from_gate2_open_fills_basket_3_and_the_level_celebrates() -> void:
	_play(3)


func test_the_rules_checker_gives_the_test_level_no_warning() -> void:
	var level: Level = load(LevelCatalog.scene_path(LEVEL_ID)).instantiate()
	add_child_autofree(level)
	var results := LevelChecker.new(level).check_all()
	var warned := results.filter(func(result): return not result["warnings"].is_empty())
	assert_eq(LevelChecker.warning_count(results), 0, "the checker's warnings:\n" + LevelChecker.format(warned))
	for one in LevelProgress.estimate(LevelChecker.new(level), 1):
		gut.p("section %d with base slimes only: %d awake by basket %s (quota %d)" % [one["section"],
				one["available"], one["basket"], one["quota"]])
		assert_true(one["progresses"], "section %d fills its basket with base slimes only" % one["section"])


# --- Playing a section ------------------------------------------------------

## Plays section `section` from its fixture: calls wake the sleepers the
## estimate counts on, then the switch is flipped and the basket fills and
## fires (the gate opens; the last basket: the celebration plays).
func _play(section: int) -> void:
	var started := Time.get_ticks_msec()
	var game := _boot(FIXTURES[section])
	var sim: Simulation = game.simulation
	if game.test_mode == null:
		return
	var checker := LevelChecker.new(game.level)
	var plan: Dictionary = LevelProgress.estimate(checker, 1)[section - 1]
	gut.p("section %d (estimate, base slimes only): %d awake by then, quota %d" % [section, plan["available"],
			plan["quota"]])
	assert_true(plan["progresses"], "the estimate: section %d fills its basket with base slimes" % section)
	var asleep: Array = plan["woken"].filter(func(id): return _slime(sim, id) >= 0 \
			and sim.slimes.state_of(_slime(sim, id)) == SlimeBodies.SLEEPER)
	for attempt in WAKE_TRIES:
		for id in _callers(checker, section, asleep):
			if id in asleep:
				_wake(game, checker, section, id)
			asleep = asleep.filter(func(other): return sim.slimes.state_of(_slime(sim, other)) == SlimeBodies.SLEEPER)
	assert_eq(asleep, [], "every sleeper the estimate counts on is woken by calls from the loop")
	var weight := _base_slimes_awake(sim)
	gut.p("section %d: %d base slimes awake after the calls (tick %d)" % [section, weight, sim.tick])
	assert_true(weight >= plan["quota"], "enough base slimes awake for the quota (%d)" % plan["quota"])
	var basket: String = plan["basket"]
	var switch := LevelStates.switch_of(sim.level, basket)
	_tap_centre(game, sim.level.switches[switch]["box"])
	assert_true(sim.object_states[switch]["flipped"], "the tap on %s flips it" % switch)
	var gate := "s%d.gate" % section
	var done := func(): return sim.object_states[basket]["phase"] == FrontierSets.FIRED \
			and (sim.frontier.celebration_done if not sim.level.gates.has(gate) else sim.gate_states[gate]["open"])
	var ticks := _run_until(game, done, FILL_TICKS, sim.level.baskets[basket]["box"].get_center(), 1.0)
	gut.p("%s: phase %s, weight %d after %d ticks; %d s real time in all" % [basket,
			sim.object_states[basket]["phase"], sim.object_states[basket]["weight"], ticks,
			(Time.get_ticks_msec() - started) / 1000])
	assert_gt(ticks, -1, "%s fills to its quota (%d) and fires within %d s" % [basket, plan["quota"],
			FILL_TICKS / TICK_RATE])
	if sim.level.gates.has(gate):
		assert_true(sim.gate_states[gate]["open"], "%s opens" % gate)
	else:
		assert_true(sim.frontier.celebration_done, "the last basket fired: the level's celebration plays")
	assert_eq(sim.train.stalled, [] as Array[Dictionary], "no train slime stalled")


## The sleepers to call among `asleep`: per line of touching sleepers
## (LevelProgress.chain), the one a called base slime reaches most easily,
## left to right (the train's way).
static func _callers(checker: LevelChecker, section: int, asleep: Array) -> Array:
	var callers := []
	var seen := {}
	for id in asleep:
		if seen.has(id):
			continue
		var best := ""
		var rise := INF
		for other in LevelProgress.chain(checker, id):
			seen[other] = true
			var take_off := LevelProgress.take_off(checker, section, checker.data.sleepers[other]["position"])
			if other in asleep and take_off["reaches"] and take_off["rise"] < rise:
				best = other
				rise = take_off["rise"]
		if best != "":
			callers.append(best)
	callers.sort_custom(func(a: String, b: String):
		return checker.data.sleepers[a]["position"].x < checker.data.sleepers[b]["position"].x)
	return callers


## Tries to wake sleeper `stable_id` and its line as a player would: waits
## (the camera on the spot) until a train slime is at the loop point a
## called base slime's hop takes off from, then taps the sleeper, which
## calls, and waits for the line to wake. Returns whether all of it woke.
func _wake(game: Node, checker: LevelChecker, section: int, stable_id: String) -> bool:
	var sim: Simulation = game.simulation
	var at: Vector2 = checker.data.sleepers[stable_id]["position"]
	var from: Vector2 = LevelProgress.take_off(checker, section, at)["from"]
	var line: Array = LevelProgress.chain(checker, stable_id)
	var box := Rect2(from, Vector2.ZERO)
	for id in line:
		box = box.expand(checker.data.sleepers[id]["position"])
	var aim := box.get_center()
	if _run_until(game, func(): return _train_slime_near(sim, from), LAP_TICKS, aim, CALL_ZOOM) < 0:
		return false
	var screen := sim.view.world_to_screen(sim.slimes.centre_of(_slime(sim, stable_id)))
	sim.push_input(Simulation.touch_down(0, screen))
	sim.push_input(Simulation.touch_up(0, screen))
	var awake := func():
		for id in line:
			if sim.slimes.state_of(_slime(sim, id)) == SlimeBodies.SLEEPER:
				return false
		return true
	return _run_until(game, awake, CALL_TICKS, aim, CALL_ZOOM) >= 0


# --- Helpers ----------------------------------------------------------------

## Runs a tick at a time, the camera on `aim` at `zoom`, until `done` holds
## or `limit` ticks pass. Returns the ticks run, or -1.
func _run_until(game: Node, done: Callable, limit: int, aim: Vector2, zoom: float) -> int:
	for i in limit:
		if done.call():
			return i
		game.simulation.camera.place(aim, zoom)
		game.sync_view()
		game.test_mode.run_ticks(1)
	return limit if done.call() else -1


## Whether a train slime has its centre within NEAR px of `point`.
static func _train_slime_near(sim: Simulation, point: Vector2) -> bool:
	for slime_id in sim.slimes.ids():
		if sim.slimes.state_of(slime_id) == SlimeBodies.TRAIN and sim.slimes.centre_of(slime_id).distance_to(point) <= NEAR:
			return true
	return false


## Taps the centre of `box` (level pixels), the camera first aimed at it.
func _tap_centre(game: Node, box: Rect2) -> void:
	var sim: Simulation = game.simulation
	sim.camera.place(box.get_center(), 1.0)
	game.sync_view()
	var at := sim.view.world_to_screen(box.get_center())
	sim.push_input(Simulation.touch_down(0, at))
	sim.push_input(Simulation.touch_up(0, at))
	game.test_mode.run_ticks(1)


## The runtime id of the slime holding stable ID `stable_id`, or -1.
static func _slime(sim: Simulation, stable_id: String) -> int:
	for slime_id in sim.slimes.ids():
		if stable_id in sim.identities.members_of(slime_id):
			return slime_id
	return -1


## The base slimes awake (not asleep as sleepers): every such slime's size.
static func _base_slimes_awake(sim: Simulation) -> int:
	var count := 0
	for slime_id in sim.slimes.ids():
		if sim.slimes.state_of(slime_id) != SlimeBodies.SLEEPER:
			count += sim.slimes.size_of(slime_id)
	return count


## The game (the main scene) in test mode on the test level from fixture
## `fixture`, time held.
func _boot(fixture: String) -> Node:
	var game: Node = load(MAIN_SCENE).instantiate()
	add_child_autofree(game)
	var run := {"seed": SEED, "time_scale": 0, "level": LEVEL_ID, "fixture": fixture}
	assert_eq(game.enable_test_mode(run), PackedStringArray(), "test mode: %s" % [run])
	return game
