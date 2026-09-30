extends GutTest
## Sessions through the real game scene and test mode's clocks (master spec
## §5.7, D95) [DoD 20, 21, 22]: screensaver mode until a tap reaches the
## world (the parent band and an edge button don't); bedtime 15 minutes in
## (a scripted "skip"); a killed session resumes where it was, in test mode
## and in normal play; from the wind-down fixture the light goes to dusk, then
## bedtime puts the slimes to sleep, saves, hides the edge buttons and taps
## don't call; from the sunrise fixture sunrise wakes them into screensaver
## mode and the next tap starts a session. The runs are repeatable, also in a
## separate Godot process. Waking early waits for chunk 18.
##
## Every game here that saves gets its own SaveStore on a scratch directory.

# @test-link [[req_session_lifecycle]]
# @test-link [[req_denial_and_stepup_behavior]]
# @test-link [[req_actor_roles_and_permissions]]

const ChildGame := preload("res://tests/e2e/child_game.gd")
const MAIN_SCENE := "res://src/main.tscn"
const START_SCRIPT := "res://tests/e2e/scripts/session_start.json"
const SUNRISE_SCRIPT := "res://tests/e2e/scripts/session_sunrise.json"
const DIR := "user://test-session-e2e/"
const LEVEL := "test"
## session_start.json: the parent band tap, the edge button tap, the world
## tap, the 15-minute skip, a bedtime tap.
const PARENT_TICK := 30
const EDGE_TICK := 60
const START_TICK := 90
const SKIP_TICK := 150
const BEDTIME_TAP_TICK := 200


## Stands in for SessionClock in normal play.
class FakeClock:
	extends RefCounted
	var reading := {}

	func now() -> Dictionary:
		return reading


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


func _game(store: SaveStore = null) -> Node:
	var game: Node = load(MAIN_SCENE).instantiate()
	game.save_store = store
	add_child_autofree(game)
	return game


func _config(path: String, overrides := {}) -> Dictionary:
	var loaded := TestMode.load_config_file(path)
	assert_eq(loaded["errors"], PackedStringArray())
	var config: Dictionary = loaded["config"]
	config["time_scale"] = 0
	config.merge(overrides, true)
	return config


func _run(path: String, overrides := {}, store: SaveStore = null) -> Node:
	var game := _game(store)
	assert_eq(game.enable_test_mode(_config(path, overrides)), PackedStringArray())
	return game


## Runs `game` up to (not including) `tick`.
func _run_to(game: Node, tick: int) -> void:
	game.test_mode.run_ticks(tick - game.simulation.tick)


func _awake_states(sim: Simulation) -> Array:
	var out := []
	for slime_id in sim.slimes.ids():
		var state := sim.slimes.state_of(slime_id)
		if state != SlimeBodies.SLEEPER:
			out.append(state)
	return out


# --- DoD 20: a session starts on a world tap and lasts 15 minutes ---------------

func test_only_a_tap_that_reaches_the_world_starts_a_session() -> void:
	var game := _run(START_SCRIPT)
	var sim: Simulation = game.simulation
	assert_true(sim.screensaver, "screensaver mode first")
	_run_to(game, PARENT_TICK + 1)
	assert_eq(sim.taps[-1]["zone"], TapDispatcher.ZONE_PARENT)
	assert_eq(sim.session.phase, Session.SCREENSAVER, "the parent band doesn't")
	_run_to(game, EDGE_TICK + 1)
	assert_eq(sim.taps[-1]["zone"], TapDispatcher.ZONE_EDGE)
	assert_eq(sim.session.phase, Session.SCREENSAVER, "an edge button doesn't")
	assert_true(sim.screensaver)
	_run_to(game, START_TICK + 1)
	assert_true(sim.taps[-1]["zone"] in [TapDispatcher.ZONE_GROUND, TapDispatcher.ZONE_OBJECT])
	assert_eq(sim.session.phase, Session.SESSION, "the world tap does")
	assert_false(sim.screensaver)
	_run_to(game, SKIP_TICK)
	assert_eq(sim.session.phase, Session.SESSION)
	_run_to(game, SKIP_TICK + 1)
	assert_eq(sim.session.phase, Session.BEDTIME, "15 minutes later: bedtime")
	_run_to(game, BEDTIME_TAP_TICK + 1)
	assert_false(sim.taps[-1]["call"], "a bedtime tap doesn't call")
	assert_eq(sim.session.phase, Session.BEDTIME)


