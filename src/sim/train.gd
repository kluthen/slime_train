class_name Train
extends RefCounted
## The train: moves the train slimes along the loop (master spec §5.1-5.3).
## Plain data and pure logic over SlimeBodies, no scene nodes.
##
## Progress. Each train slime has a progress along the current loop: a
## distance from the loop's start plus the laps it has completed. The loop is
## a target, not a constraint: the slime is a soft body moved by physics
## (squish, bumps, landing short), and its progress is re-derived after every
## tick by projecting its centre onto the loop. The projection only looks at
## a window just ahead of the last progress (PROGRESS_WINDOW), so progress
## never goes back and never jumps across the level to a part of the loop that
## happens to pass close by (the slide runs under the outgoing route). Past
## the end of the loop it wraps: the slide ends at the start, a lap is done.
##
## Hops. The slime still hops on its own seeded timer (SlimeBodies); the train
## only aims each hop: at the point of the loop hop_reach() ahead of its
## progress, with a ballistic take-off that tops out hop_apex() above the
## highest point of the route between the two and lands on the target (see
## aim()). Where the route ahead rises steeply (a step it crosses in the air),
## the slime first hops to the foot of the step, then over it, onto the top
## (take-off from the foot keeps it clear of an overhang, and a big hop from
## further back would fly into whatever hangs above). Where it drops steeply
## (the slide entrance at the frontier, which falls back under the route), the
## slime hops DROP_OVER px out past the top of the drop and falls in. The
## take-off speed is capped (hop_cap()), so a big rise takes several hops.
##
## Grip. Rings roll freely (chunk 5), but "on a steep slope its hops can't
## hold it and it may roll" (master spec §5.2): on anything gentler they do.
## So while a train slime stands on the ground between hops, on a stretch of
## the route no steeper than GRIP_MAX_SLOPE, the train takes GRIP of its rigid
## motion away each tick (SlimeBodies.brake: no sliding or rolling, the squish
## is kept). Steeper, it rolls.
##
## Hold on a climb. GRIP alone only halves the motion: on a climb the slope's
## pull creeps a standing slime back down 5 to 17 px/s between hops, and a
## queue climbing out of a basin loses most of what it gains. So on the
## outgoing route, on a stretch rising more than HOLD_FROM (up to
## GRIP_MAX_SLOPE), an active train slime standing between hops also has its
## motion down the slope cancelled and is given HOLD_LIFT of the pull gravity
## puts along the slope in one tick, up the slope
## (SlimeBodies.hold_on_slope), so the tick's gravity brings it back nearly to
## rest where it was (alone on a rise it still slides about 1.6 px/s: the two
## substeps would need 0.75 to cancel it exactly). Its motion up the slope
## (the queue's push) is GRIP's. The return route's slide is left alone, and
## so is a slime knocked off the route: held where it steers from a point
## behind, its hops from there may skim a steep slope and be braked away
## (a stall rule 2's lap run found); it slides back to where they carry it.
##
## The relay. A packed queue moves at its hop timers' pace: a slime only gains
## ground once the one ahead has gone, and its own timer (1.5 to 3 s) mostly
## fires while it is still blocked (a micro hop). So when a train slime takes
## off, the train slime right behind it along the loop, if within its reach
## of touching it, standing (supported, not parked, not itself taking off) on
## the outgoing route, has its hop timer cut to RELAY_DELAY at most: it
## follows into the room just made, and so on down the queue, a wave. Only
## the one right behind, and not across a gap wider than its reach. The relay
## acts at the end of the take-off's tick (follow(), once progress is
## re-derived), so nothing about it crosses into the next tick but the cut
## hop timer, which is state and saved: a run reloaded from a save taken
## just after a take-off carries on as the run that never stopped. It adds
## no state.
##
## The slide. Placeholder (O22): on a return route the slime doesn't hop (it
## is held) and, while it touches the ground, it is carried along the route at
## SLIDE_SPEED. The real slide comes with the level art.
##
## Knocked off the route. A slime more than OFF_ROUTE px from the route point
## at its progress (bounced back out of a chute onto the ledge above, say)
## steers from the route point nearest it within PROGRESS_WINDOW behind its
## progress: it hops for the chute again instead of being held on the ledge.
## Its recorded progress never goes back.
##
## Stalled (D118, D121; "lost" is for free slimes only, D10). A train slime
## is stalled when its progress hasn't advanced STALL_ADVANCE px in
## STALL_SECONDS of the ticks it is simulated, or when its centre leaves
## `bounds` (the level's extent, bounds_for()). The stall clock pauses while
## the slime is parked (Offscreen; D150 (1), O113's default: every parked
## train slime): on each tick follow() finds it parked, its last mark's tick
## ("marked_at") moves on by one, so the time since the mark stays what it
## was, and once simulated again the clock resumes from there, not from zero.
## A parked line in single file (Offscreen) so waits as long as its front
## does. Progress while parked (at the off-screen pace) still marks, and a
## parked slime out of bounds is still stalled at once. Once its clock has
## run out the pause stops (there is nothing left to hold back): a stalled
## slime waiting its turn stays due from the tick it came due
## (stalled_since()), parked or not. The pause lives in the saved record (and
## parking in the saved calm): no save key of its own.
## A stalled slime is due a move to the loop start, back on the train: it
## waits its turn in the loop-start queue (LoopStartQueue, D150; out of
## bounds first), carrying on meanwhile; at its turn, still stalled, it is
## moved (LoopStart.move, the move lost and stuck slimes take too; its record
## starts afresh, so the 60 s count starts again from the move) and the case
## logged in `stalled` (log_stalled()) with the reason STALLED or
## OUT_OF_BOUNDS, every time. A slime asleep at bedtime is not a train slime:
## it has no record, so it is never counted nor moved, and at sunrise its
## count starts from its waking. The safety net is for play: the whole-level
## DoD 1 test still fails on any logged case.
##
## Tick order (Simulation.step): steer() before the bodies tick (aims the
## coming hops, holds and carries slimes on the slide), follow() after it and
## after the split zones (re-derives progress, notices new slimes, relays the
## tick's take-offs); the loop-start queue moves the stalled ones last.
##
## Hop counters (debug, the PERF line's hops and short_hops, D156 point 4).
## follow() counts every train hop (an automatic hop of a train slime,
## SlimeBodies.train_hopped; a celebration's hop() and a free slime's are not
## train hops, and a slime on a slide is held, it doesn't hop) at its take-off
## in hops_taken, and at its landing (the first follow() after it that finds
## the slime supported) in short_hops_taken when its progress advanced less
## than half its hop_reach() past its progress at take-off. A hop that never
## lands as a train slime (its state changed, moved to the start, parked) is
## no short hop. They only read the bodies: no draw, no change to the
## simulation, and neither they nor the take-offs are in dump() or in saves.
##
## The hop decision's record (debug, for the slime census,
## src/debug/slime_census.gd). hop_target() notes the kind of target it
## gave (last_target_kind: TARGET_AHEAD, TARGET_STEP_FOOT, TARGET_STEP_OVER,
## TARGET_DROP); steer() notes each hop it aims on the tick; follow() keeps
## each train slime's last train hop in last_hops (its take-off tick and
## progress, the kind and target of the aim it took off on, and at its
## landing the progress it advanced and whether it was short, as the hop
## counters count it). Like the counters they only read: not state, not in
## dump() nor saves.
# @spec-link [[req_loop_and_world]]
# @spec-link [[req_hopping_behavior]]
# @spec-link [[rule_loop_travelable_with_no_input]]
# @spec-link [[rule_all_sizes_travel_loop_v1]]
# @spec-link [[rule_stalled_train_slime_moved_to_start]]
# @spec-link [[req_offscreen_simulation]]
# @spec-link [[req_platform_and_performance_targets]]
# @spec-link [[req_persistence_and_saves]]

