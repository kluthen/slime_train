extends GutTest
## Objects and taps (chunk 23E), through the Simulation on a synthetic
## level. Item 23.6 (D109): an interactive object's hit area is its drawing
## plus 5 mm on every side, never under 20 x 20 mm, measured on the screen
## at the current zoom. Item 23.7 (D109): only what answers a tap takes it:
## a tap on a basket, a gate, a signpost, or a switch whose basket is full or
## whose gate is open, is a call (and starts a session in screensaver
## mode); only a switch whose basket is filling takes a tap.
##
## The world: a floor whose top is at y = 0; the loop runs along it at a
## base slime's centre height (y = -24) from x = -1500 to 0 (section 1,
## returning under the floor while gate t.gate is closed) and on to x = 1500
## (section 2). Switch t.switch (80 x 80 px, like the test level's, centred
## on (-1100, -160)) sends the flow into basket t.basket (100 x 60 px,
## centred on (-990, -300), up and to the right of it, so their hit areas
## overlap). Gate t.gate and signpost t.signpost stand in the air, off the
## loop. The first slime starts at x = -1000, in call range of every object.
## The view: centred on (-900, -150), zoom 1, the reference phone's density.

# @test-link [[req_interactive_objects_general]]
# @test-link [[req_controls_tap_zones]]
# @test-link [[req_switch_basket_gate_set]]
# @test-link [[rule_frontier_set_inert_after_gate_open]]
# @test-link [[req_session_lifecycle]]

const Support := preload("res://tests/unit/slime_test_support.gd")
const SCREEN := ScreenView.DEFAULT_SIZE
const SWITCH := "t.switch"
const SWITCH_BOX := Rect2(-1140, -200, 80, 80)
const BASKET := "t.basket"
const BASKET_BOX := Rect2(-1040, -330, 100, 60)
const GATE := "t.gate"
const GATE_BOX := Rect2(-600, -300, 20, 200)
const SIGNPOST := "t.signpost"
const SIGNPOST_AT := Vector2(-1300, -40)
const FIRST_SPOT := Vector2(-1000, -24)
const VIEW_CENTRE := Vector2(-900, -150)
const WALL := 1_700_000_000_000


func _level() -> LevelData:
	var data := LevelData.new("object-taps", 1)
	var loop := LoopData.new("t.loop")
	loop.add_segment("t.s1.out", 1, LoopData.OUTGOING, PackedVector2Array([Vector2(-1500, -24), Vector2(0, -24)]))
	loop.add_segment("t.s1.back", 1, LoopData.RETURN, PackedVector2Array([
			Vector2(0, -24), Vector2(0, 400), Vector2(-1500, 400), Vector2(-1500, -24)]), GATE)
	loop.add_segment("t.s2.out", 2, LoopData.OUTGOING, PackedVector2Array([Vector2(0, -24), Vector2(1500, -24)]))
	loop.add_segment("t.s2.back", 2, LoopData.RETURN, PackedVector2Array([
			Vector2(1500, -24), Vector2(1500, 400), Vector2(-1500, 400), Vector2(-1500, -24)]))
	data.loop = loop
	data.first_slime = {"id": "t.first-slime", "species": "A", "position": FIRST_SPOT}
	data.add_switch(SWITCH, SWITCH_BOX, BASKET, Rect2(-1100, -10, 100, 10))
	data.add_basket(BASKET, BASKET_BOX, 3, FrontierSets.onward_outlet(loop, GATE, 200.0, Vector2.ZERO))
	data.add_gate(GATE, GATE_BOX)
	data.add_signpost(SIGNPOST, SIGNPOST_AT, SWITCH)
	data.add_tap_target(SWITCH, TapDispatcher.KIND_SWITCH, SWITCH_BOX)
	data.add_tap_target(BASKET, TapDispatcher.KIND_BASKET, BASKET_BOX)
	data.rules.append({"when": {"object": BASKET, "event": "full"}, "then": {"object": GATE, "action": "open"}})
	return data


## The synthetic level, untimed unless `sessions`, the view as the class doc
## says.
func _sim(sessions := false) -> Simulation:
	var sim := Simulation.new(7)
	sim.slimes.terrain = TerrainSegments.new([Support.floor_polygon()])
	sim.load_level(_level())
	sim.view.set_to(VIEW_CENTRE, 1.0, SCREEN)
	sim.session.read_clock(Session.reading(WALL, 0, "a"))
	if sessions:
		sim.session.open(sim)
		sim.step()
	return sim


