extends GutTest
## Sessions (src/sim/session.gd) through the Simulation (master spec §5.7,
## D95): screensaver mode until a tap that reaches the world (open ground or
## an object, never the parent band or an edge button) starts a 15-minute
## session; its last minute winds down (dusk, slower hops); bedtime puts the
## slimes to sleep, hides the edge buttons, lets taps only ripple and asks
## for a save; sunrise after the 10-minute cooldown wakes them and lands in
## screensaver mode. The timer counts real time from the clocks the scene
## layer hands in (wall and monotonic, with an epoch), survives a save, and
## catches up after a gap. Also test mode's clock (TestClock) and "skip"
## steps, the save fields and a lint: nothing under src/sim/ reads a clock.
##
## The synthetic world: a floor whose top is at y = 0 from x = -2000 to 2000;
## the loop runs along it at a base slime's centre height (y = -24) from
## x = -1500 to 1500 and returns under the floor. The first slime starts at
## x = -1000; one sleeper rests on the floor past the loop's end (x = -1800).

# @test-link [[req_session_lifecycle]]
# @test-link [[req_denial_and_stepup_behavior]]
# @test-link [[req_actor_roles_and_permissions]]

const Support := preload("res://tests/unit/slime_test_support.gd")
const FIRST_ID := "t.first-slime"
const SLEEPER_ID := "t.sleeper.01"
const SLEEPER_SPOT := Vector2(-1800, -24)
const FIRST_SPOT := Vector2(-1000, -24)
## Open ground above the floor, away from the slimes, on screen when the
## view is on the first slime.
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


func _terrain() -> TerrainSegments:
	return TerrainSegments.new([Support.floor_polygon()])


## The synthetic level, untimed (sessions not opened), the view on the
## first slime, the clocks at WALL.
func _sim(master_seed := 13) -> Simulation:
	var sim := Simulation.new(master_seed)
	sim.slimes.terrain = _terrain()
	sim.load_level(_level())
	_look_at(sim, FIRST_SPOT)
	_read(sim, 0)
	return sim


## As _sim(), with sessions open: screensaver mode.
func _opened(master_seed := 13) -> Simulation:
	var sim := _sim(master_seed)
	sim.session.open(sim)
	sim.step()
	return sim


## As _opened(), with a session started by a tap on open ground at 0 ms.
func _in_session(master_seed := 13) -> Simulation:
	var sim := _opened(master_seed)
	_tap(sim, GROUND)
	assert_eq(sim.session.phase, Session.SESSION)
	return sim


## As _in_session(), bedtime just reached.
func _at_bedtime() -> Simulation:
	var sim := _in_session()
	_step_at(sim, Session.BEDTIME_MS)
	assert_eq(sim.session.phase, Session.BEDTIME)
	return sim


func _look_at(sim: Simulation, world: Vector2) -> void:
	sim.view.set_to(world, 1.0, ScreenView.DEFAULT_SIZE)


## Hands the session the clocks `ms` after WALL, same epoch ("a").
func _read(sim: Simulation, ms: int, epoch := "a") -> void:
	sim.session.read_clock(Session.reading(WALL + ms, ms, epoch))


## One step with the clocks `ms` after WALL.
func _step_at(sim: Simulation, ms: int) -> void:
	_read(sim, ms)
	sim.step()


func _tap(sim: Simulation, world: Vector2) -> void:
	_tap_screen(sim, sim.view.world_to_screen(world))


func _tap_screen(sim: Simulation, at: Vector2) -> void:
	sim.push_input(Simulation.touch_down(0, at))
	sim.push_input(Simulation.touch_up(0, at))
	sim.step()


## The runtime id of the slime whose stable ID is `stable_id`, or -1.
func _slime(sim: Simulation, stable_id: String) -> int:
	for slime_id in sim.slimes.ids():
		if stable_id in sim.identities.members_of(slime_id):
			return slime_id
	return -1


# --- Starting a session ---------------------------------------------------------