## How far ahead of its last progress (px) a slime's progress may move in one
## projection. A slime moves at most max_speed / 60 = 20 px per tick.
const PROGRESS_WINDOW := 400.0
## How far ahead along the loop a size-1 slime aims its hops, px.
const HOP_REACH := 150.0
## Extra reach per size above 1 (bigger slimes hop further).
const HOP_REACH_PER_SIZE := 0.2
## How high above the higher end of a hop a size-1 slime tops out, px.
const HOP_APEX := 34.0
## Extra apex height per size above 1 (bigger slimes hop higher).
const HOP_APEX_PER_SIZE := 0.25
## The hop take-off speed cap, as a share of SlimeBodies.hop_velocity's
## strength-1 speed for the size.
const HOP_CAP := 1.15
## A route edge rising steeper than this (rise over run) is a step: the hop
## target moves past it.
const STEEP_RISE := 1.5
## Within this distance (px along the loop) of a step's foot, a slime hops
## over the step; further back, it hops to STEP_FOOT px before the foot.
const STEP_NEAR := 40.0
const STEP_FOOT := 10.0
## How far past the top of a step the target moves, px along the loop.
const STEP_LANDING := 80.0
## How far past the top of a drop (a route edge falling steeper than
## STEEP_RISE) a slime aims, px, carrying on the way it was going.
const DROP_OVER := 40.0
## The furthest a target moves past a step, as a share of the reach.
const MAX_REACH_FACTOR := 2.5
## Share of a standing train slime's rigid motion taken away per tick.
const GRIP := 0.5
## The steepest stretch of route (rise over run) a standing slime grips: 45°.
const GRIP_MAX_SLOPE := 1.0
## Hold on a climb (see the class doc): the rise over run above which a
## standing train slime is held, and the share of one tick's pull along the
## slope it is given up the slope.
const HOLD_FROM := 0.1
const HOLD_LIFT := 0.5
## The relay (see the class doc): the most seconds the train slime right
## behind one that takes off waits before its own hop.
const RELAY_DELAY := 0.15
## Placeholder slide: the speed slimes are carried at on a return route, px/s.
const SLIDE_SPEED := 360.0
## Placeholder slide: share of the gap to SLIDE_SPEED closed per tick.
const SLIDE_GRIP := 0.2
## How far (px) from the route point at its progress a slime is knocked off
## the route, and steers from the nearest route point behind (see the class doc).
const OFF_ROUTE := 36.0
## A slime whose progress doesn't advance STALL_ADVANCE px in
## STALL_SECONDS is stalled (D118; specs/tuning.md: 1 min).
const STALL_SECONDS := 60.0
const STALL_ADVANCE := 24.0
## STALL_SECONDS in ticks (at Simulation.TICK_RATE, 60).
const STALL_TICKS := int(STALL_SECONDS * 60)
## How far past the level's extent a slime is out of bounds, px: at the sides
## and bottom, and at the top (a big hop may leave the screen).
const BOUNDS_MARGIN := 64.0
const BOUNDS_TOP_MARGIN := 2000.0
## The reasons in `stalled`.
const STALLED := "stalled"
const OUT_OF_BOUNDS := "out_of_bounds"
## How many cases `stalled` keeps (the latest).
const STALL_LOG_SIZE := 64
## The kinds of hop target (hop_target(), last_target_kind): the route
## point reach px ahead, a step's foot, over a step, past the top of a drop;
## UNAIMED for a train hop that took off on no aim of steer().
const TARGET_AHEAD := "ahead"
const TARGET_STEP_FOOT := "step_foot"
const TARGET_STEP_OVER := "step_over"
const TARGET_DROP := "drop"
const UNAIMED := "unaimed"

