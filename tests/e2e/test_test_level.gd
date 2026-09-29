extends GutTest
## Chunk 4, "Done when": the test level (levels/test/level.tscn) loads
## headless, and a test finds the loop, the routes back and every stable ID of
## section 1 (Meadow), section 2 (Caves, chunk 15) and section 3 (Big bowl,
## chunk 16), and checks the level rules its layout must meet
## (specs/levels/test/README.md, specs/level-design.md).
##
## Distances are in level pixels; 1 screen is LevelData.SCREEN px.

# @test-link [[req_test_level_and_test_mode]]
# @test-link [[req_level_design_rules]]

const LEVEL_SCENE := "res://levels/test/level.tscn"
const SCREEN := LevelData.SCREEN
## A sleeper this close to the loop's route would sit on the loop: two
## size-1 slime radii.
const OFF_LOOP_MIN_GAP := 2.0 * PlaceholderArt.SLIME_RADIUS
## A route back ends on the loop when its last point is this close to it.
const ON_LOOP_MAX_GAP := 32.0

var level: Level


func before_all() -> void:
	level = load(LEVEL_SCENE).instantiate()
	add_child(level)


func after_all() -> void:
	level.free()


func _expected_section_1_ids() -> PackedStringArray:
	var ids := PackedStringArray([
		"start.loop", "s1.loop", "s1.slide",
		"start.split-zone", "start.first-slime",
		"s1.switch", "s1.basket", "s1.gate", "s1.signpost",
		"s1.branch.tree", "s1.route-back.tree", "s1.frame.tree",
		"s1.branch.high-step", "s1.route-back.high-step", "s1.frame.high-step",
	])
	for n in range(1, 30):
		ids.append("s1.sleeper.%02d" % n)
	ids.sort()
	return ids


## Section 2 (Caves, chunk 15).
func _expected_section_2_ids() -> PackedStringArray:
	var ids := PackedStringArray([
		"s2.loop", "s2.slide",
		"s2.switch", "s2.basket", "s2.gate", "s2.signpost",
		"s2.branch.cave", "s2.route-back.cave",
		"s2.frame.parade", "s2.frame.gate",
	])
	for n in range(1, 41):
		ids.append("s2.sleeper.%02d" % n)
	return ids


## Section 3 (Big bowl, chunk 16): where gate 2 leads; frontier set 3 has no
## gate. Sleeper numbers run to three digits.
func _expected_section_3_ids() -> PackedStringArray:
	var ids := PackedStringArray([
		"s3.loop", "s3.slide",
		"s3.switch", "s3.basket", "s3.signpost",
		"s3.branch.left-shelves", "s3.route-back.left-shelves",
		"s3.branch.right-shelves", "s3.route-back.right-shelves",
		"s3.branch.rim", "s3.route-back.rim",
		"s3.frame.bowl", "s3.frame.basket",
	])
	for n in range(1, 131):
		ids.append("s3.sleeper.%02d" % n)
	return ids


func _sleepers_of(section: String) -> Array:
	return _of_type(Sleeper).filter(func(sleeper): return sleeper.stable_id.begins_with(section + "."))


## The gates open once the loop reaches `section` (1, 2, ...): the gates of
## the sections before it.
func _gates_before(section: int) -> Array:
	var gates := []
	for n in range(1, section):
		gates.append("s%d.gate" % n)
	return gates


func _of_type(type: Variant) -> Array:
	var found := []
	for id in level.ids():
		if is_instance_of(level.find(id), type):
			found.append(level.find(id))
	return found


func _species_counts(slimes: Array) -> Dictionary:
	var counts := {}
	for slime in slimes:
		counts[slime.species] = counts.get(slime.species, 0) + 1
	return counts


# --- Loading, level id and version ------------------------------------------

func test_the_level_loads_without_errors() -> void:
	assert_eq(level.load_errors, PackedStringArray())


# @test-link [[rule_released_level_stable_with_migration]]
func test_level_id_and_version_are_read() -> void:
	assert_eq(level.level_id, "test")
	assert_eq(level.data.level_id, "test")
	assert_gte(level.level_version, 1)
	assert_eq(level.data.level_version, level.level_version)


func test_every_stable_id_of_sections_1_to_3_is_found() -> void:
	var expected := _expected_section_1_ids()
	expected.append_array(_expected_section_2_ids())
	expected.append_array(_expected_section_3_ids())
	expected.sort()
	assert_eq(level.ids(), expected)


