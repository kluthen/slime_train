class_name LevelRulesSections
extends RefCounted
## The level rules about sections and their return routes, for
## LevelChecker: species per section (rule 11), a return route per section
## (rule 13) and exploration on return routes (rule 14). Where a return
## route meets the start is rule 22 (rules_start.gd).

## The species of the first section.
const FIRST_SPECIES := 3


## Rule 11: section 1 has exactly 3 species (the first slime counts in
## section 1), each later section adds exactly one, so the level has 3 +
## (sections - 1), at most Species.COUNT.
# @spec-link [[rule_first_section_species_count]]
static func species_per_section(c: LevelChecker) -> Dictionary:
	var findings := []
	var by_section := c.species_by_section()
	var all := c.sections()
	var first: Array = by_section.get(1, [])
	if first.size() != FIRST_SPECIES:
		findings.append(LevelChecker.finding("", NAN,
				"section 1 has %d species (%s): it needs exactly %d (the first slime counts in section 1)"
				% [first.size(), ", ".join(first), FIRST_SPECIES]))
	var seen: Array = first.duplicate()
	var notes := ["section 1: %s" % ", ".join(first)]
	for section in all.slice(1):
		var added: Array = by_section.get(section, []).filter(func(letter): return not letter in seen)
		if added.size() != 1:
			findings.append(LevelChecker.finding("", NAN,
					"section %d adds %d species (%s): each later section adds exactly one"
					% [section, added.size(), ", ".join(added)]))
		seen.append_array(added)
		notes.append("section %d adds %s" % [section, ", ".join(added) if not added.is_empty() else "none"])
	for section in by_section:
		if not section in all:
			findings.append(LevelChecker.finding("", NAN,
					"slimes are placed in section %d (by their stable IDs), which the loop doesn't have" % section))
	if seen.size() > Species.COUNT:
		findings.append(LevelChecker.finding("", NAN,
				"the level has %d species; the game has %d" % [seen.size(), Species.COUNT]))
	return LevelChecker.result(11, findings, "", notes)


## Rule 13: each section has exactly one return route; it names the
## section's gate (none for the last section); in every gate state the loop
## ends on the frontier section's return route.
# @spec-link [[rule_return_route_per_section]]
static func return_route_per_section(c: LevelChecker) -> Dictionary:
	var findings := []
	var all := c.sections()
	for section in all:
		var routes := c.return_routes(section)
		if routes.size() != 1:
			findings.append(LevelChecker.finding(routes[0]["id"] if not routes.is_empty() else "", NAN,
					"section %d has %d return routes: it needs exactly one (a LoopSegment of kind return)"
					% [section, routes.size()]))
			continue
		var route: Dictionary = routes[0]
		var problem := _gate_problem(route["gate"], section, section == all[all.size() - 1])
		if not problem.is_empty():
			findings.append(LevelChecker.finding(route["id"], route["points"][0].x, problem))
		var current := c.data.loop.current_segments(c.gates_before(section))
		if current.is_empty() or current[current.size() - 1]["id"] != route["id"]:
			findings.append(LevelChecker.finding(route["id"], route["points"][0].x,
					"with the loop at section %d, the loop doesn't end on this return route" % section))
	return LevelChecker.result(13, findings, "", ["each return route has its own camera rail: the rails follow "
			+ "the loop's segments (Camera)"])


## What is wrong with `gate`, named by section `section`'s return route
## (the `last` section's names none), or "".
static func _gate_problem(gate: String, section: int, last: bool) -> String:
	if last:
		return "" if gate.is_empty() else \
				"the last section's return route names gate %s: the last section has no gate, clear its gate_id" % gate
	if gate.is_empty():
		return "the return route names no gate: set its gate_id to section %d's gate" % section
	if LevelChecker.section_of(gate) != section:
		return "the return route names gate %s, which isn't section %d's" % [gate, section]
	return ""


## Rule 14: every route back still ends on the loop in use in every gate
## state from its section on, and lands on an outgoing route (a route back
## landing on a return route leads nowhere once that gate opens).
# @spec-link [[rule_return_route_may_carry_exploration]]
static func return_route_exploration(c: LevelChecker) -> Dictionary:
	var findings := []
	var routes := c.data.route_backs.keys()
	routes.sort()
	for id in routes:
		var points: PackedVector2Array = c.data.route_backs[id]["points"]
		var end := points[points.size() - 1]
		var own := LevelChecker.section_of(id)
		var landing := c.data.loop.closest(end, c.gates_before(own))
		if landing["gap"] < LevelChecker.ON_LOOP_MAX_GAP \
				and c.data.loop.segment(landing["segment"])["kind"] == LoopData.RETURN:
			findings.append(LevelChecker.finding(id, end.x,
					"it lands on return route %s, which a gate retires: land it on an outgoing route"
					% landing["segment"]))
			continue
		for section in c.sections().filter(func(later): return later >= own):
			var near := c.data.loop.closest(end, c.gates_before(section))
			if near["gap"] >= LevelChecker.ON_LOOP_MAX_GAP:
				findings.append(LevelChecker.finding(id, end.x,
						"once the loop reaches section %d it ends %.0f px from the loop in use: "
						% [section, near["gap"]] + "land it on a route that stays in use"))
				break
	return LevelChecker.result(14, findings, "a gate's lid may shut its old return route's entrance (D105): any "
			+ "exploration placed on that route then needs another way in; check it by eye")
