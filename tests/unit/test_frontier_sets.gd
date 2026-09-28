extends GutTest
## FrontierSets (src/sim/frontier_sets.gd) on a synthetic level: slimes in a
## basket's box rest in it, and it weighs them; with its switch flipped it
## fills, then waits to be in view, plays its reward, fires (its gate opens,
## the loop grows, the train's slimes keep their place), lets its slimes go
## one at a time at its outlet, and is inert for good; flipped back before it
## is full it lets its slimes go (opting out); the doors follow the states;
## the celebration plays once, when the last basket fires, and a save keeps
## all of it; same seed, same hash.
##
## The world: a floor whose top is at y = 0 from x = -2000 to 2000. Section 1
## runs along it at a base slime's centre height (y = -24) from x = -1500 to
## 0 and returns under the floor while gate t.gate is closed; section 2 runs
## on to x = 1500 and returns the same way. Basket t.basket (quota 3) is the
## box x -900 to -600, y -200 to 0, on the floor; switch t.switch sends the
## flow into it, over a trapdoor.

# @test-link [[req_switch_basket_gate_set]]
# @test-link [[req_interactive_objects_general]]
# @test-link [[rule_gate_opens_via_switch_basket_set]]
# @test-link [[rule_frontier_set_inert_after_gate_open]]
# @test-link [[req_level_completion_celebration]]

const Support := preload("res://tests/unit/slime_test_support.gd")
const SWITCH := "t.switch"
const BASKET := "t.basket"
const GATE := "t.gate"
const BASKET_BOX := Rect2(-900, -200, 300, 200)
const TRAPDOOR := Rect2(-1100, -10, 100, 10)
const GATE_BOX := Rect2(300, -200, 20, 200)
const LID := Rect2(-30, -5, 60, 10)
const OUTLET_BEFORE := 200.0
const QUOTA := 3
const AWAY := Vector2(1200, -300)
const REWARD_TICKS := int(FrontierSets.REWARD_SECONDS * Simulation.TICK_RATE)
const RELEASE_TICKS := int(FrontierSets.RELEASE_SECONDS * Simulation.TICK_RATE)


func _loop() -> LoopData:
	var loop := LoopData.new("t.loop")
	loop.add_segment("t.s1.out", 1, LoopData.OUTGOING, PackedVector2Array([Vector2(-1500, -24), Vector2(0, -24)]))
	loop.add_segment("t.s1.back", 1, LoopData.RETURN, PackedVector2Array([
			Vector2(0, -24), Vector2(0, 400), Vector2(-1500, 400), Vector2(-1500, -24)]), GATE)
	loop.add_segment("t.s2.out", 2, LoopData.OUTGOING, PackedVector2Array([Vector2(0, -24), Vector2(1500, -24)]))
	loop.add_segment("t.s2.back", 2, LoopData.RETURN, PackedVector2Array([
			Vector2(1500, -24), Vector2(1500, 400), Vector2(-1500, 400), Vector2(-1500, -24)]))
	return loop


func _level(second_basket := false) -> LevelData:
	var data := LevelData.new("frontier", 1)
	data.loop = _loop()
	data.first_slime = {"id": "t.first-slime", "species": "A", "position": Vector2(-1400, -24)}
	data.add_switch(SWITCH, Rect2(-1150, -100, 50, 50), BASKET, TRAPDOOR)
	data.add_basket(BASKET, BASKET_BOX, QUOTA, FrontierSets.onward_outlet(data.loop, GATE, OUTLET_BEFORE, Vector2.ZERO))
	data.add_gate(GATE, GATE_BOX, LID)
	data.add_signpost("t.signpost", Vector2(-1200, 0), SWITCH)
	data.add_tap_target(SWITCH, TapDispatcher.KIND_SWITCH, Rect2(-1150, -100, 50, 50))
	data.rules.append({"when": {"object": BASKET, "event": "full"}, "then": {"object": GATE, "action": "open"}})
	if second_basket:
		data.add_basket("t.basket.2", Rect2(600, -200, 300, 200), 1, Vector2(500, -24))
	return data


