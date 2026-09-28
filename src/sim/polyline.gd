class_name Polyline
extends RefCounted
## Distance math on a polyline (an array of points joined by straight lines),
## for routes the simulation follows: the loop's segments and the routes
## back. Plain math, no scene dependencies.


## The distance from the first point to each point: out[0] is 0 and the last
## value is the polyline's length.
static func cumulative_lengths(points: PackedVector2Array) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	out.resize(points.size())
	var total := 0.0
	for i in points.size():
		if i > 0:
			total += points[i - 1].distance_to(points[i])
		out[i] = total
	return out


## The point at `distance` along the polyline, clamped to its ends.
## `lengths` comes from cumulative_lengths(points).
static func point_at(points: PackedVector2Array, lengths: PackedFloat64Array, distance: float) -> Vector2:
	if points.is_empty():
		return Vector2.ZERO
	if distance <= 0.0 or points.size() == 1:
		return points[0]
	var last := points.size() - 1
	if distance >= lengths[last]:
		return points[last]
	# The first point at or past `distance` (binary search).
	var i := lengths.bsearch(distance, true)
	var span := lengths[i] - lengths[i - 1]
	if span <= 0.0:
		return points[i]
	return points[i - 1].lerp(points[i], (distance - lengths[i - 1]) / span)


## The point of the polyline closest to `point`: a dictionary with
## "position", "distance" (along the polyline) and "gap" (from `point`).
static func closest(points: PackedVector2Array, lengths: PackedFloat64Array, point: Vector2) -> Dictionary:
	var best := {"position": Vector2.ZERO, "distance": 0.0, "gap": INF}
	if points.size() == 1:
		return {"position": points[0], "distance": 0.0, "gap": point.distance_to(points[0])}
	for i in range(1, points.size()):
		var on := Geometry2D.get_closest_point_to_segment(point, points[i - 1], points[i])
		var gap := point.distance_to(on)
		if gap < best["gap"]:
			best = {"position": on, "distance": lengths[i - 1] + points[i - 1].distance_to(on), "gap": gap}
	return best
