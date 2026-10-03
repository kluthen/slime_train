extends RefCounted
## stress-dense's placement, for tools/make_fixture.gd (chunk 22m, D153 as
## amended by D154): loop distances along the outgoing loop (gates 1 and 2
## open), which is cut into STRETCH px stretches counted from the loop's
## start (a slime's stretch is its distance divided by STRETCH, rounded
## down; a builder constant, no game code). PER_STRETCH slimes in each
## stretch (3 per 100 px), BOTTOM_PER_STRETCH (4 per 100 px) in the two
## stretches at the bottom of section 3's bowl.
## Deterministic, no draw: the same level gives the same distances.
# @spec-link [[req_test_level_and_test_mode]]
# @spec-link [[req_platform_and_performance_targets]]

## The length of a stretch of loop, px (D154 (1)).
const STRETCH := 300.0
## Slimes per stretch: 3 per 100 px of loop; the two stretches at the bottom
## of the bowl, 4 per 100 px (the user's, 2026-10-02).
const PER_STRETCH := 9
const BOTTOM_PER_STRETCH := 12
## The step (px) of the walk along the loop that finds the bowl's bottom.
const WALK_STEP := 4.0
## How far (px) above the loop's lowest point in the bowl the loop still
## counts as the bowl's bottom (the flat floor).
const BOTTOM_TOLERANCE := 0.5
## Added before rounding a short stretch's share down, so that a share that
## is a whole number in exact arithmetic isn't rounded one below it.
const ROUNDING_EPSILON := 1e-6


## The stretch of loop distance `distance` (px from the loop's start) is in.
static func stretch_of(distance: float) -> int:
	return floori(distance / STRETCH)


## stress-dense's loop distances, `count` of them in fill order, for `sim`
## with gates 1 and 2 open (D154 (1), (2)): each slime is to be put on the
## loop at its distance, as a train slime is spawned
## (Simulation.spawn_train_slime), so they lie along the loop line, not
## stacked. The two stretches at the bottom of the bowl (bottom_stretches)
## take BOTTOM_PER_STRETCH each, the lower first; then the stretches behind
## and ahead of them alternately, behind first, PER_STRETCH each, until
## `count`. Only the outgoing loop before `stop_at` (a loop distance) is
## used: a stretch cut short by it takes PER_STRETCH in proportion to what
## is left of it (rounded down), one cut to nothing ends the filling ahead;
## behind, the filling ends at the loop's start. In a stretch, its slimes
## are evenly spaced by loop distance over the part used (spacing = that
## length / its count), the first half a spacing in, so none is on a
## stretch's edge; the last stretch filled takes what is left, spread the
## same way. [] (and an error) when the room runs out first.
static func dense_distances(sim: Simulation, count: int, bowl_from: float, bowl_to: float,
		stop_at: float) -> Array:
	var end := minf(stop_at, sim.train.outgoing_length())
	var bottom := bottom_stretches(sim, bowl_from, bowl_to)
	if bottom.is_empty():
		push_error("make_fixture: the outgoing loop doesn't run through x %.0f to %.0f" % [bowl_from, bowl_to])
		return []
	var out := []
	for b: int in bottom:
		_fill(out, b * STRETCH, minf((b + 1) * STRETCH, end), BOTTOM_PER_STRETCH, count)
	var behind: int = bottom[0] - 1
	var ahead: int = bottom[1] + 1
	while out.size() < count and (behind >= 0 or ahead >= 0):
		if behind >= 0:
			_fill(out, behind * STRETCH, (behind + 1) * STRETCH, PER_STRETCH, count)
			behind -= 1
		if ahead >= 0 and out.size() < count:
			var to := minf((ahead + 1) * STRETCH, end)
			if to <= ahead * STRETCH:
				ahead = -1
			else:
				var room := floori(PER_STRETCH * (to - ahead * STRETCH) / STRETCH + ROUNDING_EPSILON)
				_fill(out, ahead * STRETCH, to, room, count)
				ahead += 1
	if out.size() < count:
		push_error("make_fixture: stress-dense has room for %d slimes, %d needed" % [out.size(), count])
		return []
	return out


## The two stretches at the bottom of section 3's bowl, lower index first:
## the one holding the middle of the bowl's bottom (the part of the outgoing
## loop, between where it first reaches x `bowl_from` and where it first
## passes `bowl_to`, within BOTTOM_TOLERANCE of its lowest point), and its
## neighbour on the side of the nearer edge. [] when the loop doesn't run
## through both.
static func bottom_stretches(sim: Simulation, bowl_from: float, bowl_to: float) -> Array:
	var lowest := -INF
	var first := -1.0
	var last := -1.0
	var distance := 0.0
	var inside := false
	while distance < sim.train.outgoing_length():
		var at := sim.train.position_at(distance)
		if not inside and at.x >= bowl_from:
			inside = true
		elif inside and at.x > bowl_to:
			break
		if inside:
			if at.y > lowest + BOTTOM_TOLERANCE:
				lowest = at.y
				first = distance
			if at.y >= lowest - BOTTOM_TOLERANCE:
				last = distance
		distance += WALK_STEP
	if first < 0.0 or distance >= sim.train.outgoing_length():
		return []
	var middle := (first + last) * 0.5
	var b := stretch_of(middle)
	var other := b - 1 if middle - b * STRETCH < STRETCH * 0.5 else b + 1
	return [mini(b, other), maxi(b, other)]


## How many of `distances` each stretch holds: stretch -> count, the
## stretches in ascending order.
static func stretch_counts(distances: Array) -> Dictionary:
	var counts := {}
	for d: float in distances:
		var b := stretch_of(d)
		counts[b] = counts.get(b, 0) + 1
	var out := {}
	var keys := counts.keys()
	keys.sort()
	for b in keys:
		out[b] = counts[b]
	return out


## Appends to `out` up to `room` loop distances evenly spaced over [`from`,
## `to`), never past `count` in all.
static func _fill(out: Array, from: float, to: float, room: int, count: int) -> void:
	var n := mini(room, count - out.size())
	if n <= 0:
		return
	var spacing := (to - from) / n
	for i in n:
		out.append(from + (i + 0.5) * spacing)