## The train hops taken so far, and those of them that landed short (see
## the class doc), cumulative: the perf log prints the difference per line.
## Debug counters, not state.
# @spec-link [[req_platform_and_performance_targets]]
var hops_taken := 0
var short_hops_taken := 0
## The kind of the last target hop_target() gave (TARGET_*), "" before
## any. Debug, for the census (see the class doc).
# @spec-link [[req_platform_and_performance_targets]]
var last_target_kind := ""
## Slime id -> its last train hop (debug, for the census; see the class
## doc): {"tick" (take-off; Simulation.tick of that step), "from" (progress
## at take-off), "kind" (TARGET_* of the aim it took off on, or UNAIMED),
## "target" (the aim's target, or null), "landed" (tick; -1 while in the
## air, or for a hop that never lands as a train hop: parked, moved),
## "advance" (px of progress from take-off to landing), "short" (bool)}.
## Dropped with the slime's record.
# @spec-link [[req_platform_and_performance_targets]]
var last_hops := {}

## The loop, and the gates opened so far (they pick the current loop).
var loop: LoopData
var open_gates: Array = []
## Where train slimes may be: outside, they are out of bounds (stalled). No
## area: no check.
var bounds := Rect2()
## The last STALL_LOG_SIZE stalled cases, oldest first: {"id", "tick",
## "reason" (STALLED or OUT_OF_BOUNDS)}. Each was moved to the loop start
## on that tick (log_stalled()).
# @spec-link [[rule_stalled_train_slime_moved_to_start]]
var stalled: Array[Dictionary] = []

## Slime id -> {"distance" (px, 0 to length()), "laps", "on_slide",
## "mark" (the progress last counted as an advance), "marked_at" (its tick,
## moved on by the ticks parked since, see the class doc; -1 before the
## first follow)}.
var _records := {}
## The current loop flattened into one closed polyline: points, cumulative
## distances, and for each edge whether it is on a return route.
var _pts := PackedVector2Array()
var _dist := PackedFloat64Array()
var _slide := PackedByteArray()
var _len := 0.0
## Slime id -> its progress at the take-off of its train hop still in the air
## (the hop counters', see the class doc). Not state: not in dump() nor saves.
# @spec-link [[req_platform_and_performance_targets]]
var _takeoff := {}
## Slime id -> [kind, target] of the hop steer() aimed it this tick (the
## census's record, see the class doc). Emptied by every steer().
# @spec-link [[req_platform_and_performance_targets]]
var _aims := {}


func _init(loop_data: LoopData = null, gates: Array = []) -> void:
	loop = loop_data
	open_gates = gates.duplicate()
	_flatten()


