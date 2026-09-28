extends GutTest
## Tap dispatch (src/sim/tap_dispatcher.gd) and the tap rules the Simulation
## applies: the four zones in the spec's order (parent zone, edge buttons,
## objects, open ground), the generous hit areas, a ripple on every tap,
## slimes in range turning toward every tap, and "the first touch wins"
## (D66, O67's proposed default: a second finger gets nothing at all).

# @test-link [[req_controls_tap_zones]]
# @test-link [[req_call_mechanic]]

const SCREEN := Vector2(1152, 648)


## A level with a switch, a basket and a sleeper, no loop.
func _level() -> LevelData:
	var data := LevelData.new("tap", 1)
	# Level = screen at the default view (centre (576, 324), zoom 1).
	data.add_tap_target("t.switch.a", TapDispatcher.KIND_SWITCH, Rect2(520, 10, 80, 80))
	data.add_tap_target("t.basket.a", TapDispatcher.KIND_BASKET, Rect2(700, 400, 200, 100))
	data.add_tap_target("t.sleeper.01", TapDispatcher.KIND_SLEEPER, Rect2(26, 276, 48, 48))
	data.add_tap_target("t.sleeper.02", TapDispatcher.KIND_SLEEPER, Rect2(300, 300, 48, 48))
	return data


func _dispatch(at: Vector2, view := ScreenView.new()) -> Dictionary:
	return TapDispatcher.dispatch(at, view, _level().tap_targets)


func _sim() -> Simulation:
	var sim := Simulation.new(5)
	sim.load_level(_level())
	return sim


func _tap(sim: Simulation, at: Vector2, finger := 0) -> void:
	sim.push_input(Simulation.touch_down(finger, at))
	sim.push_input(Simulation.touch_up(finger, at))
	sim.step()


# --- Zones, in order ---------------------------------------------------------

func test_the_top_band_wins_over_an_object() -> void:
	var hit := _dispatch(Vector2(560, 30))  # on the switch, inside the top band
	assert_eq(hit["zone"], TapDispatcher.ZONE_PARENT)
	assert_false(hit["call"], "the parent zone never calls")
	assert_eq(hit["object"], "")


func test_an_edge_button_wins_over_an_object() -> void:
	var hit := _dispatch(Vector2(50, 300))  # on sleeper 01, inside the left button
	assert_eq(hit["zone"], TapDispatcher.ZONE_EDGE)
	assert_eq(hit["side"], -1)
	assert_false(hit["call"], "an edge button never calls")
	var right := _dispatch(Vector2(SCREEN.x - 10, SCREEN.y * 0.5))
	assert_eq(right["zone"], TapDispatcher.ZONE_EDGE)
	assert_eq(right["side"], 1)


func test_the_edge_buttons_are_only_mid_height() -> void:
	var hit := _dispatch(Vector2(40, SCREEN.y - 20))
	assert_eq(hit["zone"], TapDispatcher.ZONE_GROUND, "below the left button is open ground")


func test_an_object_is_not_a_call() -> void:
	var hit := _dispatch(Vector2(800, 450))
	assert_eq(hit["zone"], TapDispatcher.ZONE_OBJECT)
	assert_eq(hit["object"], "t.basket.a")
	assert_eq(hit["kind"], TapDispatcher.KIND_BASKET)
	assert_false(hit["call"])


func test_a_sleeper_is_a_call_centred_on_it() -> void:
	var hit := _dispatch(Vector2(340, 330))
	assert_eq(hit["zone"], TapDispatcher.ZONE_OBJECT)
	assert_eq(hit["object"], "t.sleeper.02")
	assert_true(hit["call"])
	assert_eq(hit["call_point"], Vector2(324, 324), "the sleeper's centre, not the tap")


func test_open_ground_is_a_call_at_the_tap() -> void:
	var view := ScreenView.new(Vector2(5000, -300), 0.5)
	var hit := _dispatch(Vector2(600, 500), view)
	assert_eq(hit["zone"], TapDispatcher.ZONE_GROUND)
	assert_true(hit["call"])
	assert_eq(hit["call_point"], view.screen_to_world(Vector2(600, 500)))
	assert_eq(hit["world"], hit["call_point"])


# --- Hit areas ---------------------------------------------------------------

func test_hit_areas_are_larger_than_the_object() -> void:
	# The basket's box ends at x = 900; the margin is 24 screen pixels.
	assert_eq(_dispatch(Vector2(920, 450))["object"], "t.basket.a", "inside the margin")
	assert_eq(_dispatch(Vector2(930, 450))["zone"], TapDispatcher.ZONE_GROUND, "beyond it")


func test_the_margin_is_in_screen_pixels() -> void:
	# At zoom 0.5 the 24 screen px are 48 level px.
	var view := ScreenView.new(Vector2(576, 324), 0.5)
	var just_in := view.world_to_screen(Vector2(940, 450))
	var out := view.world_to_screen(Vector2(955, 450))
	assert_eq(_dispatch(just_in, view)["object"], "t.basket.a")
	assert_eq(_dispatch(out, view)["zone"], TapDispatcher.ZONE_GROUND)