func test_without_sessions_the_game_plays_untimed() -> void:
	# Test mode's default and the unit tests': an endless session.
	var sim := _sim()
	_tap(sim, GROUND)
	_step_at(sim, Session.SUNRISE_MS * 2)
	assert_eq(sim.session.phase, Session.SCREENSAVER)
	assert_eq(sim.session.elapsed_ms, 0)
	assert_false(sim.screensaver, "left as it was")
	assert_false(sim.session.can_start())
	assert_eq(sim.dump()["session"], {"phase": "screensaver", "elapsed_ms": 0, "anchor": {},
			"clock": {}, "sunrise_tick": -1})


func test_opening_sessions_lands_in_screensaver_mode() -> void:
	var sim := _sim()
	sim.session.open(sim)
	assert_true(sim.screensaver)
	_step_at(sim, 60_000)
	assert_true(sim.screensaver)
	assert_eq(sim.session.phase, Session.SCREENSAVER)
	assert_eq(sim.session.elapsed_ms, 0, "no timer in screensaver mode")
	assert_true(sim.session.can_start())


func test_a_tap_on_open_ground_starts_a_session_and_takes_the_neutral() -> void:
	var sim := _opened()
	sim.push_input(Simulation.tilt(20.0))
	sim.step()
	assert_eq(sim.phone_tilt.neutral, 0.0)
	_tap(sim, GROUND)
	assert_eq(sim.session.phase, Session.SESSION)
	assert_false(sim.screensaver)
	assert_eq(sim.phone_tilt.neutral, 20.0, "the session start takes the neutral")
	var tap: Dictionary = sim.taps[-1]
	assert_eq(tap["zone"], TapDispatcher.ZONE_GROUND)
	assert_true(tap["call"], "the tap does its usual job too")
	assert_false(sim.session.can_start())
	assert_eq(sim.session.anchor, {"wall_ms": WALL, "mono_ms": 0, "elapsed_ms": 0})


func test_a_tap_on_an_object_starts_a_session() -> void:
	var sim := _opened()
	_look_at(sim, SLEEPER_SPOT)
	_tap(sim, SLEEPER_SPOT)
	assert_eq(sim.taps[-1]["zone"], TapDispatcher.ZONE_OBJECT)
	assert_eq(sim.session.phase, Session.SESSION)


func test_the_parent_band_and_the_edge_buttons_do_not_start_a_session() -> void:
	var sim := _opened()
	_tap_screen(sim, Vector2(sim.view.screen_size.x * 0.5, TapDispatcher.parent_zone_height(sim.view) * 0.5))
	assert_eq(sim.taps[-1]["zone"], TapDispatcher.ZONE_PARENT)
	assert_eq(sim.session.phase, Session.SCREENSAVER)
	var edge := TapDispatcher.edge_button_rect(1, sim.view).get_center()
	sim.push_input(Simulation.touch_down(0, edge))
	sim.step()
	sim.push_input(Simulation.touch_up(0, edge))
	sim.step()
	assert_eq(sim.taps[-1]["zone"], TapDispatcher.ZONE_EDGE, "the button still works")
	assert_eq(sim.session.phase, Session.SCREENSAVER)
	assert_true(sim.screensaver)


# --- The phases -----------------------------------------------------------------

