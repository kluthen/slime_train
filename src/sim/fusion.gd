class_name Fusion
extends RefCounted
## Fusion and bumping (master spec §5.2 "Fusion and splitting", §5.3, D20,
## D37, D49): which slimes fuse, and when. Plain data and pure logic over the
## Simulation's pieces, no scene nodes. The ring operation itself is
## SlimeBodies.merge, reached through Simulation.fuse() so the stable
## identities follow (SlimeIdentities).
##
## Contact timers. After the bodies tick, every pair of slimes whose rings
## touch (SlimeBodies.touching_pairs) and that counts (both awake, train or
## free; the same species; both centres on screen; neither in a split zone)
## adds one tick to its count. A pair that stops touching for even one tick,
## because a hop broke the contact or anything else, or stops counting,
## loses its count: the next contact starts from zero. There is no grace for
## solver jitter: two slimes resting against each other stay within
## SlimeBodies.TOUCH_SKIN of each other every tick (tests show it), so none
## is needed.
##
## At CONTACT_TICKS (3 s) of continuous contact, a pair whose sizes add up to
## SlimeBodies.MAX_SIZE at most fuses: the fused slime keeps the lower id and
## with it that slime's state and records (a train slime stays on the train
## with its progress, a free slime keeps its phase, call point and stream),
## at the size-weighted centre. A pair that would go past the maximum size
## bumps instead: a small push apart (BUMP_SPEED, BUMP_LIFT, momentum shared
## by size), and its count starts again, so a pair that stays together bumps
## every 3 s rather than every tick. Slimes of different species never count.
##
## On screen only (§5.3). A pair counts only while both centres are inside
## the view (Simulation.view, which the scene copies from the camera before
## every tick) shrunk by VIEW_MARGIN, so the player sees the whole fusion.
## Off screen the count is dropped, not paused: a pair that comes back into
## view starts from zero.
##
## Not inside a split zone: a slime fused there would be split again at
## once.
##
## The dip nudge (level rule 5, test level 1.3). Train slimes pass through a
## dip at the train's pace and would rarely rest together for 3 s, so the
## bottom of a dip slows them a little (see dip_floors() for what a dip is):
##   - gathering: a train slime on a dip's floor waits there (doesn't hop)
##     for a train slime it may fuse with (same species, sizes adding up to
##     3 at most) less than DIP_GATHER px behind it along the loop, so that
##     one catches up with it. For the train slime directly behind it (no
##     other train slime between them) it waits as long as that holds; for
##     one with other slimes between them, which can't catch up while they
##     are in the way, only until its own progress has not advanced for
##     DIP_WAIT_SECONDS (Train's stall mark, "marked_at": a slime pushed on
##     by the queue waits again, briefly);
##   - holding: on a dip's floor, two such train slimes that touch don't hop
##     until they fuse or lose contact.
## Both only on screen, where fusion can happen. Slimes that would bump, or
## of different species, are never held. A waiting slime is let go as soon
## as no partner is behind it in reach, the one directly behind is not a
## partner and its wait is up, or it fuses (a partner directly behind hops
## on at the train's pace, so that wait is short).
##
## Why the cap (chunk 16f): the train reaches the dips as interleaved
## species (A, B, C, A, ...), so a partner usually has a slime of another
## species between them. Waiting for it with no limit held the whole queue
## behind: it crept a few px a second and train slimes stalled (DoD 1).
## The short wait still lets slimes bunch up at the bottom, where
## same-species contacts fuse or bump (test level 1.3).
##
## The nudge's record (debug, for the slime census,
## src/debug/slime_census.gd): `nudged` holds the train slimes the last
## tick's nudge held, and why (NUDGE_HOLDING or NUDGE_GATHERING). It only
## notes what the nudge decided: not state, not in dump() nor saves.
##
## State: the counts (pair of runtime ids -> ticks), in dump() and in saves.
## The dip floors are recomputed from the loop whenever the open gates
## change; they are not state.
##
## Tick order (Simulation.step): after the split zones, before the free
## slimes and the train follow (they drop the fused-away slime's records).
# @spec-link [[rule_fusion_contact_time]]
# @spec-link [[rule_max_size_three]]
# @spec-link [[rule_dip_may_nudge_fusion]]
# @spec-link [[req_offscreen_simulation]]