## The level's extent, grown by the margins: terrain plus loop.
static func bounds_for(terrain: TerrainSegments, loop_data: LoopData) -> Rect2:
	var box := Rect2()
	var started := false
	var points := PackedVector2Array()
	if terrain != null:
		points.append_array(terrain.seg_a)
	if loop_data != null:
		for segment in loop_data.segments:
			points.append_array(segment["points"])
	for point in points:
		if not started:
			box = Rect2(point, Vector2.ZERO)
			started = true
		else:
			box = box.expand(point)
	if not started:
		return Rect2()
	return Rect2(box.position - Vector2(BOUNDS_MARGIN, BOUNDS_TOP_MARGIN),
			box.size + Vector2(2.0 * BOUNDS_MARGIN, BOUNDS_MARGIN + BOUNDS_TOP_MARGIN))


# --- Sizes ------------------------------------------------------------------

## How far ahead along the loop a slime of `size` aims its hops, px.
static func hop_reach(size: int) -> float:
	return HOP_REACH * (1.0 + HOP_REACH_PER_SIZE * (size - 1))


## How high above the route a slime of `size` tops out, px.
static func hop_apex(size: int) -> float:
	return HOP_APEX * (1.0 + HOP_APEX_PER_SIZE * (size - 1))


## The take-off speed cap for a slime of `size`, px/s.
static func hop_cap(size: int) -> float:
	return SlimeBodies.hop_velocity(size, Vector2.UP, 1.0).length() * HOP_CAP


## The take-off velocity of a ballistic hop (no drag) from `from` that tops
## out `apex` px above the higher of its two ends and comes down on `to`,
## under `gravity` (px/s², downward). Faster than `cap`, the upward part is
## kept (clamped to 97 % of the cap) and the forward part reduced: the hop
## lands short.
static func aim(from: Vector2, to: Vector2, apex: float, gravity: float, cap: float) -> Vector2:
	var top := minf(from.y, to.y) - maxf(apex, 1.0)
	var rise := from.y - top
	var fall := to.y - top
	var vy := -sqrt(2.0 * gravity * rise)
	var flight := sqrt(2.0 * rise / gravity) + sqrt(2.0 * fall / gravity)
	var vx := (to.x - from.x) / flight
	if vx * vx + vy * vy > cap * cap:
		vy = maxf(vy, -cap * 0.97)
		vx = signf(vx) * minf(absf(vx), sqrt(cap * cap - vy * vy))
	return Vector2(vx, vy)


# --- The current loop -------------------------------------------------------

## The length of the current loop, px.
func length() -> float:
	return _len


## The length of the current loop's outgoing part, px.
func outgoing_length() -> float:
	var total := 0.0
	for k in _slide.size():
		if _slide[k] == 0:
			total += _dist[k + 1] - _dist[k]
	return total


## The length of the current loop's return route, px.
func slide_length() -> float:
	return _len - outgoing_length()


## The point `distance` px along the current loop (wraps).
func position_at(distance: float) -> Vector2:
	if _pts.size() < 2 or _len <= 0.0:
		return Vector2.ZERO
	var d := fposmod(distance, _len)
	var k := _edge_at(d)
	var span := _dist[k + 1] - _dist[k]
	var t := (d - _dist[k]) / span if span > 0.0 else 0.0
	return _pts[k].lerp(_pts[k + 1], t)


## Whether `distance` along the current loop is on a return route (a slide).
func is_slide_at(distance: float) -> bool:
	if _slide.is_empty() or _len <= 0.0:
		return false
	return _slide[_edge_at(fposmod(distance, _len))] != 0


## The unit direction of the current loop at `distance`.
func direction_at(distance: float) -> Vector2:
	if _slide.is_empty() or _len <= 0.0:
		return Vector2.RIGHT
	var k := _edge_at(fposmod(distance, _len))
	return (_pts[k + 1] - _pts[k]).normalized()


## Changes the gates opened so far, and with them the current loop. Progress
## is kept as a distance from the start (it stays on the part of the loop
## that doesn't change, which is all a slime can be on when a gate opens).
func set_open_gates(gates: Array) -> void:
	open_gates = gates.duplicate()
	_flatten()


## The progress on the loop closest to `point`, looking only from
## `from_distance` to PROGRESS_WINDOW px ahead of it: from_distance or more
## (never backward), and past length() once it goes round the end. Ties go to
## the nearer progress, or with `latest` to the further one.
func project(from_distance: float, point: Vector2, latest := false) -> float:
	if _pts.size() < 2 or _len <= 0.0:
		return from_distance
	var base := fposmod(from_distance, _len)
	var end := base + minf(PROGRESS_WINDOW, _len)
	var best := base
	var best_gap := point.distance_squared_to(position_at(base))
	var k := _edge_at(base)
	var wrap := 0.0
	var edges := _slide.size()
	for step in edges + 1:
		var d0 := _dist[k] + wrap
		var d1 := _dist[k + 1] + wrap
		if d0 > end:
			break
		var span := d1 - d0
		if span > 0.0:
			var a := _pts[k]
			var along := (point - a).dot(_pts[k + 1] - a) / (span * span)
			var d := clampf(d0 + along * span, maxf(d0, base), minf(d1, end))
			var at := a.lerp(_pts[k + 1], (d - d0) / span)
			var gap := point.distance_squared_to(at)
			if gap < best_gap or (latest and gap <= best_gap):
				best_gap = gap
				best = d
		k += 1
		if k >= edges:
			k = 0
			wrap += _len
	return from_distance + (best - base)