func _sim(master_seed := 3, second_basket := false) -> Simulation:
	var sim := Simulation.new(master_seed)
	sim.slimes.terrain = TerrainSegments.new([Support.floor_polygon()])
	sim.load_level(_level(second_basket))
	_look(sim, BASKET_BOX.get_center())
	return sim


func _look(sim: Simulation, at: Vector2) -> void:
	sim.view.set_to(at, 1.0, ScreenView.DEFAULT_SIZE)


## A slime of `size` resting on the floor at `x`, in `state`.
func _slime(sim: Simulation, size: int, x: float, state := SlimeBodies.TRAIN) -> int:
	var at := Vector2(x, -SlimeBodies.ring_radius_for(size) - SlimeBodies.EDGE)
	return sim.slimes.create(Species.from_letter("B"), size, at, state)


func _basket(sim: Simulation) -> Dictionary:
	return sim.object_states[BASKET]


func _in_basket(sim: Simulation) -> int:
	var n := 0
	for slime_id in sim.slimes.ids():
		if sim.slimes.state_of(slime_id) == SlimeBodies.IN_BASKET:
			n += 1
	return n


## Steps the frontier sets alone `n` times, a tick each.
func _frontier_steps(sim: Simulation, n: int) -> void:
	for i in n:
		sim.frontier.step(sim)
		sim.tick += 1


# --- The outlet ---------------------------------------------------------------------

func test_the_onward_outlet_is_on_the_route_into_the_gates_return_route() -> void:
	var loop := _loop()
	assert_eq(FrontierSets.onward_outlet(loop, GATE, OUTLET_BEFORE, Vector2.ZERO), Vector2(-200, -24))
	assert_eq(FrontierSets.onward_outlet(loop, GATE, 5000.0, Vector2.ZERO), Vector2(-1500, -24),
			"no further back than the route's start")
	assert_eq(FrontierSets.onward_outlet(loop, "t.nothing", OUTLET_BEFORE, Vector2(700, -300)), Vector2(700, -24),
			"no such gate: the outgoing route's point nearest")
	assert_eq(FrontierSets.onward_outlet(null, GATE, OUTLET_BEFORE, Vector2(5, 6)), Vector2(5, 6))


# --- Loading --------------------------------------------------------------------------

func test_a_fresh_level_gets_every_object_state_and_its_doors() -> void:
	var sim := _sim()
	assert_eq(sim.object_states[SWITCH], {"flipped": false, "trapdoor_shut": true})
	assert_eq(_basket(sim), {"phase": FrontierSets.FILLING, "weight": 0, "since": -1, "next_release": 0})
	assert_eq(sim.gate_states[GATE], {"open": false, "entrance_closed": false})
	assert_eq(sim.slimes.doors.size(), 2, "the shut trapdoor and the closed gate")
	assert_false(sim.frontier.celebration_done)


func test_saved_states_get_their_types_and_unknown_objects_are_left_alone() -> void:
	var sim := _sim()
	sim.object_states = {BASKET: {"phase": "reward", "weight": 2.0, "since": 7.0, "next_release": 0.0},
			SWITCH: {"flipped": true, "trapdoor_shut": false}, "t.unknown": {"x": 1.0}}
	sim.gate_states = {GATE: {"open": false, "entrance_closed": false}}
	sim.frontier.start(sim)
	assert_eq(StateHash.of(_basket(sim)), StateHash.of({"phase": "reward", "weight": 2, "since": 7, "next_release": 0}))
	assert_eq(sim.object_states["t.unknown"], {"x": 1.0})
	sim.object_states[BASKET]["phase"] = "nonsense"
	sim.frontier.start(sim)
	assert_eq(_basket(sim)["phase"], FrontierSets.FILLING)


func test_a_gate_saved_open_opens_the_train_loop_too() -> void:
	var sim := _sim()
	sim.gate_states = {GATE: {"open": true, "entrance_closed": true}}
	sim.frontier.start(sim)
	assert_true(GATE in sim.train.open_gates)
	assert_eq(sim.slimes.doors.size(), 2, "the trapdoor and the lid; no barrier")


# --- Filling --------------------------------------------------------------------------

