class_name TrainHold
extends RefCounted
## The hold (D145, chunk 22e; reworked in chunk 22f, D147 (4); its numbers
## proposed, calibrated from the logs, O107): the Train's helper that holds a
## train slime's due hop before a crowd or a holder in its hop corridor. The
## Train owns one and shares its records with it (the same dictionary:
## "hold" in a slime's record is the tick its hold began, absent when it
## doesn't hold); the Train's steer() calls it, nothing else does. Plain data
## and pure logic over SlimeBodies, no scene nodes, no draw.
##
## The hop corridor: an oriented box from the slime's centre to its hop's
## target (the landing point), extended CORRIDOR_PAST px past it the same
## way, CORRIDOR_HALF_WIDTH px either side of the line (corridor_corners()).
## Every slime with its centre in it counts, resting slimes and holders
## too, any species, but the slime itself, parked slimes, slimes in a basket
## and sleepers (SlimeBodies.corridor_scan). Starting at the slime's centre,
## it only sees ahead of it. When a train slime's hop is due (its timer has
## run out) and it stands on something, holds() runs the corridor's two
## checks (check()) before letting it hop:
##   - the crowd check: the occupancy, the counted slimes' summed area (PI *
##     radius_of^2) over the box's (corridor_area()), above HOLD_OCCUPANCY
##     fails it. A fused slime weighs its area;
##   - the holder rule: a holder in the corridor, anywhere in it (the
##     CORRIDOR_PAST px past the landing point included), fails it at any
##     occupancy, except a holder in the slime's stack zone: its centre
##     projects onto the hop line, measured from the slime's centre, less
##     than the two slimes' radii (radius_of each) away; it overlaps the
##     slime's own column across the hop, above or below it. A holder there
##     still counts toward the occupancy. Two stacked train slimes then never
##     hold because of each other. A holder ahead holds the slimes behind it,
##     so a queue releases front-first: the front's corridor has no holder,
##     the occupancy alone decides for it; each slime behind waits until the
##     one ahead has gone, at its next re-check.
## The holders are read from a snapshot taken at the start of the tick
## (begin_tick(), the start of Train.steer, before any slime decides), not
## from the records as the tick goes on: a slime starting or ending its hold
## this tick is seen as it was at the tick's start by every other slime, so
## no same-tick decision depends on the order the slimes are steered in.
## (Chunk 22g, experimental: with the Train's front-first order on, the
## snapshot is live instead, each slime's entry refreshed once it decided,
## refresh(), so a slime behind sees the decisions of those ahead.)
## Who counts as a holder for the holder rule is _is_holder_like()'s, one
## place: the holders and the train slimes resting by contact (below,
## D147 (4)), so a slime arriving behind a slime resting by contact holds.
## If either check fails it holds. It holds where it stands (no shorter hop):
## its hop timer is kept at HOLD_TIMER_SECONDS at least (keep_timer()),
## without a draw (as the dip nudge does), and it isn't aimed.
##
## When a holder checks again (D147 (2), chunk 22f; check_at()):
##   - the re-checks: every HOLD_RECHECK_TICKS, the first HOLD_RECHECK_TICKS
##     plus a phase (0 to HOLD_RECHECK_TICKS - 1 ticks, drawn once per hold)
##     after the hold began, so the holders' checks don't all fall on the
##     same ticks;
##   - the period's end: a hold's period is HOLD_CAP_TICKS plus an extra (0
##     to HOLD_EXTRA_MAX ticks, uniform, whole), drawn when the period
##     begins; at its end the checks run again (one check, if a re-check
##     falls on the same tick). Still blocked (the crowd check or the holder
##     rule failing), the slime holds on and a new period begins at that
##     tick, with a fresh extra. There is **no forced hop** at a period's
##     end, for a crowd hold and a holder-only hold alike (O109's default):
##     hold_ends_cap stays 0, the counter kept for the PERF line.
## The draws come from streams derived from the master seed (SlimeBodies.
## derive_stream, Rng.derive; no draw from any existing stream, the slimes'
## `slime:<id>` streams untouched): `hold:<id>:<p>`, p the tick the period
## began (the first period's p is the hold's start). Its first draw is that
## period's extra; for the first period only, its second draw is the hold's
## phase. Period k + 1 begins at period k's start + HOLD_CAP_TICKS + its
## extra, so the phase and every period are a pure function of the seed,
## the slime's id, the hold's start (the saved `hold`) and the tick: they are
## rebuilt after a load from the saved hold alone (no save key), computed
## lazily and cached in _periods, which isn't state.
## When both checks pass at a check, the hold ends: a resting holder is
## woken (only it), its timer is set to hop this tick, and the Train aims it
## as any hop (one draw per hop, at the take-off, as always). A dip nudge's
## pin wins (D147 (7)): a holder whose timer is above the floor (pinned on
## the tick before: fusion runs after the train steers) keeps it and hops
## when the pin runs out, its due hop checked again then, as any slime's. It
## may hold again at its next hop. The hold also ends when the slime is
## parked or leaves the train (a call, bedtime: its record goes), is moved to
## the start (a stall or stuck move: a fresh record), or reaches a slide
## (held there, it never hops). A holder may rest (SlimeBodies.set_may_rest,
## set every tick by set_rest(), which the Train's steer() calls), unless one
## of its contacts counts toward fusion (Fusion.counts_toward_fusion):
## resting slimes never touch for fusion. A resting holder isn't gripped nor
## carried: steer() only runs its checks. The hold is in Train.record_of()
## and Train.dump() only while a slime holds, so a run where no slime holds
## keeps its state hash.
##
## Rest by contact (D147 5 (a), chunk 22f; set_rest(), touches_holder()): a
## simulated train slime that isn't holding, isn't on a slide and whose hop
## isn't due (Train.DUE_TICKS) may rest while it touches (TrainQueues.touches:
## its centre within the two radii plus TOUCH_GAP of the holder's, read
## geometrically, since two resting slimes aren't paired in the contacts) one
## or more holders of the start of the tick's snapshot (holding: not other
## slimes resting by contact, so no chain through them; the slime behind one
## holds by the holder rule, and then is a holder) that are ahead of it along
## the loop (TrainQueues.gap_ahead) or in its stack zone: the holder's centre
## projects onto the loop's tangent at the slime's progress (Train.direction_at;
## the tangent, not the hop's direction: no hop target is aimed for a slime
## whose hop isn't due), measured from the slime's centre, less than the two
## radii away: on or under it. Not while one of its contacts counts toward
## fusion (as a holder). It rests by SlimeBodies' rule (on the ground, still
## for REST_TICKS); its hop timer stands still while it rests. It wakes when
## a slime it touches moves off fast (the local wake: the holder ahead hopping
## away) or, set_rest() checking every tick, when it no longer touches a holder
## ahead or in its stack zone (or its hop came due): the Train wakes it, only it
## (and the may-rest slimes resting on it, up the stack). A train slime that
## rests and doesn't hold is resting by contact (TrainQueues' contact_resting).
## Celebration hops, calls, free and parked slimes are not train hops: the
## hold never blocks them (it is not the slide's `held`).
##
## The hold guard (D147 (3), chunk 22f; guard()): the train never freezes.
## With no forced hop, holders could wait on each other for ever (a ring of
## holders round the loop, a front holder whose crowd never thins while the
## whole train waits on it). At the start of every tick (Train.steer, right
## after the holder snapshot, before any slime decides) the guard fires when
## at least one train slime holds, every simulated train slime (a train
## slime, not parked) is holding, resting, `held` (covered by others, or on
## a slide) or pinned by the dip nudge (dip_pinned(): a dip's floor slime
## waiting for a partner), and the most recent hold start among the holders
## is at least HOLD_GUARD_TICKS old. It then releases the front-most holder (the
## longest gap along the loop to the next train slime ahead of it, simulated
## or parked, by the records' distances; a tie to the lower id;
## front_most()): its hold ends with no check, through the crowd, by the
## same path as a clear end (woken if resting, the dip nudge's pin kept),
## and it hops on that tick. One release per firing, counted in
## guard_releases (not crowded_hops). The condition is derived each tick
## from saved state only (the holds' starts, the states, the calm, `held`,
## the hop timers), so it needs no save key. Which net fires first: the guard, at most the
## longest hop interval plus HOLD_GUARD_TICKS after a freeze starts; the
## stall net (Train.stall_of: no STALL_ADVANCE px of progress in
## STALL_SECONDS, then a move to the loop's start) is per slime and stays
## the last resort. Hold time counts toward a stall (O110's default): the
## hold never resets nor pauses a slime's stall mark, so a queue held behind
## a crowd while other train slimes still hop is moved after 60 s.
# @spec-link [[req_hopping_behavior]]
# @spec-link [[rule_loop_travelable_with_no_input]]

