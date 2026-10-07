class_name DebugCounts
extends RefCounted
## The debug overlay's counters (DebugOverlay), as pure logic reading the
## simulation: "woken / available" (count()), the slime counts
## (count_slimes()), the largest awake cluster (largest_cluster()) and the
## texts showing them. Debug builds only: nothing outside src/debug/ names it.
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
## whatever its size), read from the simulation's own state (SlimeBodies'
## calm, Offscreen's parking), not its margins. The groups overlap (On screen
## and In range share most slimes), so they don't add up to the total:
##   physics:   the slimes that cost physics on a tick, calm ACTIVE and not a
##              sleeper (SlimeBodies.crowd_count(), the crowd detail's count):
##              a slime in a basket and one asleep at bedtime still settling
##              count, a sleeper, a resting or a parked slime don't;
##   on screen: its centre is in the view's visible rect (Fusion.view_rect(),
##              the rect Offscreen parks around), any state, parked or not (a
##              parked one there is unparked by the next tick);
##   in range:  not parked (SlimeBodies.is_parked), any state;
##   parked:    parked, neither simulated nor touched, moved by Offscreen's
##              proxies;
##   resting:   calm RESTING (a wall), any state (the PERF line's).
##
## The largest awake cluster (largest_cluster()): the size, in slimes, of the
## biggest group of Physics slimes touching each other, directly or through
## others (the PERF line's). Touching: in the last tick's contact list
## (SlimeBodies.touching_pairs(), 2 px skin); when a removal since the tick
## (a fusion) has wiped that list, centres closer than the sum of the ring
## radii + 2 px.

## The stable ID place of the start basin, part of section 1.
const START_PLACE := "start"
## The slime counts' groups (count_slimes()).
const PHYSICS := "physics"
const ON_SCREEN := "on_screen"
const IN_RANGE := "in_range"
const PARKED := "parked"
const RESTING := "resting"
## The extra distance at which two rings count as touching by distance
## (touching_by_distance()): the solver's own skin (SlimeBodies.TOUCH_SKIN).
const TOUCH_GAP := SlimeBodies.TOUCH_SKIN


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


## {PHYSICS, ON_SCREEN, IN_RANGE, PARKED, RESTING} for `sim`: its slimes'
## counts, in one pass (see the class doc). Read only.
static func count_slimes(sim: Simulation) -> Dictionary:
	var shown := Fusion.view_rect(sim.view)
	var bodies := sim.slimes
	var physics := 0
	var on_screen := 0
	var parked := 0
	var resting := 0
	for s in bodies.slime_count:
		var calm := bodies.calm[s]
		if calm == SlimeBodies.ACTIVE and bodies.state[s] != SlimeBodies.STATE_SLEEPER:
			physics += 1
		elif calm == SlimeBodies.PARKED:
			parked += 1
		elif calm == SlimeBodies.RESTING:
			resting += 1
		if shown.has_point(bodies.centre_of(bodies.id[s])):
			on_screen += 1
	return {PHYSICS: physics, ON_SCREEN: on_screen, IN_RANGE: bodies.slime_count - parked,
			PARKED: parked, RESTING: resting}


## The largest awake cluster of `bodies`: the size, in slimes, of the biggest
## group of Physics slimes (calm ACTIVE, not a sleeper: crowd_count()'s rule)
## touching each other, directly or through others (A touches B, B touches C:
## one group of 3). Touching = in the last tick's contact list
## (SlimeBodies.touching_pairs(), rings within the solver's TOUCH_SKIN, 2 px);
## when a removal since the tick (a fusion, which runs after the bodies' tick)
## has wiped that list, or before the first tick, centres closer than the sum
## of the ring radii + 2 px (touching_by_distance()). The wipe is seen as no
## candidate pair left (candidate_pair_count() 0: a removal clears them too);
## a real tick with no candidate pair has no touching pair either, and the
## distance rule then finds none. A pair with an end that isn't a Physics
## slime now (resting, parked, a sleeper, or gone since the tick) joins
## nothing. A lone Physics slime is a group of 1; none: 0. Read only.
##
## `left_out`: boxes (Rect2) whose slimes don't count: a Physics slime whose
## centre is inside one of them joins nothing, as if it weren't a Physics
## slime: the cluster is counted over the others only, so two groups don't
## join through it. `left_out_ids`: slimes left out the same way, by id.
## Level rule 23's measure (ClusterWatch) leaves out the baskets' boxes and
## the train slimes on the loop's route this way; the debug overlay and the
## PERF line leave out none.
# @spec-link [[req_platform_and_performance_targets]]
# @spec-link [[rule_no_spot_where_slimes_gather_awake]]
static func largest_cluster(bodies: SlimeBodies, left_out: Array[Rect2] = [],
		left_out_ids := PackedInt32Array()) -> int:
	var physics := physics_slime_ids(bodies)
	if not left_out.is_empty():
		physics = _outside(bodies, physics, left_out)
	if not left_out_ids.is_empty():
		physics = _without(physics, left_out_ids)
	if bodies.candidate_pair_count() == 0:
		return largest_cluster_in(touching_by_distance(bodies, physics), physics)
	return largest_cluster_in(bodies.touching_pairs(), physics)


