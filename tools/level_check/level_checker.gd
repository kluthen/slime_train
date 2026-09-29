class_name LevelChecker
extends RefCounted
## The level-rules checker (chunk LD1): checks a level against the level
## design rules, specs/level-design.md (rules 1 to 22, numbered as there).
## Generic: it knows nothing of a particular level. Sections come from the
## loop's segments, the gates open once the loop reaches section n from the
## return routes before it (LevelStates), the things' sections from their
## stable IDs' place (`start` is section 1, `s2` section 2, D72).
##
## Give it a level that has built (in the scene tree, or build() called).
## check_load() says whether it loads; check(rule) checks one rule;
## check_all() every rule, 1 to 22, in order. Each result is a Dictionary:
##   "rule"      the rule's number (0: the load check);
##   "title"     the rule's short wording;
##   "status"    PASS (checked by code, nothing wrong), FAIL (see the
##               findings), MANUAL (not checkable by code: "manual" says what
##               a person must look at) or N/A (the rule doesn't apply to this
##               level: the notes say why);
##   "findings"  what is wrong, each {"id" (the stable ID it is about, or
##               ""), "x" (where, in screens, or NAN), "text" (what is wrong
##               and what to fix)};
##   "manual"    what remains for a person, even on a PASS when part of the
##               rule isn't checkable by code ("" when nothing does);
##   "notes"     what the check found or skipped (Array of String).
## format() turns results into text, to_json_data() into JSON-ready data.
##
## Behaviour. Rules 1, 2 and 7 also run the simulation core (Simulation, no
## game scene, off-screen simulation off) from the level as the loop first
## reaches each section (start_state()); `fast` skips those runs and checks
## only the level's layout. The rules themselves are in rules_*.gd next to
## this file. What each check does, and why, is in docs/dev/level-tooling.md.
# @spec-link [[req_level_design_rules]]

const PASS := "PASS"
const FAIL := "FAIL"
const MANUAL := "MANUAL"
const NA := "N/A"
## The note of a rule whose behaviour part was skipped.
const FAST_NOTE := "behaviour skipped (--fast)"
## The note of a loop rule on a level with no loop.
const NO_LOOP_NOTE := "the level has no loop"
## Each rule's short wording (specs/level-design.md).
const TITLES := {
	0: "The level loads",
	1: "The loop can be travelled with no input at all",
	2: "A slime of any size can travel the loop",
	3: "No dead ends",
	4: "The start of the loop carries a split zone",
	5: "A dip in the loop may nudge same-species slimes into fusing",
	6: "A signpost stands at every fork",
	7: "From anywhere a free slime can reach, gravity leads back toward the loop",
	8: "Every exploration branch includes its own route back to the loop",
	9: "Hints that there is something to explore are visible from the loop",
	10: "Tilt is never needed to make progress or open a gate",
	11: "The first section has 3 native species, and each later section adds one",
	12: "A frontier gate opens through the switch-plus-basket set",
	13: "Each section has its own return route to the start",
	14: "Opening a later gate never makes a return route's exploration unreachable",
	15: "Once its gate is open, a frontier set is inert for good",
	16: "At most 200 slimes per level, counted in base slimes",
	17: "Sleepers never sit on the loop itself",
	18: "The first sleeper is placed close to the first awake slime",
	19: "A framing zone wherever a wider view is needed",
	20: "A released level isn't meant to change",
	21: "At the rails' framing, every interactive object sits below the parent zone",
	22: "Slimes come home behind the loop's start; no called ledge overhangs the loop",
}
## The rules that don't need the loop; every other one is N/A without it.
const LOOP_FREE_RULES := [6, 15, 16, 18, 20]
## The seed of the behaviour runs.
const DEFAULT_SEED := 909
const SCREEN := LevelData.SCREEN
## A size-1 slime's radius, px.
const SLIME_RADIUS := PlaceholderArt.SLIME_RADIUS
## A point this close to the loop is on it (a route back's end), px.
const ON_LOOP_MAX_GAP := 32.0
## Two points this close are the same point (the frontier, the start), px.
const SAME_POINT := 1.0
## The rail views are sampled this often along a section's outgoing route, px.
const RAIL_SAMPLE := 32.0
## Two sleepers this close (centre to centre, px) are on the same row.
const ROW_LINK := 80.0
## The longest a slime may take to get back to the loop: left alone, then
## lost (D10), ticks.
const WAY_BACK_DEADLINE := Offscreen.LEFT_ALONE_TICKS + Offscreen.LOST_TICKS

## The level checked, and its plain data.
var level: Level
var data: LevelData

