class_name FrontierSets
extends RefCounted
## The frontier sets (master spec §5.4): each switch, its basket and the gate
## the basket opens, and the one-time celebration when the last basket
## fires. Pure simulation logic: the Simulation owns one (`frontier`) and
## calls start() when a level is loaded (or a save restored), step() once a
## tick, and tap_switch() when a tap lands on a switch.
##
## Where the state lives. Every object's state is plain data in the
## Simulation, keyed by stable ID, so it is saved and hashed with the rest:
## - object_states[switch] = {"flipped": bool, "trapdoor_shut": bool}
## - object_states[basket] = {"phase": FILLING | FULL | REWARD | FIRED,
##   "weight": int, "since": tick the phase began (-1: never),
##   "next_release": first tick it may release its next slime}
## - gate_states[gate] = {"open": bool, "entrance_closed": bool}
## The celebration's done mark is the level's (saved, like the hint's), and
## its start tick is transient. start() fills in the objects the level has
## and gives saved values their types (JSON reads every number as a float);
## states of objects the level doesn't have are left as they are.
##
## One tick (step()), after fusion and before the train and the free slimes
## follow their slimes:
## 1. Every train or free slime whose centre is inside a basket's box goes
##    in it: state SlimeBodies.IN_BASKET (no hopping, no train, no call; it
##    falls and settles like any body).
## 2. Each basket weighs the slimes in it (a size-3 slime weighs 3). While
##    FILLING with its switch flipped it collects; reaching its quota it is
##    FULL. FULL waits until its box's centre is in the view, then plays the
##    REWARD for REWARD_SECONDS, then fires: the rules it triggers run (its
##    gate opens) and it is FIRED. When every basket of the level has fired,
##    the celebration plays, once per save.
## 3. A basket that isn't holding its slimes (FIRED, or FILLING with its
##    switch flipped back: the opt-out) releases them one at a time, lowest
##    id first, every RELEASE_SECONDS, at its outlet when there is room: the
##    slime is moved there, at rest, and rides the train again, hopping away
##    as soon as it lands there (O126). A slime that gets in a basket that
##    is no longer collecting is released too: once fired, a basket takes no
##    more slimes.
## 4. The doors: a switch's trapdoor is open while its basket collects, and
##    shuts again once no slime is in its way; a closed gate's box is solid;
##    an open gate's lid shuts the old slide entrance once no slime is in its
##    way. The shut ones are handed to SlimeBodies.doors, solved like the
##    terrain. A door that opens or shuts (a gate's box too, when it opens)
##    wakes the resting slimes within DOOR_WAKE_REACH of it (chunk 15),
##    only those: the rest of their piles rests on (D156).
##
## Bedtime (item 23.5, D105): while the session is at bedtime (paused()),
## the sets stand still. Baskets still catch and weigh, and the doors keep
## their states, but no phase changes, no basket releases a slime (the
## slimes in it stay `in_basket`, asleep in place; sunrise doesn't move them
## out), and a reward due waits: FULL doesn't turn to REWARD, and a REWARD
## playing has its `since` moved on by every bedtime tick, so its clock
## stands still and it plays the rest at sunrise (no gate opens at bedtime).
## A celebration playing stands still the same way (celebration_since) and
## isn't shown (celebration_showing()). All the pause needs is the
## session's phase and the states above, all saved: a save taken at bedtime
## reloads the same. Sunrise resumes everything where it stood.
##
## The lasting mark (item 23.11, ux D4): once the celebration has played
## (celebration_done, and its burst over), a small mark at the start of the
## loop shows the level is complete (mark_showing(), mark_point()), after a
## reload too. During the burst every awake slime on screen does a double
## hop (CelebrationHops, `hops`).
##
## Opening a gate adds it to the train's open gates (the loop grows: the
## section's return route is replaced by the next section's segments) and
## gate_states. Train slimes on the outgoing part keep their distance; those
## still on the old return route are put the same distance from the end of
## the new loop (the return routes share their end), and every slime's
## progress mark restarts, so the loop change doesn't count as a stall.
##
## A switch tap flips it only while its basket is FILLING: once the basket
## is full the set is locked, and once it has fired the set is inert for good.
## Everything is decided by the tick and the saved state: no randomness.
# @spec-link [[req_switch_basket_gate_set]]
# @spec-link [[req_interactive_objects_general]]
# @spec-link [[rule_gate_opens_via_switch_basket_set]]
# @spec-link [[rule_frontier_set_inert_after_gate_open]]
# @spec-link [[req_level_completion_celebration]]
# @spec-link [[req_session_lifecycle]]
# @spec-link [[req_slime_states]]

