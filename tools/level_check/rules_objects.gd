class_name LevelRulesObjects
extends RefCounted
## The level rules about the interactive objects, for LevelChecker: the
## signposts at the forks (rule 6), the switch-plus-basket sets (rules 12 and
## 15) and where the objects sit on screen (rule 21).

## A signpost stands at its fork: this close to its switch's box centre, px.
const AT_FORK := 200.0
## The tap target kinds rule 21 checks: the objects a child operates.
const OPERATED := [TapDispatcher.KIND_SWITCH, TapDispatcher.KIND_BASKET]


## Rule 6: every switch (the only forks in v1) has one signpost naming it,
## within AT_FORK of it; no signpost names anything else; signposts are not
## tap targets.
# @spec-link [[rule_signpost_at_every_fork]]
static func signposts(c: LevelChecker) -> Dictionary:
	var findings := []
	var by_switch := {}
	var ids := c.data.signposts.keys()
	ids.sort()
	for id in ids:
		var switch: String = c.data.signposts[id]["switch"]
		var at: Vector2 = c.data.signposts[id]["position"]
		if not c.data.switches.has(switch):
			findings.append(LevelChecker.finding(id, at.x, "the signpost names '%s', which isn't a switch" % switch))
			continue
		if not by_switch.has(switch):
			by_switch[switch] = []
		by_switch[switch].append(id)
		var fork := (c.data.switches[switch]["box"] as Rect2).get_center()
		if at.distance_to(fork) >= AT_FORK:
			findings.append(LevelChecker.finding(id, at.x,
					"it stands %.0f px from %s (at most %.0f): move it to the fork"
					% [at.distance_to(fork), switch, AT_FORK]))
		if c.data.tap_targets.has(id):
			findings.append(LevelChecker.finding(id, at.x, "a signpost must not be a tap target"))
	var switches := c.data.switches.keys()
	switches.sort()
	for id in switches:
		var count: int = by_switch.get(id, []).size()
		if count != 1:
			findings.append(LevelChecker.finding(id, (c.data.switches[id]["box"] as Rect2).get_center().x,
					"the fork has %d signposts: it needs exactly one naming it (a Signpost with switch_id %s)"
					% [count, id]))
	return LevelChecker.result(6, findings)


## Rule 12: every gate is opened by a basket's "full" rule, every basket has
## exactly one switch pointing at it, and every section but the last has a
## gate (its return route's). The last basket may have no rule: filling it
## plays the celebration (D77).
# @spec-link [[rule_gate_opens_via_switch_basket_set]]
static func switch_plus_basket(c: LevelChecker) -> Dictionary:
	var findings := []
	var gates := c.data.gates.keys()
	gates.sort()
	for id in gates:
		if LevelStates.basket_opening(c.data, id).is_empty():
			findings.append(LevelChecker.finding(id, (c.data.gates[id]["box"] as Rect2).get_center().x,
					"no basket's \"full\" rule opens the gate: set a basket's on_full_object to it"))
	var baskets := c.data.baskets.keys()
	baskets.sort()
	for id in baskets:
		var switches := c.data.switches.keys().filter(func(s): return c.data.switches[s]["basket"] == id)
		if switches.size() != 1:
			findings.append(LevelChecker.finding(id, (c.data.baskets[id]["box"] as Rect2).get_center().x,
					"%d switches point at the basket: it needs exactly one (a Switch with basket_id %s)"
					% [switches.size(), id]))
	var all := c.sections()
	for section in all.slice(0, all.size() - 1):
		for route in c.return_routes(section):
			if not c.data.gates.has(route["gate"]):
				findings.append(LevelChecker.finding(route["id"], route["points"][0].x,
						"section %d's return route names no gate of the level ('%s'): each section but the last "
						% [section, route["gate"]] + "ends at a gate its switch-plus-basket set opens"))
	return LevelChecker.result(12, findings)


## Rule 15: by construction. FrontierSets makes a set inert for good once
## its basket has fired (tests/unit/test_frontier_sets.gd).
# @spec-link [[rule_frontier_set_inert_after_gate_open]]
static func inert_once_open(_c: LevelChecker) -> Dictionary:
	return LevelChecker.result(15, [], "a set kept as a landscape feature must not block the loop once its gate is "
			+ "open: check its switch, basket and gate by eye", ["by construction: FrontierSets makes every set "
			+ "inert once its basket has fired (tests/unit/test_frontier_sets.gd)"])


## Rule 21 (D111): in every settled rail view of its section whose x-span
## holds its box's centre, every switch's and basket's box top is at or below
## the parent zone (TapDispatcher.parent_zone_height: 7 mm, D113, at the
## reference phone's density, ScreenView's default).
# @spec-link [[rule_objects_below_parent_zone]]
static func below_parent_zone(c: LevelChecker) -> Dictionary:
	var findings := []
	var frames_of := {}
	var ids := c.data.tap_targets.keys()
	ids.sort()
	for id in ids:
		if not c.data.tap_targets[id]["kind"] in OPERATED:
			continue
		var box: Rect2 = c.data.tap_targets[id]["box"]
		var section := LevelChecker.section_of(id)
		if not frames_of.has(section):
			frames_of[section] = c.rail_frames(section)
		var worst := {}
		var band := TapDispatcher.parent_zone_height(ScreenView.new())
		for frame in frames_of[section]:
			var view: Rect2 = frame["view"]
			if box.get_center().x < view.position.x or box.get_center().x > view.end.x:
				continue
			var top := (box.position.y - view.position.y) * ScreenView.DEFAULT_SIZE.x / view.size.x
			if top < band and (worst.is_empty() or top < worst["top"]):
				worst = {"top": top, "x": (frame["point"] as Vector2).x}
		if not worst.is_empty():
			findings.append(LevelChecker.finding(id, worst["x"],
					("framed from the rail point here, its top is %.0f screen px into the parent zone "
					+ "(the top %.0f px): ")
					% [band - worst["top"], band]
					+ "move it down, or frame it lower with a framing zone"))
	return LevelChecker.result(21, findings, "", ["the settled rail views only (D111), framing zones included; "
			+ "views while the camera moves (a call's drag, the idle camera) aren't checked"])
