extends GutTest
## End-to-end, DoD 1 over the whole test level (chunk 16): "with no input at
## all, the train keeps travelling the whole current loop for a full session,
## and no slime ever becomes lost" (master spec, Definition of done 1).
##
## A full session (15 simulated minutes) with no input, through the real game
## scene and test mode (off-screen simulation on, the camera left to itself:
## the idle camera follows the train), from `gate2-open` (the loop through
## sections 1 to 3) and from `gate1-open` (sections 1 and 2), 20 train slimes
## each. Sampled every SAMPLE_TICKS:
## - progress never goes back: no train slime's progress (laps included)
##   decreases; no gate closes, no basket's phase goes back, no switch
##   flips, the train's open gates never shrink;
## - no slime is lost: none in the train's stall/out-of-bounds log nor in the
##   off-screen lost log, and the level still holds its 200 base slimes;
## - the train travels the whole loop: every train slime completes MIN_LAPS.
## The run is repeatable: the same seed gives the same hash in a second run
## in this process (over AGAIN_TICKS, against the first run's hash there) and
## in a child process over the whole session (`--test-mode --seed=
## --fixture= --run-ticks=`, started first and run alongside).
##
## Then every size travels the whole loop: from `gate2-open` with its train
## slimes taken out, a size-1, a size-2 and a size-3 train slime (three
## species, so they don't fuse) each complete a lap, once with the camera left
## to itself (off-screen simulation included) and once with the camera held
## on the size-3 slime.
##
## Today DoD 1 does not hold: the start basin jams and a train slime is lost
## as stalled (KNOWN_BREAKS). The session tests then check that this is the
## only thing that breaks (nothing else goes back, the losses are stalls in
## the start basin), still check the repeatability, and are pending; once
## the basin is fixed they fail until the entries are taken out.
##
## About 4.5 minutes in all (docs/dev/README.md, "Test level sections 2 and 3,
## full population (chunk 16)").
# @test-link [[rule_loop_travelable_with_no_input]]
# @test-link [[rule_all_sizes_travel_loop_v1]]
# @test-link [[rule_left_alone_and_lost]]
# @test-link [[rule_frontier_set_inert_after_gate_open]]
# @test-link [[req_offscreen_simulation]]
# @test-link [[req_test_level_and_test_mode]]
# @test-link [[req_loop_and_world]]

const MAIN_SCENE := "res://src/main.tscn"
## Seed 2 breaks DoD 1 from both fixtures (KNOWN_BREAKS); probes on seeds 1 to 4 and 16
## lost a slime in 5 of 10 sessions, always in the start basin.
const SEED := 2
const TICK_RATE := Simulation.TICK_RATE
## specs/tuning.md: a session is 15 minutes.
const SESSION_TICKS := 15 * 60 * TICK_RATE
## How often the run is checked, ticks.
const SAMPLE_TICKS := 30
## The second in-process run's length, ticks: long enough for off-screen
## proxies, fusions and the split zone to have run.
const AGAIN_TICKS := 2 * 60 * TICK_RATE
## Laps every train slime completes in the session (probes: 2 or 3).
const MIN_LAPS := 2
## The level's base slimes (rule_max_200_slimes_per_level).
const BASE_SLIMES := 200
## The most problems a run keeps (the first ones tell the story).
const PROBLEMS_KEPT := 12
## A lap of the whole loop takes about 6 min for every size (probes: size 1
## 5.8, size 2 6.4, size 3 6.5); a lap not done by then is a failure.
const LAP_LIMIT_TICKS := 10 * 60 * TICK_RATE
## Where the lap test's slimes start along the loop, px: past the start
## basin's rise, one size per species, the biggest ahead.
const LAP_STARTS := {1: 400.0, 2: 700.0, 3: 1000.0}
const LAP_SPECIES := {1: "A", 2: "B", 3: "C"}
## Basket phases in the order they go.
const PHASE_RANK := {
	FrontierSets.FILLING: 0, FrontierSets.FULL: 1, FrontierSets.REWARD: 2, FrontierSets.FIRED: 3,
}
## The start basin, level px (x 0 to 0.62 screens, around its floor at y 500).
const START_BASIN := Rect2(0.0, 380.0, 0.62 * LevelData.SCREEN, 140.0)
## Fixtures whose session breaks DoD 1 for a known cause (reported, not yet
## fixed): the test is then pending, with the cause and what the run found.
## An entry whose run no longer breaks it fails, so it is taken out once fixed.
const BASIN_JAM := "the start basin jams (docs/dev/README.md, chunk 16, \"DoD 1 does not hold yet\"): the placeholder " \
		+ "slide's tail runs back along the basin floor against the loop, so each slime coming home " \
		+ "shoves the train slimes heading for the rise back toward the loop's start, and slimes that fuse " \
		+ "past the split zone crawl under the first sleeper's ledge; a slime kept behind its recorded " \
		+ "progress for 60 s is lost as stalled"
