class_name DebugCounts
extends RefCounted
## The debug overlay's "woken / available" counter (DebugOverlay), as pure
## logic reading the simulation. Debug builds only: nothing outside
## src/debug/ names it.
##
## Counted in base slimes: a slime counts once per placed base slime it is
## made of (its members, SlimeIdentities), so fusing and splitting don't move
## the numbers. A slime with no placed origin (made by a test or a debug
## tool) counts its size, in section 1.
##
## Sections aren't first-class for slimes in LevelData, so a base slime
## belongs to the section its stable ID names (D72, `<place>.<kind>.<name>`):
## `s2.sleeper.03` to section 2, `start.first-slime` (the start basin) to
## section 1. A place that is neither counts as section 1.
##
## The accessible sections are section 1 plus every section the current loop
## reaches (LoopData.current_segments with the open gates): a section joins
## the loop once the gate on the return route of the section before it (its
## entrance gate) is open.
##   available: every base slime of an accessible section, sleepers included;
##   woken: those not asleep as sleepers (train, free, in a basket,
##          bedtime-asleep).

## The stable ID place of the start basin, part of section 1.
const START_PLACE := "start"


## The section stable ID `stable_id` belongs to: N for "sN.", 1 for "start."
## and for anything else (see the class doc).
static func section_of(stable_id: String) -> int:
	var place := stable_id.get_slice(".", 0)
	if place.length() >= 2 and place.begins_with("s") and place.substr(1).is_valid_int():
		return maxi(1, place.substr(1).to_int())
	return 1


## The accessible sections, ascending: section 1, plus every section with a
## segment in the current loop for `open_gates`.
static func accessible_sections(loop: LoopData, open_gates: Array) -> Array[int]:
	var out: Array[int] = [1]
	if loop == null:
		return out
	for segment in loop.current_segments(open_gates):
		var section := int(segment["section"])
		if not section in out:
			out.append(section)
	out.sort()
	return out


## The gates open in `sim`: the train's (which FrontierSets keeps in step),
## else the gate states marked open.
static func open_gates(sim: Simulation) -> Array:
	if sim.train != null:
		return sim.train.open_gates.duplicate()
	var out := []
	for gate_id in sim.gate_states:
		if bool((sim.gate_states[gate_id] as Dictionary).get("open", false)):
			out.append(gate_id)
	return out


## {"woken", "available"} for `sim` (see the class doc).
static func count(sim: Simulation) -> Dictionary:
	var sections := accessible_sections(sim.level.loop if sim.level != null else null, open_gates(sim))
	var woken := 0
	var available := 0
	var bodies := sim.slimes
	for slime_id in bodies.ids():
		var asleep := bodies.state_of(slime_id) == SlimeBodies.SLEEPER
		var members := sim.identities.members_of(slime_id)
		if members.is_empty():
			available += bodies.size_of(slime_id)
			if not asleep:
				woken += bodies.size_of(slime_id)
			continue
		for member in members:
			if not section_of(member) in sections:
				continue
			available += 1
			if not asleep:
				woken += 1
	return {"woken": woken, "available": available}