func test_ids_are_well_formed() -> void:
	for id in level.ids():
		assert_true(StableId.is_valid(id), id)


# --- Population --------------------------------------------------------------

func test_section_1_has_29_sleepers_by_species() -> void:
	var sleepers := _sleepers_of("s1")
	assert_eq(sleepers.size(), 29)
	assert_eq(_species_counts(sleepers), {"A": 9, "B": 9, "C": 11})
	for sleeper in sleepers:
		assert_eq(sleeper.size, 1, sleeper.stable_id)


func test_section_1_population_with_the_first_slime() -> void:
	# README population table: S1 is A 10, B 9, C 11. The first slime (A) is
	# awake from the start; the first sleeper is B.
	var first_slime: FirstSlime = level.find("start.first-slime")
	assert_eq(first_slime.species, "A")
	assert_eq(level.find("s1.sleeper.01").species, "B")
	var slimes := _sleepers_of("s1")
	slimes.append(first_slime)
	assert_eq(_species_counts(slimes), {"A": 10, "B": 9, "C": 11})


func test_section_2_has_40_sleepers_by_species() -> void:
	# README population table: S2 is A 7, B 7, C 7, D 19; D is new here.
	var sleepers := _sleepers_of("s2")
	assert_eq(sleepers.size(), 40)
	assert_eq(_species_counts(sleepers), {"A": 7, "B": 7, "C": 7, "D": 19})
	for sleeper in sleepers:
		assert_eq(sleeper.size, 1, sleeper.stable_id)
		var x: float = level.position_of(sleeper).x / SCREEN
		assert_between(x, 8.0, 12.66, "%s is in section 2" % sleeper.stable_id)


func test_section_3_has_130_sleepers_by_species() -> void:
	# README population table, section 3's areas: the ramp 10 E, the shelves
	# A, B, C, D 15 each and E 30, the rim A, B, C, D 5 each and E 10; E is
	# new here.
	var sleepers := _sleepers_of("s3")
	assert_eq(sleepers.size(), 130)
	assert_eq(_species_counts(sleepers), {"A": 20, "B": 20, "C": 20, "D": 20, "E": 50})
	for sleeper in sleepers:
		assert_eq(sleeper.size, 1, sleeper.stable_id)
		var x: float = level.position_of(sleeper).x / SCREEN
		assert_between(x, 12.66, 16.5, "%s is in section 3" % sleeper.stable_id)


func test_the_level_has_200_base_slimes() -> void:
	# README population table, the level: A 37, B 36, C 38, D 39, E 50.
	var slimes := _of_type(Sleeper)
	slimes.append(level.find("start.first-slime"))
	assert_eq(slimes.size(), 200)
	assert_eq(_species_counts(slimes), {"A": 37, "B": 36, "C": 38, "D": 39, "E": 50})
	assert_eq(level.data.sleepers.size(), 199, "the first slime and 199 sleepers")


func test_sleepers_are_numbered_left_to_right() -> void:
	for section in [["s1", 29], ["s2", 40], ["s3", 130]]:
		for n in range(1, section[1]):
			var here: Vector2 = level.position_of(level.find("%s.sleeper.%02d" % [section[0], n]))
			var next: Vector2 = level.position_of(level.find("%s.sleeper.%02d" % [section[0], n + 1]))
			assert_lte(here.x, next.x, "%s.sleeper.%02d" % [section[0], n])


# @test-link [[rule_sleepers_never_on_loop]]
func test_no_sleeper_sits_on_the_loop() -> void:
	for sleeper in _of_type(Sleeper):
		var gap: float = level.data.loop.gap(level.position_of(sleeper))
		assert_gt(gap, OFF_LOOP_MIN_GAP, sleeper.stable_id)


# @test-link [[rule_first_sleeper_near_first_awake_slime]]
func test_the_first_sleeper_is_near_the_first_slime() -> void:
	var first_slime_at: Vector2 = level.position_of(level.find("start.first-slime"))
	var first_sleeper_at: Vector2 = level.position_of(level.find("s1.sleeper.01"))
	assert_lte(first_slime_at.distance_to(first_sleeper_at), SCREEN / 3.0)
	for sleeper in _of_type(Sleeper):
		assert_gte(first_slime_at.distance_to(level.position_of(sleeper)),
				first_slime_at.distance_to(first_sleeper_at), "no sleeper is nearer than the first one")


# --- The loop ----------------------------------------------------------------