## The hop corridor's numbers (proposed, D147 (4), O107): how far past the
## landing point it reaches, px, and how far either side of the hop line,
## px. Above HOLD_OCCUPANCY (the counted area over the box's) the crowd
## check fails: calibrated in 22f part 2 (proposed), the sweep 0.5 to 0.7 on
## stress-moving and s3-basket-59of60 found no value with no stall move over
## 10,000 ticks; 0.7 had the fewest (stress-moving 16 and 39 against 97 and
## 94 at 0.5) and the most hops. A holder checks again every
## HOLD_RECHECK_TICKS (0.5 s, from a phase) and at its period's end: a period
## is HOLD_CAP_TICKS (5 s) plus 0 to HOLD_EXTRA_MAX ticks (1 s) (D147 (2),
## proposed).
# @spec-link [[req_hopping_behavior]]
const CORRIDOR_PAST := 100.0
const CORRIDOR_HALF_WIDTH := 75.0
const HOLD_OCCUPANCY := 0.7
const HOLD_RECHECK_TICKS := 30
const HOLD_CAP_TICKS := 300
const HOLD_EXTRA_MAX := 60
## How long the whole train must have waited (the most recent hold start's
## age, ticks; 4 s) before the hold guard releases a holder (D147 (3),
## proposed).
# @spec-link [[req_hopping_behavior]]
# @spec-link [[rule_loop_travelable_with_no_input]]
const HOLD_GUARD_TICKS := 240
## check_at()'s answer: no check this tick, a re-check, a period's end.
# @spec-link [[req_hopping_behavior]]
const NO_CHECK := 0
const RECHECK := 1
const PERIOD_END := 2
## check()'s answer, bit flags: the crowd check fails (CROWDED), the holder
## rule fails (HOLDER_AHEAD); 0 when both pass.
# @spec-link [[req_hopping_behavior]]
const CROWDED := 1
const HOLDER_AHEAD := 2
## The hop timer a holder is kept at, s, at least (the floor): above
## steer()'s "due" (1.5 ticks), so its hop never fires while it holds, with
## no draw. Clearly below the dip nudge's pin (Fusion.DIP_HOLD_SECONDS,
## 0.25 s), so a hold's end tells a pin from the floor: a holder's timer
## above the floor (PIN_MARGIN aside) was raised by the pin. Proposed (22f;
## 0.25 s, the pin's value, in 22e).
# @spec-link [[req_hopping_behavior]]
# @spec-link [[rule_dip_may_nudge_fusion]]
const HOLD_TIMER_SECONDS := 0.1
## How far above HOLD_TIMER_SECONDS a holder's timer must be to count as
## pinned, s: room for a saved timer's rounding, far below any pin.
# @spec-link [[rule_dip_may_nudge_fusion]]
const PIN_MARGIN := 0.000001
## The side of the holders' cells (begin_tick(), touches_holder()), px: at
## least the widest touching distance (two size-3 rings: their radii, 36.4
## px each, plus TrainQueues.TOUCH_GAP), so the 3 x 3 cells round a slime's
## hold every holder it touches. Each holder is listed in the 3 x 3 cells
## round its own, so a slime looks up its own cell only.
# @spec-link [[req_offscreen_simulation]]
const CONTACT_CELL := 80.0
## An empty cell's holders (touches_holder(): no allocation per lookup).
const _NO_HOLDERS: Array = []

