extends GutTest
## The test level's frontier sets (set 1 from chunk 14, set 2 from chunk 15,
## set 3 from chunk 16: a switch and a basket, no rule and no gate, the
## level's last) against the level rules: a signpost at each fork, for its switch [rule 6];
## each switch's trapdoor on the loop over its basket, so the flow drops in
## by gravity and taps alone [rule 10: no tilt]; each basket's outlet on the
## onward route; each gate on the next section's route, its lid over its
## slide's entrance; each section has its own return route [rule 13];
## opening the gates leaves every exploration branch reachable from the loop
## [rule 14]. The rules' checks are the level-rules checker's (LevelChecker,
## chunk LD1); this file holds what the test level's design fixes.

# @test-link [[rule_signpost_at_every_fork]]
# @test-link [[rule_return_route_per_section]]
# @test-link [[rule_return_route_may_carry_exploration]]
# @test-link [[rule_tilt_never_required]]
# @test-link [[req_switch_basket_gate_set]]

const LEVEL_SCENE := "res://levels/test/level.tscn"
## A point is on the loop when this close to it, px.
const ON_LOOP := 40.0

var level: Level
var data: LevelData
var checker: LevelChecker


func before_all() -> void:
	level = load(LEVEL_SCENE).instantiate()
	add_child(level)
	data = level.data
	checker = LevelChecker.new(level)


func after_all() -> void:
	level.free()


func _every_gate() -> Array:
	return data.gates.keys()


## The section number of stable ID `id` ("s2.switch" -> 2).
func _section_of(id: String) -> int:
	return LevelChecker.section_of(id)


## The gates open while section `section` is the frontier: those before it.
func _gates_before(section: int) -> Array:
	return checker.gates_before(section)


# @test-link [[rule_gate_opens_via_switch_basket_set]]
func test_there_is_a_frontier_set_per_section_with_its_rule() -> void:
	assert_eq(data.switches.keys(), ["s1.switch", "s2.switch", "s3.switch"])
	assert_eq(data.baskets.keys(), ["s1.basket", "s2.basket", "s3.basket"])
	assert_eq(data.gates.keys(), ["s1.gate", "s2.gate"], "set 3 has no gate")
	assert_eq(data.switches["s1.switch"]["basket"], "s1.basket")
	assert_eq(data.baskets["s1.basket"]["quota"], 6)
	assert_eq(data.switches["s2.switch"]["basket"], "s2.basket")
	assert_eq(data.baskets["s2.basket"]["quota"], 15)
	assert_eq(data.switches["s3.switch"]["basket"], "s3.basket")
	assert_eq(data.baskets["s3.basket"]["quota"], 60)
	# Basket 3 has no rule: filling it completes the level (the celebration).
	assert_eq(data.rules, [{"when": {"object": "s1.basket", "event": "full"},
			"then": {"object": "s1.gate", "action": "open"}},
			{"when": {"object": "s2.basket", "event": "full"},
			"then": {"object": "s2.gate", "action": "open"}}])
	assert_eq(checker.check(12)["findings"], [], "the checker's rule 12")


func test_a_signpost_stands_at_every_fork() -> void:
	# The checker's rule 6: one signpost per switch, naming it, within 200 px
	# of its box's centre, no more.
	assert_eq(checker.check(6)["findings"], [])
	assert_eq(data.signposts.size(), data.switches.size(), "one per switch, no more")


func test_signposts_are_not_interactive() -> void:
	for id in data.signposts:
		assert_false(data.tap_targets.has(id), "%s: a tap doesn't land on it" % id)


func test_the_trapdoor_lies_on_the_loop_over_its_basket() -> void:
	# The checker's rule 10: each switch's trapdoor on the loop (its gate
	# closed), opening onto its basket, the basket below: slimes drop in, no
	# tilt.
	assert_eq(data.switches.size(), 3)
	assert_eq(checker.check(10)["findings"], [])


func test_the_outlet_is_on_the_onward_route() -> void:
	for id in data.baskets:
		var outlet: Vector2 = data.baskets[id]["outlet"]
		var section := _section_of(id)
		var near := data.loop.closest(outlet, _gates_before(section))
		assert_lt(near["gap"], ON_LOOP, "%s's outlet is on the loop" % id)
		assert_eq(near["segment"], "s%d.loop" % section, "on the outgoing route, before the slide entrance")
		assert_lt(data.loop.closest(outlet, _every_gate())["gap"], ON_LOOP, "and still once the gate is open")
		assert_false((data.baskets[id]["box"] as Rect2).has_point(outlet), "outside the basket")


func test_each_gate_stands_on_the_next_sections_route_and_its_lid_over_its_slide() -> void:
	for id in data.gates:
		var section := _section_of(id)
		var gate: Dictionary = data.gates[id]
		var box: Rect2 = gate["box"]
		var next_loop := data.loop.segment("s%d.loop" % (section + 1))
		var crosses := false
		for point in next_loop["points"]:
			if point.x >= box.position.x and point.x <= box.end.x:
				crosses = true
		var first: Vector2 = next_loop["points"][0]
		var last: Vector2 = next_loop["points"][next_loop["points"].size() - 1]
		crosses = crosses or (first.x < box.position.x and last.x > box.end.x)
		assert_true(crosses, "section %d's route passes %s" % [section + 1, id])
		var lid: Rect2 = gate["lid"]
		var entrance: Vector2 = data.loop.segment("s%d.slide" % section)["points"][0]
		assert_true(entrance.x > lid.position.x and entrance.x < lid.end.x,
				"%s's lid spans slide %d's entrance" % [id, section])
		assert_gt(lid.position.y, entrance.y, "just under the route, flush with the ground")


func test_each_section_has_its_own_return_route() -> void:
	var returns := {}
	for segment in data.loop.segments:
		if segment["kind"] == LoopData.RETURN:
			returns[segment["section"]] = returns.get(segment["section"], 0) + 1
	assert_eq(returns, {1: 1, 2: 1, 3: 1})
	assert_eq(data.loop.segment("s1.slide")["gate"], "s1.gate")
	assert_eq(data.loop.segment("s2.slide")["gate"], "s2.gate")
	assert_eq(data.loop.validate(), PackedStringArray())
	var grown := PackedStringArray()
	for segment in data.loop.current_segments(["s1.gate"]):
		grown.append(segment["id"])
	assert_eq(grown, PackedStringArray(["s1.loop", "s2.loop", "s2.slide"]), "gate 1 open")
	grown = PackedStringArray()
	for segment in data.loop.current_segments(_every_gate()):
		grown.append(segment["id"])
	assert_eq(grown, PackedStringArray(["s1.loop", "s2.loop", "s3.loop", "s3.slide"]), "gate 2 open too")
	# The checker's rule 13: one return route per section, naming its gate
	# (none for the last), closing the loop in every gate state.
	assert_eq(checker.check(13)["findings"], [])


func test_opening_the_gate_leaves_every_branch_reachable() -> void:
	# The checker's rule 14: every route back still ends on the loop in every
	# gate state from its section on, and doesn't hang off a slide.
	assert_eq(data.route_backs.size(), 6)
	assert_eq(checker.check(14)["findings"], [])
