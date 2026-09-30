extends GutTest
## Chunk LD1: the level-rules checker (tools/level_check/level_checker.gd)
## and its command line (tools/check_level.gd), on levels built in code.
##
## The base level is small and follows every rule the code can check: a
## straight loop along a floor, its return route coming home under the floor
## and up behind the loop's start, a split zone at the start, the first
## slime, two sleepers on a high ledge (an exploration branch with its route
## back and a framing zone) and one frontier set with its signpost. Each
## broken variant breaks one rule, and the checker must FAIL it with a
## finding naming the right stable ID. The rules' behaviour parts (laps,
## ways back) are skipped here (fast); test_level_ways_back_e2e.gd runs the
## ways back through the checker on the test level.
##
## Distances are in level pixels; y grows downward, the floor's top is y 0.
# @test-link [[req_level_design_rules]]
# @test-link [[rule_no_dead_ends]]
# @test-link [[rule_start_carries_split_zone]]
# @test-link [[rule_signpost_at_every_fork]]
# @test-link [[rule_gravity_leads_back_to_loop]]
# @test-link [[rule_exploration_branch_has_route_back]]

const TEST_LEVEL := "res://levels/test/level.tscn"
const STATUSES := [LevelChecker.PASS, LevelChecker.FAIL, LevelChecker.MANUAL, LevelChecker.NA]
## The base level's status per rule (fast): everything the code checks
## passes; it has no dip in its loop, so rule 5 doesn't apply.
const BASE_STATUSES := {
	1: "PASS", 2: "PASS", 3: "PASS", 4: "PASS", 5: "N/A", 6: "PASS", 7: "PASS", 8: "PASS",
	9: "PASS", 10: "PASS", 11: "PASS", 12: "PASS", 13: "PASS", 14: "PASS", 15: "PASS",
	16: "PASS", 17: "PASS", 18: "PASS", 19: "PASS", 20: "PASS", 21: "PASS", 22: "PASS",
}
## The test level's status per rule (fast): its fusion dips make rule 5
## apply; everything else the code checks passes but KNOWN_BREAKS.
const TEST_LEVEL_STATUSES := {
	1: "PASS", 2: "PASS", 3: "PASS", 4: "PASS", 5: "PASS", 6: "PASS", 7: "PASS", 8: "PASS",
	9: "PASS", 10: "PASS", 11: "PASS", 12: "PASS", 13: "PASS", 14: "PASS", 15: "PASS",
	16: "PASS", 17: "PASS", 18: "PASS", 19: "PASS", 20: "PASS", 21: "PASS", 22: "PASS",
}
## Known breaks of the rules in the test level, reported rather than hidden:
## rule -> {"ids": the stable IDs its findings name, "why"}. Each is checked
## to still break the rule with exactly those findings (so a fixed one can't
## linger here) and marked pending instead of failing. None since chunk R22:
## the one LD1 found (rule 22 (b): the second dip's hollow, `Dip2Hollow`,
## overhung the loop's flat at x 9.93 to 10.0 only 110 px over the ground,
## within a called base slime's reach, `s2.sleeper.15`, `.16`) was fixed by
## moving the hollow over the dip's far slope.
const KNOWN_BREAKS := {}


# --- The base level --------------------------------------------------------------

func _curve(points: Array) -> Curve2D:
	var curve := Curve2D.new()
	for point in points:
		curve.add_point(point)
	return curve


func _terrain(level: Level, node_name: String, points: Array) -> Terrain:
	var piece := Terrain.new()
	piece.name = node_name
	piece.curve = _curve(points)
	level.add_child(piece)
	return piece


func _sleeper(level: Level, id: String, species: String, at: Vector2) -> Sleeper:
	var sleeper := Sleeper.new()
	sleeper.stable_id = id
	sleeper.species = species
	sleeper.position = at
	level.add_child(sleeper)
	return sleeper