const FILLING := "filling"
const FULL := "full"
const REWARD := "reward"
const FIRED := "fired"
const PHASES: PackedStringArray = [FILLING, FULL, REWARD, FIRED]

## How long the reward plays before the basket fires, in seconds.
const REWARD_SECONDS := 2.0
## The time between two slimes released by a basket, in seconds.
const RELEASE_SECONDS := 0.3
## How long the celebration plays, in seconds.
const CELEBRATION_SECONDS := 4.0
## A basket's outlet is free when no slime is closer to it than the two
## radii plus this, in px.
const OUTLET_CLEARANCE := 8.0
## A door only shuts when no ring point is within this of it, in px.
const DOOR_CLEARANCE := SlimeBodies.EDGE
## A door opening or shutting wakes the resting slimes whose centre is within
## this of it, px (chunk 15): a size-3 slime's width.
const DOOR_WAKE_REACH := 80.0

## Whether the celebration has played in this save (the level's mark).
var celebration_done := false
## The tick the celebration began, or -1, moved on by every bedtime tick
## spent while it plays. Transient.
var celebration_since := -1
## The double hop of the awake slimes on screen during the burst.
var hops := CelebrationHops.new()

var _level: LevelData = null
## Gate stable ID -> the tick a basket fired it open in this run
## (gates_fired_open()). Transient: not saved, emptied by start().
var _opened_on := {}
## Stable ID -> TerrainSegments, one solid box each.
var _trapdoors := {}
var _barriers := {}
var _lids := {}


## The ticks a span of `seconds` lasts.
static func ticks(seconds: float) -> int:
	return int(round(seconds * Simulation.TICK_RATE))


## Where a basket with the "onward_route" outlet releases its slimes: on the
## outgoing route that leads into the return route gate `gate_id` retires,
## `before` px before that route's end (the slide entrance). Without such a
## return route, the outgoing route's point nearest `near`.
# @spec-link [[req_switch_basket_gate_set]]
static func onward_outlet(loop: LoopData, gate_id: String, before: float, near: Vector2) -> Vector2:
	if loop == null or loop.segments.is_empty():
		return near
	var last_out: Dictionary = {}
	for segment in loop.segments:
		if segment["kind"] == LoopData.OUTGOING:
			last_out = segment
		elif segment["gate"] == gate_id and not gate_id.is_empty() and not last_out.is_empty():
			return Polyline.point_at(last_out["points"], last_out["lengths"],
					maxf(last_out["length"] - before, 0.0))
	var best := near
	var best_gap := INF
	for segment in loop.segments:
		if segment["kind"] != LoopData.OUTGOING:
			continue
		var on := Polyline.closest(segment["points"], segment["lengths"], near)
		if on["gap"] < best_gap:
			best_gap = on["gap"]
			best = on["position"]
	return best


# --- Loading --------------------------------------------------------------------

## Takes the level's frontier sets: every switch, basket and gate the level
## has gets a state (the saved one with its types, or the default), the
## train's open gates and the gate states agree, and the doors are set.
## Called by Simulation.load_level and again once a save's states are in.
func start(sim: Simulation) -> void:
	_level = sim.level
	_opened_on = {}
	_trapdoors = {}
	_barriers = {}
	_lids = {}
	if _level == null:
		sim.slimes.doors = []
		return
	for id in _sorted(_level.baskets):
		sim.object_states[id] = _basket_state(sim.object_states.get(id))
	for id in _sorted(_level.switches):
		sim.object_states[id] = _switch_state(sim, id, sim.object_states.get(id))
		var trapdoor: Rect2 = _level.switches[id]["trapdoor"]
		if trapdoor.has_area():
			_trapdoors[id] = _solid(trapdoor)
	var open_gates: Array = sim.train.open_gates.duplicate() if sim.train != null else []
	var grown := false
	for id in _sorted(_level.gates):
		var state := _gate_state(sim.gate_states.get(id))
		if id in open_gates:
			state["open"] = true
		elif state["open"]:
			open_gates.append(id)
			grown = true
		sim.gate_states[id] = state
		var gate: Dictionary = _level.gates[id]
		if (gate["box"] as Rect2).has_area():
			_barriers[id] = _solid(gate["box"])
		if (gate["lid"] as Rect2).has_area():
			_lids[id] = _solid(gate["lid"])
	if grown and sim.train != null:
		sim.train.set_open_gates(open_gates)
	_set_doors(sim)