func test_the_session_winds_down_then_bedtime_then_sunrise() -> void:
	var sim := _in_session()
	_step_at(sim, Session.WIND_DOWN_MS - 1)
	assert_eq(sim.session.phase, Session.SESSION)
	assert_eq(sim.session.dusk(sim.tick), 0.0)
	assert_eq(sim.slimes.hop_rate, 1.0)
	_step_at(sim, Session.WIND_DOWN_MS)
	assert_eq(sim.session.phase, Session.WIND_DOWN, "the last minute")
	assert_false(sim.screensaver)
	_step_at(sim, Session.WIND_DOWN_MS + 30_000)
	assert_almost_eq(sim.session.dusk(sim.tick), 0.5, 1e-6, "halfway to dusk")
	assert_almost_eq(sim.slimes.hop_rate, 0.75, 1e-6, "hops slow down")
	_step_at(sim, Session.BEDTIME_MS - 1)
	assert_eq(sim.session.phase, Session.WIND_DOWN)
	_step_at(sim, Session.BEDTIME_MS)
	assert_eq(sim.session.phase, Session.BEDTIME, "15 minutes")
	assert_eq(sim.session.dusk(sim.tick), 1.0)
	assert_false(sim.screensaver)
	_step_at(sim, Session.SUNRISE_MS - 1)
	assert_eq(sim.session.phase, Session.BEDTIME)
	_step_at(sim, Session.SUNRISE_MS)
	assert_eq(sim.session.phase, Session.SCREENSAVER, "10 minutes later")
	assert_true(sim.screensaver)
	assert_eq(sim.session.sunrise_tick, sim.tick - 1)
	assert_eq(sim.session.elapsed_ms, 0)
	assert_eq(sim.slimes.hop_rate, 1.0)
	assert_gt(sim.session.dusk(sim.tick), 0.9, "the light comes back")
	sim.run(roundi(Session.SUNRISE_SECONDS * Simulation.TICK_RATE))
	assert_eq(sim.session.dusk(sim.tick), 0.0)
	assert_true(sim.session.can_start())
	_tap(sim, GROUND)
	assert_eq(sim.session.phase, Session.SESSION, "the next tap starts a new session")


func test_dusk_and_the_hop_rate_over_the_wind_down() -> void:
	var session := Session.new()
	session.phase = Session.WIND_DOWN
	for case in [[Session.WIND_DOWN_MS, 0.0, 1.0], [Session.WIND_DOWN_MS + 15_000, 0.25, 0.875],
			[Session.BEDTIME_MS, 1.0, 0.5]]:
		session.elapsed_ms = case[0]
		assert_almost_eq(session.dusk(0), case[1], 1e-6, "dusk at %d ms" % case[0])
		assert_almost_eq(session.hop_rate(0), case[2], 1e-6, "hop rate at %d ms" % case[0])
	session.phase = Session.SESSION
	session.elapsed_ms = 1000
	assert_eq(session.dusk(0), 0.0)
	assert_eq(session.hop_rate(0), 1.0)
	session.phase = Session.BEDTIME
	assert_eq(session.hop_rate(0), 1.0, "nobody hops at bedtime anyway")
	session.phase = Session.SCREENSAVER
	session.sunrise_tick = 100
	assert_eq(session.dusk(100), 1.0)
	assert_almost_eq(session.dusk(190), 0.5, 1e-6)
	assert_eq(session.dusk(280), 0.0)


func test_the_hop_rate_slows_the_hop_timers() -> void:
	var bodies := Support.bodies_on_floor()
	bodies.auto_hops = true
	var slime := bodies.create(0, 1, Vector2(0, -24))
	bodies.set_hop_timer(slime, 10.0)
	bodies.hop_rate = 0.5
	bodies.tick(1.0 / 60.0)
	assert_almost_eq(bodies.hop_timer_of(slime), 10.0 - 0.5 / 60.0, 1e-9)
	bodies.hop_rate = 1.0
	bodies.tick(1.0 / 60.0)
	assert_almost_eq(bodies.hop_timer_of(slime), 10.0 - 1.5 / 60.0, 1e-9)


# --- Bedtime --------------------------------------------------------------------

func test_bedtime_puts_the_slimes_to_sleep_hides_the_buttons_and_asks_for_a_save() -> void:
	var sim := _in_session()
	var free := sim.slimes.create(0, 1, Vector2(-600, -24), SlimeBodies.FREE)
	sim.camera.press(1, 3)
	assert_ne(sim.camera.hold_side, 0)
	_step_at(sim, Session.BEDTIME_MS)
	var first := _slime(sim, FIRST_ID)
	assert_eq(sim.slimes.state_of(first), SlimeBodies.BEDTIME_ASLEEP)
	assert_eq(sim.slimes.state_of(free), SlimeBodies.BEDTIME_ASLEEP)
	assert_eq(sim.slimes.state_of(_slime(sim, SLEEPER_ID)), SlimeBodies.SLEEPER, "sleepers stay sleepers")
	assert_false(sim.camera.edge_buttons_visible)
	assert_eq(sim.camera.hold_side, 0, "a held button lets go")
	assert_true(sim.hint.bedtime)
	assert_true(sim.session.save_due)
	sim.run(300)
	assert_eq(sim.slimes.state_of(first), SlimeBodies.BEDTIME_ASLEEP)
	assert_eq(sim.slimes.state_of(free), SlimeBodies.BEDTIME_ASLEEP)
	assert_eq(sim.session.phase, Session.BEDTIME, "no new reading: time stands still")


