extends GutTest
## Level rule 23's measure on a synthetic level (chunk 24, item 24.7;
## specs/level-design.md rule 23, D143, O107; ClusterWatch): a basket whose
## outlet drains into a bowl where the train queues fails the rule in its
## played run, and the same level with the basket and its outlet a screen
## away from the bowl passes it.
##
## The world, built in code: a floor whose top is at y = 0 from x = -2000 to
## 6000, with a bowl BOWL_DEPTH deep from x = BOWL_X to BOWL_X + BOWL_WIDTH.
## The loop's outgoing route runs along it at a base slime's centre height
## from x = -1500 to 5500, down through the bowl, and returns under the
## floor. The bowl holds QUEUED train slimes, too deep for them to hop out:
## the train queues there. Basket t.basket (quota QUOTA, its switch flipped)
## starts full of QUOTA slimes, so its run is its fire-and-drain: it plays
## its reward, fires and lets its slimes go one at a time at its outlet.
## Both counts stay under the rule's limit (ClusterWatch.LIMIT, 20), so
## neither the queue nor the basket's own pile is a cluster above it alone:
## - next to the bowl: the basket's box is beside the bowl and its outlet
##   over the bowl's middle, so every slime released falls on the queue,
##   which grows to QUEUED + QUOTA slimes awake;
## - apart: the basket's box and its outlet are a screen to the right, on
##   flat ground, so the slimes released ride the train on, away from it.
## The run is watched from the start until the basket is empty and
## SETTLE_TICKS more (at most RUN_TICKS), the camera holding the bowl and
## the basket in view.
# @test-link [[req_level_design_rules]]

const BOWL_X := -600.0
const BOWL_WIDTH := 360.0
const BOWL_DEPTH := 180.0
## The bowl's flat floor starts this far in from each rim.
const BOWL_SLOPE := 100.0
const QUOTA := 19
const QUEUED := 18
const BASKET := "t.basket"
const SWITCH := "t.switch"
const SWITCH_BOX := Rect2(-1150, -100, 50, 50)
const TRAPDOOR := Rect2(-1100, -10, 100, 10)
## Next to the bowl: the box beside it, the outlet over its middle.
const BOX_NEXT := Rect2(-900, -200, 300, 200)
const OUTLET_NEXT := Vector2(BOWL_X + BOWL_WIDTH / 2.0, -120)
## Apart: the box and the outlet a screen to the right, on flat ground.
const BOX_APART := Rect2(300, -200, 300, 200)
const OUTLET_APART := Vector2(900, -24)
const VIEW := Vector2(0, -100)
const SETTLE_TICKS := 30 * 60
const RUN_TICKS := 120 * 60


func _floor_top() -> PackedVector2Array:
	return PackedVector2Array([Vector2(-2000, 0), Vector2(BOWL_X, 0), Vector2(BOWL_X + BOWL_SLOPE, BOWL_DEPTH),
			Vector2(BOWL_X + BOWL_WIDTH - BOWL_SLOPE, BOWL_DEPTH), Vector2(BOWL_X + BOWL_WIDTH, 0), Vector2(6000, 0)])


func _level(box: Rect2, outlet: Vector2) -> LevelData:
	var route := PackedVector2Array()
	for p in _floor_top():
		route.append(Vector2(clampf(p.x, -1500, 5500), p.y - 24))
	var loop := LoopData.new("t.loop")
	loop.add_segment("t.s1.out", 1, LoopData.OUTGOING, route)
	loop.add_segment("t.s1.back", 1, LoopData.RETURN, PackedVector2Array([
			Vector2(5500, -24), Vector2(5500, 400), Vector2(-1500, 400), Vector2(-1500, -24)]))
	var data := LevelData.new("rule23", 1)
	data.loop = loop
	data.first_slime = {"id": "t.first-slime", "species": "A", "position": Vector2(-1400, -24)}
	data.add_switch(SWITCH, SWITCH_BOX, BASKET, TRAPDOOR)
	data.add_basket(BASKET, box, QUOTA, outlet)
	data.add_tap_target(SWITCH, TapDispatcher.KIND_SWITCH, SWITCH_BOX)
	return data


## The simulation of the level with its basket's box at `box` and its outlet
## at `outlet`: its switch flipped, the basket full, the queue in the bowl.
func _sim(box: Rect2, outlet: Vector2) -> Simulation:
	var terrain := _floor_top()
	terrain.append(Vector2(6000, 300))
	terrain.append(Vector2(-2000, 300))
	var sim := Simulation.new(5)
	sim.slimes.terrain = TerrainSegments.new([terrain])
	sim.load_level(_level(box, outlet))
	sim.view.set_to(VIEW, 0.5, ScreenView.DEFAULT_SIZE)
	sim.frontier.tap_switch(sim, SWITCH)
	for i in QUOTA:
		var at := Vector2(box.position.x + 20 + (i % 6) * 48, -24 - (i / 6) * 48)
		sim.slimes.create(i % Species.COUNT, 1, at, SlimeBodies.IN_BASKET)
	for i in QUEUED:
		var at := Vector2(BOWL_X + 110 + (i % 4) * 48, BOWL_DEPTH - 24 - (i / 4) * 48)
		sim.slimes.create(i % Species.COUNT, 1, at, SlimeBodies.TRAIN)
	return sim


## Plays the run (see the class doc) and returns its watch. `label` names it
## in the log.
func _play(label: String, box: Rect2, outlet: Vector2) -> ClusterWatch:
	var sim := _sim(box, outlet)
	var watch := ClusterWatch.new()
	var empty_at := -1
	for t in RUN_TICKS:
		sim.step()
		watch.watch(sim)
		if t == 0:
			assert_eq(sim.object_states[BASKET]["weight"], QUOTA, "%s: the basket weighs its quota" % label)
		if empty_at < 0 and sim.object_states[BASKET]["weight"] == 0:
			empty_at = sim.tick
		if empty_at >= 0 and sim.tick >= empty_at + SETTLE_TICKS:
			break
	assert_eq(sim.object_states[BASKET]["phase"], FrontierSets.FIRED, "%s: the basket fires" % label)
	assert_gt(empty_at, -1, "%s: the basket drains within %d s" % [label, RUN_TICKS / Simulation.TICK_RATE])
	gut.p("rule 23, %s (empty at tick %d, run to %d): %s" % [label, empty_at, sim.tick, watch.report()])
	return watch


func test_both_counts_stay_under_the_limit_alone() -> void:
	assert_lt(QUOTA, ClusterWatch.LIMIT, "the basket's own pile is no cluster above the limit alone")
	assert_lt(QUEUED, ClusterWatch.LIMIT, "the queue in the bowl is no cluster above the limit alone")


func test_a_basket_draining_into_a_bowl_fails_rule_23() -> void:
	var watch := _play("next to the bowl", BOX_NEXT, OUTLET_NEXT)
	assert_gt(watch.largest, ClusterWatch.LIMIT, "the queue and the slimes released gather above the limit")
	assert_gt(watch.longest_above_s(), ClusterWatch.HOLD_SECONDS, "for more than the hold in a row")
	assert_false(watch.passes(), "rule 23 fails: %s" % watch.report())


func test_the_same_basket_apart_from_the_bowl_passes_rule_23() -> void:
	var watch := _play("apart", BOX_APART, OUTLET_APART)
	assert_true(watch.passes(), "rule 23 passes: %s" % watch.report())