func test_a_killed_session_resumes_where_it_was_in_test_mode() -> void:
	var store := SaveStore.new(DIR)
	var played := _run(START_SCRIPT, {}, store)
	_run_to(played, START_TICK + 30)
	assert_eq(played.save_now(), "")
	var saved: Dictionary = played.simulation.session.dump()
	assert_eq(saved["phase"], Session.SESSION)
	# The run that went on, and one that was killed and reopened a minute
	# later after a restart: same timer.
	var never_stopped := _run(START_SCRIPT, {"steps": [
		{"tick": START_TICK, "do": "tap", "at": [576, 400]},
		{"tick": START_TICK + 30, "do": "skip", "seconds": 60},
	]})
	_run_to(never_stopped, START_TICK + 90)
	var reopened := _run(START_SCRIPT, {"load": store.path_for(LEVEL), "steps": [],
			"clock": {"away": 60, "restarted": true}})
	assert_eq(reopened.simulation.tick, START_TICK + 30)
	assert_eq(reopened.simulation.session.phase, Session.SESSION, "no tap needed")
	assert_false(reopened.simulation.screensaver)
	_run_to(reopened, START_TICK + 90)
	assert_eq(reopened.simulation.session.elapsed_ms, never_stopped.simulation.session.elapsed_ms)
	assert_eq(reopened.simulation.session.phase, Session.SESSION)


func test_a_killed_session_resumes_where_it_was_in_normal_play() -> void:
	var store := SaveStore.new(DIR)
	var played := _run(START_SCRIPT, {}, store)
	_run_to(played, START_TICK + 30)
	assert_eq(played.save_now(), "")
	var saved: Dictionary = played.simulation.session.dump()
	var game := _game(SaveStore.new(DIR))
	assert_null(game.test_mode, "normal play")
	var sim: Simulation = game.simulation
	assert_eq(sim.session.phase, Session.SESSION, "reopened in the session")
	assert_false(sim.screensaver)
	var clock := FakeClock.new()
	clock.reading = Session.reading(saved["clock"]["wall_ms"] + 120_000, 5, "another process")
	game.session_clock = clock
	game.step_simulation()
	assert_eq(sim.session.elapsed_ms, saved["elapsed_ms"] + 120_000, "the two minutes away count")
	clock.reading = Session.reading(saved["clock"]["wall_ms"] + Session.BEDTIME_MS, 5 + Session.BEDTIME_MS - 120_000,
			"another process")
	game.step_simulation()
	assert_eq(sim.session.phase, Session.BEDTIME)
	var written := SaveStore.read_file(store.path_for(LEVEL))
	assert_eq(written["status"], SaveStore.OK)
	if written["status"] == SaveStore.OK:
		assert_eq(written["save"]["session"]["phase"], Session.BEDTIME, "bedtime saved")


# --- DoD 21: wind-down, then bedtime ----------------------------------------------

func test_the_wind_down_turns_to_dusk_then_bedtime_sleeps_saves_and_taps_only_ripple() -> void:
	var store := SaveStore.new(DIR)
	var game := _run(SUNRISE_SCRIPT, {"fixture": "wind-down", "autosave": true,
			"steps": [{"tick": 700, "do": "tap", "at": [576, 400]}]}, store)
	var sim: Simulation = game.simulation
	assert_eq(sim.session.phase, Session.WIND_DOWN, "14:50 into the session")
	assert_false(sim.screensaver)
	_run_to(game, 300)
	assert_eq(sim.session.phase, Session.WIND_DOWN)
	assert_gt(sim.session.dusk(sim.tick), 0.9, "almost dusk")
	assert_lt(sim.slimes.hop_rate, 0.6, "the slimes slow down")
	game.session_screen._process(0.0)
	assert_ne(game.session_screen.color, Color.WHITE, "the world is tinted")
	assert_false(FileAccess.file_exists(store.path_for(LEVEL)), "no save yet")
	_run_to(game, 601)
	assert_eq(sim.session.phase, Session.BEDTIME, "15:00")
	assert_eq(sim.session.dusk(sim.tick), 1.0)
	for state in _awake_states(sim):
		assert_eq(state, SlimeBodies.BEDTIME_ASLEEP, "every awake slime sleeps")
	assert_false(sim.camera.edge_buttons_visible)
	game.edge_buttons._process(0.0)
	assert_false(game.edge_buttons.visible, "the edge buttons hide")
	var written := SaveStore.read_file(store.path_for(LEVEL))
	assert_eq(written["status"], SaveStore.OK, "bedtime saved")
	if written["status"] == SaveStore.OK:
		assert_eq(written["save"]["session"]["phase"], Session.BEDTIME)
		assert_eq(int(written["save"]["sim"]["tick"]), 601)
	_run_to(game, 701)
	assert_eq(sim.taps[-1]["tick"], 700)
	assert_false(sim.taps[-1]["call"], "no call")
	assert_eq(sim.ripples[-1]["tick"], 700, "only a ripple")
	for state in _awake_states(sim):
		assert_eq(state, SlimeBodies.BEDTIME_ASLEEP, "still asleep")