## The hold's debug counters' names (counters()), in the PERF line's order.
# @spec-link [[req_platform_and_performance_targets]]
const COUNTERS: Array[String] = ["hold_ends_clear", "hold_ends_cap", "guard_releases", "hold_ends_other",
		"front_hops", "queue_hops", "holder_holds", "crowd_holds", "crowded_hops"]

## The hold's debug counters (chunk 22f, D147 (1) and (8)), cumulative like
## Train.hops_taken: the perf log prints their difference per line. Read
## only: no draw, no change to the simulation, not in the dump nor saves.
##   hold_ends_clear  holds ended at a check (a re-check or a period's
##                    end), both checks passing;
##   hold_ends_cap    holds ended by the cap: 0 by construction since 22f
##                    (no forced hop at a period's end), kept for the line;
##   guard_releases   holds ended by the hold guard (guard());
##   hold_ends_other  holds ended otherwise: a slide, parking, no longer a
##                    train slime (a call, bedtime) or gone, a stall or
##                    stuck move (a record restored over it is no end);
##   front_hops       train hops taken by the front of their touching queue
##                    (TrainQueues.is_front);
##   queue_hops       train hops taken while the nearest simulated train
##                    slime ahead within the hop's reach (Train.hop_reach)
##                    holds or rests (TrainQueues.waits_behind);
##   holder_holds     holds started by the holder rule with the occupancy at
##                    or below HOLD_OCCUPANCY (D147 (4): the holds the holder
##                    rule starts below the threshold, its own share);
##   crowd_holds      holds started with the occupancy above it, a holder in
##                    the corridor or not: a hold both checks start is filed
##                    here only, never in holder_holds (with holder_holds,
##                    every hold started, each once; a split part's
##                    inherited hold is no start);
##   crowded_hops     train hops taken with the occupancy above it, guard
##                    releases apart: 0 by construction since 22f (every
##                    train hop passed its checks: a due slime's, a clear
##                    end; the cap forces none), kept for the line.
# @spec-link [[req_platform_and_performance_targets]]
var hold_ends_clear := 0
var hold_ends_cap := 0
var guard_releases := 0
var hold_ends_other := 0
var front_hops := 0
var queue_hops := 0
var holder_holds := 0
var crowd_holds := 0
var crowded_hops := 0
## The occupancy the last check() measured (debug, read only; a probe reads
## it). Not state.
# @spec-link [[req_platform_and_performance_targets]]
var last_occupancy := 0.0

