class_name StuckSlimes
extends RefCounted
## The stuck safety net (master spec §5.2, D100): slimes that can't fuse
## lodged inside each other are pulled apart. Plain data and pure logic over
## the Simulation's pieces, no scene nodes, no randomness; the Simulation
## owns one (`stuck_slimes`) and calls step() every tick, after the train
## follows.
##
## Every CHECK_TICKS (0.5 s, on the ticks that are a multiple of it) the
## simulated slimes (not parked; every state) are checked in pairs: a pair
## whose centres are closer than CLOSE_SHARE of the smaller one's ring radius
## counts one more check, a pair that isn't loses its count. A pair about to
## fuse is never counted: the same species, sizes adding up to
## SlimeBodies.MAX_SIZE at most (SlimeBodies.can_merge), both awake (train or
## free: Fusion's rule).
##
## A pair found so on CHECKS checks in a row (about 2 s) is stuck. The slime
## that moves is the smaller one, on a tie the higher id, among those of the
## two that are a train or a free slime (mover_of()): it is due a move to the
## loop start, back on the train, and waits its turn in the loop-start queue
## (LoopStartQueue, D150), which moves it (LoopStart.move, the move lost and
## stalled slimes take too) and logs it here (moved()); every pair it was in
## then loses its count (forget()). While its mover waits, the pair's count
## keeps counting (CHECKS + 1, + 2, ...), so the check that made it stuck is
## read back from it (stuck_since()); a pair that has come apart by its turn
## has lost its count, and its mover leaves the queue without a move.
## Sleepers, slimes in a basket and bedtime-asleep slimes are never moved:
## when neither slime may move, the pair is only logged, once while it stays
## so (its count stays at CHECKS). Every case is logged in `stuck`: {"id"
## (the slime moved, or the one that would have been), "other", "tick",
## "reason": STUCK, "moved"}.
##
## Stuck is its own case, not lost (D10): it isn't in Offscreen's lost log.
## It stays as the backstop. The cause found (O91): the contacts drew two
## rings deeper than a radius inside each other together until their centres
## met; they now push them apart (SlimeBodies._solve_contacts).
##
## Cost: the pairs come from one sweep along x (a native sort of the
## simulated slimes' centres, then only neighbours within the largest
## threshold), so a check costs about as much as a sort of the simulated
## slimes, once every CHECK_TICKS.
##
## The counts and the log are in dump() and in saves ("stuck_slimes",
## SaveData).
# @spec-link [[rule_stuck_slimes_moved_to_start]]

## How often the pairs are checked, ticks (0.5 s, D100).
const CHECK_TICKS := 30
## Checks in a row that make a pair stuck (about 2 s, D100).
const CHECKS := 4
## Closer than this share of the smaller one's ring radius, a pair's centres
## count (a quarter, D100).
const CLOSE_SHARE := 0.25
## How many cases `stuck` keeps (the latest).
const LOG_SIZE := 64
## The reason logged.
const STUCK := "stuck"
## The sweep (_close_pairs): each simulated slime as one sortable integer,
## its x from the leftmost in 1/ORDER_SCALE px above ORDER_SHIFT bits, its
## index below.
const ORDER_SCALE := 16.0
const ORDER_SHIFT := 20
const ORDER_INDEX_MASK := (1 << ORDER_SHIFT) - 1

## Vector2i(lower id, higher id) -> the checks in a row its centres were close
## (past CHECKS while its mover waits its turn, see the class doc).
var counts := {}
## The last LOG_SIZE cases, oldest first (see the class doc).
var stuck: Array[Dictionary] = []


## One tick, after the train follows: on a check tick, counts the close
## pairs and logs the stuck ones neither of which may move (see the class
## doc); the others wait in the loop-start queue.
# @spec-link [[req_slime_states]]
# @spec-link [[rule_stuck_slimes_moved_to_start]]
func step(sim: Simulation) -> void:
	if sim.tick % CHECK_TICKS != 0:
		return
	var bodies := sim.slimes
	var found := _close_pairs(bodies)
	var next := {}
	for pair in found:
		var was: int = counts.get(pair, 0)
		var movable := mover_of(bodies, pair) >= 0
		next[pair] = was + 1 if movable or was < CHECKS else CHECKS
		if was == CHECKS - 1 and not movable:
			_log(_mover(bodies, pair, false), pair, sim.tick, false)
	counts = next


## The stuck pairs (CHECKS checks or more), in order.
func stuck_pairs() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for pair: Vector2i in counts:
		if counts[pair] >= CHECKS:
			out.append(pair)
	out.sort()
	return out


## The tick of the check that made `pair` stuck, read back from its count at
## `tick` (see the class doc).
func stuck_since(pair: Vector2i, tick: int) -> int:
	assert(counts.get(pair, 0) >= CHECKS, "StuckSlimes.stuck_since: %s is not stuck" % pair)
	return tick - tick % CHECK_TICKS - (int(counts[pair]) - CHECKS) * CHECK_TICKS


