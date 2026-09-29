extends GutTest
## End-to-end: a full simulated session on the test level (the Meadow's
## stand-in, section 1 only) with no input at all. The game wakes the first
## slime by itself and the train carries it round the loop: out along the
## outgoing route, down the slide and back through the start basin, lap after
## lap. Its progress only moves forward (modulo the wrap at the end of the
## loop), it is never lost, and the whole run is repeatable: the same seed
## gives the same state hash.
##
## 15 simulated minutes = 54 000 ticks, run twice (see docs/dev/README.md,
## "Train", for the runtime).

# @test-link [[rule_loop_travelable_with_no_input]]
# @test-link [[req_loop_and_world]]
# @test-link [[req_hopping_behavior]]
# @test-link [[req_slime_states]]

const MAIN_SCENE := "res://src/main.tscn"
const SEED := 20260928
## specs/tuning.md: a session is 15 minutes.
const SESSION_SECONDS := 15 * 60
## How often the run is sampled (progress, lost) to keep the test fast.
const SAMPLE_TICKS := 30
## Share of the expected pace the train must reach: hops are uneven and some
## land short, so the check leaves a margin (the ideal pace makes about 5.8
## laps in a session, 0.7 of it 4; seven seeds all made 5).
const PACE_MARGIN := 0.7


func _boot() -> Node:
	var game: Node = load(MAIN_SCENE).instantiate()
	add_child_autofree(game)
	assert_eq(game.enable_test_mode({"seed": SEED, "time_scale": 0}), PackedStringArray())
	return game


## The laps a size-1 slime is expected to make in `seconds`: the outgoing
## part at one hop reach per mean hop interval, the slides at the slide speed.
static func expected_laps(train: Train, seconds: float) -> float:
	var interval := SlimeBodies.hop_interval_range(1)
	var hop_pace := Train.hop_reach(1) / ((interval.x + interval.y) * 0.5)
	var lap_seconds := train.outgoing_length() / hop_pace + train.slide_length() / Train.SLIDE_SPEED
	return seconds / lap_seconds


## Runs a full session and returns [hash, laps, samples, problems].
func _run_session(game: Node) -> Dictionary:
	var sim: Simulation = game.simulation
	var ids: Array[int] = []
	for slime_id in sim.slimes.ids():
		if sim.slimes.state_of(slime_id) != SlimeBodies.SLEEPER:
			ids.append(slime_id)
	assert_eq(ids.size(), 1, "the game woke the first slime (the rest are sleepers)")
	var slime := ids[0]
	var last: float = sim.train.progress_of(slime)
	var problems := PackedStringArray()
	var ticks := SESSION_SECONDS * Simulation.TICK_RATE
	var started := Time.get_ticks_msec()
	for done in range(0, ticks, SAMPLE_TICKS):
		game.test_mode.run_ticks(SAMPLE_TICKS)
		var now: float = sim.train.progress_of(slime)
		if now < last:
			problems.append("tick %d: progress went back from %.1f to %.1f" % [sim.tick, last, now])
		last = now
		if not sim.train.stalled.is_empty():
			problems.append("tick %d: lost %s" % [sim.tick, sim.train.stalled])
			break
		if sim.slimes.state_of(slime) != SlimeBodies.TRAIN:
			problems.append("tick %d: the slime left the train" % sim.tick)
			break
	var elapsed := (Time.get_ticks_msec() - started) / 1000.0
	return {"hash": sim.state_hash(), "tick": sim.tick, "laps": sim.train.laps_of(slime),
			"progress": last, "problems": problems, "seconds": elapsed}


func test_the_train_loops_a_full_session_with_no_input() -> void:
	var first := _boot()
	var run := _run_session(first)
	var train: Train = first.simulation.train
	var wanted := floori(expected_laps(train, SESSION_SECONDS) * PACE_MARGIN)
	gut.p("session: %d ticks in %.1f s real time, %d laps (progress %.0f px, loop %.0f px), wanted %d"
			% [run["tick"], run["seconds"], run["laps"], run["progress"], train.length(), wanted])
	assert_eq(run["tick"], SESSION_SECONDS * Simulation.TICK_RATE)
	assert_eq(run["problems"], PackedStringArray())
	assert_gte(wanted, 1, "the session is long enough for a lap")
	assert_gte(run["laps"], wanted)

	var second := _boot()
	var again := _run_session(second)
	assert_eq(again["hash"], run["hash"], "the same seed gives the same session")