static func _basket_state(saved: Variant) -> Dictionary:
	var from: Dictionary = saved if saved is Dictionary else {}
	var phase := str(from.get("phase", FILLING))
	return {"phase": phase if phase in PHASES else FILLING, "weight": int(from.get("weight", 0)),
			"since": int(from.get("since", -1)), "next_release": int(from.get("next_release", 0))}


func _switch_state(sim: Simulation, id: String, saved: Variant) -> Dictionary:
	var from: Dictionary = saved if saved is Dictionary else {}
	var state := {"flipped": bool(from.get("flipped", false)), "trapdoor_shut": true}
	state["trapdoor_shut"] = bool(from["trapdoor_shut"]) if from.has("trapdoor_shut") \
			else not _collecting(sim, id, state)
	return state


static func _gate_state(saved: Variant) -> Dictionary:
	var from: Dictionary = saved if saved is Dictionary else {}
	return {"open": bool(from.get("open", false)), "entrance_closed": bool(from.get("entrance_closed", false))}


# --- Taps -------------------------------------------------------------------------

## Only what answers a tap takes it (item 23.7, D109): of `targets` (tap
## targets, as LevelData.tap_targets), those that answer a tap now. A
## switch answers while its basket is filling (switch_answers()); a basket
## never does; other kinds (a sleeper: a call centred on it) pass through.
## A tap on anything left out lands on what is under it, open ground: a
## call, which in screensaver mode starts a session.
# @spec-link [[req_interactive_objects_general]]
# @spec-link [[req_controls_tap_zones]]
func answering(sim: Simulation, targets: Dictionary) -> Dictionary:
	var out := {}
	for id in targets:
		match targets[id]["kind"]:
			TapDispatcher.KIND_BASKET:
				pass
			TapDispatcher.KIND_SWITCH:
				if switch_answers(sim, id):
					out[id] = targets[id]
			_:
				out[id] = targets[id]
	return out


## Whether switch `id` answers a tap now: while its basket is filling. Once
## the basket is full the set is locked (no opting out of a full basket),
## and once it has fired the set is inert for good.
# @spec-link [[req_switch_basket_gate_set]]
# @spec-link [[rule_frontier_set_inert_after_gate_open]]
func switch_answers(sim: Simulation, id: String) -> bool:
	if _level == null or not _level.switches.has(id):
		return false
	var basket: Dictionary = sim.object_states.get(_level.switches[id]["basket"], {})
	return basket.is_empty() or basket["phase"] == FILLING


## A tap on switch `id`: flips it, while it answers (switch_answers()).
## Flipped back, the basket lets its slimes go (the opt-out). Returns
## whether it flipped.
func tap_switch(sim: Simulation, id: String) -> bool:
	if not switch_answers(sim, id):
		return false
	var state: Dictionary = sim.object_states[id]
	state["flipped"] = not state["flipped"]
	return true


# --- Ticking ----------------------------------------------------------------------

## One tick of every frontier set (see the class doc).
# @spec-link [[req_switch_basket_gate_set]]
func step(sim: Simulation) -> void:
	if _level == null:
		return
	var asleep := paused(sim)
	if not _level.baskets.is_empty():
		_catch(sim)
		var inside := _inside(sim)
		for id in _sorted(_level.baskets):
			if asleep:
				_basket_wait(sim, id, inside[id])
			else:
				_basket_step(sim, id, inside[id])
	if asleep:
		if celebration_playing(sim.tick):
			celebration_since += 1
	else:
		hops.step(sim, celebration_playing(sim.tick))
	_doors_step(sim)
	_set_doors(sim)


