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
##              through it, and the two came back on screen on one spot:
##              two rings that then pushed each other in, before O91's fix
##              in the contacts, and that now part with a jolt.) Over an open
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
## is left alone; LOST_TICKS after that, still free, it is lost: due a move
## to the loop start, back on the train, it waits its turn in the
## loop-start queue (LoopStartQueue, D150) with its count still in `away`,
## carrying on meanwhile; at its turn, still free and off screen, it is
## moved (lose(): LoopStart.move, shared with the stuck and stalled safety
## nets) and logged in `lost`. A free slime that stays on screen is never
## lost.
##
## Detail (D96; crowd detail). Each tick, once the slimes near the view are
## simulated and the far ones parked, every calm ACTIVE ring takes the
## detail level detail_level() (SlimeBodies.set_active_detail): the higher
## of the zoom's and the lower of the crowd's and the detail ceiling
## (D141): max(zoom's, min(crowd, ceiling)).
##   zoom       below LOW_ZOOM zoomed out: at least SlimeBodies.LOW_DETAIL;
##              from FULL_ZOOM up not; in between it stays what it was.
##   crowd      the slimes that cost physics this tick (calm ACTIVE, not
##              sleepers: SlimeBodies.crowd_count): level 1 from
##              CROWD_STEPS[0] (20), 2 from [1] (30), 3 from [2] (40); a
##              level goes down only once the count is CROWD_EASE (5) below
##              its step (15, 25, 35), so rings never reshape back and forth
##              (crowd_level_for). On a screen full of slimes the chaos
##              hides the rounder shapes, and the physics costs less.
##   ceiling    `detail_ceiling`, 0 to SlimeBodies.MAX_DETAIL: how far the
##              crowd may lower the detail. An input, like the tilt: the
##              game root hands it over before every tick (src/main.gd,
##              from the scene layer's LoadMeter in `auto`, D141), so a
##              change applies from the next tick. Its default is
##              MAX_DETAIL (`always`: the crowd's level as is, D140's
##              behaviour), what every run but normal play keeps. Not in
##              dump() nor saves: the state and its hash don't depend on it,
##              only the rings it shapes do.
## A pile slime (in a basket, asleep at bedtime) stops at
## SlimeBodies.PILE_MAX_DETAIL (level 2: at 6 points a pile creeps for long
## before it rests). A resting or parked ring keeps its points (a reshape
## would wake a resting pile); it takes the level on the tick it is ACTIVE
## again. From the slimes' states and the ceiling handed over, never from a
## measured time here: same seed and same ceilings, same hash (the default
## ceiling never changes, so a run that keeps it repeats exactly).
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
# @spec-link [[req_persistence_and_saves]]

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
## The crowd (active slimes) from which the rings take detail level 1, 2, 3.
const CROWD_STEPS: Array[int] = [20, 30, 40]
## A crowd level goes down once the count is this far below its step.
const CROWD_EASE := 5
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

## Physics only near the screen (the game's mode). Not saved. A mode of the
## game, not a test branch: the game turns it on (src/main.gd) and so do the
## bench tools, while bare simulations (the core's unit tests) simulate every
## slime.
var enabled := false
## Whether the rings use the zoomed-out point counts.
var zoomed_out := false
## The crowd's detail level, 0 to SlimeBodies.MAX_DETAIL (crowd_level_for).
var crowd_level := 0
## The detail ceiling (see the class doc), 0 to SlimeBodies.MAX_DETAIL: an
## input handed over at a tick boundary, not state. Not saved.
# @spec-link [[req_offscreen_simulation]]
# @spec-link [[req_test_level_and_test_mode]]
var detail_ceiling := SlimeBodies.MAX_DETAIL
## Free slime id -> the tick its off-screen count starts from.
var away := {}
## Parked free slime id -> the way it follows: {"route": the route back's
## stable ID, or "" for a straight line, "along": px along it, "from", "to":
## the straight line's ends}.
var proxies := {}
## The last LOST_LOG_SIZE lost slimes, oldest first: {"id", "tick", "reason"}.
var lost: Array[Dictionary] = []

