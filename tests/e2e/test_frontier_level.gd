extends GutTest
## The test level's frontier set 1 against the level rules (chunk 14): a
## signpost at the fork, for the switch [rule 6]; the switch's trapdoor on
## the loop over its basket, so the flow drops in by gravity and taps alone
## [rule 10: no tilt]; the basket's outlet on the onward route; the gate on
## section 2's route, its lid over slide 1's entrance; each section has its
## own return route [rule 13]; opening gate 1 leaves every exploration branch
## reachable from the loop [rule 14].

# @test-link [[rule_signpost_at_every_fork]]
# @test-link [[rule_return_route_per_section]]
# @test-link [[rule_return_route_may_carry_exploration]]
# @test-link [[rule_tilt_never_required]]
# @test-link [[req_switch_basket_gate_set]]

const LEVEL_SCENE := "res://levels/test/level.tscn"
## A signpost stands at its fork: this close to its switch, px.
const AT_FORK := 200.0
## A point is on the loop when this close to it, px.
const ON_LOOP := 40.0
## A route back ends on the loop when its last point is this close to it
## (as test_test_level.gd).
const ON_LOOP_MAX_GAP := 32.0

var level: Level
var data: LevelData


func before_all() -> void:
	level = load(LEVEL_SCENE).instantiate()
	add_child(level)
	data = level.data


func after_all() -> void:
	level.free()


func _every_gate() -> Array:
	return data.gates.keys()


func test_there_is_a_frontier_set_with_its_rule() -> void:
	assert_eq(data.switches.keys(), ["s1.switch"])
	assert_eq(data.baskets.keys(), ["s1.basket"])
	assert_eq(data.gates.keys(), ["s1.gate"])
	assert_eq(data.switches["s1.switch"]["basket"], "s1.basket")
	assert_eq(data.baskets["s1.basket"]["quota"], 6)
	assert_eq(data.rules, [{"when": {"object": "s1.basket", "event": "full"},
			"then": {"object": "s1.gate", "action": "open"}}])


func test_a_signpost_stands_at_every_fork() -> void:
	var by_switch := {}
	for id in data.signposts:
		by_switch[data.signposts[id]["switch"]] = id
	for id in data.switches:
		assert_true(by_switch.has(id), "%s has a signpost" % id)
		if by_switch.has(id):
			var at: Vector2 = data.signposts[by_switch[id]]["position"]
			var fork: Vector2 = (data.switches[id]["box"] as Rect2).get_center()
			assert_lt(at.distance_to(fork), AT_FORK, "%s stands at the fork" % by_switch[id])
	assert_eq(by_switch.size(), data.signposts.size(), "one per switch, no more")


func test_signposts_are_not_interactive() -> void:
	for id in data.signposts:
		assert_false(data.tap_targets.has(id), "%s: a tap doesn't land on it" % id)


func test_the_trapdoor_lies_on_the_loop_over_its_basket() -> void:
	for id in data.switches:
		var trapdoor: Rect2 = data.switches[id]["trapdoor"]
		var basket: Rect2 = data.baskets[data.switches[id]["basket"]]["box"]
		assert_true(trapdoor.has_area(), "%s has a trapdoor" % id)
		var top := Vector2(trapdoor.get_center().x, trapdoor.position.y)
		assert_lt(data.loop.closest(top)["gap"], ON_LOOP, "the loop runs over it (gates closed)")
		assert_true(trapdoor.grow(1.0).intersects(basket), "it opens onto the basket")
		assert_gt(basket.end.y, trapdoor.end.y, "the basket is below: slimes drop in, no tilt")


func test_the_outlet_is_on_the_onward_route() -> void:
	for id in data.baskets:
		var outlet: Vector2 = data.baskets[id]["outlet"]
		var near := data.loop.closest(outlet)
		assert_lt(near["gap"], ON_LOOP, "%s's outlet is on the loop" % id)
		assert_eq(near["segment"], "s1.loop", "on the outgoing route, before the slide entrance")
		assert_lt(data.loop.closest(outlet, _every_gate())["gap"], ON_LOOP, "and still once the gate is open")
		assert_false((data.baskets[id]["box"] as Rect2).has_point(outlet), "outside the basket")


func test_the_gate_stands_on_section_2s_route_and_its_lid_over_slide_1() -> void:
	var gate: Dictionary = data.gates["s1.gate"]
	var box: Rect2 = gate["box"]
	var s2_loop := data.loop.segment("s2.loop")
	var crosses := false
	for point in s2_loop["points"]:
		if point.x >= box.position.x and point.x <= box.end.x:
			crosses = true
	var first: Vector2 = s2_loop["points"][0]
	var last: Vector2 = s2_loop["points"][s2_loop["points"].size() - 1]
	crosses = crosses or (first.x < box.position.x and last.x > box.end.x)
	assert_true(crosses, "section 2's route passes the gate")
	var lid: Rect2 = gate["lid"]
	var entrance: Vector2 = data.loop.segment("s1.slide")["points"][0]
	assert_true(entrance.x > lid.position.x and entrance.x < lid.end.x, "the lid spans slide 1's entrance")
	assert_gt(lid.position.y, entrance.y, "just under the route, flush with the ground")


func test_each_section_has_its_own_return_route() -> void:
	var returns := {}
	for segment in data.loop.segments:
		if segment["kind"] == LoopData.RETURN:
			returns[segment["section"]] = returns.get(segment["section"], 0) + 1
	assert_eq(returns, {1: 1, 2: 1})
	assert_eq(data.loop.segment("s1.slide")["gate"], "s1.gate")
	assert_eq(data.loop.validate(), PackedStringArray())
	var grown := PackedStringArray()
	for segment in data.loop.current_segments(_every_gate()):
		grown.append(segment["id"])
	assert_eq(grown, PackedStringArray(["s1.loop", "s2.loop", "s2.slide"]))


func test_opening_the_gate_leaves_every_branch_reachable() -> void:
	for id in data.route_backs:
		var points: PackedVector2Array = data.route_backs[id]["points"]
		var end := points[points.size() - 1]
		assert_lt(data.loop.closest(end, _every_gate())["gap"], ON_LOOP_MAX_GAP,
				"%s still ends on the loop once gate 1 is open" % id)
		assert_ne(data.loop.closest(end)["segment"], "s1.slide", "%s doesn't hang off slide 1" % id)
