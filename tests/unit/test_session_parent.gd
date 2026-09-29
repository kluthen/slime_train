extends GutTest
## The session's parent operations (chunk 18) through the Simulation: the
## time left the parent sees behind the code (D114), wake early (D57: ends
## bedtime, sunrise and screensaver mode on the next step, deterministic as
## an input) and carrying a running session into a fresh simulation when the
## parent deletes the level save (D104: the timers untouched). The session's
## own phases are in test_session.gd (kept apart: that file is at its size
## limit).
##
## The synthetic world is test_session.gd's: a floor whose top is at y = 0
## from x = -2000 to 2000, the loop along it at a base slime's centre height
## (y = -24) from x = -1500 to 1500, the first slime at x = -1000 and one
## sleeper past the loop's end (x = -1800).

# @test-link [[req_session_lifecycle]]
# @test-link [[rule_time_left_shown_only_behind_code]]
# @test-link [[req_persistence_and_saves]]

const Support := preload("res://tests/unit/slime_test_support.gd")
const FIRST_ID := "t.first-slime"
const SLEEPER_ID := "t.sleeper.01"
const SLEEPER_SPOT := Vector2(-1800, -24)
const FIRST_SPOT := Vector2(-1000, -24)
## Open ground above the floor, on screen when the view is on the first slime.
const GROUND := FIRST_SPOT + Vector2(300, -200)
## Any wall clock: the tests count from here.
const WALL := 1_700_000_000_000


func _level() -> LevelData:
	var data := LevelData.new("sessions", 1)
	var loop := LoopData.new("t.loop")
	loop.add_segment("t.loop.out", 1, LoopData.OUTGOING, PackedVector2Array([
			Vector2(-1500, -24), Vector2(1500, -24)]))
	loop.add_segment("t.loop.back", 1, LoopData.RETURN, PackedVector2Array([
			Vector2(1500, -24), Vector2(1500, 400), Vector2(-1500, 400), Vector2(-1500, -24)]), "t.gate")
	data.loop = loop
	data.first_slime = {"id": FIRST_ID, "species": "A", "position": FIRST_SPOT}
	data.add_sleeper(SLEEPER_ID, "B", SLEEPER_SPOT)
	data.add_tap_target(SLEEPER_ID, TapDispatcher.KIND_SLEEPER,
			Rect2(SLEEPER_SPOT - Vector2(21, 21), Vector2(42, 42)))
	return data


## A fresh simulation on the synthetic level, looking at the first slime,
## with the clocks at WALL.
func _sim(master_seed := 13) -> Simulation:
	var sim := Simulation.new(master_seed)
	sim.slimes.terrain = TerrainSegments.new([Support.floor_polygon()])
	sim.load_level(_level())
	sim.view.set_to(FIRST_SPOT, 1.0, ScreenView.DEFAULT_SIZE)
	_read(sim, 0)
	return sim


## As _sim(), with sessions open: screensaver mode.
func _opened(master_seed := 13) -> Simulation:
	var sim := _sim(master_seed)
	sim.session.open(sim)
	sim.step()
	return sim


## As _opened(), with a session started by a tap on open ground at 0 ms (a
## call: the first-play hint is done).
func _in_session(master_seed := 13) -> Simulation:
	var sim := _opened(master_seed)
	var at := sim.view.world_to_screen(GROUND)
	sim.push_input(Simulation.touch_down(0, at))
	sim.push_input(Simulation.touch_up(0, at))
	sim.step()
	assert_eq(sim.session.phase, Session.SESSION)
	return sim


## As _in_session(), bedtime just reached.
func _at_bedtime() -> Simulation:
	var sim := _in_session()
	_step_at(sim, Session.BEDTIME_MS)
	assert_eq(sim.session.phase, Session.BEDTIME)
	return sim


## Hands the session the clocks `ms` after WALL, same epoch.
func _read(sim: Simulation, ms: int) -> void:
	sim.session.read_clock(Session.reading(WALL + ms, ms, "a"))


## One step with the clocks `ms` after WALL.
func _step_at(sim: Simulation, ms: int) -> void:
	_read(sim, ms)
	sim.step()


## The runtime id of the slime whose stable ID is `stable_id`, or -1.
func _slime(sim: Simulation, stable_id: String) -> int:
	for slime_id in sim.slimes.ids():
		if stable_id in sim.identities.members_of(slime_id):
			return slime_id
	return -1


# --- The time left (D114) -------------------------------------------------------