## Where a slime at `point` whose progress is `distance` steers from: its
## progress, or, knocked more than OFF_ROUTE px off the route, the route point
## nearest it within PROGRESS_WINDOW behind (see the class doc).
func steering_distance(distance: float, point: Vector2) -> float:
	if _len <= 0.0 or point.distance_to(position_at(distance)) <= OFF_ROUTE:
		return distance
	var back := minf(PROGRESS_WINDOW, _len)
	# Where the route runs back close to itself (the slide's end meeting the
	# loop's start), the point nearest the progress wins.
	return fposmod(project(distance - back, point, true), _len)


## Where a slime at `progress` aims its next hop, `reach` px ahead along the
## loop, or at a step's foot, or over it (see the class doc).
func hop_target(progress: float, reach: float) -> Vector2:
	var target := progress + reach
	# The first step (steep rise) or drop starting before the target, if any.
	var k := _edge_at(fposmod(progress, _len))
	var wrap := progress - fposmod(progress, _len)
	var found := false
	for step in _slide.size():
		if _dist[k] + wrap > target:
			break
		if _is_steep(k):
			found = true
			break
		if _is_drop(k) and _dist[k] + wrap > progress:
			var run := _pts[k] - _pts[k - 1 if k > 0 else _slide.size() - 1]
			last_target_kind = TARGET_DROP
			return _pts[k] + run.normalized() * DROP_OVER
		k += 1
		if k >= _slide.size():
			k = 0
			wrap += _len
	if not found:
		last_target_kind = TARGET_AHEAD
		return position_at(target)
	var foot := maxf(_dist[k] + wrap, progress)
	if foot - progress > STEP_NEAR:
		last_target_kind = TARGET_STEP_FOOT
		return position_at(foot - STEP_FOOT)
	# Over the step: STEP_LANDING px beyond its top.
	for step in _slide.size():
		if not _is_steep(k):
			break
		k += 1
		if k >= _slide.size():
			k = 0
			wrap += _len
	last_target_kind = TARGET_STEP_OVER
	return position_at(minf(_dist[k] + wrap + STEP_LANDING, progress + reach * MAX_REACH_FACTOR))


## The highest point (lowest y) of the loop between `from` and `to` (px along
## it, from <= to), ends included.
func highest_between(from: float, to: float) -> float:
	var top := minf(position_at(from).y, position_at(to).y)
	var k := _edge_at(fposmod(from, _len))
	var wrap := from - fposmod(from, _len)
	for step in _slide.size():
		var d := _dist[k + 1] + wrap
		if d >= to:
			break
		top = minf(top, _pts[k + 1].y)
		k += 1
		if k >= _slide.size():
			k = 0
			wrap += _len
	return top


# --- Slimes -----------------------------------------------------------------

## Starts following slime `slime_id` at `distance` px along the loop,
## afresh (a hop it is in the air for won't count as landed).
func track(slime_id: int, distance: float) -> void:
	var d := fposmod(distance, _len) if _len > 0.0 else 0.0
	_records[slime_id] = {"distance": d, "laps": 0, "on_slide": false,
			"mark": d, "marked_at": -1}
	_takeoff.erase(slime_id)


func tracks(slime_id: int) -> bool:
	return _records.has(slime_id)


## The ids followed, ascending.
func tracked_ids() -> PackedInt32Array:
	var out := PackedInt32Array(_records.keys())
	out.sort()
	return out


## The slime's distance along the loop from its start, 0 to length().
func distance_of(slime_id: int) -> float:
	return _records[slime_id]["distance"] if _records.has(slime_id) else 0.0


func laps_of(slime_id: int) -> int:
	return _records[slime_id]["laps"] if _records.has(slime_id) else 0


## The tick of the slime's last stall mark (see advance()), -1 when it has
## none or isn't followed.
func marked_at_of(slime_id: int) -> int:
	return _records[slime_id]["marked_at"] if _records.has(slime_id) else -1


## Whether train slime `slime_id` is in the air on a train hop that hasn't
## landed yet (the hop counters' take-off; debug, for the census).
# @spec-link [[req_platform_and_performance_targets]]
func in_air(slime_id: int) -> bool:
	return _takeoff.has(slime_id)


