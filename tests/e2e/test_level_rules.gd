extends GutTest
## Chunk 16: the level rules (specs/level-design.md, numbered as there)
## checked on the built test level as a whole, sections 1 to 3, where the
## rule is about the level's layout rather than a behaviour: species per
## section [rule 11] and what it gives the level [v1 scope], the hints seen
## from the loop [rule 9], the loop closed by a slide in every gate state [rule
## 3], the fusion dips [rule 5]. The other layout rules are checked in
## test_test_level.gd and test_frontier_level.gd; the ways back from every
## sleeper's spot in test_level_ways_back_e2e.gd.
##
## Distances are in level pixels; 1 screen is LevelData.SCREEN px.

# @test-link [[req_level_design_rules]]

const LEVEL_SCENE := "res://levels/test/level.tscn"
const SCREEN := LevelData.SCREEN
## A sleeper peeks into the view when any of its drawn body does: its centre
## is within the view grown by its radius.
const BODY_RADIUS := PlaceholderArt.SLIME_RADIUS
## The rail views are sampled this often along a section's outgoing route, px.
const RAIL_SAMPLE := 32.0
## The fusion dips of specs/levels/test/README.md (1.3 and 2.3): [first
## screen, last screen], and how much lower than both ends the loop's lowest
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


func before_all() -> void:
	level = load(LEVEL_SCENE).instantiate()
	add_child(level)
	data = level.data


func after_all() -> void:
	level.free()


## The section number of a stable ID ("s2.sleeper.07" -> 2; "start.*" -> 1).
static func _section_of(id: String) -> int:
	var place := id.get_slice(".", 0)
	return 1 if place == "start" else place.trim_prefix("s").to_int()


## The gates open once the loop reaches `section`: those of the sections
## before it.
static func _gates_before(section: int) -> Array:
	var gates := []
	for n in range(1, section):
		gates.append("s%d.gate" % n)
	return gates


## The section numbers of the loop, ascending.
func _sections() -> Array:
	var found := []
	for segment in data.loop.segments:
		if not segment["section"] in found:
			found.append(segment["section"])
	found.sort()
	return found


## Section number -> the species letters of the slimes placed in it (its
## sleepers; the first slime counts in section 1).
func _species_by_section() -> Dictionary:
	var by_section := {}
	var placed := {data.first_slime["id"]: data.first_slime["species"]}
	for id in data.sleepers:
		placed[id] = data.sleepers[id]["species"]
	for id in placed:
		var section := _section_of(id)
		if not by_section.has(section):
			by_section[section] = []
		if not placed[id] in by_section[section]:
			by_section[section].append(placed[id])
	for section in by_section:
		by_section[section].sort()
	return by_section


## The views the settled camera shows from the rails along section
## `section`'s outgoing route, with the gates before it open (Camera.start
## frames a rail point exactly as the camera settles there).
func _rail_views(section: int) -> Array[Rect2]:
	var gates := _gates_before(section)
	var camera := Camera.new()
	camera.zones = data.framing_zones
	var views: Array[Rect2] = []
	var before := 0.0
	for segment in data.loop.current_segments(gates):
		if segment["id"] == "s%d.loop" % section:
			var along := 0.0
			while along <= segment["length"]:
				camera.start(data.loop, gates, data.loop.position_at(before + along, gates))
				var size := ScreenView.DEFAULT_SIZE / camera.zoom
				views.append(Rect2(camera.view_centre(ScreenView.DEFAULT_SIZE) - size * 0.5, size))
				along += RAIL_SAMPLE
		before += segment["length"]
	return views


## What hints at branch `branch_id` from the loop: its sleepers; a branch
## with none (the high step: nothing lives up there) shows its top, where
## its route back starts.
func _hints_of(branch_id: String) -> Array[Vector2]:
	var hints: Array[Vector2] = []
	for id in data.sleepers:
		if data.branch_at(data.sleepers[id]["position"]) == branch_id:
			hints.append(data.sleepers[id]["position"])
	if hints.is_empty():
		var points: PackedVector2Array = data.route_backs[data.route_back_for(branch_id)]["points"]
		hints.append(points[0])
	return hints


## Whether any of `hints` peeks into any of `views`.
static func _any_seen(hints: Array[Vector2], views: Array[Rect2]) -> bool:
	for view in views:
		for hint in hints:
			if view.grow(BODY_RADIUS).has_point(hint):
				return true
	return false


# --- Rule 11: species per section ---------------------------------------------

