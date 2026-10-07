class_name FreeSlimes
extends RefCounted
## The call and the free slimes (master spec §5.2, D46, D73): what a slime
## does between answering a call and rejoining the train. Plain data and pure
## logic over SlimeBodies, no scene nodes; the Simulation drives it.
##
## The call. A call has a point (level pixels) and a start tick. Every awake
## slime (train or free) whose centre is within the call radius of the point
## answers it: it becomes free (it leaves the train), is let go if it was held
## (on the slide), turns toward the point and hops toward it soon after
## (FIRST_HOP_SECONDS). The radius is CALL_RADIUS_SCREENS of the view's width,
## so it follows the zoom. A slime still answering an earlier call but out of
## the new call's range takes the new point too (a new tap replaces the call,
## D73), and its give-up clock restarts with the new call.
##
## A free slime goes through three phases, and hops on its own seeded timer
## all along (SlimeBodies) while this class aims each hop and paces the next:
##
##   answering  it hops toward the call point, Train.hop_reach() at most
##              sideways, upward when the point is higher (up to max_rise():
##              bigger slimes jump higher), ANSWER_PACE times its usual hop
##              interval. It gives up when its centre comes within REACHED
##              px of the point or after CALL_SECONDS, and turns unsure.
##   unsure     for UNSURE_SECONDS it stays near the last call point: further
##              than UNSURE_RANGE px from it sideways, it hops back toward it;
##              closer, it makes small lazy hops (UNSURE_REACH, UNSURE_APEX)
##              in random directions drawn from its own stream, UNSURE_PACE
##              times its usual hop interval. Then it heads back.
##   heading    it hops back toward the loop at its usual pace. The way back
##   back       is chosen again at every hop, from where the slime stands:
##              inside an exploration branch's box, it follows that branch's
##              route back (it aims Train.hop_reach() ahead of its projection
##              on the route); past the route's end, or in no branch, it
##              hops straight for the nearest point of the current loop,
##              which is mostly downhill. When that point is less than
##              MIN_SIDEWAYS px away sideways (the loop is below), it hops
##              MIN_SIDEWAYS px the way the loop runs there, aimed level with
##              where it stands, so it clears a ledge's edge rather than hop
##              in place above the loop. It rejoins the train (state train;
##              the Train adopts it at the loop point closest to it) as soon
##              as its centre is within REJOIN_DISTANCE of the loop.
##
## Physics applies throughout: between hops a free slime standing on ground
## no steeper than 45° grips it (GRIP, like a train slime); steeper, it rolls.
##
## Randomness: each free slime's lazy hops come from a stream derived from
## the master Rng as "free:<id>:<tick it became free>", whose state is kept
## in dump(). A slime freed again later gets a fresh stream.
##
## Tick order (Simulation.step): answer_call() while input is applied; steer()
## before the bodies tick; paced() after it; inherit() for split parts;
## follow() after the split zones and before Train.follow().
# @spec-link [[req_call_mechanic]]
# @spec-link [[req_slime_states]]
# @spec-link [[rule_exploration_branch_has_route_back]]

const ANSWERING := "answering"
const UNSURE := "unsure"
const HEADING_BACK := "heading_back"

## The call radius, as a share of the view's width (specs/tuning.md: about
## half the screen width).
const CALL_RADIUS_SCREENS := 0.5
## How long a slime answers a call it can't reach before giving up, s.
const CALL_SECONDS := 8.0
## How long a slime stays unsure after its call ends, s.
const UNSURE_SECONDS := 15.0
## A size-1 slime whose centre comes this close to the call point has
## reached it, px (bigger slimes: plus their extra radius).
const REACHED := 56.0
## The longest wait before an answering slime's first hop, s: it turns toward
## the point, then hops.
const FIRST_HOP_SECONDS := 0.35
## Each phase's hop interval, as a share of the usual one (SlimeBodies): a
## called slime hops a bit more often than on the train, an unsure one lazily.
const ANSWER_PACE := 0.6
const UNSURE_PACE := 1.3
const HEADING_BACK_PACE := 1.0
## Further than this from the last call point sideways, an unsure slime hops
## back toward it, px.
const UNSURE_RANGE := 120.0
## An unsure slime's lazy hops: at most this far sideways, px, topping out
## UNSURE_APEX px above their higher end.
const UNSURE_REACH := 60.0
const UNSURE_APEX := 16.0
## A heading-back slime whose centre is this close to the current loop
## rejoins the train, px (bigger slimes: plus their extra radius).
const REJOIN_DISTANCE := 40.0
## The least a slime heading straight for the loop hops sideways, px.
const MIN_SIDEWAYS := 60.0
## Share of a standing free slime's rigid motion taken away per tick.
const GRIP := 0.5
## Ground whose outward normal points at least this much up (y, downward
## positive) is no steeper than 45°: a free slime standing on it grips.
const GRIP_NORMAL_Y := -0.707
## Kept below the highest hop the take-off cap allows, px.
const RISE_MARGIN := 4.0