var _terrain: TerrainSegments = null


## A checker of `checked`, a level that has built.
func _init(checked: Level) -> void:
	level = checked
	data = checked.data


# --- Checking ------------------------------------------------------------------

## The load check: the level's load errors (Level.load_errors), except the
## malformed and duplicate stable IDs, which are rule 20's findings.
func check_load() -> Dictionary:
	var findings := []
	if data == null:
		findings.append(finding("", NAN, "the level hasn't been built: add it to the scene tree or call build()"))
		return result(0, findings)
	for error in level.load_errors:
		if not is_stable_id_error(error):
			findings.append(finding("", NAN, error))
	return result(0, findings)


## Rule `rule` (1 to 22). `fast` skips the behaviour runs (rules 1, 2, 7).
func check(rule: int, fast := false) -> Dictionary:
	if not TITLES.has(rule) or rule == 0:
		push_error("LevelChecker: there is no rule %d (the rules are 1 to 22)" % rule)
		return {"rule": rule, "title": "", "status": FAIL, "manual": "", "notes": [],
				"findings": [finding("", NAN, "there is no rule %d (the rules are 1 to 22)" % rule)]}
	if data == null:
		return not_applicable(rule, "the level hasn't been built")
	if data.loop == null and not rule in LOOP_FREE_RULES:
		return not_applicable(rule, NO_LOOP_NOTE)
	match rule:
		1: return LevelRulesLoop.travelled_with_no_input(self, fast)
		2: return LevelRulesLoop.any_size(self, fast)
		3: return LevelRulesLoop.no_dead_ends(self)
		4: return LevelRulesLoop.split_zone_at_start(self)
		5: return LevelRulesLoop.fusion_dips(self)
		6: return LevelRulesObjects.signposts(self)
		7: return LevelRulesExploration.gravity_leads_back(self, fast)
		8: return LevelRulesExploration.route_back_per_branch(self)
		9: return LevelRulesExploration.hints_visible(self)
		10: return LevelRulesExploration.no_tilt_needed(self)
		11: return LevelRulesSections.species_per_section(self)
		12: return LevelRulesObjects.switch_plus_basket(self)
		13: return LevelRulesSections.return_route_per_section(self)
		14: return LevelRulesSections.return_route_exploration(self)
		15: return LevelRulesObjects.inert_once_open(self)
		16: return LevelRulesPlacement.at_most_200(self)
		17: return LevelRulesPlacement.sleepers_off_loop(self)
		18: return LevelRulesPlacement.first_sleeper_close(self)
		19: return LevelRulesPlacement.framing_zones(self)
		20: return LevelRulesPlacement.released_level(self)
		21: return LevelRulesObjects.below_parent_zone(self)
	return LevelRulesStart.the_start(self)


## Every rule of `rules` (all when empty), each once, in ascending order.
func check_all(fast := false, rules := []) -> Array:
	var out := []
	for rule in range(1, 23):
		if rules.is_empty() or rule in rules:
			out.append(check(rule, fast))
	return out


# --- Results -------------------------------------------------------------------

## A finding about stable ID `id` (or ""), at level x `x_px` (or NAN).
static func finding(id: String, x_px: float, text: String) -> Dictionary:
	return {"id": id, "x": x_px / SCREEN if not is_nan(x_px) else NAN, "text": text}


## Rule `rule`'s result: FAIL with findings, PASS without (unless `status`
## says otherwise).
static func result(rule: int, findings: Array, manual := "", notes := [], status := "") -> Dictionary:
	if status.is_empty():
		status = FAIL if not findings.is_empty() else PASS
	return {"rule": rule, "title": TITLES.get(rule, ""), "status": status, "findings": findings,
			"manual": manual, "notes": notes}


## Rule `rule` doesn't apply to this level, because `why`.
static func not_applicable(rule: int, why: String) -> Dictionary:
	return result(rule, [], "", [why], NA)


## Whether a Level load error is about a malformed or duplicate stable ID
## (Level.build's wording).
static func is_stable_id_error(error: String) -> bool:
	return error.begins_with("duplicate stable id ") \
			or error.contains(": stable id '") and error.contains("doesn't follow")


## How many rule results have each status (the load check, rule 0, apart).
static func counts(results: Array) -> Dictionary:
	var out := {PASS: 0, FAIL: 0, MANUAL: 0, NA: 0}
	for one in results:
		if one["rule"] > 0:
			out[one["status"]] += 1
	return out


