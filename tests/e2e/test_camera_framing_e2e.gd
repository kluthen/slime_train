extends GutTest
## End-to-end on the test level (the Meadow), chunk 13: framing zones and the
## idle camera through the real game scene and test mode's scripted input.
## Holding the right edge button carries the camera into s1.frame.tree, which
## zooms out and shifts the view up to show the tree's lower platform; short
## presses stay inside it and a long hold leaves it. Left alone for 45 s the
## camera starts following the first slime, after a 10 s zoom-out cue; a tap
## takes the camera back and still calls. Screensaver mode starts on the idle
## camera. A seeded run is repeatable.

# @test-link [[req_camera_rails_and_framing]]
# @test-link [[rule_framing_zone_wherever_wider_view_needed]]
# @test-link [[req_idle_camera_and_screensaver_zoom]]

const MAIN_SCENE := "res://src/main.tscn"
const SEED := 91
const TICK_RATE := Simulation.TICK_RATE
const SCREEN := ScreenView.DEFAULT_SIZE
const HOLD_FROM := 10
const TREE := "s1.frame.tree"
const HIGH_STEP := "s1.frame.high-step"
## Where the right button takes the camera: the middle of the tree's zone
## (x 4.5-5.5 screens), on the loop.
const TREE_MIDDLE_X := 5.0 * LevelData.SCREEN


func _boot(steps: Array = []) -> Node:
	var game: Node = load(MAIN_SCENE).instantiate()
	add_child_autofree(game)
	assert_eq(game.enable_test_mode({"seed": SEED, "time_scale": 0, "steps": steps}), PackedStringArray())
	return game


func _button(side: int) -> Array:
	var at := TapDispatcher.edge_button_rect(side, ScreenView.new(Vector2.ZERO, 1.0, SCREEN)).get_center()
	return [at.x, at.y]


func _ticks_for(distance: float) -> int:
	return ceili(distance / Camera.PACE * TICK_RATE)


## How long to hold the right button from the start of the loop so the
## camera comes to rest in the middle of the tree's zone.
func _hold_to_tree(game: Node) -> int:
	var sim: Simulation = game.simulation
	var loop := sim.level.loop
	var target: float = loop.closest(Vector2(TREE_MIDDLE_X, -80), sim.train.open_gates)["distance"]
	return _ticks_for(target - sim.camera.distance - Camera.STEP)


func _to_tree_steps(hold: int) -> Array:
	return [
		{"tick": HOLD_FROM, "do": "touch_down", "at": _button(1)},
		{"tick": HOLD_FROM + hold, "do": "touch_up"},
	]


func _rail_point(sim: Simulation) -> Vector2:
	return Camera.rail_point(sim.level.loop, sim.train.open_gates, sim.camera.distance)


func _assert_scene_mirrors(game: Node) -> void:
	var sim: Simulation = game.simulation
	assert_eq(game.camera.position, sim.view.centre, "the Camera2D shows the simulation's view")
	assert_eq(game.camera.zoom, Vector2(sim.camera.zoom, sim.camera.zoom), "and its zoom")


func test_the_meadow_s_framing_zones_reach_the_camera() -> void:
	var game := _boot()
	var sim: Simulation = game.simulation
	var zones := sim.level.framing_zones
	assert_true(zones.has(TREE))
	assert_true(zones.has(HIGH_STEP))
	assert_eq(sim.camera.zones, zones)
	assert_lt(zones[TREE]["zoom"], zones[HIGH_STEP]["zoom"], "the tree needs the wider view")
	assert_lt(zones[TREE]["zoom"], 1.0)
	assert_lt((zones[TREE]["offset"] as Vector2).y, 0.0, "shifted up, toward the platform")
	assert_eq(sim.camera.frame_zone, "", "the start of the loop is framed as usual")
	assert_eq(sim.camera.zoom, 1.0)


func test_driving_into_the_tree_zone_reframes_the_view() -> void:
	var hold := _hold_to_tree(_boot())
	var game := _boot(_to_tree_steps(hold))
	var sim: Simulation = game.simulation
	var zones := sim.level.framing_zones
	game.test_mode.run_ticks(HOLD_FROM + hold)
	var seen := {}
	var last_zoom := sim.camera.zoom
	for i in 5 * TICK_RATE:
		game.test_mode.run_ticks(1)
		seen[sim.camera.frame_zone] = true
		assert_lt(absf(sim.camera.zoom - last_zoom), 0.01, "no jump in zoom")
		last_zoom = sim.camera.zoom
	assert_true(seen.has(TREE))
	assert_eq(sim.camera.frame_zone, TREE, "at rest in the tree's zone")
	assert_true((zones[TREE]["box"] as Rect2).has_point(_rail_point(sim)))
	assert_almost_eq(sim.camera.zoom, float(zones[TREE]["zoom"]), 1e-6, "the zone's zoom")
	var framed := _rail_point(sim) + (zones[TREE]["offset"] as Vector2)
	assert_almost_eq(sim.camera.position.x, framed.x, 1e-3)
	assert_almost_eq(sim.camera.position.y, framed.y, 1e-3, "shifted by the zone's offset")
	game.sync_view()
	_assert_scene_mirrors(game)
	var platform_top := Vector2(4.8 * LevelData.SCREEN, -360)
	var on_screen := sim.view.world_to_screen(platform_top)
	assert_true(Rect2(Vector2.ZERO, SCREEN).has_point(on_screen), "the tree's lower platform is in view")
	var loop_point := sim.level.loop.position_at(sim.camera.distance, sim.train.open_gates)
	assert_true(Rect2(Vector2.ZERO, SCREEN).has_point(sim.view.world_to_screen(loop_point)), "and so is the loop")