# @test-link [[rule_first_section_species_count]]
func test_the_first_section_has_3_species_and_each_later_one_adds_one() -> void:
	var by_section := _species_by_section()
	assert_eq(by_section.keys().size(), _sections().size(), "every section has its slimes")
	assert_eq(by_section[1], ["A", "B", "C"], "S1: A, B, C")
	var seen: Array = by_section[1].duplicate()
	for section in _sections():
		if section == 1:
			continue
		var new_ones: Array = by_section[section].filter(func(letter): return not letter in seen)
		assert_eq(new_ones.size(), 1, "section %d adds exactly one species" % section)
		seen.append_array(new_ones)
	assert_eq(by_section[2], ["A", "B", "C", "D"], "S2 adds D")
	assert_eq(by_section[3], ["A", "B", "C", "D", "E"], "S3 adds E")


# @test-link [[req_scope_one_level_four_sections]]
# @test-link [[rule_first_section_species_count]]
func test_the_level_has_3_species_plus_one_per_later_section() -> void:
	# v1's level: 4 sections, 6 species. The test level is deliberately
	# smaller (README, "What this level does not settle"): 3 sections, so 5.
	var species := []
	for letters in _species_by_section().values():
		for letter in letters:
			if not letter in species:
				species.append(letter)
	assert_eq(_sections(), [1, 2, 3])
	assert_eq(species.size(), 3 + _sections().size() - 1)
	assert_lte(species.size(), Species.COUNT, "every one a species the game has")


# --- Rule 9: hints visible from the loop ---------------------------------------

# @test-link [[rule_hints_visible_from_loop]]
# @test-link [[rule_framing_zone_wherever_wider_view_needed]]
func test_every_branch_shows_a_hint_from_the_loop() -> void:
	assert_eq(data.branches.size(), 6)
	var hintless := []
	for branch_id: String in data.branches:
		var seen := _any_seen(_hints_of(branch_id), _rail_views(_section_of(branch_id)))
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
	var views := _rail_views(1)
	assert_gt(views.size(), 100, "section 1's outgoing route, every %d px" % RAIL_SAMPLE)
	assert_almost_eq(views[0].size.x, ScreenView.DEFAULT_SIZE.x, 0.01, "the start: normal zoom")
	var widest := 0.0
	for view in _rail_views(3):
		widest = maxf(widest, view.size.x)
	assert_almost_eq(widest, ScreenView.DEFAULT_SIZE.x / 0.5, 0.01, "the bowl's zone: zoom 0.5")


# --- Rule 3: no dead ends: the loop closes in every gate state -------------------

# @test-link [[rule_no_dead_ends]]
# @test-link [[rule_return_route_per_section]]
func test_in_every_gate_state_a_slide_takes_the_frontier_back_to_the_start() -> void:
	var start := data.loop.position_at(0.0)
	for section in _sections():
		var gates := _gates_before(section)
		var current := data.loop.current_segments(gates)
		var last: Dictionary = current[current.size() - 1]
		assert_eq(last["id"], "s%d.slide" % section, "section %d: its slide closes the loop" % section)
		assert_eq(last["kind"], LoopData.RETURN)
		var points: PackedVector2Array = last["points"]
		var frontier := data.loop.frontier(gates)
		assert_eq(frontier["section"], section)
		assert_lt(points[0].distance_to(frontier["position"]), 1.0, "slide %d starts at the frontier" % section)
		assert_lt(points[points.size() - 1].distance_to(start), 1.0, "and comes out at the start")
		assert_lt(points[points.size() - 1].x, SCREEN, "in the start basin")
		assert_gt(points[points.size() - 1].y, points[0].y, "it ends lower than it starts: a slide")
		for i in range(1, current.size()):
			var before: PackedVector2Array = current[i - 1]["points"]
			var after: PackedVector2Array = current[i]["points"]
			assert_lt(before[before.size() - 1].distance_to(after[0]), LoopData.JOIN_TOLERANCE,
					"%s joins %s" % [current[i - 1]["id"], current[i]["id"]])


# --- Rule 5: the fusion dips -----------------------------------------------------

# @test-link [[rule_dip_may_nudge_fusion]]
func test_the_fusion_dips_are_low_points_of_the_loop() -> void:
	var gates := _gates_before(3)
	var total := data.loop.length(gates)
	for dip in DIPS:
		var left := data.loop.closest(Vector2(dip[0] * SCREEN, 0.0), gates)
		var right := data.loop.closest(Vector2(dip[1] * SCREEN, 0.0), gates)
		assert_lt(left["distance"], right["distance"], "the loop runs through the dip left to right")
		var lowest := -INF
		var along: float = left["distance"]
		while along <= right["distance"] and along < total:
			lowest = maxf(lowest, data.loop.position_at(along, gates).y)
			along += 8.0
		var rim := maxf((left["position"] as Vector2).y, (right["position"] as Vector2).y)
		assert_gt(lowest - rim, DIP_DEPTH, "the dip at %s to %s screens" % [dip[0], dip[1]])