# The switches a parked train slime may drop through (_basket_below), read
# once per level (_read_trapdoors): the level `_trapdoor_level`'s switches
# with a trapdoor into a basket of the level, by id ascending; their ids,
# their trapdoors grown ENTRY_REACH upward, their baskets. Not state: read
# off the level again after a load.
var _trapdoor_level: LevelData = null
var _trapdoor_ids := PackedStringArray()
var _trapdoor_reach: Array[Rect2] = []
var _trapdoor_baskets := PackedStringArray()


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


## The crowd's detail level for `count` active slimes, from `level` (the
## last tick's): up at each of CROWD_STEPS, down only CROWD_EASE below it.
# @spec-link [[req_offscreen_simulation]]
static func crowd_level_for(count: int, level: int) -> int:
	assert(count >= 0 and level >= 0 and level <= CROWD_STEPS.size(),
			"Offscreen.crowd_level_for: count %d, level %d" % [count, level])
	while level < CROWD_STEPS.size() and count >= CROWD_STEPS[level]:
		level += 1
	while level > 0 and count <= CROWD_STEPS[level - 1] - CROWD_EASE:
		level -= 1
	return level


## The detail level the active rings take (see the class doc): the higher of
## the zoom's and the lower of the crowd's and the ceiling.
# @spec-link [[req_offscreen_simulation]]
func detail_level() -> int:
	assert(detail_ceiling >= 0 and detail_ceiling <= SlimeBodies.MAX_DETAIL,
			"Offscreen: invalid detail ceiling %d" % detail_ceiling)
	return maxi(mini(crowd_level, detail_ceiling), SlimeBodies.LOW_DETAIL if zoomed_out else 0)


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
	var shown := Fusion.view_rect(sim.view)
	var near := shown.grow(NEAR_MARGIN)
	var far := shown.grow(PARK_MARGIN)
	# Each slime's centre, read once: nothing below moves a slime before its
	# own proxy does (parking only drops its velocity), so the proxies take it
	# from here.
	var ids := bodies.ids()
	var centres := PackedVector2Array()
	centres.resize(ids.size())
	for k in ids.size():
		var slime_id := ids[k]
		var centre := bodies.centre_of(slime_id)
		centres[k] = centre
		if near.has_point(centre):
			bodies.unpark(slime_id)
		elif not far.has_point(centre):
			bodies.park(slime_id)
	# After the parking: the crowd is who is simulated this tick, and a slime
	# just back takes the level before it ticks. Nothing below reads the
	# active slimes' centres (the proxies move parked ones only).
	_detail(sim)
	for slime_id in proxies.keys():
		if not bodies.is_parked(slime_id) or bodies.state_of(slime_id) != SlimeBodies.FREE:
			proxies.erase(slime_id)
	var room := _train_room(sim)
	for k in ids.size():
		var slime_id := ids[k]
		if not bodies.is_parked(slime_id):
			continue
		match bodies.state_of(slime_id):
			SlimeBodies.TRAIN:
				_train_proxy(sim, slime_id, room, centres[k])
			SlimeBodies.FREE:
				_free_proxy(sim, slime_id, centres[k])
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
	return {"zoomed_out": zoomed_out, "crowd_level": crowd_level, "away": counts, "proxies": ways,
			"lost": lost.duplicate(true)}


## Puts back the state saved from dump()'s plain data (with exact values).
func restore(data: Dictionary) -> void:
	zoomed_out = bool(data.get("zoomed_out", false))
	crowd_level = int(data.get("crowd_level", 0))
	assert(crowd_level >= 0 and crowd_level <= CROWD_STEPS.size(),
			"Offscreen.restore: invalid crowd level %d" % crowd_level)
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

## Wakes the resting slimes a call or a tilt change disturbs, each by itself
## (the local wake, D156): those within the call's radius, every one on a tilt.
# @spec-link [[req_offscreen_simulation]]
func _disturb(sim: Simulation) -> void:
	var bodies := sim.slimes
	if sim.free_slimes.call_tick == sim.tick:
		bodies.wake_around(sim.free_slimes.call_point, sim.call_radius())
	if not sim.phone_tilt.down().is_equal_approx(bodies.free_down):
		for slime_id in bodies.ids():
			if bodies.calm_of(slime_id) == SlimeBodies.RESTING:
				bodies.wake(slime_id)