## Logs that `slime_id`, stuck with `other`, was moved to the loop start at
## `tick` (by the loop-start queue).
func moved(slime_id: int, other: int, tick: int) -> void:
	_log(slime_id, Vector2i(mini(slime_id, other), maxi(slime_id, other)), tick, true)


## Drops every count `slime_id` is in: it was moved away.
func forget(slime_id: int) -> void:
	for pair: Vector2i in counts.keys():
		if pair.x == slime_id or pair.y == slime_id:
			counts.erase(pair)


## Which of stuck `pair` moves: the smaller, on a tie the higher id, among
## the train and free slimes; -1 when neither may move.
static func mover_of(bodies: SlimeBodies, pair: Vector2i) -> int:
	return _mover(bodies, pair, true)


## The state as plain data, for Simulation.dump() and saves: {"counts":
## [[lower id, higher id, checks]] in order, "stuck": the log}.
# @spec-link [[req_persistence_and_saves]]
func dump() -> Dictionary:
	var pairs := counts.keys()
	pairs.sort()
	var out := []
	for pair: Vector2i in pairs:
		out.append([pair.x, pair.y, counts[pair]])
	return {"counts": out, "stuck": stuck.duplicate(true)}


## Puts back the state dump() gave, as plain JSON data (numbers may be
## floats): counts and log.
# @spec-link [[req_persistence_and_saves]]
func restore(data: Dictionary) -> void:
	counts = {}
	for entry in data.get("counts", []):
		counts[Vector2i(int(entry[0]), int(entry[1]))] = int(entry[2])
	stuck = []
	for entry in data.get("stuck", []):
		stuck.append({"id": int(entry["id"]), "other": int(entry["other"]), "tick": int(entry["tick"]),
				"reason": str(entry["reason"]), "moved": bool(entry["moved"])})


# --- Internals --------------------------------------------------------------

## Logs `pair`'s case: `slime_id` moved, or the one that would have been.
func _log(slime_id: int, pair: Vector2i, tick: int, was_moved: bool) -> void:
	var other_id := pair.y if slime_id == pair.x else pair.x
	stuck.append({"id": slime_id, "other": other_id, "tick": tick, "reason": STUCK, "moved": was_moved})
	if stuck.size() > LOG_SIZE:
		stuck.pop_front()


## Which of `pair` moves: the smaller, on a tie the higher id; with
## `movable_only`, only among the train and free slimes (-1 when neither is).
static func _mover(bodies: SlimeBodies, pair: Vector2i, movable_only: bool) -> int:
	var best := -1
	for slime_id in [pair.y, pair.x]:
		if movable_only and not _awake(bodies.state_of(slime_id)):
			continue
		if best < 0 or bodies.size_of(slime_id) < bodies.size_of(best):
			best = slime_id
	return best


## Every pair of simulated slimes whose centres are close (see the class
## doc) and that isn't about to fuse, as Vector2i(lower id, higher id), in
## order. One sweep along x (see the class doc).
static func _close_pairs(bodies: SlimeBodies) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	# The centres as everything else reads them (the mean of the points:
	# SlimeBodies.centre is a mid-substep estimate, a few px off in a squeeze).
	var centres := PackedVector2Array()
	centres.resize(bodies.slime_count)
	var left := INF
	var widest := 0.0
	for s in bodies.slime_count:
		if bodies.calm[s] != SlimeBodies.PARKED:
			centres[s] = bodies.centre_of(bodies.id[s])
			left = minf(left, centres[s].x)
			widest = maxf(widest, bodies.ring_radius[s])
	var order := PackedInt64Array()
	for s in bodies.slime_count:
		if bodies.calm[s] != SlimeBodies.PARKED:
			order.append((int((centres[s].x - left) * ORDER_SCALE) << ORDER_SHIFT) | s)
	if order.size() < 2:
		return out
	order.sort()
	# A little more than the largest threshold: x is rounded in the order.
	var reach := widest * CLOSE_SHARE + 1.0
	var count := order.size()
	for k in count:
		var s := int(order[k] & ORDER_INDEX_MASK)
		var at := centres[s]
		for j in range(k + 1, count):
			var t := int(order[j] & ORDER_INDEX_MASK)
			var there := centres[t]
			if there.x - at.x > reach:
				break
			var close := minf(bodies.ring_radius[s], bodies.ring_radius[t]) * CLOSE_SHARE
			if at.distance_squared_to(there) >= close * close:
				continue
			var a := bodies.id[s]
			var b := bodies.id[t]
			if bodies.can_merge(a, b) and _awake(bodies.state[s]) and _awake(bodies.state[t]):
				continue
			out.append(Vector2i(mini(a, b), maxi(a, b)))
	out.sort()
	return out


static func _awake(slime_state: int) -> bool:
	return slime_state == SlimeBodies.TRAIN or slime_state == SlimeBodies.FREE