## Whether the frontier sets stand still now: at bedtime (see the class doc).
# @spec-link [[req_session_lifecycle]]
static func paused(sim: Simulation) -> bool:
	return sim.session.phase == Session.BEDTIME


## Whether the celebration is playing at `tick` (standing still at bedtime
## counts as playing: it isn't over).
func celebration_playing(tick: int) -> bool:
	return celebration_since >= 0 and tick - celebration_since < ticks(CELEBRATION_SECONDS)


## Whether the celebration's burst shows now: playing, and not at bedtime.
func celebration_showing(sim: Simulation) -> bool:
	return celebration_playing(sim.tick) and not paused(sim)


## Whether the level's lasting mark shows at `tick`: the celebration has
## played (its done mark) and its burst is over.
# @spec-link [[req_level_completion_celebration]]
func mark_showing(tick: int) -> bool:
	return celebration_done and not celebration_playing(tick)


## Where the lasting mark stands: the start of the loop (distance 0).
static func mark_point(level: LevelData) -> Vector2:
	return level.loop.position_at(0.0)


## Whether basket `id` holds its slimes now: collecting, full or rewarding.
func holding(sim: Simulation, id: String) -> bool:
	var state: Dictionary = sim.object_states.get(id, {})
	if state.is_empty():
		return false
	if state["phase"] == FULL or state["phase"] == REWARD:
		return true
	return state["phase"] == FILLING and _flipped_for(sim, id)


## The gates a basket fired open on this tick, sorted: the "basket fired"
## event, read after step() (the camera shows a gate opening,
## Simulation.step). Only a firing in this run counts: a gate saved open, or
## a basket saved fired, opens nothing again after a load.
# @spec-link [[req_switch_basket_gate_set]]
# @spec-link [[req_camera_shows_gate_opening]]
func gates_fired_open(sim: Simulation) -> PackedStringArray:
	var out := PackedStringArray()
	for id in _sorted(_opened_on):
		if _opened_on[id] == sim.tick:
			out.append(id)
	return out


## The state as plain data, for Simulation.dump().
func dump() -> Dictionary:
	return {"celebration_done": celebration_done, "celebration_since": celebration_since,
			"celebration_hops": hops.dump()}


func _catch(sim: Simulation) -> void:
	var bodies := sim.slimes
	var ids := _sorted(_level.baskets)
	for slime_id in bodies.ids():
		var state := bodies.state_of(slime_id)
		if state != SlimeBodies.TRAIN and state != SlimeBodies.FREE:
			continue
		var centre := bodies.centre_of(slime_id)
		for id in ids:
			if (_level.baskets[id]["box"] as Rect2).has_point(centre):
				bodies.set_state(slime_id, SlimeBodies.IN_BASKET)
				bodies.set_hop_held(slime_id, false)
				break


## Basket stable ID -> the ids of the slimes in it, ascending: each slime in
## a basket belongs to the basket whose box holds its centre, or else the
## nearest box.
func _inside(sim: Simulation) -> Dictionary:
	var ids := _sorted(_level.baskets)
	var out := {}
	for id in ids:
		out[id] = PackedInt32Array()
	for slime_id in sim.slimes.ids():
		if sim.slimes.state_of(slime_id) != SlimeBodies.IN_BASKET:
			continue
		var centre := sim.slimes.centre_of(slime_id)
		var best := ""
		var best_gap := INF
		for id in ids:
			var gap := _gap(_level.baskets[id]["box"], centre)
			if gap < best_gap:
				best_gap = gap
				best = id
		out[best].append(slime_id)
	return out


