class_name SlimeCensus
extends RefCounted
## The slime census: an instant status dump of every slime, for finding out
## why the train moves as it does (the user's, 2026-10-05: on the phone,
## stress-dense's slimes behind a held front slime kept making micro hops).
## Debug builds only, like the rest of src/debug/: the debug overlay's
## Census button takes one (reason "button"), and the game root's
## --census-every=S[,--census-until=T] user arguments take one every S
## seconds of game time (reason "timer"; parse_args(), after_tick()). Nothing
## outside src/debug/ names this class: the game root loads it by path.
##
## It only reads the simulation: no state changes, so the state hash is the
## same with or without it (tests/unit/test_slime_census.gd). The reads it
## shares with the game (a centre cache, the train's last target kind) are
## caches that hold the very value the game would compute.
##
## One census prints, through print() (stdout; logcat's "godot" tag on
## Android), a header, ONE line per slime, a footer; space-separated
## key=value tokens, no space inside a value, every line well under logcat's
## 4 KB cut (MAX_LINE). tools/census.py reads them back.
##
##   CENSUS begin tick=<t> time=<s> slimes=<n> tick_kind=<native|gdscript>
##       fixture=<name|none> reason=<button|timer> + the level's side:
##       open_gates, frontier (gate) and frontier_at (its loop distance),
##       loop_len, call (the last call's point@tick, or -), hop_rate, queue
##       (slimes due a move to the loop start) and next_turn (the
##       loop-start queue's next turn), on_screen, in_range, parked
##   CENSUS slime ... (the keys below; a key that doesn't apply is left out)
##   CENSUS end tick=<t> lines=<slime lines> ms=<time spent>
##
## Every slime: id (runtime), sid (stable ID: its first member, "+n" for
## the others; - for none), species (letter), size, state, calm, detail,
## held (SlimeBodies.held: the hop hold), supported, still (rest count),
## pile, pos and vel (centre, px; mean velocity, px/s, from pos - prev),
## hop_timer (s), on_screen (centre in the view), in_range (not parked),
## fusion_view (inside the view less Fusion.VIEW_MARGIN: fusion counts),
## section, loop_segment (the loop segment it is on: the train's progress,
## or the current loop's nearest point for the others; the user's
## "corridor" and "segment" are this), route (that segment's kind,
## outgoing or return), loop_gap (px from that loop point), zones (every
## named zone holding its centre: split zones, exploration branches,
## framing zones, baskets, switches, gates; "<switch>.trapdoor" and
## "<gate>.lid" for those parts; - for none), door (the shut doors its body
## is against, a switch's trapdoor, a closed gate, a lid: "<door>:floor"
## when it stands on top of it, "<door>:wall" when beside or under it), hold (what holds
## it back, see hold_of()), touch (the slimes its ring touched on the last
## tick), touch_held (those of them held, "<id>:<their hold>"), contact
## (fusion contact timers with them, "<id>:<ticks>"), stuck (stuck-check
## counts, "<id>:<checks>"), due (in the loop-start queue:
## "<reason>:<since tick>:<rank>").
##
## A train slime adds the loop side: dist (px along the current loop), laps,
## progress, rank (in the train, front first: by dist, highest first), ahead
## (the slime before it) and gap_ahead (px along the loop to it), to_frontier
## (px to the frontier along the outgoing route; - past it), on_slide,
## mark_age (ticks since its stall mark) and stall_in (ticks left before it
## is stalled), and the hop decision (Train.steer's inputs and outputs):
## steer_from (where it steers from) and off_route (knocked off the
## route), slope (the route's rise over run there), grip (standing on a
## stretch it grips), dip_floor (on a dip's floor), nudge (the dip nudge
## held it on the last tick: holding or gathering), hop_due (its timer is
## due, so steer aims it this tick), reach, next_kind (the target kind if it
## hopped now: Train.TARGET_*), next_target, next_apex, next_v (the take-off
## velocity aimed), capped (the take-off speed cap cuts it: the hop lands
## short); in_air (a train hop not landed yet), and its last train hop
## (TrainHopLog.last_hops): last_hop (take-off tick), last_kind, last_from,
## last_target, landed (tick; -1 in the air, or never landed as a train
## hop: parked or moved first), last_advance (px of progress
## from take-off to landing), last_short (less than half its reach).
## A free slime adds phase, since, call_point, route_back, away (ticks off
## screen) and left_alone.
# @spec-link [[req_platform_and_performance_targets]]