## One finding as text: "<id> (x <screens>): <text>".
static func finding_text(one: Dictionary) -> String:
	var where := ""
	if not str(one["id"]).is_empty():
		where = one["id"]
	if not is_nan(one["x"]):
		where += (" " if not where.is_empty() else "") + "(x %.2f)" % one["x"]
	return (where + ": " if not where.is_empty() else "") + str(one["text"])


## The results as text, one line per result ("rule 7   FAIL    <title>")
## and, indented under it, its findings ("- "), what is left for a person
## ("manual: ") and its notes ("note: ").
static func format(results: Array) -> String:
	var lines := PackedStringArray()
	var indent := " ".repeat(9)
	for one in results:
		var label := "load" if one["rule"] == 0 else "rule %d" % one["rule"]
		lines.append("%-8s %-7s %s" % [label, one["status"], one["title"]])
		for each in one["findings"]:
			lines.append(indent + "- " + finding_text(each))
		if not str(one["manual"]).is_empty():
			lines.append(indent + "manual: " + one["manual"])
		for note in one["notes"]:
			lines.append(indent + "note: " + note)
	return "\n".join(lines)


## The results as JSON-ready data: a finding's x is null when it has none.
static func to_json_data(results: Array) -> Array:
	var out := []
	for one in results:
		var copy: Dictionary = one.duplicate(true)
		for each in copy["findings"]:
			if is_nan(each["x"]):
				each["x"] = null
		out.append(copy)
	return out


# --- The level's sections and gates ---------------------------------------------

## The section numbers of the loop, ascending.
func sections() -> Array[int]:
	var found: Array[int] = []
	if data.loop == null:
		return found
	for segment in data.loop.segments:
		if not segment["section"] in found:
			found.append(segment["section"])
	found.sort()
	return found


## The section number of stable ID `id` from its place: `start` is section
## 1, `s2` section 2; 0 for anything else.
static func section_of(id: String) -> int:
	var place := id.get_slice(".", 0)
	if place == "start":
		return 1
	if place.begins_with("s") and place.trim_prefix("s").is_valid_int():
		return place.trim_prefix("s").to_int()
	return 0


## The gates open once the loop reaches `section` (LevelStates.gates_before).
func gates_before(section: int) -> Array:
	return LevelStates.gates_before(data, section)


## Every gate a return route names: the loop grown through every section.
func every_gate() -> Array:
	var all := sections()
	return gates_before(all[all.size() - 1] + 1) if not all.is_empty() else []


