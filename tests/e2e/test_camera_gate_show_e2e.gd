extends GutTest
## End-to-end on the test level: showing a gate open (master spec §5.6, build
## plan item 23.10) through the real game scene and test mode. From
## `s1-basket-5of6`, with the camera on basket 1 (the fixture's camera) so
## gate 1 is off screen, the basket fires and the camera ends with gate 1 in
## view within about 1.5 s, then stays there; a tap during the glide calls
## and takes the camera back; with gate 1 already in view when the basket
## fires the camera doesn't move; same seed, same hash.

# @test-link [[req_camera_shows_gate_opening]]
# @test-link [[req_switch_basket_gate_set]]

const MAIN_SCENE := "res://src/main.tscn"
const SEED := 14
const TICK_RATE := Simulation.TICK_RATE
const SCREEN := ScreenView.DEFAULT_SIZE
const BASKET := "s1.basket"
const GATE := "s1.gate"
## The basket fires within this, s (test_frontier_e2e: about 7 s).
const FIRE_WITHIN := 30
const SHOW_TICKS := int(Camera.SHOW_SECONDS * TICK_RATE)


func _boot() -> Node:
	var game: Node = load(MAIN_SCENE).instantiate()
	add_child_autofree(game)
	assert_eq(game.enable_test_mode({"seed": SEED, "time_scale": 0, "fixture": "s1-basket-5of6"}), PackedStringArray())
	return game


func _phase(game: Node) -> String:
	return game.simulation.object_states[BASKET]["phase"]


## Runs until basket 1 is in `phase`, at most FIRE_WITHIN s. Returns the
## ticks it took, or -1.
func _run_until(game: Node, phase: String) -> int:
	for i in FIRE_WITHIN * TICK_RATE:
		if _phase(game) == phase:
			return i
		game.test_mode.run_ticks(1)
	return -1


func _gate_in_view(game: Node) -> bool:
	var sim: Simulation = game.simulation
	return Fusion.view_rect(sim.view).encloses(sim.level.gates[GATE]["box"])


func test_the_basket_fires_and_the_camera_shows_gate_1_within_1_5_s() -> void:
	var game := _boot()
	var sim: Simulation = game.simulation
	assert_false(_gate_in_view(game), "the camera on basket 1: gate 1 off screen")
	assert_gt(_run_until(game, FrontierSets.FIRED), 0, "the basket fires")
	assert_true(sim.gate_states[GATE]["open"])
	assert_eq(sim.camera.mode, Camera.SHOW, "the camera glides to the gate")
	var shown := -1
	for i in 3 * TICK_RATE:
		if _gate_in_view(game):
			shown = i
			break
		game.test_mode.run_ticks(1)
	gut.p("gate 1 in view %d ticks after the basket fired" % shown)
	assert_between(shown, 1, SHOW_TICKS + 1, "gate 1 in view within about 1.5 s")
	game.test_mode.run_ticks(SHOW_TICKS)
	assert_eq(sim.camera.mode, Camera.RAILS, "then under normal control")
	var there := sim.camera.position
	game.test_mode.run_ticks(5 * TICK_RATE)
	assert_true(_gate_in_view(game), "it stays there")
	assert_lt(sim.camera.position.distance_to(there), 1.0, "no glide back")


func test_a_tap_during_the_glide_calls_and_takes_the_camera_back() -> void:
	var game := _boot()
	var sim: Simulation = game.simulation
	assert_gt(_run_until(game, FrontierSets.FIRED), 0)
	game.test_mode.run_ticks(SHOW_TICKS / 3)
	assert_eq(sim.camera.mode, Camera.SHOW)
	game.sync_view()
	var at := Vector2.ZERO
	for offset in [Vector2(-400, -150), Vector2(400, -150), Vector2(-400, 150), Vector2(400, 150)]:
		at = SCREEN * 0.5 + offset
		if TapDispatcher.dispatch(at, sim.view, Sleepers.tap_targets(sim))["zone"] == TapDispatcher.ZONE_GROUND:
			break
	sim.push_input(Simulation.touch_down(0, at))
	sim.push_input(Simulation.touch_up(0, at))
	game.test_mode.run_ticks(1)
	var tap: Dictionary = sim.taps[-1]
	assert_eq(tap["zone"], TapDispatcher.ZONE_GROUND)
	assert_true(tap["call"], "the tap calls")
	assert_eq(sim.camera.mode, Camera.DRAG, "and the camera is the child's again")
	assert_lt(sim.camera.drag_point.distance_to(tap["world"]), 0.01, "toward the tap (the log snaps it)")


func test_with_gate_1_already_in_view_the_camera_doesn_t_move() -> void:
	var game := _boot()
	var sim: Simulation = game.simulation
	assert_gt(_run_until(game, FrontierSets.REWARD), 0, "the basket seen full: its reward plays")
	# Between basket 1 and gate 1, on the rails: both in view.
	var basket: Rect2 = sim.level.baskets[BASKET]["box"]
	var gate: Rect2 = sim.level.gates[GATE]["box"]
	var between := (basket.get_center() + gate.get_center()) * 0.5
	sim.camera.start(sim.level.loop, sim.train.open_gates, Vector2(gate.position.x - SCREEN.x * 0.5 + 40.0, between.y))
	game.sync_view()
	assert_true(_gate_in_view(game), "gate 1 in view")
	var from := sim.camera.position
	var fired := _run_until(game, FrontierSets.FIRED)
	assert_gt(fired, 0, "the basket fires")
	for i in 3 * TICK_RATE:
		assert_ne(sim.camera.mode, Camera.SHOW)
		assert_lt(sim.camera.position.distance_to(from), 0.01, "the camera doesn't move")
		game.test_mode.run_ticks(1)


func test_a_run_with_a_gate_shown_is_repeatable() -> void:
	var hashes := []
	for run in 2:
		var game := _boot()
		assert_gt(_run_until(game, FrontierSets.FIRED), 0)
		game.test_mode.run_ticks(SHOW_TICKS + TICK_RATE)
		hashes.append(game.simulation.state_hash())
	assert_eq(hashes[0], hashes[1], "same seed, same hash")
