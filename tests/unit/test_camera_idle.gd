extends GutTest
## The idle camera and screensaver mode (master spec §5.6, §5.7, DoD 19):
## after 45 s with no input the camera glides to the train slime nearest the
## middle of the view and follows it, through fusion (the fused slime) and
## splitting (one of the pieces); the cue, from 10 s before, is a slow
## zoom-out toward the one zoom idle and screensaver mode share, 10-20 %
## wider than normal play. Any touch takes back control and still does its
## normal job. Framing zones are ignored while following, and framing resumes
## on touch only if the camera's centre is still inside a zone. Screensaver
## mode starts on the idle camera straight away.
##
## The camera is driven as the Simulation drives it: watch() (the slimes,
## whether a finger is down, screensaver mode) then step(), once a tick.
## Slimes float with no gravity and no hops, so they only move when a test
## pushes them.

# @test-link [[req_idle_camera_and_screensaver_zoom]]
# @test-link [[req_camera_rails_and_framing]]

const DT := Simulation.TICK_SECONDS
const TICK_RATE := Simulation.TICK_RATE
const SCREEN := ScreenView.DEFAULT_SIZE
const ZONE := "t.frame.wide"
const ZONE_BOX := Rect2(2000, -600, 800, 700)
const ZONE_ZOOM := 0.8
const ZONE_OFFSET := Vector2(0, -100)

var _tick := 0
var _loop: LoopData
var _bodies: SlimeBodies


func before_each() -> void:
	_tick = 0
	_loop = LoopData.new("t.loop")
	_loop.add_segment("t.loop.out", 1, LoopData.OUTGOING, PackedVector2Array([
			Vector2(0, 0), Vector2(3000, 0)]))
	_loop.add_segment("t.slide", 1, LoopData.RETURN, PackedVector2Array([
			Vector2(3000, 0), Vector2(3000, 400), Vector2(0, 400), Vector2(0, 0)]), "t.gate")
	_bodies = SlimeBodies.new(Rng.new(5))
	_bodies.gravity = Vector2.ZERO
	_bodies.auto_hops = false


func _camera(near: Vector2) -> Camera:
	var data := LevelData.new("t", 1)
	data.add_framing_zone(ZONE, ZONE_BOX, ZONE_ZOOM, ZONE_OFFSET)
	var camera := Camera.new()
	camera.zones = data.framing_zones
	camera.start(_loop, [], near)
	return camera


## `ticks` ticks of the camera, the slimes ticking too; `touching` says a
## finger is down all along, `bedtime` that it is bedtime.
func _run(camera: Camera, ticks: int, touching := false, screensaver := false, bedtime := false) -> void:
	for i in ticks:
		_bodies.tick(DT)
		camera.watch(_bodies, touching, screensaver, bedtime)
		camera.step(_loop, [], DT, _tick)
		_tick += 1


func _train(at: Vector2, species := 0, size := 1) -> int:
	return _bodies.create(species, size, at, SlimeBodies.TRAIN)


func _idle_ticks() -> int:
	return int(Camera.IDLE_SECONDS * TICK_RATE)


func _cue_ticks() -> int:
	return int(Camera.CUE_SECONDS * TICK_RATE)


# --- The timer and the cue -------------------------------------------------------

func test_the_idle_camera_takes_over_after_45_s_with_the_cue_from_35_s() -> void:
	assert_eq(Camera.IDLE_SECONDS, 45.0)
	assert_eq(Camera.CUE_SECONDS, 10.0)
	var camera := _camera(Vector2(1000, 0))
	_train(Vector2(1100, -24))
	_run(camera, _idle_ticks() - _cue_ticks())
	assert_eq(camera.zoom, 1.0, "35 s: no cue yet")
	assert_eq(camera.mode, Camera.RAILS)
	var last := camera.zoom
	for i in _cue_ticks() - 1:
		_run(camera, 1)
		assert_lt(camera.zoom, last, "the cue: a slow zoom-out, every tick")
		assert_lt(last - camera.zoom, 0.001, "slow")
		assert_eq(camera.mode, Camera.RAILS, "still the child's camera during the cue")
		last = camera.zoom
		if i == _cue_ticks() / 2:
			assert_almost_eq(camera.zoom, (1.0 + Camera.IDLE_ZOOM) * 0.5, 0.01, "half way at 40 s")
	_run(camera, 1)
	assert_eq(camera.mode, Camera.FOLLOW, "45 s: the idle camera")
	assert_eq(camera.zoom, Camera.IDLE_ZOOM, "on the shared zoom")


