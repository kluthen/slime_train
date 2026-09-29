class_name Offscreen
extends RefCounted
## Physics only on or near the screen (master spec §5.3, D69, D70, D96;
## chunk 15). Plain data and pure logic over SlimeBodies, no scene nodes; the
## Simulation owns one (`offscreen`) and calls step() at the start of every
## tick, before anything steers or ticks the bodies.
##
## Parking. A slime whose centre leaves the view grown by PARK_MARGIN is
## parked (SlimeBodies.park: neither simulated nor touched); one whose centre
## comes within the view grown by NEAR_MARGIN is simulated again
## (SlimeBodies.unpark), at rest where it was put: the view comes near it and
## it appears just outside the view. Between the two margins a slime keeps
## what it was, so it never flickers. Every state parks, sleepers and piles
## included; fusion and waking already happen on screen only.
##
## Parked slimes move on their own, at the deterministic pace (pace()):
##   train      a position along the loop: its progress moves pace × dt
##              on (SLIDE_SPEED on a slide), by Train.advance() from the
##              loop point there (the point projects onto itself, so the
##              progress moves the whole step on any slope), and its centre
##              is put on that point, lifted by its size (lift()) along the
##              loop's normal (up_normal()), where a slime resting on the
##              slope has its centre; on the flat that is straight up, like
##              spawn_train_slime(). Train.follow() then projects it as
##              usual, never backward, so the laps, the stall checks and the
##              gates growing the loop all work unchanged. (Lifted straight
##              up on a downhill stretch, the centre projected behind its
##              progress, which never goes back: a big slime stopped there
##              and stalled.) Single file: it never moves
##              closer than the two slimes' widths (ring radius plus EDGE,
##              each) behind the train slime ahead of it along the loop,
##              parked or not; it waits there, as it would bump into it on
##              screen (_train_room(); from the distances at the start of
##              the tick, so the order the proxies move in doesn't matter;
##              on one spot, the higher id is ahead). (Without it, a parked
##              slime faster than the one ahead, on the slide or bigger, ran
##              through it, and the two came back on screen on one spot,
##              where two rings never come apart.) Over an open
##              trapdoor (its box grown ENTRY_REACH upward) it drops into
##              the basket instead: it is put in the basket box's next free
##              clear slot (a grid its own width plus SLOT_GAP apart,
##              bottom row first), where the
##              frontier sets catch it. Baskets so keep counting weight off
##              screen, and fill there; the reward and the firing already
##              wait until the basket is in view.
##   free       placed on the nearest point of its area's route back (the
##              route serving the exploration branch it is in) when that
##              point is within ROUTE_NEAR, queued a slime's width behind
##              any slime already following it from there, and follows it at
##              the same pace;
##              outside any branch, it goes straight for the nearest point
##              of the current loop when that is within ROUTE_NEAR. At the
##              end it rejoins the train (state train; the Train adopts it
##              where the loop passes closest). With no route back near it
##              stays where it is, and is lost in time (below).
##   others     sleepers, slimes in a basket, bedtime-asleep slimes stay put.
##
## Left alone and lost (D10). A free slime whose centre is outside the view
## (the screen itself, no margin) counts off-screen ticks from `away`; back
## on screen, or no longer free, the count stops. After LEFT_ALONE_TICKS it
## is left alone; LOST_TICKS after that, still free, it is lost (lose()):
## moved to the start of the loop, back on the train (LoopStart.move, shared
## with the stuck and stalled safety nets), and logged in `lost`. A free
## slime that stays on screen is never lost.
##
## Zoomed out (D96). Below LOW_ZOOM every slime's ring uses the zoomed-out
## point counts (SlimeBodies.set_low_detail); from FULL_ZOOM up the full
## ones. In between the detail stays what it was.
##
## Resting piles (SlimeBodies' resting-pile rule) are also woken here by the
## two disturbances the bodies can't see: a call (every resting slime within
## the call radius of its point, on the tick it is made) and a change of
## the tilt's way down (every resting slime). The frontier sets wake the
## piles by their doors.
##
## `enabled` is a mode, like Simulation.screensaver: not in dump() nor saves.
## The game turns it on (src/main.gd); off, nothing parks, and a slime parked
## before is simulated again (the core's tests run with every slime
## simulated). The state it keeps (away counts, proxies' routes, lost log,
## zoomed out) is in dump() and in saves ("offscreen", SaveData).
## Everything is decided by the tick, the view and the saved state: no
## randomness.
# @spec-link [[req_offscreen_simulation]]
# @spec-link [[rule_left_alone_and_lost]]

