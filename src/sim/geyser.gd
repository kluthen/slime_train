class_name Geyser
extends RefCounted
## EXPERIMENT (branch exp/geyser; D157 (5), O117): the geyser at the return
## route's end, "high and wide" (the variant the user kept, 2026-10-06). Not
## in the spec, no ATD atom yet. When a train slime reaches the end of the
## return route (the "finish line": its progress wraps past the loop's end,
## which is the loop's start, Train.lapped), it is lifted out from under the
## slimes piled over it and launched high and wide, onto a free spot of the
## loop LAND_MIN to LAND_MAX px from its start, so arrivals come down spread
## along the loop instead of piling up on one point (level rule 24).
##
## The lift. The arrival is first moved straight up above the slimes stacked
## over it (`lift_origin`: the highest ring overlapping its column, plus
## LIFT_GAP; at most LIFT_MAX px, the lifted ring clear of the terrain by
## CLEARANCE, else no lift), and flies from there: a launch from under the
## pile was smothered by it within a few ticks.
##
## The flight. CANDIDATES spots are drawn uniformly LAND_MIN to LAND_MAX px
## along the loop (the slime's centre lifted by its size above the loop
## there, LoopStart.landing_point), and an apex APEX px above the higher end
## of the flight, give or take APEX_JITTER. Of the spots that pass the
## landing limits below, the emptiest wins (room_at: the nearest slime's ring
## furthest; a slime in the air counted where it comes down). The slime gets
## the take-off velocity at once (Train.aim, ballistic; SlimeBodies.launch:
## its points' previous positions, as a hop's, and unsupported, so the
## train's grip doesn't brake it on the next tick): the solver is untouched,
## so it works the same on both ticks.
##
## The landing limits (O117), each draw checked in this order (`rejects`
## counts the reasons):
## - "gate": at or past the first gate along the loop (gate_limit), or on a
##   return route's slide: the geyser never skips a gate.
## - "zone": a fused slime lands only inside a split zone (on a level with
##   any), where it splits at once. A base slime may land past the start's
##   zone: the zone splits fused slimes and keeps the slimes inside it from
##   fusing (Fusion), nothing else, so for a base slime landing past it is the
##   walk out of the zone skipped; it may fuse there at once, as any train
##   slime leaving the zone does.
## - "ledge": not under nor beside a ledge rule 22 (b) guards (a terrain
##   piece a sleeper rests on, its top within a called base slime's reach of
##   the loop's ground there; guarded_ledges), the slime's ring kept
##   CLEARANCE px clear of the ledge's sides: a slime landing there, on the
##   slimes queued under it, bridged onto the ledge (test level: FirstLedge).
## - "route": where the slime comes to rest must be the loop's own route:
##   coming down the spot's column it stops on the terrain under the spot or
##   on the first slime in the column (a slime in the air where it comes
##   down), whichever is higher (rest_height), and that resting centre must
##   lie within Train.OFF_ROUTE px of the route point, as a train slime on
##   the route does. This keeps it off the queue stacked 2-3 deep on the
##   loop's first stretch (it landed 80-130 px above the loop, knocked off
##   the route) and off a spot with no ground under it.
## - "flight": the flight keeps CLEARANCE px between the slime's ring and
##   every terrain segment on the way (the ends' own neighbourhoods aside):
##   no flying into an overhang.
## - "room": off screen only (below), a spot where its ring would overlap
##   another slime's (LoopStart.is_free's test).
## With no draw passing them all, the arrival isn't lifted nor launched: it
## carries on as without the geyser (the plain arrival at the loop's start,
## followed by the train from there); `refused` counts them.
##
## Off screen (a parked slime, moved by Offscreen's proxy): no lift and no
## flight. It is put straight on the emptiest drawn spot that passes the
## limits (the flight's aside, the room's added), its progress moved there
## (Train.place), as the loop-start queue's moves do (D150): the proxy
## carries it on from there. With no such spot it stays in the proxies'
## single file, as without the geyser.
##
## Randomness: the derived stream "geyser:<tick>:<slime id>" (Rng.derive),
## the apex and all CANDIDATES draws taken every time: no draw from any other
## stream, same seed, same launches. Nothing is saved: a launch is only a
## velocity (in the bodies) or a progress (in the train record).
##
## `enabled` is a mode for the experiment's with/without runs (the same
## build): off with the user argument --no-geyser or SLIME_GEYSER=off
## (default_enabled()), or set by a test. Not in dump() nor saves.
## Runs in Simulation.step right after Train.follow (which, with Offscreen's
## proxies earlier in the tick, fills Train.lapped).