func test_the_loop_is_found_with_a_positive_length() -> void:
	var loop: LoopData = level.data.loop
	assert_not_null(loop)
	assert_eq(loop.validate(), PackedStringArray())
	assert_gt(loop.length(), 8.0 * SCREEN, "out along section 1 and back by the slide")
	assert_eq(level.find("start.loop"), level.loop)


# @test-link [[rule_return_route_per_section]]
func test_section_1_loop_is_its_outgoing_route_then_the_slide() -> void:
	var loop: LoopData = level.data.loop
	var ids := PackedStringArray()
	for segment in loop.current_segments():
		ids.append(segment["id"])
	assert_eq(ids, PackedStringArray(["s1.loop", "s1.slide"]))
	var slide := loop.segment("s1.slide")
	assert_eq(slide["kind"], LoopData.RETURN)
	assert_eq(slide["section"], 1)
	assert_eq(slide["gate"], "s1.gate", "in use while gate 1 is closed")
	var returns := 0
	for segment in loop.segments:
		if segment["section"] == 1 and segment["kind"] == LoopData.RETURN:
			returns += 1
	assert_eq(returns, 1, "one return route for section 1")


# @test-link [[rule_return_route_per_section]]
func test_the_slide_runs_from_the_frontier_back_to_the_start() -> void:
	var loop: LoopData = level.data.loop
	var frontier := loop.frontier()
	var slide := loop.segment("s1.slide")
	var points: PackedVector2Array = slide["points"]
	assert_lt(points[0].distance_to(frontier["position"]), 1.0, "starts where the loop ends")
	assert_lt(points[points.size() - 1].distance_to(loop.position_at(0.0)), 1.0, "comes out at the start")
	assert_gt(points[points.size() - 1].y, points[0].y, "a slide: it ends lower than it starts")
	assert_lt(points[points.size() - 1].x, SCREEN, "comes out in the start basin (screen 0 to 1)")


func test_the_frontier_is_at_gate_1() -> void:
	var frontier := level.data.loop.frontier()
	assert_eq(frontier["gate"], "s1.gate")
	assert_eq(frontier["section"], 1)
	var gate_at: Vector2 = level.position_of(level.find("s1.gate"))
	var frontier_at: Vector2 = frontier["position"]
	assert_between(frontier_at.x, 7.4 * SCREEN, 7.8 * SCREEN, "the slide entrance, about 7.6")
	assert_lt(frontier_at.x, gate_at.x, "the loop ends just before the gate")
	assert_lt(gate_at.x - frontier_at.x, 0.5 * SCREEN)


# @test-link [[rule_start_carries_split_zone]]
func test_the_split_zone_sits_at_the_start_of_the_loop() -> void:
	var split_zone: SplitZone = level.find("start.split-zone")
	var start: Vector2 = level.data.loop.position_at(0.0)
	assert_true(split_zone.contains(start - level.position_of(split_zone)), "the loop starts inside the split zone")
	assert_lt(start.x, SCREEN, "in the start basin")


func test_the_first_slime_starts_in_the_basin_on_the_loop() -> void:
	var at: Vector2 = level.position_of(level.find("start.first-slime"))
	assert_lt(at.x, SCREEN)
	assert_lt(level.data.loop.gap(at), ON_LOOP_MAX_GAP)


# --- Exploration branches and routes back -------------------------------------

func test_the_tree_route_back_is_found() -> void:
	var route_back: RouteBack = level.find("s1.route-back.tree")
	assert_not_null(route_back)
	assert_eq(route_back.serves, "s1.branch.tree")
	assert_true(level.data.route_backs.has("s1.route-back.tree"))
	assert_eq(level.data.route_backs["s1.route-back.tree"]["serves"], "s1.branch.tree")


# @test-link [[rule_exploration_branch_has_route_back]]
func test_the_branches_and_their_routes_back_are_plain_data() -> void:
	assert_eq(level.data.branches.keys().size(), 6)
	assert_eq(level.data.route_back_for("s1.branch.tree"), "s1.route-back.tree")
	assert_eq(level.data.route_back_for("s1.branch.high-step"), "s1.route-back.high-step")
	assert_eq(level.data.route_back_for("s2.branch.cave"), "s2.route-back.cave")
	for name in ["left-shelves", "right-shelves", "rim"]:
		assert_eq(level.data.route_back_for("s3.branch." + name), "s3.route-back." + name)
	var platform := Vector2(5.2 * LevelData.SCREEN, -384)
	assert_eq(level.data.branch_at(platform), "s1.branch.tree", "the tree's platform is in its branch")
	var pocket := Vector2(11.3 * LevelData.SCREEN, -724)
	assert_eq(level.data.branch_at(pocket), "s2.branch.cave", "the cave's pocket is in its branch")