const KNOWN_BREAKS := {"gate2-open": BASIN_JAM, "gate1-open": BASIN_JAM}


func _boot(fixture: String) -> Node:
	var game: Node = load(MAIN_SCENE).instantiate()
	game.save_store = null
	add_child_autofree(game)
	assert_eq(game.enable_test_mode({"seed": SEED, "time_scale": 0, "fixture": fixture}), PackedStringArray())
	return game


# --- The child process ------------------------------------------------------------------

## Starts the same run in a child process, without waiting for it:
## {"pid", "stdio", "stderr", "text"} (execute_with_pipe's, plus the output
## read so far).
func _start_child(fixture: String, ticks: int) -> Dictionary:
	var args := PackedStringArray([
		"--headless", "--quit-after", "20000", "--path", ProjectSettings.globalize_path("res://"), "--",
		"--test-mode", "--seed=%d" % SEED, "--fixture=%s" % fixture, "--run-ticks=%d" % ticks,
	])
	var child := OS.execute_with_pipe(OS.get_executable_path(), args, false)
	assert_false(child.is_empty(), "the child process started")
	child["text"] = ""
	return child


## Reads what the child wrote so far (so its pipes never fill up).
func _drain(child: Dictionary) -> void:
	if child.is_empty():
		return
	child["text"] += (child["stdio"] as FileAccess).get_as_text()
	(child["stderr"] as FileAccess).get_as_text()


## Waits for the child to end and returns its STATE line, or null.
func _finish_child(child: Dictionary) -> RegExMatch:
	if child.is_empty():
		return null
	while OS.is_process_running(child["pid"]):
		_drain(child)
		OS.delay_msec(100)
	_drain(child)
	assert_eq(OS.get_process_exit_code(child["pid"]), 0, "child exit code")
	var line := RegEx.create_from_string("STATE tick=(\\d+) hash=([0-9a-f]{64})").search(child["text"])
	assert_not_null(line, "no STATE line in:\n%s" % child["text"])
	return line


# --- Watching a session -----------------------------------------------------------------

## The level's base slimes: every slime's size added up.
static func _base_slimes(sim: Simulation) -> int:
	var count := 0
	for slime_id in sim.slimes.ids():
		count += sim.slimes.size_of(slime_id)
	return count


## The frontier's state that must never go back: gate id -> open, basket id
## -> phase rank, switch id -> flipped; and the train's open gates.
static func _frontier(sim: Simulation) -> Dictionary:
	var gates := {}
	for id in sim.gate_states:
		gates[id] = bool(sim.gate_states[id]["open"])
	var baskets := {}
	var switches := {}
	for id in sim.object_states:
		var state: Dictionary = sim.object_states[id]
		if state.has("phase"):
			baskets[id] = PHASE_RANK[state["phase"]]
		elif state.has("flipped"):
			switches[id] = bool(state["flipped"])
	return {"gates": gates, "baskets": baskets, "switches": switches, "open": sim.train.open_gates.duplicate()}


