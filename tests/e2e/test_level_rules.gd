extends GutTest
## Chunk 16: the level rules (specs/level-design.md, numbered as there)
## checked on the built test level as a whole, sections 1 to 3, where the
## rule is about the level's layout rather than a behaviour: species per
## section [rule 11] and what it gives the level [v1 scope], the hints seen
## from the loop [rule 9], the loop closed by a slide in every gate state [rule
## 3], the fusion dips [rule 5]. The checks themselves are the level-rules
## checker's (LevelChecker, chunk LD1); this file holds what the test level's
## design fixes (S2 adds D, 6 branches, the bowl's zoom, the designed dips).
## The other layout rules are checked in test_test_level.gd and
## test_frontier_level.gd; the ways back from every sleeper's spot in
## test_level_ways_back_e2e.gd.
##
## Distances are in level pixels; 1 screen is LevelData.SCREEN px.

# @test-link [[req_level_design_rules]]

const LEVEL_SCENE := "res://levels/test/level.tscn"
const SCREEN := LevelData.SCREEN
## The fusion dips of specs/levels/test/README.md (1.3 and 2.3): [first
## screen, last screen], and how much lower than both rims the loop's lowest
## point in between must be, px, for train slimes to bunch there.
const DIPS := [[2.5, 3.5], [10.0, 10.5]]
const DIP_DEPTH := 80.0
## Known breaks of rule 9 in the built level, reported rather than hidden:
## branch ID -> why. Each is checked to still break the rule (so a fixed one
## can't linger here) and marked pending instead of failing. None since
## chunk 16d, which added `s2.frame.cave` for the cave's pocket (y -724).
const KNOWN_HINTLESS := {}

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


# --- Rule 11: species per section ---------------------------------------------

# @test-link [[rule_first_section_species_count]]
func test_the_first_section_has_3_species_and_each_later_one_adds_one() -> void:
	var by_section := checker.species_by_section()
	assert_eq(by_section.keys().size(), checker.sections().size(), "every section has its slimes")
	assert_eq(by_section[1], ["A", "B", "C"], "S1: A, B, C")
	var seen: Array = by_section[1].duplicate()
	for section in checker.sections():
		if section == 1:
			continue
		var new_ones: Array = by_section[section].filter(func(letter): return not letter in seen)
		assert_eq(new_ones.size(), 1, "section %d adds exactly one species" % section)
		seen.append_array(new_ones)
	assert_eq(by_section[2], ["A", "B", "C", "D"], "S2 adds D")
	assert_eq(by_section[3], ["A", "B", "C", "D", "E"], "S3 adds E")
	assert_eq(checker.check(11)["findings"], [], "the checker's rule 11")


# @test-link [[req_scope_one_level_four_sections]]
# @test-link [[rule_first_section_species_count]]
func test_the_level_has_3_species_plus_one_per_later_section() -> void:
	# v1's level: 4 sections, 6 species. The test level is deliberately
	# smaller (README, "What this level does not settle"): 3 sections, so 5.
	var species := []
	for letters in checker.species_by_section().values():
		for letter in letters:
			if not letter in species:
				species.append(letter)
	assert_eq(Array(checker.sections()), [1, 2, 3])
	assert_eq(species.size(), 3 + checker.sections().size() - 1)
	assert_lte(species.size(), Species.COUNT, "every one a species the game has")


# --- Rule 9: hints visible from the loop ---------------------------------------

# @test-link [[rule_hints_visible_from_loop]]
# @test-link [[rule_framing_zone_wherever_wider_view_needed]]
func test_every_branch_shows_a_hint_from_the_loop() -> void:
	assert_eq(data.branches.size(), 6)
	var hintless := []
	for branch_id: String in data.branches:
		var seen := LevelChecker.any_seen(checker.hints_of(branch_id),
				checker.rail_views(LevelChecker.section_of(branch_id)))
		if not seen:
			hintless.append(branch_id)
		if KNOWN_HINTLESS.has(branch_id):
			assert_false(seen, "%s now shows a hint: take it out of KNOWN_HINTLESS" % branch_id)
		else:
			assert_true(seen, "%s: none of its sleepers peeks into a rail view of its section" % branch_id)
	for branch_id in KNOWN_HINTLESS:
		if branch_id in hintless:
			pending("rule 9 broken, %s: %s" % [branch_id, KNOWN_HINTLESS[branch_id]])


func test_the_rail_views_follow_the_framing_zones() -> void:
	# The views the hint test uses: normal zoom on the rails, wider in a
	# framing zone (the tree's, the bowl's).
	var views := checker.rail_views(1)
	assert_gt(views.size(), 100, "section 1's outgoing route, every %d px" % LevelChecker.RAIL_SAMPLE)
	assert_almost_eq(views[0].size.x, ScreenView.DEFAULT_SIZE.x, 0.01, "the start: normal zoom")
	var widest := 0.0
	for view in checker.rail_views(3):
		widest = maxf(widest, view.size.x)
	assert_almost_eq(widest, ScreenView.DEFAULT_SIZE.x / 0.5, 0.01, "the bowl's zone: zoom 0.5")


# --- Rule 3: no dead ends: the loop closes in every gate state -------------------

# @test-link [[rule_no_dead_ends]]
# @test-link [[rule_return_route_per_section]]
func test_in_every_gate_state_a_slide_takes_the_frontier_back_to_the_start() -> void:
	for section in checker.sections():
		var current := data.loop.current_segments(checker.gates_before(section))
		var last: Dictionary = current[current.size() - 1]
		assert_eq(last["id"], "s%d.slide" % section, "section %d: its slide closes the loop" % section)
		# Its own return route, from the frontier to the start, every segment
		# joining the next.
		assert_eq(checker.loop_closes(section), [], "section %d: the loop closes" % section)
		var points: PackedVector2Array = last["points"]
		assert_lt(points[points.size() - 1].x, SCREEN, "in the start basin")
		assert_gt(points[points.size() - 1].y, points[0].y, "it ends lower than it starts: a slide")


# --- Rule 5: the fusion dips -----------------------------------------------------

# @test-link [[rule_dip_may_nudge_fusion]]
func test_the_fusion_dips_are_low_points_of_the_loop() -> void:
	var gates := checker.gates_before(3)
	var dips := checker.dips(gates, DIP_DEPTH)
	for dip in DIPS:
		var left := data.loop.closest(Vector2(dip[0] * SCREEN, 0.0), gates)
		var right := data.loop.closest(Vector2(dip[1] * SCREEN, 0.0), gates)
		assert_lt(left["distance"], right["distance"], "the loop runs through the dip left to right")
		var found := dips.filter(func(one): return one["x"] >= dip[0] * SCREEN and one["x"] <= dip[1] * SCREEN)
		assert_eq(found.size(), 1, "the dip at %s to %s screens: %s" % [dip[0], dip[1], dips])
		if found.size() == 1:
			assert_gt(found[0]["depth"], DIP_DEPTH, "the dip at %s to %s screens" % [dip[0], dip[1]])
