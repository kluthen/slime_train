class_name LoopData
extends RefCounted
## The loop as plain data, for the simulation core: no scene nodes, so an
## off-screen slime can be simulated as a distance along it (chunk 15).
## Built at load from the level's Loop component (src/components/loop.gd).
##
## A loop is an ordered list of route segments, each a polyline in level
## pixels. A segment belongs to a section and is either OUTGOING (the route
## out from the start toward the frontier) or RETURN (the section's return
## route, back to the start). A return route is in use while its `gate` (the
## section's frontier gate) is closed. Opening the gate replaces it with the
## next section's segments: that is how the loop grows (D9). Segments join
## end to start, and every return route ends at the start of the loop.
##
## Queries take `open_gates`, the stable IDs of the gates open so far (the gate
## state lives in the simulation, not here). The current loop is a cycle:
## distances wrap round it.

const OUTGOING := "outgoing"
const RETURN := "return"
## How far apart (px) the end of one segment and the start of the next may be.
const JOIN_TOLERANCE := 2.0

## The stable ID of the level's Loop component.
var loop_id := ""
## Every segment, in loop order: dictionaries with "id", "section", "kind",
## "gate" ("" when none), "points" (PackedVector2Array), "lengths"
## (PackedFloat64Array, cumulative) and "length".
var segments: Array[Dictionary] = []


func _init(id := "") -> void:
	loop_id = id


## Appends a segment. `gate` is the gate that retires a RETURN segment.
# @spec-link [[rule_return_route_per_section]]
func add_segment(id: String, section: int, kind: String, points: PackedVector2Array, gate := "") -> void:
	var lengths := Polyline.cumulative_lengths(points)
	segments.append({
		"id": id,
		"section": section,
		"kind": kind,
		"gate": gate,
		"points": points,
		"lengths": lengths,
		"length": lengths[lengths.size() - 1] if not lengths.is_empty() else 0.0,
	})


## The segment with this stable ID, or {}.
func segment(id: String) -> Dictionary:
	for candidate in segments:
		if candidate["id"] == id:
			return candidate
	return {}


## The segments in use, in order: each section's outgoing segments, up to the
## first section whose return route's gate is not in `open_gates`, then that
## return route. When every gate is open, the last return route stays in use.
# @spec-link [[req_loop_and_world]]
# @spec-link [[rule_return_route_per_section]]
func current_segments(open_gates: Array = []) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var last_return: Dictionary = {}
	for section in _sections():
		for candidate in segments:
			if candidate["section"] == section and candidate["kind"] == OUTGOING:
				out.append(candidate)
		for candidate in segments:
			if candidate["section"] == section and candidate["kind"] == RETURN:
				last_return = candidate
				if not candidate["gate"] in open_gates:
					out.append(candidate)
					return out
	if not last_return.is_empty():
		out.append(last_return)
	return out


## The length of the current loop, in px.
func length(open_gates: Array = []) -> float:
	var total := 0.0
	for current in current_segments(open_gates):
		total += current["length"]
	return total


## The point at `distance` px along the current loop from its start. The loop
## is a cycle, so the distance wraps.
# @spec-link [[req_loop_and_world]]
func position_at(distance: float, open_gates: Array = []) -> Vector2:
	var current := current_segments(open_gates)
	if current.is_empty():
		return Vector2.ZERO
	var total := length(open_gates)
	var left := fposmod(distance, total) if total > 0.0 else 0.0
	for part in current:
		if left <= part["length"]:
			return Polyline.point_at(part["points"], part["lengths"], left)
		left -= part["length"]
	var last: PackedVector2Array = current[current.size() - 1]["points"]
	return last[last.size() - 1]