func _basket_step(sim: Simulation, id: String, inside: PackedInt32Array) -> void:
	var state: Dictionary = sim.object_states[id]
	var basket: Dictionary = _level.baskets[id]
	var weight := 0
	for slime_id in inside:
		weight += sim.slimes.size_of(slime_id)
	state["weight"] = weight
	match state["phase"]:
		FILLING:
			if _flipped_for(sim, id) and weight >= int(basket["quota"]):
				state["phase"] = FULL
				state["since"] = sim.tick
		FULL:
			if Fusion.view_rect(sim.view).has_point((basket["box"] as Rect2).get_center()):
				state["phase"] = REWARD
				state["since"] = sim.tick
		REWARD:
			if sim.tick - state["since"] >= ticks(REWARD_SECONDS):
				state["phase"] = FIRED
				state["since"] = sim.tick
				_fire(sim, id)
	if holding(sim, id) or inside.is_empty() or sim.tick < state["next_release"]:
		return
	var size := sim.slimes.size_of(inside[0])
	if _release(sim, inside[0], basket["outlet"]):
		state["weight"] = weight - size
		state["next_release"] = sim.tick + ticks(RELEASE_SECONDS)


## Basket `id` at bedtime: it still weighs the slimes in it, but no phase
## changes and nothing is released; a reward playing keeps the time it has
## left (its `since` moves on with the tick).
# @spec-link [[req_switch_basket_gate_set]]
func _basket_wait(sim: Simulation, id: String, inside: PackedInt32Array) -> void:
	var state: Dictionary = sim.object_states[id]
	var weight := 0
	for slime_id in inside:
		weight += sim.slimes.size_of(slime_id)
	state["weight"] = weight
	if state["phase"] == REWARD:
		state["since"] += 1


## Runs the rules basket `id` triggers when full, then checks whether every
## basket has fired (the celebration).
func _fire(sim: Simulation, id: String) -> void:
	for rule in _level.rules:
		var when: Dictionary = rule.get("when", {})
		var then: Dictionary = rule.get("then", {})
		if when.get("object", "") != id or when.get("event", "") != "full":
			continue
		var target := str(then.get("object", ""))
		if then.get("action", "") == "open" and _level.gates.has(target):
			_open_gate(sim, target)
	if celebration_done:
		return
	for basket_id in _level.baskets:
		if sim.object_states[basket_id]["phase"] != FIRED:
			return
	celebration_done = true
	celebration_since = sim.tick
	hops.begin(sim)


## Opens gate `id` for good, and grows the train's loop (see the class doc).
func _open_gate(sim: Simulation, id: String) -> void:
	sim.gate_states[id]["open"] = true
	_opened_on[id] = sim.tick
	_disturb(sim, _level.gates[id]["box"])
	var train := sim.train
	if train == null or id in train.open_gates:
		return
	var old_length := train.length()
	var old_outgoing := train.outgoing_length()
	var records := {}
	for slime_id in train.tracked_ids():
		records[slime_id] = train.record_of(slime_id)
	var gates := train.open_gates.duplicate()
	gates.append(id)
	train.set_open_gates(gates)
	var new_length := train.length()
	var new_outgoing := train.outgoing_length()
	for slime_id in records:
		var record: Dictionary = records[slime_id]
		var distance: float = record["distance"]
		if distance > old_outgoing:
			distance = clampf(new_length - (old_length - distance), new_outgoing, new_length)
		record["distance"] = distance
		record["mark"] = record["laps"] * new_length + distance
		record["marked_at"] = sim.tick
		train.restore_record(slime_id, record)


## Moves slime `slime_id` to `outlet` at rest, back on the train. False when
## a slime is in the way. It wakes, and so do the resting slimes touching
## where it was; the rest of the basket's pile rests on (D156). Its hop timer
## is run out, so it hops away as soon as it stands on the outlet's ground
## (O126) and clears the outlet for the next one.
# @spec-link [[req_switch_basket_gate_set]]
func _release(sim: Simulation, slime_id: int, outlet: Vector2) -> bool:
	var bodies := sim.slimes
	var radius := bodies.radius_of(slime_id)
	var at := outlet + Vector2(0.0, -(radius - SlimeBodies.RING_RADIUS_SIZE_1))
	for other in bodies.ids():
		if other == slime_id:
			continue
		if bodies.centre_of(other).distance_to(at) < radius + bodies.radius_of(other) + OUTLET_CLEARANCE:
			return false
	var body := bodies.body_of(slime_id)
	var shift: Vector2 = at - bodies.centre_of(slime_id)
	var points: PackedVector2Array = body["points"]
	for k in points.size():
		points[k] += shift
	body["points"] = points
	body["previous"] = points.duplicate()
	body["centre"] = body["centre"] + shift
	body["held"] = false
	body["supported"] = false
	body["hop_timer"] = 0.0
	bodies.set_body(slime_id, body)
	bodies.set_state(slime_id, SlimeBodies.TRAIN)
	return true


