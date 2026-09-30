class_name MidairLanding
extends RefCounted
## The mid-air rule on load (master spec §5.10, D12, DoD 28; chunk 19): no
## slime is left in mid-air when a save is loaded. Pure logic over the
## Simulation, no scene nodes, no randomness; SaveData.restore applies it last.
##
## A slime is in the air when its body is not supported (SlimeBodies:
## touching no ground, terrain facing up or another slime from above, during
## the last tick), it is neither a sleeper nor in a basket (those stay where
## they were saved), and it is not parked. A slime resting on another slime is
## supported, so it is left as it is. A slime of a hand-made save without a
## body (a rest ring at its centre) is not supported yet, so it is put down
## too (by nothing, or a pixel or so, when its centre is at rest height). A
## parked slime (off screen, Offscreen)
## is neither simulated nor touched: Offscreen puts it where it goes (on the
## loop, on its route back), and once simulated again it falls like any body,
## just outside the view, so it is left as it is and is nothing to land on.
##
## Grounded. A slime in the air is moved straight down, its whole body by one
## distance, onto the first surface below it: the terrain's and the shut
## doors' surfaces facing up (a ring point stays SlimeBodies.terrain_skin
## off them, as the terrain contact keeps it), or the upper side of another
## slime's ring (a ring point rests on it). It is put down at rest (previous
## points = points: no velocity) and marked supported. A slime already
## touching what is below it (just landing) moves by less than a pixel, or not
## at all: it never moves up. The slimes in the air are put down lowest first
## (the lowest ring point, then the id), so one above another lands on it once
## that one is down; a slime still in the air is nothing to land on.
##
## Lost. A slime in the air with no surface anywhere below it (beyond the
## level's edge) is lost the usual way (Offscreen.lose: to the loop start,
## back on the train, in the lost log), after every other one is down.
## Without a train (a level with no loop) Offscreen.lose does nothing, and
## the slime stays where it was.
# @spec-link [[req_persistence_and_saves]]


## Puts every slime of `sim` in the air on the ground below it, or loses it
## when there is nothing below (see the class doc). Returns the ids lost.
# @spec-link [[req_persistence_and_saves]]
static func apply(sim: Simulation) -> PackedInt32Array:
	var bodies := sim.slimes
	var falling: Array[int] = []
	var lowest := {}
	# Nothing to land on: the parked slimes, and the slimes still in the air.
	var ignored := {}
	for slime_id in bodies.ids():
		if bodies.is_parked(slime_id):
			ignored[slime_id] = true
		elif _in_the_air(bodies, slime_id):
			falling.append(slime_id)
			lowest[slime_id] = _lowest(bodies.points_of(slime_id))
			ignored[slime_id] = true
	falling.sort_custom(func(a: int, b: int) -> bool:
		return lowest[a] > lowest[b] or (lowest[a] == lowest[b] and a < b))
	var lost := PackedInt32Array()
	for slime_id in falling:
		var fall := _fall(sim, slime_id, ignored)
		if fall == INF:
			lost.append(slime_id)
		else:
			_put_down(bodies, slime_id, fall)
			ignored.erase(slime_id)
	for slime_id in lost:
		sim.offscreen.lose(sim, slime_id)
	return lost


## Whether unparked slime `slime_id` is in the air: unsupported, not a
## sleeper, not in a basket.
static func _in_the_air(bodies: SlimeBodies, slime_id: int) -> bool:
	var state := bodies.state_of(slime_id)
	if state == SlimeBodies.SLEEPER or state == SlimeBodies.IN_BASKET:
		return false
	return not bodies.body_of(slime_id)["supported"]


## Moves slime `slime_id` down by `fall` px, at rest and supported.
static func _put_down(bodies: SlimeBodies, slime_id: int, fall: float) -> void:
	var body := bodies.body_of(slime_id)
	var points: PackedVector2Array = body["points"]
	for k in points.size():
		points[k].y += fall
	body["points"] = points
	body["previous"] = points.duplicate()
	body["centre"] = body["centre"] + Vector2(0.0, fall)
	body["supported"] = true
	bodies.set_body(slime_id, body)


