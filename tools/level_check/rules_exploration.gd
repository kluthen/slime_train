class_name LevelRulesExploration
extends RefCounted
## The level rules about exploration (specs/level-design.md,
## "Exploration"): rules 7 to 10, for LevelChecker.

## A route back may rise this much between two points and still only go
## down (curve tessellation noise), px.
const DOWN_TOLERANCE := 0.5
## A trapdoor's top is on the loop when this close to it, px.
const ON_LOOP := 40.0
## The placeholder signpost's drawing round its position (Signpost._draw:
## the pole and the board), level pixels.
const SIGNPOST_BOX := Rect2(-30, -90, 60, 90)


## Rule 7: every route back only goes down. Unless `fast`: from both ends of
## every row of sleepers of each section, a slime woken there alone as a
## free slime heading back rejoins the train within
## LevelChecker.WAY_BACK_DEADLINE (left alone, then lost), from the level as
## the loop first reaches that section.
# @spec-link [[rule_gravity_leads_back_to_loop]]
static func gravity_leads_back(c: LevelChecker, fast: bool) -> Dictionary:
	var findings := []
	var routes := c.data.route_backs.keys()
	routes.sort()
	for id in routes:
		var points: PackedVector2Array = c.data.route_backs[id]["points"]
		for k in range(1, points.size()):
			if points[k].y < points[k - 1].y - DOWN_TOLERANCE:
				findings.append(LevelChecker.finding(id, points[k].x,
						"the route back climbs %.0f px here: a route back only goes down, so gravity leads back"
						% (points[k - 1].y - points[k].y)))
				break
	var notes := []
	if fast:
		notes.append(LevelChecker.FAST_NOTE)
	else:
		for section in c.sections():
			var slowest := 0
			var tried := c.row_ends(section)
			for id in tried:
				var ticks := c.way_back_ticks(section, id)
				slowest = maxi(slowest, ticks)
				if ticks < 0:
					findings.append(LevelChecker.finding(id, c.data.sleepers[id]["position"].x,
							"a slime woken there is not back on the loop within %d s: make the ground there "
							% (LevelChecker.WAY_BACK_DEADLINE / Simulation.TICK_RATE)
							+ "slope toward the loop, or give it a route back"))
			notes.append("section %d: %d sleepers' spots tried (both ends of every row), slowest back in %.1f s"
					% [section, tried.size(), slowest / float(Simulation.TICK_RATE)])
	return LevelChecker.result(7, findings, "spots a free slime can reach that hold no sleeper (a ledge or bough "
			+ "it is called up to, where it falls) aren't tried: check by eye that the ground there leads back "
			+ "toward the loop", notes)


## Rule 8: every exploration branch has exactly one route back, starting
## inside the branch and ending on the loop (rule 3's landing check).
# @spec-link [[rule_exploration_branch_has_route_back]]
static func route_back_per_branch(c: LevelChecker) -> Dictionary:
	var findings := []
	var branches := c.data.branches.keys()
	branches.sort()
	var routes := c.data.route_backs.keys()
	routes.sort()
	for branch in branches:
		var box: Rect2 = c.data.branches[branch]
		var serving := routes.filter(func(id): return c.data.route_backs[id]["serves"] == branch)
		if serving.size() != 1:
			findings.append(LevelChecker.finding(branch, box.get_center().x,
					"the exploration branch has %d routes back (%s): it needs exactly one"
					% [serving.size(), ", ".join(serving)]))
		for id in serving:
			var points: PackedVector2Array = c.data.route_backs[id]["points"]
			if not box.has_point(points[0]):
				findings.append(LevelChecker.finding(id, points[0].x,
						"the route back doesn't start inside %s: start it in the branch" % branch))
			var problem := c.landing_problem(id)
			if not problem.is_empty():
				findings.append(LevelChecker.finding(id, points[points.size() - 1].x, problem))
	return LevelChecker.result(8, findings)