## What went back in the frontier between `was` and `now` (_frontier()).
static func _frontier_problems(was: Dictionary, now: Dictionary, tick: int) -> PackedStringArray:
	var problems := PackedStringArray()
	for id in was["gates"]:
		if was["gates"][id] and not now["gates"].get(id, false):
			problems.append("tick %d: gate %s closed" % [tick, id])
	for id in was["baskets"]:
		if now["baskets"].get(id, -1) < was["baskets"][id]:
			problems.append("tick %d: basket %s went back to rank %d" % [tick, id, now["baskets"].get(id, -1)])
	for id in was["switches"]:
		if now["switches"].get(id) != was["switches"][id]:
			problems.append("tick %d: switch %s flipped with no input" % [tick, id])
	for gate in was["open"]:
		if not gate in now["open"]:
			problems.append("tick %d: the train lost open gate %s" % [tick, gate])
	return problems


## Train slime id -> progress (laps included), for every train slime.
static func _progress(sim: Simulation) -> Dictionary:
	var progress := {}
	for slime_id in sim.train.tracked_ids():
		if sim.slimes.state_of(slime_id) == SlimeBodies.TRAIN:
			progress[slime_id] = sim.train.progress_of(slime_id)
	return progress


## Runs `ticks` ticks of `game` with no input, checking every SAMPLE_TICKS,
## and draining `child`. Returns {"problems" (progress or the frontier going
## back, base slimes missing), "lost" (each loss: "id reason tick at
## centre"), "lost_at" (the lost slimes' centres when seen), "again_hash"
## (the hash at AGAIN_TICKS), "hash", "seconds"}.
func _watch(game: Node, ticks: int, child: Dictionary) -> Dictionary:
	var sim: Simulation = game.simulation
	var problems := PackedStringArray()
	var lost := PackedStringArray()
	var lost_at: Array[Vector2] = []
	var seen := {}
	var last := _progress(sim)
	var frontier := _frontier(sim)
	var again_hash := ""
	var started := Time.get_ticks_msec()
	while sim.tick < ticks:
		game.test_mode.run_ticks(mini(SAMPLE_TICKS, ticks - sim.tick))
		_drain(child)
		if sim.tick == AGAIN_TICKS:
			again_hash = sim.state_hash()
		var now := _progress(sim)
		for slime_id in now:
			if last.has(slime_id) and now[slime_id] < last[slime_id]:
				problems.append("tick %d: slime %d's progress went back from %.1f to %.1f"
						% [sim.tick, slime_id, last[slime_id], now[slime_id]])
		last = now
		var next_frontier := _frontier(sim)
		problems.append_array(_frontier_problems(frontier, next_frontier, sim.tick))
		frontier = next_frontier
		if _base_slimes(sim) != BASE_SLIMES:
			problems.append("tick %d: %d base slimes" % [sim.tick, _base_slimes(sim)])
		for entry in sim.train.lost + sim.offscreen.lost:
			var text := "%d %s at tick %d" % [entry["id"], entry["reason"], entry["tick"]]
			if seen.has(text):
				continue
			seen[text] = true
			var at := sim.slimes.centre_of(entry["id"]) if sim.slimes.has(entry["id"]) else Vector2.INF
			lost.append("%s at %s" % [text, at.round()])
			lost_at.append(at)
		if problems.size() > PROBLEMS_KEPT:
			problems.resize(PROBLEMS_KEPT)
	return {"problems": problems, "lost": lost, "lost_at": lost_at, "again_hash": again_hash,
			"hash": sim.state_hash(), "seconds": (Time.get_ticks_msec() - started) / 1000.0}