## The base level, not built: variants change it, then _checker() builds it.
func _base() -> Level:
	var level := Level.new()
	level.name = "Synthetic"
	level.level_id = "synthetic"
	level.level_version = 1
	autofree(level)
	_terrain(level, "Floor", [Vector2(-200, 0), Vector2(3000, 0), Vector2(3000, 200), Vector2(-200, 200)])
	_terrain(level, "HighLedge", [Vector2(350, -160), Vector2(750, -160), Vector2(750, -140), Vector2(350, -140)])
	var loop := Loop.new()
	loop.name = "Loop"
	level.add_child(loop)
	var outgoing := LoopSegment.new()
	outgoing.stable_id = "s1.loop"
	outgoing.curve = _curve([Vector2(200, -24), Vector2(2600, -24)])
	loop.add_child(outgoing)
	var slide := LoopSegment.new()
	slide.stable_id = "s1.slide"
	slide.kind = LoopData.RETURN
	slide.curve = _curve([Vector2(2600, -24), Vector2(2700, 400), Vector2(60, 400), Vector2(60, -24),
			Vector2(200, -24)])
	loop.add_child(slide)
	var split_zone := SplitZone.new()
	split_zone.stable_id = "start.split-zone"
	split_zone.position = Vector2(200, -40)
	split_zone.size = Vector2(300, 120)
	level.add_child(split_zone)
	var first := FirstSlime.new()
	first.species = "A"
	first.position = Vector2(160, -24)
	level.add_child(first)
	_sleeper(level, "s1.sleeper.01", "B", Vector2(400, -184))
	_sleeper(level, "s1.sleeper.02", "C", Vector2(700, -184))
	var branch := ExplorationBranch.new()
	branch.stable_id = "s1.branch.ledge"
	branch.position = Vector2(550, -200)
	branch.size = Vector2(500, 150)
	level.add_child(branch)
	var route_back := RouteBack.new()
	route_back.name = "RouteBack"
	route_back.stable_id = "s1.route-back.ledge"
	route_back.serves = "s1.branch.ledge"
	route_back.curve = _curve([Vector2(760, -184), Vector2(800, -150), Vector2(850, -24)])
	level.add_child(route_back)
	var frame := FramingZone.new()
	frame.stable_id = "s1.frame.ledge"
	frame.position = Vector2(550, -100)
	frame.size = Vector2(600, 300)
	frame.zoom = 0.8
	level.add_child(frame)
	var switch := Switch.new()
	switch.stable_id = "s1.switch"
	switch.position = Vector2(2300, -40)
	switch.basket_id = "s1.basket"
	switch.trapdoor = Rect2(-100, 24, 200, 20)
	level.add_child(switch)
	var basket := Basket.new()
	basket.stable_id = "s1.basket"
	basket.position = Vector2(2300, 50)
	basket.size = Vector2(200, 100)
	basket.quota = 5
	basket.outlet = "point"
	basket.outlet_point = Vector2(400, -74)
	level.add_child(basket)
	var signpost := Signpost.new()
	signpost.name = "Signpost"
	signpost.stable_id = "s1.signpost"
	signpost.switch_id = "s1.switch"
	signpost.position = Vector2(2150, -24)
	level.add_child(signpost)
	return level


## The level's component with stable ID `id` (before it is built).
func _node(level: Level, id: String) -> Node:
	for node in level.find_children("*", "", true, false):
		if node.is_in_group(Level.THINGS_GROUP) and node.stable_id == id:
			return node
	return null


## Builds `level` (out of the tree: its load errors are returned, not
## pushed) and returns its checker.
func _checker(level: Level) -> LevelChecker:
	level.build()
	return LevelChecker.new(level)


## Asserts that `rule` FAILs on `level` with a finding naming `id`; returns
## the result.
func _assert_fails(level: Level, rule: int, id: String) -> Dictionary:
	var result := _checker(level).check(rule, true)
	assert_eq(result["status"], LevelChecker.FAIL, "rule %d fails: %s" % [rule, result])
	var ids := []
	for finding in result["findings"]:
		ids.append(finding["id"])
	assert_has(ids, id, "rule %d names %s: %s" % [rule, id, result["findings"]])
	return result


func _statuses(results: Array) -> Dictionary:
	var out := {}
	for result in results:
		out[result["rule"]] = result["status"]
	return out