func test_a_finger_held_down_is_input() -> void:
	var camera := _camera(Vector2(1000, 0))
	_train(Vector2(1100, -24))
	_run(camera, _idle_ticks() + TICK_RATE, true)
	assert_eq(camera.mode, Camera.RAILS)
	assert_eq(camera.zoom, 1.0)
	_run(camera, _idle_ticks() - 1)
	assert_eq(camera.mode, Camera.RAILS, "45 s from the finger lifting")
	_run(camera, 1)
	assert_eq(camera.mode, Camera.FOLLOW)


func test_without_a_train_slime_it_waits() -> void:
	var camera := _camera(Vector2(1000, 0))
	_bodies.create(0, 1, Vector2(1000, -24), SlimeBodies.SLEEPER)
	_run(camera, _idle_ticks() + TICK_RATE)
	assert_eq(camera.mode, Camera.RAILS, "nothing to follow")
	var slime := _train(Vector2(1300, -24))
	_run(camera, 1)
	assert_eq(camera.mode, Camera.FOLLOW)
	assert_eq(camera.follow_id, slime)


# --- Following -----------------------------------------------------------------------

func test_it_follows_the_train_slime_nearest_the_middle_of_the_view() -> void:
	var camera := _camera(Vector2(1000, 0))
	_train(Vector2(1600, -24))
	var nearest := _train(Vector2(1250, -24))
	_train(Vector2(700, -24))
	_bodies.create(0, 1, camera.position, SlimeBodies.FREE)
	_bodies.create(0, 1, camera.position + Vector2(10, 0), SlimeBodies.SLEEPER)
	_run(camera, _idle_ticks())
	assert_eq(camera.mode, Camera.FOLLOW)
	assert_eq(camera.follow_id, nearest, "the train slime nearest the middle (not a free slime nor a sleeper)")
	var from := camera.position
	var last := from.distance_to(_bodies.centre_of(nearest) + Camera.RAIL_OFFSET)
	for i in TICK_RATE / 2:
		_run(camera, 1)
		var gap := camera.position.distance_to(_bodies.centre_of(nearest) + Camera.RAIL_OFFSET)
		assert_lt(gap, last + 1e-3, "it glides to it")
		assert_lt(camera.position.distance_to(from), Camera.FOLLOW_PACE * DT * (i + 1) + 1e-3, "no jump")
		last = gap
	_run(camera, 3 * TICK_RATE)
	assert_lt(camera.position.distance_to(_bodies.centre_of(nearest) + Camera.RAIL_OFFSET), 1.0, "on it")
	_bodies.set_velocity(nearest, Vector2(150, 0))
	_run(camera, 3 * TICK_RATE)
	var ahead := _bodies.centre_of(nearest)
	assert_gt(ahead.x, 1500.0, "the slime moved on")
	assert_lt(camera.position.distance_to(ahead + Camera.RAIL_OFFSET), 150.0, "and the camera went with it")


func test_it_follows_the_fused_slime() -> void:
	var camera := _camera(Vector2(1000, 0))
	var lower := _train(Vector2(700, -24))
	var followed := _train(Vector2(1050, -24))
	_train(Vector2(1300, -24), 1)
	_run(camera, _idle_ticks())
	assert_eq(camera.follow_id, followed)
	assert_eq(_bodies.merge(lower, followed), lower, "the lower id survives the fusion")
	_run(camera, 1)
	assert_eq(camera.follow_id, lower, "it follows the fused slime")
	assert_eq(camera.mode, Camera.FOLLOW)
	_run(camera, 4 * TICK_RATE)
	assert_lt(camera.position.distance_to(_bodies.centre_of(lower) + Camera.RAIL_OFFSET), 1.0)


func test_it_follows_the_fused_slime_when_it_had_the_lower_id() -> void:
	var camera := _camera(Vector2(1000, 0))
	var followed := _train(Vector2(1000, -24))
	var other := _train(Vector2(1400, -24))
	_run(camera, _idle_ticks())
	assert_eq(camera.follow_id, followed)
	_bodies.merge(other, followed)
	_run(camera, 1)
	assert_eq(camera.follow_id, followed)


