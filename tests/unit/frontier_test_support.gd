extends RefCounted
## Shared helpers for the frontier set tests that came after chunk 14 (not a
## test script: no test_ prefix): the synthetic level of
## test_frontier_sets.gd, a simulation on it, slimes placed on its floor, and
## the session moved to bedtime and sunrise.
##
## The world: a floor whose top is at y = 0 from x = -2000 to 2000. Section 1
## runs along it at a base slime's centre height (y = -24) from x = -1500 to
## 0 and returns under the floor while gate t.gate is closed; section 2 runs
## on to x = 1500 and returns the same way. Basket t.basket (quota 3) is the
## box x -900 to -600, y -200 to 0, on the floor; switch t.switch sends the
## flow into it, over a trapdoor. With `second_basket`, t.basket.2 (quota 1,
## no rule) is the box x 600 to 900.

const Support := preload("res://tests/unit/slime_test_support.gd")
const SWITCH := "t.switch"
const BASKET := "t.basket"
const BASKET_2 := "t.basket.2"
const GATE := "t.gate"
const BASKET_BOX := Rect2(-900, -200, 300, 200)
const BASKET_2_BOX := Rect2(600, -200, 300, 200)
const TRAPDOOR := Rect2(-1100, -10, 100, 10)
const GATE_BOX := Rect2(300, -200, 20, 200)
const LID := Rect2(-30, -5, 60, 10)
const OUTLET_BEFORE := 200.0
const QUOTA := 3
## A view far from both baskets.
const AWAY := Vector2(1200, -300)
const REWARD_TICKS := int(FrontierSets.REWARD_SECONDS * Simulation.TICK_RATE)
const RELEASE_TICKS := int(FrontierSets.RELEASE_SECONDS * Simulation.TICK_RATE)
const CELEBRATION_TICKS := int(FrontierSets.CELEBRATION_SECONDS * Simulation.TICK_RATE)


## The synthetic level's loop (see the class doc).
static func loop() -> LoopData:
	var out := LoopData.new("t.loop")
	out.add_segment("t.s1.out", 1, LoopData.OUTGOING, PackedVector2Array([Vector2(-1500, -24), Vector2(0, -24)]))
	out.add_segment("t.s1.back", 1, LoopData.RETURN, PackedVector2Array([
			Vector2(0, -24), Vector2(0, 400), Vector2(-1500, 400), Vector2(-1500, -24)]), GATE)
	out.add_segment("t.s2.out", 2, LoopData.OUTGOING, PackedVector2Array([Vector2(0, -24), Vector2(1500, -24)]))
	out.add_segment("t.s2.back", 2, LoopData.RETURN, PackedVector2Array([
			Vector2(1500, -24), Vector2(1500, 400), Vector2(-1500, 400), Vector2(-1500, -24)]))
	return out


## The synthetic level (see the class doc).
static func level(second_basket := false) -> LevelData:
	var data := LevelData.new("frontier", 1)
	data.loop = loop()
	data.first_slime = {"id": "t.first-slime", "species": "A", "position": Vector2(-1400, -24)}
	data.add_switch(SWITCH, Rect2(-1150, -100, 50, 50), BASKET, TRAPDOOR)
	data.add_basket(BASKET, BASKET_BOX, QUOTA, FrontierSets.onward_outlet(data.loop, GATE, OUTLET_BEFORE, Vector2.ZERO))
	data.add_gate(GATE, GATE_BOX, LID)
	data.add_signpost("t.signpost", Vector2(-1200, 0), SWITCH)
	data.add_tap_target(SWITCH, TapDispatcher.KIND_SWITCH, Rect2(-1150, -100, 50, 50))
	data.rules.append({"when": {"object": BASKET, "event": "full"}, "then": {"object": GATE, "action": "open"}})
	if second_basket:
		data.add_basket(BASKET_2, BASKET_2_BOX, 1, Vector2(500, -24))
	return data


## A simulation on the synthetic level, the view on basket t.basket.
static func sim(master_seed := 3, second_basket := false) -> Simulation:
	var out := Simulation.new(master_seed)
	out.slimes.terrain = TerrainSegments.new([Support.floor_polygon()])
	out.load_level(level(second_basket))
	look(out, BASKET_BOX.get_center())
	return out


## Puts the view's centre at `at`, zoom 1.
static func look(on: Simulation, at: Vector2) -> void:
	on.view.set_to(at, 1.0, ScreenView.DEFAULT_SIZE)


## A slime of `size` resting on the floor at `x`, in `state`.
static func slime(on: Simulation, size: int, x: float, state := SlimeBodies.TRAIN) -> int:
	var at := Vector2(x, -SlimeBodies.ring_radius_for(size) - SlimeBodies.EDGE)
	return on.slimes.create(Species.from_letter("B"), size, at, state)


## How many slimes are in state `state`.
static func count(on: Simulation, state: int) -> int:
	var n := 0
	for slime_id in on.slimes.ids():
		if on.slimes.state_of(slime_id) == state:
			n += 1
	return n


## Steps the frontier sets alone `n` times, a tick each.
static func frontier_steps(on: Simulation, n: int) -> void:
	for i in n:
		on.frontier.step(on)
		on.tick += 1


## Starts a session and jumps to bedtime (the awake slimes fall asleep).
static func bedtime(on: Simulation) -> void:
	on.session.start(on)
	on.session.jump(on, Session.BEDTIME_MS)


## Jumps from bedtime to sunrise (the bedtime-asleep slimes wake).
static func sunrise(on: Simulation) -> void:
	on.session.jump(on, Session.SUNRISE_MS)
