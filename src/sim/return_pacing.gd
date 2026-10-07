class_name ReturnPacing
extends RefCounted
## EXPERIMENT (branch exp/pacing; D159 (6), O118): pacing the return route's
## end. Not in the spec, no ATD atom. The train slimes coming home on the
## current loop's return route stop on its last flat stretch before the
## loop's start and queue there, in single file: the front one (the head)
## stops at the hold point (hold_point()), each next one GAP px clear behind
## the slime ahead of it. The head is let go (released) one at a time by the
## variant's rule; it then slides on as without pacing, reaches the loop's
## start (a lap; with the geyser on, the Geyser launches it) and the next one
## moves up to the hold point.
##
## The hold point. Walking back from the loop's end (the return route's end,
## the loop's start) over the return route's edges, past the climb into the
## start (edges rising or falling steeper than FLAT): the end of the last
## gentle edge, less BACK px (a slime's width: it waits on the flat, not on
## the climb's foot). On the test level: about 38,100 px along the loop
## (x 370, y 585), in the tunnel under the first stretch, 170 px from the
## loop's start; the queue grows back along the tunnel (x rising).
##
## The rule (SLIME_PACING, comma-separated name=value tokens, read once;
## unset or empty: no pacing at all, main's behaviour and hash):
##   room=N   P1, by room: the head is released while the loop's first
##            stretch (train slimes 0 to ROOM_STRETCH px along the loop, off
##            the return route) and the released slimes still on the return
##            route together hold fewer than N base slimes (a size 3 counts
##            three: level rule 24's count).
##   pace=K   P2, by pace: at most one release per K ticks.
##   both     P3: room and pace together (the room rule with the pace as a
##            minimum gap).
## The head is released wherever it is (far back with no queue, it slides
## on unchecked): pacing only ever holds a slime the rule doesn't release.
##
## How it holds. Each tick (step(), before Train.steer), every unreleased
## train slime on the return route gets a stop distance along the loop: the
## head's the hold point, the next one's the slime ahead's distance (released
## or not) less both rings, both EDGEs and GAP. Train.steer then carries a
## grounded slide slime with a stop at most at the speed that brakes it to
## rest on its stop under DECEL (sqrt(2 * DECEL * gap)) instead of
## SLIDE_SPEED (Train._carry_to); a parked one (Offscreen's proxy) never
## moves past its stop. A queued slime's stall clock pauses (as a parked
## one's, D150 (1)): it waits, it isn't stalled.
##
## Determinism: no randomness, no clock: the order is the distances' (ties
## by id), the rule reads the tick. Not saved (the experiment's state): the
## released set and the last release's tick. A save mid-queue would forget
## them: see HANDOFF.md for what a production version would save.
# @spec-link [[req_loop_and_world]]

## Edges steeper than this (rise over run, either way) are the climb into the
## start, walked past to find the hold point.
const FLAT := 0.2
## The hold point sits this far back from the end of the last gentle edge, px.
const BACK := 30.0
## The clear room kept between two queued slimes' rings, px.
const GAP := 8.0
## The braking a queued slime gets toward its stop, px/s^2.
const DECEL := 1200.0
## P1's first stretch, px along the loop from its start (rule 23's 240 px).
const ROOM_STRETCH := 240.0

## Whether pacing runs (a rule set).
var enabled := false
## P1's limit in base slimes (0: no room rule).
var room_limit := 0
## P2's pace in ticks (0: no pace rule).
var pace_ticks := 0
## Unreleased slide slime id -> its stop distance along the loop (px), set
## each step(). Read by Train.steer and Offscreen's proxy.
var stops := {}
## Released slime id -> true, until it leaves the return route (it lapped,
## or was moved). Not saved (see the class doc).
var released := {}
## The tick of the last release, -1 before any. Not saved.
var last_release := -1
## Debug counters (the probe's), not state: releases, the queue now (slimes
## with a stop that are within QUEUED_NEAR of it: waiting), its length along
## the loop (px, the head's hold point to the last waiting slime), and the
## waits: id -> the tick it started waiting; finished waits, in ticks.
var releases := 0
var queue_now := 0
var queue_px := 0.0
var queue_tail := Vector2.ZERO
var wait_from := {}
var waits := PackedInt32Array()
## A slime within this of its stop and slower than this is waiting (debug).
const QUEUED_NEAR := 12.0

## The hold point for the loop's current length (cached; -1.0 until known).
var _hold := -1.0
var _hold_for_len := -1.0


func _init() -> void:
	configure(OS.get_environment("SLIME_PACING"))