## The slime's progress, laps included: it never goes back.
func progress_of(slime_id: int) -> float:
	if not _records.has(slime_id):
		return 0.0
	var record: Dictionary = _records[slime_id]
	return record["laps"] * _len + record["distance"]


## Re-derives a slime's progress from its centre at `tick`, and marks it
## when it advanced STALL_ADVANCE px since the last mark (the stall count
## starts again from there).
func advance(slime_id: int, centre: Vector2, tick: int) -> void:
	var record: Dictionary = _records[slime_id]
	var progress := project(record["distance"], centre)
	if progress >= _len:
		progress -= _len
		record["laps"] += 1
	record["distance"] = progress
	var now := progress_of(slime_id)
	if record["marked_at"] < 0 or now - record["mark"] >= STALL_ADVANCE:
		record["mark"] = now
		record["marked_at"] = tick


## Why followed slime `slime_id`, its centre at `centre`, is stalled at
## `tick` (after advance()): STALLED when its last mark is STALL_SECONDS old
## (parked ticks not counted, see the class doc),
## OUT_OF_BOUNDS when its centre is outside `bounds`, else "".
# @spec-link [[rule_stalled_train_slime_moved_to_start]]
func stall_of(slime_id: int, centre: Vector2, tick: int) -> String:
	if stalled_since(slime_id, tick) >= 0:
		return STALLED
	if is_out_of_bounds(centre):
		return OUT_OF_BOUNDS
	return ""


## The tick followed slime `slime_id`'s stall clock ran out (its last mark
## plus STALL_TICKS, parked ticks not counted), or -1 when it hasn't at
## `tick`.
# @spec-link [[rule_stalled_train_slime_moved_to_start]]
func stalled_since(slime_id: int, tick: int) -> int:
	var marked_at: int = _records[slime_id]["marked_at"]
	if marked_at >= 0 and tick - marked_at >= STALL_TICKS:
		return marked_at + STALL_TICKS
	return -1


## Whether a slime centred at `centre` is out of the level's bounds (none
## without bounds).
func is_out_of_bounds(centre: Vector2) -> bool:
	return bounds.has_area() and not bounds.has_point(centre)


## Logs that slime `slime_id` was moved to the loop start at `tick` for
## `reason` (STALLED or OUT_OF_BOUNDS), by the loop-start queue.
# @spec-link [[rule_stalled_train_slime_moved_to_start]]
func log_stalled(slime_id: int, tick: int, reason: String) -> void:
	assert(reason == STALLED or reason == OUT_OF_BOUNDS, "Train.log_stalled: reason '%s'" % reason)
	stalled.append({"id": slime_id, "tick": tick, "reason": reason})
	if stalled.size() > STALL_LOG_SIZE:
		stalled.pop_front()


## Split parts carry on from where the slime was: `parts` from
## SlimeBodies.split, the original id first.
func inherit(parts: PackedInt32Array) -> void:
	if parts.is_empty() or not _records.has(parts[0]):
		return
	for k in range(1, parts.size()):
		_records[parts[k]] = _records[parts[0]].duplicate()


## Before the bodies tick: aims the hops about to happen, holds the slimes
## standing on a climb, and holds and carries the slimes on a slide.
# @spec-link [[rule_train_climbs_without_sliding_back]]
func steer(bodies: SlimeBodies, dt: float) -> void:
	if not _aims.is_empty():
		_aims.clear()
	for slime_id in tracked_ids():
		var s := bodies.index_of(slime_id)
		# A parked slime moves off screen at its pace (Offscreen).
		if s < 0 or bodies.state[s] != SlimeBodies.TRAIN or bodies.calm[s] == SlimeBodies.PARKED:
			continue
		var record: Dictionary = _records[slime_id]
		var from := bodies.centre_of(slime_id)
		var progress := steering_distance(record["distance"], from)
		var on_slide := is_slide_at(progress)
		if on_slide != record["on_slide"]:
			record["on_slide"] = on_slide
			bodies.set_hop_held(slime_id, on_slide)
		if on_slide:
			if bodies.supported[s] != 0:
				_carry(bodies, slime_id, progress)
			continue
		var waiting := bodies.hop_timer[s] > dt * 1.5
		if bodies.supported[s] != 0:
			var slope := direction_at(progress)
			if absf(slope.y) <= absf(slope.x) * GRIP_MAX_SLOPE:
				bodies.brake(slime_id, GRIP)
				# Knocked off the route (it steers from a point behind), it isn't held.
				var on_route: bool = progress == record["distance"]
				if on_route and waiting and -slope.y > absf(slope.x) * HOLD_FROM \
						and bodies.calm[s] == SlimeBodies.ACTIVE:
					bodies.hold_on_slope(slime_id, slope, -bodies.gravity.dot(slope) * dt * HOLD_LIFT)
		if waiting:
			continue
		var size := bodies.size[s]
		var target := hop_target(progress, hop_reach(size))
		var high := minf(highest_between(progress, progress + hop_reach(size)), target.y)
		var apex := hop_apex(size) + maxf(0.0, minf(from.y, target.y) - high)
		bodies.set_hop_aim(slime_id, aim(from, target, apex, bodies.gravity.y, hop_cap(size)))
		_aims[slime_id] = [last_target_kind, target]


