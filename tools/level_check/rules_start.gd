class_name LevelRulesStart
extends RefCounted
## Level rule 22, the start (D117, D123), for LevelChecker, in two parts:
## (a) a return route delivers slimes into the start behind the loop's
## start, never along the loop's first stretch against the flow;
## (b) nothing a base slime must be called up to overhangs the loop where
## larger slimes pass.

## The loop's first stretch, px along it from its start.
const FIRST_STRETCH := 1.5 * LevelData.SCREEN
## Around the loop's start the return route joins it: px.
const JOIN := 80.0
## The closest a return route may run to the first stretch outside the
## join: two size-1 slime radii, px.
const CLEARANCE := 2.0 * PlaceholderArt.SLIME_RADIUS
## How often the return routes are sampled, px.
const ROUTE_SAMPLE := 8.0
## A sleeper rests on the terrain piece whose top is at most this far below
## its body's bottom, px.
const RESTS_WITHIN := 16.0
## How often a ledge is sampled across its width, px.
const LEDGE_SAMPLE := 8.0


## Rule 22, both parts.
static func the_start(c: LevelChecker) -> Dictionary:
	var findings := behind_the_train(c)
	var notes := []
	findings.append_array(called_ledges(c, notes))
	return LevelChecker.result(22, findings, "only terrain holding a sleeper is checked for a low overhang: a "
			+ "ledge a slime is called up to for anything else (a bough, a lookout) is checked by eye", notes)


## How high over the ground a train slime of `size` tops out when it hops
## along the loop, px: its body's height at rest (twice its ring radius
## plus the ring's edge) plus the apex the train aims over the route
## (Train.hop_apex). About 82 (size 1), 108 (size 2) and 130 (size 3).
static func hop_top(size: int) -> float:
	return 2.0 * (SlimeBodies.ring_radius_for(size) + SlimeBodies.EDGE) + Train.hop_apex(size)


## How high over the ground a called base slime can hop up onto a ledge, px
## (FreeSlimes.max_rise at the slime bodies' gravity): about 133.
static func called_reach() -> float:
	return FreeSlimes.max_rise(1, SlimeBodies.new(Rng.new(0)).gravity.length())


## Part (a): in every gate state, no point of the current return route
## farther than JOIN from the loop's start comes within CLEARANCE of the
## loop's first stretch.
# @spec-link [[rule_return_route_joins_start_behind_train]]
static func behind_the_train(c: LevelChecker) -> Array:
	var findings := []
	var loop := c.data.loop
	var start := loop.position_at(0.0)
	for section in c.sections():
		var gates := c.gates_before(section)
		var current := loop.current_segments(gates)
		var route: Dictionary = current[current.size() - 1]
		if route["kind"] != LoopData.RETURN:
			continue
		var stretch := PackedVector2Array()
		var along := 0.0
		while along <= minf(FIRST_STRETCH, loop.length(gates) - route["length"]):
			stretch.append(loop.position_at(along, gates))
			along += 4.0
		var bounds := Rect2(stretch[0], Vector2.ZERO)
		for point in stretch:
			bounds = bounds.expand(point)
		bounds = bounds.grow(CLEARANCE)
		var near := INF
		var where := Vector2.ZERO
		along = 0.0
		while along <= route["length"]:
			var at := Polyline.point_at(route["points"], route["lengths"], along)
			along += ROUTE_SAMPLE
			if at.distance_to(start) <= JOIN or not bounds.has_point(at):
				continue
			var gap := _gap(stretch, at)
			if gap < near:
				near = gap
				where = at
		if near < CLEARANCE:
			findings.append(LevelChecker.finding(route["id"], where.x,
					"with the loop at section %d it runs %.0f px from the loop's first %.1f screens (at least %.0f): "
					% [section, near, FIRST_STRETCH / LevelData.SCREEN, CLEARANCE]
					+ "bring it home behind the loop's start, so slimes coming home join behind the train"))
	return findings


## The distance from `point` to the polyline `points`, px.
static func _gap(points: PackedVector2Array, point: Vector2) -> float:
	var best := INF
	for k in range(1, points.size()):
		best = minf(best, point.distance_to(Geometry2D.get_closest_point_to_segment(point, points[k - 1], points[k])))
	return best