# --- The base level passes -------------------------------------------------------

func test_the_base_level_loads_and_fails_no_rule() -> void:
	var checker := _checker(_base())
	assert_eq(checker.check_load()["status"], LevelChecker.PASS, str(checker.check_load()))
	var results := checker.check_all(true)
	for result in results:
		assert_ne(result["status"], LevelChecker.FAIL, "rule %d: %s" % [result["rule"], result["findings"]])
	assert_eq(_statuses(results), BASE_STATUSES)


func test_check_all_covers_rules_1_to_22_once_with_valid_results() -> void:
	var results := _checker(_base()).check_all(true)
	var rules := []
	for result in results:
		rules.append(result["rule"])
		assert_has(STATUSES, result["status"], "rule %d" % result["rule"])
		assert_false(str(result["title"]).is_empty(), "rule %d has its title" % result["rule"])
		assert_true(result["findings"] is Array and result["notes"] is Array and result["manual"] is String)
		if result["status"] == LevelChecker.FAIL:
			assert_false(result["findings"].is_empty(), "a FAIL says what is wrong")
		if result["status"] in [LevelChecker.MANUAL, LevelChecker.NA]:
			assert_false(str(result["manual"]).is_empty() and result["notes"].is_empty(), "rule %d says why"
					% result["rule"])
	assert_eq(rules, range(1, 23))
	var some := _checker(_base()).check_all(true, [17, 4])
	assert_eq(some.map(func(result): return result["rule"]), [4, 17], "a selection, in order")


func test_behaviour_is_skipped_when_fast() -> void:
	var checker := _checker(_base())
	for rule in [1, 2, 7]:
		assert_has(checker.check(rule, true)["notes"], LevelChecker.FAST_NOTE, "rule %d" % rule)


func test_a_level_without_a_loop_fails_to_load_and_the_loop_rules_do_not_apply() -> void:
	var level := _base()
	level.get_node("Loop").free()
	var checker := _checker(level)
	var load := checker.check_load()
	assert_eq(load["status"], LevelChecker.FAIL)
	assert_true(str(load["findings"]).contains("no loop"), str(load["findings"]))
	var one := checker.check(1, true)
	assert_eq(one["status"], LevelChecker.NA)
	assert_true(str(one["notes"]).contains("no loop"))
	assert_eq(checker.check_all(true).size(), 22)


# --- One broken variant per rule -------------------------------------------------

func test_a_branch_without_a_route_back_fails_rules_3_and_8() -> void:
	var level := _base()
	level.get_node("RouteBack").free()
	_assert_fails(level, 3, "s1.branch.ledge")
	_assert_fails(level, 8, "s1.branch.ledge")


# @test-link [[rule_return_route_may_carry_exploration]]
func test_a_route_back_landing_on_a_return_route_fails_rules_3_and_14() -> void:
	var level := _base()
	_node(level, "s1.route-back.ledge").curve = _curve([Vector2(760, -184), Vector2(760, 400)])
	_assert_fails(level, 3, "s1.route-back.ledge")
	_assert_fails(level, 14, "s1.route-back.ledge")


func test_no_split_zone_at_the_start_fails_rule_4() -> void:
	var level := _base()
	_node(level, "start.split-zone").position = Vector2(1500, -40)
	_assert_fails(level, 4, "start.loop")


# @test-link [[rule_dip_may_nudge_fusion]]
func test_the_dips_of_the_loop_are_found() -> void:
	var level := _base()
	_node(level, "s1.loop").curve = _curve([Vector2(200, -24), Vector2(1000, -24), Vector2(1200, 176),
			Vector2(1400, -24), Vector2(2600, -24)])
	var checker := _checker(level)
	var dips := checker.dips()
	assert_eq(dips.size(), 1, str(dips))
	assert_almost_eq(float(dips[0]["depth"]), 200.0, 1.0)
	assert_almost_eq(float(dips[0]["x"]), 1200.0, 8.0)
	var result := checker.check(5, true)
	assert_eq(result["status"], LevelChecker.PASS)
	assert_eq(result["notes"].size(), 1, "the dip is listed")


