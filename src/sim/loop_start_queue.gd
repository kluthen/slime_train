class_name LoopStartQueue
extends RefCounted
## The loop-start queue (D150 (2)): the slimes due a move to the loop start
## are moved one per turn, the next turn 30 to 120 ticks after the last move.
## The Simulation owns one (`loop_start_queue`) and calls step() last in its
## tick, after the stuck check. Pure logic over the Simulation's pieces.
##
## Due. The safety nets only find the slimes due; none moves a slime itself:
##   stalled        a train slime whose stall clock ran out (Train: its last
##                  mark STALL_SECONDS old), due from that tick;
##   out of bounds  a train slime whose centre is outside the level's bounds
##                  (Train.bounds), due from now;
##   stuck          the mover of a stuck pair (StuckSlimes: CHECKS checks in
##                  a row; its count keeps counting while it waits), due
##                  from the check that made it stuck;
##   lost           a free slime off screen LEFT_ALONE_TICKS plus LOST_TICKS
##                  (Offscreen.away), due from then.
## A slime due for two reasons waits once, at its earliest, and is moved
## under that reason (on a tie: out of bounds, stalled, stuck, lost).
##
## The order: the slimes out of bounds first (outside the level, falling),
## by id; then first due, first moved, ties by id.
##
## A turn. The next turn comes the first draw of the derived stream
## "loop_start:gap:<tick of the last move>" (TURN_MIN to TURN_MAX ticks, both
## included) after the last move, or at once with no move yet. On a turn the
## head of the queue takes a random free spot (LoopStart.free_spot) and is
## moved and logged by its net; with every draw taken nobody moves, and the
## head tries again, with fresh draws, on the next multiple of RETRY_TICKS.
## A turn is tried on the tick it opens, on every multiple of RETRY_TICKS
## after it, and at once on the tick the queue's earliest slime came due (a
## slime due into an empty queue). A slime out of bounds is due "from now":
## while one waits, the queue is tried every tick.
##
## While it waits a slime carries on as it would (simulated or parked,
## resting, hopping): nothing keeps it in place. The queue is rebuilt from
## the nets' state on every turn, so a slime whose reason no longer holds (a
## stalled slime that advanced, a stuck pair come apart, a lost slime back on
## screen or no longer free, a slime back in bounds) is simply no longer in
## it: it leaves without a move, and the turn goes to the next one on the
## same tick.
##
## Derived, not saved (D150): who is due and since when come from the nets'
## saved state (the train records' marks, the stuck counts, the off-screen
## counts, the centres), and the last move's tick from the three move logs
## (Train.stalled, the stuck log's moved entries, Offscreen.lost; a logged
## tick later than the current tick, from an old fixture, is no move). A save
## and reload mid-queue so moves the same slimes on the same ticks to the
## same spots. The debug kill tool's move (Offscreen.lose) stays immediate,
## outside the queue, and counts as a move: it is in the lost log.
# @spec-link [[rule_stalled_train_slime_moved_to_start]]
# @spec-link [[rule_stuck_slimes_moved_to_start]]
# @spec-link [[rule_left_alone_and_lost]]

## The wait from one move to the next turn, ticks (0.5 to 2 s, D150).
const TURN_MIN := 30
const TURN_MAX := 120
## With every draw taken, the head tries again on the next tick that is a
## multiple of this (0.5 s, D150).
const RETRY_TICKS := 30
## The reasons a slime is due (Train.STALLED, Train.OUT_OF_BOUNDS,
## StuckSlimes.STUCK, Offscreen.LOST), in their tie order.
const REASONS: Array[String] = [Train.OUT_OF_BOUNDS, Train.STALLED, StuckSlimes.STUCK, Offscreen.LOST]

## The gap after the last move, read from its stream once (not state: the
## same tick always gives the same gap).
var _gap_after := -1
var _gap := 0


## One tick, last in Simulation.step: on an open turn, moves the head of the
## queue (see the class doc).
# @spec-link [[rule_stalled_train_slime_moved_to_start]]
# @spec-link [[rule_stuck_slimes_moved_to_start]]
# @spec-link [[rule_left_alone_and_lost]]
func step(sim: Simulation) -> void:
	if sim.train == null:
		return
	var tick := sim.tick
	var opens := next_turn(sim)
	if tick < opens:
		return
	var queue := due(sim)
	if queue.is_empty():
		return
	var earliest := tick
	for entry in queue:
		earliest = mini(earliest, entry["since"])
	if tick != opens and tick % RETRY_TICKS != 0 and earliest != tick:
		return
	var head: Dictionary = queue[0]
	var distance := LoopStart.free_spot(sim, head["id"], tick)
	if distance == LoopStart.NO_SPOT:
		return
	_move(sim, head, distance)