## Reads the rule from `spec` (see the class doc); an unknown token or value
## fails loudly.
func configure(spec: String) -> void:
	enabled = false
	room_limit = 0
	pace_ticks = 0
	for token in spec.to_lower().split(",", false):
		var p := token.split("=")
		assert(p.size() == 2 and p[1].is_valid_int() and int(p[1]) > 0,
				"ReturnPacing: bad SLIME_PACING token '%s'" % token)
		match p[0]:
			"room":
				room_limit = int(p[1])
			"pace":
				pace_ticks = int(p[1])
			_:
				assert(false, "ReturnPacing: unknown SLIME_PACING token '%s'" % token)
	enabled = room_limit > 0 or pace_ticks > 0


## Where along the current loop the head waits (see the class doc), px.
func hold_point(train: Train) -> float:
	var length := train.length()
	if _hold_for_len == length:
		return _hold
	var d := length
	var step := 4.0
	while d > step and train.is_slide_at(d - step):
		var dir := train.direction_at(d - step)
		if absf(dir.y) <= absf(dir.x) * FLAT:
			break
		d -= step
	_hold = d - BACK
	_hold_for_len = length
	return _hold


## Before the train steers: prunes the released set, releases the head when
## the rule allows, and gives every unreleased slide slime its stop (see the
## class doc).
func step(sim: Simulation) -> void:
	stops.clear()
	if not enabled or sim.train == null or sim.train.length() <= 0.0:
		return
	var train := sim.train
	var bodies := sim.slimes
	var hold := hold_point(train)
	var order := PackedInt64Array()
	var room := 0
	for slime_id in train.tracked_ids():
		if bodies.state_of(slime_id) != SlimeBodies.TRAIN:
			released.erase(slime_id)
			wait_from.erase(slime_id)
			continue
		var distance := train.distance_of(slime_id)
		if not train.is_slide_at(distance):
			released.erase(slime_id)
			_end_wait(slime_id, sim.tick)
			if distance < ROOM_STRETCH:
				room += bodies.size_of(slime_id)
			continue
		if released.has(slime_id):
			room += bodies.size_of(slime_id)
		order.append((int(distance * 64.0) << 32) | slime_id)
	for slime_id: int in released.keys():
		if not train.tracks(slime_id):
			released.erase(slime_id)
	order.sort()
	var ahead := -1
	queue_now = 0
	queue_px = 0.0
	for k in range(order.size() - 1, -1, -1):
		var slime_id := int(order[k] & 0xFFFFFFFF)
		var distance := train.distance_of(slime_id)
		if released.has(slime_id) or distance > hold:
			ahead = slime_id
			continue
		if ahead < 0 or released.has(ahead) or train.distance_of(ahead) > hold:
			if _may_release(sim.tick, room):
				released[slime_id] = true
				room += bodies.size_of(slime_id)
				last_release = sim.tick
				releases += 1
				_end_wait(slime_id, sim.tick)
				ahead = slime_id
				continue
		var stop := hold
		if ahead >= 0:
			var widths := bodies.radius_of(slime_id) + bodies.radius_of(ahead) + 2.0 * SlimeBodies.EDGE + GAP
			stop = minf(hold, train.distance_of(ahead) - widths)
		stops[slime_id] = stop
		if stop - distance < QUEUED_NEAR and bodies.velocity_of(slime_id).length() < 30.0:
			queue_now += 1
			queue_px = hold - distance
			queue_tail = bodies.centre_of(slime_id)
			if not wait_from.has(slime_id):
				wait_from[slime_id] = sim.tick
		ahead = slime_id


## Whether the rule lets the head go at `tick`, with `room` base slimes on
## the first stretch and in transit.
func _may_release(tick: int, room: int) -> bool:
	if room_limit > 0 and room >= room_limit:
		return false
	if pace_ticks > 0 and last_release >= 0 and tick - last_release < pace_ticks:
		return false
	return true


## Ends slime `slime_id`'s wait (debug), if it was waiting.
func _end_wait(slime_id: int, tick: int) -> void:
	if wait_from.has(slime_id):
		waits.append(tick - int(wait_from[slime_id]))
		wait_from.erase(slime_id)


## The speed a grounded slide slime at `distance` is carried at toward its
## stop (see the class doc), px/s; SLIDE_SPEED or more when it has none.
func carry_speed(slime_id: int, distance: float) -> float:
	if not stops.has(slime_id):
		return Train.SLIDE_SPEED
	var gap: float = stops[slime_id] - distance
	return minf(Train.SLIDE_SPEED, sqrt(2.0 * DECEL * maxf(gap, 0.0)))


## How far parked slime `slime_id` at `distance` may move on, px (INF with
## no stop).
func room_for(slime_id: int, distance: float) -> float:
	if not stops.has(slime_id):
		return INF
	return maxf(0.0, stops[slime_id] - distance)
