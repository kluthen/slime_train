extends SceneTree
## The level report (chunk LD1): what a level holds and how it measures up,
## for a level designer, on any level. It reads the level with the
## level-rules checker's helpers (LevelChecker, tools/level_check/) and
## checks nothing itself: tools/check_level.gd does.
##
## Run:   tools/level.sh report [--level=<id>] [--json]
##   (tools/level.sh imports first and starts Godot with --no-header, so
##   --json prints the JSON alone on stdout; the raw command is
##   godot --headless --no-header --path . -s res://tools/level_report.gd -- ...)
##
##   --level=<id>   the level (LevelCatalog; default "test")
##   --json         print one JSON object (the same data) instead of text
##
## Text output: a header line (with the first slime's species), then
## sections, each opened by a "== <name> =="
## line, one fact per line (x in screens, y and lengths in level px unless a
## line says otherwise):
##   loop              per gate state, the loop in use: its length and a
##                     size-1 slime's lap at the train's pace (hops at the
##                     off-screen pace, Offscreen.pace; slides at
##                     Train.SLIDE_SPEED);
##   population        base slimes per section and species (the first slime
##                     counts in section 1), against the cap (rule 16) and the
##                     species rule (rule 11), as the checker judges them;
##   sleeper rows      each row of LevelChecker.sleeper_rows: its IDs, its
##                     species, its x span, the exploration branch it is in;
##   exploration branches  each branch's box, its sleepers, its route back's
##                     length and a size-1 slime's time along it off screen,
##                     against being left alone (Offscreen.LEFT_ALONE_TICKS);
##   frontier sets     each basket's switch, quota and target (a gate, or the
##                     celebration), and the base slimes placed by then;
##   framing zones     each zone's x span, zoom and offset;
##   reach             per sleeper row, a static estimate: the rise to the
##                     row from the best take-off point of the loop within a
##                     called hop's reach sideways (LevelProgress.take_off)
##                     against a called hop's highest rise
##                     (FreeSlimes.max_rise) for sizes 1, 2 and 3;
##   progress          per section with a basket, a static estimate
##                     (LevelProgress.estimate): the base slimes a called
##                     slime can wake by then against the basket's quota.
##
## Exit code: 0; 2 when it can't run (a bad argument, an unknown level, a
## level that doesn't load).

const USAGE := "usage: tools/level.sh report [--level=<id>] [--json]"
const S := LevelData.SCREEN
## The sizes a called slime's reach is given for.
const SIZES := [1, 2, 3]
## An off-screen slime is left alone after this long away, seconds.
const LEFT_ALONE_SECONDS := Offscreen.LEFT_ALONE_TICKS * Simulation.TICK_SECONDS
## A slime left alone and still free is lost this long after, seconds.
const LOST_SECONDS := Offscreen.LOST_TICKS * Simulation.TICK_SECONDS

var _level_id := LevelCatalog.DEFAULT_ID
var _json := false


## Reads the arguments, loads the level, prints its report and quits.
func _initialize() -> void:
	var problem := _parse()
	var level: Level = null
	if problem.is_empty():
		var loaded := _load(_level_id)
		problem = loaded["problem"]
		level = loaded["level"]
	if not problem.is_empty():
		printerr("level_report: %s" % problem)
		printerr(USAGE)
		quit(2)
		return
	var report := collect(LevelChecker.new(level))
	print(JSON.stringify(report) if _json else "\n".join(format(report)))
	level.free()
	quit(0)


## Reads the arguments into the settings. Returns "" or the problem.
func _parse() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--level="):
			_level_id = arg.trim_prefix("--level=")
		elif arg == "--json":
			_json = true
		else:
			return "unknown argument '%s'" % arg
	return ""


## Loads and builds level `id`: {"level" (a built Level, or null), "problem"
## ("" or why it doesn't load)}.
static func _load(id: String) -> Dictionary:
	var problem := LevelCatalog.problem(id)
	if not problem.is_empty():
		return {"level": null, "problem": problem}
	var scene = load(LevelCatalog.scene_path(id)).instantiate()
	if not scene is Level:
		scene.free()
		return {"level": null, "problem": "%s: its root isn't a Level (src/components/level.gd)"
				% LevelCatalog.scene_path(id)}
	var errors: PackedStringArray = scene.build()
	if scene.data == null or scene.data.loop == null:
		errors.append("the level has no loop")
	if not errors.is_empty():
		scene.free()
		return {"level": null, "problem": "level %s doesn't load: %s" % [id, "; ".join(errors)]}
	return {"level": scene, "problem": ""}


