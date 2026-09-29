extends GutTest
## End-to-end on the test level (chunk 23E), through the real game scene and
## test mode, on the reference phone's density (test mode's).
## Item 23.6 (D109): an object's hit area is its drawing plus 5 mm, at least
## 20 x 20 mm, on the screen at the current zoom: at zoom 1 a tap 4 mm
## outside switch 1's drawing flips it and one 6 mm outside calls; in
## `s3.frame.basket` (zoom 0.8) a tap near the edge of the 20 mm floor
## centred on switch 3 flips it.
## Item 23.7 (D109): only what answers a tap takes it. From `gate1-open`
## (basket 1 fired, switch 1 inert) in screensaver mode, a tap on basket 1,
## gate 1, signpost 1 or switch 1 calls the slimes in range and starts a
## session; a tap on a filling basket's switch still flips it.

# @test-link [[req_interactive_objects_general]]
# @test-link [[req_controls_tap_zones]]
# @test-link [[rule_frontier_set_inert_after_gate_open]]
# @test-link [[req_session_lifecycle]]

const MAIN_SCENE := "res://src/main.tscn"
const SEED := 23
const SWITCH_1 := "s1.switch"
const SWITCH_3 := "s3.switch"
const FRAME_3 := "s3.frame.basket"


func _boot(config := {}) -> Node:
	var game: Node = load(MAIN_SCENE).instantiate()
	add_child_autofree(game)
	var run := {"seed": SEED, "time_scale": 0}
	run.merge(config, true)
	assert_eq(game.enable_test_mode(run), PackedStringArray())
	return game


## Taps level point `world` (a touch down and up) with the view as it is
## now, dispatched on the next tick, which this runs. Returns the tap's
## record.
func _tap_world(game: Node, world: Vector2) -> Dictionary:
	var sim: Simulation = game.simulation
	game.sync_view()
	var at := sim.view.world_to_screen(world)
	sim.push_input(Simulation.touch_down(0, at))
	sim.push_input(Simulation.touch_up(0, at))
	game.test_mode.run_ticks(1)
	return sim.taps[-1]


## Puts the camera on `centre` at `zoom` and the view with it.
func _aim(game: Node, centre: Vector2, zoom := 1.0) -> void:
	game.simulation.camera.place(centre, zoom)
	game.sync_view()


## `mm` millimetres on the game's screen, in level px at the view's zoom.
func _mm(game: Node, mm: float) -> float:
	var view: ScreenView = game.simulation.view
	return view.mm_to_px(mm) / view.zoom


func _box(game: Node, id: String) -> Rect2:
	return game.simulation.level.tap_targets[id]["box"]


func _flipped(game: Node, id: String) -> bool:
	return game.simulation.object_states[id]["flipped"]


## The awake slimes (train or free) a call at `world` reaches now, sorted.
func _in_range(game: Node, world: Vector2) -> Array:
	var sim: Simulation = game.simulation
	game.sync_view()
	var out := []
	for slime_id in sim.slimes.ids():
		var state := sim.slimes.state_of(slime_id)
		if state != SlimeBodies.TRAIN and state != SlimeBodies.FREE:
			continue
		if sim.slimes.centre_of(slime_id).distance_to(world) <= sim.call_radius():
			out.append(slime_id)
	out.sort()
	return out


# --- 23.6: hit areas held on the screen ---------------------------------------------

func test_at_zoom_1_a_tap_4_mm_outside_switch_1_flips_it_and_6_mm_calls() -> void:
	var game := _boot()
	var box := _box(game, SWITCH_1)
	_aim(game, box.get_center())
	assert_eq(game.simulation.view.px_per_mm, ScreenView.REFERENCE_PX_PER_MM, "the reference phone")
	var left_mid := Vector2(box.position.x, box.get_center().y)
	var far := _tap_world(game, left_mid - Vector2(_mm(game, 6.0), 0))
	assert_true(far["call"], "6 mm outside: a call")
	assert_ne(far["object"], SWITCH_1)
	assert_false(_flipped(game, SWITCH_1))
	var near := _tap_world(game, left_mid - Vector2(_mm(game, 4.0), 0))
	assert_eq(near["object"], SWITCH_1, "4 mm outside: on the switch")
	assert_false(near["call"])
	assert_true(_flipped(game, SWITCH_1), "it flips")


