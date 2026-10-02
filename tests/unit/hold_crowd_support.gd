extends RefCounted
## Shared helpers for the hold tests (not a test script: no test_ prefix):
## the crowd the hold's tests set before a train slime, test_train_hold.gd,
## test_train_hold_corridor.gd, test_train_hold_period.gd and
## test_hold_counters.gd. Recalibrated in chunk 22f part 2, when
## TrainHold.HOLD_OCCUPANCY went from 0.5 to 0.7: a grid of base slimes that
## don't touch fills at most about 0.56 of a hop corridor.
##
## The world they share: a floor slab, its top at y = 0 (y 0 to SLAB), a base
## slime standing on it at y = STAND_Y. A crowd is free slimes held still
## (hop held; the tests don't steer free slimes), none touching another, so
## they neither fuse, slide nor rest, in rows: one row of base slimes on the
## floor, BASE_SPACING px apart, and rows of bigger slimes (big_size()) each
## on its own shelf, one under the slab and `above_rows` above the floor,
## big_spacing() px apart, as far along as the floor row. The big slimes are
## the biggest whose rows under the slab and just above the floor have their
## centres in a base floor slime's hop corridor (TrainHold.CORRIDOR_HALF_WIDTH
## either side of its centre), so the crowd fills the corridor as much as
## slimes that don't touch can. test_train_hold_corridor.gd checks that a
## base slime NEAR px before the crowd's first column sees it above
## TrainHold.HOLD_OCCUPANCY, so a new calibration the crowd can't reach fails
## there, loudly. The floor row is created last: removing the latest first
## thins a crowd a base slime at a time.

const STAND_Y := -(SlimeBodies.RING_RADIUS_SIZE_1 + SlimeBodies.EDGE)
const SLAB := 6.0
const SPECIES := 2
## The floor row's spacing: two base slimes (and their shelves) don't touch.
const BASE_SPACING := 46.0
## A base slime's shelf half-width; a big one's is its ring radius.
const BASE_SHELF_HALF_WIDTH := 22.0
const SHELF_THICKNESS := 4.0
## The room between a slime and the shelf or slab over it, px.
const GAP := 2.0
## How far inside the corridor's side a big row's centre stays, px (a
## standing slime's centre sags a little).
const SIDE_MARGIN := 2.0
## A train slime this far before a crowd's first column, px: the distance
## the hold tests use.
const NEAR := 60.0


## The size of a crowd's off-floor slimes (see the class doc).
static func big_size() -> int:
	var size := 1
	while _fits(size + 1):
		size += 1
	return size


## Whether rows of size `size` under the slab and just above the floor have
## their centres in a base floor slime's hop corridor, SIDE_MARGIN inside.
static func _fits(size: int) -> bool:
	var limit := TrainHold.CORRIDOR_HALF_WIDTH - SIDE_MARGIN
	return absf(_under_y(size) - STAND_Y) < limit and absf(_above_y(size, 1) - STAND_Y) < limit


## A standing slime's half-height for `size`: its ring radius plus the edge.
static func _half(size: int) -> float:
	return SlimeBodies.ring_radius_for(size) + SlimeBodies.EDGE


## The centre height of a row of size `size` under the slab: its top GAP px
## below the slab.
static func _under_y(size: int) -> float:
	return SLAB + GAP + _half(size)


## The centre height of above row `row` (1 the lowest) of size `size`, each
## row's shelf GAP px above the row below it, the lowest's above the floor
## row's base slimes.
static func _above_y(size: int, row: int) -> float:
	var shelf_top := -2.0 * _half(1) - GAP - SHELF_THICKNESS
	return shelf_top - _half(size) - (row - 1) * (2.0 * _half(size) + GAP + SHELF_THICKNESS)


## The big rows' spacing, px: their shelves (half-width the ring radius) and
## their slimes don't touch.
static func big_spacing() -> float:
	return ceilf(2.0 * _half(big_size()) + GAP)