func test_the_time_left_counts_down_to_bedtime_then_to_sunrise() -> void:
	var sim := _opened()
	assert_eq(sim.session.time_left_ms(), -1, "screensaver mode: no timer")
	sim = _in_session()
	assert_eq(sim.session.time_left_ms(), Session.BEDTIME_MS, "a whole session")
	_step_at(sim, 60_000)
	assert_eq(sim.session.time_left_ms(), Session.BEDTIME_MS - 60_000)
	_step_at(sim, Session.WIND_DOWN_MS + 30_000)
	assert_eq(sim.session.phase, Session.WIND_DOWN)
	assert_eq(sim.session.time_left_ms(), 30_000, "the wind-down counts to bedtime too")
	_step_at(sim, Session.BEDTIME_MS)
	assert_eq(sim.session.time_left_ms(), Session.COOLDOWN_SECONDS * 1000, "bedtime: to sunrise")
	_step_at(sim, Session.BEDTIME_MS + 240_000)
	assert_eq(sim.session.time_left_ms(), Session.COOLDOWN_SECONDS * 1000 - 240_000)
	_step_at(sim, Session.SUNRISE_MS)
	assert_eq(sim.session.time_left_ms(), -1, "sunrise: screensaver mode again")


func test_the_time_left_is_a_pure_query_never_below_zero() -> void:
	var sim := _in_session()
	_step_at(sim, 90_000)
	var before := sim.state_hash()
	assert_eq(sim.session.time_left_ms(), sim.session.time_left_ms())
	assert_eq(sim.state_hash(), before, "asking changes nothing")
	# Restored past its limit, before the next step catches up: nothing left.
	var late := Session.new()
	late.phase = Session.SESSION
	late.elapsed_ms = Session.BEDTIME_MS + 5
	assert_eq(late.time_left_ms(), 0)
	late.phase = Session.BEDTIME
	late.elapsed_ms = Session.SUNRISE_MS + 5
	assert_eq(late.time_left_ms(), 0)


# --- Wake early (D57) -----------------------------------------------------------

func test_wake_early_at_bedtime_brings_sunrise_on_the_next_step() -> void:
	var sim := _at_bedtime()
	_step_at(sim, Session.BEDTIME_MS + 60_000)
	sim.push_input(Simulation.wake_early())
	assert_eq(sim.session.phase, Session.BEDTIME, "queued, not applied")
	_step_at(sim, Session.BEDTIME_MS + 61_000)
	assert_eq(sim.session.phase, Session.SCREENSAVER, "sunrise, then screensaver mode")
	assert_true(sim.screensaver)
	assert_eq(sim.session.sunrise_tick, sim.tick - 1, "with its cue")
	assert_eq(sim.session.elapsed_ms, 0)
	assert_eq(sim.session.time_left_ms(), -1)
	assert_eq(sim.slimes.state_of(_slime(sim, FIRST_ID)), SlimeBodies.TRAIN, "the slimes wake")
	assert_true(sim.camera.edge_buttons_visible)
	assert_false(sim.hint.bedtime)
	assert_eq(sim.input_log[-1]["kind"], Simulation.INPUT_WAKE_EARLY, "logged like any input")
	assert_true(sim.session.can_start(), "the next tap starts a session")


func test_wake_early_is_deterministic() -> void:
	var hashes := []
	for i in 2:
		var sim := _at_bedtime()
		sim.push_input(Simulation.wake_early())
		_step_at(sim, Session.BEDTIME_MS + 1000)
		sim.run(30)
		hashes.append(sim.state_hash())
	assert_eq(hashes[0], hashes[1])


func test_wake_early_outside_bedtime_does_nothing() -> void:
	# The button shows only at bedtime, but a press can race the natural
	# sunrise: it then lands in screensaver mode or a new session, where it
	# must not end anything.
	var idle := _opened()
	idle.push_input(Simulation.wake_early())
	_step_at(idle, 1000)
	assert_eq(idle.session.phase, Session.SCREENSAVER)
	assert_eq(idle.session.sunrise_tick, -1, "no sunrise cue")
	var sim := _in_session()
	_step_at(sim, 60_000)
	sim.push_input(Simulation.wake_early())
	_step_at(sim, 61_000)
	assert_eq(sim.session.phase, Session.SESSION, "the session goes on")
	assert_eq(sim.session.elapsed_ms, 61_000)


# --- A deleted save keeps the session (D104) --------------------------------------

