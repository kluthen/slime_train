class_name SlimeDetail
extends RefCounted
## Calm, rest and detail: the parts of SlimeBodies that decide which slimes
## simulate (park, unpark, the resting-pile rule) and how many points each
## ring has (its detail level, the ring rebuilds), as static functions over a
## SlimeBodies' packed arrays. The rules are in SlimeBodies' class doc
## ("Calm" and "Detail"). SlimeBodies owns every array and keeps its
## interface: its calm and detail functions (crowd_count, park, unpark,
## wake_resting_in, set_detail, set_active_detail), its rest pass
## (_rest) and its ring rebuilds (_resample, _reshape) call these. The one
## wake every path goes through, SlimeBodies._wake_at, stays in SlimeBodies,
## and these call it.
##
## The rest pass mirrors its native port (native/slime_native/src/
## solver_rest.cpp) bit for bit, and a resampled ring's rest ring is bit for
## bit a fresh one's: the same float operations in the same order as when
## they were SlimeBodies' own.
##
## As in SlimeSolverGD: each function reads the arrays it needs into locals
## once, at its start. A packed array read into a local shares the member's
## buffer, so the writes reach the bodies. A function that replaces a
## member's buffer (resample, reshape: the point slices) assigns the member
## itself. `b`, the bodies, is untyped: the native schema test compiles a
## renamed copy of slime_bodies.gd (tests/unit/test_native_solver.gd). So
## every local is typed by hand.


## How many slimes cost physics on a tick: calm ACTIVE and not sleepers
## (resting and parked slimes, and sleepers, are never integrated).
# @spec-link [[req_offscreen_simulation]]
static func crowd_count(b) -> int:
	var calm: PackedByteArray = b.calm
	var state: PackedInt32Array = b.state
	var slime_count: int = b.slime_count
	var count := 0
	for s in slime_count:
		if calm[s] == SlimeBodies.ACTIVE and state[s] != SlimeBodies.STATE_SLEEPER:
			count += 1
	return count


## Parks slime index `s`, not parked (SlimeBodies.park checks it): from now
## on it is neither simulated nor touched, not even as a wall, until
## unpark(). Its velocity is dropped.
# @spec-link [[req_offscreen_simulation]]
static func park(b, s: int) -> void:
	var calm: PackedByteArray = b.calm
	calm[s] = SlimeBodies.PARKED
	var still_ticks: PackedInt32Array = b.still_ticks
	still_ticks[s] = 0
	b._set_velocity_at(s, Vector2.ZERO)
	var drift: PackedVector2Array = b._drift
	drift[s] = Vector2.ZERO


## Simulates parked slime index `s` again (SlimeBodies.unpark checks it),
## at rest where it was put.
static func unpark(b, s: int) -> void:
	var calm: PackedByteArray = b.calm
	calm[s] = SlimeBodies.ACTIVE
	var still_ticks: PackedInt32Array = b.still_ticks
	still_ticks[s] = 0
	b._set_velocity_at(s, Vector2.ZERO)


## Wakes every resting slime whose centre is in `box`. Returns how many.
# @spec-link [[req_offscreen_simulation]]
static func wake_resting_in(b, box: Rect2) -> int:
	var calm: PackedByteArray = b.calm
	var centre: PackedVector2Array = b.centre
	var slime_count: int = b.slime_count
	var woken := 0
	for s in slime_count:
		if calm[s] == SlimeBodies.RESTING and box.has_point(centre[s]):
			woken += b._wake_at(s)
	return woken


## Gives slime `slime_id`'s ring the point count of detail `level` (0 to
## MAX_DETAIL), read off its current shape (resample), whatever its calm.
## False when nothing changed.
# @spec-link [[req_offscreen_simulation]]
static func set_detail(b, slime_id: int, level: int) -> bool:
	assert(level >= 0 and level <= SlimeBodies.MAX_DETAIL, "SlimeBodies: invalid detail level %d" % level)
	var s: int = b.index_of(slime_id)
	var detail: PackedByteArray = b.detail
	if s < 0 or detail[s] == level:
		return false
	detail[s] = level
	resample(b, s, detail_points(b, s, b.size[s]))
	return true