## How high the flight tops out above the higher of its two ends, px. About
## 40 % of the screen's height (648): a "high" geyser, seen from the
## normal zoom, still under the speed limit (take-off ~950 px/s).
const APEX := 260.0
## The apex varies by up to this share either way, so arrivals a few ticks
## apart don't fly the same arc.
const APEX_JITTER := 0.25
## Where along the loop a launched slime may land, px from its start. From
## LAND_MIN: past the start's hump, the hole the slides come up through and
## the terrace's first slimes (test level: x 362); to LAND_MAX: the user's
## "wide dispersion" (test level: the slope up from the terrace, x 867).
const LAND_MIN := 150.0
const LAND_MAX := 700.0
## How many landing spots are drawn per launch (the emptiest kept one wins).
const CANDIDATES := 10
## The room kept between the ring and the terrain along the flight, and
## between the ring and a guarded ledge's sides, px.
const CLEARANCE := 4.0
## How many points along the flight are checked against the terrain.
const SAMPLES := 16
## The take-off speed cap, as a share of SlimeBodies.max_speed.
const SPEED_SHARE := 0.95
## The lifted arrival's ring keeps this much room above the highest ring
## over it, px.
const LIFT_GAP := 6.0
## The furthest an arrival is lifted, px (about five base slimes stacked); a
## higher pile and it flies from where it is.
const LIFT_MAX := 240.0
## A sleeper rests on the terrain piece whose top is at most this far below
## its ring's bottom, px (the level checker's rule 22 (b) test,
## LevelRulesStart.RESTS_WITHIN).
const RESTS_WITHIN := 16.0
## Two outline points this close are the same vertex when a terrain piece's
## outline is walked (guarded_ledges), px.
const VERTEX_EPS := 0.01
## How many launches `launches_log` keeps (debug).
const LOG_SIZE := 64

## Whether arrivals are launched (see the class doc). Not saved.
var enabled := true
## Debug counters of the lift: how many arrivals were lifted, and by how
## much in all and at most (px).
var lifted := 0
var lift_total := 0.0
var lift_highest := 0.0
## Debug counters (the experiment's probe), not state: the arrivals seen
## (with or without the geyser), the launches made (flights and off-screen
## placements), and the arrivals not launched for want of a spot passing the
## limits.
var arrivals := 0
var launches := 0
var refused := 0
## The draws turned down, by reason ("gate", "zone", "ledge", "route",
## "flight", "room": see the class doc). Debug, not state.
var rejects := {}
## The latest LOG_SIZE launches, oldest first: {"id", "tick", "distance"
## (the landing spot along the loop), "parked" (bool), "at" (Vector2, the
## landing centre)}. Debug, not state.
var launches_log: Array[Dictionary] = []

## The first gate's distance along the loop (cached, -1.0 until known).
var _gate_limit := -1.0
## The ledges rule 22 (b) guards (cached by guarded_ledges; null until known).
var _ledges: Variant = null


func _init() -> void:
	enabled = default_enabled()


## Whether this run launches arrivals: false with the user argument
## --no-geyser or the environment variable SLIME_GEYSER=off.
static func default_enabled() -> bool:
	if OS.get_cmdline_user_args().has("--no-geyser"):
		return false
	return OS.get_environment("SLIME_GEYSER") != "off"


