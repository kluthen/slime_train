class_name TrainClimb
extends RefCounted
## The train's climb: the hold on a climb and the relay, for Train (master
## spec §5.2). Static functions over SlimeBodies and Train's records, no
## state of their own. Train.steer() holds, Train.follow() relays.
##
## Hold on a climb. Train.GRIP alone only halves the motion: on a climb the
## slope's pull creeps a standing slime back down 5 to 17 px/s between hops,
## and a queue climbing out of a basin loses most of what it gains. So on the
## outgoing route, on a stretch rising more than HOLD_FROM (up to
## Train.GRIP_MAX_SLOPE), an active train slime standing between hops also
## has its motion down the slope cancelled and is given HOLD_LIFT of the pull
## gravity puts along the slope in one tick, up the slope
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
## acts at the end of the take-off's tick (Train.follow(), once progress is
## re-derived), so nothing about it crosses into the next tick but the cut
## hop timer, which is state and saved: a run reloaded from a save taken
## just after a take-off carries on as the run that never stopped. It adds
## no state. Finding the one right behind scans every train record (_behind):
## measured at stress-dense (health review Q9, 2026-10-07), the relay costs
## about 44 µs a tick, under 1 % of the tick, so it has no index.

## Hold on a climb (see the class doc): the rise over run above which a
## standing train slime is held, and the share of one tick's pull along the
## slope it is given up the slope.
const HOLD_FROM := 0.1
const HOLD_LIFT := 0.5
## The relay (see the class doc): the most seconds the train slime right
## behind one that takes off waits before its own hop.
const RELAY_DELAY := 0.15


## The hold on a climb (see the class doc) for train slime `slime_id` (index
## `s`), standing on the outgoing route, gripped, waiting for its hop, on a
## stretch going `slope` (unit, along the loop), for a tick of `dt` s.
# @spec-link [[rule_train_climbs_without_sliding_back]]
static func hold(bodies: SlimeBodies, slime_id: int, s: int, slope: Vector2, dt: float) -> void:
	if -slope.y > absf(slope.x) * HOLD_FROM and bodies.calm[s] == SlimeBodies.ACTIVE:
		bodies.hold_on_slope(slime_id, slope, -bodies.gravity.dot(slope) * dt * HOLD_LIFT)


## The relay (see the class doc), at the end of Train.follow(): for each
## train slime that took off on this tick (SlimeBodies.train_hopped), cuts
## the hop timer of the train slime right behind it to RELAY_DELAY, when that
## one stands on the outgoing route within its reach of touching it.
## `records` are Train's (slime id -> record), on a loop `loop_length` px
## long. The cut timer is the bodies' state, saved; the take-offs are not,
## and are not read past this tick.
# @spec-link [[req_hopping_behavior]]
# @spec-link [[rule_train_relay_on_take_off]]
static func relay(bodies: SlimeBodies, records: Dictionary, loop_length: float) -> void:
	for hopped in bodies.train_hopped:
		if not records.has(hopped) or bodies.state_of(hopped) != SlimeBodies.TRAIN:
			continue
		var behind := _behind(bodies, records, loop_length, hopped)
		if behind.is_empty():
			continue
		var follower: int = behind[0]
		var b := bodies.index_of(follower)
		if b < 0 or bodies.train_hopped.has(follower) or bodies.calm[b] == SlimeBodies.PARKED \
				or bodies.supported[b] == 0 or records[follower]["on_slide"]:
			continue
		var room := bodies.radius_of(hopped) + bodies.radius_of(follower) + 2.0 * SlimeBodies.EDGE
		if behind[1] < Train.hop_reach(bodies.size[b]) + room and bodies.hop_timer[b] > RELAY_DELAY:
			bodies.set_hop_timer(follower, RELAY_DELAY)


## The train slime right behind followed train slime `slime_id` along the
## loop (`records`, `loop_length` as relay()'s): the nearest one further
## back by distance (then by id, for slimes at the same distance), the front
## one's round the loop. [its id, the gap along the loop in px], or [] when
## there is no other train slime.
# @spec-link [[rule_train_relay_on_take_off]]
static func _behind(bodies: SlimeBodies, records: Dictionary, loop_length: float, slime_id: int) -> Array:
	var at: float = records[slime_id]["distance"]
	var best := -1
	var best_gap := INF
	for other: int in records:
		if other == slime_id or bodies.state_of(other) != SlimeBodies.TRAIN:
			continue
		var gap: float = at - records[other]["distance"]
		if gap < 0.0 or (gap == 0.0 and other > slime_id):
			gap += loop_length
		if gap < best_gap or (gap == best_gap and other > best):
			best_gap = gap
			best = other
	return [] if best < 0 else [best, best_gap]