## Continuous contact before two slimes fuse, s (specs/tuning.md).
const CONTACT_SECONDS := 3.0
const CONTACT_TICKS := 180
## How far inside the view's edges a slime's centre must be to count as on
## screen, px: a base slime's drawn radius, so its whole body shows.
const VIEW_MARGIN := 24.0
## A bump: the speed the two slimes part at, px/s (shared by size, the
## smaller moves more), and the lift each gets, px/s upward, so they leave
## the ground and the push carries.
const BUMP_SPEED := 240.0
const BUMP_LIFT := 200.0
## A dip: a low point of the loop's outgoing route with the route rising at
## least DIP_DEPTH px above it on both sides before it goes any lower.
const DIP_DEPTH := 100.0
## A dip's floor: the stretch of route around its low point that is at most
## DIP_FLOOR_RISE px above it.
const DIP_FLOOR_RISE := 30.0
## How far behind a slime on a dip's floor (px along the loop) a slime it may
## fuse with makes it wait: two hops of a base slime.
const DIP_GATHER := 300.0
## The longest a slime on a dip's floor waits for a partner with other
## slimes between them, s, counted from when its progress last advanced
## (proposed for specs/tuning.md, chunk 16f).
const DIP_WAIT_SECONDS := 5.0
const DIP_WAIT_TICKS := 300
## The hop timer a held slime is kept at, s: it hops soon after it is let go.
const DIP_HOLD_SECONDS := 0.25
## Why the nudge held a slime (`nudged`).
const NUDGE_HOLDING := "holding"
const NUDGE_GATHERING := "gathering"

## Train slime id -> why the last tick's dip nudge held it (NUDGE_HOLDING or
## NUDGE_GATHERING). Debug, for the census (see the class doc).
# @spec-link [[req_platform_and_performance_targets]]
var nudged := {}

## Pair of runtime ids Vector2i(lower, higher) -> ticks of continuous contact.
var _contacts := {}
## The current loop's dip floors: [Vector2(from, to)] distances along it.
var _floors: Array[Vector2] = []
## The loop and open gates the floors were computed for.
var _floors_for := ""


# --- Queries ----------------------------------------------------------------

## Ticks of continuous contact counted for slimes `a` and `b` (0 when none).
func contact_ticks(a: int, b: int) -> int:
	return _contacts.get(Vector2i(mini(a, b), maxi(a, b)), 0)


## The view's box in level pixels.
static func view_rect(view: ScreenView) -> Rect2:
	var size := view.screen_size / view.zoom
	return Rect2(view.centre - size * 0.5, size)


## Whether level point `at` counts as on screen for fusion.
static func on_screen(view: ScreenView, at: Vector2) -> bool:
	return view_rect(view).grow(-VIEW_MARGIN).has_point(at)


## The dip floors of the current loop (`loop` with `open_gates`), as
## Vector2(from, to) distances along it, in order. A dip is a vertex of an
## outgoing segment from which the route, followed both ways without
## leaving the outgoing part or going any lower, rises DIP_DEPTH px above it;
## its floor is the stretch around it at most DIP_FLOOR_RISE px higher.
## Return routes (slides) have no dips. Distances match Train's.
static func dip_floors(loop: LoopData, open_gates: Array) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if loop == null:
		return out
	var pts := PackedVector2Array()
	var dist := PackedFloat64Array()
	var outgoing := PackedByteArray()  # per vertex: on an outgoing segment
	var length := 0.0
	for segment in loop.current_segments(open_gates):
		var points: PackedVector2Array = segment["points"]
		var is_out := 1 if segment["kind"] == LoopData.OUTGOING else 0
		for k in points.size():
			if not pts.is_empty() and k == 0:
				outgoing[outgoing.size() - 1] = outgoing[outgoing.size() - 1] & is_out
				continue
			if not pts.is_empty():
				length += pts[pts.size() - 1].distance_to(points[k])
			pts.append(points[k])
			dist.append(length)
			outgoing.append(is_out)
	for i in pts.size():
		if outgoing[i] == 0:
			continue
		if not _rises(pts, outgoing, i, -1) or not _rises(pts, outgoing, i, 1):
			continue
		var floor_range := Vector2(_floor_end(pts, dist, i, -1), _floor_end(pts, dist, i, 1))
		if not out.is_empty() and out[out.size() - 1].y >= floor_range.x:
			# A flat bottom: several vertices share one floor.
			out[out.size() - 1].y = maxf(out[out.size() - 1].y, floor_range.y)
		else:
			out.append(floor_range)
	return out


## Whether `distance` along the current loop is on a dip's floor.
func on_dip_floor(distance: float) -> bool:
	for floor_range in _floors:
		if distance >= floor_range.x and distance <= floor_range.y:
			return true
	return false


# --- Ticking ----------------------------------------------------------------