# --- The report's data ------------------------------------------------------------

## The whole report as JSON-ready data (x in screens, lengths in px, times in
## seconds).
func collect(c: LevelChecker) -> Dictionary:
	var rows := _rows(c)
	return {
		"level": c.data.level_id, "version": c.data.level_version, "sections": c.sections(),
		"pace": {"size_1": Offscreen.pace(1), "slide": Train.SLIDE_SPEED},
		"loop": _loop_states(c), "population": _population(c), "rows": rows,
		"branches": _branches(c), "frontier_sets": _frontier_sets(c), "framing_zones": _framing_zones(c),
		"reach": _reach(c, rows), "first_slime": c.data.first_slime.get("species", ""),
		"progress": LevelProgress.estimate(c),
	}


## Per section n, the loop in use once it reaches n (the gates before it
## open): its outgoing and return lengths, px, and a size-1 slime's lap,
## seconds (hopping at the off-screen pace, sliding at the slide's speed).
static func _loop_states(c: LevelChecker) -> Array:
	var out := []
	for section in c.sections():
		var gates := c.gates_before(section)
		var outgoing := 0.0
		var back := 0.0
		var routes := PackedStringArray()
		for segment in c.data.loop.current_segments(gates):
			if segment["kind"] == LoopData.OUTGOING:
				outgoing += segment["length"]
			else:
				back += segment["length"]
				routes.append(segment["id"])
		out.append({"section": section, "gates": gates, "outgoing": outgoing, "return": back,
				"return_routes": routes, "length": outgoing + back,
				"lap_seconds": outgoing / Offscreen.pace(1) + back / Train.SLIDE_SPEED})
	return out


## The base slimes per section and species letter, the level's totals, the
## cap (rule 16) and the species rule (rule 11), with the checker's verdicts.
# @spec-link [[rule_max_200_slimes_per_level]]
# @spec-link [[rule_first_section_species_count]]
static func _population(c: LevelChecker) -> Dictionary:
	var placed := {}
	if not c.data.first_slime.is_empty():
		placed[c.data.first_slime["id"]] = [1, c.data.first_slime["species"]]
	for id in c.data.sleepers:
		placed[id] = [LevelChecker.section_of(id), c.data.sleepers[id]["species"]]
	var letters := []
	var by_section := {}
	for id in placed:
		var section: int = placed[id][0]
		var letter: String = placed[id][1]
		if not letter in letters:
			letters.append(letter)
		if not by_section.has(section):
			by_section[section] = {}
		by_section[section][letter] = by_section[section].get(letter, 0) + 1
	letters.sort()
	var sections := by_section.keys()
	sections.sort()
	var table := []
	for section in sections:
		table.append({"section": section, "counts": by_section[section], "total": _sum(by_section[section])})
	var species_rule := c.check(11)
	return {"species": letters, "sections": table, "base_slimes": c.base_slimes(),
			"cap": LevelRulesPlacement.MAX_BASE_SLIMES, "cap_status": c.check(16)["status"],
			"species_status": species_rule["status"], "species_notes": species_rule["notes"]}


## Every sleeper row (LevelChecker.sleeper_rows), section by section, left
## to right: its name ("<section>.<k>"), IDs (first and last in number
## order), species counts, x span (screens), y span (px) and the exploration
## branches its sleepers are in (branch -> how many).
static func _rows(c: LevelChecker) -> Array:
	var out := []
	for section in _sleeper_sections(c):
		var rows := c.sleeper_rows(section)
		rows.sort_custom(func(a, b): return c.data.sleepers[a[0]]["position"].x < c.data.sleepers[b[0]]["position"].x)
		for k in rows.size():
			var ids: Array = rows[k].duplicate()
			ids.sort_custom(func(a: String, b: String): return a.naturalnocasecmp_to(b) < 0)
			var species := {}
			var branches := {}
			var xs := []
			var ys := []
			for id in ids:
				var sleeper: Dictionary = c.data.sleepers[id]
				species[sleeper["species"]] = species.get(sleeper["species"], 0) + 1
				var branch := c.data.branch_at(sleeper["position"])
				if not branch.is_empty():
					branches[branch] = branches.get(branch, 0) + 1
				xs.append(sleeper["position"].x / S)
				ys.append(sleeper["position"].y)
			out.append({"row": "%d.%d" % [section, k + 1], "section": section, "ids": [ids[0], ids[ids.size() - 1]],
					"count": ids.size(), "species": _sorted(species), "x": [xs.min(), xs.max()],
					"y": [ys.min(), ys.max()], "branches": branches, "members": ids})
	return out