## The centres of a crowd whose first column is at x = `from_x`, its columns
## going `way` (1 right, -1 left): `columns` base slimes on the floor and,
## as far along, big slimes under the slab and in `above_rows` rows above
## it; the floor row last (see the class doc).
static func spots(from_x: float, way: float, columns: int, above_rows: int) -> Array[Vector2]:
	var big := big_size()
	var big_columns := floori(BASE_SPACING * (columns - 1) / big_spacing()) + 1
	var rows: Array[float] = [_under_y(big)]
	for row in range(1, above_rows + 1):
		rows.append(_above_y(big, row))
	var out: Array[Vector2] = []
	for y in rows:
		for column in big_columns:
			out.append(Vector2(from_x + way * big_spacing() * column, y))
	for column in columns:
		out.append(Vector2(from_x + way * BASE_SPACING * column, STAND_Y))
	return out


## The size of the crowd slime at `at` (a spot of spots()): base on the
## floor, big off it.
static func size_at(at: Vector2) -> int:
	return 1 if at.y == STAND_Y else big_size()


## The x of the crowd's last floor column (spots()' arguments).
static func last_x(from_x: float, way: float, columns: int) -> float:
	return from_x + way * BASE_SPACING * (columns - 1)


## The shelf under a slime of `size` whose centre is at `at`.
static func shelf(at: Vector2, size: int) -> PackedVector2Array:
	var half_width := BASE_SHELF_HALF_WIDTH if size == 1 else SlimeBodies.ring_radius_for(size)
	var top := at.y + _half(size)
	return PackedVector2Array([Vector2(at.x - half_width, top), Vector2(at.x + half_width, top),
			Vector2(at.x + half_width, top + SHELF_THICKNESS), Vector2(at.x - half_width, top + SHELF_THICKNESS)])


## The world's polygons: the floor slab and a shelf under each crowd spot of
## `spots` off the floor.
static func polygons(spots: Array[Vector2]) -> Array:
	var out := [PackedVector2Array([Vector2(-2000, 0), Vector2(2000, 0), Vector2(2000, SLAB),
			Vector2(-2000, SLAB)])]
	for at in spots:
		if at.y != STAND_Y:
			out.append(shelf(at, size_at(at)))
	return out


## The world's terrain for a crowd at `spots` (polygons()).
static func terrain(spots: Array[Vector2]) -> TerrainSegments:
	return TerrainSegments.new(polygons(spots))


## Creates the crowd at `spots` in `bodies`: free slimes of SPECIES held still.
static func place(bodies: SlimeBodies, spots: Array[Vector2]) -> void:
	for at in spots:
		bodies.set_hop_held(bodies.create(SPECIES, size_at(at), at, SlimeBodies.FREE), true)


## Removes free slimes from the hop corridor from `from` to `target`, all but
## `except_id`, the latest first: until the occupancy is at or below
## TrainHold.HOLD_OCCUPANCY or, `crowded`, while one more removal would still
## leave it above (the fewest above it). Returns the occupancy left.
static func thin(bodies: SlimeBodies, from: Vector2, target: Vector2, except_id: int, crowded: bool) -> float:
	var ids: Array[int] = []
	bodies.corridor_scan(from, target, TrainHold.CORRIDOR_PAST, TrainHold.CORRIDOR_HALF_WIDTH, except_id, ids)
	ids.reverse()
	var box := TrainHold.corridor_area(from, target)
	var occupancy := TrainHold.occupancy_of(bodies, from, target, except_id)
	for other in ids:
		if bodies.state_of(other) != SlimeBodies.FREE:
			continue
		var share := PI * bodies.radius_of(other) ** 2 / box
		if occupancy <= TrainHold.HOLD_OCCUPANCY or (crowded and occupancy - share <= TrainHold.HOLD_OCCUPANCY):
			break
		bodies.remove(other)
		occupancy = TrainHold.occupancy_of(bodies, from, target, except_id)
	return occupancy