## The last call: its point (level pixels) and start tick (-1: none yet).
var call_point := Vector2.ZERO
var call_tick := -1

var _master: Rng
## Slime id -> {"phase", "since" (the tick the phase began), "point" (its
## call point), "route" (the route back last chosen, or ""), "stream" (Rng)}.
var _records := {}


func _init(master: Rng) -> void:
	_master = master


## The call radius for a view `view_width` level pixels wide, px.
static func call_radius(view_width: float) -> float:
	return CALL_RADIUS_SCREENS * view_width


## The highest a slime of `size` aims above its take-off point, px: its
## capped hop's height, less the hop's apex (so it still clears the ledge).
static func max_rise(size: int, gravity: float) -> float:
	var up := Train.hop_cap(size) * 0.97
	return up * up / (2.0 * gravity) - Train.hop_apex(size) - RISE_MARGIN


# --- Queries ----------------------------------------------------------------

## Whether slime `slime_id` is followed as a free slime.
func tracks(slime_id: int) -> bool:
	return _records.has(slime_id)


## The ids followed, ascending.
func tracked_ids() -> PackedInt32Array:
	var out := PackedInt32Array(_records.keys())
	out.sort()
	return out


## The slime's phase (ANSWERING, UNSURE, HEADING_BACK), or "".
func phase_of(slime_id: int) -> String:
	return _records[slime_id]["phase"] if _records.has(slime_id) else ""


## The tick the slime's phase began, or -1.
func phase_since(slime_id: int) -> int:
	return _records[slime_id]["since"] if _records.has(slime_id) else -1


## The call point the slime answers (or answered last).
func point_of(slime_id: int) -> Vector2:
	return _records[slime_id]["point"] if _records.has(slime_id) else Vector2.ZERO


## The route back the slime chose at its last hop heading back, or "".
func route_of(slime_id: int) -> String:
	return _records[slime_id]["route"] if _records.has(slime_id) else ""


# --- Changing ---------------------------------------------------------------

## A call at `point` on `tick`, answered by every awake slime within `radius`.
## Returns the ids that answered, ascending.
func answer_call(point: Vector2, tick: int, bodies: SlimeBodies, radius: float) -> PackedInt32Array:
	call_point = point
	call_tick = tick
	var answered := PackedInt32Array()
	for slime_id in bodies.ids():
		var s := bodies.index_of(slime_id)
		var awake := bodies.state[s] == SlimeBodies.TRAIN or bodies.state[s] == SlimeBodies.FREE
		if not awake:
			continue
		if bodies.centre_of(slime_id).distance_to(point) <= radius:
			bodies.set_state(slime_id, SlimeBodies.FREE)
			bodies.set_hop_held(slime_id, false)
			var record := _record_for(slime_id, tick)
			record["phase"] = ANSWERING
			record["since"] = tick
			record["point"] = point
			bodies.set_hop_timer(slime_id, minf(bodies.hop_timer[s], FIRST_HOP_SECONDS))
			answered.append(slime_id)
		elif _records.has(slime_id) and _records[slime_id]["phase"] == ANSWERING:
			_records[slime_id]["point"] = point
			_records[slime_id]["since"] = tick
	return answered