func test_a_switch_without_signpost_fails_rule_6() -> void:
	var level := _base()
	level.get_node("Signpost").free()
	_assert_fails(level, 6, "s1.switch")


func test_a_signpost_away_from_its_fork_fails_rule_6() -> void:
	var level := _base()
	_node(level, "s1.signpost").position = Vector2(1500, -24)
	_assert_fails(level, 6, "s1.signpost")


# @test-link [[rule_gravity_leads_back_to_loop]]
func test_a_route_back_that_climbs_fails_rule_7() -> void:
	var level := _base()
	_node(level, "s1.route-back.ledge").curve = _curve([Vector2(760, -184), Vector2(800, -250),
			Vector2(850, -24)])
	_assert_fails(level, 7, "s1.route-back.ledge")


# @test-link [[rule_hints_visible_from_loop]]
func test_a_decoration_in_front_over_a_sleeper_fails_rule_9() -> void:
	var level := _base()
	var bush := Decoration.new()
	bush.name = "FrontBush"
	bush.curve = _curve([Vector2(370, -214), Vector2(430, -214), Vector2(430, -154), Vector2(370, -154)])
	level.add_child(bush)
	assert_eq(_checker(level).check(9, true)["status"], LevelChecker.PASS, "behind the level: fine")
	bush.in_front = true
	var result := _assert_fails(level, 9, "s1.sleeper.01")
	assert_true(str(result["findings"]).contains("FrontBush"), "names the decoration")


# @test-link [[rule_hints_visible_from_loop]]
func test_a_branch_out_of_every_rail_view_fails_rule_9() -> void:
	var level := _base()
	_node(level, "s1.branch.ledge").position = Vector2(550, -2000)
	_node(level, "s1.sleeper.01").position = Vector2(400, -1984)
	_node(level, "s1.sleeper.02").position = Vector2(700, -1984)
	_node(level, "s1.route-back.ledge").curve = _curve([Vector2(760, -1984), Vector2(850, -24)])
	_assert_fails(level, 9, "s1.branch.ledge")


# @test-link [[rule_tilt_never_required]]
func test_a_basket_above_its_trapdoor_fails_rule_10() -> void:
	var level := _base()
	_node(level, "s1.basket").position = Vector2(2300, -300)
	_assert_fails(level, 10, "s1.switch")


# @test-link [[rule_first_section_species_count]]
func test_two_species_in_section_1_fail_rule_11() -> void:
	var level := _base()
	_node(level, "s1.sleeper.02").species = "B"
	var result := _checker(level).check(11, true)
	assert_eq(result["status"], LevelChecker.FAIL)


# @test-link [[rule_gate_opens_via_switch_basket_set]]
func test_a_basket_without_its_switch_fails_rule_12() -> void:
	var level := _base()
	_node(level, "s1.switch").basket_id = ""
	_assert_fails(level, 12, "s1.basket")


# @test-link [[rule_return_route_per_section]]
# @test-link [[rule_gate_opens_via_switch_basket_set]]
func test_a_gate_on_the_last_sections_return_route_fails_rules_12_and_13() -> void:
	var level := _base()
	var gate := Gate.new()
	gate.stable_id = "s1.gate"
	gate.position = Vector2(2650, -100)
	level.add_child(gate)
	_node(level, "s1.slide").gate_id = "s1.gate"
	_assert_fails(level, 13, "s1.slide")
	_assert_fails(level, 12, "s1.gate")


# @test-link [[rule_max_200_slimes_per_level]]
func test_201_base_slimes_fail_rule_16() -> void:
	var level := _base()
	for n in range(3, 202):
		_sleeper(level, "s1.sleeper.%02d" % n, "C", Vector2(1000 + 5 * n, -2000))
	var result := _checker(level).check(16, true)
	assert_eq(result["status"], LevelChecker.FAIL)
	assert_true(str(result["findings"]).contains("201"), str(result["findings"]))


# @test-link [[rule_sleepers_never_on_loop]]
func test_a_sleeper_on_the_loop_fails_rule_17() -> void:
	var level := _base()
	_sleeper(level, "s1.sleeper.03", "C", Vector2(1200, -30))
	_assert_fails(level, 17, "s1.sleeper.03")