func test_at_bedtime_a_tap_only_ripples() -> void:
	var sim := _at_bedtime()
	var first := _slime(sim, FIRST_ID)
	_tap(sim, sim.slimes.centre_of(first) + Vector2(60, -40))
	var tap: Dictionary = sim.taps[-1]
	assert_eq(tap["zone"], TapDispatcher.ZONE_GROUND)
	assert_false(tap["call"], "no call")
	assert_eq(tap["answered"], [])
	assert_eq(sim.ripples[-1]["tick"], sim.tick - 1, "the ripple still shows")
	assert_eq(sim.slimes.state_of(first), SlimeBodies.BEDTIME_ASLEEP)
	_look_at(sim, SLEEPER_SPOT)
	_tap(sim, SLEEPER_SPOT)
	assert_eq(sim.taps[-1]["zone"], TapDispatcher.ZONE_GROUND, "objects don't answer")
	assert_eq(sim.taps[-1]["object"], "")
	assert_false(sim.taps[-1]["call"])
	var edge := TapDispatcher.edge_button_rect(-1, sim.view).get_center()
	_tap_screen(sim, edge)
	assert_eq(sim.taps[-1]["zone"], TapDispatcher.ZONE_GROUND, "the edge buttons are hidden")
	assert_eq(sim.camera.hold_side, 0)
	_tap_screen(sim, Vector2(300, 10))
	assert_eq(sim.taps[-1]["zone"], TapDispatcher.ZONE_PARENT, "the parent band stays")
	assert_eq(sim.session.phase, Session.BEDTIME)


# --- Sunrise --------------------------------------------------------------------

func test_sunrise_wakes_the_slimes_near_the_loop_into_the_train_the_others_free() -> void:
	var sim := _in_session()
	var far := sim.slimes.create(0, 1, Vector2(1800, -24), SlimeBodies.FREE)
	_step_at(sim, Session.BEDTIME_MS)
	sim.run(60)
	_step_at(sim, Session.SUNRISE_MS)
	var first := _slime(sim, FIRST_ID)
	assert_eq(sim.slimes.state_of(first), SlimeBodies.TRAIN, "on the loop: the train again")
	assert_false(sim.train.record_of(first).is_empty(), "the train follows it")
	assert_eq(sim.slimes.state_of(far), SlimeBodies.FREE, "off the loop: free")
	assert_eq(sim.free_slimes.phase_of(far), FreeSlimes.HEADING_BACK, "and it heads back")
	assert_eq(sim.slimes.state_of(_slime(sim, SLEEPER_ID)), SlimeBodies.SLEEPER)
	assert_true(sim.camera.edge_buttons_visible)
	assert_false(sim.hint.bedtime)
	assert_true(sim.screensaver)


# --- The clocks -----------------------------------------------------------------

func test_the_timer_follows_the_monotonic_clock_when_the_wall_clock_is_set_back() -> void:
	var sim := _in_session()
	sim.session.read_clock(Session.reading(WALL - 3_600_000, 10_000, "a"))
	sim.step()
	assert_eq(sim.session.elapsed_ms, 10_000, "an hour back on the wall: only 10 s passed")
	sim.session.read_clock(Session.reading(WALL - 3_600_000 + 5_000, 15_000, "a"))
	sim.step()
	assert_eq(sim.session.elapsed_ms, 15_000)


