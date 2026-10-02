extends RefCounted
## Shared helpers for the slime body tests (not a test script: no test_
## prefix). Worlds are built from plain polygons, as the Terrain component
## bakes them.

## A flat floor whose top is at y = 0, from x = -2000 to 2000.
static func floor_polygon() -> PackedVector2Array:
	return PackedVector2Array([Vector2(-2000, 0), Vector2(2000, 0), Vector2(2000, 300), Vector2(-2000, 300)])


## A box with a floor at y = 0 and walls at x = -half_width and half_width.
static func box_polygons(half_width: float) -> Array:
	return [
		floor_polygon(),
		PackedVector2Array([Vector2(-half_width - 100, -1000), Vector2(-half_width, -1000),
				Vector2(-half_width, 10), Vector2(-half_width - 100, 10)]),
		PackedVector2Array([Vector2(half_width, -1000), Vector2(half_width + 100, -1000),
				Vector2(half_width + 100, 10), Vector2(half_width, 10)]),
	]


static func bodies_on_floor(master_seed := 1) -> SlimeBodies:
	var bodies := SlimeBodies.new(Rng.new(master_seed))
	bodies.terrain = TerrainSegments.new([floor_polygon()])
	return bodies


## Checks the packed arrays agree with each other: ranges contiguous and in
## order, no holes, ids ascending. Returns the problems found.
static func layout_problems(bodies: SlimeBodies) -> PackedStringArray:
	var problems := PackedStringArray()
	var next_first := 0
	for i in bodies.slime_count:
		if bodies.first[i] != next_first:
			problems.append("slime %d starts at %d, expected %d" % [i, bodies.first[i], next_first])
		var expected := SlimeBodies.detail_points_for(bodies.size[i], bodies.detail[i])
		if bodies.npts[i] != expected:
			problems.append("slime %d has %d points for size %d" % [i, bodies.npts[i], bodies.size[i]])
		if i > 0 and bodies.id[i] <= bodies.id[i - 1]:
			problems.append("ids not ascending at %d" % i)
		next_first += bodies.npts[i]
	if bodies.pos.size() != next_first or bodies.prev.size() != next_first or bodies.rest_off.size() != next_first:
		problems.append("point arrays hold %d/%d/%d points, the ranges %d"
				% [bodies.pos.size(), bodies.prev.size(), bodies.rest_off.size(), next_first])
	for array_name in ["id", "first", "npts", "size", "species", "state", "ring_radius", "rest_area",
			"centre", "hop_timer", "heading", "calm", "detail", "still_ticks", "may_rest", "on_ground"]:
		if bodies.get(array_name).size() != bodies.slime_count:
			problems.append("%s has %d entries for %d slimes" % [array_name, bodies.get(array_name).size(), bodies.slime_count])
	return problems


static func max_speed(bodies: SlimeBodies) -> float:
	var top := 0.0
	for slime_id in bodies.ids():
		top = maxf(top, bodies.velocity_of(slime_id).length())
	return top
