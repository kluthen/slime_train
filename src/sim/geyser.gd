class_name Geyser
extends RefCounted
## EXPERIMENT (branch exp/geyser; D157 (5), O117): the geyser at the return
## route's end. Not in the spec, no ATD atom: the user decides whether it
## stays. When a train slime reaches the end of the return route (the
## "finish line": its progress wraps past the loop's end, which is the
## loop's start, Train.lapped), it is launched high with a wide horizontal
## spread, so arrivals come down spread over the loop's first stretch
## instead of popping out on one point, and get away from the start before
## the next ones arrive (level rule 24).
##
## The launch. For each arrival, CANDIDATES landing spots are drawn along the
## loop, uniformly LAND_MIN to LAND_MAX px from its start (the slime's centre
## lifted by its size above the loop there, LoopStart.landing_point), and an
## apex APEX px above the higher end of the flight, give or take
## APEX_JITTER. A spot is kept only when it lies inside a split zone (on a
## level with any: the start's; a fused slime still splits at once) and its
## flight (Train.aim: ballistic, no drag) keeps CLEARANCE px between the
## slime's ring and every terrain segment on the way (the ends' own
## neighbourhoods aside): no flying into an overhang, no landing on or under
## a ledge (rule 22 (b)'s, on the test level FirstLedge). Of the spots kept,
## the emptiest is taken: the one whose nearest slime is furthest (a slime
## in the air counted where it will come down at that height: its
## ballistic path, from its velocity; D150's "never onto another slime",
## made cheap). The slime gets the take-off velocity at once
## (SlimeBodies.launch: its points' previous positions, as a hop's, and
## unsupported, so the train's grip doesn't brake it on the next tick):
## the solver is untouched, so it works the same on both ticks. With no spot
## kept, it isn't launched and carries on as without the geyser.
##
## Off screen (a parked slime, moved by Offscreen's proxy): no flight. It is
## put straight on the emptiest of the drawn spots inside a split zone where
## its ring overlaps no other slime's (LoopStart.is_free's test), its
## progress moved there (Train.place), as the loop-start queue's moves do
## (D150): the proxy carries it on from there. With no such spot it isn't
## placed: it carries on in the proxies' single file, as without the geyser
## (placing it anyway stacked parked slimes on one another, which unpark as
## a stuck pile).
##
## Randomness: the derived stream "geyser:<tick>:<slime id>" (Rng.derive),
## all CANDIDATES draws and the apex's taken every time: no draw from any
## other stream, same seed, same launches. Nothing is saved: a launch is
## only a velocity (in the bodies) or a progress (in the train record).
##
## The jet carries what sits above (`carry`, variant B). An arrival comes up
## under the train slimes waiting at the loop's start (on the test level,
## stacked over the hole the slides come up through, on the hump before the
## terrace): launched alone it smacks into them and drops back (variant A,
## measured). So with `carry`, the train slimes the arrival's jet meets, those
## simulated whose ring overlaps the arrival's column (horizontally within the
## two radii, CARRY_REACH px above its centre at most) and that haven't left
## the start yet (progress below LAND_MIN), are launched with it, each to its
## own spot from its own stream, the same tick.
##
## `enabled` and `carry` are modes for the experiment's with/without runs
## (the same build): the geyser off with the user argument --no-geyser or
## SLIME_GEYSER=off, the carry off (variant A) with --geyser-solo or
## SLIME_GEYSER=solo (default_enabled(), default_carry()), or set by a test.
## Not in dump() nor saves.
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
## LAND_MIN: past the start's hump and the hole the slides come up through
## (test level: the terrace's left edge, x 300); to LAND_MAX: the loop's
## first stretch, D150's landing stretch (LoopStart.STRETCH).
const LAND_MIN := 100.0
const LAND_MAX := LoopStart.STRETCH
## How many landing spots are drawn per launch (the emptiest kept one wins).
const CANDIDATES := 6
## The room kept between the ring and the terrain along the flight, px.
const CLEARANCE := 4.0
## How many points along the flight are checked against the terrain.
const SAMPLES := 16
## The take-off speed cap, as a share of SlimeBodies.max_speed.
const SPEED_SHARE := 0.95
## How far above an arrival's centre its jet carries the slimes it meets, px
## (about two base slimes stacked).
const CARRY_REACH := 90.0
## How many launches `launches_log` keeps (debug).
const LOG_SIZE := 64