## The zoom's and the crowd's detail (see the class doc), given to every
## active ring.
# @spec-link [[req_offscreen_simulation]]
func _detail(sim: Simulation) -> void:
	if sim.view.zoom < LOW_ZOOM:
		zoomed_out = true
	elif sim.view.zoom >= FULL_ZOOM:
		zoomed_out = false
	crowd_level = crowd_level_for(sim.slimes.crowd_count(), crowd_level)
	sim.slimes.set_active_detail(detail_level())


## Moves parked train slime `slime_id` on along the loop (see the class doc):
## its progress first, from the loop point itself, then its centre, lifted
## along the loop's normal. It moves at most `room[slime_id]` px when `room`
## (_train_room()) has it: single file. `centre`: its centre now.
func _train_proxy(sim: Simulation, slime_id: int, room: Dictionary, centre: Vector2) -> void:
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
	bodies.translate(slime_id, at - centre)


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
		if bodies.has(slime_id) and bodies.state_of(slime_id) == SlimeBodies.TRAIN:
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
## doc), and puts it back on the train at the way's end. `centre`: its
## centre now.
func _free_proxy(sim: Simulation, slime_id: int, centre: Vector2) -> void:
	var bodies := sim.slimes
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


## Counts the free slimes' off-screen ticks (the lost ones wait in the
## loop-start queue, their count kept).
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
		# Past LEFT_ALONE_TICKS + LOST_TICKS it is lost: the loop-start queue
		# reads that from `away`.


## Slime `slime_id` is lost (D10): it goes to the loop start, back on the
## train (LoopStart.move, the move stuck and stalled slimes take too),
## `distance` px along the loop, and is logged in `lost`. Its off-screen
## count, way and stuck counts go. Nothing without a train. The loop-start
## queue gives the spot at a lost slime's turn; without one (`distance`
## negative) the move is immediate, outside the queue, to LoopStart.spot_now:
## the debug overlay's kill tool (DebugKill), and a slime lost on load
## (SaveData, MidairLanding).
# @spec-link [[rule_left_alone_and_lost]]
func lose(sim: Simulation, slime_id: int, distance := -1.0) -> void:
	away.erase(slime_id)
	proxies.erase(slime_id)
	if sim.train == null:
		return
	if distance < 0.0:
		distance = LoopStart.spot_now(sim, slime_id, sim.tick)
	LoopStart.move(sim.slimes, sim.train, slime_id, distance)
	sim.stuck_slimes.forget(slime_id)
	lost.append({"id": slime_id, "tick": sim.tick, "reason": LOST})
	if lost.size() > LOST_LOG_SIZE:
		lost.pop_front()


## The basket whose switch's open trapdoor lies under `at`, or "": off
## screen, the train still fills the baskets (FrontierSets weighs them).
## Only with a level loaded (a train rides a level's loop).
# @spec-link [[req_switch_basket_gate_set]]
func _basket_below(sim: Simulation, at: Vector2) -> String:
	var level := sim.level
	assert(level != null, "Offscreen._basket_below: no level loaded")
	if level != _trapdoor_level:
		_read_trapdoors(level)
	for k in _trapdoor_ids.size():
		if not _trapdoor_reach[k].has_point(at):
			continue
		var state: Dictionary = sim.object_states.get(_trapdoor_ids[k], {})
		if not state.is_empty() and not state["trapdoor_shut"]:
			return _trapdoor_baskets[k]
	return ""


## Reads `level`'s switches with a trapdoor into one of its baskets, by id
## ascending, into the `_trapdoor_*` arrays (see them).
func _read_trapdoors(level: LevelData) -> void:
	_trapdoor_level = level
	_trapdoor_ids = PackedStringArray()
	_trapdoor_reach = []
	_trapdoor_baskets = PackedStringArray()
	var ids := PackedStringArray(level.switches.keys())
	ids.sort()
	for id in ids:
		var trapdoor: Rect2 = level.switches[id]["trapdoor"]
		var basket := str(level.switches[id]["basket"])
		if not trapdoor.has_area() or not level.baskets.has(basket):
			continue
		_trapdoor_ids.append(id)
		_trapdoor_reach.append(trapdoor.grow_individual(0.0, ENTRY_REACH, 0.0, 0.0))
		_trapdoor_baskets.append(basket)


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