func test_the_timer_follows_the_wall_clock_when_the_monotonic_one_lags() -> void:
	# A phone asleep may pause the monotonic clock; the wall clock ran on.
	var sim := _in_session()
	sim.session.read_clock(Session.reading(WALL + 300_000, 2_000, "a"))
	sim.step()
	assert_eq(sim.session.elapsed_ms, 300_000)
	sim.session.read_clock(Session.reading(WALL + 301_000, 3_000, "a"))
	sim.step()
	assert_eq(sim.session.elapsed_ms, 301_000, "no jitter from the lagging clock")


func test_the_timer_never_runs_backwards() -> void:
	var sim := _in_session()
	_step_at(sim, 60_000)
	sim.session.read_clock(Session.reading(WALL, 0, "a"))
	sim.step()
	assert_eq(sim.session.elapsed_ms, 60_000)


func test_a_restart_counts_the_wall_clock_gap_and_takes_the_neutral_again() -> void:
	var sim := _in_session()
	_step_at(sim, 100_000)
	sim.push_input(Simulation.tilt(-15.0))
	sim.session.read_clock(Session.reading(WALL + 400_000, 50, "b"))
	sim.step()
	assert_eq(sim.session.elapsed_ms, 400_000, "the 5 minutes away count")
	assert_eq(sim.phone_tilt.neutral, -15.0, "reopened: neutral again")
	sim.session.read_clock(Session.reading(WALL + 401_000, 1_050, "b"))
	sim.step()
	assert_eq(sim.session.elapsed_ms, 401_000)


func test_a_restart_with_the_wall_clock_set_back_counts_no_gap() -> void:
	var sim := _in_session()
	_step_at(sim, 100_000)
	sim.session.read_clock(Session.reading(WALL - 86_400_000, 0, "b"))
	sim.step()
	assert_eq(sim.session.elapsed_ms, 100_000)
	sim.session.read_clock(Session.reading(WALL - 86_400_000 + 2_000, 2_000, "b"))
	sim.step()
	assert_eq(sim.session.elapsed_ms, 102_000)


func test_coming_back_to_the_foreground_takes_the_neutral_again() -> void:
	var sim := _in_session()
	sim.push_input(Simulation.tilt(25.0))
	sim.step()
	sim.session.reopened()
	sim.step()
	assert_eq(sim.phone_tilt.neutral, 25.0)
	var idle := _opened()
	idle.push_input(Simulation.tilt(25.0))
	idle.step()
	idle.session.reopened()
	idle.step()
	assert_eq(idle.phone_tilt.neutral, 0.0, "not in screensaver mode")


func test_a_long_gap_catches_up_to_screensaver_mode_without_a_cue() -> void:
	var sim := _in_session()
	_step_at(sim, 7_200_000)
	assert_eq(sim.session.phase, Session.SCREENSAVER, "two hours away")
	assert_eq(sim.session.sunrise_tick, -1, "sunrise is not replayed")
	assert_eq(sim.session.dusk(sim.tick), 0.0)
	assert_true(sim.session.save_due, "bedtime came and went: it asked for a save")
	assert_eq(sim.slimes.state_of(_slime(sim, FIRST_ID)), SlimeBodies.TRAIN, "awake")
	assert_true(sim.camera.edge_buttons_visible)
	assert_true(sim.screensaver)


func test_a_gap_into_bedtime_goes_through_the_wind_down() -> void:
	var sim := _in_session()
	_step_at(sim, 1_000_000)
	assert_eq(sim.session.phase, Session.BEDTIME)
	assert_eq(sim.slimes.state_of(_slime(sim, FIRST_ID)), SlimeBodies.BEDTIME_ASLEEP)
	_step_at(sim, Session.SUNRISE_MS + 500)
	assert_eq(sim.session.phase, Session.SCREENSAVER)
	assert_eq(sim.session.sunrise_tick, sim.tick - 1, "a little late: the cue still shows")


# --- Saves ----------------------------------------------------------------------

func _through_json(save: Dictionary) -> Dictionary:
	var json := JSON.new()
	assert_eq(json.parse(SaveData.to_text(save)), OK)
	return json.data