## Launches every train slime that reached the return route's end this tick
## (Train.lapped, emptied here), in id order (see the class doc).
func step(sim: Simulation) -> void:
	var train := sim.train
	if train == null or train.lapped.is_empty():
		return
	var ids := PackedInt32Array(train.lapped.keys())
	ids.sort()
	train.lapped.clear()
	for slime_id in ids:
		var bodies := sim.slimes
		if not bodies.has(slime_id) or bodies.state_of(slime_id) != SlimeBodies.TRAIN or not train.tracks(slime_id):
			continue
		arrivals += 1
		if enabled:
			launch(sim, slime_id)


## Launches train slime `slime_id` (see the class doc). Returns whether it
## was launched (or placed, parked).
func launch(sim: Simulation, slime_id: int) -> bool:
	var bodies := sim.slimes
	var train := sim.train
	var stream := sim.rng.derive("geyser:%d:%d" % [sim.tick, slime_id])
	var apex := APEX * (1.0 + stream.randf_range(-APEX_JITTER, APEX_JITTER))
	var parked := bodies.is_parked(slime_id)
	var size := bodies.size_of(slime_id)
	var from := bodies.centre_of(slime_id)
	var origin := from if parked else lift_origin(bodies, slime_id)
	var cap := bodies.max_speed * SPEED_SHARE
	var best_distance := -1.0
	var best_room := -INF
	var best_at := Vector2.ZERO
	var best_velocity := Vector2.ZERO
	for k in CANDIDATES:
		var distance := stream.randf_range(LAND_MIN, LAND_MAX)
		var at := LoopStart.landing_point(train, size, distance)
		var why := landing_limit(sim, slime_id, distance, at)
		var velocity := Vector2.ZERO
		if why == "" and not parked:
			velocity = Train.aim(origin, at, apex, bodies.gravity.y, cap)
			if not flight_clear(bodies, size, origin, velocity, at):
				why = "flight"
		var room := room_at(bodies, slime_id, at)
		# Off screen there is no flight to sort it out: only a free spot (no
		# ring there, LoopStart.is_free's test), else the proxy's single file.
		if why == "" and parked and room < SlimeBodies.ring_radius_for(size) + 2.0 * SlimeBodies.EDGE:
			why = "room"
		if why != "":
			rejects[why] = rejects.get(why, 0) + 1
			continue
		if room > best_room:
			best_room = room
			best_distance = distance
			best_at = at
			best_velocity = velocity
	if best_distance < 0.0:
		refused += 1
		return false
	if parked:
		bodies.translate(slime_id, best_at - from)
		train.place(slime_id, best_distance)
	else:
		if origin != from:
			bodies.translate(slime_id, origin - from)
			lifted += 1
			lift_total += from.y - origin.y
			lift_highest = maxf(lift_highest, from.y - origin.y)
		bodies.launch(slime_id, best_velocity)
	launches += 1
	launches_log.append({"id": slime_id, "tick": sim.tick, "distance": best_distance, "parked": parked,
			"at": best_at})
	if launches_log.size() > LOG_SIZE:
		launches_log.pop_front()
	return true


## Which of the landing limits (see the class doc) spot `at`, `distance` px
## along the loop, breaks for slime `slime_id`, the flight's and the room's
## aside: "gate", "zone", "ledge" or "route", or "" when it breaks none.
func landing_limit(sim: Simulation, slime_id: int, distance: float, at: Vector2) -> String:
	var bodies := sim.slimes
	var train := sim.train
	if distance >= gate_limit(sim) or train.is_slide_at(distance):
		return "gate"
	if bodies.size_of(slime_id) > 1 and not sim.split_zones.zones.is_empty() and not sim.split_zones.covers(at):
		return "zone"
	var radius := bodies.radius_of(slime_id)
	if under_ledge(bodies.terrain, guarded_ledges(sim), at, radius, bodies.gravity.y):
		return "ledge"
	var rest := rest_height(bodies, slime_id, at)
	if is_nan(rest) or Vector2(at.x, rest).distance_to(train.position_at(distance)) > Train.OFF_ROUTE:
		return "route"
	return ""