## The Train's records (the same dictionary, shared): slime id -> record.
var _records: Dictionary
## The holder the hold guard released this tick (guard()), -1 for none:
## holds() lets it hop with no check. Reset by begin_tick() every tick, so
## not state.
# @spec-link [[req_hopping_behavior]]
var _released := -1
## The holds' schedules (_period()): slime id -> [the hold's start, its
## phase, the current period's start, its end]. Rebuilt from the saved hold
## start alone, so not state: emptied of a slime when its hold ends.
# @spec-link [[req_hopping_behavior]]
# @spec-link [[req_persistence_and_saves]]
var _periods := {}
## The holders at the start of this tick (begin_tick()), holding: slime id
## -> its cell (the hold guard's, rest by contact's), and the holder rule's
## (_is_holder_like: those and the train slimes resting by contact), and the
## holders by cell (Vector2i of CONTACT_CELL px cells -> Array of the ids of
## the holders in it or in the 8 cells round it, for touches_holder()). Rebuilt every tick from the records, so not state.
## With the Train's front-first order on, refresh() keeps them live through
## the tick (chunk 22g, experimental).
# @spec-link [[req_hopping_behavior]]
# @spec-link [[req_offscreen_simulation]]
var _holders := {}
var _holder_like := {}
var _holder_cells := {}
## check()'s corridor ids, reused (no allocation per check).
var _in_corridor: Array[int] = []


## A hold over the Train's `records` (shared, not copied).
func _init(records: Dictionary) -> void:
	_records = records


## The area of the hop corridor from `from` to a hop's `target`, px²: its
## length (the hop's, plus CORRIDOR_PAST) times its width.
# @spec-link [[req_hopping_behavior]]
static func corridor_area(from: Vector2, target: Vector2) -> float:
	return (from.distance_to(target) + CORRIDOR_PAST) * 2.0 * CORRIDOR_HALF_WIDTH


## The hop corridor's corners from `from` to a hop's `target` (the debug
## overlay outlines it): the start's and the far end's, on one side, then
## the far end's and the start's on the other. None for a hop going nowhere.
# @spec-link [[req_platform_and_performance_targets]]
static func corridor_corners(from: Vector2, target: Vector2) -> PackedVector2Array:
	var axis := target - from
	if axis.length() < 0.001:
		return PackedVector2Array()
	var way := axis.normalized()
	var side := Vector2(-way.y, way.x) * CORRIDOR_HALF_WIDTH
	var end := target + way * CORRIDOR_PAST
	return PackedVector2Array([from - side, end - side, end + side, from + side])


## The occupancy of the hop corridor from `from` to `target` in `bodies`, all
## but `except_id` (the hopper): the counted slimes' summed area over the
## box's. Read only.
# @spec-link [[req_hopping_behavior]]
static func occupancy_of(bodies: SlimeBodies, from: Vector2, target: Vector2, except_id: int) -> float:
	var ids: Array[int] = []
	return bodies.corridor_scan(from, target, CORRIDOR_PAST, CORRIDOR_HALF_WIDTH, except_id, ids) \
			/ corridor_area(from, target)


## The debug counters (see COUNTERS), name -> count, in COUNTERS' order.
# @spec-link [[req_platform_and_performance_targets]]
func counters() -> Dictionary:
	return {"hold_ends_clear": hold_ends_clear, "hold_ends_cap": hold_ends_cap, "guard_releases": guard_releases,
			"hold_ends_other": hold_ends_other, "front_hops": front_hops, "queue_hops": queue_hops,
			"holder_holds": holder_holds, "crowd_holds": crowd_holds, "crowded_hops": crowded_hops}