## The ids of `bodies`' Physics slimes (calm ACTIVE, not a sleeper:
## crowd_count()'s rule), ascending. Read only.
# @spec-link [[req_platform_and_performance_targets]]
static func physics_slime_ids(bodies: SlimeBodies) -> PackedInt32Array:
	var out := PackedInt32Array()
	for s in bodies.slime_count:
		if bodies.calm[s] == SlimeBodies.ACTIVE and bodies.state[s] != SlimeBodies.STATE_SLEEPER:
			out.append(bodies.id[s])
	return out


## The ids of `ids` (ids of `bodies`) whose centre is inside none of the
## `boxes`, in order. Read only.
# @spec-link [[rule_no_spot_where_slimes_gather_awake]]
static func _outside(bodies: SlimeBodies, ids: PackedInt32Array, boxes: Array[Rect2]) -> PackedInt32Array:
	var out := PackedInt32Array()
	for slime_id in ids:
		var centre := bodies.centre_of(slime_id)
		var inside := false
		for box in boxes:
			if box.has_point(centre):
				inside = true
				break
		if not inside:
			out.append(slime_id)
	return out


## The ids of `ids` not in `left_out`, in order. Read only.
# @spec-link [[rule_no_spot_where_slimes_gather_awake]]
static func _without(ids: PackedInt32Array, left_out: PackedInt32Array) -> PackedInt32Array:
	var gone := {}
	for slime_id in left_out:
		gone[slime_id] = true
	var out := PackedInt32Array()
	for slime_id in ids:
		if not gone.has(slime_id):
			out.append(slime_id)
	return out


## The pairs of `physics_ids` (ids of `bodies`) touching by distance: centres
## closer than the sum of their ring radii + TOUCH_GAP, as Vector2i(lower id,
## higher id), each pair once. A uniform grid on the centres, cells as wide
## as the widest possible touching distance, so the 3x3 cells around a slime
## hold every slime it can touch: O(ids + pairs). Read only.
# @spec-link [[req_platform_and_performance_targets]]
static func touching_by_distance(bodies: SlimeBodies, physics_ids: PackedInt32Array) -> Array:
	var count := physics_ids.size()
	var centres := PackedVector2Array()
	var radii := PackedFloat32Array()
	centres.resize(count)
	radii.resize(count)
	var widest := 0.0
	for i in count:
		centres[i] = bodies.centre_of(physics_ids[i])
		radii[i] = bodies.radius_of(physics_ids[i])
		widest = maxf(widest, radii[i])
	var cell_size := 2.0 * widest + TOUCH_GAP
	var grid := {}
	var pairs := []
	for i in count:
		var c := centres[i]
		var cell := Vector2i(floori(c.x / cell_size), floori(c.y / cell_size))
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var near: Variant = grid.get(cell + Vector2i(dx, dy))
				if near == null:
					continue
				for j: int in near:
					if c.distance_to(centres[j]) < radii[i] + radii[j] + TOUCH_GAP:
						var a := physics_ids[i]
						var b := physics_ids[j]
						pairs.append(Vector2i(mini(a, b), maxi(a, b)))
		# An Array, not a PackedInt32Array: a packed array read from the
		# Dictionary is a copy, and appending to it would be lost.
		if grid.has(cell):
			(grid[cell] as Array).append(i)
		else:
			grid[cell] = [i]
	return pairs


## The size of the biggest connected group of `physics_ids` linked by
## `pairs` (Vector2i(id, id), any order), a union-find over the ids with path
## compression, O(pairs + ids). A pair with an end not in `physics_ids` is
## skipped. 0 when `physics_ids` is empty, else at least 1.
# @spec-link [[req_platform_and_performance_targets]]
static func largest_cluster_in(pairs: Array, physics_ids: PackedInt32Array) -> int:
	var index_by_id := {}
	for i in physics_ids.size():
		index_by_id[physics_ids[i]] = i
	var parent := PackedInt32Array()
	var group_size := PackedInt32Array()
	parent.resize(physics_ids.size())
	group_size.resize(physics_ids.size())
	for i in physics_ids.size():
		parent[i] = i
		group_size[i] = 1
	var largest := mini(1, physics_ids.size())
	for pair: Vector2i in pairs:
		if not (index_by_id.has(pair.x) and index_by_id.has(pair.y)):
			continue
		var a := _root(parent, index_by_id[pair.x])
		var b := _root(parent, index_by_id[pair.y])
		if a == b:
			continue
		if group_size[a] < group_size[b]:
			var swap := a
			a = b
			b = swap
		parent[b] = a
		group_size[a] += group_size[b]
		largest = maxi(largest, group_size[a])
	return largest


## The root of index `i` in the union-find `parent`, compressing the path to
## it (every index on the way points at the root afterwards).
# @spec-link [[req_platform_and_performance_targets]]
static func _root(parent: PackedInt32Array, i: int) -> int:
	var root := i
	while parent[root] != root:
		root = parent[root]
	while parent[i] != root:
		var next := parent[i]
		parent[i] = root
		i = next
	return root


## The bar's text for count_slimes()'s `counts`: the four counts (not
## Resting, the PERF line's).
static func slimes_text(counts: Dictionary) -> String:
	return "Physics %d : on screen %d : in range %d : parked %d" % [
			counts[PHYSICS], counts[ON_SCREEN], counts[IN_RANGE], counts[PARKED]]


## The bar's text for `fps` frames per second, rounded to a whole number.
static func fps_text(fps: float) -> String:
	return "%d fps" % roundi(fps)