func test_the_bedtime_fixture_is_bedtime() -> void:
	var game := _run(SUNRISE_SCRIPT, {"fixture": "bedtime", "steps": []})
	var sim: Simulation = game.simulation
	assert_eq(sim.session.phase, Session.BEDTIME)
	assert_false(sim.camera.edge_buttons_visible)
	assert_true(sim.hint.bedtime)
	for state in _awake_states(sim):
		assert_eq(state, SlimeBodies.BEDTIME_ASLEEP)
	_run_to(game, 60)
	assert_eq(sim.session.phase, Session.BEDTIME)
	assert_eq(sim.session.elapsed_ms, Session.BEDTIME_MS + TestClock.ms_at(59))


# --- DoD 22: sunrise --------------------------------------------------------------

func test_sunrise_wakes_the_slimes_into_screensaver_mode_and_the_next_tap_starts_a_session() -> void:
	var game := _run(SUNRISE_SCRIPT)
	var sim: Simulation = game.simulation
	assert_eq(sim.session.phase, Session.BEDTIME, "9:55 into the cooldown")
	_run_to(game, 300)
	assert_eq(sim.session.phase, Session.BEDTIME)
	_run_to(game, 301)
	assert_eq(sim.session.phase, Session.SCREENSAVER, "sunrise, 5 s later")
	assert_eq(sim.session.sunrise_tick, 300, "with its cue")
	assert_true(sim.screensaver)
	assert_true(sim.camera.edge_buttons_visible)
	assert_false(sim.hint.bedtime)
	assert_false(SlimeBodies.BEDTIME_ASLEEP in _awake_states(sim), "everyone woke")
	assert_true(SlimeBodies.TRAIN in _awake_states(sim), "the train is back")
	_run_to(game, 400)
	var light := sim.session.dusk(sim.tick)
	assert_true(light > 0.0 and light < 1.0, "the light is coming back (%.2f)" % light)
	assert_eq(sim.session.phase, Session.SCREENSAVER, "no session without a tap")
	_run_to(game, 401)
	assert_eq(sim.session.phase, Session.SESSION, "the first tap starts a session")
	assert_false(sim.screensaver)


# --- Determinism ------------------------------------------------------------------

func test_a_session_run_is_repeatable() -> void:
	var hashes := []
	for i in 2:
		var game := _run(START_SCRIPT)
		_run_to(game, BEDTIME_TAP_TICK + 60)
		hashes.append(game.simulation.state_hash())
	assert_eq(hashes[0], hashes[1])
	var sunrise := []
	for i in 2:
		var game := _run(SUNRISE_SCRIPT)
		_run_to(game, 500)
		sunrise.append(game.simulation.state_hash())
	assert_eq(sunrise[0], sunrise[1])


func test_a_separate_process_gives_the_same_hash() -> void:
	for case in [[START_SCRIPT, BEDTIME_TAP_TICK + 60], [SUNRISE_SCRIPT, 500]]:
		var child := _child(case[0], case[1])
		assert_eq(child["code"], 0, "child exit code")
		var game := _run(case[0])
		_run_to(game, case[1])
		assert_eq(child["tick"], case[1])
		assert_eq(child["hash"], game.simulation.state_hash(), "same hash in another process: %s" % case[0])


## Runs the game in a child process in test mode with `script` for `ticks`.
## Returns {"code", "tick", "hash"}.
func _child(script: String, ticks: int) -> Dictionary:
	var args := ChildGame.engine_args(3000)
	args.append_array([
		"--test-mode", "--test-script=" + script, "--run-ticks=%d" % ticks,
	])
	var output := []
	var code := OS.execute(OS.get_executable_path(), args, output, true)
	var text := "\n".join(output)
	var line := RegEx.create_from_string("STATE tick=(\\d+) hash=([0-9a-f]{64})").search(text)
	assert_not_null(line, "no STATE line in:\n%s" % text)
	if line == null:
		return {"code": code, "tick": -1, "hash": ""}
	return {"code": code, "tick": line.get_string(1).to_int(), "hash": line.get_string(2)}