## Parked beyond the view grown by this, px (a third of a screen).
const PARK_MARGIN := 384.0
## Simulated again within the view grown by this, px (a quarter of a screen).
const NEAR_MARGIN := 288.0
## A free slime's route back (or the loop) is near within this, px.
const ROUTE_NEAR := 288.0
## Off screen this long, a free slime is left alone (10 s, D10).
const LEFT_ALONE_TICKS := 600
## Left alone this long and still free, it is lost (1 min, D10).
const LOST_TICKS := 3600
## A parked train slime drops through an open trapdoor when its centre is in
## the trapdoor's box grown this far upward, px (the loop rides above it).
const ENTRY_REACH := 64.0
## The room between two slots of the grid a parked slime drops into a basket
## on, px (the grid's pitch is the slime's width plus this).
const SLOT_GAP := 4.0
## Below this zoom rings use fewer points; from FULL_ZOOM up the full count.
const LOW_ZOOM := 0.8
const FULL_ZOOM := 0.85
## Single file (_train_room()): train slimes are ordered along the loop by
## their distance in 1/ORDER_SCALE px, then by id (the low 32 bits).
const ORDER_SCALE := 64.0
const ORDER_ID_MASK := 0xFFFFFFFF
## How many lost slimes `lost` keeps.
const LOST_LOG_SIZE := 16
## How much closer than a slime's width two queued proxies may sit before
## one is moved back, px: absorbs floating-point rounding when queueing.
const QUEUE_TOLERANCE := 0.001
const LOST := "lost"

## Physics only near the screen (the game's mode). Not saved.
var enabled := false
## Whether the rings use the zoomed-out point counts.
var zoomed_out := false
## Free slime id -> the tick its off-screen count starts from.
var away := {}
## Parked free slime id -> the way it follows: {"route": the route back's
## stable ID, or "" for a straight line, "along": px along it, "from", "to":
## the straight line's ends}.
var proxies := {}
## The last LOST_LOG_SIZE lost slimes, oldest first: {"id", "tick", "reason"}.
var lost: Array[Dictionary] = []


## The deterministic pace of a slime of `size` off screen, px/s: one hop
## reach per mean hop interval, scaled by the bodies' hop rate.
static func pace(size: int, hop_rate := 1.0) -> float:
	var interval := SlimeBodies.hop_interval_range(size)
	return Train.hop_reach(size) / ((interval.x + interval.y) * 0.5) * hop_rate


## How far above a route (drawn at a base slime's centre height) a slime of
## `size` rides, px.
static func lift(size: int) -> float:
	return SlimeBodies.ring_radius_for(size) - SlimeBodies.ring_radius_for(1)


## The unit normal of a route running along `direction` on its upper side
## (up is negative y): the way a slime resting on it is lifted. Square to a
## vertical stretch, it points to the route's left.
static func up_normal(direction: Vector2) -> Vector2:
	var normal := Vector2(direction.y, -direction.x)
	return -normal if normal.y > 0.0 else normal


## Whether free slime `slime_id` is left alone at `tick`.
func is_left_alone(slime_id: int, tick: int) -> bool:
	return away.has(slime_id) and tick - int(away[slime_id]) >= LEFT_ALONE_TICKS


## One tick, at its start (see the class doc).
func step(sim: Simulation) -> void:
	var bodies := sim.slimes
	_disturb(sim)
	if not enabled:
		for slime_id in bodies.ids():
			bodies.unpark(slime_id)
		away.clear()
		proxies.clear()
		return
	_detail(sim)
	var shown := Fusion.view_rect(sim.view)
	var near := shown.grow(NEAR_MARGIN)
	var far := shown.grow(PARK_MARGIN)
	for slime_id in bodies.ids():
		var centre := bodies.centre_of(slime_id)
		if near.has_point(centre):
			bodies.unpark(slime_id)
		elif not far.has_point(centre):
			bodies.park(slime_id)
	for slime_id in proxies.keys():
		if not bodies.is_parked(slime_id) or bodies.state_of(slime_id) != SlimeBodies.FREE:
			proxies.erase(slime_id)
	var room := _train_room(sim)
	for slime_id in bodies.ids():
		if not bodies.is_parked(slime_id):
			continue
		match bodies.state_of(slime_id):
			SlimeBodies.TRAIN:
				_train_proxy(sim, slime_id, room)
			SlimeBodies.FREE:
				_free_proxy(sim, slime_id)
	_count_away(sim, shown)