## After the bodies tick (and the split zones): follows every train slime,
## adopting new ones where the loop passes closest, and drops the others;
## counts the train hops (see the class doc); then relays the tick's
## take-offs (_relay). The stalled ones are moved by the loop-start queue,
## after.
# @spec-link [[rule_stalled_train_slime_moved_to_start]]
# @spec-link [[req_platform_and_performance_targets]]
# @spec-link [[rule_train_relay_on_take_off]]
func follow(bodies: SlimeBodies, tick: int) -> void:
	for slime_id in tracked_ids():
		if bodies.state_of(slime_id) != SlimeBodies.TRAIN:
			_records.erase(slime_id)
			_takeoff.erase(slime_id)
			last_hops.erase(slime_id)
	hops_taken += bodies.train_hopped.size()
	for slime_id in bodies.ids():
		var s := bodies.index_of(slime_id)
		if bodies.state[s] != SlimeBodies.TRAIN:
			continue
		var centre := bodies.centre_of(slime_id)
		if not _records.has(slime_id):
			track(slime_id, _closest_distance(centre))
		var before := progress_of(slime_id)
		if bodies.calm[s] == SlimeBodies.PARKED:
			_pause_stall_clock(slime_id, tick)
		advance(slime_id, centre, tick)
		_count_landing(bodies, slime_id, s, before, tick)
	if not bodies.train_hopped.is_empty():
		_relay(bodies)


## Slime `slime_id`'s record, exactly (for saves): {"distance", "laps",
## "on_slide", "mark", "marked_at"}, or {} when it isn't followed.
func record_of(slime_id: int) -> Dictionary:
	return _records[slime_id].duplicate() if _records.has(slime_id) else {}


## Follows slime `slime_id` from a saved record (record_of). Missing fields
## take track()'s values.
func restore_record(slime_id: int, record: Dictionary) -> void:
	track(slime_id, record.get("distance", 0.0))
	var mine: Dictionary = _records[slime_id]
	for key in ["laps", "on_slide", "mark", "marked_at"]:
		if record.has(key):
			mine[key] = record[key]


## The train's state as plain data, for Simulation.dump().
func dump() -> Dictionary:
	var slimes := []
	for slime_id in tracked_ids():
		var record: Dictionary = _records[slime_id]
		slimes.append({"id": slime_id, "distance": snappedf(record["distance"], 0.01),
				"laps": record["laps"], "on_slide": record["on_slide"],
				"mark": snappedf(record["mark"], 0.01), "marked_at": record["marked_at"]})
	return {"open_gates": open_gates.duplicate(), "slimes": slimes, "stalled": stalled.duplicate(true)}


# --- Internals --------------------------------------------------------------

## The stall clock's pause (see the class doc) for followed slime `slime_id`,
## parked at `tick`: its last mark's tick moves on by one, so the time since
## the mark stays what it was. A fresh record (no mark yet) is left alone,
## and so is a mark already at `tick` (Offscreen's proxy may have just made
## it): the mark never goes past the current tick. A clock that had already
## run out at the last tick is left alone too: the slime stays due from the
## tick it came due.
# @spec-link [[rule_stalled_train_slime_moved_to_start]]
# @spec-link [[req_offscreen_simulation]]
func _pause_stall_clock(slime_id: int, tick: int) -> void:
	var record: Dictionary = _records[slime_id]
	var marked_at: int = record["marked_at"]
	if marked_at >= 0 and marked_at < tick and tick - 1 - marked_at < STALL_TICKS:
		record["marked_at"] = marked_at + 1