func test_it_follows_one_of_the_pieces_when_its_slime_splits() -> void:
	var camera := _camera(Vector2(1000, 0))
	var big := _train(Vector2(1050, -40), 0, 3)
	_run(camera, _idle_ticks())
	assert_eq(camera.follow_id, big)
	var parts := _bodies.split(big)
	assert_eq(parts.size(), 3)
	_run(camera, 1)
	assert_true(camera.follow_id in Array(parts), "one of the pieces")
	assert_eq(camera.follow_id, parts[0], "the piece that keeps the id")
	assert_eq(camera.mode, Camera.FOLLOW)


# --- Taking back control ---------------------------------------------------------------

func test_a_touch_takes_back_control() -> void:
	var camera := _camera(Vector2(1000, 0))
	_train(Vector2(1300, -24))
	_run(camera, _idle_ticks() + 3 * TICK_RATE)
	assert_eq(camera.mode, Camera.FOLLOW)
	camera.touched()
	_run(camera, 1)
	assert_ne(camera.mode, Camera.FOLLOW, "the child has the camera back")
	assert_eq(camera.follow_id, -1)
	_run(camera, 10 * TICK_RATE)
	assert_eq(camera.mode, Camera.RAILS, "back on the rails")
	assert_almost_eq(camera.zoom, 1.0, 1e-6, "at the normal zoom")
	_run(camera, _idle_ticks() - 10 * TICK_RATE - 2)
	assert_eq(camera.mode, Camera.RAILS, "a fresh 45 s from the touch")


func test_a_touch_during_the_cue_stops_it() -> void:
	var camera := _camera(Vector2(1000, 0))
	_train(Vector2(1300, -24))
	_run(camera, _idle_ticks() - _cue_ticks() / 2)
	assert_lt(camera.zoom, 1.0)
	camera.touched()
	_run(camera, 5 * TICK_RATE)
	assert_almost_eq(camera.zoom, 1.0, 1e-6, "the zoom goes back")
	assert_eq(camera.mode, Camera.RAILS)


func test_an_edge_press_while_following_moves_on_from_the_nearest_rail_point() -> void:
	var camera := _camera(Vector2(1000, 0))
	_train(Vector2(1300, -24))
	_run(camera, _idle_ticks() + 4 * TICK_RATE)
	camera.touched()
	camera.press(1, 0)
	camera.release(0)
	_run(camera, 3 * TICK_RATE)
	assert_eq(camera.mode, Camera.RAILS)
	assert_almost_eq(camera.distance, 1300.0 + Camera.STEP, 2.0, "one step on from the rail point by the slime")


# --- Framing zones while following ----------------------------------------------------------

func test_framing_zones_are_ignored_while_following() -> void:
	var camera := _camera(Vector2(1500, 0))
	var slime := _train(Vector2(1600, -24))
	_run(camera, _idle_ticks() + 2 * TICK_RATE)
	_bodies.set_velocity(slime, Vector2(250, 0))
	var passed_zone := false
	for i in 4 * TICK_RATE:
		_run(camera, 1)
		passed_zone = passed_zone or ZONE_BOX.has_point(camera.position)
		assert_eq(camera.zoom, Camera.IDLE_ZOOM, "the shared zoom, whatever the zone")
		assert_eq(camera.frame_zone, "")
	assert_true(passed_zone, "the camera went through the zone")


func test_on_touch_framing_resumes_if_the_centre_is_still_in_a_zone() -> void:
	var camera := _camera(Vector2(2400, 0))
	_train(Vector2(2400, -24))
	_run(camera, _idle_ticks() + 3 * TICK_RATE)
	assert_eq(camera.mode, Camera.FOLLOW)
	assert_true(ZONE_BOX.has_point(camera.position))
	camera.touched()
	_run(camera, 1)
	assert_eq(camera.frame_zone, ZONE, "the centre is in the zone: its framing resumes")
	_run(camera, 10 * TICK_RATE)
	assert_almost_eq(camera.zoom, ZONE_ZOOM, 1e-6)
	assert_eq(camera.mode, Camera.RAILS)


