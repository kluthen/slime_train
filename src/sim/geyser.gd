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
## Phase 2, "high and wide" (`wide`, variants C and D). The launch starts
## clear of the pile: the arrival is first lifted straight up above the
## slimes stacked over it (`lift_origin`: the highest ring overlapping its
## column, plus LIFT_GAP; at most LIFT_MAX px, the lifted ring clear of the
## terrain by CLEARANCE, else no lift), then flies from there. Landing spots
## are drawn much further along the loop, `land_min` to `land_max` px (C:
## HIGH_LAND_MIN to HIGH_LAND_MAX; D: HIGH_LAND_MIN to HIGH_LAND_MIN +
## RATE_LENGTH, the length the measured departure rate absorbs), WIDE_CANDIDATES
## of them, never at or past the first gate along the loop (`gate_limit`).
## C keeps the emptiest; D the one whose RATE_BIN px bin got the fewest
## landings lately (so no metre is fed faster than it clears), then the
## emptiest.
## Past the start's split zone a base slime may land (nothing to split); a
## fused one still only inside a split zone. No carry (the lift replaces it).
##
## `enabled` and `carry` are modes for the experiment's with/without runs
## (the same build): the geyser off with the user argument --no-geyser or
## SLIME_GEYSER=off, the carry off (variant A) with --geyser-solo or
## SLIME_GEYSER=solo (default_enabled(), default_carry()); variant C with
## --geyser-high or SLIME_GEYSER=high, D with --geyser-rate or
## SLIME_GEYSER=rate (default_variant(), set_variant()); or set by a test.
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
## Variants C and D: the landing stretch starts past the hump, the hole and
## the terrace's first slimes (test level: x 362), px along the loop.
const HIGH_LAND_MIN := 150.0
## Variant C: the landing stretch ends 700 px along the loop (test level: the
## slope up from the terrace, x 867; the user's "wide dispersion").
const HIGH_LAND_MAX := 700.0
## Variant D: the landing stretch's length, px: the length over which the
## measured arrivals are absorbed at the measured clearing rate of a crowded
## loop start. Probe (tools/geyser_probe.gd), s3-basket-59of60 seeds 1 and 2
## without the geyser, camera on the start, ticks 9000 to 14000: 15.4
## arrivals and 6.1 departures past 240 px per 600 ticks, so a crowded
## stretch clears 6.1 / 240 = 0.0255 slimes per px per 600 ticks, and 15.4
## arrivals need 15.4 / 0.0255 = 605 px. Rounded to 600 (150 to 750 px).
const RATE_LENGTH := 600.0
## Variant D: the stretch is cut into bins this long, px; a spot is scored
## by the landings its bin got in the last RATE_WINDOW ticks (at the rate
## above, a 50 px bin clears about 1.3 slimes per 600 ticks), the fewest
## winning, the emptiest spot breaking ties.
const RATE_BIN := 50.0
const RATE_WINDOW := 600
## Variants C and D: spots drawn per launch (a stretch twice as long).
const WIDE_CANDIDATES := 10
## Variants C and D: the lifted arrival's ring keeps this much room above the
## highest ring over it, px.
const LIFT_GAP := 6.0
## Variants C and D: the furthest an arrival is lifted, px (about five base
## slimes stacked); a higher pile and it flies from where it is.
const LIFT_MAX := 240.0

## The variants (default_variant()).
const VARIANT_CARRY := "carry"
const VARIANT_SOLO := "solo"
const VARIANT_HIGH := "high"
const VARIANT_RATE := "rate"

## Whether arrivals are launched (see the class doc). Not saved.
var enabled := true
## Whether the jet carries the slimes above an arrival (see the class doc).
var carry := true
## Variants C and D: lift the arrival above the pile and land it further on
## (see the class doc). Not saved.
var wide := false
## Variant D: spots scored by their bin's recent landings (see RATE_BIN).
var by_rate := false
## Variant D: the ticks of the recent landings, by bin (debug state of the
## experiment, not saved: a reload forgets them).
var _bin_landings := {}
## Where along the loop a launched slime may land, px (LAND_MIN and LAND_MAX
## unless `wide`).
var land_min := LAND_MIN
var land_max := LAND_MAX
## Debug counters of the lift: how many arrivals were lifted, and by how
## much in all and at most (px).
var lifted := 0
var lift_total := 0.0
var lift_highest := 0.0
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