## The line tag, and each line's kind.
const TAG := "CENSUS"
const BEGIN := "begin"
const SLIME := "slime"
const END := "end"
## Why a census was taken.
const BUTTON := "button"
const TIMER := "timer"
## A line is kept under this many bytes (logcat cuts lines near 4 KB): a list
## that would go past it is cut short, ending in "+<n left>".
const MAX_LINE := 3500
## The user arguments: --census-every=S (seconds of game time between two
## censuses, > 0) and --census-until=T (the last census's time, seconds,
## optional: none, every S seconds for as long as the run lasts).
const EVERY_FLAG := "--census-every"
const UNTIL_FLAG := "--census-until"
## How far past its ring (px) a shut door still counts as against a slime.
const DOOR_REACH := SlimeBodies.EDGE + SlimeBodies.TOUCH_SKIN + 2.0
## The hold names (hold_of()).
const HOLD_NONE := "-"
## How a slime is against a door (doors_against()).
const FLOOR := ":floor"
const WALL := ":wall"

## The schedule: a census every `every_ticks` ticks of game time, the last
## at `until_ticks` (-1: no end).
var every_ticks := 0
var until_ticks := -1
## How many censuses this schedule took.
var taken := 0


## A schedule of a census every `every_seconds` (> 0) of game time until
## `until_seconds` (< 0: no end), in ticks (at least one).
func _init(every_seconds := 10.0, until_seconds := -1.0) -> void:
	every_ticks = maxi(1, roundi(every_seconds * Simulation.TICK_RATE))
	until_ticks = roundi(until_seconds * Simulation.TICK_RATE) if until_seconds >= 0.0 else -1


## Whether a census is due once the simulation has run `tick` ticks: every
## every_ticks from the level's start (tick 0, not counted), up to
## until_ticks.
func due(tick: int) -> bool:
	return tick > 0 and tick % every_ticks == 0 and (until_ticks < 0 or tick <= until_ticks)


## After each tick (the game root's step_simulation()): takes and prints the
## census when due. Returns whether it took one.
func after_tick(sim: Simulation, fixture := "") -> bool:
	if not due(sim.tick):
		return false
	run(sim, TIMER, fixture)
	taken += 1
	return true


## Reads --census-every=S and --census-until=T from the user arguments
## (after "--"); every other argument is left alone. Returns {"requested"
## (bool: either given), "every" (s), "until" (s, -1 when not given),
## "errors"}: a value that isn't a number > 0, a flag given twice, or
## --census-until without --census-every is an error.
static func parse_args(user_args: PackedStringArray) -> Dictionary:
	var result := {"requested": false, "every": -1.0, "until": -1.0, "errors": PackedStringArray()}
	var seen := {}
	for arg in user_args:
		var flag := arg.get_slice("=", 0)
		if flag != EVERY_FLAG and flag != UNTIL_FLAG:
			continue
		result["requested"] = true
		if seen.has(flag):
			result["errors"].append("%s is given more than once" % flag)
			continue
		seen[flag] = true
		var value := arg.substr(flag.length() + 1) if "=" in arg else ""
		if not value.is_valid_float() or value.to_float() <= 0.0:
			result["errors"].append("%s=SECONDS expects a number of seconds > 0, got '%s'" % [flag, value])
			continue
		result["every" if flag == EVERY_FLAG else "until"] = value.to_float()
	if seen.has(UNTIL_FLAG) and not seen.has(EVERY_FLAG):
		result["errors"].append("%s needs %s" % [UNTIL_FLAG, EVERY_FLAG])
	return result