## The state as plain data, for Simulation.dump().
func dump() -> Dictionary:
	var counts := []
	for slime_id in _sorted_ids(away):
		counts.append({"id": slime_id, "since": away[slime_id]})
	var ways := []
	for slime_id in _sorted_ids(proxies):
		var way: Dictionary = proxies[slime_id]
		ways.append({"id": slime_id, "route": way["route"], "along": snappedf(way["along"], 0.001),
				"from": (way["from"] as Vector2).snapped(Vector2(0.01, 0.01)),
				"to": (way["to"] as Vector2).snapped(Vector2(0.01, 0.01))})
	return {"zoomed_out": zoomed_out, "away": counts, "proxies": ways, "lost": lost.duplicate(true)}


## Puts back the state saved from dump()'s plain data (with exact values).
func restore(data: Dictionary) -> void:
	zoomed_out = bool(data.get("zoomed_out", false))
	away = {}
	for entry in data.get("away", []):
		away[int(entry["id"])] = int(entry["since"])
	proxies = {}
	for entry in data.get("proxies", []):
		proxies[int(entry["id"])] = {"route": str(entry["route"]), "along": float(entry["along"]),
				"from": entry["from"], "to": entry["to"]}
	lost = []
	for entry in data.get("lost", []):
		lost.append({"id": int(entry["id"]), "tick": int(entry["tick"]), "reason": str(entry["reason"])})


# --- Internals --------------------------------------------------------------

## Wakes the resting piles a call or a tilt change disturbs.
func _disturb(sim: Simulation) -> void:
	var bodies := sim.slimes
	if sim.free_slimes.call_tick == sim.tick:
		bodies.wake_around(sim.free_slimes.call_point, sim.call_radius())
	if not sim.phone_tilt.down().is_equal_approx(bodies.free_down):
		for slime_id in bodies.ids():
			if bodies.calm_of(slime_id) == SlimeBodies.RESTING:
				bodies.wake(slime_id)


## Low detail below LOW_ZOOM, full from FULL_ZOOM up.
func _detail(sim: Simulation) -> void:
	if sim.view.zoom < LOW_ZOOM:
		zoomed_out = true
	elif sim.view.zoom >= FULL_ZOOM:
		zoomed_out = false
	for slime_id in sim.slimes.ids():
		sim.slimes.set_low_detail(slime_id, zoomed_out)


## Moves parked train slime `slime_id` on along the loop (see the class doc):
## its progress first, from the loop point itself, then its centre, lifted
## along the loop's normal. It moves at most `room[slime_id]` px when `room`
## (_train_room()) has it: single file.
func _train_proxy(sim: Simulation, slime_id: int, room: Dictionary) -> void:
	var train := sim.train
	if train == null or not train.tracks(slime_id) or train.length() <= 0.0:
		return
	var bodies := sim.slimes
	var size := bodies.size_of(slime_id)
	var distance := train.distance_of(slime_id)
	var speed := Train.SLIDE_SPEED if train.is_slide_at(distance) else pace(size, bodies.hop_rate)
	var step := speed * Simulation.TICK_SECONDS
	if room.has(slime_id):
		step = minf(step, room[slime_id])
	var ahead := distance + step
	var on := train.position_at(ahead)
	# The point on the loop projects onto itself: the progress moves the whole
	# step, whatever the slope and the lift (a lifted point could project
	# behind, and progress never goes back: it stalled).
	train.advance(slime_id, on, sim.tick)
	var at := on + up_normal(train.direction_at(ahead)) * lift(size)
	var basket := _basket_below(sim, at)
	if not basket.is_empty():
		at = _slot(sim, basket, size)
	bodies.translate(slime_id, at - bodies.centre_of(slime_id))