## After the bodies tick and the split zones: counts the contacts, fuses the
## pairs that have touched for CONTACT_TICKS (sim.fuse), bumps the ones too
## big to fuse, then nudges the train slimes at the bottom of dips.
func step(sim: Simulation) -> void:
	var bodies := sim.slimes
	var counts := {}
	var due: Array[Vector2i] = []
	for pair: Vector2i in bodies.touching_pairs():
		if not _counts(sim, pair.x, pair.y):
			continue
		var ticks: int = _contacts.get(pair, 0) + 1
		if ticks >= CONTACT_TICKS:
			due.append(pair)
		else:
			counts[pair] = ticks
	_contacts = counts
	var changed := {}
	for pair in due:
		if changed.has(pair.x) or changed.has(pair.y):
			continue
		if bodies.can_merge(pair.x, pair.y):
			if sim.fuse(pair.x, pair.y) >= 0:
				changed[pair.x] = true
				changed[pair.y] = true
		else:
			_bump(bodies, pair.x, pair.y)
	if not changed.is_empty():
		# The fused slime is a fresh ring: its contacts start again.
		for pair: Vector2i in _contacts.keys():
			if changed.has(pair.x) or changed.has(pair.y):
				_contacts.erase(pair)
	_nudge(sim)


## The counts as plain data, for Simulation.dump() and saves: [[a, b,
## ticks]], a < b, in order.
func dump() -> Array:
	var pairs := _contacts.keys()
	pairs.sort()
	var out := []
	for pair: Vector2i in pairs:
		out.append([pair.x, pair.y, _contacts[pair]])
	return out


## Puts the counts back from dump().
func restore(data: Array) -> void:
	_contacts.clear()
	for entry in data:
		_contacts[Vector2i(int(entry[0]), int(entry[1]))] = int(entry[2])


# --- Internals --------------------------------------------------------------

## Whether the touching pair (a, b) counts toward fusing or bumping.
func _counts(sim: Simulation, a: int, b: int) -> bool:
	var bodies := sim.slimes
	var sa := bodies.index_of(a)
	var sb := bodies.index_of(b)
	if sa < 0 or sb < 0 or bodies.species[sa] != bodies.species[sb]:
		return false
	if not _awake(bodies.state[sa]) or not _awake(bodies.state[sb]):
		return false
	var ca := bodies.centre_of(a)
	var cb := bodies.centre_of(b)
	if not on_screen(sim.view, ca) or not on_screen(sim.view, cb):
		return false
	return not sim.split_zones.covers(ca) and not sim.split_zones.covers(cb)


static func _awake(slime_state: int) -> bool:
	return slime_state == SlimeBodies.TRAIN or slime_state == SlimeBodies.FREE


## Pushes a and b apart: they part at BUMP_SPEED, the smaller moving more
## (momentum kept), and both lift off at BUMP_LIFT.
func _bump(bodies: SlimeBodies, a: int, b: int) -> void:
	var apart := bodies.centre_of(b) - bodies.centre_of(a)
	var direction := apart.normalized() if apart.length() > 0.001 else Vector2.RIGHT
	var wa := float(bodies.size_of(a))
	var wb := float(bodies.size_of(b))
	var lift := Vector2(0.0, -BUMP_LIFT)
	bodies.set_velocity(a, bodies.velocity_of(a) - direction * BUMP_SPEED * wb / (wa + wb) + lift)
	bodies.set_velocity(b, bodies.velocity_of(b) + direction * BUMP_SPEED * wa / (wa + wb) + lift)


## The dip nudge (see the class doc). Each train slime's distance is read
## once, and the touching partners are gathered once per tick, only when
## some slime is on a dip's floor: with ~150 slimes in view, asking the
## train and the bodies pair by pair cost most of the tick.
# @spec-link [[rule_dip_may_nudge_fusion]]
func _nudge(sim: Simulation) -> void:
	if not nudged.is_empty():
		nudged.clear()
	var train := sim.train
	if train == null:
		return
	var key := "%s|%s" % [train.loop.loop_id if train.loop != null else "", str(train.open_gates)]
	if key != _floors_for:
		_floors_for = key
		_floors = dip_floors(train.loop, train.open_gates)
	if _floors.is_empty():
		return
	var bodies := sim.slimes
	# The train slimes (in id order), their distances along the loop, which
	# of them are on screen, and which of those are on a dip's floor.
	var all: Array[int] = []
	var distances := PackedFloat64Array()
	var shown := PackedByteArray()
	var on_floor := PackedInt32Array()
	for slime_id in train.tracked_ids():
		if bodies.state_of(slime_id) != SlimeBodies.TRAIN:
			continue
		var distance := train.distance_of(slime_id)
		var visible := on_screen(sim.view, bodies.centre_of(slime_id))
		if visible and on_dip_floor(distance):
			on_floor.append(all.size())
		all.append(slime_id)
		distances.append(distance)
		shown.append(1 if visible else 0)
	if on_floor.is_empty():
		return
	var partners := _floor_partners(bodies, all, on_floor)
	for k in on_floor:
		var slime_id := all[k]
		var why := ""
		if _holding(bodies, partners, slime_id):
			why = NUDGE_HOLDING
		elif _gathering(sim, all, distances, shown, k):
			why = NUDGE_GATHERING
		if why != "":
			nudged[slime_id] = why
			bodies.set_hop_timer(slime_id, maxf(bodies.hop_timer_of(slime_id), DIP_HOLD_SECONDS))