func test_a_fresh_simulation_carries_a_running_session_on_time() -> void:
	var old := _in_session()
	old.push_input(Simulation.tilt(20.0))
	_step_at(old, 60_000)
	old.run(30)
	assert_true(old.hint.done, "progress: the first call happened")
	var fresh := _sim(99)
	fresh.carry_session(old)
	assert_eq(fresh.session.phase, Session.SESSION)
	assert_eq(fresh.session.elapsed_ms, old.session.elapsed_ms)
	assert_eq(fresh.session.anchor, old.session.anchor)
	assert_eq(fresh.session.time_left_ms(), old.session.time_left_ms(), "the same time left")
	assert_true(fresh.session.enabled, "sessions stay open")
	assert_false(fresh.screensaver)
	assert_eq(fresh.phone_tilt.dump(), old.phone_tilt.dump(), "the session's neutral too")
	assert_false(fresh.hint.done, "the progress is gone")
	assert_eq(fresh.session.clock["tick"], fresh.tick - (old.tick - old.session.clock["tick"]),
			"the clock's tick is the fresh simulation's")
	_step_at(fresh, Session.BEDTIME_MS - 1)
	assert_ne(fresh.session.phase, Session.BEDTIME)
	_step_at(fresh, Session.BEDTIME_MS)
	assert_eq(fresh.session.phase, Session.BEDTIME, "bedtime on time")
	assert_eq(fresh.slimes.state_of(_slime(fresh, FIRST_ID)), SlimeBodies.BEDTIME_ASLEEP)


func test_a_fresh_simulation_carries_bedtime_asleep() -> void:
	var old := _at_bedtime()
	_step_at(old, Session.BEDTIME_MS + 120_000)
	var fresh := _sim(99)
	fresh.carry_session(old)
	assert_eq(fresh.session.phase, Session.BEDTIME)
	assert_eq(fresh.session.time_left_ms(), old.session.time_left_ms())
	assert_eq(fresh.slimes.state_of(_slime(fresh, FIRST_ID)), SlimeBodies.BEDTIME_ASLEEP,
			"the fresh world's awake slime sleeps")
	assert_eq(fresh.slimes.state_of(_slime(fresh, SLEEPER_ID)), SlimeBodies.SLEEPER)
	assert_false(fresh.camera.edge_buttons_visible)
	assert_true(fresh.hint.bedtime)
	assert_false(fresh.session.save_due, "the game root saves on its own")
	assert_eq(fresh.session.dusk(fresh.tick), 1.0)
	_step_at(fresh, Session.SUNRISE_MS - 1)
	assert_eq(fresh.session.phase, Session.BEDTIME)
	_step_at(fresh, Session.SUNRISE_MS)
	assert_eq(fresh.session.phase, Session.SCREENSAVER, "sunrise on time")
	assert_eq(fresh.slimes.state_of(_slime(fresh, FIRST_ID)), SlimeBodies.TRAIN)


func test_a_carried_sunrise_cue_never_darkens_the_fresh_world() -> void:
	# The cue counts in ticks; the fresh simulation starts again at tick 0.
	var old := _at_bedtime()
	old.run(600)
	_step_at(old, Session.SUNRISE_MS)
	old.run(30)
	assert_gt(old.session.dusk(old.tick), 0.0, "the light is still coming back")
	var fresh := _sim(99)
	fresh.carry_session(old)
	assert_eq(fresh.session.phase, Session.SCREENSAVER)
	assert_true(fresh.screensaver)
	assert_eq(fresh.session.sunrise_tick, -1, "a cue from before tick 0 is dropped (proposed)")
	assert_eq(fresh.session.dusk(fresh.tick), 0.0, "day")


func test_an_untimed_game_stays_untimed() -> void:
	var old := _sim()
	old.run(10)
	var fresh := _sim(99)
	fresh.carry_session(old)
	assert_false(fresh.session.enabled)
	assert_eq(fresh.session.phase, Session.SCREENSAVER)
	assert_false(fresh.screensaver, "left as it was")


func test_test_modes_clock_carried_to_a_fresh_simulation_goes_on() -> void:
	# Test mode's clock (TestClock) is a function of the tick: carried to a
	# fresh simulation at tick 0, it reads on as if the old one ran on.
	var clock := TestClock.for_run(null, 0, {}, {50: 1000, 150: 2000, 400: 3000})
	var carried := clock.carried(200, 0)
	assert_eq(carried.reading_at(0), clock.reading_at(200), "no jump")
	for fresh_tick in [1, 59, 60, 199]:
		assert_eq(carried.reading_at(fresh_tick)["wall_ms"] - carried.reading_at(0)["wall_ms"],
				TestClock.ms_at(200 + fresh_tick) - TestClock.ms_at(200), "1000 / 60 ms a tick, no drift")
	assert_eq(carried.reading_at(160), Session.reading(clock.reading_at(200)["wall_ms"]
			+ TestClock.ms_at(360) - TestClock.ms_at(200), TestClock.ms_at(360) + 3000, TestClock.EPOCH),
			"the skips already counted don't count again")
	assert_eq(carried.reading_at(400)["mono_ms"], TestClock.ms_at(600) + 6000, "a later skip counts once")
	var twice := carried.carried(100, 0)
	assert_eq(twice.reading_at(0), carried.reading_at(100), "carried again, no jump")
	assert_eq(twice.reading_at(400)["mono_ms"], TestClock.ms_at(700) + 6000)