## Every exploration branch: its box (x in screens, y in px), its sleepers,
## its route back's length (px) and a size-1 slime's time along it at the
## off-screen pace, against being left alone.
static func _branches(c: LevelChecker) -> Array:
	var out := []
	var ids := c.data.branches.keys()
	ids.sort()
	for id in ids:
		var box: Rect2 = c.data.branches[id]
		var inside := 0
		for sleeper in c.data.sleepers.values():
			if c.data.branch_at(sleeper["position"]) == id:
				inside += 1
		var entry := {"id": id, "x": [box.position.x / S, box.end.x / S], "y": [box.position.y, box.end.y],
				"sleepers": inside, "route_back": c.data.route_back_for(id), "left_alone_seconds": LEFT_ALONE_SECONDS,
				"lost_seconds": LOST_SECONDS}
		if not entry["route_back"].is_empty():
			var lengths: PackedFloat64Array = c.data.route_backs[entry["route_back"]]["lengths"]
			entry["length"] = lengths[lengths.size() - 1]
			entry["seconds"] = entry["length"] / Offscreen.pace(1)
		out.append(entry)
	return out


## Every basket, section by section: its switch, quota and target (the gate
## its rule opens, or "" for the celebration), and the base slimes placed by
## then (the first slime and the sleepers of sections 1 to its own).
static func _frontier_sets(c: LevelChecker) -> Array:
	var baskets := c.data.baskets.keys()
	baskets.sort_custom(func(a: String, b: String):
		var sa := LevelChecker.section_of(a)
		var sb := LevelChecker.section_of(b)
		return sa < sb or (sa == sb and a < b))
	var out := []
	for basket in baskets:
		var switch := LevelStates.switch_of(c.data, basket)
		var section := LevelChecker.section_of(switch if not switch.is_empty() else basket)
		var available := 0 if c.data.first_slime.is_empty() else 1
		for id in c.data.sleepers:
			var placed := LevelChecker.section_of(id)
			if placed >= 1 and placed <= section:
				available += 1
		out.append({"section": section, "switch": switch, "basket": basket, "quota": c.data.baskets[basket]["quota"],
				"gate": _gate_opened_by(c.data, basket), "available": available})
	return out


## Every framing zone, left to right: its x span (screens), zoom and offset
## (px).
static func _framing_zones(c: LevelChecker) -> Array:
	var ids := c.data.framing_zones.keys()
	ids.sort_custom(func(a: String, b: String):
		var xa: float = c.data.framing_zones[a]["box"].position.x
		var xb: float = c.data.framing_zones[b]["box"].position.x
		return xa < xb or (xa == xb and a < b))
	var out := []
	for id in ids:
		var zone: Dictionary = c.data.framing_zones[id]
		var box: Rect2 = zone["box"]
		out.append({"id": id, "x": [box.position.x / S, box.end.x / S], "zoom": zone["zoom"],
				"offset": [zone["offset"].x, zone["offset"].y]})
	return out


## Per sleeper row, a static estimate of its reach from the loop in use at
## its section (LevelProgress.take_off): the rise (px, up is positive) from
## the best take-off point within a called size-1 hop's reach sideways to
## each sleeper's centre; the row's lowest and highest over the sleepers
## with a take-off point ([null, null] when no loop is within that reach
## sideways of any, so the JSON stays valid); and the smallest size whose
## called hop reaches its easiest sleeper (LevelProgress.smallest_size), 0
## for none.
# @spec-link [[rule_all_sizes_travel_loop_v1]]
static func _reach(c: LevelChecker, rows: Array) -> Dictionary:
	var max_rise := {}
	for size in SIZES:
		max_rise[str(size)] = LevelProgress.max_rise(size)
	var out := []
	for row in rows:
		var rises := []
		var smallest := 0
		for id in row["members"]:
			var at: Vector2 = c.data.sleepers[id]["position"]
			var rise: float = LevelProgress.take_off(c, row["section"], at)["rise"]
			if not is_inf(rise):
				rises.append(rise)
			var size := LevelProgress.smallest_size(c, row["section"], at)
			if size > 0 and (smallest == 0 or size < smallest):
				smallest = size
		var span: Array = [rises.min(), rises.max()] if not rises.is_empty() else [null, null]
		out.append({"row": row["row"], "rise": span, "smallest_size": smallest})
	return {"max_rise": max_rise, "hop_reach": Train.hop_reach(1), "rows": out}