func test_on_touch_outside_a_zone_it_returns_to_the_rails_unframed() -> void:
	var camera := _camera(Vector2(1000, 0))
	_train(Vector2(1300, -24))
	_run(camera, _idle_ticks() + 3 * TICK_RATE)
	camera.touched()
	_run(camera, 1)
	assert_eq(camera.frame_zone, "")
	assert_eq(camera.mode, Camera.RETURN, "back to the rails as after a call")
	_run(camera, 10 * TICK_RATE)
	assert_eq(camera.mode, Camera.RAILS)
	assert_almost_eq(camera.zoom, 1.0, 1e-6)


# --- Screensaver mode and the shared zoom -----------------------------------------------------

func test_screensaver_mode_starts_on_the_idle_camera_straight_away() -> void:
	var camera := _camera(Vector2(1000, 0))
	var slime := _train(Vector2(1200, -24))
	_run(camera, 1, false, true)
	assert_eq(camera.mode, Camera.FOLLOW, "no 45 s wait")
	assert_eq(camera.follow_id, slime)
	assert_eq(camera.zoom, Camera.IDLE_ZOOM, "on the shared zoom at once, no cue")
	camera.touched()
	_run(camera, 1, false, true)
	assert_ne(camera.mode, Camera.FOLLOW, "a touch takes control in screensaver mode too")
	_run(camera, _idle_ticks() - 1, false, true)
	assert_ne(camera.mode, Camera.FOLLOW, "then the usual 45 s")
	_run(camera, 1, false, true)
	assert_eq(camera.mode, Camera.FOLLOW)


func test_screensaver_mode_inside_a_wide_zone_keeps_its_zoom() -> void:
	var camera := _camera(Vector2(2400, 0))
	_train(Vector2(2400, -24))
	assert_eq(camera.zoom, ZONE_ZOOM)
	assert_lt(ZONE_ZOOM, Camera.IDLE_ZOOM, "the zone is wider than the idle zoom")
	_run(camera, 1, false, true)
	assert_eq(camera.mode, Camera.FOLLOW)
	assert_eq(camera.zoom, ZONE_ZOOM, "it never zooms in (D103); nor does it stack with the zone's")
	assert_eq(camera.frame_zone, "", "the zone is ignored while following")


# --- The idle zoom never zooms in (item 23.4, D103) -----------------------------------------------

func test_inside_a_wide_zone_the_cue_and_the_idle_camera_keep_its_zoom() -> void:
	var camera := _camera(Vector2(2400, 0))
	var slime := _train(Vector2(2450, -24))
	assert_eq(camera.zoom, ZONE_ZOOM)
	for i in _idle_ticks() + 2 * TICK_RATE:
		_run(camera, 1)
		assert_true(camera.zoom <= ZONE_ZOOM, "never above the zone's zoom")
	assert_eq(camera.mode, Camera.FOLLOW)
	assert_eq(camera.zoom, ZONE_ZOOM, "the idle camera keeps it")
	_bodies.set_velocity(slime, Vector2(-250, 0))
	for i in 4 * TICK_RATE:
		_run(camera, 1)
		assert_eq(camera.zoom, ZONE_ZOOM, "out of the zone too, while following")
	assert_false(ZONE_BOX.has_point(camera.position), "the slime led it out of the zone")


func test_in_a_zone_narrower_than_the_idle_zoom_the_cue_zooms_out_as_before() -> void:
	var data := LevelData.new("t", 1)
	data.add_framing_zone("t.frame.mild", ZONE_BOX, 0.95, Vector2.ZERO)
	var camera := Camera.new()
	camera.zones = data.framing_zones
	camera.start(_loop, [], Vector2(2400, 0))
	_train(Vector2(2450, -24))
	assert_eq(camera.zoom, 0.95)
	_run(camera, _idle_ticks() - _cue_ticks() / 2)
	assert_lt(camera.zoom, 0.95, "the cue zooms out")
	_run(camera, _cue_ticks())
	assert_eq(camera.mode, Camera.FOLLOW)
	assert_eq(camera.zoom, Camera.IDLE_ZOOM, "to the shared zoom")


# --- At bedtime (item 23.12) ----------------------------------------------------------------------