func test_slimes_in_the_box_rest_in_it_and_fill_it_by_weight() -> void:
	var sim := _sim()
	sim.frontier.tap_switch(sim, SWITCH)
	var two := _slime(sim, 2, -800)
	var outside := _slime(sim, 1, -400)
	_look(sim, AWAY)
	_frontier_steps(sim, 1)
	assert_eq(sim.slimes.state_of(two), SlimeBodies.IN_BASKET)
	assert_eq(sim.slimes.state_of(outside), SlimeBodies.TRAIN)
	assert_eq(_basket(sim)["weight"], 2, "a size-2 slime fills 2")
	assert_eq(_basket(sim)["phase"], FrontierSets.FILLING)
	var free := _slime(sim, 1, -700, SlimeBodies.FREE)
	_frontier_steps(sim, 1)
	assert_eq(sim.slimes.state_of(free), SlimeBodies.IN_BASKET, "a free slime too")
	assert_eq(_basket(sim)["weight"], 3)
	assert_eq(_basket(sim)["phase"], FrontierSets.FULL, "at its quota")


func test_sleepers_are_never_caught() -> void:
	var sim := _sim()
	sim.frontier.tap_switch(sim, SWITCH)
	var sleeper := _slime(sim, 1, -800, SlimeBodies.SLEEPER)
	_frontier_steps(sim, 1)
	assert_eq(sim.slimes.state_of(sleeper), SlimeBodies.SLEEPER)
	assert_eq(_basket(sim)["weight"], 0)


# --- The reward waits for the view, then fires ------------------------------------

func test_a_full_basket_waits_for_the_view_then_fires_and_opens_the_gate() -> void:
	var sim := _sim()
	sim.frontier.tap_switch(sim, SWITCH)
	_slime(sim, 3, -750)
	_look(sim, AWAY)
	_frontier_steps(sim, 600)
	assert_eq(_basket(sim)["phase"], FrontierSets.FULL, "off screen: it waits")
	assert_false(sim.gate_states[GATE]["open"])
	_look(sim, BASKET_BOX.get_center())
	_frontier_steps(sim, 1)
	assert_eq(_basket(sim)["phase"], FrontierSets.REWARD, "in view: the reward")
	_frontier_steps(sim, REWARD_TICKS - 1)
	assert_eq(_basket(sim)["phase"], FrontierSets.REWARD, "for REWARD_SECONDS")
	_frontier_steps(sim, 1)
	assert_eq(_basket(sim)["phase"], FrontierSets.FIRED)
	assert_true(sim.gate_states[GATE]["open"], "its rule opens the gate")
	assert_eq(sim.train.open_gates, [GATE], "the loop grows")


func test_opening_the_gate_keeps_the_train_slimes_place() -> void:
	var sim := _sim()
	var ahead := sim.spawn_train_slime(Species.from_letter("A"), 1, 500.0)
	var on_slide := sim.spawn_train_slime(Species.from_letter("A"), 1, 2000.0)
	var old_length := sim.train.length()
	sim.tick = 100
	sim.frontier._open_gate(sim, GATE)
	var new_length := sim.train.length()
	assert_gt(new_length, old_length)
	var kept := sim.train.record_of(ahead)
	assert_almost_eq(kept["distance"], 500.0, 0.001, "on the outgoing route: the same distance")
	var moved := sim.train.record_of(on_slide)
	assert_almost_eq(new_length - moved["distance"], old_length - 2000.0, 0.001,
			"on the old return route: the same distance from the end (they share it)")
	assert_eq(moved["marked_at"], 100, "its progress mark restarts")
	assert_almost_eq(moved["mark"], moved["distance"], 0.001)


# --- Releasing ------------------------------------------------------------------------

