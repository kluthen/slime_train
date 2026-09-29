class_name LevelRulesPlacement
extends RefCounted
## The level rules about what is placed where, for LevelChecker: the
## population (rules 16 and 17), onboarding (rule 18), the framing zones
## (rule 19) and the stable IDs a released level keeps (rule 20).

## The most base slimes a level holds (D67).
const MAX_BASE_SLIMES := 200
## A sleeper this close to the loop's route would sit on it: two size-1
## slime radii, px.
const OFF_LOOP_MIN_GAP := 2.0 * PlaceholderArt.SLIME_RADIUS
## The first sleeper is this close to the first slime, px: about a third of
## a screen, as the test level has it (specs/levels/test/README.md).
const FIRST_SLEEPER_NEAR := LevelData.SCREEN / 3.0


## Rule 16: the first slime and the sleepers make at most MAX_BASE_SLIMES
## base slimes.
# @spec-link [[rule_max_200_slimes_per_level]]
static func at_most_200(c: LevelChecker) -> Dictionary:
	var count := c.base_slimes()
	var findings := []
	if count > MAX_BASE_SLIMES:
		findings.append(LevelChecker.finding("", NAN,
				"the level holds %d base slimes (the first slime and %d sleepers): at most %d, take sleepers out"
				% [count, c.data.sleepers.size(), MAX_BASE_SLIMES]))
	return LevelChecker.result(16, findings, "where many slimes pile up on one screen they should stay mostly "
			+ "still (a basket being filled): measure it with tools/bench_level.gd", ["%d base slimes" % count])


## Rule 17: every sleeper is more than OFF_LOOP_MIN_GAP from every loop
## segment, in use or not (LoopData.gap).
# @spec-link [[rule_sleepers_never_on_loop]]
static func sleepers_off_loop(c: LevelChecker) -> Dictionary:
	var findings := []
	var ids := c.data.sleepers.keys()
	ids.sort()
	for id in ids:
		var at: Vector2 = c.data.sleepers[id]["position"]
		var gap := c.data.loop.gap(at)
		if gap <= OFF_LOOP_MIN_GAP:
			findings.append(LevelChecker.finding(id, at.x,
					"it sits %.0f px from the loop (more than %.0f needed): move it off the loop, waking always "
					% [gap, OFF_LOOP_MIN_GAP] + "takes a call"))
	return LevelChecker.result(17, findings)


## Rule 18: the sleeper nearest the first slime is within FIRST_SLEEPER_NEAR.
# @spec-link [[rule_first_sleeper_near_first_awake_slime]]
static func first_sleeper_close(c: LevelChecker) -> Dictionary:
	if c.data.first_slime.is_empty():
		return LevelChecker.result(18, [LevelChecker.finding("", NAN,
				"the level has no first slime: place a FirstSlime")])
	if c.data.sleepers.is_empty():
		return LevelChecker.not_applicable(18, "the level has no sleepers")
	var nearest := c.nearest_sleeper()
	var at: Vector2 = c.data.sleepers[nearest]["position"]
	var away := at.distance_to(c.data.first_slime["position"]) / LevelData.SCREEN
	var findings := []
	if away * LevelData.SCREEN > FIRST_SLEEPER_NEAR:
		findings.append(LevelChecker.finding(nearest, at.x,
				"the nearest sleeper is %.2f screens from the first slime (at most %.2f): place one closer"
				% [away, FIRST_SLEEPER_NEAR / LevelData.SCREEN]))
	return LevelChecker.result(18, findings, "", ["the first sleeper is %s, %.2f screens from the first slime"
			% [nearest, away]])