## Bedtime as the session makes it: every awake slime falls asleep where it is.
func _bedtime() -> void:
	for slime_id in _bodies.ids():
		if _bodies.state_of(slime_id) in [SlimeBodies.TRAIN, SlimeBodies.FREE]:
			_bodies.set_state(slime_id, SlimeBodies.BEDTIME_ASLEEP)


func _sunrise() -> void:
	for slime_id in _bodies.ids():
		if _bodies.state_of(slime_id) == SlimeBodies.BEDTIME_ASLEEP:
			_bodies.set_state(slime_id, SlimeBodies.TRAIN)


func test_at_bedtime_the_idle_camera_follows_no_one_and_stays_put() -> void:
	var camera := _camera(Vector2(1000, 0))
	var slime := _train(Vector2(1400, -24))
	_run(camera, _idle_ticks() + 10)
	assert_eq(camera.mode, Camera.FOLLOW)
	assert_gt(camera.position.distance_to(_bodies.centre_of(slime) + Camera.RAIL_OFFSET), 50.0,
			"still gliding to its slime")
	_bedtime()
	# The slime drifts: a camera still following it would move.
	_bodies.set_velocity(slime, Vector2(40, 0))
	_run(camera, 1, false, false, true)
	var still := camera.position
	for i in 20 * TICK_RATE:
		_run(camera, 1, false, false, true)
		assert_eq(camera.position, still, "it travels nowhere")
	assert_eq(camera.follow_id, -1, "it follows no one")
	assert_eq(camera.zoom, Camera.IDLE_ZOOM, "at the idle zoom")
	_bodies.set_velocity(slime, Vector2.ZERO)
	_sunrise()
	_run(camera, 1, false, true, false)
	assert_eq(camera.mode, Camera.FOLLOW)
	assert_eq(camera.follow_id, slime, "at sunrise it follows a train slime again")


func test_bedtime_during_the_cue_starts_no_idle_camera() -> void:
	var camera := _camera(Vector2(1000, 0))
	var slime := _train(Vector2(1400, -24))
	_run(camera, _idle_ticks() - _cue_ticks() / 2)
	assert_lt(camera.zoom, 1.0, "the cue is on")
	_bedtime()
	var still := camera.position
	for i in _cue_ticks() + 20 * TICK_RATE:
		_run(camera, 1, false, false, true)
		assert_eq(camera.position, still, "it travels nowhere")
	assert_eq(camera.mode, Camera.RAILS, "no idle camera at bedtime")
	assert_eq(camera.zoom, Camera.IDLE_ZOOM, "the zoom may settle at the idle zoom")
	_sunrise()
	_run(camera, 1, false, true, false)
	assert_eq(camera.mode, Camera.FOLLOW)
	assert_eq(camera.follow_id, slime, "at sunrise it follows a train slime again")


func test_idle_and_screensaver_share_one_zoom_10_to_20_percent_wider() -> void:
	assert_between(1.0 / Camera.IDLE_ZOOM, 1.1, 1.2, "10-20 % wider than normal play")
	var idle := _camera(Vector2(1000, 0))
	_train(Vector2(1100, -24))
	_run(idle, _idle_ticks())
	var screensaver := _camera(Vector2(1000, 0))
	_run(screensaver, 1, false, true)
	assert_eq(idle.zoom, screensaver.zoom)
	assert_eq(idle.zoom, Camera.IDLE_ZOOM)


# --- In the Simulation ----------------------------------------------------------------------

func _sim() -> Simulation:
	var sim := Simulation.new(3)
	sim.slimes.terrain = TerrainSegments.new([load("res://tests/unit/slime_test_support.gd").floor_polygon()])
	var data := LevelData.new("camera", 1)
	var loop := LoopData.new("t.loop")
	loop.add_segment("t.loop.out", 1, LoopData.OUTGOING, PackedVector2Array([
			Vector2(-1500, -24), Vector2(1500, -24)]))
	loop.add_segment("t.slide", 1, LoopData.RETURN, PackedVector2Array([
			Vector2(1500, -24), Vector2(1500, 400), Vector2(-1500, 400), Vector2(-1500, -24)]), "t.gate")
	data.loop = loop
	data.add_framing_zone("t.frame.far", Rect2(900, -500, 500, 500), 0.7, Vector2(0, -100))
	sim.load_level(data)
	return sim