## Where arrival `slime_id` flies from: its centre lifted straight up so its
## ring clears, by LIFT_GAP, every ring overlapping its column above it (the
## pile over the hole), or its centre when nothing is over it, the lift would
## exceed LIFT_MAX, or the lifted ring would come within CLEARANCE px of the
## terrain.
static func lift_origin(bodies: SlimeBodies, slime_id: int) -> Vector2:
	var from := bodies.centre_of(slime_id)
	var radius := bodies.radius_of(slime_id)
	var y := from.y
	for other in bodies.ids():
		if other == slime_id:
			continue
		var q := bodies.centre_of(other)
		var r := bodies.radius_of(other)
		if absf(q.x - from.x) < radius + r and q.y <= from.y + radius:
			y = minf(y, q.y - r - radius - LIFT_GAP)
	if y >= from.y or from.y - y > LIFT_MAX:
		return from
	var origin := Vector2(from.x, y)
	var terrain := bodies.terrain
	if terrain != null:
		var reach := radius + CLEARANCE
		for k in terrain.seg_a.size():
			var on := Geometry2D.get_closest_point_to_segment(origin, terrain.seg_a[k], terrain.seg_b[k])
			if origin.distance_to(on) < reach:
				return from
	return origin


## The distance along the loop of the first gate (the loop point nearest any
## of the level's gate boxes' centres), INF on a level without gates or a
## train. Cached: the level doesn't change.
func gate_limit(sim: Simulation) -> float:
	if _gate_limit >= 0.0:
		return _gate_limit
	_gate_limit = INF
	if sim.level != null and sim.level.loop != null and sim.train != null:
		for gate_id in sim.level.gates:
			var box: Rect2 = sim.level.gates[gate_id]["box"]
			var d: float = sim.level.loop.closest(box.get_center(), sim.train.open_gates)["distance"]
			_gate_limit = minf(_gate_limit, d)
	return _gate_limit


## The ledges rule 22 (b) guards: the terrain pieces the level's sleepers
## rest on (the piece whose top, facing up, lies under a sleeper within its
## ring's bottom plus RESTS_WITHIN px), each as its outline's segment
## indices (walked from that top segment, vertex to vertex). Whether a piece
## overhangs a spot within reach is under_ledge's test. Cached: the level
## doesn't change. Empty without terrain or sleepers.
func guarded_ledges(sim: Simulation) -> Array[PackedInt32Array]:
	if _ledges != null:
		return _ledges
	var out: Array[PackedInt32Array] = []
	var terrain := sim.slimes.terrain
	if terrain != null and sim.level != null:
		var below := SlimeBodies.ring_radius_for(1) + SlimeBodies.EDGE + RESTS_WITHIN
		for sleeper_id in sim.level.sleepers:
			var at: Vector2 = sim.level.sleepers[sleeper_id]["position"]
			var k := _top_under(terrain, at, below)
			if k >= 0:
				var outline := _outline(terrain, k)
				if not out.has(outline):
					out.append(outline)
	_ledges = out
	return out


## The terrain segment facing up whose height at `at`.x lies 0 to `below` px
## under `at`, the nearest, or -1.
static func _top_under(terrain: TerrainSegments, at: Vector2, below: float) -> int:
	var best := -1
	var best_gap := INF
	for k in terrain.seg_a.size():
		var a := terrain.seg_a[k]
		var b := terrain.seg_b[k]
		if terrain.seg_n[k].y >= 0.0 or a.x == b.x or at.x < minf(a.x, b.x) or at.x > maxf(a.x, b.x):
			continue
		var gap := lerpf(a.y, b.y, (at.x - a.x) / (b.x - a.x)) - at.y
		if gap >= 0.0 and gap <= below and gap < best_gap:
			best = k
			best_gap = gap
	return best