## Takes a census of `sim` for `reason` (BUTTON or TIMER) and prints it.
## `fixture`: the test-mode fixture running ("" for none). Returns how many
## slimes it logged.
static func run(sim: Simulation, reason: String, fixture := "") -> int:
	var out := lines(sim, reason, fixture)
	for line in out:
		print(line)
	return out.size() - 2


## The census of `sim` as its lines: the header, one line per slime (in id
## order), the footer (with the time it took).
static func lines(sim: Simulation, reason: String, fixture := "") -> PackedStringArray:
	var start_usec := Time.get_ticks_usec()
	var context := _context(sim)
	var bodies := sim.slimes
	var out := PackedStringArray()
	out.append(_header(sim, reason, fixture, context))
	for s in bodies.slime_count:
		out.append(slime_line(sim, bodies.id[s], context))
	var ms := (Time.get_ticks_usec() - start_usec) / 1000.0
	out.append("%s %s tick=%d lines=%d ms=%.1f" % [TAG, END, sim.tick, bodies.slime_count, ms])
	return out


## What holds slime `slime_id` back, as a comma list (HOLD_NONE: nothing):
##   parked, resting   its calm: not simulated, or a wall at rest;
##   asleep, bedtime, basket
##                     its state never hops (a sleeper, asleep at bedtime, in
##                     a basket);
##   slide             held on a return route (the train holds it: no hop,
##                     carried along);
##   held              held otherwise (SlimeBodies.held);
##   dip_holding, dip_gathering
##                     the dip nudge held its hop on the last tick
##                     (Fusion.nudged): touching a partner it may fuse with,
##                     or waiting for one behind;
##   door              its body is against a shut door as a wall (beside or
##                     under it: doors_against()'s ":wall"); standing on one
##                     (":floor", a shut trapdoor is the onward route) is no
##                     hold.
static func hold_of(sim: Simulation, slime_id: int, doors: PackedStringArray) -> String:
	var bodies := sim.slimes
	var s := bodies.index_of(slime_id)
	var out := PackedStringArray()
	if bodies.calm[s] == SlimeBodies.PARKED:
		out.append("parked")
	elif bodies.calm[s] == SlimeBodies.RESTING:
		out.append("resting")
	match bodies.state[s]:
		SlimeBodies.SLEEPER:
			out.append("asleep")
		SlimeBodies.BEDTIME_ASLEEP:
			out.append("bedtime")
		SlimeBodies.IN_BASKET:
			out.append("basket")
	if bodies.held[s] != 0:
		var on_slide := sim.train != null and bodies.state[s] == SlimeBodies.TRAIN \
				and bool(sim.train.record_of(slime_id).get("on_slide", false))
		out.append("slide" if on_slide else "held")
	var nudge: String = sim.fusion.nudged.get(slime_id, "")
	if nudge != "":
		out.append("dip_" + nudge)
	for door in doors:
		if door.ends_with(WALL):
			out.append("door")
			break
	return HOLD_NONE if out.is_empty() else ",".join(out)


