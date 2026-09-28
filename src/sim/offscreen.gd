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
##   train      a position along the loop: its centre is put pace × dt
##              further along the loop (SLIDE_SPEED on a slide), lifted by
##              its size like spawn_train_slime(). Train.follow() then
##              projects it as usual, so the laps, the lost checks and the
##              gates growing the loop all work unchanged. Over an open
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
## is left alone; LOST_TICKS after that, still free, it is lost: moved to the
## start of the loop (distance 0, lifted by its size), back on the train,
## and logged in `lost`. A free slime that stays on screen is never lost.
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
	for slime_id in bodies.ids():
		if not bodies.is_parked(slime_id):
			continue
		match bodies.state_of(slime_id):
			SlimeBodies.TRAIN:
				_train_proxy(sim, slime_id)
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


func _train_proxy(sim: Simulation, slime_id: int) -> void:
	var train := sim.train
	if train == null or not train.tracks(slime_id) or train.length() <= 0.0:
		return
	var bodies := sim.slimes
	var size := bodies.size_of(slime_id)
	var distance := train.distance_of(slime_id)
	var speed := Train.SLIDE_SPEED if train.is_slide_at(distance) else pace(size, bodies.hop_rate)
	var at := train.position_at(distance + speed * Simulation.TICK_SECONDS) + Vector2(0.0, -lift(size))
	var basket := _basket_below(sim, at)
	if not basket.is_empty():
		at = _slot(sim, basket, size)
	bodies.translate(slime_id, at - bodies.centre_of(slime_id))


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
			_lose(sim, slime_id)


## Moves lost slime `slime_id` to the start of the loop, back on the train.
func _lose(sim: Simulation, slime_id: int) -> void:
	var bodies := sim.slimes
	away.erase(slime_id)
	proxies.erase(slime_id)
	if sim.train == null:
		return
	var at := sim.train.position_at(0.0) + Vector2(0.0, -lift(bodies.size_of(slime_id)))
	if bodies.is_parked(slime_id):
		bodies.translate(slime_id, at - bodies.centre_of(slime_id))
	else:
		var body := bodies.body_of(slime_id)
		var shift: Vector2 = at - bodies.centre_of(slime_id)
		var points: PackedVector2Array = body["points"]
		for k in points.size():
			points[k] += shift
		body["points"] = points
		body["previous"] = points.duplicate()
		body["centre"] = body["centre"] + shift
		body["supported"] = false
		bodies.set_body(slime_id, body)
	bodies.set_state(slime_id, SlimeBodies.TRAIN)
	bodies.set_hop_held(slime_id, false)
	sim.train.track(slime_id, 0.0)
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