func test_the_nearest_object_wins_where_hit_areas_overlap() -> void:
	var targets := {
		"t.sleeper.01": {"kind": TapDispatcher.KIND_SLEEPER, "box": Rect2(400, 300, 48, 48)},
		"t.sleeper.02": {"kind": TapDispatcher.KIND_SLEEPER, "box": Rect2(460, 300, 48, 48)},
	}
	assert_eq(TapDispatcher.object_at(Vector2(450, 324), 1.0, targets), "t.sleeper.01")
	assert_eq(TapDispatcher.object_at(Vector2(456, 324), 1.0, targets), "t.sleeper.02")


# --- In the simulation --------------------------------------------------------

func test_every_tap_leaves_a_ripple() -> void:
	var sim := _sim()
	var spots := [Vector2(560, 30), Vector2(50, 300), Vector2(800, 450), Vector2(600, 600)]
	for at in spots:
		_tap(sim, at)
	assert_eq(sim.ripples.size(), 4, "one ripple per tap, in all four zones")
	var zones := []
	for k in spots.size():
		assert_eq(sim.ripples[k]["at"], spots[k], "where the finger touched (level = screen here)")
		zones.append(sim.taps[k]["zone"])
	assert_eq(zones, [TapDispatcher.ZONE_PARENT, TapDispatcher.ZONE_EDGE,
			TapDispatcher.ZONE_OBJECT, TapDispatcher.ZONE_GROUND])
	assert_eq(sim.taps.map(func(t): return t["call"]), [false, false, false, true])


func test_a_ripple_fades_away() -> void:
	var sim := _sim()
	_tap(sim, Vector2(600, 600))
	sim.run(Simulation.RIPPLE_TICKS - 2)
	assert_eq(sim.ripples.size(), 1)
	sim.run(2)
	assert_eq(sim.ripples.size(), 0, "gone after RIPPLE_TICKS")


func test_the_tap_is_dispatched_when_the_finger_touches_down() -> void:
	var sim := _sim()
	sim.push_input(Simulation.touch_down(0, Vector2(600, 600)))
	sim.step()
	assert_eq(sim.taps.size(), 1)
	assert_eq(sim.ripples.size(), 1)


func test_the_first_touch_wins() -> void:
	var sim := _sim()
	sim.push_input(Simulation.touch_down(0, Vector2(600, 600)))
	sim.step()
	sim.push_input(Simulation.touch_down(1, Vector2(700, 300)))
	sim.step()
	assert_eq(sim.fingers_down.size(), 2, "every finger is still recorded")
	assert_eq(sim.taps.size(), 1, "the second finger is not a tap")
	assert_eq(sim.ripples.size(), 1, "not even a ripple")
	assert_eq(sim.active_finger, 0)


func test_a_second_finger_stays_ignored_until_it_lifts() -> void:
	var sim := _sim()
	sim.push_input(Simulation.touch_down(0, Vector2(600, 600)))
	sim.push_input(Simulation.touch_down(1, Vector2(700, 300)))
	sim.step()
	assert_eq(sim.taps.size(), 1, "two fingers on one tick: the first counts")
	sim.push_input(Simulation.touch_up(0, null))
	sim.step()
	assert_eq(sim.active_finger, -1)
	sim.push_input(Simulation.touch_down(2, Vector2(400, 500)))
	sim.step()
	assert_eq(sim.taps.size(), 1, "finger 1 is still down: a new touch is ignored too")
	sim.push_input(Simulation.touch_up(1, null))
	sim.push_input(Simulation.touch_up(2, null))
	sim.step()
	sim.push_input(Simulation.touch_down(3, Vector2(400, 500)))
	sim.step()
	assert_eq(sim.taps.size(), 2, "once every finger is up, the next new touch counts")
	assert_eq(sim.taps[1]["finger"], 3)
	assert_eq(sim.active_finger, 3)


func test_slimes_in_range_turn_toward_every_tap() -> void:
	var sim := _sim()
	var near := sim.slimes.create(0, 1, Vector2(300, 400), SlimeBodies.TRAIN)
	var far := sim.slimes.create(0, 1, Vector2(1100, 600), SlimeBodies.TRAIN)
	var asleep := sim.slimes.create(0, 1, Vector2(100, 150), SlimeBodies.SLEEPER)
	_tap(sim, Vector2(100, 40))  # the parent zone: no call
	assert_true(sim.facing.has(near))
	assert_almost_eq(sim.facing[near].x, (Vector2(100, 40) - Vector2(300, 400)).normalized().x, 0.001)
	assert_false(sim.facing.has(far), "out of range (half the screen width, 576 px)")
	assert_false(sim.facing.has(asleep), "a sleeper doesn't turn")
	assert_eq(sim.slimes.state_of(near), SlimeBodies.TRAIN, "a parent-zone tap doesn't call")


func test_taps_are_in_the_state() -> void:
	var a := _sim()
	var b := _sim()
	_tap(a, Vector2(600, 600))
	b.step()
	assert_ne(a.state_hash(), b.state_hash(), "the ripple, the tap and the call are state")
	assert_eq(a.dump()["ripples"].size(), 1)
	assert_eq(a.dump()["taps"].size(), 1)
	assert_eq(a.dump()["free_slimes"]["call"]["tick"], 0)