## Takes the start of the tick's holder snapshot (see the class doc) and
## clears the hold guard's last release: the Train's steer() calls it first,
## before guard() and before any slime decides.
# @spec-link [[req_hopping_behavior]]
func begin_tick(bodies: SlimeBodies) -> void:
	_released = -1
	_holders.clear()
	_holder_like.clear()
	_holder_cells.clear()
	for slime_id: int in _records:
		if not _is_holder_like(bodies, slime_id):
			continue
		_holder_like[slime_id] = true
		if _records[slime_id].has("hold"):
			_add_holder(bodies, slime_id)


## Lists holder `slime_id` in the snapshot's holders, under its cell, and
## in the 3 x 3 cells round it (begin_tick(), refresh()).
# @spec-link [[req_offscreen_simulation]]
func _add_holder(bodies: SlimeBodies, slime_id: int) -> void:
	var cell := Vector2i((bodies.centre_of(slime_id) / CONTACT_CELL).floor())
	_holders[slime_id] = cell
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var near := cell + Vector2i(dx, dy)
			if not _holder_cells.has(near):
				_holder_cells[near] = []
			_holder_cells[near].append(slime_id)


## The front-first order's live snapshot (chunk 22g, experimental; the
## Train's steer() calls it only with Train.front_first on, after slime
## `slime_id` decided): its entry in the holder snapshot is set again from
## its state now, by begin_tick()'s rule (added or taken out of the holders,
## the holder rule's and the cells), so the slimes steered after it this
## tick, behind it, see this tick's decision (a front holder letting go is
## no holder for them; one starting to hold is). Only its entry: slimes
## SlimeBodies.wake woke up its stack keep theirs until their own turn.
# @spec-link [[req_hopping_behavior]]
# @spec-link [[req_platform_and_performance_targets]]
# @spec-link [[rule_loop_travelable_with_no_input]]
func refresh(bodies: SlimeBodies, slime_id: int) -> void:
	var like := _records.has(slime_id) and _is_holder_like(bodies, slime_id)
	if like:
		_holder_like[slime_id] = true
	else:
		_holder_like.erase(slime_id)
	var holding: bool = like and _records[slime_id].has("hold")
	if holding == _holders.has(slime_id):
		return
	if holding:
		_add_holder(bodies, slime_id)
		return
	var cell: Vector2i = _holders[slime_id]
	_holders.erase(slime_id)
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var near := cell + Vector2i(dx, dy)
			var ids: Array = _holder_cells[near]
			ids.erase(slime_id)
			if ids.is_empty():
				_holder_cells.erase(near)


## Whether slime `slime_id` counted as a holder for the holder rule at the
## start of this tick (the snapshot, begin_tick(): a holder, or a train slime
## resting by contact).
# @spec-link [[req_hopping_behavior]]
func was_holder(slime_id: int) -> bool:
	return _holder_like.has(slime_id)


## Whether simulated train slime `slime_id`, the loop's tangent at its
## progress `tangent`, touches a holder of the start of the tick's snapshot
## ahead of it along the loop, `loop_length` px long, or in its stack zone
## (see the class doc, rest by contact). Read only.
# @spec-link [[req_offscreen_simulation]]
func touches_holder(bodies: SlimeBodies, slime_id: int, tangent: Vector2, loop_length: float) -> bool:
	if _holders.is_empty():
		return false
	var at := bodies.centre_of(slime_id)
	var own_radius := bodies.radius_of(slime_id)
	for holder: int in _holder_cells.get(Vector2i((at / CONTACT_CELL).floor()), _NO_HOLDERS):
		if holder == slime_id or not TrainQueues.touches(bodies, slime_id, holder):
			continue
		if TrainQueues.gap_ahead(_records, slime_id, holder, loop_length) >= 0.0 \
				or absf((bodies.centre_of(holder) - at).dot(tangent)) < own_radius + bodies.radius_of(holder):
			return true
	return false


## Sets simulated train slime `slime_id`'s (index `s`) may_rest for this
## tick, after its steer at `dt` (see the class doc): a holder may rest, a
## slime touching a holder ahead or in its stack zone (touches_holder(), the
## loop's tangent at its progress `tangent`, a loop `loop_length` px long)
## may rest by contact, neither while one of its contacts counts toward
## fusion in `fusion`. A slime resting though neither holding nor touching
## such a holder is woken (SlimeBodies.wake: only it, and up the stack).
# @spec-link [[req_offscreen_simulation]]
# @spec-link [[rule_fusion_contact_time]]
func set_rest(bodies: SlimeBodies, slime_id: int, s: int, tangent: Vector2, loop_length: float, dt: float,
		fusion: Fusion) -> void:
	var record: Dictionary = _records[slime_id]
	var holding := record.has("hold")
	var by_contact: bool = not holding and not record["on_slide"] and bodies.hop_timer[s] > dt * Train.DUE_TICKS \
			and touches_holder(bodies, slime_id, tangent, loop_length)
	bodies.set_may_rest(slime_id, (holding or by_contact) and not fusion.counts_toward_fusion(slime_id))
	if not holding and not by_contact and bodies.calm[s] == SlimeBodies.RESTING:
		bodies.wake(slime_id)


