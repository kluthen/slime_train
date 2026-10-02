class_name TrainQueues
extends RefCounted
## The touching queues of the train (chunk 22f, D147 (1) and (8)): pure,
## read-only geometry over the Train's records (slime id -> {"distance", ...,
## "hold" while it holds}) and SlimeBodies, for the hold's debug counters
## (TrainHold.count_hops) and the Train's snapshot (Train.hold_snapshot, the
## debug bar's "hold n" and the PERF line). No draw, no state change: nothing
## here is in the dump, the saves or the state hash.
##
## Only simulated train slimes take part (a train slime, not parked; the hold
## is for them only: parking ends it), proposed.
##   - Touching (D143's, by distance): centres within the sum of their
##     radii (SlimeBodies.radius_of, the rest ring's) plus TOUCH_GAP.
##   - Ahead along the loop: the forward distance between the two records'
##     distances, laps aside (it wraps), is above 0 and below half the
##     loop; at the same distance the lower id is ahead (proposed: an order
##     that doesn't hang on the records' order).
##   - A touching queue: a chain of train slimes consecutive along the loop
##     (by distance, the one ahead later), each touching the next, across
##     the loop's end too. Its front is its member furthest along; a lone
##     slime is a queue of 1, its own front.
# @spec-link [[req_platform_and_performance_targets]]

## How far apart two rings may be and still touch, px (D143: 2 px, the
## solver's skin).
const TOUCH_GAP := SlimeBodies.TOUCH_SKIN
## The smallest touching queue whose back slimes the snapshot counts (D147 (8)).
const QUEUE_MIN := 5
## The snapshot's fields, in the PERF line's order (see snapshot()).
const SNAPSHOT_FIELDS: Array[String] = ["holding", "holding_resting", "contact_resting", "queue_back",
		"queue_back_held"]


## Whether slimes `a` and `b` touch (see the class doc).
# @spec-link [[req_platform_and_performance_targets]]
static func touches(bodies: SlimeBodies, a: int, b: int) -> bool:
	return bodies.centre_of(a).distance_to(bodies.centre_of(b)) \
			<= bodies.radius_of(a) + bodies.radius_of(b) + TOUCH_GAP


## How far ahead of train slime `a` along a loop `loop_length` px long train
## slime `b` is, px, by `records`' distances; -1 when it isn't ahead (see
## the class doc).
# @spec-link [[req_platform_and_performance_targets]]
static func gap_ahead(records: Dictionary, a: int, b: int, loop_length: float) -> float:
	if loop_length <= 0.0 or a == b:
		return -1.0
	var d := fposmod(float(records[b]["distance"]) - float(records[a]["distance"]), loop_length)
	if d == 0.0:
		return 0.0 if b < a else -1.0
	return d if d < loop_length * 0.5 else -1.0


## Whether `slime_id` (a record of `records`) is a simulated train slime.
# @spec-link [[req_platform_and_performance_targets]]
static func simulated(bodies: SlimeBodies, slime_id: int) -> bool:
	var s := bodies.index_of(slime_id)
	return s >= 0 and bodies.state[s] == SlimeBodies.TRAIN and bodies.calm[s] != SlimeBodies.PARKED


## Whether train slime `slime_id` is the front of its touching queue: no
## simulated train slime ahead of it touches it.
# @spec-link [[req_platform_and_performance_targets]]
static func is_front(records: Dictionary, bodies: SlimeBodies, slime_id: int, loop_length: float) -> bool:
	for other: int in records:
		if gap_ahead(records, slime_id, other, loop_length) >= 0.0 and simulated(bodies, other) \
				and touches(bodies, slime_id, other):
			return false
	return true


## Whether the nearest simulated train slime ahead of train slime `slime_id`
## within `reach` px along the loop holds or rests (D147 (8)'s queue hop);
## false when none is that near. At the same distance, any of them.
# @spec-link [[req_platform_and_performance_targets]]
static func waits_behind(records: Dictionary, bodies: SlimeBodies, slime_id: int, reach: float,
		loop_length: float) -> bool:
	var nearest := INF
	var waiting := false
	for other: int in records:
		var d := gap_ahead(records, slime_id, other, loop_length)
		if d < 0.0 or d > reach or d > nearest or not simulated(bodies, other):
			continue
		var waits: bool = records[other].has("hold") or bodies.calm_of(other) == SlimeBodies.RESTING
		waiting = waits or (waiting and d == nearest)
		nearest = d
	return waiting


## The snapshot (SNAPSHOT_FIELDS -> count) of `records`' train slimes on a
## loop `loop_length` px long:
##   holding          those holding (a record's "hold");
##   holding_resting  of them, calm RESTING;
##   contact_resting  calm RESTING but not holding: resting by contact with a
##                    holder (TrainHold.set_rest, D147 5 (a));
##   queue_back       in every touching queue of QUEUE_MIN or more simulated
##                    train slimes, the members behind its front;
##   queue_back_held  of them, holding or resting.
## O(n log n), read only.
# @spec-link [[req_platform_and_performance_targets]]
static func snapshot(records: Dictionary, bodies: SlimeBodies, loop_length: float) -> Dictionary:
	var out := {}
	for field in SNAPSHOT_FIELDS:
		out[field] = 0
	var members := []
	for slime_id: int in records:
		if bodies.state_of(slime_id) != SlimeBodies.TRAIN:
			continue
		var resting := bodies.calm_of(slime_id) == SlimeBodies.RESTING
		if records[slime_id].has("hold"):
			out["holding"] += 1
			out["holding_resting"] += 1 if resting else 0
		elif resting:
			out["contact_resting"] += 1
		if simulated(bodies, slime_id):
			members.append(slime_id)
	for queue: Array in queues(records, bodies, members):
		if queue.size() < QUEUE_MIN:
			continue
		for k in queue.size() - 1:
			out["queue_back"] += 1
			var waits: bool = records[queue[k]].has("hold") or bodies.calm_of(queue[k]) == SlimeBodies.RESTING
			out["queue_back_held"] += 1 if waits else 0
	return out


## The touching queues of train slimes `members` (ids of `records`), each
## from its back to its front (see the class doc).
# @spec-link [[req_platform_and_performance_targets]]
static func queues(records: Dictionary, bodies: SlimeBodies, members: Array) -> Array:
	var order := members.duplicate()
	order.sort_custom(func(a: int, b: int) -> bool:
		var da: float = records[a]["distance"]
		var db: float = records[b]["distance"]
		return da < db or (da == db and a > b))
	var out := []
	for slime_id: int in order:
		if out.is_empty() or not touches(bodies, out[-1][-1], slime_id):
			out.append([slime_id])
		else:
			out[-1].append(slime_id)
	# Across the loop's end: the last queue runs on into the first.
	if out.size() > 1 and touches(bodies, out[-1][-1], out[0][0]):
		out[0] = out[-1] + out[0]
		out.pop_back()
	return out
