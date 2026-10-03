extends RefCounted
## Room for the test level's stress fixtures, for tools/make_fixture.gd:
##   column_spots    room for size-1 slimes, column by column, found by
##                   scanning the terrain (chunk 16: the bowl's, _bowl_spots;
##                   moved here unchanged in chunk 22j);
##   dense_distances stress-dense's placement (chunk 22j, D153 (2), rebuilt
##                   2026-10-02 at the user's word): loop distances along
##                   the outgoing loop, DENSE_PER_BUCKET per loop bucket (the
##                   bucket cap less 25 %) and DENSE_BOTTOM_PER_BUCKET (the
##                   cap) in the two buckets at the bottom of section 3's bowl.
## Deterministic, no draw: the same level gives the same spots.
# @spec-link [[req_test_level_and_test_mode]]

## The columns' pitch and the stacked spots' pitch, px.
const SPOT_PITCH := 50.0
## stress-dense: slimes per loop bucket, the bucket cap's 4 per 100 px of
## loop (12 per 300 px bucket, D151) less 25 %; the two buckets at the
## bottom of the bowl hold the cap itself (the user's, 2026-10-02).
const DENSE_PER_BUCKET := 9
const DENSE_BOTTOM_PER_BUCKET := 12
## The step (px) of the walk along the loop that finds the bowl's bottom.
const WALK_STEP := 4.0
## How far (px) above the loop's lowest point in the bowl the loop still
## counts as the bowl's bottom (the flat floor).
const BOTTOM_TOLERANCE := 0.5


## Room for a size-1 slime in columns SPOT_PITCH px apart from `from_x` to
## `to_x`, each scanned from `top` down to `bottom`: each space between
## terrain pieces holds slimes stacked SPOT_PITCH px apart from its floor (a
## ledge's top, or the ground) up to its ceiling (the ledge above's
## underside). A piece the scan gets through within 40 px is a ledge;
## otherwise it is the ground, and the column ends. Column by column, left
## to right; in a column, space by space from the top, each space from its
## floor up.
static func column_spots(terrain: TerrainSegments, from_x: float, to_x: float, top: float, bottom: float) -> Array:
	var reach := SlimeBodies.ring_radius_for(1) + SlimeBodies.EDGE
	var spots := []
	var x := from_x
	while x <= to_x:
		var ceiling := top
		var y := top
		while y < bottom:
			if not terrain.resolve(Vector2(x, y))["hit"]:
				y += 2.0
				continue
			var centre := y - reach - 2.0
			while centre - reach >= ceiling + 2.0:
				if terrain.resolve(Vector2(x, centre))["distance"] >= reach + 1.0:
					spots.append(Vector2(x, centre))
				centre -= SPOT_PITCH
			var below := y
			var through := false
			while below < y + 40.0 and not through:
				below += 2.0
				var hit := terrain.resolve(Vector2(x, below))
				through = not hit["hit"] and hit["distance"] < 8.0
			if not through:
				break
			ceiling = below
			y = below + 2.0
		x += SPOT_PITCH
	return spots


## Sorts `spots` lowest first (the largest y first; on a tie, left first).
static func sort_lowest_first(spots: Array) -> void:
	spots.sort_custom(func(a: Vector2, b: Vector2): return a.y > b.y or (a.y == b.y and a.x < b.x))


## stress-dense's loop distances, `count` of them in fill order, for `sim`
## with gates 1 and 2 open (D153 (2), rebuilt 2026-10-02): each slime is
## to be put on the loop at its distance, as a train slime is spawned
## (Simulation.spawn_train_slime), so they lie along the loop line, not
## stacked. The loop is cut into loop buckets as the bucket cap cuts it
## (BucketLoads, the train's bucket length). The two buckets at the bottom
## of the bowl (bottom_buckets) take DENSE_BOTTOM_PER_BUCKET each, the
## lower first; then the buckets behind and ahead of them alternately,
## behind first, DENSE_PER_BUCKET each, until `count`. Only the outgoing
## loop before `stop_at` (a loop distance) is used: a bucket cut short by
## it takes DENSE_PER_BUCKET in proportion to what is left of it (rounded
## down), one cut to nothing ends the filling ahead; behind, the filling
## ends at the loop's start. In a bucket, its slimes are evenly spaced by
## loop distance over the part used (spacing = that length / its count),
## the first half a spacing in, so none is on a bucket's edge; the last
## bucket filled takes what is left, spread the same way. [] (and an
## error) when the room runs out first.
static func dense_distances(sim: Simulation, count: int, bowl_from: float, bowl_to: float,
		stop_at: float) -> Array:
	var length := sim.train.bucket_length
	var end := minf(stop_at, sim.train.outgoing_length())
	var bottom := bottom_buckets(sim, bowl_from, bowl_to)
	if bottom.is_empty():
		push_error("make_fixture: the outgoing loop doesn't run through x %.0f to %.0f" % [bowl_from, bowl_to])
		return []
	var out := []
	for b: int in bottom:
		_fill(out, b * length, minf((b + 1) * length, end), DENSE_BOTTOM_PER_BUCKET, count)
	var behind: int = bottom[0] - 1
	var ahead: int = bottom[1] + 1
	while out.size() < count and (behind >= 0 or ahead >= 0):
		if behind >= 0:
			_fill(out, behind * length, (behind + 1) * length, DENSE_PER_BUCKET, count)
			behind -= 1
		if ahead >= 0 and out.size() < count:
			var to := minf((ahead + 1) * length, end)
			if to <= ahead * length:
				ahead = -1
			else:
				var room := floori(DENSE_PER_BUCKET * (to - ahead * length) / length + BucketLoads.CAP_EPSILON)
				_fill(out, ahead * length, to, room, count)
				ahead += 1
	if out.size() < count:
		push_error("make_fixture: stress-dense has room for %d slimes, %d needed" % [out.size(), count])
		return []
	return out


## The two loop buckets at the bottom of section 3's bowl, lower index
## first: the one holding the middle of the bowl's bottom (the stretch of
## the outgoing loop, between where it first reaches x `bowl_from` and where
## it first passes `bowl_to`, within BOTTOM_TOLERANCE of its lowest point),
## and its neighbour on the side of the nearer edge. [] when the loop
## doesn't run through both.
static func bottom_buckets(sim: Simulation, bowl_from: float, bowl_to: float) -> Array:
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
	var length := sim.train.bucket_length
	var middle := (first + last) * 0.5
	var b := floori(middle / length)
	var other := b - 1 if middle - b * length < length * 0.5 else b + 1
	return [mini(b, other), maxi(b, other)]


## Appends to `out` up to `room` loop distances evenly spaced over [`from`,
## `to`), never past `count` in all.
static func _fill(out: Array, from: float, to: float, room: int, count: int) -> void:
	var n := mini(room, count - out.size())
	if n <= 0:
		return
	var spacing := (to - from) / n
	for i in n:
		out.append(from + (i + 0.5) * spacing)
