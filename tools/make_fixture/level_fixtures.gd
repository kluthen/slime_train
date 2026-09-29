extends RefCounted
## The fixtures tools/make_fixture.gd makes for any level other than the test
## level (chunk LD1), found from the level's data alone, never from stable-ID
## names:
##   fresh          the level as new (no save);
##   gate<k>-open   for the k-th gate in loop order: the gates of the sections
##                  up to its own open as after their baskets fired
##                  (LevelStates.open_gates), the level otherwise as new (the
##                  first slime at its marker, every sleeper asleep); the
##                  camera at the start of the section the loop grows into,
##                  the first point of its outgoing loop segment.
## The test level keeps its own, hand-made table (tools/make_fixture.gd).
## stale() says whether any level's fixture save is older than the level
## (chunk LD3): the level's own test and test_fixtures_e2e use it.
# @spec-link [[req_test_level_and_test_mode]]

## The fresh fixture's description (the scaffolder, tools/new_level.gd,
## uses this one too).
const FRESH_DESCRIPTION := "The level as new: no save, the first slime woken at its marker and every " \
		+ "sleeper asleep at its own; the first-play hint is due."
## A sleeper kept asleep in a fixture's save this far from its place in the
## level has moved since the fixture was made, px (saves round centres to
## hundredths).
const MOVED := 1.0


## The level's fixtures, in order: {"fixtures": name -> {"description",
## "camera" ([x, y], or null), "save" (false for fresh), "gates" (the gates
## to open, in loop order)}, "error": "" or why a fixture can't be made}.
# @spec-link [[req_test_level_and_test_mode]]
static func table(data: LevelData) -> Dictionary:
	var fixtures := {"fresh": {"description": FRESH_DESCRIPTION, "camera": null, "save": false, "gates": []}}
	if data.loop == null:
		return {"fixtures": fixtures, "error": ""}
	var k := 0
	for segment in data.loop.segments:
		var gate: String = segment["gate"]
		if segment["kind"] != LoopData.RETURN or gate.is_empty():
			continue
		k += 1
		var section: int = segment["section"]
		var gates := LevelStates.gates_before(data, section + 1)
		var next := _next_outgoing(data, gates, section)
		if next.is_empty():
			return {"fixtures": fixtures, "error": "gate %s (section %d's return route %s) opens onto no later "
					% [gate, section, segment["id"]] + "section: add the next section's outgoing loop segment"}
		var at: Vector2 = next["points"][0]
		fixtures["gate%d-open" % k] = {"description": _gate_description(data, gates, next), "camera": [at.x, at.y],
				"save": true, "gates": gates}
	return {"fixtures": fixtures, "error": ""}


## Fixture `fixture` (an entry of table()) as a simulation of the level on
## its baked `terrain`: {"sim" (Simulation, or null), "error" ("" or what
## went wrong)}.
# @spec-link [[req_test_level_and_test_mode]]
static func build(data: LevelData, terrain: TerrainSegments, fixture: Dictionary) -> Dictionary:
	var sim := LevelStates.fresh_simulation(data, terrain, 1)
	var problems := LevelStates.open_gates(sim, data, fixture["gates"])
	if not problems.is_empty():
		return {"sim": null, "error": "; ".join(problems)}
	return {"sim": sim, "error": ""}


## Why fixture save `save` (SaveData's format, as a fixture holds it) is
## older than the level `data` (chunk LD3), or [] when it is current. A
## save written before the level changed still loads (SaveData.problems
## only checks its shape and the level's ID and version), but without what
## the level gained since: so it is stale when a slime of the level (the
## first slime, a sleeper) is in none of its slimes, when one of its slimes
## holds a stable ID the level doesn't have, when a slime it keeps asleep
## sleeps elsewhere or is of another species than the level's sleeper, or
## when a switch, basket or gate of the level has no state in it. Positions
## are compared within MOVED px.
# @spec-link [[req_test_level_and_test_mode]]
static func stale(save: Dictionary, data: LevelData) -> PackedStringArray:
	var out := PackedStringArray()
	var level_slimes := {}
	if not data.first_slime.is_empty():
		level_slimes[data.first_slime["id"]] = data.first_slime
	for id in data.sleepers:
		level_slimes[id] = data.sleepers[id]
	var held := {}
	for slime in save.get("slimes", []):
		for id in slime.get("members", []):
			held[id] = true
			if not level_slimes.has(id):
				out.append("its slime %s holds %s, which the level doesn't have" % [slime.get("id", "?"), id])
		if slime.get("state") == "sleeper" and data.sleepers.has(slime.get("id", "")):
			var sleeper: Dictionary = data.sleepers[slime["id"]]
			var centre := Vector2(slime["centre"][0], slime["centre"][1])
			if centre.distance_to(sleeper["position"]) > MOVED:
				out.append("%s sleeps at %s in it, at %s in the level" % [slime["id"], centre.round(),
						(sleeper["position"] as Vector2).round()])
			if slime.get("species") != sleeper["species"]:
				out.append("%s is species %s in it, %s in the level" % [slime["id"], slime.get("species"),
						sleeper["species"]])
	var missing := level_slimes.keys().filter(func(id): return not held.has(id))
	missing.sort()
	for id in missing:
		out.append("the level's %s isn't in it" % id)
	var objects: Dictionary = save.get("objects", {})
	var gates: Dictionary = save.get("gates", {})
	for id in data.switches.keys() + data.baskets.keys():
		if not objects.has(id):
			out.append("the level's %s has no state in it" % id)
	for id in data.gates:
		if not gates.has(id):
			out.append("the level's %s has no state in it" % id)
	return out


## The first outgoing segment of a section after `section` in the loop in
## use with `gates` open, or {}.
static func _next_outgoing(data: LevelData, gates: Array, section: int) -> Dictionary:
	for segment in data.loop.current_segments(gates):
		if segment["kind"] == LoopData.OUTGOING and segment["section"] > section:
			return segment
	return {}


## What a gate fixture is: its gates, their baskets and switches, and where
## the loop and the camera are.
static func _gate_description(data: LevelData, gates: Array, next: Dictionary) -> String:
	var sets := PackedStringArray()
	for gate in gates:
		var basket := LevelStates.basket_opening(data, gate)
		sets.append("%s (basket %s, switch %s)" % [gate, basket, LevelStates.switch_of(data, basket)])
	var one := gates.size() == 1
	return ("%s open as after %s fired, %s inert and %s old slide %s shut: %s. The loop runs into section %d. "
			% ["Gate" if one else "Gates", "its basket" if one else "their baskets",
			"its switch" if one else "their switches", "its" if one else "their",
			"entrance" if one else "entrances", ", ".join(sets), next["section"]]
			+ "Otherwise the level as new: the first slime at its marker, every sleeper asleep. The camera "
			+ "at section %d's start (the first point of %s). For starting from section %d."
			% [next["section"], next["id"], next["section"]])