## Where the current loop reaches its frontier: the end of its outgoing part,
## where the return route takes the flow. A dictionary with "gate" (the
## frontier gate, "" when every gate is open), "section", "distance" (along the
## loop) and "position".
func frontier(open_gates: Array = []) -> Dictionary:
	var distance := 0.0
	var result := {"gate": "", "section": 0, "distance": 0.0, "position": Vector2.ZERO}
	for current in current_segments(open_gates):
		if current["kind"] == RETURN:
			result["gate"] = current["gate"] if not current["gate"] in open_gates else ""
			break
		distance += current["length"]
		var points: PackedVector2Array = current["points"]
		result["section"] = current["section"]
		result["position"] = points[points.size() - 1]
	result["distance"] = distance
	return result


## The point of the current loop closest to `point`: a dictionary with
## "distance" (along the loop), "position", "gap" (from `point`) and "segment"
## (its stable ID).
func closest(point: Vector2, open_gates: Array = []) -> Dictionary:
	var best := {"distance": 0.0, "position": Vector2.ZERO, "gap": INF, "segment": ""}
	var before := 0.0
	for current in current_segments(open_gates):
		var on := Polyline.closest(current["points"], current["lengths"], point)
		if on["gap"] < best["gap"]:
			best = {"distance": before + on["distance"], "position": on["position"],
					"gap": on["gap"], "segment": current["id"]}
		before += current["length"]
	return best


## The distance from `point` to the nearest segment of any section, in use or
## not. For placement checks: sleepers never sit on the loop.
func gap(point: Vector2) -> float:
	var best := INF
	for candidate in segments:
		best = minf(best, Polyline.closest(candidate["points"], candidate["lengths"], point)["gap"])
	return best


## What is wrong with the loop's shape, as readable errors (empty when fine):
## no segments, a segment with fewer than two points, an unknown kind, two
## segments that don't join, or a return route that doesn't reach the start.
# @spec-link [[rule_no_dead_ends]]
func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if segments.is_empty():
		errors.append("the loop %s has no segments" % loop_id)
		return errors
	for candidate in segments:
		if candidate["points"].size() < 2:
			errors.append("loop segment %s needs at least two points" % candidate["id"])
		if not candidate["kind"] in [OUTGOING, RETURN]:
			errors.append("loop segment %s has an unknown kind '%s'" % [candidate["id"], candidate["kind"]])
	if not errors.is_empty():
		return errors
	var start: Vector2 = segments[0]["points"][0]
	var outgoing_end := start
	for section in _sections():
		for candidate in segments:
			if candidate["section"] != section:
				continue
			var points: PackedVector2Array = candidate["points"]
			if points[0].distance_to(outgoing_end) > JOIN_TOLERANCE:
				errors.append("loop segment %s doesn't start where the outgoing route before it ends (%s)"
						% [candidate["id"], outgoing_end])
			if candidate["kind"] == OUTGOING:
				outgoing_end = points[points.size() - 1]
			elif points[points.size() - 1].distance_to(start) > JOIN_TOLERANCE:
				errors.append("return route %s doesn't end at the start of the loop (%s)"
						% [candidate["id"], start])
	return errors


## The loop as plain data (JSON-friendly: points are [x, y] pairs).
func to_dict() -> Dictionary:
	var out := []
	for candidate in segments:
		var points := []
		for point in candidate["points"]:
			points.append([point.x, point.y])
		out.append({"id": candidate["id"], "section": candidate["section"], "kind": candidate["kind"],
				"gate": candidate["gate"], "points": points})
	return {"id": loop_id, "segments": out}


## The inverse of to_dict().
static func from_dict(data: Dictionary) -> LoopData:
	var loop := LoopData.new(data.get("id", ""))
	for candidate in data.get("segments", []):
		var points := PackedVector2Array()
		for pair in candidate["points"]:
			points.append(Vector2(pair[0], pair[1]))
		loop.add_segment(candidate["id"], int(candidate["section"]), candidate["kind"], points,
				candidate.get("gate", ""))
	return loop


## The section numbers present, in ascending order.
func _sections() -> Array[int]:
	var found: Array[int] = []
	for candidate in segments:
		if not candidate["section"] in found:
			found.append(candidate["section"])
	found.sort()
	return found