# @test-link [[rule_first_sleeper_near_first_awake_slime]]
func test_a_far_first_sleeper_fails_rule_18() -> void:
	var level := _base()
	_node(level, "s1.sleeper.01").position = Vector2(1000, -184)
	_node(level, "s1.sleeper.02").position = Vector2(1100, -184)
	_assert_fails(level, 18, "s1.sleeper.01")


# @test-link [[rule_framing_zone_wherever_wider_view_needed]]
func test_a_framing_zone_off_the_loop_fails_rule_19() -> void:
	var level := _base()
	_node(level, "s1.frame.ledge").position = Vector2(550, -1000)
	_assert_fails(level, 19, "s1.frame.ledge")


# @test-link [[rule_released_level_stable_with_migration]]
func test_a_duplicate_stable_id_fails_rule_20_and_not_the_load_check() -> void:
	var level := _base()
	_sleeper(level, "s1.sleeper.02", "C", Vector2(720, -184))
	var checker := _checker(level)
	assert_eq(checker.check_load()["status"], LevelChecker.PASS, "rule 20's finding, not a load failure")
	_assert_fails(level, 20, "s1.sleeper.02")


# @test-link [[rule_released_level_stable_with_migration]]
func test_a_gap_in_the_sleepers_numbers_fails_rule_20() -> void:
	var level := _base()
	_node(level, "s1.sleeper.02").stable_id = "s1.sleeper.03"
	_assert_fails(level, 20, "s1.sleeper.03")


# @test-link [[rule_objects_below_parent_zone]]
func test_a_switch_in_the_parent_zone_band_fails_rule_21() -> void:
	var level := _base()
	_node(level, "s1.switch").position = Vector2(2300, -420)
	var result := _assert_fails(level, 21, "s1.switch")
	assert_true(str(result["findings"]).contains("parent zone"), str(result["findings"]))


## Rule 21 on the base level's rails (chunk 23E): the rail point is at
## y -24 and the camera frames it 120 px under the middle of the view
## (Camera.RAIL_OFFSET), so at zoom 1 on the reference phone (648 px high)
## the screen's top is at y -468 and the band (7 mm, about 67 px) reaches
## y -401. The base switch is 200 x 100 px, centred on its position.
const RAIL_SCREEN_TOP := -468.0
const SWITCH_HALF_HEIGHT := 50.0


# @test-link [[rule_objects_below_parent_zone]]
func test_rule_21_holds_1_px_below_the_band_and_fails_1_px_inside_it() -> void:
	var band := TapDispatcher.parent_zone_height(ScreenView.new())
	var level := _base()
	_node(level, "s1.switch").position = Vector2(2300, RAIL_SCREEN_TOP + band + 1.0 + SWITCH_HALF_HEIGHT)
	assert_eq(_checker(level).check(21, true)["status"], LevelChecker.PASS, "1 px below the band")
	level = _base()
	_node(level, "s1.switch").position = Vector2(2300, RAIL_SCREEN_TOP + band - 1.0 + SWITCH_HALF_HEIGHT)
	_assert_fails(level, 21, "s1.switch")


# @test-link [[rule_objects_below_parent_zone]]
func test_a_gate_in_the_band_or_an_object_above_the_screen_fails_rule_21() -> void:
	var level := _base()
	var gate := Gate.new()
	gate.stable_id = "s1.gate"
	gate.position = Vector2(2450, -420)
	level.add_child(gate)
	_assert_fails(level, 21, "s1.gate")
	level = _base()
	_node(level, "s1.switch").position = Vector2(2300, -700)
	var result := _assert_fails(level, 21, "s1.switch")
	assert_true(str(result["findings"]).contains("parent zone"), "framed above the screen: not below the band")


