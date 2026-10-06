extends GutTest
## The safety nets on the test level, through the real game scene and test
## mode (off-screen simulation on) (chunk 23A, build plan items 23.3 and
## 23.13): two base train slimes of different species put on one centre on
## screen, and held there (before every tick the second one's ring is put
## back on the first one's: the solver parts two rings on one centre since
## O91's fix, the net is the backstop for a pair something else keeps
## there), are stuck, and the higher id goes to the start of the loop (a tie
## in size), logged in the state dump; from `wind-down`, through bedtime and
## more than a minute of it, no slime asleep at bedtime is counted as
## stalled or moved.
# @test-link [[rule_stuck_slimes_moved_to_start]]
# @test-link [[rule_stalled_train_slime_moved_to_start]]
# @test-link [[req_slime_states]]

const MAIN_SCENE := "res://src/main.tscn"
const SCRIPT := "res://tests/e2e/scripts/session_sunrise.json"
## `wind-down`: bedtime comes at this tick (tests/e2e/test_session_e2e.gd).
const BEDTIME_TICK := 601
## How far a bedtime-asleep slime may settle in its pile, px: far less than
## a move to the start of the loop.
const SETTLE := 60.0


func _run(overrides: Dictionary) -> Node:
	var game: Node = load(MAIN_SCENE).instantiate()
	add_child_autofree(game)
	var loaded := TestMode.load_config_file(SCRIPT)
	assert_eq(loaded["errors"], PackedStringArray())
	var config: Dictionary = loaded["config"]
	config["time_scale"] = 0
	config.merge(overrides, true)
	assert_eq(game.enable_test_mode(config), PackedStringArray())
	return game


func test_two_train_slimes_on_one_centre_one_goes_to_the_start() -> void:
	var game := _run({"fixture": "fresh", "sessions": false, "steps": []})
	var sim: Simulation = game.simulation
	game.test_mode.run_ticks(StuckSlimes.CHECK_TICKS - sim.tick % StuckSlimes.CHECK_TICKS)
	# On screen: where the loop passes closest to the view's centre. Base
	# slimes, so the start's split zone leaves them whole.
	var distance: float = sim.level.loop.closest(sim.view.centre, sim.train.open_gates)["distance"]
	var first := sim.spawn_train_slime(Species.from_letter("B"), 1, distance)
	var second := sim.spawn_train_slime(Species.from_letter("C"), 1, distance)
	var from := sim.tick
	for i in StuckSlimes.CHECKS * StuckSlimes.CHECK_TICKS:
		if sim.stuck_slimes.stuck.is_empty():
			var body := sim.slimes.body_of(second)
			var under := sim.slimes.body_of(first)
			for key in ["points", "previous", "centre"]:
				body[key] = under[key]
			assert_true(sim.slimes.set_body(second, body), "held on one centre")
		game.test_mode.run_ticks(1)
	var stuck: Array = sim.dump()["stuck_slimes"]["stuck"]
	assert_eq(stuck.size(), 1, "one stuck case, in the state dump")
	if stuck.size() == 1:
		assert_eq(stuck[0]["id"], second, "on a tie, the higher id")
		assert_eq(stuck[0]["other"], first)
		assert_true(stuck[0]["moved"])
		assert_eq(stuck[0]["tick"], from + (StuckSlimes.CHECKS - 1) * StuckSlimes.CHECK_TICKS, "about 2 s")
	assert_eq(sim.slimes.state_of(second), SlimeBodies.TRAIN, "back on the train")
	assert_lte(sim.train.distance_of(second), LoopStart.STRETCH, "at the start of the loop")
	assert_eq(sim.offscreen.lost, [] as Array[Dictionary], "stuck is not lost")
	assert_eq(sim.train.stalled, [] as Array[Dictionary])


func test_from_wind_down_no_slime_asleep_at_bedtime_is_counted_as_stalled_or_moved() -> void:
	var game := _run({"fixture": "wind-down", "steps": []})
	var sim: Simulation = game.simulation
	game.test_mode.run_ticks(BEDTIME_TICK + 1 - sim.tick)
	assert_eq(sim.session.phase, Session.BEDTIME)
	var asleep := {}
	for slime_id in sim.slimes.ids():
		if sim.slimes.state_of(slime_id) == SlimeBodies.BEDTIME_ASLEEP:
			asleep[slime_id] = sim.slimes.centre_of(slime_id)
	assert_gt(asleep.size(), 0, "the train (the fixture's first slime) fell asleep")
	var stall_ticks := int(Train.STALL_SECONDS * Simulation.TICK_RATE)
	game.test_mode.run_ticks(stall_ticks + 10 * Simulation.TICK_RATE)
	assert_eq(sim.session.phase, Session.BEDTIME, "still bedtime")
	assert_eq(sim.train.stalled, [] as Array[Dictionary], "no stall counted")
	assert_eq(sim.train.tracked_ids().size(), 0, "no train slime to count")
	for entry in sim.stuck_slimes.stuck:
		assert_false(entry["moved"], "no stuck slime moved at bedtime: %s" % entry)
	for slime_id in asleep:
		assert_eq(sim.slimes.state_of(slime_id), SlimeBodies.BEDTIME_ASLEEP, "slime %d still asleep" % slime_id)
		assert_lt(sim.slimes.centre_of(slime_id).distance_to(asleep[slime_id]), SETTLE,
				"slime %d stayed where it fell asleep" % slime_id)