## Section `section`'s return routes (loop segments of kind RETURN).
func return_routes(section: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for segment in data.loop.segments:
		if segment["section"] == section and segment["kind"] == LoopData.RETURN:
			out.append(segment)
	return out


## What is wrong with the loop in use once it reaches `section` (the gates
## before it open), as findings: it must be that section's outgoing route
## closed by its own return route, starting at the frontier and ending at
## the loop's start, every segment joining the next.
func loop_closes(section: int) -> Array:
	var gates := gates_before(section)
	var current := data.loop.current_segments(gates)
	var out := []
	var label := "with the loop at section %d (gates open: %s)" % [section, ", ".join(gates) if not gates.is_empty()
			else "none"]
	if current.is_empty():
		return [finding(data.loop.loop_id, NAN, "%s the loop has no segments" % label)]
	for k in range(1, current.size()):
		var before: PackedVector2Array = current[k - 1]["points"]
		var after: PackedVector2Array = current[k]["points"]
		if before[before.size() - 1].distance_to(after[0]) > LoopData.JOIN_TOLERANCE:
			out.append(finding(current[k]["id"], after[0].x, "%s it doesn't start where %s ends: join them"
					% [label, current[k - 1]["id"]]))
	var last: Dictionary = current[current.size() - 1]
	var points: PackedVector2Array = last["points"]
	if last["kind"] != LoopData.RETURN or last["section"] != section:
		out.append(finding(last["id"], points[points.size() - 1].x,
				"%s the loop ends on %s, not on section %d's return route: add one after its outgoing route"
				% [label, last["id"], section]))
		return out
	var frontier := data.loop.frontier(gates)
	if frontier["section"] != section or points[0].distance_to(frontier["position"]) > SAME_POINT:
		out.append(finding(last["id"], points[0].x, "%s it doesn't start at the frontier (%s)"
				% [label, (frontier["position"] as Vector2).round()]))
	var start := data.loop.position_at(0.0)
	if points[points.size() - 1].distance_to(start) > SAME_POINT:
		out.append(finding(last["id"], points[points.size() - 1].x,
				"%s it doesn't end at the loop's start (%s): bring it back there" % [label, start.round()]))
	return out


## What is wrong with where route back `route_id` lands, or "": its end must
## be on the loop in use once the loop reaches the route's section, on an
## outgoing segment.
func landing_problem(route_id: String) -> String:
	var points: PackedVector2Array = data.route_backs[route_id]["points"]
	var end := points[points.size() - 1]
	var near := data.loop.closest(end, gates_before(section_of(route_id)))
	if near["gap"] >= ON_LOOP_MAX_GAP:
		return "it ends %.0f px from the loop in use at its section (at most %.0f): end it on the loop" \
				% [near["gap"], ON_LOOP_MAX_GAP]
	if data.loop.segment(near["segment"])["kind"] != LoopData.OUTGOING:
		return "it ends on return route %s, not on an outgoing route: once that gate opens it leads nowhere" \
				% near["segment"]
	return ""


# --- Things in the level ---------------------------------------------------------

## Section number -> the species letters (sorted) of the slimes placed in it:
## its sleepers; the first slime counts in section 1.
func species_by_section() -> Dictionary:
	var placed := {}
	if not data.first_slime.is_empty():
		placed[data.first_slime["id"]] = data.first_slime["species"]
	for id in data.sleepers:
		placed[id] = data.sleepers[id]["species"]
	var by_section := {}
	for id in placed:
		var section := 1 if id == data.first_slime.get("id") else section_of(id)
		if not by_section.has(section):
			by_section[section] = []
		if not placed[id] in by_section[section]:
			by_section[section].append(placed[id])
	for section in by_section:
		by_section[section].sort()
	return by_section


## The base slimes the level holds: the first slime and the sleepers.
func base_slimes() -> int:
	return data.sleepers.size() + (0 if data.first_slime.is_empty() else 1)


## The stable ID of the sleeper nearest the first slime, or "".
func nearest_sleeper() -> String:
	if data.first_slime.is_empty():
		return ""
	var from: Vector2 = data.first_slime["position"]
	var best := ""
	var ids := data.sleepers.keys()
	ids.sort()
	for id in ids:
		if best.is_empty() or from.distance_to(data.sleepers[id]["position"]) \
				< from.distance_to(data.sleepers[best]["position"]):
			best = id
	return best


## The Terrain pieces the slimes collide with: [{"node" (its path from the
## level), "polygon" (its outline, level pixels)}], in tree order.
func terrain_pieces() -> Array:
	var out := []
	for node in level.find_children("*", "", true, false):
		if node is Terrain and node.has_collision:
			var outline: PackedVector2Array = node.baked_polygon
			if outline.is_empty():
				outline = Terrain.bake_polygon(node.curve, node.bake_tolerance_degrees)
			if outline.size() >= 3:
				out.append({"node": str(level.get_path_to(node)), "polygon": level.transform_of(node) * outline})
	return out


## The level's collision terrain for the simulation (SlimeWorld), built once.
func terrain() -> TerrainSegments:
	if _terrain == null:
		_terrain = SlimeWorld.terrain_from(level)
	return _terrain


# --- The camera's view -------------------------------------------------------------

## The views the settled camera shows from the rails along section
## `section`'s outgoing route, every RAIL_SAMPLE px, with the gates before
## it open (Camera.start frames a rail point exactly as the camera settles
## there, framing zones included), in level pixels.
func rail_views(section: int) -> Array[Rect2]:
	var views: Array[Rect2] = []
	for frame in rail_frames(section):
		views.append(frame["view"])
	return views


## rail_views(), each with its rail point, on a screen of `screen_size`
## viewport px (the project's viewport by default): [{"point" (Vector2, on
## the loop), "view" (Rect2, level px), "screen" (the ScreenView, at the
## reference phone's density, for sizes measured on the screen)}].
func rail_frames(section: int, screen_size := ScreenView.DEFAULT_SIZE) -> Array[Dictionary]:
	var gates := gates_before(section)
	var camera := Camera.new()
	camera.zones = data.framing_zones
	var frames: Array[Dictionary] = []
	var before := 0.0
	for segment in data.loop.current_segments(gates):
		if segment["section"] == section and segment["kind"] == LoopData.OUTGOING:
			var along := 0.0
			while along <= segment["length"]:
				var point := data.loop.position_at(before + along, gates)
				camera.start(data.loop, gates, point)
				var screen := ScreenView.new()
				camera.apply_to(screen, screen_size)
				var size := screen_size / camera.zoom
				frames.append({"point": point, "view": Rect2(screen.centre - size * 0.5, size), "screen": screen})
				along += RAIL_SAMPLE
		before += segment["length"]
	return frames


## What hints at branch `branch_id` from the loop: its sleepers; a branch
## with none shows its top, where its route back starts. Empty when it has
## neither.
func hints_of(branch_id: String) -> Array[Vector2]:
	var hints: Array[Vector2] = []
	for id in data.sleepers:
		if data.branch_at(data.sleepers[id]["position"]) == branch_id:
			hints.append(data.sleepers[id]["position"])
	var route := data.route_back_for(branch_id)
	if hints.is_empty() and not route.is_empty():
		hints.append(data.route_backs[route]["points"][0])
	return hints


## Whether any of `hints` peeks into any of `views`: a slime's body there
## (its centre within the view grown by its radius) shows.
static func any_seen(hints: Array[Vector2], views: Array[Rect2]) -> bool:
	for view in views:
		for hint in hints:
			if view.grow(SLIME_RADIUS).has_point(hint):
				return true
	return false



# --- The loop's shape --------------------------------------------------------------

## The dips of the loop's outgoing routes with `gates` open (every gate by
## default), left to right, sampled every `step` px and at every point of
## the routes: LevelGeometry.dips, low points at least `depth` px below both
## rims. Each {"x", "y" (the lowest point), "depth", "from_x", "to_x" (the
## dip's brim)}.
func dips(gates = null, depth := 80.0, step := 8.0) -> Array:
	var open: Array = every_gate() if gates == null else gates
	var points := PackedVector2Array()
	for segment in data.loop.current_segments(open):
		if segment["kind"] == LoopData.OUTGOING:
			points.append_array(LevelGeometry.sample(segment["points"], step))
	return LevelGeometry.dips(points, depth)


## The distance along the loop in use with `gates` open where it leaves the
## split zones it starts in (0 when it starts in none), px.
func past_split_zone(gates: Array) -> float:
	var distance := 0.0
	var total := data.loop.length(gates)
	while distance < total:
		var at := data.loop.position_at(distance, gates)
		var inside := false
		for zone in data.split_zones.values():
			inside = inside or (zone as Rect2).has_point(at)
		if not inside:
			return distance
		distance += 4.0
	return 0.0


# --- Behaviour ---------------------------------------------------------------------

## A simulation of the level as the loop first reaches `section`: fresh, with
## the gates before it open as after their baskets fired (LevelStates).
## Problems opening them are pushed as errors (rule 12 names them).
func start_state(section: int, run_seed := DEFAULT_SEED) -> Simulation:
	var sim := LevelStates.fresh_simulation(data, terrain(), run_seed)
	for problem in LevelStates.open_gates(sim, data, gates_before(section)):
		push_error("LevelChecker: %s" % problem)
	return sim


## The sleepers of section `section` in rows: groups linked by gaps under
## ROW_LINK, each sorted left to right, as stable IDs.
func sleeper_rows(section: int) -> Array:
	var ids := data.sleepers.keys().filter(func(id): return section_of(id) == section)
	ids.sort()
	var row_of := {}
	var rows := []
	for id in ids:
		if row_of.has(id):
			continue
		var row := [id]
		row_of[id] = row
		var k := 0
		while k < row.size():
			var at: Vector2 = data.sleepers[row[k]]["position"]
			for other in ids:
				if not row_of.has(other) and at.distance_to(data.sleepers[other]["position"]) < ROW_LINK:
					row_of[other] = row
					row.append(other)
			k += 1
		row.sort_custom(func(a, b): return data.sleepers[a]["position"].x < data.sleepers[b]["position"].x)
		rows.append(row)
	return rows


## The sleepers whose spots rule 7 tries in section `section`: both ends of
## every row (a row's middle is between its ends).
func row_ends(section: int) -> Array:
	var ends := []
	for row in sleeper_rows(section):
		ends.append(row[0])
		if row.size() > 1:
			ends.append(row[row.size() - 1])
	return ends


## The ticks a slime woken alone at sleeper `stable_id` takes to rejoin the
## train from start_state(section), or -1 (LevelRuns.way_back_ticks).
func way_back_ticks(section: int, stable_id: String, run_seed := DEFAULT_SEED,
		deadline := WAY_BACK_DEADLINE) -> int:
	return LevelRuns.way_back_ticks(start_state(section, run_seed), stable_id, deadline)


## Laps of the loop as it first reaches `section` by lone train slimes of
## `sizes` (LevelRuns.lap_ticks): {"ticks": size -> the tick its lap was
## done, or -1; "stalled"; "limit"; "length"}.
func lap_ticks(section: int, sizes := [1], run_seed := DEFAULT_SEED) -> Dictionary:
	var sim := start_state(section, run_seed)
	return LevelRuns.lap_ticks(sim, sizes, past_split_zone(sim.train.open_gates) + SLIME_RADIUS)