func test_in_s3_frame_basket_a_tap_near_the_edge_of_the_20_mm_floor_flips_switch_3() -> void:
	var game := _boot({"fixture": "gate2-open"})
	var sim: Simulation = game.simulation
	var zone: Rect2 = sim.level.framing_zones[FRAME_3]["box"]
	sim.camera.start(sim.level.loop, sim.train.open_gates, zone.get_center())
	game.sync_view()
	assert_eq(sim.camera.frame_zone, FRAME_3)
	assert_eq(sim.view.zoom, 0.8, "the zone's zoom")
	var centre := _box(game, SWITCH_3).get_center()
	var half := _mm(game, 10.0)
	assert_gt(half, _box(game, SWITCH_3).size.x * 0.5 + _mm(game, 5.0), "the floor is what holds here")
	var edge := centre - Vector2(half - _mm(game, 0.5), 0)
	var tap := _tap_world(game, edge)
	assert_eq(tap["object"], SWITCH_3, "0.5 mm inside the floor's left edge")
	assert_true(_flipped(game, SWITCH_3), "it flips")
	var past := _tap_world(game, centre - Vector2(half + _mm(game, 0.5), 0))
	assert_true(past["call"], "0.5 mm past it: a call")
	assert_true(_flipped(game, SWITCH_3), "left as it was")


# --- 23.7: only what answers a tap takes it -------------------------------------------

func test_in_screensaver_mode_taps_on_what_doesn_t_answer_call_and_start_a_session() -> void:
	var probe := _boot({"fixture": "gate1-open"})
	var level: LevelData = probe.simulation.level
	assert_eq(probe.simulation.object_states["s1.basket"]["phase"], FrontierSets.FIRED, "basket 1 has fired")
	var signpost := ""
	for id in level.signposts:
		if level.signposts[id]["switch"] == SWITCH_1:
			signpost = id
	var spots := {
		"basket 1": level.baskets["s1.basket"]["box"].get_center(),
		"gate 1": level.gates["s1.gate"]["box"].get_center(),
		"signpost 1": level.signposts[signpost]["position"],
		"switch 1, its gate open": level.switches[SWITCH_1]["box"].get_center(),
	}
	var answered := 0
	for what in spots:
		var game := _boot({"fixture": "gate1-open", "sessions": true})
		var sim: Simulation = game.simulation
		assert_eq(sim.session.phase, Session.SCREENSAVER, "%s: screensaver mode first" % what)
		_aim(game, spots[what])
		var expected := _in_range(game, spots[what])
		var flipped := _flipped(game, SWITCH_1)
		var tap := _tap_world(game, spots[what])
		assert_eq(tap["zone"], TapDispatcher.ZONE_GROUND, "%s: open ground" % what)
		assert_true(tap["call"], "%s: a call" % what)
		var got: Array = tap["answered"].duplicate()
		got.sort()
		assert_eq(got, expected, "%s: the slimes in range answer" % what)
		answered += got.size()
		assert_eq(sim.session.phase, Session.SESSION, "%s: a session starts" % what)
		assert_eq(_flipped(game, SWITCH_1), flipped, "%s: switch 1 left as it was" % what)
	assert_gt(answered, 0, "some slime was in range")


func test_a_tap_on_a_filling_basket_s_switch_still_flips_it() -> void:
	var game := _boot({"fixture": "gate1-open", "sessions": true})
	var sim: Simulation = game.simulation
	assert_eq(sim.object_states["s2.basket"]["phase"], FrontierSets.FILLING)
	var centre := _box(game, "s2.switch").get_center()
	_aim(game, centre)
	var tap := _tap_world(game, centre)
	assert_eq(tap["object"], "s2.switch")
	assert_false(tap["call"])
	assert_true(_flipped(game, "s2.switch"), "it flips")
	assert_eq(sim.session.phase, Session.SESSION, "a tap that reaches the world starts a session")