## The hop counters for train slime `slime_id` (index `s`), just advanced
## from progress `before` at `tick`: a hop it took this tick takes off from
## `before`; one in the air lands when the slime is supported, short when it
## advanced less than half its hop_reach(); a parked slime's hop never
## lands. The census's last_hops follow them (see the class doc).
# @spec-link [[req_platform_and_performance_targets]]
func _count_landing(bodies: SlimeBodies, slime_id: int, s: int, before: float, tick: int) -> void:
	if bodies.calm[s] == SlimeBodies.PARKED:
		_takeoff.erase(slime_id)
	elif bodies.train_hopped.has(slime_id):
		_takeoff[slime_id] = before
		var aimed: Array = _aims.get(slime_id, [])
		last_hops[slime_id] = {"tick": tick, "from": before, "kind": aimed[0] if not aimed.is_empty() else UNAIMED,
				"target": aimed[1] if not aimed.is_empty() else null, "landed": -1, "advance": 0.0, "short": false}
	elif _takeoff.has(slime_id) and bodies.supported[s] != 0:
		var advance: float = progress_of(slime_id) - _takeoff[slime_id]
		var short := advance < hop_reach(bodies.size[s]) * 0.5
		if short:
			short_hops_taken += 1
		var last: Dictionary = last_hops.get(slime_id, {})
		if not last.is_empty():
			last["landed"] = tick
			last["advance"] = advance
			last["short"] = short
		_takeoff.erase(slime_id)


## The relay (see the class doc), at the end of follow(): for each train
## slime that took off on this tick (SlimeBodies.train_hopped), cuts the hop
## timer of the train slime right behind it to RELAY_DELAY, when that one
## stands on the outgoing route within its reach of touching it. The cut
## timer is the bodies' state, saved; the take-offs are not, and are not read
## past this tick.
# @spec-link [[req_hopping_behavior]]
# @spec-link [[rule_train_relay_on_take_off]]
func _relay(bodies: SlimeBodies) -> void:
	for hopped in bodies.train_hopped:
		if not _records.has(hopped) or bodies.state_of(hopped) != SlimeBodies.TRAIN:
			continue
		var behind := _behind(bodies, hopped)
		if behind.is_empty():
			continue
		var follower: int = behind[0]
		var b := bodies.index_of(follower)
		if b < 0 or bodies.train_hopped.has(follower) or bodies.calm[b] == SlimeBodies.PARKED \
				or bodies.supported[b] == 0 or _records[follower]["on_slide"]:
			continue
		var room := bodies.radius_of(hopped) + bodies.radius_of(follower) + 2.0 * SlimeBodies.EDGE
		if behind[1] < hop_reach(bodies.size[b]) + room and bodies.hop_timer[b] > RELAY_DELAY:
			bodies.set_hop_timer(follower, RELAY_DELAY)


## The train slime right behind followed train slime `slime_id` along the
## loop: the nearest one further back by distance (then by id, for slimes at
## the same distance), the front one's round the loop. [its id, the gap
## along the loop in px], or [] when there is no other train slime.
func _behind(bodies: SlimeBodies, slime_id: int) -> Array:
	var at: float = _records[slime_id]["distance"]
	var best := -1
	var best_gap := INF
	for other: int in _records:
		if other == slime_id or bodies.state_of(other) != SlimeBodies.TRAIN:
			continue
		var gap: float = at - _records[other]["distance"]
		if gap < 0.0 or (gap == 0.0 and other > slime_id):
			gap += _len
		if gap < best_gap or (gap == best_gap and other > best):
			best_gap = gap
			best = other
	return [] if best < 0 else [best, best_gap]


## Placeholder slide: pulls the slime's speed along the route toward SLIDE_SPEED.
func _carry(bodies: SlimeBodies, slime_id: int, distance: float) -> void:
	var tangent := direction_at(distance)
	var velocity := bodies.velocity_of(slime_id)
	var along := velocity.dot(tangent)
	if along >= SLIDE_SPEED:
		return
	bodies.set_velocity(slime_id, velocity + tangent * (SLIDE_SPEED - along) * SLIDE_GRIP)


func _closest_distance(point: Vector2) -> float:
	if loop == null:
		return 0.0
	return loop.closest(point, open_gates)["distance"]


## The index of the edge holding `distance` (0 to length()).
func _edge_at(distance: float) -> int:
	var k := _dist.bsearch(distance, false) - 1
	return clampi(k, 0, _slide.size() - 1)


func _is_steep(k: int) -> bool:
	var d := _pts[k + 1] - _pts[k]
	return -d.y > absf(d.x) * STEEP_RISE


func _is_drop(k: int) -> bool:
	var d := _pts[k + 1] - _pts[k]
	return d.y > absf(d.x) * STEEP_RISE


func _flatten() -> void:
	_pts = PackedVector2Array()
	_dist = PackedFloat64Array()
	_slide = PackedByteArray()
	_len = 0.0
	if loop == null:
		return
	for segment in loop.current_segments(open_gates):
		var points: PackedVector2Array = segment["points"]
		var is_return := 1 if segment["kind"] == LoopData.RETURN else 0
		for k in points.size():
			if _pts.is_empty():
				_pts.append(points[k])
				_dist.append(0.0)
				continue
			if k == 0:
				continue  # the join: the previous segment's last point
			_len += _pts[_pts.size() - 1].distance_to(points[k])
			_pts.append(points[k])
			_dist.append(_len)
			_slide.append(is_return)