## How far slime `slime_id` goes straight down before it rests on a surface
## (0 or more), or INF when there is none below it. The slimes in `ignored`
## (parked, still in the air, or lost; itself too) are nothing to land on.
static func _fall(sim: Simulation, slime_id: int, ignored: Dictionary) -> float:
	var bodies := sim.slimes
	var points := bodies.points_of(slime_id)
	var span := _span(points)
	var fall := INF
	var solids: Array[TerrainSegments] = []
	if bodies.terrain != null:
		solids.append(bodies.terrain)
	solids.append_array(bodies.doors)
	for solid in solids:
		fall = minf(fall, _fall_onto_solid(points, span, solid, bodies.terrain_skin))
	for other in bodies.ids():
		if ignored.has(other) or not _may_be_under(span, bodies.centre_of(other),
				2.0 * bodies.radius_of(other)):
			continue
		fall = minf(fall, _fall_onto_ring(points, span, bodies.points_of(other), bodies.centre_of(other)))
	return maxf(fall, 0.0) if fall != INF else INF


## The fall of `points` (spanning `span`: min x, max x, min y) onto the
## surfaces of `solid` facing up, each point staying `skin` off them; INF
## when none is below.
static func _fall_onto_solid(points: PackedVector2Array, span: Rect2, solid: TerrainSegments,
		skin: float) -> float:
	var fall := INF
	for k in solid.segment_count():
		var a := solid.seg_a[k]
		var b := solid.seg_b[k]
		if solid.seg_n[k].y >= 0.0 or not _under(a, b, span):
			continue
		fall = minf(fall, _fall_onto_segment(points, a, b) - skin)
	return fall


## The fall of `points` (spanning `span`) onto the upper side of the ring
## `ring` around `ring_centre`; INF when it isn't below them.
static func _fall_onto_ring(points: PackedVector2Array, span: Rect2, ring: PackedVector2Array,
		ring_centre: Vector2) -> float:
	var fall := INF
	var n := ring.size()
	for k in n:
		var a := ring[k]
		var b := ring[(k + 1) % n]
		if ((a + b) * 0.5 - ring_centre).y >= 0.0 or not _under(a, b, span):
			continue
		fall = minf(fall, _fall_onto_segment(points, a, b))
	return fall


## Whether a ring around `ring_centre`, no point of it further than `reach`
## from it (a squashed ring stays well within twice its radius), may lie
## below points spanning `span` (a quick test before _fall_onto_ring).
static func _may_be_under(span: Rect2, ring_centre: Vector2, reach: float) -> bool:
	return (ring_centre.x + reach >= span.position.x and ring_centre.x - reach <= span.end.x
			and ring_centre.y + reach >= span.position.y - TerrainSegments.MARGIN)


## Whether segment `a`-`b` may lie below points spanning `span`: it overlaps
## them across and reaches no higher than TerrainSegments.MARGIN above them.
static func _under(a: Vector2, b: Vector2, span: Rect2) -> bool:
	return (maxf(a.x, b.x) >= span.position.x and minf(a.x, b.x) <= span.end.x
			and maxf(a.y, b.y) >= span.position.y - TerrainSegments.MARGIN)


## The shortest vertical distance from one of `points` down to segment
## `a`-`b`, INF when it is under none of them. A segment a little above a
## point (within TerrainSegments.MARGIN: the point sank into it) gives a
## negative distance.
static func _fall_onto_segment(points: PackedVector2Array, a: Vector2, b: Vector2) -> float:
	var dx := b.x - a.x
	if absf(dx) < 1e-6:
		return INF
	var low_x := minf(a.x, b.x)
	var high_x := maxf(a.x, b.x)
	var fall := INF
	for p in points:
		if p.x < low_x or p.x > high_x:
			continue
		var y := a.y + (b.y - a.y) * (p.x - a.x) / dx
		var gap := y - p.y
		if gap >= -TerrainSegments.MARGIN:
			fall = minf(fall, gap)
	return fall


## The box of `points`.
static func _span(points: PackedVector2Array) -> Rect2:
	var box := Rect2(points[0], Vector2.ZERO)
	for p in points:
		box = box.expand(p)
	return box


## The y of the lowest of `points` (the largest y).
static func _lowest(points: PackedVector2Array) -> float:
	var low := -INF
	for p in points:
		low = maxf(low, p.y)
	return low