func test_a_fired_basket_lets_its_slimes_go_one_at_a_time_at_its_outlet() -> void:
	var sim := _sim()
	sim.frontier.tap_switch(sim, SWITCH)
	var a := _slime(sim, 1, -850, SlimeBodies.IN_BASKET)
	var b := _slime(sim, 2, -750, SlimeBodies.IN_BASKET)
	_frontier_steps(sim, 1)
	assert_eq(_basket(sim)["phase"], FrontierSets.FULL)
	_frontier_steps(sim, 1)
	assert_eq(_basket(sim)["phase"], FrontierSets.REWARD, "full and in view: the next tick")
	_frontier_steps(sim, REWARD_TICKS)
	assert_eq(_basket(sim)["phase"], FrontierSets.FIRED)
	var outlet: Vector2 = sim.level.baskets[BASKET]["outlet"]
	assert_eq(sim.slimes.state_of(a), SlimeBodies.TRAIN, "the lowest id first, as it fires")
	assert_eq(sim.slimes.state_of(b), SlimeBodies.IN_BASKET, "one at a time")
	assert_lt(sim.slimes.centre_of(a).distance_to(outlet), 1.0, "at the outlet")
	assert_eq(_basket(sim)["weight"], 2)
	assert_eq(sim.slimes.velocity_of(a), Vector2.ZERO, "at rest")
	# The outlet is taken by a: b waits until it is clear.
	_frontier_steps(sim, RELEASE_TICKS * 3)
	assert_eq(sim.slimes.state_of(b), SlimeBodies.IN_BASKET, "not onto a slime")
	sim.slimes.set_body(a, _moved(sim.slimes.body_of(a), Vector2(-300, 0)))
	_frontier_steps(sim, 1)
	assert_eq(sim.slimes.state_of(b), SlimeBodies.TRAIN)
	var lift := SlimeBodies.ring_radius_for(2) - SlimeBodies.ring_radius_for(1)
	assert_lt(sim.slimes.centre_of(b).distance_to(outlet + Vector2(0, -lift)), 1.0, "resting its size above it")
	assert_eq(_basket(sim)["weight"], 0, "empty")


func _moved(body: Dictionary, by: Vector2) -> Dictionary:
	var points: PackedVector2Array = body["points"]
	for k in points.size():
		points[k] += by
	body["points"] = points
	body["previous"] = points.duplicate()
	body["centre"] = body["centre"] + by
	return body


func test_released_slimes_ride_the_train_again() -> void:
	var sim := _sim()
	var slime := _slime(sim, 1, -800, SlimeBodies.IN_BASKET)
	# The switch isn't flipped: the basket doesn't hold it.
	for i in 5:
		sim.step()
	assert_eq(sim.slimes.state_of(slime), SlimeBodies.TRAIN)
	assert_true(sim.train.tracks(slime), "the train adopts it")
	assert_false(sim.slimes.body_of(slime)["held"], "free to hop")


# --- Opting out --------------------------------------------------------------------

func test_flipping_the_switch_back_before_full_lets_the_slimes_go() -> void:
	var sim := _sim()
	sim.frontier.tap_switch(sim, SWITCH)
	_slime(sim, 2, -800, SlimeBodies.IN_BASKET)
	_frontier_steps(sim, 10)
	assert_eq(_in_basket(sim), 1, "held while collecting")
	assert_eq(_basket(sim)["weight"], 2)
	assert_true(sim.frontier.tap_switch(sim, SWITCH), "flipped back")
	_frontier_steps(sim, 1)
	assert_eq(_in_basket(sim), 0, "let go")
	assert_eq(_basket(sim)["weight"], 0, "the basket is empty")
	assert_eq(_basket(sim)["phase"], FrontierSets.FILLING, "and can fill again")
	assert_false(sim.gate_states[GATE]["open"])


func test_a_basket_whose_switch_is_not_flipped_does_not_fill() -> void:
	var sim := _sim()
	_slime(sim, 3, -750, SlimeBodies.IN_BASKET)
	_frontier_steps(sim, 1)
	assert_eq(_basket(sim)["phase"], FrontierSets.FILLING, "not collecting: never full")


# --- Inert for good --------------------------------------------------------------------