func test_the_simulation_hands_the_level_s_zones_to_its_camera() -> void:
	var sim := _sim()
	assert_eq(sim.camera.zones.keys(), ["t.frame.far"])


func test_a_simulation_plays_as_in_a_session_until_screensaver_mode_is_on() -> void:
	var sim := _sim()
	assert_false(sim.screensaver, "the game root turns it on (chunk 17 drives it)")
	sim.spawn_train_slime(0, 1, 100.0)
	sim.run(TICK_RATE)
	assert_eq(sim.camera.mode, Camera.RAILS)
	sim.screensaver = true
	sim.step()
	assert_eq(sim.camera.mode, Camera.FOLLOW)
	assert_eq(sim.camera.zoom, Camera.IDLE_ZOOM)
	assert_true(sim.dump()["camera"]["screensaver"], "the camera's dump has it")


func test_in_the_simulation_the_idle_camera_waits_45_s_without_a_touch() -> void:
	var sim := _sim()
	sim.spawn_train_slime(0, 1, 100.0)
	sim.push_input(Simulation.touch_down(0, Vector2(600, 400)))
	sim.push_input(Simulation.touch_up(0, null))
	sim.run(_idle_ticks())
	assert_eq(sim.camera.mode, Camera.RAILS, "the tap reset the clock")
	sim.push_input(Simulation.tilt(20.0))
	sim.run(TICK_RATE)
	assert_eq(sim.camera.mode, Camera.FOLLOW, "tilt isn't touching: 45 s after the tap")


func test_a_tap_on_open_ground_takes_back_control_and_still_calls() -> void:
	var sim := _sim()
	var slime := sim.spawn_train_slime(0, 1, 1500.0)
	sim.screensaver = true
	sim.run(2 * TICK_RATE)
	assert_eq(sim.camera.mode, Camera.FOLLOW)
	sim.camera.apply_to(sim.view, SCREEN)
	var at := sim.view.world_to_screen(sim.slimes.centre_of(slime) + Vector2(150, -30))
	sim.push_input(Simulation.touch_down(0, at))
	sim.push_input(Simulation.touch_up(0, at))
	sim.step()
	var tap: Dictionary = sim.taps.back()
	assert_eq(tap["zone"], TapDispatcher.ZONE_GROUND)
	assert_true(tap["call"], "the tap does its normal job")
	assert_eq(tap["answered"], [slime])
	assert_eq(sim.camera.mode, Camera.DRAG, "and the camera is the child's again")


func test_an_edge_tap_takes_back_control_and_moves_the_camera() -> void:
	var sim := _sim()
	sim.spawn_train_slime(0, 1, 1500.0)
	sim.screensaver = true
	sim.run(2 * TICK_RATE)
	sim.camera.apply_to(sim.view, SCREEN)
	sim.push_input(Simulation.touch_down(0, TapDispatcher.edge_button_rect(-1, SCREEN).get_center()))
	sim.push_input(Simulation.touch_up(0, null))
	sim.step()
	assert_eq(sim.camera.mode, Camera.RAILS)
	assert_false(sim.taps.back()["call"])
	var from := sim.camera.distance + sim.camera.rail_left
	sim.run(3 * TICK_RATE)
	assert_almost_eq(sim.camera.distance, from, 1e-6, "one step backward")


# --- State ------------------------------------------------------------------------------------

func test_the_idle_camera_is_in_the_dump_and_restores() -> void:
	var a := _camera(Vector2(1000, 0))
	_train(Vector2(1300, -24))
	_run(a, _idle_ticks() - 60)
	var b := Camera.new()
	b.zones = a.zones
	b.restore(a.dump())
	assert_eq(StateHash.canonical_json(b.dump()), StateHash.canonical_json(a.dump()))
	var tick := _tick
	# The bodies are shared: run each camera over the same slimes, one tick
	# at a time, without moving them.
	for i in 3 * TICK_RATE:
		a.watch(_bodies, false, false, false)
		a.step(_loop, [], DT, tick + i)
		b.watch(_bodies, false, false, false)
		b.step(_loop, [], DT, tick + i)
	assert_eq(a.mode, Camera.FOLLOW)
	assert_eq(StateHash.canonical_json(b.dump()), StateHash.canonical_json(a.dump()))