## A tap (down and up on the same tick) on level point `world`, then a step.
## Returns the tap's record.
func _tap_world(sim: Simulation, world: Vector2) -> Dictionary:
	var at := sim.view.world_to_screen(world)
	sim.push_input(Simulation.touch_down(0, at))
	sim.push_input(Simulation.touch_up(0, at))
	sim.step()
	return sim.taps[-1]


func _flipped(sim: Simulation) -> bool:
	return sim.object_states[SWITCH]["flipped"]


## `mm` millimetres on `sim`'s screen, in level px at its zoom.
func _mm(sim: Simulation, mm: float) -> float:
	return sim.view.mm_to_px(mm) / sim.view.zoom


func _assert_call(tap: Dictionary, sim: Simulation, what: String) -> void:
	assert_eq(tap["zone"], TapDispatcher.ZONE_GROUND, "%s: open ground" % what)
	assert_true(tap["call"], "%s: a call" % what)
	assert_eq(tap["answered"], [sim.slimes.ids()[0]], "%s: the slime in range answers" % what)
	assert_false(_flipped(sim), "%s: the switch doesn't flip" % what)


# --- 23.6: hit areas held on the screen ------------------------------------------

func test_at_zoom_1_a_tap_4_mm_outside_the_switch_flips_it_and_6_mm_calls() -> void:
	# 80 px is about 8.4 mm: plus 5 mm a side is under the 20 mm floor, so the
	# floor holds, reaching about 5.8 mm past the drawing.
	var sim := _sim()
	var left_mid := Vector2(SWITCH_BOX.position.x, SWITCH_BOX.get_center().y)
	_assert_call(_tap_world(sim, left_mid - Vector2(_mm(sim, 6.0), 0)), sim, "6 mm left")
	var tap := _tap_world(sim, left_mid - Vector2(_mm(sim, 4.0), 0))
	assert_eq(tap["object"], SWITCH, "4 mm left: on the switch")
	assert_false(tap["call"])
	assert_true(_flipped(sim), "it flips")
	var below := Vector2(SWITCH_BOX.get_center().x, SWITCH_BOX.end.y)
	_tap_world(sim, below + Vector2(0, _mm(sim, 4.0)))
	assert_false(_flipped(sim), "4 mm below flips it back")
	assert_true(_tap_world(sim, below + Vector2(0, _mm(sim, 6.0)))["call"], "6 mm below calls")


func test_the_20_mm_floor_is_held_on_the_screen_when_zoomed_out() -> void:
	# At zoom 0.8 the drawing is 6.7 mm on the screen; the floor, 20 mm
	# centred on it, is 239 level px across (191 at zoom 1).
	var sim := _sim()
	sim.view.set_to(SWITCH_BOX.get_center(), 0.8, SCREEN)
	var half := _mm(sim, 10.0)
	assert_almost_eq(half * 2.0, sim.view.mm_to_px(20.0) / 0.8, 1e-3)
	var tap := _tap_world(sim, SWITCH_BOX.get_center() + Vector2(half - 1.0, 0))
	assert_eq(tap["object"], SWITCH, "just inside the floor's edge")
	assert_true(_flipped(sim))
	_tap_world(sim, SWITCH_BOX.get_center() - Vector2(0, half - 1.0))
	assert_false(_flipped(sim), "just inside its top edge: flipped back")
	assert_true(_tap_world(sim, SWITCH_BOX.get_center() + Vector2(half + 1.0, 0))["call"], "just past it: a call")
	assert_false(_flipped(sim))


func test_the_hit_area_follows_the_screens_density() -> void:
	# Twice the reference density: the 80 px drawing is 4.2 mm, so the floor
	# reaches 7.9 mm past it. The px that were 6 mm (a call) are now 3 mm.
	var sim := _sim()
	var left_mid := Vector2(SWITCH_BOX.position.x, SWITCH_BOX.get_center().y)
	var six_mm_before := _mm(sim, 6.0)
	sim.view.px_per_mm = ScreenView.REFERENCE_PX_PER_MM * 2.0
	assert_true(_tap_world(sim, left_mid - Vector2(_mm(sim, 8.5), 0))["call"], "8.5 mm left calls")
	_tap_world(sim, left_mid - Vector2(six_mm_before, 0))
	assert_true(_flipped(sim), "3 mm left (the old 6 mm) flips")


# --- 23.7: only what answers a tap takes it ---------------------------------------