## Counts this tick's train hops `bodies.train_hopped` (after Train.follow
## re-derived every progress) on a loop `loop_length` px long: front and
## queue hops (see the counters). Read only.
# @spec-link [[req_platform_and_performance_targets]]
func count_hops(bodies: SlimeBodies, loop_length: float) -> void:
	for slime_id in bodies.train_hopped:
		if not _records.has(slime_id):
			continue
		front_hops += 1 if TrainQueues.is_front(_records, bodies, slime_id, loop_length) else 0
		var reach := Train.hop_reach(bodies.size_of(slime_id))
		queue_hops += 1 if TrainQueues.waits_behind(_records, bodies, slime_id, reach, loop_length) else 0


## Ends slime `slime_id`'s hold, if it has a record and holds, without
## waking it, and counts it in hold_ends_other (parking, a call, bedtime,
## gone, a stall or stuck move).
# @spec-link [[req_platform_and_performance_targets]]
func drop(slime_id: int) -> void:
	_periods.erase(slime_id)
	if _records.has(slime_id) and _records[slime_id].erase("hold"):
		hold_ends_other += 1


## end_hold() for a hold ending otherwise (a slide), counted in hold_ends_other.
# @spec-link [[req_platform_and_performance_targets]]
func end_other(bodies: SlimeBodies, slime_id: int) -> void:
	if _records[slime_id].has("hold"):
		hold_ends_other += 1
	end_hold(bodies, slime_id)


## Whether train slime `slime_id` (index `s`, its hop aimed at `target`),
## its hop due or holding, holds at `tick` (see the class doc): a slime
## standing on something starts holding when a check fails (in the air, it
## hops on landing: it checks then); a holder holds on until both checks
## pass at one of its checks (check_at(): a re-check or a period's end; no
## forced hop), or the hold guard released it this tick (guard(): it hops,
## no check). When its hold ends it is woken (only it) and returns false:
## its timer is set to hop this tick, unless a dip nudge pinned it (D147
## (7), the pin wins: a timer above the floor, set on the tick before, since
## fusion runs after the train steers); then it hops when the pin runs out.
## Derived from the hop timer, saved state: a save and reload keeps the pin.
# @spec-link [[req_hopping_behavior]]
# @spec-link [[rule_dip_may_nudge_fusion]]
func holds(bodies: SlimeBodies, slime_id: int, s: int, target: Vector2, tick: int) -> bool:
	if slime_id == _released:
		return false
	var record: Dictionary = _records[slime_id]
	if not record.has("hold"):
		if bodies.supported[s] == 0:
			return false
		var failed := check(bodies, slime_id, target)
		if failed == 0:
			return false
		record["hold"] = tick
		crowd_holds += 1 if failed & CROWDED else 0
		holder_holds += 0 if failed & CROWDED else 1
		return true
	if check_at(bodies, slime_id, tick) == NO_CHECK or check(bodies, slime_id, target) != 0:
		return true
	hold_ends_clear += 1
	_let_go(bodies, slime_id, s)
	return false


## Whether holder `slime_id` checks again at `tick` (see the class doc):
## PERIOD_END at its period's end, RECHECK at a re-check (HOLD_RECHECK_TICKS
## apart from HOLD_RECHECK_TICKS + its phase after the hold began), else
## NO_CHECK (and for a slime that doesn't hold). Read only for the
## simulation (it fills the schedule cache); public: tests and the probe read it.
# @spec-link [[req_hopping_behavior]]
func check_at(bodies: SlimeBodies, slime_id: int, tick: int) -> int:
	if not _records.has(slime_id) or not _records[slime_id].has("hold"):
		return NO_CHECK
	var start: int = _records[slime_id]["hold"]
	var elapsed := tick - start
	if elapsed <= 0:
		return NO_CHECK
	var period := _period(bodies, slime_id, start, tick)
	if tick == period[3]:
		return PERIOD_END
	var first: int = HOLD_RECHECK_TICKS + period[1]
	return RECHECK if elapsed >= first and (elapsed - first) % HOLD_RECHECK_TICKS == 0 else NO_CHECK


