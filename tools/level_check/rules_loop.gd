class_name LevelRulesLoop
extends RefCounted
## The level rules about the loop (specs/level-design.md, "The loop"): rules
## 1 to 5, for LevelChecker. Rule 6 (signposts) is in rules_objects.gd.


## Rule 1: in every gate state the loop closes (its segments join, the last
## is a return route back to the start) and every switch sends the flow
## onward by default (its trapdoor shut in a fresh level), so nothing is
## needed to go on. Unless `fast`: in every gate state a lone size-1 train
## slime laps the whole loop with no input, and none is lost.
# @spec-link [[rule_loop_travelable_with_no_input]]
static func travelled_with_no_input(c: LevelChecker, fast: bool) -> Dictionary:
	var findings := []
	for error in c.data.loop.validate():
		findings.append(LevelChecker.finding(c.data.loop.loop_id, NAN, error))
	for section in c.sections():
		findings.append_array(c.loop_closes(section))
	var fresh := LevelStates.fresh_simulation(c.data, c.terrain(), LevelChecker.DEFAULT_SEED)
	var switches := c.data.switches.keys()
	switches.sort()
	for id in switches:
		if not fresh.object_states[id]["trapdoor_shut"]:
			findings.append(LevelChecker.finding(id, (c.data.switches[id]["box"] as Rect2).get_center().x,
					"its trapdoor is open in a fresh level: a switch must send the flow onward by default"))
	var notes := []
	if fast:
		notes.append(LevelChecker.FAST_NOTE)
	elif findings.is_empty():
		for section in c.sections():
			findings.append_array(_lap_findings(c, section, [1], notes))
	return LevelChecker.result(1, findings, "", notes)


## Rule 2: v1 has no size filter, so every size takes the same loop. Unless
## `fast`: a size-2 and a size-3 train slime each lap the whole loop with
## every gate open.
# @spec-link [[rule_all_sizes_travel_loop_v1]]
static func any_size(c: LevelChecker, fast: bool) -> Dictionary:
	var notes := ["v1 has no size filter (D89): every size takes the same loop"]
	var findings := []
	if fast:
		notes.append(LevelChecker.FAST_NOTE)
	else:
		var all := c.sections()
		findings = _lap_findings(c, all[all.size() - 1], [2, 3], notes)
	return LevelChecker.result(2, findings, "", notes)


## The findings of lap runs of `sizes` with the loop at `section`; adds a
## note per size.
static func _lap_findings(c: LevelChecker, section: int, sizes: Array, notes: Array) -> Array:
	var laps := c.lap_ticks(section, sizes)
	var findings := []
	var where := "with the loop at section %d (%.1f screens)" % [section, laps["length"] / LevelChecker.SCREEN]
	for case in laps["stalled"]:
		findings.append(LevelChecker.finding("", NAN,
				"%s a train slime needed a safety net (%s) at tick %d and was moved to the start: see where "
				% [where, case["reason"], case["tick"]] + "with the debug view"))
	for size in laps["ticks"]:
		var ticks: int = laps["ticks"][size]
		if ticks < 0 and laps["stalled"].is_empty():
			findings.append(LevelChecker.finding("", NAN, "%s a size-%d train slime didn't lap the loop within %d s"
					% [where, size, laps["limit"] / Simulation.TICK_RATE]))
		elif ticks >= 0:
			notes.append("%s a size-%d slime lapped it in %.0f s" % [where, size, ticks / float(Simulation.TICK_RATE)])
	return findings


## Rule 3: every exploration branch has a route back, every route back ends
## on the loop in use at its section, on an outgoing route, and in every
## gate state the loop closes back to the start.
# @spec-link [[rule_no_dead_ends]]
static func no_dead_ends(c: LevelChecker) -> Dictionary:
	var findings := []
	var branches := c.data.branches.keys()
	branches.sort()
	for id in branches:
		if c.data.route_back_for(id).is_empty():
			findings.append(LevelChecker.finding(id, (c.data.branches[id] as Rect2).get_center().x,
					"the exploration branch has no route back: add a RouteBack serving it, down to the loop"))
	var routes := c.data.route_backs.keys()
	routes.sort()
	for id in routes:
		var problem := c.landing_problem(id)
		if not problem.is_empty():
			var points: PackedVector2Array = c.data.route_backs[id]["points"]
			findings.append(LevelChecker.finding(id, points[points.size() - 1].x, problem))
	for section in c.sections():
		findings.append_array(c.loop_closes(section))
	return LevelChecker.result(3, findings)


## Rule 4: the loop's start point is inside a split zone.
# @spec-link [[rule_start_carries_split_zone]]
static func split_zone_at_start(c: LevelChecker) -> Dictionary:
	var start := c.data.loop.position_at(0.0)
	for zone in c.data.split_zones.values():
		if (zone as Rect2).has_point(start):
			return LevelChecker.result(4, [])
	return LevelChecker.result(4, [LevelChecker.finding(c.data.loop.loop_id, start.x,
			"the loop's start %s is in no split zone: place a SplitZone over it" % start.round())])


## Rule 5 (optional: a dip "may" nudge fusion): the dips of the loop, with
## every gate open, listed; N/A when there are none.
# @spec-link [[rule_dip_may_nudge_fusion]]
static func fusion_dips(c: LevelChecker) -> Dictionary:
	var found := c.dips()
	if found.is_empty():
		return LevelChecker.not_applicable(5, "the loop has no dip (a low point at least 80 px below both rims)")
	var notes := []
	for dip in found:
		notes.append("a dip at x %.2f, %.0f px deep (brim from %.2f to %.2f)" % [dip["x"] / LevelChecker.SCREEN,
				dip["depth"], dip["from_x"] / LevelChecker.SCREEN, dip["to_x"] / LevelChecker.SCREEN])
	return LevelChecker.result(5, [], "whether each dip really nudges same-species slimes into fusing is judged "
			+ "in play (train slimes bunch at its bottom)", notes)