## The tick the next turn opens (see the class doc): the last move's tick
## plus its gap, or 0 with no move yet.
func next_turn(sim: Simulation) -> int:
	var last := last_move(sim)
	if last < 0:
		return 0
	if last != _gap_after:
		_gap_after = last
		_gap = sim.rng.derive("loop_start:gap:%d" % last).randi_range(TURN_MIN, TURN_MAX)
	return last + _gap


## The latest tick in the three move logs no later than now, or -1.
# @spec-link [[req_persistence_and_saves]]
static func last_move(sim: Simulation) -> int:
	var tick := sim.tick
	var last := -1
	if sim.train != null:
		last = maxi(last, _latest(sim.train.stalled, tick, false))
	last = maxi(last, _latest(sim.stuck_slimes.stuck, tick, true))
	return maxi(last, _latest(sim.offscreen.lost, tick, false))


## The slimes due a move to the loop start now, in the queue's order (see
## the class doc): {"id", "reason", "since" (the tick it came due), "other"
## (a stuck slime's pair, else -1), "out" (out of bounds)}.
# @spec-link [[req_persistence_and_saves]]
static func due(sim: Simulation) -> Array[Dictionary]:
	var tick := sim.tick
	var bodies := sim.slimes
	var train := sim.train
	var found := {}
	for slime_id in train.tracked_ids():
		var s := bodies.index_of(slime_id)
		if s < 0 or bodies.state[s] != SlimeBodies.TRAIN:
			continue
		var stalled := train.stalled_since(slime_id, tick)
		if stalled >= 0:
			_offer(found, slime_id, Train.STALLED, stalled, -1)
		if train.is_out_of_bounds(bodies.centre_of(slime_id)):
			_offer(found, slime_id, Train.OUT_OF_BOUNDS, tick, -1)
			found[slime_id]["out"] = true
	var stuck := sim.stuck_slimes
	for pair: Vector2i in stuck.stuck_pairs():
		# A slime gone since the last check (fused) breaks its pairs.
		if not bodies.has(pair.x) or not bodies.has(pair.y):
			continue
		var mover := StuckSlimes.mover_of(bodies, pair)
		if mover >= 0:
			var other := pair.y if mover == pair.x else pair.x
			_offer(found, mover, StuckSlimes.STUCK, stuck.stuck_since(pair, tick), other)
	var offscreen := sim.offscreen
	for slime_id: int in offscreen.away:
		var since := int(offscreen.away[slime_id]) + Offscreen.LEFT_ALONE_TICKS + Offscreen.LOST_TICKS
		if since <= tick and bodies.state_of(slime_id) == SlimeBodies.FREE:
			_offer(found, slime_id, Offscreen.LOST, since, -1)
	var out: Array[Dictionary] = []
	for entry: Dictionary in found.values():
		out.append(entry)
	out.sort_custom(_before)
	return out


# --- Internals --------------------------------------------------------------

## Moves `entry`'s slime `distance` px along the loop and logs it under its
## reason, with its net.
func _move(sim: Simulation, entry: Dictionary, distance: float) -> void:
	var slime_id: int = entry["id"]
	match entry["reason"]:
		Offscreen.LOST:
			sim.offscreen.lose(sim, slime_id, distance)
		StuckSlimes.STUCK:
			LoopStart.move(sim.slimes, sim.train, slime_id, distance)
			sim.stuck_slimes.moved(slime_id, entry["other"], sim.tick)
		_:
			LoopStart.move(sim.slimes, sim.train, slime_id, distance)
			sim.train.log_stalled(slime_id, sim.tick, entry["reason"])
	sim.stuck_slimes.forget(slime_id)


## Records that `slime_id` is due for `reason` since `since` (with `other`
## for a stuck slime), keeping its earliest reason (see the class doc).
static func _offer(found: Dictionary, slime_id: int, reason: String, since: int, other: int) -> void:
	if found.has(slime_id):
		var was: Dictionary = found[slime_id]
		if was["since"] < since or (was["since"] == since and REASONS.find(was["reason"]) <= REASONS.find(reason)):
			return
		was["reason"] = reason
		was["since"] = since
		was["other"] = other
		return
	found[slime_id] = {"id": slime_id, "reason": reason, "since": since, "other": other, "out": false}


## The queue's order (see the class doc).
static func _before(a: Dictionary, b: Dictionary) -> bool:
	if a["out"] != b["out"]:
		return a["out"]
	if not a["out"] and a["since"] != b["since"]:
		return a["since"] < b["since"]
	return a["id"] < b["id"]


## The latest tick no later than `tick` in move log `entries` (with
## `moved_only`, among the entries whose "moved" is true), or -1.
static func _latest(entries: Array[Dictionary], tick: int, moved_only: bool) -> int:
	for k in range(entries.size() - 1, -1, -1):
		var entry: Dictionary = entries[k]
		if int(entry["tick"]) > tick or (moved_only and not entry["moved"]):
			continue
		return int(entry["tick"])
	return -1