# @test-link [[req_controls_tap_zones]]
func test_the_switch_basket_and_sleepers_are_tap_targets() -> void:
	var targets: Dictionary = level.data.tap_targets
	assert_eq(targets["s1.switch"]["kind"], TapDispatcher.KIND_SWITCH)
	assert_eq(targets["s1.basket"]["kind"], TapDispatcher.KIND_BASKET)
	assert_eq(targets["s2.switch"]["kind"], TapDispatcher.KIND_SWITCH)
	assert_eq(targets["s2.basket"]["kind"], TapDispatcher.KIND_BASKET)
	assert_eq(targets["s3.switch"]["kind"], TapDispatcher.KIND_SWITCH)
	assert_eq(targets["s3.basket"]["kind"], TapDispatcher.KIND_BASKET)
	var sleepers := 0
	for id in targets:
		if targets[id]["kind"] == TapDispatcher.KIND_SLEEPER:
			sleepers += 1
	assert_eq(sleepers, _of_type(Sleeper).size(), "every sleeper")
	assert_eq(targets.size(), sleepers + 6, "nothing else (gates, split zones, signposts are not tapped)")


# @test-link [[rule_exploration_branch_has_route_back]]
func test_every_exploration_branch_has_a_route_back() -> void:
	var branches := _of_type(ExplorationBranch)
	assert_eq(branches.size(), 6)
	for branch in branches:
		var served := 0
		for route_back in _of_type(RouteBack):
			if route_back.serves == branch.stable_id:
				served += 1
				var points: PackedVector2Array = level.data.route_backs[route_back.stable_id]["points"]
				assert_true(branch.contains(points[0] - level.position_of(branch)),
						"%s starts in %s" % [route_back.stable_id, branch.stable_id])
		assert_gt(served, 0, branch.stable_id)


# @test-link [[rule_no_dead_ends]]
# @test-link [[rule_exploration_branch_has_route_back]]
func test_every_route_back_ends_on_the_loop() -> void:
	assert_eq(level.data.route_backs.size(), 6)
	for id in level.data.route_backs:
		var points: PackedVector2Array = level.data.route_backs[id]["points"]
		# The loop in use once the loop reaches the route's section.
		var section := str(id).get_slice(".", 0)
		var gates := _gates_before(section.trim_prefix("s").to_int())
		var closest: Dictionary = level.data.loop.closest(points[points.size() - 1], gates)
		assert_lt(closest["gap"], ON_LOOP_MAX_GAP, id)
		assert_eq(closest["segment"], section + ".loop", "%s lands on the loop in use" % id)


# @test-link [[rule_gravity_leads_back_to_loop]]
func test_routes_back_only_go_down() -> void:
	# Gravity leads back: a route back never climbs (y grows downward).
	for id in level.data.route_backs:
		var points: PackedVector2Array = level.data.route_backs[id]["points"]
		for i in range(1, points.size()):
			assert_gte(points[i].y, points[i - 1].y - 0.5, "%s point %d" % [id, i])


# --- Frontier set 1, framing zones, rules ------------------------------------

func test_frontier_set_1_is_placed_as_in_the_readme() -> void:
	var expected := {"s1.switch": 6.5, "s1.basket": 7.0, "s1.gate": 7.8, "s1.signpost": 6.5}
	for id in expected:
		var x: float = level.position_of(level.find(id)).x / SCREEN
		assert_almost_eq(x, expected[id], 0.25, id)
	assert_eq(level.find("s1.basket").quota, 6)
	assert_eq(level.find("s1.switch").basket_id, "s1.basket")
	assert_eq(level.find("s1.signpost").switch_id, "s1.switch")


func test_basket_1_rule_validates_against_the_registry() -> void:
	var rules: Array = level.find("s1.basket").rules()
	assert_eq(rules.size(), 1)
	assert_eq(rules[0].to_dict(), {"when": {"object": "s1.basket", "event": "full"},
			"then": {"object": "s1.gate", "action": "open"}})
	assert_eq(rules[0].validate(level.registry), PackedStringArray())
	assert_eq(level.all_rules().size(), 2, "basket 1's and basket 2's (basket 3 has none)")


