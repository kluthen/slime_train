class_name LevelGeometry
extends RefCounted
## Plain geometry for the level-rules checker (LevelChecker): overlaps
## between outlines, boxes and circles, and where a vertical line crosses a
## route or a terrain piece. Level pixels, y grows downward. Pure functions.

## How many sides the polygon standing in for a circle has.
const CIRCLE_SIDES := 24
## A dip's wall ends where the route drops more than this below its top, px
## (smaller wiggles are part of the wall).
const RIM_TOLERANCE := 16.0


## The four corners of `box`, as a polygon.
static func box_polygon(box: Rect2) -> PackedVector2Array:
	return PackedVector2Array([box.position, Vector2(box.end.x, box.position.y), box.end,
			Vector2(box.position.x, box.end.y)])


## A polygon standing in for the circle of `radius` round `centre`.
static func circle_polygon(centre: Vector2, radius: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in CIRCLE_SIDES:
		out.append(centre + Vector2.from_angle(TAU * k / CIRCLE_SIDES) * radius)
	return out


## Whether the two polygons overlap (share some area, or one holds the other).
static func polygons_overlap(a: PackedVector2Array, b: PackedVector2Array) -> bool:
	if a.size() < 3 or b.size() < 3:
		return false
	return not Geometry2D.intersect_polygons(a, b).is_empty()


## Whether the polyline `points` passes through `box` (a point inside, or an
## edge crossing it).
static func polyline_meets_box(points: PackedVector2Array, box: Rect2) -> bool:
	for point in points:
		if box.has_point(point):
			return true
	return not Geometry2D.intersect_polyline_with_polygon(points, box_polygon(box)).is_empty()


## The y of every point where the polyline `points` crosses the vertical
## line at `x` (a vertical edge on the line counts by its ends; a point
## shared by two edges may come twice).
static func crossings(points: PackedVector2Array, x: float) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	for k in range(1, points.size()):
		var a := points[k - 1]
		var b := points[k]
		if is_equal_approx(a.x, b.x):
			if is_equal_approx(a.x, x):
				out.append_array([a.y, b.y])
		elif x >= minf(a.x, b.x) and x <= maxf(a.x, b.x):
			out.append(lerpf(a.y, b.y, (x - a.x) / (b.x - a.x)))
	return out


## The solid spans of the closed `polygon` along the vertical line at `x`:
## [top, bottom] pairs of y, top to bottom (even-odd over its edges).
static func spans(polygon: PackedVector2Array, x: float) -> Array[Vector2]:
	var ys: Array[float] = []
	for k in polygon.size():
		var a := polygon[k]
		var b := polygon[(k + 1) % polygon.size()]
		# Half-open in x, so a vertex on the line counts once.
		if (a.x <= x) == (b.x <= x):
			continue
		ys.append(lerpf(a.y, b.y, (x - a.x) / (b.x - a.x)))
	ys.sort()
	var out: Array[Vector2] = []
	for k in range(0, ys.size() - 1, 2):
		out.append(Vector2(ys[k], ys[k + 1]))
	return out


## The polyline `route` sampled every `step` px along each edge, every one of
## its points included.
static func sample(route: PackedVector2Array, step: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in range(1, route.size()):
		var along := 0.0
		var edge := route[k - 1].distance_to(route[k])
		while along < edge:
			out.append(route[k - 1].move_toward(route[k], along))
			along += step
	if not route.is_empty():
		out.append(route[route.size() - 1])
	return out


## The dips of the route sampled as `points` (left to right, y down): low
## points at least `depth` px below both rims. A rim is the top of the dip's
## wall on that side: the highest point the route climbs to before it drops
## again by more than RIM_TOLERANCE (or ends). Each {"x", "y" (the lowest
## point), "depth" (below the lower rim), "from_x", "to_x" (where each wall
## is back up at the lower rim's height: the dip's brim)}; one per dip (its
## lowest point, the first when level).
static func dips(points: PackedVector2Array, depth: float) -> Array:
	var found := []
	for k in range(1, points.size() - 1):
		if not (points[k].y > points[k - 1].y and points[k].y >= points[k + 1].y):
			continue
		var left := _rim(points, k, -1)
		var right := _rim(points, k, 1)
		var brim := maxf(points[left].y, points[right].y)
		if points[k].y - brim < depth:
			continue
		var from := k
		while from > left and points[from].y > brim:
			from -= 1
		var to := k
		while to < right and points[to].y > brim:
			to += 1
		found.append({"k": k, "x": points[k].x, "y": points[k].y, "depth": points[k].y - brim,
				"from_x": points[from].x, "to_x": points[to].x})
	var out := []
	for dip in found:
		var lowest := true
		for other in found:
			lowest = lowest and not (other["x"] >= dip["from_x"] and other["x"] <= dip["to_x"]
					and (other["y"] > dip["y"] or other["y"] == dip["y"] and other["k"] < dip["k"]))
		if lowest:
			dip.erase("k")
			out.append(dip)
	return out


## The top of the wall from `k` going `way` (-1 or 1): the highest point
## before the route drops more than RIM_TOLERANCE below it, gets lower than
## at `k`, or ends. Its index.
static func _rim(points: PackedVector2Array, k: int, way: int) -> int:
	var best := k
	var j := k + way
	while j >= 0 and j < points.size() and points[j].y <= points[k].y \
			and points[j].y <= points[best].y + RIM_TOLERANCE:
		if points[j].y < points[best].y:
			best = j
		j += way
	return best


## The x-extent of `polygon`: Vector2(left, right).
static func x_extent(polygon: PackedVector2Array) -> Vector2:
	var out := Vector2(INF, -INF)
	for point in polygon:
		out = Vector2(minf(out.x, point.x), maxf(out.y, point.x))
	return out