func test_the_switch_is_locked_once_full_and_inert_once_fired() -> void:
	var sim := _sim()
	sim.frontier.tap_switch(sim, SWITCH)
	_slime(sim, 3, -750, SlimeBodies.IN_BASKET)
	_look(sim, AWAY)
	_frontier_steps(sim, 1)
	assert_eq(_basket(sim)["phase"], FrontierSets.FULL)
	assert_false(sim.frontier.tap_switch(sim, SWITCH), "full: the tap does nothing")
	assert_true(sim.object_states[SWITCH]["flipped"])
	_look(sim, BASKET_BOX.get_center())
	_frontier_steps(sim, REWARD_TICKS + 1)
	assert_eq(_basket(sim)["phase"], FrontierSets.FIRED)
	var before := StateHash.of(sim.object_states[SWITCH])
	assert_false(sim.frontier.tap_switch(sim, SWITCH), "fired: the tap does nothing")
	assert_eq(StateHash.of(sim.object_states[SWITCH]), before)


func test_a_fired_basket_takes_no_more_slimes() -> void:
	var sim := _sim()
	sim.frontier.tap_switch(sim, SWITCH)
	var first := _slime(sim, 3, -750, SlimeBodies.IN_BASKET)
	_frontier_steps(sim, REWARD_TICKS + 2)
	assert_eq(_basket(sim)["phase"], FrontierSets.FIRED)
	assert_eq(_in_basket(sim), 0)
	sim.slimes.set_body(first, _moved(sim.slimes.body_of(first), Vector2(-400, 0)))
	_frontier_steps(sim, RELEASE_TICKS)
	var late := _slime(sim, 1, -850)
	_frontier_steps(sim, 1)
	assert_eq(sim.slimes.state_of(late), SlimeBodies.TRAIN, "let go at once, the outlet clear")
	assert_eq(_basket(sim)["phase"], FrontierSets.FIRED, "and it stays fired")
	assert_eq(sim.train.open_gates, [GATE], "the gate stays open")


func test_a_tap_on_the_switch_flips_it_through_the_simulation() -> void:
	var sim := _sim()
	_look(sim, Vector2(-1125, -75))
	var at := sim.view.world_to_screen(Vector2(-1125, -75))
	sim.push_input(Simulation.touch_down(0, at))
	sim.push_input(Simulation.touch_up(0, at))
	sim.step()
	assert_true(sim.object_states[SWITCH]["flipped"])
	assert_eq(sim.taps[-1]["kind"], TapDispatcher.KIND_SWITCH)
	assert_false(sim.taps[-1]["call"], "a switch tap doesn't call")


# --- The doors --------------------------------------------------------------------------

func test_the_doors_follow_the_states() -> void:
	var sim := _sim()
	sim.frontier.tap_switch(sim, SWITCH)
	_frontier_steps(sim, 1)
	assert_false(sim.object_states[SWITCH]["trapdoor_shut"], "collecting: the trapdoor opens")
	assert_eq(sim.slimes.doors.size(), 1, "only the closed gate")
	var in_way := _slime(sim, 1, -1050)
	sim.slimes.set_body(in_way, _moved(sim.slimes.body_of(in_way), Vector2(0, 10)))
	sim.frontier.tap_switch(sim, SWITCH)
	_frontier_steps(sim, 1)
	assert_false(sim.object_states[SWITCH]["trapdoor_shut"], "a slime is in its way: it stays open")
	sim.slimes.set_body(in_way, _moved(sim.slimes.body_of(in_way), Vector2(400, -10)))
	_frontier_steps(sim, 1)
	assert_true(sim.object_states[SWITCH]["trapdoor_shut"], "clear: it shuts")
	sim.frontier._open_gate(sim, GATE)
	_frontier_steps(sim, 1)
	assert_true(sim.gate_states[GATE]["entrance_closed"], "the old slide entrance closes")
	assert_eq(sim.slimes.doors.size(), 2, "the trapdoor and the lid; the gate's box is gone")


func test_a_shut_door_holds_a_slime_up() -> void:
	var sim := _sim()
	var slime := sim.slimes.create(Species.from_letter("B"), 1, Vector2(-1050, -40), SlimeBodies.SLEEPER)
	sim.slimes.set_state(slime, SlimeBodies.FREE)
	sim.slimes.terrain = TerrainSegments.new([PackedVector2Array([
			Vector2(-2000, 200), Vector2(2000, 200), Vector2(2000, 300), Vector2(-2000, 300)])])
	sim.slimes.auto_hops = false
	for i in 60:
		sim.slimes.tick(Simulation.TICK_SECONDS)
	assert_lt(sim.slimes.centre_of(slime).y, -10.0, "rests on the shut trapdoor")
	sim.object_states[SWITCH]["flipped"] = true
	sim.frontier.step(sim)
	for i in 60:
		sim.slimes.tick(Simulation.TICK_SECONDS)
	assert_gt(sim.slimes.centre_of(slime).y, 100.0, "the trapdoor open, it drops")