## The touching pairs of `on_floor` (indices into `all`: the train slimes on
## screen and on a dip's floor), as id -> [ids it touches], both ways.
func _floor_partners(bodies: SlimeBodies, all: Array[int], on_floor: PackedInt32Array) -> Dictionary:
	var floor_ids := {}
	for k in on_floor:
		floor_ids[all[k]] = true
	var partners := {}
	for pair: Vector2i in bodies.touching_pairs():
		if floor_ids.has(pair.x) and floor_ids.has(pair.y):
			partners.get_or_add(pair.x, []).append(pair.y)
			partners.get_or_add(pair.y, []).append(pair.x)
	return partners


## Holding (the dip nudge): whether train slime `slime_id`, on screen on a
## dip's floor, touches a slime it may fuse with that is on screen on a
## dip's floor too (`partners`, from _floor_partners).
func _holding(bodies: SlimeBodies, partners: Dictionary, slime_id: int) -> bool:
	for other: int in partners.get(slime_id, []):
		if bodies.can_merge(slime_id, other):
			return true
	return false


## Gathering (the dip nudge): whether `all[k]` waits for a slime it may
## fuse with, on screen (`shown`) and less than DIP_GATHER px behind it
## along the loop (`distances`, of `all`): as long as it likes for the train
## slime directly behind it (among `all`, every train slime), and until it
## has not advanced for DIP_WAIT_TICKS for one with other slimes between
## them.
func _gathering(sim: Simulation, all: Array[int], distances: PackedFloat64Array, shown: PackedByteArray,
		k: int) -> bool:
	var train := sim.train
	var slime_id := all[k]
	var at := distances[k]
	var length := train.length()
	var next := -1
	var nearest := INF
	for j in all.size():
		var behind := fposmod(at - distances[j], length)
		if j != k and behind > 0.0 and behind < nearest:
			next = j
			nearest = behind
	if nearest >= DIP_GATHER:
		return false
	if shown[next] != 0 and sim.slimes.can_merge(slime_id, all[next]):
		return true
	var marked_at := train.marked_at_of(slime_id)
	if marked_at >= 0 and sim.tick - marked_at >= DIP_WAIT_TICKS:
		return false
	for j in all.size():
		if shown[j] == 0 or j == k:
			continue
		var behind := fposmod(at - distances[j], length)
		if behind > 0.0 and behind < DIP_GATHER and sim.slimes.can_merge(slime_id, all[j]):
			return true
	return false


## Whether the route from vertex `i`, followed in direction `step` (-1 or 1)
## over outgoing vertices, rises DIP_DEPTH px above it before going lower.
static func _rises(pts: PackedVector2Array, outgoing: PackedByteArray, i: int, step: int) -> bool:
	var bottom := pts[i].y
	var k := i + step
	while k >= 0 and k < pts.size() and outgoing[k] != 0:
		if pts[k].y > bottom:
			return false
		if bottom - pts[k].y >= DIP_DEPTH:
			return true
		k += step
	return false


## The distance where the floor around vertex `i` ends in direction `step`:
## where the route first rises DIP_FLOOR_RISE px above the vertex.
static func _floor_end(pts: PackedVector2Array, dist: PackedFloat64Array, i: int, step: int) -> float:
	var top := pts[i].y - DIP_FLOOR_RISE
	var k := i
	while k + step >= 0 and k + step < pts.size():
		var n := k + step
		if pts[n].y <= top:
			var t := (pts[k].y - top) / (pts[k].y - pts[n].y)
			return lerpf(dist[k], dist[n], t)
		k = n
	return dist[k]