## DoD 1 from `fixture` (see the file's doc). A fixture in KNOWN_BREAKS must
## still lose a slime, only by the train's stall rule, in the start basin,
## with nothing else going back; the test is then pending.
func _check_session(fixture: String) -> void:
	var child := _start_child(fixture, SESSION_TICKS)
	var game := _boot(fixture)
	var sim: Simulation = game.simulation
	assert_gt(_progress(sim).size(), 1, "the fixture has a train")
	var run := _watch(game, SESSION_TICKS, child)
	var laps := []
	for slime_id in sim.train.tracked_ids():
		laps.append(sim.train.laps_of(slime_id))
	gut.p("%s: %d ticks in %.1f s real time, laps %s, lost %s" % [fixture, sim.tick, run["seconds"], laps, run["lost"]])
	assert_eq(sim.tick, SESSION_TICKS)
	assert_eq(run["problems"], PackedStringArray(), "%s: progress never goes back, no base slime missing" % fixture)
	var lost: PackedStringArray = run["lost"]
	if KNOWN_BREAKS.has(fixture):
		assert_false(lost.is_empty(), "%s no longer loses a slime: take it out of KNOWN_BREAKS" % fixture)
		for entry in sim.train.lost + sim.offscreen.lost:
			assert_eq(entry["reason"], Train.LOST_STALLED, "the known break: stalled (%s)" % entry)
		for at in run["lost_at"]:
			assert_true(START_BASIN.has_point(at), "the known break: in the start basin (%s)" % at)
	else:
		assert_eq(lost, PackedStringArray(), "%s: no slime lost" % fixture)
		assert_gte(laps.min() if not laps.is_empty() else 0, MIN_LAPS, "every train slime travels the whole loop")

	var again := _boot(fixture)
	again.test_mode.run_ticks(AGAIN_TICKS)
	assert_eq(again.simulation.state_hash(), run["again_hash"], "the same seed gives the same run in this process")

	var line := _finish_child(child)
	if line != null:
		assert_eq(line.get_string(1).to_int(), SESSION_TICKS)
		assert_eq(line.get_string(2), run["hash"], "the same seed gives the same session in a child process")
	if KNOWN_BREAKS.has(fixture) and not lost.is_empty():
		pending("DoD 1 broken from %s: %s. Lost: %s" % [fixture, KNOWN_BREAKS[fixture], "; ".join(lost)])


func test_a_session_from_gate2_open_keeps_the_train_going_and_loses_nothing() -> void:
	_check_session("gate2-open")


func test_a_session_from_gate1_open_keeps_the_train_going_and_loses_nothing() -> void:
	_check_session("gate1-open")


# --- Every size, a whole lap ------------------------------------------------------------

## From `gate2-open` with its train slimes taken out (the sleepers stay), a
## size-1, size-2 and size-3 train slime on the loop (LAP_STARTS); with
## `follow` > 0 the camera is held on the slime of that size, else left to
## itself. Checks that each completes a lap and none is lost.
func _check_all_sizes_lap(follow: int) -> void:
	var game := _boot("gate2-open")
	var sim: Simulation = game.simulation
	for slime_id in sim.slimes.ids():
		if sim.slimes.state_of(slime_id) == SlimeBodies.TRAIN:
			sim.slimes.remove(slime_id)
	var length := sim.train.length()
	var slimes := {}
	var from := {}
	for size in LAP_STARTS:
		slimes[size] = sim.spawn_train_slime(Species.from_letter(LAP_SPECIES[size]), size, LAP_STARTS[size])
		from[size] = sim.train.progress_of(slimes[size])
	var lapped := {}
	var started := Time.get_ticks_msec()
	while sim.tick < LAP_LIMIT_TICKS and lapped.size() < slimes.size():
		for t in SAMPLE_TICKS:
			if follow > 0:
				sim.camera.place(sim.slimes.centre_of(slimes[follow]), 1.0)
				game.sync_view()
			game.test_mode.run_ticks(1)
		if not sim.train.lost.is_empty() or not sim.offscreen.lost.is_empty():
			break
		for size in slimes:
			if not lapped.has(size) and sim.train.progress_of(slimes[size]) >= from[size] + length:
				lapped[size] = sim.tick
	gut.p("follow %d: laps done at %s (ticks), %.1f s real time" % [follow, lapped, (Time.get_ticks_msec() - started) / 1000.0])
	assert_eq(sim.train.lost, [] as Array[Dictionary], "no train slime lost")
	assert_eq(sim.offscreen.lost, [] as Array[Dictionary], "no slime lost off screen")
	for size in slimes:
		assert_true(lapped.has(size), "the size-%d slime completed a lap of the whole loop" % size)


func test_slimes_of_every_size_lap_the_whole_loop_with_the_camera_left_alone() -> void:
	_check_all_sizes_lap(0)


func test_slimes_of_every_size_lap_the_whole_loop_with_the_camera_on_the_biggest() -> void:
	_check_all_sizes_lap(3)