func _doors_step(sim: Simulation) -> void:
	for id in _sorted(_level.switches):
		var state: Dictionary = sim.object_states[id]
		var was_shut: bool = state["trapdoor_shut"]
		if _collecting(sim, id, state):
			state["trapdoor_shut"] = false
		elif not state["trapdoor_shut"] and (not _trapdoors.has(id)
				or _clear(sim, _level.switches[id]["trapdoor"])):
			state["trapdoor_shut"] = true
		if state["trapdoor_shut"] != was_shut:
			_disturb(sim, _level.switches[id]["trapdoor"])
	for id in _sorted(_level.gates):
		var state: Dictionary = sim.gate_states[id]
		if state["open"] and not state["entrance_closed"] and (not _lids.has(id)
				or _clear(sim, _level.gates[id]["lid"])):
			state["entrance_closed"] = true
			_disturb(sim, _level.gates[id]["lid"])


## A door opening or shutting wakes the resting slimes by it (chunk 15),
## not the rest of their piles (D156).
# @spec-link [[req_offscreen_simulation]]
static func _disturb(sim: Simulation, box: Rect2) -> void:
	if box.has_area():
		sim.slimes.wake_resting_in(box.grow(DOOR_WAKE_REACH))


func _set_doors(sim: Simulation) -> void:
	var doors: Array[TerrainSegments] = []
	for id in _sorted(_trapdoors):
		if sim.object_states[id]["trapdoor_shut"]:
			doors.append(_trapdoors[id])
	for id in _sorted(_level.gates):
		var state: Dictionary = sim.gate_states[id]
		if not state["open"] and _barriers.has(id):
			doors.append(_barriers[id])
		if state["entrance_closed"] and _lids.has(id):
			doors.append(_lids[id])
	sim.slimes.doors = doors


## Whether switch `id` (its `state`) sends the flow into its basket now: it
## is flipped and the basket is filling.
func _collecting(sim: Simulation, id: String, state: Dictionary) -> bool:
	if not state["flipped"]:
		return false
	var basket: Dictionary = sim.object_states.get(_level.switches[id]["basket"], {})
	return basket.is_empty() or basket["phase"] == FILLING


## Whether basket `id`'s switch is flipped (a basket no switch serves always
## collects).
func _flipped_for(sim: Simulation, id: String) -> bool:
	for switch_id in _sorted(_level.switches):
		if _level.switches[switch_id]["basket"] == id:
			return sim.object_states[switch_id]["flipped"]
	return true


## Whether no ring point of an awake slime is in `box` (grown by
## DOOR_CLEARANCE).
func _clear(sim: Simulation, box: Rect2) -> bool:
	var grown := box.grow(DOOR_CLEARANCE)
	var bodies := sim.slimes
	for s in bodies.slime_count:
		if bodies.state[s] == SlimeBodies.SLEEPER:
			continue
		var f: int = bodies.first[s]
		for i in range(f, f + bodies.npts[s]):
			if grown.has_point(bodies.pos[i]):
				return false
	return true


static func _solid(box: Rect2) -> TerrainSegments:
	return TerrainSegments.new([PackedVector2Array([box.position, Vector2(box.end.x, box.position.y),
			box.end, Vector2(box.position.x, box.end.y)])])


static func _gap(box: Rect2, point: Vector2) -> float:
	var nearest := Vector2(clampf(point.x, box.position.x, box.end.x), clampf(point.y, box.position.y, box.end.y))
	return point.distance_to(nearest)


static func _sorted(dictionary: Dictionary) -> PackedStringArray:
	var out := PackedStringArray(dictionary.keys())
	out.sort()
	return out