# @test-link [[rule_objects_below_parent_zone]]
func test_a_framing_zone_s_framing_counts_for_rule_21() -> void:
	# The switch's top at y -330 is below the band on the plain rails. A zone
	# over it at zoom 0.5, shifted 400 px down, frames the view's top at
	# y -144 + 400 - 648 = -392 and the band (134 level px) down to y -258.
	var level := _base()
	_node(level, "s1.switch").position = Vector2(2300, -330 + SWITCH_HALF_HEIGHT)
	assert_eq(_checker(level).check(21, true)["status"], LevelChecker.PASS, "the plain rails")
	level = _base()
	_node(level, "s1.switch").position = Vector2(2300, -330 + SWITCH_HALF_HEIGHT)
	var zone := FramingZone.new()
	zone.stable_id = "s1.frame.switch"
	zone.position = Vector2(2300, -100)
	zone.size = Vector2(800, 400)
	zone.zoom = 0.5
	zone.offset = Vector2(0, 400)
	level.add_child(zone)
	_assert_fails(level, 21, "s1.switch")


# @test-link [[rule_objects_below_parent_zone]]
func test_rule_21_checks_the_switches_baskets_and_gates() -> void:
	var checker := _checker(_base())
	var ids := LevelRulesObjects.parent_zone_objects(checker.data).keys()
	ids.sort()
	assert_eq(ids, ["s1.basket", "s1.switch"], "not the signpost, not the sleepers")


# @test-link [[rule_return_route_joins_start_behind_train]]
func test_a_return_route_along_the_loops_first_stretch_fails_rule_22() -> void:
	var level := _base()
	_node(level, "s1.slide").curve = _curve([Vector2(2600, -24), Vector2(2600, 20), Vector2(200, 20),
			Vector2(200, -24)])
	_assert_fails(level, 22, "s1.slide")


# @test-link [[rule_no_called_ledge_over_loop]]
func test_a_called_ledge_over_the_loop_fails_rule_22_outside_the_split_zone() -> void:
	var level := _base()
	_terrain(level, "LowLedge", [Vector2(900, -110), Vector2(1000, -110), Vector2(1000, -90), Vector2(900, -90)])
	_sleeper(level, "s1.sleeper.03", "C", Vector2(950, -134))
	var result := _assert_fails(level, 22, "s1.sleeper.03")
	assert_true(str(result["findings"]).contains("LowLedge"), str(result["findings"]))
	# Inside the split zone's reach only base slimes pass under it: fine.
	var zone: SplitZone = _node(level, "start.split-zone")
	zone.position = Vector2(550, -40)
	zone.size = Vector2(1100, 120)
	assert_eq(_checker(level).check(22, true)["status"], LevelChecker.PASS)


# --- Output ----------------------------------------------------------------------

func test_the_text_and_json_forms() -> void:
	var level := _base()
	_sleeper(level, "s1.sleeper.03", "C", Vector2(1200, -30))
	var checker := _checker(level)
	var results := [checker.check_load()]
	results.append_array(checker.check_all(true))
	var text := LevelChecker.format(results)
	assert_true(text.contains("load     PASS    "), text)
	assert_true(text.contains("rule 17  FAIL    "), text)
	assert_true(text.contains("         - s1.sleeper.03 (x 1.04): "), text)
	var json := LevelChecker.to_json_data(results)
	var parsed = JSON.parse_string(JSON.stringify(json))
	assert_not_null(parsed, "valid JSON (no NAN)")
	assert_eq(parsed.size(), 23)
	assert_eq(LevelChecker.counts(results), {"PASS": 20, "FAIL": 1, "MANUAL": 0, "N/A": 1})


# --- The test level --------------------------------------------------------------

# @test-link [[rule_no_called_ledge_over_loop]]
func test_the_test_level_fails_no_rule_but_its_known_breaks() -> void:
	var level: Level = load(TEST_LEVEL).instantiate()
	add_child_autofree(level)
	var checker := LevelChecker.new(level)
	assert_eq(checker.check_load()["status"], LevelChecker.PASS)
	var results := checker.check_all(true)
	for result in results:
		if KNOWN_BREAKS.has(result["rule"]):
			assert_eq(result["findings"].map(func(one): return one["id"]), KNOWN_BREAKS[result["rule"]]["ids"],
					"rule %d still breaks as known: take it out of KNOWN_BREAKS once fixed" % result["rule"])
			pending("rule %d broken: %s" % [result["rule"], KNOWN_BREAKS[result["rule"]]["why"]])
		else:
			assert_ne(result["status"], LevelChecker.FAIL, "rule %d: %s" % [result["rule"], result["findings"]])
	assert_eq(_statuses(results), TEST_LEVEL_STATUSES)


