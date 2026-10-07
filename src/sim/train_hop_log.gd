class_name TrainHopLog
extends RefCounted
## The train's debug hop bookkeeping: the hop counters (the PERF line's hops
## and short_hops, D156 point 4) and the hop decision's record (for the
## slime census, src/debug/slime_census.gd). Train owns one (Train.hop_log)
## and feeds it; the perf log, the census and the tools read it.
##
## Hop counters. Train.follow() counts every train hop (an automatic hop of a
## train slime, SlimeBodies.train_hopped; a celebration's hop() and a free
## slime's are not train hops, and a slime on a slide is held, it doesn't
## hop) at its take-off in hops_taken, and at its landing (the first follow()
## after it that finds the slime supported) in short_hops_taken when its
## progress advanced less than half its Train.hop_reach() past its progress
## at take-off. A hop that never lands as a train slime (its state changed,
## moved to the start, parked) is no short hop.
##
## The hop decision's record. Train.hop_target() notes the kind of target it
## gave (last_target_kind: Train.TARGET_AHEAD, TARGET_STEP_FOOT,
## TARGET_STEP_OVER, TARGET_DROP); Train.steer() notes each hop it aims on
## the tick (aimed()); follow() keeps each train slime's last train hop in
## last_hops (its take-off tick and progress, the kind and target of the aim
## it took off on, and at its landing the progress it advanced and whether
## it was short, as the hop counters count it).
##
## None of it is state: it only reads the bodies (no draw, no change to the
## simulation), and neither it nor the take-offs are in dump() or in saves.

## The train hops taken so far, and those of them that landed short (see
## the class doc), cumulative: the perf log prints the difference per line.
# @spec-link [[req_platform_and_performance_targets]]
var hops_taken := 0
var short_hops_taken := 0
## The kind of the last target Train.hop_target() gave (Train.TARGET_*), ""
## before any (see the class doc).
var last_target_kind := ""
## Slime id -> its last train hop (see the class doc): {"tick" (take-off;
## Simulation.tick of that step), "from" (progress at take-off), "kind"
## (Train.TARGET_* of the aim it took off on, or Train.UNAIMED), "target"
## (the aim's target, or null), "landed" (tick; -1 while in the air, or for
## a hop that never lands as a train hop: parked, moved), "advance" (px of
## progress from take-off to landing), "short" (bool)}. Dropped with the
## slime's train record.
var last_hops := {}

## Slime id -> its progress at the take-off of its train hop still in the air
## (the hop counters', see the class doc).
var _takeoff := {}
## Slime id -> [kind, target] of the hop Train.steer() aimed it this tick
## (the census's record, see the class doc). Emptied by every steer().
var _aims := {}


## Whether train slime `slime_id` is in the air on a train hop that hasn't
## landed yet (the hop counters' take-off; for the census).
func in_air(slime_id: int) -> bool:
	return _takeoff.has(slime_id)


## Forgets the aims of the last tick (at the start of Train.steer()).
func clear_aims() -> void:
	if not _aims.is_empty():
		_aims.clear()


## Notes that Train.steer() aimed slime `slime_id`'s hop at `target`, of the
## kind last_target_kind.
func aimed(slime_id: int, target: Vector2) -> void:
	_aims[slime_id] = [last_target_kind, target]


## Forgets slime `slime_id`'s hop in the air (followed afresh: Train.track()).
func forget_takeoff(slime_id: int) -> void:
	_takeoff.erase(slime_id)


## Forgets slime `slime_id` altogether (its train record dropped).
func forget(slime_id: int) -> void:
	_takeoff.erase(slime_id)
	last_hops.erase(slime_id)


## Counts the tick's `count` train take-offs (SlimeBodies.train_hopped).
func count_takeoffs(count: int) -> void:
	hops_taken += count


## The hop counters for train slime `slime_id` (index `s`), just advanced by
## `train` from progress `before` at `tick`: a hop it took this tick takes
## off from `before`; one in the air lands when the slime is supported, short
## when it advanced less than half its Train.hop_reach(); a parked slime's
## hop never lands. last_hops follows them (see the class doc).
# @spec-link [[req_platform_and_performance_targets]]
func count_landing(bodies: SlimeBodies, train: Train, slime_id: int, s: int, before: float, tick: int) -> void:
	if bodies.calm[s] == SlimeBodies.PARKED:
		_takeoff.erase(slime_id)
	elif bodies.train_hopped.has(slime_id):
		_takeoff[slime_id] = before
		var aim: Array = _aims.get(slime_id, [])
		last_hops[slime_id] = {"tick": tick, "from": before, "kind": aim[0] if not aim.is_empty() else Train.UNAIMED,
				"target": aim[1] if not aim.is_empty() else null, "landed": -1, "advance": 0.0, "short": false}
	elif _takeoff.has(slime_id) and bodies.supported[s] != 0:
		var advance: float = train.progress_of(slime_id) - _takeoff[slime_id]
		var short := advance < Train.hop_reach(bodies.size[s]) * 0.5
		if short:
			short_hops_taken += 1
		var last: Dictionary = last_hops.get(slime_id, {})
		if not last.is_empty():
			last["landed"] = tick
			last["advance"] = advance
			last["short"] = short
		_takeoff.erase(slime_id)