## The segments of the closed terrain outline segment `first` is on, sorted:
## walked from each segment's end to the segment starting there.
static func _outline(terrain: TerrainSegments, first: int) -> PackedInt32Array:
	var out := PackedInt32Array([first])
	var k := first
	for n in terrain.seg_a.size():
		var next := -1
		for j in terrain.seg_a.size():
			if terrain.seg_a[j].distance_to(terrain.seg_b[k]) <= VERTEX_EPS:
				next = j
				break
		if next < 0 or next == first:
			break
		out.append(next)
		k = next
	out.sort()
	return out


## Whether a slime of ring radius `radius` resting at `at` would be under or
## beside one of `ledges` (guarded_ledges, outlines in `terrain`): some part
## of the ledge's outline within its ring's width plus CLEARANCE px either
## side of `at` lies above its ring's top, and the ledge's top there is
## within a called base slime's reach (FreeSlimes.max_rise, at `gravity`) of
## the ground (its ring's bottom), as rule 22 (b) measures.
static func under_ledge(terrain: TerrainSegments, ledges: Array[PackedInt32Array], at: Vector2, radius: float,
		gravity: float) -> bool:
	if ledges.is_empty():
		return false
	var ring := radius + SlimeBodies.EDGE
	var reach := FreeSlimes.max_rise(1, gravity)
	var left := at.x - ring - CLEARANCE
	var right := at.x + ring + CLEARANCE
	for outline in ledges:
		var top := INF
		for k in outline:
			var a := terrain.seg_a[k]
			var b := terrain.seg_b[k]
			var x0 := maxf(left, minf(a.x, b.x))
			var x1 := minf(right, maxf(a.x, b.x))
			if x0 > x1:
				continue
			# The highest point of the segment's part between x0 and x1.
			var high := minf(a.y, b.y)
			if a.x != b.x:
				high = minf(lerpf(a.y, b.y, (x0 - a.x) / (b.x - a.x)), lerpf(a.y, b.y, (x1 - a.x) / (b.x - a.x)))
			if high < at.y - ring:
				top = minf(top, high)
		if top < INF and at.y + ring - top <= reach:
			return true
	return false


## The height (y) slime `slime_id` comes to rest at when it comes down spot
## `at`'s column: on the terrain under it (its ring's bottom on the first
## terrain surface met going down from Train.OFF_ROUTE px over its ring's
## top, at most Train.OFF_ROUTE px under its bottom; only surfaces facing
## up), or on the slimes in the
## column (their rings touching its ring; a slime in the air counted where
## it comes down to `at`'s height), whichever is higher. NAN with no terrain
## under the spot within that reach.
static func rest_height(bodies: SlimeBodies, slime_id: int, at: Vector2) -> float:
	var radius := bodies.radius_of(slime_id) + SlimeBodies.EDGE
	var rest := NAN
	var terrain := bodies.terrain
	if terrain == null:
		return rest
	var top := Vector2(at.x, at.y - radius - Train.OFF_ROUTE)
	var bottom := Vector2(at.x, at.y + radius + Train.OFF_ROUTE)
	for k in terrain.seg_a.size():
		if terrain.seg_n[k].y >= 0.0:
			continue
		var hit: Variant = Geometry2D.segment_intersects_segment(top, bottom, terrain.seg_a[k], terrain.seg_b[k])
		if hit != null and (is_nan(rest) or hit.y - radius < rest):
			rest = hit.y - radius
	if is_nan(rest):
		return rest
	for other in bodies.ids():
		if other == slime_id:
			continue
		var q := where_down(bodies, other, at.y)
		var reach := radius + bodies.radius_of(other) + SlimeBodies.EDGE
		var dx := absf(q.x - at.x)
		if dx < reach:
			rest = minf(rest, q.y - sqrt(reach * reach - dx * dx))
	return rest