func test_short_presses_stay_in_the_zone_and_a_long_hold_leaves_it() -> void:
	var probe := _boot()
	var hold := _hold_to_tree(probe)
	var steps := _to_tree_steps(hold)
	var tap_from := HOLD_FROM + hold + 4 * TICK_RATE
	for i in 4:
		steps.append({"tick": tap_from + i * TICK_RATE, "do": "tap", "at": _button(1)})
	var hold_from := tap_from + 6 * TICK_RATE
	steps.append({"tick": hold_from, "do": "touch_down", "at": _button(1)})
	steps.append({"tick": hold_from + 2 * TICK_RATE, "do": "touch_up"})
	var game := _boot(steps)
	var sim: Simulation = game.simulation
	var box: Rect2 = sim.level.framing_zones[TREE]["box"]
	game.test_mode.run_until(tap_from)
	assert_eq(sim.camera.frame_zone, TREE)
	game.test_mode.run_until(hold_from)
	assert_eq(sim.camera.frame_zone, TREE, "four short presses: still framed by the tree's zone")
	assert_true(box.has_point(_rail_point(sim)))
	assert_gt(_rail_point(sim).x, box.end.x - Camera.PACE / TICK_RATE - 1.0, "held at its edge")
	var left_at := -1
	while sim.tick < hold_from + 2 * TICK_RATE:
		game.test_mode.run_ticks(1)
		if left_at < 0 and not box.has_point(_rail_point(sim)):
			left_at = sim.tick - hold_from
	assert_between(left_at, int(Camera.EXIT_HOLD * TICK_RATE), int(Camera.EXIT_HOLD * TICK_RATE) + 3,
			"about 1 s of holding, then out")
	game.test_mode.run_ticks(6 * TICK_RATE)
	assert_eq(sim.camera.frame_zone, "")
	assert_almost_eq(sim.camera.zoom, 1.0, 1e-6, "the normal zoom again")
	game.sync_view()
	_assert_scene_mirrors(game)


func test_left_alone_for_45_s_the_camera_follows_the_first_slime() -> void:
	var game := _boot()
	var sim: Simulation = game.simulation
	var slime: int = sim.slimes.ids()[0]
	game.test_mode.run_ticks(int((Camera.IDLE_SECONDS - Camera.CUE_SECONDS) * TICK_RATE))
	assert_eq(sim.camera.mode, Camera.RAILS)
	assert_eq(sim.camera.zoom, 1.0, "35 s: no cue yet")
	game.test_mode.run_ticks(5 * TICK_RATE)
	assert_lt(sim.camera.zoom, 1.0, "the cue: zooming out slowly")
	assert_gt(sim.camera.zoom, Camera.IDLE_ZOOM)
	assert_eq(sim.camera.mode, Camera.RAILS)
	game.test_mode.run_ticks(5 * TICK_RATE)
	assert_eq(sim.camera.mode, Camera.FOLLOW, "45 s: the idle camera")
	assert_eq(sim.camera.follow_id, slime, "the only train slime")
	assert_eq(sim.camera.zoom, Camera.IDLE_ZOOM)
	game.test_mode.run_ticks(5 * TICK_RATE)
	var centre := sim.slimes.centre_of(slime)
	assert_lt(sim.camera.position.distance_to(centre + Camera.RAIL_OFFSET), LevelData.SCREEN * 0.2,
			"following it (a little behind a hopping slime)")
	game.sync_view()
	_assert_scene_mirrors(game)
	var at := sim.view.world_to_screen(centre + Vector2(120, -40))
	sim.push_input(Simulation.touch_down(0, at))
	sim.push_input(Simulation.touch_up(0, at))
	game.test_mode.run_ticks(1)
	var tap: Dictionary = sim.taps.back()
	assert_eq(tap["zone"], TapDispatcher.ZONE_GROUND)
	assert_true(tap["call"], "the tap still calls")
	assert_eq(tap["answered"], [slime])
	assert_eq(sim.camera.mode, Camera.DRAG, "the child has the camera again")
	assert_eq(sim.camera.follow_id, -1)


func test_screensaver_mode_starts_on_the_idle_camera() -> void:
	var game := _boot()
	var sim: Simulation = game.simulation
	assert_false(sim.screensaver, "test mode plays as in a session")
	sim.screensaver = true
	game.test_mode.run_ticks(1)
	assert_eq(sim.camera.mode, Camera.FOLLOW)
	assert_eq(sim.camera.zoom, Camera.IDLE_ZOOM)
	game.sync_view()
	_assert_scene_mirrors(game)


func test_a_seeded_framing_and_idle_run_is_repeatable() -> void:
	var probe := _boot()
	var hold := _hold_to_tree(probe)
	var steps := _to_tree_steps(hold)
	var after := HOLD_FROM + hold + 3 * TICK_RATE
	steps.append({"tick": after, "do": "tap", "at": _button(1)})
	steps.append({"tick": after + TICK_RATE, "do": "touch_down", "at": _button(1)})
	steps.append({"tick": after + 3 * TICK_RATE, "do": "touch_up"})
	var ticks := after + 3 * TICK_RATE + int((Camera.IDLE_SECONDS + 5.0) * TICK_RATE)
	var hashes := []
	var cameras := []
	for run in 2:
		var game := _boot(steps)
		game.test_mode.run_ticks(ticks)
		assert_eq(game.simulation.camera.mode, Camera.FOLLOW, "run %d ends on the idle camera" % run)
		hashes.append(game.simulation.state_hash())
		cameras.append(StateHash.canonical_json(game.simulation.dump()["camera"]))
	assert_eq(hashes[0], hashes[1], "same seed, same presses: same hash")
	assert_eq(cameras[0], cameras[1])