## set_detail(`level`) on every calm ACTIVE slime, by index: ascending, like
## ids(), so the same state as one call per id (Offscreen, every tick); a
## pile slime takes PILE_MAX_DETAIL at most. Resting and parked slimes keep
## their rings (a reshape would wake a resting pile); they take the level
## once ACTIVE again, on the next call. Returns how many rings changed.
# @spec-link [[req_offscreen_simulation]]
static func set_active_detail(b, level: int) -> int:
	assert(level >= 0 and level <= SlimeBodies.MAX_DETAIL, "SlimeBodies: invalid detail level %d" % level)
	var detail: PackedByteArray = b.detail
	var slime_count: int = b.slime_count
	# Often every ring already has it: one native count, no loop.
	if level <= SlimeBodies.PILE_MAX_DETAIL and detail.count(level) == slime_count:
		return 0
	var calm: PackedByteArray = b.calm
	var state: PackedInt32Array = b.state
	var size: PackedInt32Array = b.size
	var pile_level := mini(level, SlimeBodies.PILE_MAX_DETAIL)
	var changed := 0
	for s in slime_count:
		if calm[s] != SlimeBodies.ACTIVE:
			continue
		var wanted := pile_level if can_rest(state[s]) else level
		if detail[s] != wanted:
			detail[s] = wanted
			resample(b, s, detail_points(b, s, size[s]))
			changed += 1
	return changed


## Whether a slime in `slime_state` may rest: the pile states, which never
## hop (a slime in a basket, or asleep at bedtime). SlimeBodies._can_rest.
static func can_rest(slime_state: int) -> bool:
	return slime_state == SlimeBodies.STATE_IN_BASKET or slime_state == SlimeBodies.STATE_BEDTIME_ASLEEP


## The resting-pile rule (see SlimeBodies' class doc), after the tick, the
## GDScript one (SlimeBodies._rest). A resting slime touching a slime moving
## faster than WAKE_SPEED wakes, only it: the rest of its pile rests on (the
## local wake, D156). Each active pile slime counts its still, supported
## ticks; a group of touching active pile slimes whose every member has
## counted REST_TICKS rests together. Piles rest whole (a half-resting group
## would make its moving half take every overlap against the wall, jolt, and
## wake it again); they wake locally (D156; D96 woke them whole).
# @spec-link [[req_offscreen_simulation]]
static func rest(b) -> void:
	var slime_count: int = b.slime_count
	if not b.rest_enabled:
		for s in slime_count:
			b._wake_at(s)
		return
	var h: float = b._h
	var drift2: float = SlimeBodies.REST_DRIFT * SlimeBodies.REST_DRIFT
	var fast2: float = SlimeBodies.WAKE_SPEED * h * SlimeBodies.WAKE_SPEED * h
	var pair_touch: PackedByteArray = b._pair_touch
	var pairs: PackedInt32Array = b._pairs
	var calm: PackedByteArray = b.calm
	var state: PackedInt32Array = b.state
	var drift: PackedVector2Array = b._drift
	for k in pair_touch.size():
		if pair_touch[k] == 0:
			continue
		var a: int = pairs[2 * k]
		var c: int = pairs[2 * k + 1]
		if calm[a] == SlimeBodies.RESTING and calm[c] == SlimeBodies.ACTIVE and state[c] != SlimeBodies.STATE_SLEEPER:
			if drift[c].length_squared() > fast2:
				b._wake_at(a)
		elif calm[c] == SlimeBodies.RESTING and calm[a] == SlimeBodies.ACTIVE and state[a] != SlimeBodies.STATE_SLEEPER:
			if drift[a].length_squared() > fast2:
				b._wake_at(c)
	var supported: PackedInt32Array = b.supported
	var centre: PackedVector2Array = b.centre
	var rest_anchor: PackedVector2Array = b.rest_anchor
	var still_ticks: PackedInt32Array = b.still_ticks
	var ready := false
	for s in slime_count:
		if calm[s] != SlimeBodies.ACTIVE or not can_rest(state[s]):
			continue
		if supported[s] == 0 or centre[s].distance_squared_to(rest_anchor[s]) > drift2:
			still_ticks[s] = 0
			rest_anchor[s] = centre[s]
			continue
		still_ticks[s] = mini(still_ticks[s] + 1, SlimeBodies.REST_TICKS)
		ready = ready or still_ticks[s] == SlimeBodies.REST_TICKS
	if ready:
		rest_piles(b)