## Rule 19: every framing zone's box meets the loop (the camera enters a
## zone at a rail point inside it) and its zoom is above 0 and at most 1.
## Where a wider view is needed is judged by eye.
# @spec-link [[rule_framing_zone_wherever_wider_view_needed]]
static func framing_zones(c: LevelChecker) -> Dictionary:
	var manual := "where a wider view is needed (a branch's hint, a basket and its gate, a big pile) is judged by eye"
	if c.data.framing_zones.is_empty():
		return LevelChecker.result(19, [], manual, ["the level has no framing zone"], LevelChecker.MANUAL)
	var findings := []
	var ids := c.data.framing_zones.keys()
	ids.sort()
	for id in ids:
		var zone: Dictionary = c.data.framing_zones[id]
		var box: Rect2 = zone["box"]
		var meets := false
		for segment in c.data.loop.segments:
			meets = meets or LevelGeometry.polyline_meets_box(segment["points"], box)
		if not meets:
			findings.append(LevelChecker.finding(id, box.get_center().x,
					"its box doesn't meet the loop, so the camera never enters it: stretch it over the loop"))
		if zone["zoom"] <= 0.0 or zone["zoom"] > 1.0:
			findings.append(LevelChecker.finding(id, box.get_center().x,
					"its zoom is %.2f: a framing zone widens the view, above 0 and at most 1" % zone["zoom"]))
	return LevelChecker.result(19, findings, manual)


## Rule 20: the stable IDs are well-formed and unique, level_version is 1 or
## more, and each section's sleepers are numbered from .01 without gaps,
## left to right (specs/levels/test/README.md, "Stable IDs"). Keeping them
## once released is for a person.
# @spec-link [[rule_released_level_stable_with_migration]]
static func released_level(c: LevelChecker) -> Dictionary:
	var findings := _id_findings(c)
	if c.level.level_version < 1:
		findings.append(LevelChecker.finding("", NAN, "level_version is %d: it starts at 1" % c.level.level_version))
	var by_section := {}
	for id in c.data.sleepers:
		var section := LevelChecker.section_of(id)
		if not by_section.has(section):
			by_section[section] = []
		by_section[section].append(id)
	for section in by_section:
		findings.append_array(_numbering(c, by_section[section]))
	return LevelChecker.result(20, findings, "once the level is released, compare its stable IDs with the released "
			+ "version's: keep every one, and bump level_version with a save migration for any change (D72)",
			["level version %d" % c.level.level_version])


## The malformed and duplicate stable IDs of the level's things.
static func _id_findings(c: LevelChecker) -> Array:
	var findings := []
	var first_of := {}
	for node in c.level.find_children("*", "", true, false):
		if not node.is_in_group(Level.THINGS_GROUP):
			continue
		var id: String = node.stable_id
		var x := c.level.position_of(node).x
		if not StableId.is_valid(id):
			findings.append(LevelChecker.finding(id, x,
					"%s: the stable ID doesn't follow <place>.<kind>.<name> " % c.level.get_path_to(node)
					+ "(lowercase, numbered things with two digits)"))
		elif first_of.has(id):
			findings.append(LevelChecker.finding(id, x,
					"the stable ID is used twice (%s and %s): give each thing its own"
					% [first_of[id], c.level.get_path_to(node)]))
		else:
			first_of[id] = c.level.get_path_to(node)
	return findings


## What is wrong with the numbering of one section's sleepers `ids`.
static func _numbering(c: LevelChecker, ids: Array) -> Array:
	var findings := []
	var numbered := []
	for id in ids:
		var name: String = id.get_slice(".", id.get_slice_count(".") - 1)
		if not name.is_valid_int() or name != "%02d" % name.to_int():
			findings.append(LevelChecker.finding(id, c.data.sleepers[id]["position"].x,
					"a sleeper is numbered .01, .02 and so on"))
		else:
			numbered.append([name.to_int(), id])
	numbered.sort_custom(func(a, b): return a[0] < b[0])
	for k in numbered.size():
		var id: String = numbered[k][1]
		var x: float = c.data.sleepers[id]["position"].x
		if numbered[k][0] != k + 1:
			findings.append(LevelChecker.finding(id, x,
					"expected number .%02d here: number each section's sleepers from .01 without gaps" % (k + 1)))
			break
		if k > 0 and x < c.data.sleepers[numbered[k - 1][1]]["position"].x:
			findings.append(LevelChecker.finding(id, x,
					"it is left of %s: number the sleepers left to right" % numbered[k - 1][1]))
			break
	return findings