## The sections holding sleepers or loop, ascending (a sleeper whose ID
## names no section is in section 0).
static func _sleeper_sections(c: LevelChecker) -> Array:
	var out: Array = c.sections().duplicate()
	for id in c.data.sleepers:
		if not LevelChecker.section_of(id) in out:
			out.append(LevelChecker.section_of(id))
	out.sort()
	return out


## The gate basket `basket`'s rule opens when full, or "" (none: a last
## basket, whose firing may play the celebration).
static func _gate_opened_by(data: LevelData, basket: String) -> String:
	for gate in data.gates:
		if LevelStates.basket_opening(data, gate) == basket:
			return gate
	return ""


## The sum of `counts`' values.
static func _sum(counts: Dictionary) -> int:
	var total := 0
	for value in counts.values():
		total += value
	return total


## `counts` with its keys sorted.
static func _sorted(counts: Dictionary) -> Dictionary:
	var keys := counts.keys()
	keys.sort()
	var out := {}
	for key in keys:
		out[key] = counts[key]
	return out


# --- The report as text -------------------------------------------------------------

## The report as text lines (see the file's doc).
static func format(r: Dictionary) -> PackedStringArray:
	var lines := PackedStringArray()
	lines.append("level_report: level %s (version %d), %d sections, %d base slimes, first slime %s"
			% [r["level"], r["version"], r["sections"].size(), r["population"]["base_slimes"],
			_or_none(r["first_slime"])])
	lines.append("pace: a size-1 slime hops %.1f px/s off screen (Offscreen.pace), slides %.0f px/s (Train.SLIDE_SPEED)"
			% [r["pace"]["size_1"], r["pace"]["slide"]])
	lines.append("== loop ==")
	for state in r["loop"]:
		lines.append("loop at section %d (gates open: %s): %.2f screens, outgoing %.2f + return %s %.2f; size-1 lap %.0f s"
				% [state["section"], _list_or_none(state["gates"]), state["length"] / S, state["outgoing"] / S,
				", ".join(state["return_routes"]), state["return"] / S, state["lap_seconds"]])
	lines.append_array(_format_population(r["population"]))
	lines.append("== sleeper rows ==")
	for row in r["rows"]:
		var ids := "%s to %s (%d sleepers)" % [row["ids"][0], row["ids"][1], row["count"]]
		if row["count"] == 1:
			ids = "%s (1 sleeper)" % row["ids"][0]
		lines.append("row %s: %s: %s; x %.2f to %.2f; branch: %s" % [row["row"], ids, _counts_text(row["species"]),
				row["x"][0], row["x"][1], _branches_text(row["branches"], row["count"])])
	lines.append("== exploration branches ==")
	for branch in r["branches"]:
		lines.append(_branch_line(branch))
	lines.append("== frontier sets ==")
	for k in r["frontier_sets"].size():
		var fs: Dictionary = r["frontier_sets"][k]
		var target := "opens gate %s" % fs["gate"] if not fs["gate"].is_empty() \
				else "no gate: the celebration, once every basket has fired"
		lines.append("set %d (section %d): switch %s, basket %s, quota %d, %s; available by then %d (base slimes of sections 1 to %d)"
				% [k + 1, fs["section"], _or_none(fs["switch"]), fs["basket"], fs["quota"], target, fs["available"],
				fs["section"]])
	lines.append("== framing zones ==")
	for zone in r["framing_zones"]:
		lines.append("%s: x %.2f to %.2f, zoom %.2f, offset (%.0f, %.0f)" % [zone["id"], zone["x"][0], zone["x"][1],
				zone["zoom"], zone["offset"][0], zone["offset"][1]])
	lines.append_array(_format_reach(r["reach"]))
	lines.append_array(_format_progress(r["progress"]))
	return lines