func test_frontier_set_2_is_placed_as_in_the_readme() -> void:
	# README 2.5: the basket is 1.5 screens from its switch, past the cave.
	var expected := {"s2.switch": 11.0, "s2.basket": 12.4, "s2.gate": 12.8, "s2.signpost": 10.9}
	for id in expected:
		var x: float = level.position_of(level.find(id)).x / SCREEN
		assert_almost_eq(x, expected[id], 0.1, id)
	var switch_x: float = level.position_of(level.find("s2.switch")).x / SCREEN
	var basket_x: float = level.position_of(level.find("s2.basket")).x / SCREEN
	assert_between(basket_x - switch_x, 1.3, 1.6, "about 1.5 screens apart")
	assert_eq(level.find("s2.basket").quota, 15)
	assert_eq(level.find("s2.switch").basket_id, "s2.basket")
	assert_eq(level.find("s2.signpost").switch_id, "s2.switch")
	var rules: Array = level.find("s2.basket").rules()
	assert_eq(rules.size(), 1)
	assert_eq(rules[0].to_dict(), {"when": {"object": "s2.basket", "event": "full"},
			"then": {"object": "s2.gate", "action": "open"}})
	assert_eq(rules[0].validate(level.registry), PackedStringArray())


func test_frontier_set_3_is_placed_as_in_the_readme() -> void:
	# README 3.4: the last set, a switch and a basket; no gate, no rule (filling
	# the basket completes the level).
	var expected := {"s3.switch": 15.67, "s3.basket": 16.01, "s3.signpost": 15.62}
	for id in expected:
		var x: float = level.position_of(level.find(id)).x / SCREEN
		assert_almost_eq(x, expected[id], 0.01, id)
	assert_eq(level.find("s3.basket").quota, 60)
	assert_eq(level.find("s3.switch").basket_id, "s3.basket")
	assert_eq(level.find("s3.signpost").switch_id, "s3.switch")
	assert_eq(level.find("s3.basket").rules().size(), 0, "no rule")
	assert_null(level.find("s3.gate"), "no gate")
	assert_false(level.data.gates.has("s3.gate"))


func test_framing_zones() -> void:
	var tree: FramingZone = level.find("s1.frame.tree")
	assert_lt(tree.zoom, 1.0, "zooms out")
	assert_lt(tree.offset.y, 0.0, "shifts up")
	assert_almost_eq(level.position_of(tree).x / SCREEN, 5.0, 0.25)
	var high_step: FramingZone = level.find("s1.frame.high-step")
	assert_almost_eq(level.position_of(high_step).x / SCREEN, 4.0, 0.25)
	assert_lte(high_step.zoom, 1.0)
	var parade: FramingZone = level.find("s2.frame.parade")
	assert_almost_eq(level.position_of(parade).x / SCREEN, 9.5, 0.25)
	assert_lt(parade.zoom, 1.0, "zooms out over the parade")
	var gate_2: FramingZone = level.find("s2.frame.gate")
	assert_almost_eq(level.position_of(gate_2).x / SCREEN, 12.6, 0.25)
	assert_lt(gate_2.zoom, 1.0, "the basket and the gate both in view")
	var bowl: FramingZone = level.find("s3.frame.bowl")
	assert_almost_eq(level.position_of(bowl).x / SCREEN, 14.375, 0.25)
	assert_eq(bowl.zoom, 0.5, "the whole bowl in view")
	var basket_3: FramingZone = level.find("s3.frame.basket")
	assert_almost_eq(level.position_of(basket_3).x / SCREEN, 15.875, 0.25)
	assert_lt(basket_3.zoom, 1.0, "the switch and the basket both in view")


# --- Terrain -----------------------------------------------------------------

func test_terrain_bakes_into_collision_and_visuals() -> void:
	var pieces := []
	for node in level.find_children("*", "", true, false):
		if node is Terrain:
			pieces.append(node)
	assert_gt(pieces.size(), 3)
	for piece in pieces:
		assert_gt(piece.baked_polygon.size(), 3, piece.name)
		assert_false(Geometry2D.triangulate_polygon(piece.baked_polygon).is_empty(),
				"%s is a simple polygon" % piece.name)
		assert_eq(piece.fill.polygon, piece.baked_polygon, piece.name)
		assert_true(piece.outline.closed, piece.name)
		if piece.has_collision:
			assert_eq(piece.collision_polygon.polygon, piece.baked_polygon, piece.name)
		else:
			assert_null(piece.collision_polygon, piece.name)