## Rests every group of touching active pile slimes whose members have all
## been still for REST_TICKS (union-find over the touching pairs).
static func rest_piles(b) -> void:
	var slime_count: int = b.slime_count
	var pair_touch: PackedByteArray = b._pair_touch
	var pairs: PackedInt32Array = b._pairs
	var calm: PackedByteArray = b.calm
	var state: PackedInt32Array = b.state
	var root := PackedInt32Array()
	root.resize(slime_count)
	for s in slime_count:
		root[s] = s
	for k in pair_touch.size():
		if pair_touch[k] == 0:
			continue
		var a: int = pairs[2 * k]
		var c: int = pairs[2 * k + 1]
		if calm[a] != SlimeBodies.ACTIVE or calm[c] != SlimeBodies.ACTIVE or not can_rest(state[a]) or not can_rest(state[c]):
			continue
		var ra := _find(root, a)
		var rc := _find(root, c)
		if ra != rc:
			root[maxi(ra, rc)] = mini(ra, rc)
	# A group rests when none of its members is short of REST_TICKS.
	var still_ticks: PackedInt32Array = b.still_ticks
	var short := PackedByteArray()
	short.resize(slime_count)
	for s in slime_count:
		if calm[s] == SlimeBodies.ACTIVE and can_rest(state[s]) and still_ticks[s] < SlimeBodies.REST_TICKS:
			short[_find(root, s)] = 1
	var pile: PackedInt32Array = b.pile
	var id: PackedInt32Array = b.id
	var drift: PackedVector2Array = b._drift
	for s in slime_count:
		if calm[s] != SlimeBodies.ACTIVE or not can_rest(state[s]):
			continue
		var r := _find(root, s)
		if short[r] != 0:
			continue
		calm[s] = SlimeBodies.RESTING
		still_ticks[s] = 0
		pile[s] = id[r]
		b._set_velocity_at(s, Vector2.ZERO)
		drift[s] = Vector2.ZERO


## The root of index `s` in the union-find `root`, halving the path on the
## way (rest_piles).
static func _find(root: PackedInt32Array, s: int) -> int:
	while root[s] != s:
		root[s] = root[root[s]]
		s = root[s]
	return s


## The ring point count of slime index `s` at `slime_size`, at its detail.
static func detail_points(b, s: int, slime_size: int) -> int:
	return SlimeBodies.POINTS_BY_DETAIL[b.detail[s]][slime_size]


## Point `k`'s offset on a rest ring of `n` points and radius `r`: point 0
## at the bottom. reshape and resample share it, so a ring resampled on
## loading a save (SlimeBodies.set_body) is bit for bit the one made fresh.
static func rest_offset(k: int, n: int, r: float) -> Vector2:
	var a := TAU * k / n + PI * 0.5
	return Vector2(cos(a), sin(a)) * r