func _reloaded(sim: Simulation) -> Simulation:
	var save := _through_json(sim.to_save())
	assert_eq(SaveData.problems(save, _level()), PackedStringArray())
	return Simulation.from_save(save, _level(), _terrain())


func test_a_session_reloads_with_the_same_hash_and_carries_on() -> void:
	var sim := _in_session()
	_step_at(sim, Session.WIND_DOWN_MS + 10_000)
	sim.run(30)
	# (D12, chunk 19: a load puts mid-air slimes down)
	MidairLanding.apply(sim)
	var reloaded := _reloaded(sim)
	assert_eq(reloaded.state_hash(), sim.state_hash())
	assert_eq(reloaded.session.dump(), sim.session.dump())
	for game in [sim, reloaded]:
		_step_at(game, Session.WIND_DOWN_MS + 20_000)
		game.run(30)
	assert_eq(reloaded.session.elapsed_ms, Session.WIND_DOWN_MS + 20_000)
	assert_eq(reloaded.state_hash(), sim.state_hash(), "carried on the same")


func test_bedtime_reloads_asleep_with_the_buttons_hidden() -> void:
	var sim := _at_bedtime()
	sim.run(10)
	var reloaded := _reloaded(sim)
	assert_eq(reloaded.state_hash(), sim.state_hash())
	assert_eq(reloaded.session.phase, Session.BEDTIME)
	assert_false(reloaded.camera.edge_buttons_visible)
	assert_true(reloaded.hint.bedtime)
	assert_eq(reloaded.slimes.state_of(_slime(reloaded, FIRST_ID)), SlimeBodies.BEDTIME_ASLEEP)
	# Killed at bedtime, back 4 minutes later after a restart: the rest of the
	# cooldown runs.
	reloaded.session.read_clock(Session.reading(WALL + Session.BEDTIME_MS + 240_000, 0, "b"))
	reloaded.step()
	assert_eq(reloaded.session.phase, Session.BEDTIME)
	assert_eq(reloaded.session.elapsed_ms, Session.BEDTIME_MS + 240_000)
	reloaded.session.read_clock(Session.reading(WALL + Session.SUNRISE_MS, 360_000, "b"))
	reloaded.step()
	assert_eq(reloaded.session.phase, Session.SCREENSAVER)


func test_the_readable_save_keeps_a_running_session_from_tick_0() -> void:
	var sim := _in_session()
	_step_at(sim, 60_000)
	var readable := SaveData.readable(sim.to_save())
	assert_eq(readable["session"]["phase"], Session.SESSION)
	assert_eq(readable["session"]["elapsed_ms"], 60_000)
	assert_eq(readable["session"]["clock"]["tick"], 0, "a readable save starts at tick 0")
	var idle := _opened()
	assert_false(SaveData.readable(idle.to_save()).has("session"), "screensaver mode: nothing to keep")


func test_the_save_checks_the_session() -> void:
	var sim := _in_session()
	_step_at(sim, 1_000)
	var good := _through_json(sim.to_save())
	assert_eq(SaveData.problems(good, _level()), PackedStringArray())
	var cases := {
		"phase": func(s: Dictionary) -> void: s["phase"] = "dusk",
		"elapsed_ms": func(s: Dictionary) -> void: s["elapsed_ms"] = -1,
		"clock": func(s: Dictionary) -> void: s.erase("clock"),
		"epoch": func(s: Dictionary) -> void: s["clock"]["epoch"] = 3,
		"wall_ms": func(s: Dictionary) -> void: s["anchor"]["wall_ms"] = 1.5,
	}
	for name in cases:
		var bad: Dictionary = good.duplicate(true)
		cases[name].call(bad["session"])
		assert_false(SaveData.problems(bad, _level()).is_empty(), "a bad %s is refused" % name)


# --- Test mode's clock ----------------------------------------------------------