## The first gate's distance along the loop (cached, -1.0 until known).
var _gate_limit := -1.0


func _init() -> void:
	enabled = default_enabled()
	carry = default_carry()
	set_variant(default_variant())


## The variant of this run: VARIANT_HIGH with the user argument
## --geyser-high or SLIME_GEYSER=high, VARIANT_RATE with --geyser-rate or
## SLIME_GEYSER=rate, VARIANT_SOLO without the carry, else VARIANT_CARRY.
static func default_variant() -> String:
	var args := OS.get_cmdline_user_args()
	var env := OS.get_environment("SLIME_GEYSER")
	if args.has("--geyser-high") or env == VARIANT_HIGH:
		return VARIANT_HIGH
	if args.has("--geyser-rate") or env == VARIANT_RATE:
		return VARIANT_RATE
	return VARIANT_CARRY if default_carry() else VARIANT_SOLO


## Sets `carry`, `wide` and the landing stretch for `variant` (leaves
## `enabled` alone).
func set_variant(variant: String) -> void:
	wide = variant == VARIANT_HIGH or variant == VARIANT_RATE
	carry = variant == VARIANT_CARRY
	by_rate = variant == VARIANT_RATE
	land_min = HIGH_LAND_MIN if wide else LAND_MIN
	land_max = LAND_MAX
	if variant == VARIANT_HIGH:
		land_max = HIGH_LAND_MAX
	elif variant == VARIANT_RATE:
		land_max = HIGH_LAND_MIN + RATE_LENGTH


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
	var origin := from
	if wide and not parked:
		origin = lift_origin(bodies, slime_id)
	var cap := bodies.max_speed * SPEED_SHARE
	var top := minf(land_max, gate_limit(sim) - 1.0) if wide else land_max
	var draws := WIDE_CANDIDATES if wide else CANDIDATES
	var zoned := not sim.split_zones.zones.is_empty() and (not wide or size > 1)
	var best_distance := -1.0
	var best_room := -INF
	var best_score := 0x7fffffff
	var best_at := Vector2.ZERO
	var best_velocity := Vector2.ZERO
	for k in draws:
		var distance := stream.randf_range(land_min, land_max)
		if distance >= top:
			continue
		var at := LoopStart.landing_point(train, size, distance)
		if zoned and not sim.split_zones.covers(at):
			continue
		var velocity := Vector2.ZERO
		if not parked:
			velocity = Train.aim(origin, at, apex, bodies.gravity.y, cap)
			if not flight_clear(bodies, size, origin, velocity, at):
				continue
		var room := room_at(bodies, slime_id, at)
		# Off screen there is no flight to sort it out: only a free spot (no
		# ring there, LoopStart.is_free's test), else the proxy's single file.
		if parked and room < SlimeBodies.ring_radius_for(size) + 2.0 * SlimeBodies.EDGE:
			continue
		var score := _bin_score(distance, sim.tick) if by_rate else 0
		if score < best_score or (score == best_score and room > best_room):
			best_score = score
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
	if by_rate:
		var bin := int(best_distance / RATE_BIN)
		var recent: Array = _bin_landings.get(bin, [])
		recent.append(sim.tick)
		_bin_landings[bin] = recent
	launches += 1
	launches_log.append({"id": slime_id, "tick": sim.tick, "distance": best_distance, "parked": parked,
			"at": best_at})
	if launches_log.size() > LOG_SIZE:
		launches_log.pop_front()
	return true


## Variant D: how many landings the bin of `distance` got in the
## RATE_WINDOW ticks before `tick` (older ones forgotten).
func _bin_score(distance: float, tick: int) -> int:
	var bin := int(distance / RATE_BIN)
	if not _bin_landings.has(bin):
		return 0
	var recent: Array = _bin_landings[bin]
	while not recent.is_empty() and tick - int(recent[0]) >= RATE_WINDOW:
		recent.pop_front()
	return recent.size()


## Where arrival `slime_id` flies from in the wide variants: its centre
## lifted straight up so its ring clears, by LIFT_GAP, every ring overlapping
## its column above it (the pile over the hole), or its centre when nothing
## is over it, the lift would exceed LIFT_MAX, or the lifted ring would come
## within CLEARANCE px of the terrain.
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
