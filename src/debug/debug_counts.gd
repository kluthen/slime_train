class_name DebugCounts
extends RefCounted
## The debug overlay's counters (DebugOverlay), as pure logic reading the
## simulation: "woken / available" (count()), the slime counts (count_slimes())
## and the texts showing them. Debug builds only: nothing outside src/debug/
## names it.
##
## Woken / available. Counted in base slimes: a slime counts once per placed base slime it is
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
##
## The slime counts. Counted in slimes (bodies: a fused slime counts once,
## whatever its size), every state (sleepers, piles, baskets included), each
## in exactly one group, read from the off-screen simulation's own state
## (Offscreen), not its margins:
##   on screen:  its centre is in the view's visible rect (Fusion.view_rect(),
##               the rect Offscreen parks around), parked or not (a parked
##               one there is unparked by the next tick);
##   simulated:  off the visible rect but fully simulated (not parked): within
##               the view grown by NEAR_MARGIN, or between the margins and not
##               parked yet, or Offscreen is off;
##   off screen: off the visible rect and parked (SlimeBodies.is_parked):
##               neither simulated nor touched, moved by Offscreen's proxies.

## The stable ID place of the start basin, part of section 1.
const START_PLACE := "start"
## The slime counts' groups (count_slimes()).
const ON_SCREEN := "on_screen"
const SIMULATED := "simulated"
const OFF_SCREEN := "off_screen"


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


## {"on_screen", "simulated", "off_screen"} for `sim`: its slimes in the three
## groups of the slime counts (see the class doc).
static func count_slimes(sim: Simulation) -> Dictionary:
	var shown := Fusion.view_rect(sim.view)
	var out := {ON_SCREEN: 0, SIMULATED: 0, OFF_SCREEN: 0}
	var bodies := sim.slimes
	for slime_id in bodies.ids():
		if shown.has_point(bodies.centre_of(slime_id)):
			out[ON_SCREEN] += 1
		elif bodies.is_parked(slime_id):
			out[OFF_SCREEN] += 1
		else:
			out[SIMULATED] += 1
	return out


## The bar's text for count_slimes()'s `counts`.
static func slimes_text(counts: Dictionary) -> String:
	return "Slimes %d on screen : %d simulated : %d off screen" % [
			counts[ON_SCREEN], counts[SIMULATED], counts[OFF_SCREEN]]


## The bar's text for `fps` frames per second, rounded to a whole number.
static func fps_text(fps: float) -> String:
	return "%d fps" % roundi(fps)