## Single file for the parked train slimes (see the class doc): parked
## train slime id -> how far it may move on this tick, px: its gap along the
## loop to the train slime ahead of it (parked or not) less both slimes'
## widths, never below 0. Read from the distances at the start of the tick.
## Empty when no train slime is parked or there is only one.
func _train_room(sim: Simulation) -> Dictionary:
	var room := {}
	var train := sim.train
	if train == null or train.length() <= 0.0:
		return room
	var bodies := sim.slimes
	# Along the loop, back to front, as one sortable integer per slime (a
	# native sort: a sort_custom here cost 1 ms a tick with 200 train
	# slimes): the distance in 1/ORDER_SCALE px, then the id, so on one spot
	# the higher id is ahead.
	var order := PackedInt64Array()
	var any_parked := false
	for slime_id in train.tracked_ids():
		if bodies.state_of(slime_id) == SlimeBodies.TRAIN:
			order.append((int(train.distance_of(slime_id) * ORDER_SCALE) << 32) | slime_id)
			any_parked = any_parked or bodies.is_parked(slime_id)
	if not any_parked or order.size() < 2:
		return room
	order.sort()
	var count := order.size()
	for k in count:
		var slime_id := int(order[k] & ORDER_ID_MASK)
		if not bodies.is_parked(slime_id):
			continue
		var next := int(order[(k + 1) % count] & ORDER_ID_MASK)
		var gap := train.distance_of(next) - train.distance_of(slime_id)
		if k == count - 1:
			gap += train.length()
		var widths := SlimeBodies.ring_radius_for(bodies.size_of(slime_id)) \
				+ SlimeBodies.ring_radius_for(bodies.size_of(next)) + 2.0 * SlimeBodies.EDGE
		# Two within 1/ORDER_SCALE px may come in id order: a gap a hair
		# below 0, no room.
		room[slime_id] = maxf(0.0, gap - widths)
	return room


## Moves parked free slime `slime_id` along its way back (see the class
## doc), and puts it back on the train at the way's end.
func _free_proxy(sim: Simulation, slime_id: int) -> void:
	var bodies := sim.slimes
	var centre := bodies.centre_of(slime_id)
	var size := bodies.size_of(slime_id)
	if not proxies.has(slime_id):
		var way := _way_for(sim, centre)
		if way.is_empty():
			return
		if way["route"] != "":
			_queue(way, 2.0 * (SlimeBodies.ring_radius_for(size) + SlimeBodies.EDGE))
		proxies[slime_id] = way
	var way: Dictionary = proxies[slime_id]
	way["along"] = float(way["along"]) + pace(size, bodies.hop_rate) * Simulation.TICK_SECONDS
	var at: Vector2
	var done := false
	if way["route"] != "":
		var route: Dictionary = sim.level.route_backs[way["route"]]
		var lengths: PackedFloat64Array = route["lengths"]
		done = way["along"] >= lengths[lengths.size() - 1]
		at = Polyline.point_at(route["points"], lengths, way["along"])
	else:
		var from: Vector2 = way["from"]
		var span := from.distance_to(way["to"])
		done = way["along"] >= span
		at = from.lerp(way["to"], 1.0 if done else way["along"] / span)
	bodies.translate(slime_id, at + Vector2(0.0, -lift(size)) - centre)
	if done:
		proxies.erase(slime_id)
		bodies.set_state(slime_id, SlimeBodies.TRAIN)


## Puts a new way on a route back `spacing` px behind every proxy already
## on that route within `spacing` of it, so slimes that went off screen
## together follow it in single file instead of on one point.
func _queue(way: Dictionary, spacing: float) -> void:
	# A proxy that was just placed `spacing` behind another may come out a
	# hair closer than `spacing` in floating point (a - (a - s) < s), so the
	# check keeps a tolerance, and the loop is bounded: `along` only ever
	# goes down, once per proxy at most.
	var moved := true
	var rounds := 0
	while moved and rounds <= proxies.size():
		moved = false
		rounds += 1
		for other in _sorted_ids(proxies):
			var ahead: Dictionary = proxies[other]
			if ahead["route"] != way["route"]:
				continue
			if absf(float(ahead["along"]) - float(way["along"])) < spacing - QUEUE_TOLERANCE:
				way["along"] = float(ahead["along"]) - spacing
				moved = true


## The way back for a free slime parked at `centre` (see the class doc), or
## {} when no route back and no loop is near.
func _way_for(sim: Simulation, centre: Vector2) -> Dictionary:
	var level := sim.level
	if level == null:
		return {}
	var branch := level.branch_at(centre)
	var route := level.route_back_for(branch) if not branch.is_empty() else ""
	if not route.is_empty():
		var on := Polyline.closest(level.route_backs[route]["points"], level.route_backs[route]["lengths"], centre)
		if on["gap"] <= ROUTE_NEAR:
			return {"route": route, "along": on["distance"], "from": Vector2.ZERO, "to": Vector2.ZERO}
	if branch.is_empty() and level.loop != null:
		var gates: Array = sim.train.open_gates if sim.train != null else []
		var nearest := level.loop.closest(centre, gates)
		if nearest["gap"] <= ROUTE_NEAR:
			return {"route": "", "along": 0.0, "from": centre, "to": nearest["position"]}
	return {}