## Rule 9: from the loop, every exploration branch shows a hint (its
## sleepers, or the start of its route back when it has none) in a settled
## rail view of its section, framing zones included. And a decoration drawn
## in front of the level covers no tap target, sleeper, first slime or
## signpost.
# @spec-link [[rule_hints_visible_from_loop]]
static func hints_visible(c: LevelChecker) -> Dictionary:
	var findings := []
	var views_of := {}
	var branches := c.data.branches.keys()
	branches.sort()
	for branch in branches:
		var section := LevelChecker.section_of(branch)
		if not views_of.has(section):
			views_of[section] = c.rail_views(section)
		var hints := c.hints_of(branch)
		if hints.is_empty() or not LevelChecker.any_seen(hints, views_of[section]):
			findings.append(LevelChecker.finding(branch, (c.data.branches[branch] as Rect2).get_center().x,
					"nothing of the branch peeks into a rail view of section %d: move a sleeper or the branch's "
					% section + "edge into view, or add a framing zone that shows it"))
	findings.append_array(_covering_decorations(c))
	return LevelChecker.result(9, findings, "whether each hint reads as something to explore is judged by eye")


## The findings of decorations drawn in front that cover an object, a
## sleeper, the first slime or a signpost.
static func _covering_decorations(c: LevelChecker) -> Array:
	var covered := []
	var ids := c.data.tap_targets.keys()
	ids.sort()
	for id in ids:
		if c.data.tap_targets[id]["kind"] != TapDispatcher.KIND_SLEEPER:
			var box: Rect2 = c.data.tap_targets[id]["box"]
			covered.append([id, box.get_center().x, LevelGeometry.box_polygon(box)])
	for id in c.data.sleepers:
		var at: Vector2 = c.data.sleepers[id]["position"]
		covered.append([id, at.x, LevelGeometry.circle_polygon(at, LevelChecker.SLIME_RADIUS)])
	if not c.data.first_slime.is_empty():
		var at: Vector2 = c.data.first_slime["position"]
		covered.append([c.data.first_slime["id"], at.x, LevelGeometry.circle_polygon(at, LevelChecker.SLIME_RADIUS)])
	for id in c.data.signposts:
		var at: Vector2 = c.data.signposts[id]["position"]
		covered.append([id, at.x, LevelGeometry.box_polygon(Rect2(at + SIGNPOST_BOX.position, SIGNPOST_BOX.size))])
	var findings := []
	for node in c.level.find_children("*", "", true, false):
		if not (node is Decoration and node.in_front):
			continue
		var outline: PackedVector2Array = node.level_polygon(c.level)
		for thing in covered:
			if LevelGeometry.polygons_overlap(outline, thing[2]):
				findings.append(LevelChecker.finding(thing[0], thing[1],
						"decoration %s is drawn in front and covers it: turn its in_front off or move it"
						% c.level.get_path_to(node)))
	return findings


## Rule 10: every switch's trapdoor lies on the loop over its basket, the
## basket below it, so the flow drops in by gravity and taps alone. Whether
## any exploration spot or gate needs tilt is for a person.
# @spec-link [[rule_tilt_never_required]]
static func no_tilt_needed(c: LevelChecker) -> Dictionary:
	var findings := []
	var switches := c.data.switches.keys()
	switches.sort()
	for id in switches:
		var trapdoor: Rect2 = c.data.switches[id]["trapdoor"]
		var x := (c.data.switches[id]["box"] as Rect2).get_center().x
		if not trapdoor.has_area():
			findings.append(LevelChecker.finding(id, x,
					"the switch has no trapdoor: give it one on the loop, over its basket"))
			continue
		var top := Vector2(trapdoor.get_center().x, trapdoor.position.y)
		var gap: float = c.data.loop.closest(top, c.gates_before(LevelChecker.section_of(id)))["gap"]
		if gap >= ON_LOOP:
			findings.append(LevelChecker.finding(id, top.x,
					"its trapdoor's top is %.0f px from the loop (at most %.0f): put it on the loop" % [gap, ON_LOOP]))
		var basket_id: String = c.data.switches[id]["basket"]
		if not c.data.baskets.has(basket_id):
			continue
		var basket: Rect2 = c.data.baskets[basket_id]["box"]
		if not trapdoor.grow(1.0).intersects(basket):
			findings.append(LevelChecker.finding(id, top.x,
					"its trapdoor doesn't open onto %s: put the basket right under it" % basket_id))
		if basket.end.y <= trapdoor.end.y:
			findings.append(LevelChecker.finding(id, top.x,
					"%s isn't below its trapdoor: slimes must drop in, with no tilt" % basket_id))
	return LevelChecker.result(10, findings, "no exploration spot or gate may need tilt: check that every branch "
			+ "is reached by calls alone (slopes a called slime hops up, ledges within its reach)")