# --- The celebration -----------------------------------------------------------------

func test_the_celebration_plays_once_when_the_last_basket_fires() -> void:
	var sim := _sim(3, true)
	sim.frontier.tap_switch(sim, SWITCH)
	_slime(sim, 3, -750, SlimeBodies.IN_BASKET)
	_look(sim, BASKET_BOX.get_center())
	_frontier_steps(sim, REWARD_TICKS + 2)
	assert_eq(_basket(sim)["phase"], FrontierSets.FIRED)
	assert_false(sim.frontier.celebration_done, "another basket still to fire")
	_slime(sim, 1, 750, SlimeBodies.IN_BASKET)
	_look(sim, Vector2(750, -100))
	_frontier_steps(sim, REWARD_TICKS + 2)
	assert_eq(sim.object_states["t.basket.2"]["phase"], FrontierSets.FIRED)
	assert_true(sim.frontier.celebration_done, "the last one: the celebration")
	var since := sim.frontier.celebration_since
	assert_true(sim.frontier.celebration_playing(sim.tick))
	_frontier_steps(sim, int(FrontierSets.CELEBRATION_SECONDS * Simulation.TICK_RATE))
	assert_false(sim.frontier.celebration_playing(sim.tick), "it ends")
	assert_eq(sim.frontier.celebration_since, since, "never again")


func test_a_saved_celebration_is_not_replayed() -> void:
	var sim := _sim()
	sim.frontier.tap_switch(sim, SWITCH)
	_slime(sim, 3, -750, SlimeBodies.IN_BASKET)
	_frontier_steps(sim, REWARD_TICKS + 2)
	assert_true(sim.frontier.celebration_done)
	var save := sim.to_save()
	assert_eq(save["celebration_done"], true)
	# A fresh start from the save, its transient part gone (as a hand-made one).
	save.erase("transient")
	var again := Simulation.from_save(save, _level(), sim.slimes.terrain, 3)
	assert_true(again.frontier.celebration_done)
	assert_false(again.frontier.celebration_playing(again.tick), "not replayed")
	assert_true(SaveData.readable(save)["celebration_done"])


# --- Saves and determinism ---------------------------------------------------------

func test_a_save_round_trip_keeps_the_same_hash() -> void:
	var sim := _sim()
	sim.frontier.tap_switch(sim, SWITCH)
	_slime(sim, 2, -800, SlimeBodies.IN_BASKET)
	for i in 30:
		sim.step()
	var text := JSON.stringify(sim.to_save(), "", true, true)
	var again := Simulation.from_save(JSON.parse_string(text), _level(), sim.slimes.terrain, 3)
	again.view.set_to(sim.view.centre, sim.view.zoom, sim.view.screen_size)
	assert_eq(again.state_hash(), sim.state_hash())
	assert_eq(again.slimes.state_of(sim.slimes.ids()[-1]), SlimeBodies.IN_BASKET)


func test_a_save_with_a_bad_celebration_mark_is_refused() -> void:
	var sim := _sim()
	var save := sim.to_save()
	save["celebration_done"] = "yes"
	assert_eq(SaveData.problems(save, _level()), PackedStringArray(["'celebration_done' must be true or false"]))


func test_same_seed_same_hash() -> void:
	var hashes := []
	for run in 2:
		var sim := _sim(21)
		sim.frontier.tap_switch(sim, SWITCH)
		for k in 3:
			sim.spawn_train_slime(Species.from_letter("C"), 1, 100.0 + 90.0 * k)
		for i in 900:
			_look(sim, BASKET_BOX.get_center())
			sim.step()
		hashes.append(sim.state_hash())
		gut.p("run %d: basket %s, gate %s" % [run, _basket(sim), sim.gate_states[GATE]])
	assert_eq(hashes[0], hashes[1])