## Counts the free slimes' off-screen ticks, and moves the lost ones.
func _count_away(sim: Simulation, shown: Rect2) -> void:
	var bodies := sim.slimes
	for slime_id in away.keys():
		if not bodies.has(slime_id) or bodies.state_of(slime_id) != SlimeBodies.FREE:
			away.erase(slime_id)
	for slime_id in bodies.ids():
		if bodies.state_of(slime_id) != SlimeBodies.FREE:
			continue
		if shown.has_point(bodies.centre_of(slime_id)):
			away.erase(slime_id)
			continue
		if not away.has(slime_id):
			away[slime_id] = sim.tick
		elif sim.tick - int(away[slime_id]) >= LEFT_ALONE_TICKS + LOST_TICKS:
			lose(sim, slime_id)


## Slime `slime_id` is lost (D10): it goes to the start of the loop, back on
## the train (LoopStart.move, the move stuck and stalled slimes take too), and
## is logged in `lost`. Its off-screen count and way go. Nothing without a
## train. Also the debug overlay's kill tool (DebugKill).
# @spec-link [[rule_left_alone_and_lost]]
func lose(sim: Simulation, slime_id: int) -> void:
	away.erase(slime_id)
	proxies.erase(slime_id)
	if sim.train == null:
		return
	LoopStart.move(sim.slimes, sim.train, slime_id)
	lost.append({"id": slime_id, "tick": sim.tick, "reason": LOST})
	if lost.size() > LOST_LOG_SIZE:
		lost.pop_front()


## The basket whose switch's open trapdoor lies under `at`, or "": off
## screen, the train still fills the baskets (FrontierSets weighs them).
# @spec-link [[req_switch_basket_gate_set]]
func _basket_below(sim: Simulation, at: Vector2) -> String:
	var level := sim.level
	if level == null:
		return ""
	var ids := PackedStringArray(level.switches.keys())
	ids.sort()
	for id in ids:
		var state: Dictionary = sim.object_states.get(id, {})
		var trapdoor: Rect2 = level.switches[id]["trapdoor"]
		if state.is_empty() or state["trapdoor_shut"] or not trapdoor.has_area():
			continue
		if trapdoor.grow_individual(0.0, ENTRY_REACH, 0.0, 0.0).has_point(at):
			var basket := str(level.switches[id]["basket"])
			if level.baskets.has(basket):
				return basket
	return ""


## The first free slot of basket `id`'s box for a slime of `size`: on a
## grid the slime's width plus SLOT_GAP apart, bottom row first, left to
## right, the first spot clear of every slime already in the box. With none
## clear, the top row's middle (the bodies push apart once simulated).
func _slot(sim: Simulation, id: String, size: int) -> Vector2:
	var box: Rect2 = sim.level.baskets[id]["box"]
	var bodies := sim.slimes
	var inside := []
	for slime_id in bodies.ids():
		if bodies.state_of(slime_id) != SlimeBodies.SLEEPER and box.has_point(bodies.centre_of(slime_id)):
			inside.append(slime_id)
	var radius := SlimeBodies.ring_radius_for(size) + SlimeBodies.EDGE
	var pitch := 2.0 * radius + SLOT_GAP
	var columns := maxi(1, int(box.size.x / pitch))
	var rows := maxi(1, int(box.size.y / pitch))
	var left := box.position.x + (box.size.x - columns * pitch) * 0.5 + pitch * 0.5
	var bottom := box.end.y - radius - 2.0
	for row in rows:
		for column in columns:
			var at := Vector2(left + pitch * column, bottom - pitch * row)
			var clear := true
			for slime_id in inside:
				var room := radius + SlimeBodies.ring_radius_for(bodies.size_of(slime_id)) + SlimeBodies.EDGE
				if at.distance_to(bodies.centre_of(slime_id)) < room:
					clear = false
					break
			if clear:
				return at
	return Vector2(box.get_center().x, bottom - pitch * (rows - 1))


static func _sorted_ids(dictionary: Dictionary) -> PackedInt32Array:
	var out := PackedInt32Array(dictionary.keys())
	out.sort()
	return out