## The population section: the table, the cap line and the species line.
static func _format_population(p: Dictionary) -> PackedStringArray:
	var lines := PackedStringArray(["== population =="])
	var head := "%-8s" % "section"
	for letter in p["species"]:
		head += " %4s" % letter
	lines.append(head + " %6s" % "total")
	var level := {}
	for row in p["sections"]:
		var line := "%-8s" % str(row["section"])
		for letter in p["species"]:
			var n: int = row["counts"].get(letter, 0)
			level[letter] = level.get(letter, 0) + n
			line += " %4s" % (str(n) if n > 0 else "-")
		lines.append(line + " %6d" % row["total"])
	var total := "%-8s" % "level"
	for letter in p["species"]:
		total += " %4d" % level.get(letter, 0)
	lines.append(total + " %6d" % p["base_slimes"])
	lines.append("base slimes: %d of at most %d (rule 16): %s" % [p["base_slimes"], p["cap"], p["cap_status"]])
	lines.append("species per section (rule 11: section 1 has 3, each later section adds 1): %s: %s"
			% ["; ".join(p["species_notes"]), p["species_status"]])
	return lines


## One exploration branch's line.
static func _branch_line(b: Dictionary) -> String:
	var line := "%s: x %.2f to %.2f, y %.0f to %.0f px; %d sleepers; " % [b["id"], b["x"][0], b["x"][1], b["y"][0],
			b["y"][1], b["sleepers"]]
	if b["route_back"].is_empty():
		return line + "no route back (rule 8)"
	var verdict := "within" if b["seconds"] <= b["left_alone_seconds"] else "longer than"
	return line + "route back %s %.2f screens, %.1f s for a size-1 slime off screen: %s left alone (%.0f s; lost %.0f s later)" \
			% [b["route_back"], b["length"] / S, b["seconds"], verdict, b["left_alone_seconds"], b["lost_seconds"]]


## The reach section: the max rises, then one line per row.
static func _format_reach(reach: Dictionary) -> PackedStringArray:
	var lines := PackedStringArray()
	lines.append("== reach (a static estimate from the level's shape, to each row's easiest sleeper: play it to be sure) ==")
	var rises := PackedStringArray()
	for size in SIZES:
		rises.append("size %d %.0f px" % [size, reach["max_rise"][str(size)]])
	lines.append("a called hop rises at most (FreeSlimes.max_rise): %s; it takes off from the loop's point least below "
			% ", ".join(rises) + "the sleeper within a hop's reach sideways (%.0f px for size 1)" % reach["hop_reach"])
	for row in reach["rows"]:
		var rise := "no loop within a hop's reach sideways"
		if row["rise"][0] != null:
			rise = "rise %.0f px" % row["rise"][0]
		if row["rise"][0] != null and row["rise"][1] - row["rise"][0] >= 1.0:
			rise = "rise %.0f to %.0f px" % row["rise"]
		var verdict := "beyond a called hop from the loop"
		if row["smallest_size"] > 0:
			verdict = "reachable by a called size %d hop from the loop" % row["smallest_size"]
		lines.append("row %s: %s: %s" % [row["row"], rise, verdict])
	return lines


## The progress section: one line per section with a basket.
static func _format_progress(progress: Array) -> PackedStringArray:
	var lines := PackedStringArray()
	lines.append("== progress (a static estimate: the base slimes a called slime can wake by each basket; "
			+ "play it to be sure) ==")
	for one in progress:
		var verdict := "progresses"
		if not one["progresses"]:
			var named: Array = one["unreached"].slice(0, LevelProgress.NAMED)
			var rest: int = one["unreached"].size() - named.size()
			verdict = "MAY NOT PROGRESS (out of reach: %s%s)" % [", ".join(named),
					" and %d more" % rest if rest > 0 else ""]
		lines.append("section %d: basket %s, quota %d; awake by then about %d base slimes (%s), largest size %d: %s"
				% [one["section"], one["basket"], one["quota"], one["available"], _counts_text(one["species"]),
				one["largest"], verdict])
	return lines


## "A 2, B 1".
static func _counts_text(counts: Dictionary) -> String:
	var parts := PackedStringArray()
	for key in counts:
		parts.append("%s %d" % [key, counts[key]])
	return ", ".join(parts)


## The branches a row's sleepers are in: "none", "s1.branch.tree", or
## "s1.branch.tree (3 of 4)" when some are outside.
static func _branches_text(branches: Dictionary, count: int) -> String:
	if branches.is_empty():
		return "none"
	var parts := PackedStringArray()
	for id in branches:
		parts.append(id if branches[id] == count else "%s (%d of %d)" % [id, branches[id], count])
	return ", ".join(parts)


## `ids` joined, or "none".
static func _list_or_none(ids: Array) -> String:
	return ", ".join(ids) if not ids.is_empty() else "none"


## `text`, or "none" when empty.
static func _or_none(text: String) -> String:
	return text if not text.is_empty() else "none"
