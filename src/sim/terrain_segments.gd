class_name TerrainSegments
extends RefCounted
## The static terrain the slime rings collide with, as plain data (O78,
## adopted default): every edge of the baked terrain outlines becomes a
## segment with its outward normal, and a uniform grid lists, for each cell,
## the segments within MARGIN of it. The simulation tests each ring point
## against the segments of the cell it is in, rather than using Godot physics
## bodies, so the solver stays in one place and can move to native code
## unchanged.
##
## Built once per level from closed polygons in level pixels (the Terrain
## component's baked outlines; src/slimes/slime_world.gd gathers them) and
## never changed afterwards, so several simulations can share one.
##
## A point is inside the terrain when it lies behind the nearest segment's
## outward normal. Only segments within MARGIN are searched, so a point that
## got deeper than MARGIN into the terrain is no longer seen. A ring point
## moves at most max_speed per substep (10 px at 1200 px/s, 2 substeps at
## 60 Hz), under MARGIN, and terrain pieces must be thicker than about
## 2 x MARGIN so a point can't come out the far side.

## The grid's cell size, in level pixels.
const CELL := 32.0
## How far from a segment a cell lists it: the deepest a point can be found.
const MARGIN := 16.0

## Per segment: its start and end, its direction (end - start), 1 / its
## squared length, and its outward unit normal.
var seg_a := PackedVector2Array()
var seg_b := PackedVector2Array()
var seg_d := PackedVector2Array()
var seg_inv_len2 := PackedFloat32Array()
var seg_n := PackedVector2Array()

## The grid: `origin` is the top-left corner of cell 0; cell (x, y) is
## y * grid_w + x. Cell c lists cell_items[cell_start[c] .. cell_start[c + 1]].
var origin := Vector2.ZERO
var inv_cell := 1.0 / CELL
var grid_w := 0
var grid_h := 0
var cell_start := PackedInt32Array()
var cell_items := PackedInt32Array()


## `polygons`: closed outlines (PackedVector2Array, the closing point not
## repeated), in either winding. The inside of each outline is solid.
func _init(polygons: Array = []) -> void:
	for polygon in polygons:
		_add_polygon(polygon)
	_build_grid()


func segment_count() -> int:
	return seg_a.size()


func is_empty() -> bool:
	return seg_a.is_empty()


## The nearest-surface answer for one point: {"hit": whether `point` is inside
## the terrain, "position": where it is pushed to (the nearest surface point,
## or `point` itself), "normal": the outward normal there (ZERO if no segment
## is near), "distance": from `point` to the nearest segment (INF if none)}.
func resolve(point: Vector2) -> Dictionary:
	var k := nearest_segment(point)
	if k < 0:
		return {"hit": false, "position": point, "normal": Vector2.ZERO, "distance": INF}
	var on := closest_on_segment(k, point)
	var inside := (point - on).dot(seg_n[k]) < 0.0
	return {"hit": inside, "position": on if inside else point, "normal": seg_n[k], "distance": point.distance_to(on)}


## How deep `point` is inside the terrain (0 outside, or deeper than MARGIN).
func depth(point: Vector2) -> float:
	var hit := resolve(point)
	return hit["distance"] if hit["hit"] else 0.0


## The index of the segment nearest `point` among those listed in its cell,
## or -1. Ties go to the segment listed first.
func nearest_segment(point: Vector2) -> int:
	var cell := cell_of(point)
	if cell < 0:
		return -1
	var best := -1
	var best_d2 := INF
	for q in range(cell_start[cell], cell_start[cell + 1]):
		var k := cell_items[q]
		var d2 := point.distance_squared_to(closest_on_segment(k, point))
		if d2 < best_d2:
			best_d2 = d2
			best = k
	return best


func closest_on_segment(k: int, point: Vector2) -> Vector2:
	var t := clampf((point - seg_a[k]).dot(seg_d[k]) * seg_inv_len2[k], 0.0, 1.0)
	return seg_a[k] + seg_d[k] * t


## The grid cell holding `point`, or -1 outside the grid.
func cell_of(point: Vector2) -> int:
	var cx := floori((point.x - origin.x) * inv_cell)
	var cy := floori((point.y - origin.y) * inv_cell)
	if cx < 0 or cy < 0 or cx >= grid_w or cy >= grid_h:
		return -1
	return cy * grid_w + cx


func _add_polygon(polygon: PackedVector2Array) -> void:
	var count := polygon.size()
	if count < 3:
		return
	# Shoelace sum: positive when the outline turns clockwise on screen
	# (y down), and then (d.y, -d.x) points out of the solid.
	var twice_area := 0.0
	for i in count:
		twice_area += polygon[i].cross(polygon[(i + 1) % count])
	var outward := 1.0 if twice_area > 0.0 else -1.0
	for i in count:
		var a := polygon[i]
		var d := polygon[(i + 1) % count] - a
		var len2 := d.length_squared()
		if len2 < 1e-8:
			continue
		seg_a.append(a)
		seg_b.append(a + d)
		seg_d.append(d)
		seg_inv_len2.append(1.0 / len2)
		seg_n.append(Vector2(d.y, -d.x).normalized() * outward)


func _build_grid() -> void:
	cell_start = PackedInt32Array([0])
	cell_items = PackedInt32Array()
	grid_w = 0
	grid_h = 0
	if is_empty():
		return
	var low := seg_a[0]
	var high := seg_a[0]
	for k in segment_count():
		for p in [seg_a[k], seg_b[k]]:
			low = low.min(p)
			high = high.max(p)
	origin = low - Vector2(MARGIN, MARGIN)
	grid_w = floori((high.x + MARGIN - origin.x) * inv_cell) + 1
	grid_h = floori((high.y + MARGIN - origin.y) * inv_cell) + 1
	# A cell lists a segment when the segment comes within MARGIN of some
	# point of the cell: within MARGIN + half the diagonal of its centre.
	var reach := MARGIN + CELL * sqrt(2.0) * 0.5
	var per_cell: Array[PackedInt32Array] = []
	per_cell.resize(grid_w * grid_h)
	for k in segment_count():
		var a := seg_a[k]
		var b := seg_b[k]
		var x0 := floori((minf(a.x, b.x) - MARGIN - origin.x) * inv_cell)
		var x1 := floori((maxf(a.x, b.x) + MARGIN - origin.x) * inv_cell)
		var y0 := floori((minf(a.y, b.y) - MARGIN - origin.y) * inv_cell)
		var y1 := floori((maxf(a.y, b.y) + MARGIN - origin.y) * inv_cell)
		for cy in range(maxi(y0, 0), mini(y1, grid_h - 1) + 1):
			for cx in range(maxi(x0, 0), mini(x1, grid_w - 1) + 1):
				var centre := origin + Vector2(cx + 0.5, cy + 0.5) * CELL
				if centre.distance_to(closest_on_segment(k, centre)) <= reach:
					per_cell[cy * grid_w + cx].append(k)
	cell_start.resize(grid_w * grid_h + 1)
	for c in per_cell.size():
		cell_items.append_array(per_cell[c])
		cell_start[c + 1] = cell_items.size()