func test_the_test_clock_runs_with_the_ticks_and_skips() -> void:
	var clock := TestClock.for_run(null, 0, {}, {120: 600_000})
	assert_eq(clock.reading_at(0), TestClock.default_reading())
	assert_eq(clock.reading_at(60)["wall_ms"], TestClock.DEFAULT_WALL_MS + 1000)
	assert_eq(clock.reading_at(119)["mono_ms"], TestClock.ms_at(119))
	assert_eq(clock.reading_at(120)["mono_ms"], 2000 + 600_000, "the skip lands before tick 120")
	assert_eq(clock.reading_at(120)["wall_ms"] - clock.reading_at(119)["wall_ms"], 600_000 + 17)
	assert_eq(clock.reading_at(500)["epoch"], TestClock.EPOCH)


func test_a_reloaded_run_carries_on_the_saved_clock() -> void:
	var saved := {"clock": {"wall_ms": 5_000_000, "mono_ms": 70_000, "epoch": "test", "tick": 300}}
	var skips := {100: 1000, 400: 2000}
	var clock := TestClock.for_run(saved, 300, {}, skips)
	assert_eq(clock.reading_at(300), Session.reading(5_000_000, 70_000, "test"))
	assert_eq(clock.reading_at(400)["wall_ms"], 5_000_000 + TestClock.ms_at(400) - TestClock.ms_at(300) + 2000,
			"only the skips from the run's start count")
	var away := TestClock.for_run(saved, 300, {"away": 60, "restarted": true}, {})
	assert_eq(away.reading_at(300), Session.reading(5_060_000, 0, "test/restarted"))


func test_skip_steps_parse() -> void:
	var parsed := TestModeScript.parse([{"tick": 90, "do": "skip", "seconds": 600},
			{"tick": 90, "do": "skip", "seconds": 0.5}, {"tick": 10, "do": "tap", "at": [1, 2]}])
	assert_eq(parsed.errors, PackedStringArray())
	assert_eq(parsed.skips, {90: 600_500})
	assert_eq(parsed.events_at(90), [], "a skip is no input")
	assert_eq(parsed.last_tick, 90)
	for bad in [{"tick": 1, "do": "skip"}, {"tick": 1, "do": "skip", "seconds": 0},
			{"tick": 1, "do": "skip", "seconds": "10"}, {"tick": 1, "do": "skip", "seconds": 5, "at": [1, 1]}]:
		assert_false(TestModeScript.parse([bad]).errors.is_empty(), "refused: %s" % [bad])


func test_test_mode_checks_its_session_settings() -> void:
	var good := TestMode.from_config({"seed": 1, "sessions": true,
			"clock": {"away": 30, "restarted": true}})
	assert_eq(good.errors, PackedStringArray())
	assert_true(good.sessions)
	assert_eq(good.clock_at(0), Session.reading(TestClock.DEFAULT_WALL_MS + 30_000, 0, "test/restarted"))
	for bad in [{"sessions": 1}, {"clock": {"away": -1}}, {"clock": {"later": 1}}, {"clock": []}]:
		bad["seed"] = 1
		assert_false(TestMode.from_config(bad).errors.is_empty(), "refused: %s" % [bad])


# --- The clock rule ---------------------------------------------------------------

func test_nothing_under_src_sim_reads_a_clock() -> void:
	# The simulation is handed its clocks (Session.read_clock); reading one
	# there would make runs impossible to repeat.
	var clock_call := RegEx.create_from_string("\\b(Time\\s*\\.|OS\\s*\\.\\s*get_ticks|get_unix_time|get_ticks_(m|u)sec)")
	assert_not_null(clock_call.search("var t := Time.get_ticks_msec()"), "the check catches offenders")
	var offenders := PackedStringArray()
	for file in DirAccess.get_files_at("res://src/sim/"):
		if not file.ends_with(".gd"):
			continue
		var path := "res://src/sim/".path_join(file)
		var lines := FileAccess.get_file_as_string(path).split("\n")
		for i in lines.size():
			if clock_call.search(lines[i].split("#")[0]) != null:
				offenders.append("%s:%d: %s" % [path, i + 1, lines[i].strip_edges()])
	assert_eq(offenders, PackedStringArray(), "hand the simulation its clocks instead")