## Part (b): for each sleeper, the terrain piece it rests on; wherever an
## outgoing route of the loop passes under that piece with its underside
## lower than a size-3 train slime's hop reaches over the loop's ground
## (hop_top), and its top within a called base slime's reach from that
## ground (called_reach), the loop there must be inside a split zone, where
## only base slimes pass. The loop's ground is its route plus a base slime's
## radius (the route runs at a base slime's centre height). Return routes
## aren't checked: slimes are carried along them, not hopping (Train).
# @spec-link [[rule_no_called_ledge_over_loop]]
static func called_ledges(c: LevelChecker, notes: Array) -> Array:
	var reach := called_reach()
	var hop := hop_top(SlimeBodies.MAX_SIZE)
	var pieces := c.terrain_pieces()
	var routes := []
	for segment in c.data.loop.segments:
		if segment["kind"] == LoopData.OUTGOING:
			routes.append(segment["points"])
	var findings := []
	var ids := c.data.sleepers.keys()
	ids.sort()
	var passed := []
	for id in ids:
		var at: Vector2 = c.data.sleepers[id]["position"]
		var piece := _resting_piece(pieces, at)
		if piece.is_empty():
			continue
		var over := _overhang(c, piece["polygon"], routes, hop, reach)
		if over.is_empty():
			continue
		if not over["outside"].is_empty():
			var xs: Array = over["outside"]
			findings.append(LevelChecker.finding(id, at.x,
					"it rests on %s, which overhangs the loop from x %.2f to %.2f only %.0f px over the loop's ground "
					% [piece["node"], xs[0] / LevelData.SCREEN, xs[xs.size() - 1] / LevelData.SCREEN, over["clearance"]]
					+ ("(a size-3 train slime's hop reaches %.0f px), its top %.0f px up, "
					+ "within a called base slime's reach (%.0f px): ") % [hop, over["top"], reach]
					+ "move the ledge off the loop's path or out of reach, or extend the split zone over it"))
		else:
			passed.append(id)
	if not passed.is_empty():
		notes.append("called ledges over the loop inside a split zone (only base slimes pass): %s" % ", ".join(passed))
	notes.append("a called ledge: its top at most %.0f px over the loop's ground, its underside under %.0f px"
			% [reach, hop])
	return findings


## The terrain piece sleeper centre `at` rests on (its top right under the
## body), or {}.
static func _resting_piece(pieces: Array, at: Vector2) -> Dictionary:
	var best := {}
	var best_gap := INF
	for piece in pieces:
		for span in LevelGeometry.spans(piece["polygon"], at.x):
			var gap: float = span.x - at.y
			if gap >= 0.0 and gap <= PlaceholderArt.SLIME_RADIUS + RESTS_WITHIN and gap < best_gap:
				best = piece
				best_gap = gap
	return best


## Where `polygon` overhangs the loop's outgoing `routes` too low for a
## size-3 hop and within a called slime's reach: {"outside" (the xs, px,
## outside every split zone), "inside" (within one), "clearance" and "top"
## (the lowest underside and its top over the loop's ground there, px)}, or
## {} when it overhangs nowhere so.
static func _overhang(c: LevelChecker, polygon: PackedVector2Array, routes: Array, hop: float,
		reach: float) -> Dictionary:
	var extent := LevelGeometry.x_extent(polygon)
	var out := {"outside": [], "inside": [], "clearance": INF, "top": 0.0}
	var x := extent.x
	while x <= extent.y:
		var spans := LevelGeometry.spans(polygon, x)
		var route_ys := PackedFloat64Array()
		for points in routes:
			route_ys.append_array(LevelGeometry.crossings(points, x))
		for route_y in route_ys:
			var ground: float = route_y + PlaceholderArt.SLIME_RADIUS
			var ledge := _span_above(spans, route_y)
			if is_inf(ledge.x) or ground - ledge.y >= hop or ground - ledge.x > reach:
				continue
			var inside := _in_split_zone(c, Vector2(x, route_y))
			out["inside" if inside else "outside"].append(x)
			if not inside and ground - ledge.y < out["clearance"]:
				out["clearance"] = ground - ledge.y
				out["top"] = ground - ledge.x
		x += LEDGE_SAMPLE
	return out if not (out["outside"].is_empty() and out["inside"].is_empty()) else {}


## The lowest of `spans` ([top, bottom] pairs) whose bottom is above level y
## `y`, or Vector2(INF, -INF).
static func _span_above(spans: Array[Vector2], y: float) -> Vector2:
	var best := Vector2(INF, -INF)
	for span in spans:
		if span.y < y and span.y > best.y:
			best = span
	return best


## Whether `point` is inside one of the level's split zones.
static func _in_split_zone(c: LevelChecker, point: Vector2) -> bool:
	for zone in c.data.split_zones.values():
		if (zone as Rect2).has_point(point):
			return true
	return false