## Where slime `other` is, for a slime landing at height `y`: a slime in the
## air (unsupported, awake) where its ballistic path (from its velocity)
## comes down to `y`, any other where it is.
static func where_down(bodies: SlimeBodies, other: int, y: float) -> Vector2:
	var s := bodies.index_of(other)
	var q := bodies.centre_of(other)
	if bodies.supported[s] == 0 and bodies.calm[s] == SlimeBodies.ACTIVE:
		var velocity := bodies.velocity_of(other)
		var t := time_down_to(q, velocity, bodies.gravity.y, y)
		if t > 0.0:
			return Vector2(q.x + velocity.x * t, y)
	return q


## The time a ballistic flight from `from` at `velocity` under `gravity`
## (px/s², down) takes to come down to height `y`, or -1.0 when it never
## does (it stays above).
static func time_down_to(from: Vector2, velocity: Vector2, gravity: float, y: float) -> float:
	# from.y + vy t + g t² / 2 = y, the later root.
	var disc := velocity.y * velocity.y + 2.0 * gravity * (y - from.y)
	if disc < 0.0 or gravity <= 0.0:
		return -1.0
	var t := (-velocity.y + sqrt(disc)) / gravity
	return t if t >= 0.0 else -1.0


## Whether a slime of `size` flying from `from` at `velocity` down onto `at`
## keeps CLEARANCE px between its ring and every terrain segment on the way,
## SAMPLES points along the flight, those within a ring's width of either
## end aside (the ground it leaves and lands on).
static func flight_clear(bodies: SlimeBodies, size: int, from: Vector2, velocity: Vector2, at: Vector2) -> bool:
	var gravity := bodies.gravity.y
	var total := time_down_to(from, velocity, gravity, at.y)
	if total <= 0.0:
		return false
	var terrain := bodies.terrain
	if terrain == null:
		return true
	var reach := SlimeBodies.ring_radius_for(size) + CLEARANCE
	var ends := 2.0 * SlimeBodies.ring_radius_for(size) + CLEARANCE
	# Only the segments near the flight's box.
	var top := from.y + velocity.y * velocity.y / (-2.0 * gravity) if velocity.y < 0.0 else minf(from.y, at.y)
	var box := Rect2(Vector2(minf(from.x, at.x), minf(top, minf(from.y, at.y))), Vector2.ZERO)
	box = box.expand(Vector2(maxf(from.x, at.x), maxf(from.y, at.y))).grow(reach)
	var near := []
	for k in terrain.seg_a.size():
		var a := terrain.seg_a[k]
		var b := terrain.seg_b[k]
		if Rect2(a, Vector2.ZERO).expand(b).grow(1.0).intersects(box):
			near.append(k)
	for i in range(1, SAMPLES):
		var t := total * i / SAMPLES
		var p := from + velocity * t + Vector2(0.0, 0.5 * gravity * t * t)
		if p.distance_to(from) < ends or p.distance_to(at) < ends:
			continue
		for k: int in near:
			var on := Geometry2D.get_closest_point_to_segment(p, terrain.seg_a[k], terrain.seg_b[k])
			if p.distance_to(on) < reach:
				return false
	return true


## How much room a slime landing at `at` would have: the distance to the
## nearest other slime's ring (centre distance less its radius), a slime in
## the air counted where it comes down to `at`'s height (where_down). INF
## with no other slime.
static func room_at(bodies: SlimeBodies, slime_id: int, at: Vector2) -> float:
	var room := INF
	for other in bodies.ids():
		if other != slime_id:
			room = minf(room, where_down(bodies, other, at.y).distance_to(at) - bodies.radius_of(other))
	return room