## Before the bodies tick: grips the standing free slimes, and aims the hops
## about to happen (see the class doc). `level` gives the branches, routes
## back and loop; `open_gates` picks the current loop.
func steer(bodies: SlimeBodies, dt: float, level: LevelData, open_gates: Array) -> void:
	for slime_id in tracked_ids():
		var s := bodies.index_of(slime_id)
		# A parked slime follows its route back off screen (Offscreen).
		if s < 0 or bodies.state[s] != SlimeBodies.FREE or bodies.calm[s] == SlimeBodies.PARKED:
			continue
		var from := bodies.centre_of(slime_id)
		if bodies.supported[s] != 0 and _on_gentle_ground(bodies, s, from):
			bodies.brake(slime_id, GRIP)
		# SlimeBodies hops this tick exactly when this holds (see SlimeHops.auto_hops).
		if bodies.hop_timer[s] - dt > 0.0 or bodies.supported[s] == 0 or bodies.held[s] != 0:
			continue
		var record: Dictionary = _records[slime_id]
		var size := bodies.size[s]
		var gravity := bodies.gravity.y
		var reach := Train.hop_reach(size)
		var aim := Vector2.ZERO
		match record["phase"]:
			ANSWERING:
				aim = _toward(from, record["point"], reach, Train.hop_apex(size), size, gravity)
			UNSURE:
				var point: Vector2 = record["point"]
				if absf(point.x - from.x) > UNSURE_RANGE:
					aim = _toward(from, point, reach, Train.hop_apex(size), size, gravity)
				else:
					var stream: Rng = record["stream"]
					var to := from + Vector2(stream.randf_range(-UNSURE_REACH, UNSURE_REACH), 0.0)
					aim = Train.aim(from, to, UNSURE_APEX, gravity, Train.hop_cap(size))
			HEADING_BACK:
				var target := _way_back(record, from, reach, level, open_gates)
				aim = _toward(from, target, reach, Train.hop_apex(size), size, gravity)
		bodies.set_hop_aim(slime_id, aim)


## After the bodies tick: paces the next hop of every free slime that just
## hopped (its phase's share of the interval SlimeBodies drew).
func paced(bodies: SlimeBodies) -> void:
	for slime_id in bodies.hopped:
		if not _records.has(slime_id) or bodies.state_of(slime_id) != SlimeBodies.FREE:
			continue
		var pace := HEADING_BACK_PACE
		match _records[slime_id]["phase"]:
			ANSWERING:
				pace = ANSWER_PACE
			UNSURE:
				pace = UNSURE_PACE
		bodies.set_hop_timer(slime_id, bodies.hop_timer_of(slime_id) * pace)


## Split parts carry on in the phase the slime was in: `parts` from
## SlimeBodies.split, the original id first. Each part gets its own stream.
func inherit(parts: PackedInt32Array, tick: int) -> void:
	if parts.is_empty() or not _records.has(parts[0]):
		return
	for k in range(1, parts.size()):
		var record: Dictionary = _records[parts[0]].duplicate()
		record["stream"] = _master.derive("free:%d:%d" % [parts[k], tick])
		_records[parts[k]] = record


## After the split zones, before Train.follow(): moves every free slime to
## its next phase when its time comes, and puts heading-back slimes that
## reached the loop back on the train. Free slimes nobody called (made free
## by a test or a later chunk) head back.
func follow(bodies: SlimeBodies, tick: int, level: LevelData, open_gates: Array) -> void:
	for slime_id in tracked_ids():
		if not bodies.has(slime_id) or bodies.state_of(slime_id) != SlimeBodies.FREE:
			_records.erase(slime_id)
	for slime_id in bodies.ids():
		var s := bodies.index_of(slime_id)
		if bodies.state[s] != SlimeBodies.FREE:
			continue
		var centre := bodies.centre_of(slime_id)
		if not _records.has(slime_id):
			var fresh := _record_for(slime_id, tick)
			fresh["phase"] = HEADING_BACK
			fresh["since"] = tick
			fresh["point"] = centre
		var record: Dictionary = _records[slime_id]
		var extra := bodies.ring_radius[s] - SlimeBodies.RING_RADIUS_SIZE_1
		match record["phase"]:
			ANSWERING:
				var reached := centre.distance_to(record["point"]) <= REACHED + extra
				if reached or tick - record["since"] >= int(CALL_SECONDS * Simulation.TICK_RATE):
					record["phase"] = UNSURE
					record["since"] = tick
			UNSURE:
				if tick - record["since"] >= int(UNSURE_SECONDS * Simulation.TICK_RATE):
					record["phase"] = HEADING_BACK
					record["since"] = tick
			HEADING_BACK:
				if level == null or level.loop == null:
					continue
				if level.loop.closest(centre, open_gates)["gap"] <= REJOIN_DISTANCE + extra:
					bodies.set_state(slime_id, SlimeBodies.TRAIN)
					_records.erase(slime_id)


## Slime `slime_id`'s record, for saves: {"phase", "since", "point",
## "route", "rng_state" (its stream's state)}, or {} when it isn't free.
func record_of(slime_id: int) -> Dictionary:
	if not _records.has(slime_id):
		return {}
	var record: Dictionary = _records[slime_id]
	return {"phase": record["phase"], "since": record["since"], "point": record["point"],
			"route": record["route"], "rng_state": (record["stream"] as Rng).state}