## Whether arrivals are launched (see the class doc). Not saved.
var enabled := true
## Whether the jet carries the slimes above an arrival (see the class doc).
var carry := true
## Debug counters (the experiment's probe), not state: the arrivals seen
## (with or without the geyser), the launches made (flights and off-screen
## placements), and the arrivals not launched for want of a kept spot.
var arrivals := 0
var launches := 0
var refused := 0
var carried := 0
## The latest LOG_SIZE launches, oldest first: {"id", "tick", "distance"
## (the landing spot along the loop), "parked" (bool), "at" (Vector2, the
## landing centre)}. Debug, not state.
var launches_log: Array[Dictionary] = []


func _init() -> void:
	enabled = default_enabled()
	carry = default_carry()


## Whether this run launches arrivals: false with the user argument
## --no-geyser or the environment variable SLIME_GEYSER=off.
static func default_enabled() -> bool:
	if OS.get_cmdline_user_args().has("--no-geyser"):
		return false
	return OS.get_environment("SLIME_GEYSER") != "off"


## Whether the jet carries the slimes above (variant B): false with the user
## argument --geyser-solo or SLIME_GEYSER=solo.
static func default_carry() -> bool:
	if OS.get_cmdline_user_args().has("--geyser-solo"):
		return false
	return OS.get_environment("SLIME_GEYSER") != "solo"


## Launches every train slime that reached the return route's end this tick
## (Train.lapped, emptied here), in id order, and with `carry` the slimes
## each one's jet meets (see the class doc).
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
		if not enabled:
			continue
		var parked := bodies.is_parked(slime_id)
		if launch(sim, slime_id) and carry and not parked:
			for other in in_jet(sim, slime_id):
				if launch(sim, other):
					carried += 1


## The train slimes the jet of arrival `slime_id` meets (see the class doc),
## in id order: simulated, not yet past LAND_MIN, their ring overlapping the
## column CARRY_REACH px above the arrival's centre.
func in_jet(sim: Simulation, slime_id: int) -> PackedInt32Array:
	var bodies := sim.slimes
	var train := sim.train
	var out := PackedInt32Array()
	var from := bodies.centre_of(slime_id)
	var radius := bodies.radius_of(slime_id)
	for other in bodies.ids():
		if other == slime_id or bodies.state_of(other) != SlimeBodies.TRAIN or bodies.calm_of(other) != SlimeBodies.ACTIVE:
			continue
		if not train.tracks(other) or train.distance_of(other) >= LAND_MIN or train.is_slide_at(train.distance_of(other)):
			continue
		var at := bodies.centre_of(other)
		var rise := from.y - at.y
		if absf(at.x - from.x) < radius + bodies.radius_of(other) and rise >= 0.0 and rise <= CARRY_REACH:
			out.append(other)
	return out


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
	var cap := bodies.max_speed * SPEED_SHARE
	var best_distance := -1.0
	var best_room := -INF
	var best_at := Vector2.ZERO
	var best_velocity := Vector2.ZERO
	for k in CANDIDATES:
		var distance := stream.randf_range(LAND_MIN, LAND_MAX)
		var at := LoopStart.landing_point(train, size, distance)
		if not sim.split_zones.zones.is_empty() and not sim.split_zones.covers(at):
			continue
		var velocity := Vector2.ZERO
		if not parked:
			velocity = Train.aim(from, at, apex, bodies.gravity.y, cap)
			if not flight_clear(bodies, size, from, velocity, at):
				continue
		var room := room_at(bodies, slime_id, at)
		# Off screen there is no flight to sort it out: only a free spot (no
		# ring there, LoopStart.is_free's test), else the proxy's single file.
		if parked and room < SlimeBodies.ring_radius_for(size) + 2.0 * SlimeBodies.EDGE:
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
		bodies.launch(slime_id, best_velocity)
	launches += 1
	launches_log.append({"id": slime_id, "tick": sim.tick, "distance": best_distance, "parked": parked,
			"at": best_at})
	if launches_log.size() > LOG_SIZE:
		launches_log.pop_front()
	return true


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
## the air counted where its ballistic path comes down to `at`'s height
## (from its velocity), parked ones where they are. INF with no other slime.
static func room_at(bodies: SlimeBodies, slime_id: int, at: Vector2) -> float:
	var room := INF
	var gravity := bodies.gravity.y
	for other in bodies.ids():
		if other == slime_id:
			continue
		var s := bodies.index_of(other)
		var q := bodies.centre_of(other)
		if bodies.supported[s] == 0 and bodies.calm[s] == SlimeBodies.ACTIVE:
			var velocity := bodies.velocity_of(other)
			var t := time_down_to(q, velocity, gravity, at.y)
			if t > 0.0:
				q = Vector2(q.x + velocity.x * t, at.y)
		room = minf(room, q.distance_to(at) - bodies.radius_of(other))
	return room