## Holder `slime_id`'s period holding `tick` (a period's end tick belongs to
## the period it ends): Vector2i(its start, its end); (-1, -1) when it
## doesn't hold. Public: tests and the probe read it.
# @spec-link [[req_hopping_behavior]]
func period_at(bodies: SlimeBodies, slime_id: int, tick: int) -> Vector2i:
	if not _records.has(slime_id) or not _records[slime_id].has("hold"):
		return Vector2i(-1, -1)
	var period := _period(bodies, slime_id, _records[slime_id]["hold"], tick)
	return Vector2i(period[2], period[3])


## Holder `slime_id`'s re-check phase (0 to HOLD_RECHECK_TICKS - 1), -1 when
## it doesn't hold. Public: tests read it.
# @spec-link [[req_hopping_behavior]]
func phase_of(bodies: SlimeBodies, slime_id: int) -> int:
	if not _records.has(slime_id) or not _records[slime_id].has("hold"):
		return -1
	var start: int = _records[slime_id]["hold"]
	return _period(bodies, slime_id, start, start)[1]


## The name of the stream holding the draws of slime `slime_id`'s period
## that began at tick `period_start` (see the class doc).
# @spec-link [[req_hopping_behavior]]
static func stream_name(slime_id: int, period_start: int) -> String:
	return "hold:%d:%d" % [slime_id, period_start]


## The hold guard at `tick`, on a loop `loop_length` px long (see the class
## doc), run after begin_tick(), before any slime decides: when it fires,
## the front-most holder's hold ends (woken if resting, the pin kept) and
## it hops this tick, no check (holds() lets it go). Returns its id, or -1
## when the guard doesn't fire.
# @spec-link [[req_hopping_behavior]]
# @spec-link [[rule_loop_travelable_with_no_input]]
func guard(bodies: SlimeBodies, tick: int, loop_length: float) -> int:
	if _holders.is_empty():
		return -1
	var latest := 0
	var seen := false
	for slime_id: int in _holders:
		var began: int = _records[slime_id]["hold"]
		latest = began if not seen else maxi(latest, began)
		seen = true
	if tick - latest < HOLD_GUARD_TICKS:
		return -1
	for slime_id: int in _records:
		var s := bodies.index_of(slime_id)
		if s < 0 or bodies.state[s] != SlimeBodies.TRAIN or bodies.calm[s] == SlimeBodies.PARKED:
			continue
		if not _holders.has(slime_id) and bodies.calm[s] != SlimeBodies.RESTING and bodies.held[s] == 0 \
				and not dip_pinned(bodies, s):
			return -1
	_released = front_most(_records, bodies, _holders.keys(), loop_length)
	guard_releases += 1
	_let_go(bodies, _released, bodies.index_of(_released))
	return _released


## Whether the slime at index `s` of `bodies`, not a holder, is pinned by the
## dip nudge (Fusion._nudge), read at the start of a tick: its hop timer at
## Fusion.DIP_HOLD_SECONDS (PIN_MARGIN aside), where the nudge, the last part
## of the tick before, left it. The hold guard counts it as waiting. Derived
## from the hop timer, saved state (no save key); an untouched timer passing
## that value exactly at a tick's start reads as pinned for that tick.
# @spec-link [[req_hopping_behavior]]
# @spec-link [[rule_loop_travelable_with_no_input]]
# @spec-link [[rule_dip_may_nudge_fusion]]
static func dip_pinned(bodies: SlimeBodies, s: int) -> bool:
	return absf(bodies.hop_timer[s] - Fusion.DIP_HOLD_SECONDS) <= PIN_MARGIN


## The front-most of `holders` (ids of `records`, the Train's): the one with
## the longest gap along a loop `loop_length` px long, by the records'
## distances, to the next train slime ahead of it (simulated or parked; at
## the same distance the lower id is ahead, as TrainQueues'; none ahead: a
## whole loop); a tie to the lower id. -1 for no holder.
# @spec-link [[req_hopping_behavior]]
# @spec-link [[rule_loop_travelable_with_no_input]]
static func front_most(records: Dictionary, bodies: SlimeBodies, holders: Array, loop_length: float) -> int:
	var best := -1
	var best_gap := -1.0
	for holder: int in holders:
		var gap := loop_length
		for other: int in records:
			if other == holder or bodies.state_of(other) != SlimeBodies.TRAIN:
				continue
			var d := fposmod(float(records[other]["distance"]) - float(records[holder]["distance"]), loop_length)
			gap = minf(gap, d if d > 0.0 or other < holder else loop_length)
		if gap > best_gap or (gap == best_gap and holder < best):
			best = holder
			best_gap = gap
	return best