## Puts back a free slime's record from a save (record_of). Without a
## "rng_state" its stream starts fresh, as if it had become free at "since".
func restore_record(slime_id: int, record: Dictionary) -> void:
	var since: int = record.get("since", 0)
	var stream := _master.derive("free:%d:%d" % [slime_id, since])
	if record.has("rng_state"):
		stream.state = record["rng_state"]
	_records[slime_id] = {"phase": record.get("phase", HEADING_BACK), "since": since,
			"point": record.get("point", Vector2.ZERO), "route": record.get("route", ""), "stream": stream}


## The free slimes and the last call as plain data, for Simulation.dump().
func dump() -> Dictionary:
	var slimes := []
	for slime_id in tracked_ids():
		var record: Dictionary = _records[slime_id]
		slimes.append({"id": slime_id, "phase": record["phase"], "since": record["since"],
				"point": (record["point"] as Vector2).snapped(Vector2(0.01, 0.01)),
				"route": record["route"], "rng_state": str((record["stream"] as Rng).state)})
	var last_call: Variant = null
	if call_tick >= 0:
		last_call = {"point": call_point.snapped(Vector2(0.01, 0.01)), "tick": call_tick}
	return {"call": last_call, "slimes": slimes}


# --- Internals --------------------------------------------------------------

## The slime's record, made (with a fresh stream) when it has none.
func _record_for(slime_id: int, tick: int) -> Dictionary:
	if not _records.has(slime_id):
		_records[slime_id] = {"phase": HEADING_BACK, "since": tick, "point": Vector2.ZERO,
				"route": "", "stream": _master.derive("free:%d:%d" % [slime_id, tick])}
	return _records[slime_id]


## The take-off velocity of a hop from `from` toward `target`: at most
## `reach` px sideways (the rise scaled with it), at most max_rise() up.
static func _toward(from: Vector2, target: Vector2, reach: float, apex: float, size: int,
		gravity: float) -> Vector2:
	var d := target - from
	var dx := clampf(d.x, -reach, reach)
	var dy := d.y
	if absf(d.x) > reach:
		dy = d.y * reach / absf(d.x)
	dy = maxf(dy, -max_rise(size, gravity))
	return Train.aim(from, from + Vector2(dx, dy), apex, gravity, Train.hop_cap(size))


## Where a heading-back slime at `from` hops for: along its branch's route
## back, or at the nearest point of the current loop (see the class doc).
## Records the route chosen.
func _way_back(record: Dictionary, from: Vector2, reach: float, level: LevelData,
		open_gates: Array) -> Vector2:
	record["route"] = ""
	if level == null:
		return from
	var branch := level.branch_at(from)
	var route := level.route_back_for(branch) if not branch.is_empty() else ""
	if not route.is_empty():
		var points: PackedVector2Array = level.route_backs[route]["points"]
		var lengths: PackedFloat64Array = level.route_backs[route]["lengths"]
		var on := Polyline.closest(points, lengths, from)
		var end := lengths[lengths.size() - 1]
		if on["distance"] < end - 1.0:
			record["route"] = route
			return Polyline.point_at(points, lengths, on["distance"] + reach)
	if level.loop == null:
		return from
	var nearest := level.loop.closest(from, open_gates)
	var target: Vector2 = nearest["position"]
	var dx := target.x - from.x
	if absf(dx) < MIN_SIDEWAYS:
		# The loop is below, more or less: hop the way it runs there (always
		# the same way, so the slime never hops to and fro above a crest),
		# level with where the slime stands, so the hop carries it the whole
		# MIN_SIDEWAYS before it comes down and it clears a ledge's edge.
		var ahead := level.loop.position_at(nearest["distance"] + 1.0, open_gates)
		var way := 1.0 if ahead.x >= target.x else -1.0
		target = Vector2(from.x + way * MIN_SIDEWAYS, minf(target.y, from.y))
	return target


## Whether slime index `s`, centred at `centre`, stands on terrain no steeper
## than 45°.
static func _on_gentle_ground(bodies: SlimeBodies, s: int, centre: Vector2) -> bool:
	if bodies.terrain == null:
		return false
	var below := centre + Vector2(0.0, bodies.ring_radius[s] + SlimeBodies.EDGE + 4.0)
	var normal: Vector2 = bodies.terrain.resolve(below)["normal"]
	return normal != Vector2.ZERO and normal.y <= GRIP_NORMAL_Y
