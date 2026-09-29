class_name LevelRulesObjects
extends RefCounted
## The level rules about the interactive objects, for LevelChecker: the
## signposts at the forks (rule 6), the switch-plus-basket sets (rules 12 and
## 15) and where the objects sit on screen (rule 21).

## A signpost stands at its fork: this close to its switch's box centre, px.
const AT_FORK := 200.0


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


## Rule 21 (D111, item 23.9): at the rails' framing, every interactive
## object (parent_zone_objects(): every switch, basket and gate) sits fully
## below the parent zone. The rails' framing: the settled rail views of every
## section's outgoing route with the gates before it open (rail_frames(),
## framing zones included), so every object is checked against the whole
## level's rails, on the reference phone's screen (1440 x 648 viewport px at
## its density, where the band is 7 mm, about 67 px). The return routes'
## rails (the slides) aren't checked: from them the camera frames the
## objects from below, not where the child meets them (a reading taken,
## proposed, D126). parent_zone_findings() does the check on any views.
# @spec-link [[rule_objects_below_parent_zone]]
static func below_parent_zone(c: LevelChecker) -> Dictionary:
	var frames: Array[Dictionary] = []
	for section in c.sections():
		frames.append_array(c.rail_frames(section, ScreenView.REFERENCE_PHONE_SIZE))
	var views: Array[ScreenView] = []
	for frame in frames:
		views.append(frame["screen"])
	var findings := []
	for one in parent_zone_findings(c.data, views):
		findings.append(LevelChecker.finding(one["id"], (frames[one["view"]]["point"] as Vector2).x,
				("framed from the rail point here, its top is %.0f screen px into the parent zone "
				+ "(the top %.0f px): ") % [one["band"] - one["top"], one["band"]]
				+ "move it down, or frame it lower with a framing zone"))
	return LevelChecker.result(21, findings, "", ["the settled views of the outgoing routes' rails only "
			+ "(proposed, D126), framing zones included, on the reference phone; the slides' rails and views "
			+ "while the camera moves (a call's drag, the idle camera, a gate being shown) aren't checked"])


## The interactive objects rule 21 checks: stable ID -> drawn box (Rect2,
## level px), every switch, basket and gate. Signposts aren't interactive
## (D47); sleepers are slimes, not objects.
# @spec-link [[rule_objects_below_parent_zone]]
static func parent_zone_objects(data: LevelData) -> Dictionary:
	var out := {}
	for group in [data.switches, data.baskets, data.gates]:
		for id in group:
			out[id] = group[id]["box"]
	return out


## Rule 21 over `views`: one finding per interactive object that some view
## frames (its box's centre within the view's width) with its top inside
## the parent zone (TapDispatcher.parent_zone_height at that view), or
## above the screen, at the view where it goes deepest. Each finding: {"id"
## (stable ID), "view" (the index in `views`), "top" (the box's top on that
## screen, screen px), "band" (the parent zone's height there, screen px)}.
## Sorted by ID; empty when the rule holds.
# @spec-link [[rule_objects_below_parent_zone]]
static func parent_zone_findings(data: LevelData, views: Array[ScreenView]) -> Array[Dictionary]:
	var boxes := parent_zone_objects(data)
	var ids := boxes.keys()
	ids.sort()
	var out: Array[Dictionary] = []
	for id in ids:
		var worst := _deepest_in_band(boxes[id], views)
		if not worst.is_empty():
			worst["id"] = id
			out.append(worst)
	return out


## Of `views`, the one framing `box` with its top deepest inside the parent
## zone, as a parent_zone_findings() finding without its ID; {} when none.
static func _deepest_in_band(box: Rect2, views: Array[ScreenView]) -> Dictionary:
	var worst := {}
	for index in views.size():
		var view := views[index]
		var centre_x := view.world_to_screen(box.get_center()).x
		if centre_x < 0.0 or centre_x > view.screen_size.x:
			continue
		var top := view.world_to_screen(box.position).y
		var band := TapDispatcher.parent_zone_height(view)
		if top < band and (worst.is_empty() or top - band < worst["top"] - worst["band"]):
			worst = {"view": index, "top": top, "band": band}
	return worst