func test_a_tap_on_a_filling_basket_s_switch_flips_it() -> void:
	var sim := _sim()
	var tap := _tap_world(sim, SWITCH_BOX.get_center())
	assert_eq(tap["zone"], TapDispatcher.ZONE_OBJECT)
	assert_eq(tap["kind"], TapDispatcher.KIND_SWITCH)
	assert_false(tap["call"], "operating the switch isn't a call")
	assert_true(_flipped(sim))


func test_a_tap_on_a_basket_is_a_call() -> void:
	var sim := _sim()
	var tap := _tap_world(sim, BASKET_BOX.get_center())
	_assert_call(tap, sim, "on the basket")
	assert_eq(tap["world"], BASKET_BOX.get_center(), "centred on the tap")


func test_a_tap_on_a_gate_or_a_signpost_is_a_call() -> void:
	var sim := _sim()
	_assert_call(_tap_world(sim, GATE_BOX.get_center()), sim, "on the gate")
	_assert_call(_tap_world(sim, SIGNPOST_AT), sim, "on the signpost")


func test_a_tap_on_a_switch_whose_basket_is_full_is_a_call() -> void:
	var sim := _sim()
	sim.object_states[BASKET]["phase"] = FrontierSets.FULL
	_assert_call(_tap_world(sim, SWITCH_BOX.get_center()), sim, "basket full")
	sim.object_states[BASKET]["phase"] = FrontierSets.REWARD
	_assert_call(_tap_world(sim, SWITCH_BOX.get_center()), sim, "reward playing")


func test_a_tap_on_a_switch_whose_gate_is_open_is_a_call() -> void:
	var sim := _sim()
	sim.object_states[BASKET]["phase"] = FrontierSets.FIRED
	sim.gate_states[GATE]["open"] = true
	_assert_call(_tap_world(sim, SWITCH_BOX.get_center()), sim, "gate open")


func test_where_hit_areas_overlap_the_answering_switch_takes_the_tap() -> void:
	# (-1010, -250) is in both hit areas and nearer the basket's centre; the
	# basket doesn't answer taps, so the switch takes it.
	var sim := _sim()
	var at := Vector2(-1010, -250)
	var view := sim.view
	assert_true(TapDispatcher.hit_area(TapDispatcher.KIND_BASKET, BASKET_BOX, view).has_point(at))
	assert_true(TapDispatcher.hit_area(TapDispatcher.KIND_SWITCH, SWITCH_BOX, view).has_point(at))
	assert_lt(at.distance_to(BASKET_BOX.get_center()), at.distance_to(SWITCH_BOX.get_center()))
	var tap := _tap_world(sim, at)
	assert_eq(tap["object"], SWITCH)
	assert_true(_flipped(sim))
	# Once the basket is full, neither answers: the same tap calls.
	sim.object_states[BASKET]["phase"] = FrontierSets.FULL
	assert_true(_tap_world(sim, at)["call"])
	assert_true(_flipped(sim), "left as it was")


func test_in_screensaver_mode_a_tap_on_what_doesn_t_answer_starts_a_session() -> void:
	var spots := {"basket": BASKET_BOX.get_center(), "gate": GATE_BOX.get_center(), "signpost": SIGNPOST_AT,
			"full basket's switch": SWITCH_BOX.get_center()}
	for what in spots:
		var sim := _sim(true)
		assert_eq(sim.session.phase, Session.SCREENSAVER)
		if what == "full basket's switch":
			sim.object_states[BASKET]["phase"] = FrontierSets.FULL
		var tap := _tap_world(sim, spots[what])
		assert_true(tap["call"], "%s: a call" % what)
		assert_eq(sim.session.phase, Session.SESSION, "%s: a session starts" % what)
		assert_false(sim.screensaver)


func test_answering_leaves_out_what_doesn_t_answer() -> void:
	var sim := _sim()
	var targets: Dictionary = sim.level.tap_targets.duplicate()
	targets["t.sleeper.01"] = {"kind": TapDispatcher.KIND_SLEEPER, "box": Rect2(0, -48, 48, 48)}
	assert_eq(sim.frontier.answering(sim, targets).keys(), [SWITCH, "t.sleeper.01"],
			"a filling basket's switch and a sleeper; never a basket")
	sim.object_states[BASKET]["phase"] = FrontierSets.FULL
	assert_eq(sim.frontier.answering(sim, targets).keys(), ["t.sleeper.01"])