## The hop corridor's two checks (see the class doc) for train slime
## `slime_id`, its hop aimed at `target`: CROWDED when the crowd check
## fails, HOLDER_AHEAD when the holder rule does (a snapshot holder, or a
## train slime resting by contact, outside its stack zone), 0 when both pass. Sets last_occupancy. Read only for the
## simulation. Public: a diagnostic probe reads it too.
# @spec-link [[req_hopping_behavior]]
func check(bodies: SlimeBodies, slime_id: int, target: Vector2) -> int:
	var from := bodies.centre_of(slime_id)
	var area := bodies.corridor_scan(from, target, CORRIDOR_PAST, CORRIDOR_HALF_WIDTH, slime_id, _in_corridor)
	last_occupancy = area / corridor_area(from, target)
	var failed := CROWDED if last_occupancy > HOLD_OCCUPANCY else 0
	var way := (target - from).normalized()
	var own_radius := bodies.radius_of(slime_id)
	for other in _in_corridor:
		if not _holder_like.has(other):
			continue
		var along := absf((bodies.centre_of(other) - from).dot(way))
		if along >= own_radius + bodies.radius_of(other):
			failed |= HOLDER_AHEAD
			break
	return failed


## Keeps holder `slime_id`'s (index `s`) hop timer at HOLD_TIMER_SECONDS at
## least, without a draw: its hop doesn't fire while it holds.
# @spec-link [[req_hopping_behavior]]
func keep_timer(bodies: SlimeBodies, slime_id: int, s: int) -> void:
	bodies.set_hop_timer(slime_id, maxf(bodies.hop_timer[s], HOLD_TIMER_SECONDS))


## Ends slime `slime_id`'s hold, if it holds; a resting holder is woken, only
## it (SlimeBodies.wake: the rest of its pile rests on).
# @spec-link [[req_hopping_behavior]]
func end_hold(bodies: SlimeBodies, slime_id: int) -> void:
	_periods.erase(slime_id)
	if _records[slime_id].erase("hold") and bodies.calm_of(slime_id) == SlimeBodies.RESTING:
		bodies.wake(slime_id)


## Ends holder `slime_id`'s (index `s`) hold to hop (a clear end, a guard
## release): end_hold(), then its timer is set to hop this tick unless a dip
## nudge's pin holds it above the floor (the pin wins, D147 (7)).
# @spec-link [[req_hopping_behavior]]
# @spec-link [[rule_dip_may_nudge_fusion]]
func _let_go(bodies: SlimeBodies, slime_id: int, s: int) -> void:
	end_hold(bodies, slime_id)
	if bodies.hop_timer[s] <= HOLD_TIMER_SECONDS + PIN_MARGIN:
		bodies.set_hop_timer(slime_id, 0.0)


## Holder `slime_id`'s schedule for its hold begun at `start`, its period
## holding `tick` reached (see the class doc): [start, its phase, the
## period's start, its end], from the cache, rebuilt from `start` alone
## when missing, stale or past `tick`. Period k + 1 begins where period k
## ends; each period's extra is the first draw of its stream (stream_name),
## the phase the first period's second draw.
# @spec-link [[req_hopping_behavior]]
# @spec-link [[req_persistence_and_saves]]
func _period(bodies: SlimeBodies, slime_id: int, start: int, tick: int) -> Array:
	var period: Array = _periods.get(slime_id, [])
	if period.is_empty() or period[0] != start or (tick <= period[2] and period[2] != start):
		var stream := bodies.derive_stream(stream_name(slime_id, start))
		var extra := stream.randi_range(0, HOLD_EXTRA_MAX)
		period = [start, stream.randi_range(0, HOLD_RECHECK_TICKS - 1), start, start + HOLD_CAP_TICKS + extra]
		_periods[slime_id] = period
	while period[3] < tick:
		period[2] = period[3]
		period[3] += HOLD_CAP_TICKS + bodies.derive_stream(stream_name(slime_id, period[2])).randi_range(0,
				HOLD_EXTRA_MAX)
	return period


## Whether followed slime `slime_id` counts as a holder for the holder rule
## (the snapshot's one test, begin_tick()): a simulated train slime (a train
## slime, not parked) that holds its hop, or that rests without holding (a
## train slime resting by contact with a holder, D147 5 (a): only rest by
## contact lets a train slime that doesn't hold rest).
# @spec-link [[req_hopping_behavior]]
# @spec-link [[req_offscreen_simulation]]
func _is_holder_like(bodies: SlimeBodies, slime_id: int) -> bool:
	var s := bodies.index_of(slime_id)
	if s < 0 or bodies.state[s] != SlimeBodies.TRAIN or bodies.calm[s] == SlimeBodies.PARKED:
		return false
	return _records[slime_id].has("hold") or bodies.calm[s] == SlimeBodies.RESTING
