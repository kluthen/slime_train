extends RefCounted
## Room for the test level's stress fixtures, for tools/make_fixture.gd:
##   column_spots  room for size-1 slimes, column by column, found by
##                 scanning the terrain (chunk 16: the bowl's, _bowl_spots;
##                 moved here unchanged in chunk 22j);
##   dense_spots   stress-dense's placement (chunk 22j, D153 (2)): the dense
##                 case the rules allow plus 50 %, DENSE_PER_BUCKET of
##                 weight per loop bucket, centred on section 3's bowl.
## Deterministic, no draw: the same level gives the same spots.
# @spec-link [[req_test_level_and_test_mode]]

## The columns' pitch and the stacked spots' pitch, px.
const SPOT_PITCH := 50.0
## stress-dense: slimes per loop bucket, the bucket cap's 4 per 100 px of
## loop (12 per 300 px bucket, D151) plus 50 % (D153).
const DENSE_PER_BUCKET := 18
## stress-dense's candidate spots: columns from DENSE_FROM to DENSE_TO
## (wider than the bowl, x 13.5 to 15.33 screens: about two screens behind
## it, and up to switch 3), scanned from SCAN_TOP down to SCAN_BOTTOM (the
## bowl's scan).
const DENSE_FROM := 12.0 * LevelData.SCREEN
const DENSE_TO := 15.75 * LevelData.SCREEN
const SCAN_TOP := -560.0
const SCAN_BOTTOM := 200.0
## The step (px) of the walk along the loop that finds its stretch through
## the bowl.
const WALK_STEP := 4.0


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


## stress-dense's spots, `count` of them in fill order, for `sim` with
## gates 1 and 2 open (D153 (2)). The candidates are column_spots from
## DENSE_FROM to DENSE_TO whose nearest point of the loop in use is on its
## outgoing part, not below that point by more than a slime's reach (so none
## in a basket's pit, under a slide's lid or in a return route's tunnel) and
## before `stop` (a level point: none at or past it along the loop). Each
## belongs to the loop bucket of its nearest loop distance, cut as the
## bucket cap cuts the loop (BucketLoads, the train's bucket length). The
## centre bucket (the one holding the middle of the loop's stretch through
## x `bowl_from` to `bowl_to`) takes its DENSE_PER_BUCKET lowest spots, then
## the buckets behind and ahead alternately, behind first, as many each; a
## bucket short of spots takes what it has. [] (and an error) when the
## candidates run out first.
static func dense_spots(sim: Simulation, terrain: TerrainSegments, count: int, bowl_from: float,
		bowl_to: float, stop: Vector2) -> Array:
	var loop := sim.level.loop
	var gates := sim.train.open_gates
	var buckets := BucketLoads.new()
	buckets.configure(sim.train.length(), sim.train.bucket_length, BucketLoads.DEFAULT_DENSITY, 0)
	var stop_at: float = loop.closest(stop, gates)["distance"]
	var reach := SlimeBodies.ring_radius_for(1) + SlimeBodies.EDGE
	var by_bucket := {}
	for at: Vector2 in column_spots(terrain, DENSE_FROM, DENSE_TO, SCAN_TOP, SCAN_BOTTOM):
		var nearest := loop.closest(at, gates)
		if loop.segment(nearest["segment"])["kind"] != LoopData.OUTGOING:
			continue
		if at.y > (nearest["position"] as Vector2).y + reach or nearest["distance"] >= stop_at:
			continue
		var b := buckets.bucket_index(nearest["distance"])
		if not by_bucket.has(b):
			by_bucket[b] = []
		by_bucket[b].append(at)
	var middle := _middle_through(sim, bowl_from, bowl_to)
	if middle < 0.0:
		push_error("make_fixture: the outgoing loop doesn't run through x %.0f to %.0f" % [bowl_from, bowl_to])
		return []
	var centre := buckets.bucket_index(middle)
	var out := []
	var step := 0
	while out.size() < count and step < buckets.count():
		for b in ([centre] if step == 0 else [centre - step, centre + step]):
			var room: Array = by_bucket.get(b, [])
			sort_lowest_first(room)
			out.append_array(room.slice(0, mini(DENSE_PER_BUCKET, count - out.size())))
		step += 1
	if out.size() < count:
		push_error("make_fixture: stress-dense has room for %d slimes, %d needed" % [out.size(), count])
		return []
	return out


## The loop distance halfway along the stretch of the outgoing loop in use
## from where it first reaches x `from_x` to where it first passes `to_x`;
## -1 when it doesn't run through both.
static func _middle_through(sim: Simulation, from_x: float, to_x: float) -> float:
	var enter := -1.0
	var distance := 0.0
	while distance < sim.train.outgoing_length():
		var x := sim.train.position_at(distance).x
		if enter < 0.0 and x >= from_x:
			enter = distance
		elif enter >= 0.0 and x > to_x:
			return (enter + distance) * 0.5
		distance += WALK_STEP
	return -1.0