## The shut doors (stable ID; "<switch>.trapdoor", "<gate>.lid") the body
## of slime `slime_id` is against: its centre within its ring radius plus
## DOOR_REACH of the door's box, each "<door>:floor" (FLOOR) when its
## centre is above the box's top and within its width (it stands on it),
## else "<door>:wall" (WALL).
static func doors_against(sim: Simulation, slime_id: int, shut: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	var centre := sim.slimes.centre_of(slime_id)
	var reach := sim.slimes.radius_of(slime_id) + DOOR_REACH
	for door_id: String in shut:
		var box: Rect2 = shut[door_id]
		if _gap(box, centre) <= reach:
			var on_top := centre.y < box.position.y and centre.x >= box.position.x and centre.x <= box.end.x
			out.append(door_id + (FLOOR if on_top else WALL))
	return out


## The shut doors of `sim` now, door name -> box: the trapdoors of the
## switches whose trapdoor is shut, the closed gates' boxes, the lids shut
## (as FrontierSets solves them).
static func shut_doors(sim: Simulation) -> Dictionary:
	var out := {}
	if sim.level == null:
		return out
	for switch_id: String in _sorted(sim.level.switches):
		var box: Rect2 = sim.level.switches[switch_id]["trapdoor"]
		var state: Dictionary = sim.object_states.get(switch_id, {})
		if box.has_area() and bool(state.get("trapdoor_shut", false)):
			out[switch_id + ".trapdoor"] = box
	for gate_id: String in _sorted(sim.level.gates):
		var gate: Dictionary = sim.level.gates[gate_id]
		var state: Dictionary = sim.gate_states.get(gate_id, {})
		if not bool(state.get("open", false)) and (gate["box"] as Rect2).has_area():
			out[gate_id] = gate["box"]
		if bool(state.get("entrance_closed", false)) and (gate["lid"] as Rect2).has_area():
			out[gate_id + ".lid"] = gate["lid"]
	return out


## The named zones of `level` holding `point` (see the class doc), sorted.
static func zones_at(level: LevelData, point: Vector2) -> PackedStringArray:
	var out := PackedStringArray()
	if level == null:
		return out
	for zone_id: String in level.split_zones:
		if (level.split_zones[zone_id] as Rect2).has_point(point):
			out.append(zone_id)
	for zone_id: String in level.branches:
		if (level.branches[zone_id] as Rect2).has_point(point):
			out.append(zone_id)
	for zone_id: String in level.framing_zones:
		if (level.framing_zones[zone_id]["box"] as Rect2).has_point(point):
			out.append(zone_id)
	for zone_id: String in level.baskets:
		if (level.baskets[zone_id]["box"] as Rect2).has_point(point):
			out.append(zone_id)
	for zone_id: String in level.switches:
		if (level.switches[zone_id]["box"] as Rect2).has_point(point):
			out.append(zone_id)
		if (level.switches[zone_id]["trapdoor"] as Rect2).has_point(point):
			out.append(zone_id + ".trapdoor")
	for zone_id: String in level.gates:
		if (level.gates[zone_id]["box"] as Rect2).has_point(point):
			out.append(zone_id)
		if (level.gates[zone_id]["lid"] as Rect2).has_point(point):
			out.append(zone_id + ".lid")
	out.sort()
	return out


## Whether the take-off speed cap cuts a hop Train.aim() aims from `from` to
## `to` with `apex`, under `gravity`, at `cap` (the same ballistic speed it
## computes before capping): such a hop lands short.
static func aim_capped(from: Vector2, to: Vector2, apex: float, gravity: float, cap: float) -> bool:
	var top := minf(from.y, to.y) - maxf(apex, 1.0)
	var rise := from.y - top
	var fall := to.y - top
	var vy := -sqrt(2.0 * gravity * rise)
	var flight := sqrt(2.0 * rise / gravity) + sqrt(2.0 * fall / gravity)
	var vx := (to.x - from.x) / flight
	return vx * vx + vy * vy > cap * cap


## Slime `slime_id`'s line, with `context` (_context()).
static func slime_line(sim: Simulation, slime_id: int, context: Dictionary) -> String:
	var bodies := sim.slimes
	var s := bodies.index_of(slime_id)
	var centre := bodies.centre_of(slime_id)
	var tokens := PackedStringArray([TAG, SLIME])
	var members := sim.identities.members_of(slime_id)
	var sid := "-"
	if not members.is_empty():
		sid = members[0] if members.size() == 1 else "%s+%d" % [members[0], members.size() - 1]
	_put(tokens, "id", str(slime_id))
	_put(tokens, "sid", sid)
	_put(tokens, "species", Species.letter(bodies.species[s]))
	_put(tokens, "size", str(bodies.size[s]))
	_put(tokens, "state", SlimeBodies.STATE_NAMES[bodies.state[s]])
	_put(tokens, "calm", SlimeBodies.CALM_NAMES[bodies.calm[s]])
	_put(tokens, "detail", str(bodies.detail[s]))
	_put(tokens, "held", str(bodies.held[s]))
	_put(tokens, "supported", str(bodies.supported[s]))
	_put(tokens, "still", str(bodies.still_ticks[s]))
	_put(tokens, "pile", str(bodies.pile[s]))
	_put(tokens, "pos", _vec(centre))
	_put(tokens, "vel", _vec(bodies.velocity_of(slime_id)))
	_put(tokens, "hop_timer", "%.3f" % bodies.hop_timer[s])
	_put(tokens, "on_screen", _bit(context["shown"].has_point(centre)))
	_put(tokens, "in_range", _bit(bodies.calm[s] != SlimeBodies.PARKED))
	_put(tokens, "fusion_view", _bit(Fusion.on_screen(sim.view, centre)))
	var train := sim.train
	var is_train := train != null and bodies.state[s] == SlimeBodies.TRAIN and train.tracks(slime_id)
	var place := _place_on_loop(sim, slime_id, centre, is_train, context)
	_put(tokens, "section", str(place["section"]))
	_put(tokens, "loop_segment", place["segment"])
	_put(tokens, "route", place["route"])
	_put(tokens, "loop_gap", "%.1f" % place["gap"])
	_put(tokens, "zones", _list(zones_at(sim.level, centre)))
	var doors: PackedStringArray = context["doors"].get(slime_id, PackedStringArray())
	_put(tokens, "door", _list(doors))
	_put(tokens, "hold", context["holds"][slime_id])
	var touching: Array = context["touch"].get(slime_id, [])
	var touch := PackedStringArray()
	var touch_held := PackedStringArray()
	var contact := PackedStringArray()
	for other: int in touching:
		touch.append(str(other))
		var other_hold: String = context["holds"].get(other, HOLD_NONE)
		if other_hold != HOLD_NONE:
			touch_held.append("%d:%s" % [other, other_hold.replace(",", "+")])
		var ticks := sim.fusion.contact_ticks(slime_id, other)
		if ticks > 0:
			contact.append("%d:%d" % [other, ticks])
	_put(tokens, "touch", _list(touch))
	_put(tokens, "touch_held", _list(touch_held))
	_put(tokens, "contact", _list(contact))
	_put(tokens, "stuck", _list(context["stuck"].get(slime_id, PackedStringArray())))
	_put(tokens, "due", context["due"].get(slime_id, "-"))
	if is_train:
		_train_tokens(tokens, sim, slime_id, s, centre, place, context)
	elif bodies.state[s] == SlimeBodies.FREE and sim.free_slimes.tracks(slime_id):
		_free_tokens(tokens, sim, slime_id)
	return _fit(tokens)


# --- Internals --------------------------------------------------------------

## What every line of one census shares, read once: the view's box, the
## loop's current segments (with where each starts along the loop), the
## train's order, the touching pairs by slime, the shut doors each slime is
## against and each slime's hold, the stuck counts and the loop-start queue.
static func _context(sim: Simulation) -> Dictionary:
	var bodies := sim.slimes
	var gates := DebugCounts.open_gates(sim)
	var context := {"shown": Fusion.view_rect(sim.view), "gates": gates, "segments": [],
			"order": {}, "touch": {}, "doors": {}, "holds": {}, "stuck": {}, "due": {}}
	if sim.level != null and sim.level.loop != null:
		var at := 0.0
		for segment in sim.level.loop.current_segments(gates):
			context["segments"].append({"segment": segment, "from": at})
			at += segment["length"]
		context["frontier"] = sim.level.loop.frontier(gates)
	if sim.train != null:
		var ranked: Array = []
		for slime_id in sim.train.tracked_ids():
			if bodies.state_of(slime_id) == SlimeBodies.TRAIN:
				ranked.append([sim.train.distance_of(slime_id), slime_id])
		ranked.sort_custom(func(a: Array, b: Array) -> bool:
			return a[0] > b[0] or (a[0] == b[0] and a[1] < b[1]))
		for k in ranked.size():
			context["order"][ranked[k][1]] = {"rank": k + 1, "ahead": ranked[k - 1][1] if k > 0 else -1,
					"gap": ranked[k - 1][0] - ranked[k][0] if k > 0 else -1.0}
		var queue := LoopStartQueue.due(sim)
		for k in queue.size():
			var entry: Dictionary = queue[k]
			context["due"][entry["id"]] = "%s:%d:%d" % [entry["reason"], entry["since"], k + 1]
		context["queue"] = queue.size()
	for pair: Vector2i in bodies.touching_pairs():
		context["touch"].get_or_add(pair.x, []).append(pair.y)
		context["touch"].get_or_add(pair.y, []).append(pair.x)
	for pair: Vector2i in sim.stuck_slimes.counts:
		var checks := "%d" % int(sim.stuck_slimes.counts[pair])
		context["stuck"].get_or_add(pair.x, PackedStringArray()).append("%d:%s" % [pair.y, checks])
		context["stuck"].get_or_add(pair.y, PackedStringArray()).append("%d:%s" % [pair.x, checks])
	var shut := shut_doors(sim)
	for slime_id in bodies.ids():
		var doors := doors_against(sim, slime_id, shut) if not shut.is_empty() else PackedStringArray()
		if not doors.is_empty():
			context["doors"][slime_id] = doors
		context["holds"][slime_id] = hold_of(sim, slime_id, doors)
	return context


## The header line (see the class doc).
static func _header(sim: Simulation, reason: String, fixture: String, context: Dictionary) -> String:
	var tokens := PackedStringArray([TAG, BEGIN])
	_put(tokens, "tick", str(sim.tick))
	_put(tokens, "time", "%.2f" % (sim.tick / float(Simulation.TICK_RATE)))
	_put(tokens, "slimes", str(sim.slimes.slime_count))
	_put(tokens, "tick_kind", TickChoice.NATIVE if sim.slimes.uses_native() else TickChoice.GDSCRIPT)
	_put(tokens, "fixture", fixture if fixture != "" else "none")
	_put(tokens, "reason", reason)
	_put(tokens, "open_gates", _list(PackedStringArray(context["gates"])))
	var frontier: Dictionary = context.get("frontier", {})
	_put(tokens, "frontier", frontier.get("gate", "") if frontier.get("gate", "") != "" else "-")
	_put(tokens, "frontier_at", "%.1f" % float(frontier.get("distance", 0.0)))
	_put(tokens, "loop_len", "%.1f" % (sim.train.length() if sim.train != null else 0.0))
	var call := "-"
	if sim.free_slimes.call_tick >= 0:
		call = "%s@%d" % [_vec(sim.free_slimes.call_point), sim.free_slimes.call_tick]
	_put(tokens, "call", call)
	_put(tokens, "hop_rate", "%.2f" % sim.slimes.hop_rate)
	_put(tokens, "queue", str(context.get("queue", 0)))
	_put(tokens, "next_turn", str(sim.loop_start_queue.next_turn(sim)) if sim.train != null else "-")
	var counts := DebugCounts.count_slimes(sim)
	_put(tokens, "on_screen", str(counts[DebugCounts.ON_SCREEN]))
	_put(tokens, "in_range", str(counts[DebugCounts.IN_RANGE]))
	_put(tokens, "parked", str(counts[DebugCounts.PARKED]))
	return " ".join(tokens)


## Where slime `slime_id` (centre `centre`) is on the loop: {"section",
## "segment", "route", "gap", "along" (px into the segment)}. A train slime
## from its progress; any other from the current loop's nearest point.
static func _place_on_loop(sim: Simulation, slime_id: int, centre: Vector2, is_train: bool,
		context: Dictionary) -> Dictionary:
	var place := {"section": 0, "segment": "-", "route": "-", "gap": 0.0, "along": 0.0}
	var segments: Array = context["segments"]
	if segments.is_empty():
		return place
	var distance := 0.0
	if is_train:
		distance = sim.train.distance_of(slime_id)
		place["gap"] = centre.distance_to(sim.train.position_at(distance))
	else:
		var nearest := sim.level.loop.closest(centre, context["gates"])
		distance = nearest["distance"]
		place["gap"] = nearest["gap"]
	var found: Dictionary = segments[segments.size() - 1]
	for entry: Dictionary in segments:
		if distance < entry["from"] + entry["segment"]["length"]:
			found = entry
			break
	place["section"] = int(found["segment"]["section"])
	place["segment"] = found["segment"]["id"]
	place["route"] = found["segment"]["kind"]
	place["along"] = distance - found["from"]
	return place


## A train slime's loop side and hop decision (see the class doc).
static func _train_tokens(tokens: PackedStringArray, sim: Simulation, slime_id: int, s: int, centre: Vector2,
		place: Dictionary, context: Dictionary) -> void:
	var bodies := sim.slimes
	var train := sim.train
	var record := train.record_of(slime_id)
	var distance := train.distance_of(slime_id)
	var order: Dictionary = context["order"].get(slime_id, {"rank": 0, "ahead": -1, "gap": -1.0})
	_put(tokens, "dist", "%.1f" % distance)
	_put(tokens, "laps", str(train.laps_of(slime_id)))
	_put(tokens, "progress", "%.1f" % train.progress_of(slime_id))
	_put(tokens, "rank", str(order["rank"]))
	_put(tokens, "ahead", str(order["ahead"]) if order["ahead"] >= 0 else "-")
	_put(tokens, "gap_ahead", "%.1f" % order["gap"] if order["ahead"] >= 0 else "-")
	var frontier: Dictionary = context.get("frontier", {})
	var to_frontier := float(frontier.get("distance", 0.0)) - distance
	_put(tokens, "to_frontier", "%.1f" % to_frontier if place["route"] == LoopData.OUTGOING else "-")
	_put(tokens, "on_slide", _bit(bool(record.get("on_slide", false))))
	var marked_at := int(record.get("marked_at", -1))
	_put(tokens, "mark_age", str(sim.tick - marked_at) if marked_at >= 0 else "-")
	_put(tokens, "stall_in", str(maxi(0, marked_at + Train.STALL_TICKS - sim.tick)) if marked_at >= 0 else "-")
	var from := train.steering_distance(distance, centre)
	_put(tokens, "steer_from", "%.1f" % from)
	_put(tokens, "off_route", _bit(from != distance))
	var slope := train.direction_at(from)
	_put(tokens, "slope", "%.2f" % (-slope.y / absf(slope.x) if absf(slope.x) > 0.0001 else -signf(slope.y) * 99.0))
	_put(tokens, "grip", _bit(bodies.supported[s] != 0 and absf(slope.y) <= absf(slope.x) * Train.GRIP_MAX_SLOPE))
	_put(tokens, "dip_floor", _bit(sim.fusion.on_dip_floor(distance)))
	_put(tokens, "nudge", sim.fusion.nudged.get(slime_id, "-"))
	_put(tokens, "hop_due", _bit(bodies.hop_timer[s] <= Simulation.TICK_SECONDS * 1.5))
	var size := bodies.size[s]
	var reach := Train.hop_reach(size)
	_put(tokens, "reach", "%.1f" % reach)
	if not train.is_slide_at(from):
		var target := train.hop_target(from, reach)
		var high := minf(train.highest_between(from, from + reach), target.y)
		var apex := Train.hop_apex(size) + maxf(0.0, minf(centre.y, target.y) - high)
		var cap := Train.hop_cap(size)
		_put(tokens, "next_kind", train.hop_log.last_target_kind)
		_put(tokens, "next_target", _vec(target))
		_put(tokens, "next_apex", "%.1f" % apex)
		_put(tokens, "next_v", _vec(Train.aim(centre, target, apex, bodies.gravity.y, cap)))
		_put(tokens, "capped", _bit(aim_capped(centre, target, apex, bodies.gravity.y, cap)))
	_put(tokens, "in_air", _bit(train.hop_log.in_air(slime_id)))
	var last: Dictionary = train.hop_log.last_hops.get(slime_id, {})
	if not last.is_empty():
		_put(tokens, "last_hop", str(last["tick"]))
		_put(tokens, "last_kind", last["kind"])
		_put(tokens, "last_from", "%.1f" % last["from"])
		_put(tokens, "last_target", _vec(last["target"]) if last["target"] != null else "-")
		_put(tokens, "landed", str(last["landed"]))
		_put(tokens, "last_advance", "%.1f" % last["advance"] if last["landed"] >= 0 else "-")
		_put(tokens, "last_short", _bit(last["short"]) if last["landed"] >= 0 else "-")


## A free slime's record (see the class doc).
static func _free_tokens(tokens: PackedStringArray, sim: Simulation, slime_id: int) -> void:
	var free := sim.free_slimes
	_put(tokens, "phase", free.phase_of(slime_id))
	_put(tokens, "since", str(free.phase_since(slime_id)))
	_put(tokens, "call_point", _vec(free.point_of(slime_id)))
	_put(tokens, "route_back", free.route_of(slime_id) if free.route_of(slime_id) != "" else "-")
	var away: Variant = sim.offscreen.away.get(slime_id)
	_put(tokens, "away", str(sim.tick - int(away)) if away != null else "-")
	_put(tokens, "left_alone", _bit(sim.offscreen.is_left_alone(slime_id, sim.tick)))


## Appends `key`=`value` to `tokens`; a value never holds a space.
static func _put(tokens: PackedStringArray, key: String, value: String) -> void:
	tokens.append("%s=%s" % [key, value.replace(" ", "_") if value != "" else "-"])


## The tokens as one line under MAX_LINE bytes: the longest list values are
## cut short ("...,+<n>") until it fits.
static func _fit(tokens: PackedStringArray) -> String:
	var line := " ".join(tokens)
	while line.to_utf8_buffer().size() >= MAX_LINE:
		var longest := -1
		for k in tokens.size():
			if longest < 0 or tokens[k].length() > tokens[longest].length():
				longest = k
		var key := tokens[longest].get_slice("=", 0)
		var value := tokens[longest].substr(key.length() + 1)
		var items := value.split(",")
		if items.size() > 2:
			var keep := items.size() / 2
			tokens[longest] = "%s=%s,+%d" % [key, ",".join(items.slice(0, keep)), items.size() - keep]
		else:
			tokens[longest] = "%s=%s+" % [key, value.left(value.length() / 2)]
		line = " ".join(tokens)
	return line


static func _vec(v: Vector2) -> String:
	return "%.1f,%.1f" % [v.x, v.y]


static func _bit(on: bool) -> String:
	return "1" if on else "0"


static func _list(items: PackedStringArray) -> String:
	return ",".join(items) if not items.is_empty() else "-"


static func _gap(box: Rect2, point: Vector2) -> float:
	var nearest := Vector2(clampf(point.x, box.position.x, box.end.x), clampf(point.y, box.position.y, box.end.y))
	return point.distance_to(nearest)


static func _sorted(dictionary: Dictionary) -> PackedStringArray:
	var out := PackedStringArray(dictionary.keys())
	out.sort()
	return out