# @test-link [[rule_gate_opens_via_switch_basket_set]]
func test_the_start_states_open_the_gates_as_after_their_baskets_fired() -> void:
	var level: Level = load(TEST_LEVEL).instantiate()
	add_child_autofree(level)
	var checker := LevelChecker.new(level)
	assert_eq(checker.gates_before(1), [])
	assert_eq(checker.gates_before(3), ["s1.gate", "s2.gate"], "from the return routes, in loop order")
	var sim := checker.start_state(3)
	assert_eq(sim.train.open_gates, ["s1.gate", "s2.gate"], "the loop grown into section 3")
	for n in [1, 2]:
		assert_eq(sim.object_states["s%d.switch" % n], {"flipped": true, "trapdoor_shut": true})
		assert_eq(sim.object_states["s%d.basket" % n]["phase"], FrontierSets.FIRED)
		assert_eq(sim.object_states["s%d.basket" % n]["since"], 0)
		assert_eq(sim.gate_states["s%d.gate" % n], {"open": true, "entrance_closed": true})
	assert_eq(sim.object_states["s3.basket"]["phase"], FrontierSets.FILLING, "the frontier's set untouched")
	assert_false(sim.object_states["s3.switch"]["flipped"])


# @test-link [[rule_loop_travelable_with_no_input]]
func test_a_lone_slime_laps_the_test_levels_first_loop() -> void:
	# Rule 1's behaviour run, with the loop at section 1 (about 3 minutes of
	# play; rules 1 and 2 run it in every gate state and for every size).
	var level: Level = load(TEST_LEVEL).instantiate()
	add_child_autofree(level)
	var laps := LevelChecker.new(level).lap_ticks(1, [1])
	gut.p("section 1: a size-1 slime lapped %.1f screens in %.0f s (limit %.0f s)" % [laps["length"] / LevelData.SCREEN,
			laps["ticks"][1] / float(Simulation.TICK_RATE), laps["limit"] / float(Simulation.TICK_RATE)])
	assert_eq(laps["stalled"], [] as Array[Dictionary], "no safety net needed (stalled or stuck)")
	assert_gt(laps["ticks"][1], 0, "it lapped the loop")


# --- The command line ------------------------------------------------------------

func _run_cli(arguments: Array) -> Dictionary:
	var output := []
	var command := ["--headless", "--path", ProjectSettings.globalize_path("res://"), "-s",
			"res://tools/check_level.gd", "--"]
	command.append_array(arguments)
	var code := OS.execute(OS.get_executable_path(), command, output, true)
	return {"code": code, "text": "\n".join(output)}


func test_the_command_line_checks_the_test_level() -> void:
	var run := _run_cli(["--level=test", "--fast"])
	# 1 while the test level has a known break (KNOWN_BREAKS), 0 once none.
	assert_eq(run["code"], 1 if not KNOWN_BREAKS.is_empty() else 0, run["text"])
	var rule_lines := 0
	for line in run["text"].split("\n"):
		if RegEx.create_from_string("^rule \\d+ +(PASS|FAIL|MANUAL|N/A) ").search(line) != null:
			rule_lines += 1
	assert_eq(rule_lines, 22, run["text"])
	assert_true(run["text"].contains("check_level: level test (version 2): 3 sections, 200 base slimes"), run["text"])
	assert_true(run["text"].contains("load     PASS    The level loads"), run["text"])
	assert_true(run["text"].contains("rule 1   PASS    "), run["text"])
	assert_true(run["text"].contains("(fast: behaviour skipped)"), run["text"])


func test_the_command_line_refuses_an_unknown_level() -> void:
	var run := _run_cli(["--level=no-such-level"])
	assert_eq(run["code"], 2, run["text"])
	assert_true(run["text"].contains("no level 'no-such-level'"), run["text"])