## Gives slime index `s` a ring of `n` points read off its current shape: the
## new points sit at even angles from its point 0's, each at the radius of
## the current ring there (its radial profile), all moving at the slime's
## mean velocity; the rest ring, area and edge are the regular `n`-gon's.
## Its slice changes size like in reshape.
static func resample(b, s: int, n: int) -> void:
	var first: PackedInt32Array = b.first
	var npts: PackedInt32Array = b.npts
	var pos: PackedVector2Array = b.pos
	var f: int = first[s]
	var old: int = npts[s]
	var c: Vector2 = b._centre_at(s)
	var velocity: Vector2 = b._velocity_at(s)
	var a0 := (pos[f] - c).angle()
	# Not ring_radius[s] (32-bit): the radius reshape uses, so the rest ring
	# and area are bit for bit a fresh ring's (a reloaded save resamples).
	var r: float = SlimeBodies.ring_radius_for(b.size[s])
	var ring := PackedVector2Array()
	var back := PackedVector2Array()
	var offs := PackedVector2Array()
	ring.resize(n)
	back.resize(n)
	offs.resize(n)
	var step: Vector2 = velocity * b._h
	for k in n:
		var t := float(k) * old / n
		var i := int(t)
		var fr := t - i
		var r0 := (pos[f + i] - c).length()
		var r1 := (pos[f + (i + 1) % old] - c).length()
		var a := a0 + TAU * k / n
		ring[k] = c + Vector2.from_angle(a) * (r0 + (r1 - r0) * fr)
		back[k] = ring[k] - step
		offs[k] = rest_offset(k, n, r)
	_replace_slice(b, s, f, old, ring, back, offs)
	var rest_area: PackedFloat32Array = b.rest_area
	var rest_edge: PackedFloat32Array = b.rest_edge
	var centre: PackedVector2Array = b.centre
	rest_area[s] = SlimeBodies._polygon_area(n, r)
	rest_edge[s] = 2.0 * r * sin(PI / n)
	centre[s] = c
	b._wake_at(s)
	b.topology_version += 1


## Gives slime index `s` a fresh rest ring of `slime_size` centred at `at`,
## moving at `velocity`, replacing its point slice (the later slimes' slices
## move to stay back to back).
static func reshape(b, s: int, slime_size: int, at: Vector2, velocity: Vector2) -> void:
	var n := detail_points(b, s, slime_size)
	var r: float = SlimeBodies.ring_radius_for(slime_size)
	b._wake_at(s)
	var ring := PackedVector2Array()
	var offs := PackedVector2Array()
	ring.resize(n)
	offs.resize(n)
	for k in n:
		# Point 0 at the bottom: the ring is mirror-symmetric about the
		# vertical and stands on a point (its stable resting pose), whatever
		# the point count, so a resting slime doesn't roll.
		var off := rest_offset(k, n, r)
		offs[k] = off
		ring[k] = at + off
	var step: Vector2 = velocity * b._h
	var back := PackedVector2Array()
	back.resize(n)
	for k in n:
		back[k] = ring[k] - step
	var f: int = b.first[s]
	var old: int = b.npts[s]
	_replace_slice(b, s, f, old, ring, back, offs)
	var size: PackedInt32Array = b.size
	var ring_radius: PackedFloat32Array = b.ring_radius
	var rest_area: PackedFloat32Array = b.rest_area
	var rest_edge: PackedFloat32Array = b.rest_edge
	var bound_r: PackedFloat32Array = b.bound_r
	var centre: PackedVector2Array = b.centre
	var angle0: PackedFloat32Array = b.angle0
	size[s] = slime_size
	ring_radius[s] = r
	rest_area[s] = SlimeBodies._polygon_area(n, r)
	rest_edge[s] = 2.0 * r * sin(PI / n)
	bound_r[s] = r * 1.3
	centre[s] = at
	angle0[s] = 0.0
	b.topology_version += 1


## Replaces slime index `s`'s point slice (`old` points from `f`) with the
## new `ring`, `back` (prev) and `offs` (rest_off), shifts the later slimes'
## slices to stay back to back, and sets its point count; its cached centre
## is stale from then (resample, reshape).
static func _replace_slice(b, s: int, f: int, old: int, ring: PackedVector2Array,
		back: PackedVector2Array, offs: PackedVector2Array) -> void:
	var pos: PackedVector2Array = b.pos
	var prev: PackedVector2Array = b.prev
	var rest_off: PackedVector2Array = b.rest_off
	b.pos = pos.slice(0, f) + ring + pos.slice(f + old)
	b.prev = prev.slice(0, f) + back + prev.slice(f + old)
	b.rest_off = rest_off.slice(0, f) + offs + rest_off.slice(f + old)
	var centre_ok: PackedByteArray = b._centre_ok
	centre_ok[s] = 0
	var first: PackedInt32Array = b.first
	var n := ring.size()
	for t in range(s + 1, b.slime_count):
		first[t] += n - old
	var npts: PackedInt32Array = b.npts
	npts[s] = n
