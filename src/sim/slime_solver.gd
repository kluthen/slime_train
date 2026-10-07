class_name SlimeSolverGD
extends RefCounted
## The GDScript solver: the passes of SlimeBodies' tick that move the ring
## points (integrate, the pair grid, the slime contacts, the rings, the
## terrain and the doors), as static functions over a SlimeBodies' packed
## arrays. SlimeBodies owns every array and calls these through its own
## pass functions (_integrate, _build_pairs, _solve_contacts, _solve_rings,
## _solve_terrain), one pass at a time, whenever the native solver (the
## extension's SlimeSolver, docs/dev/native.md) doesn't run that pass.
##
## Each pass mirrors its native port (native/slime_native/src/solver_*.cpp)
## bit for bit: the same float operations in the same order, so both ticks
## give the same state hashes. The native equivalence tests
## (tests/unit/test_native_*.gd) pin every pass against its port.
##
## Each pass reads the arrays it needs into locals once, at its start. A
## packed array read into a local shares the member's buffer, so the writes
## reach the bodies. Never keep one across passes: a native pass replaces
## the members' buffers (see "The marshalling" in docs/dev/native.md).
##
## `b`, the bodies, is untyped: whatever script holds SlimeBodies' fields
## will do, as the native schema test's copy of slime_bodies.gd with a field
## renamed (tests/unit/test_native_solver.gd). So every local is typed by
## hand.


## Verlet step: gravity (SlimeBodies.gravity_for the slime's state), air
## drag, and internal damping (each point's velocity pulled toward its
## slime's mean). Also refreshes each slime's centre and point-0 angle.
static func integrate(b, h: float) -> void:
	var p: PackedVector2Array = b.pos
	var o: PackedVector2Array = b.prev
	var first: PackedInt32Array = b.first
	var npts: PackedInt32Array = b.npts
	var state: PackedInt32Array = b.state
	var calm: PackedByteArray = b.calm
	var centre: PackedVector2Array = b.centre
	var angle0: PackedFloat32Array = b.angle0
	var drift: PackedVector2Array = b._drift
	var g: Vector2 = b.gravity * h * h
	var g_free: Vector2 = b.gravity_for(SlimeBodies.STATE_FREE) * h * h
	var ms: float = b.max_speed * h
	var idamp: float = b.internal_damping
	var damp: float = 1.0 - b.air_drag * h
	var slime_count: int = b.slime_count
	for s in slime_count:
		var f: int = first[s]
		var cnt: int = npts[s]
		var end: int = f + cnt
		if state[s] == SlimeBodies.STATE_SLEEPER or calm[s] != SlimeBodies.ACTIVE:
			# Asleep, resting or parked: it doesn't simulate (its points stay
			# put), but its point-0 angle is kept right for the contacts.
			var r_sleep: Vector2 = p[f] - centre[s]
			angle0[s] = atan2(r_sleep.y, r_sleep.x)
			drift[s] = Vector2.ZERO
			continue
		var gs: Vector2 = g_free if state[s] == SlimeBodies.STATE_FREE else g
		var mean := Vector2.ZERO
		for i in range(f, end):
			mean += p[i] - o[i]
		mean /= cnt
		var c := Vector2.ZERO
		for i in range(f, end):
			var cur: Vector2 = p[i]
			var v: Vector2 = cur - o[i]
			v = ((v + (mean - v) * idamp) * damp).limit_length(ms) + gs
			o[i] = cur
			var nxt := cur + v
			p[i] = nxt
			c += nxt
		c /= cnt
		drift[s] = c - centre[s]
		centre[s] = c
		var r0: Vector2 = p[f] - c
		angle0[s] = atan2(r0.y, r0.x)


## Counting sort of the slimes into a uniform grid on their centres, then the
## list of candidate pairs (index a < index b). Cells are at least as wide as
## the widest possible pair distance, so neighbouring cells are enough.
static func build_pairs(b) -> void:
	var pairs: PackedInt32Array = b._pairs
	var centre: PackedVector2Array = b.centre
	var calm: PackedByteArray = b.calm
	var state: PackedInt32Array = b.state
	var bound_r: PackedFloat32Array = b.bound_r
	var slime_cell: PackedInt32Array = b._slime_cell
	var slime_count: int = b.slime_count
	pairs.clear()
	# Parked slimes are left out of the grid (they touch nothing).
	var placed := 0
	var low := Vector2.INF
	var high := -Vector2.INF
	# The highest index of a slime in the grid that isn't a wall (-1: none).
	var last_mover := -1
	for s in slime_count:
		if calm[s] == SlimeBodies.PARKED:
			continue
		placed += 1
		low = low.min(centre[s])
		high = high.max(centre[s])
		# Not SlimeBodies._is_wall(s), inlined (calm is ACTIVE or RESTING here).
		if state[s] != SlimeBodies.STATE_SLEEPER and calm[s] == SlimeBodies.ACTIVE:
			last_mover = s
	if placed < 2:
		b._pair_touch.resize(0)
		return
	var extent := high - low
	var cell_size := maxf(104.0, maxf(extent.x, extent.y) / 256.0)
	var grid_w := int(extent.x / cell_size) + 1
	var grid_h := int(extent.y / cell_size) + 1
	b._cell_size = cell_size
	b._grid_origin = low
	b._grid_w = grid_w
	b._grid_h = grid_h
	var cells := grid_w * grid_h
	var cell_start: PackedInt32Array = b._cell_start
	var cell_items: PackedInt32Array = b._cell_items
	cell_start.resize(cells + 1)
	cell_start.fill(0)
	cell_items.resize(placed)
	var inv := 1.0 / cell_size
	for s in slime_count:
		if calm[s] == SlimeBodies.PARKED:
			slime_cell[s] = -1
			continue
		var c: Vector2 = centre[s] - low
		var cell := mini(int(c.y * inv), grid_h - 1) * grid_w + mini(int(c.x * inv), grid_w - 1)
		slime_cell[s] = cell
		cell_start[cell + 1] += 1
	for k in cells:
		cell_start[k + 1] += cell_start[k]
	var fill := cell_start.slice(0, cells)
	for s in slime_count:
		var cell: int = slime_cell[s]
		if cell < 0:
			continue
		cell_items[fill[cell]] = s
		fill[cell] += 1
	# A pair (s, t) has s < t and at most one wall. A slime after the last
	# mover is a wall with only walls after it: it pairs with nothing, so
	# the scan stops at the last mover (none: no pairs).
	for s in last_mover + 1:
		var cell: int = slime_cell[s]
		if cell < 0:
			continue
		var wall_s: bool = b._is_wall(s)
		var cx := cell % grid_w
		var cy := cell / grid_w
		var cs: Vector2 = centre[s]
		var rs: float = bound_r[s]
		var x0 := maxi(cx - 1, 0)
		var x1 := mini(cx + 2, grid_w)
		for gy in range(maxi(cy - 1, 0), mini(cy + 2, grid_h)):
			# The cells x0 .. x1 - 1 of row gy hold their slimes back to back
			# in cell_items, so one range scans them all, in the order the
			# cells come (the native pass scans them cell by cell).
			var row := gy * grid_w
			for q in range(cell_start[row + x0], cell_start[row + x1]):
				var t: int = cell_items[q]
				# Two walls (sleepers, resting slimes) are never paired.
				if t <= s or (wall_s and b._is_wall(t)):
					continue
				# Margin: slimes may close in during the tick's substeps.
				var rr: float = rs + bound_r[t] + 8.0
				if (centre[t] - cs).length_squared() < rr * rr:
					pairs.append(s)
					pairs.append(t)
	b._pair_touch.resize(pairs.size() / 2)
	b._pair_touch.fill(0)


## Ring against ring. For each side of a pair, the points of ring a facing b
## that are inside b's radial profile (read off b's points, ordered by angle
## around its centre) move out by half the overlap, and the whole of ring b
## moves back by the same total, so momentum is kept. Also records touching
## pairs and support (a point resting on the upper half of another ring).
##
## Out of b means out on a's side of b's centre. A point of a that has gone
## past b's centre (seen from a's centre: the rings are deeper in each other
## than a's radius) moves out along its offset from b's centre mirrored
## across the line through b's centre square to the centres' line, so the
## push still parts the rings (same size, away from b's centre). Pushed
## straight out from b's centre, it moved on away from a's centre: a was
## drawn into b, the deeper the stronger, until the two centres met and no
## point was inside the other any more (a slime gobbled by another, O91).
# @spec-link [[rule_contact_pushes_slimes_apart]]
static func solve_contacts(b) -> void:
	var p: PackedVector2Array = b.pos
	var o: PackedVector2Array = b.prev
	var pairs: PackedInt32Array = b._pairs
	var pair_touch: PackedByteArray = b._pair_touch
	var centre: PackedVector2Array = b.centre
	var bound_r: PackedFloat32Array = b.bound_r
	var npts: PackedInt32Array = b.npts
	var first: PackedInt32Array = b.first
	var angle0: PackedFloat32Array = b.angle0
	var drift: PackedVector2Array = b._drift
	var supported: PackedInt32Array = b.supported
	var mu: float = b.slime_friction
	var np := pairs.size()
	var inv_tau := 1.0 / TAU
	var skin := SlimeBodies.TOUCH_SKIN
	var i := 0
	while i < np:
		var s0: int = pairs[i]
		var s1: int = pairs[i + 1]
		var pair := i / 2
		i += 2
		var rr: float = bound_r[s0] + bound_r[s1]
		if (centre[s1] - centre[s0]).length_squared() >= rr * rr:
			continue
		for side in 2:
			var a := s0 if side == 0 else s1
			var bs := s1 if side == 0 else s0
			var ca: Vector2 = centre[a]
			var cb: Vector2 = centre[bs]
			var rb: float = bound_r[bs] + skin
			var rb2 := rb * rb
			var nb: int = npts[bs]
			var fb: int = first[bs]
			var b0: float = angle0[bs]
			var na: int = npts[a]
			var fa: int = first[a]
			var dir := cb - ca
			var ta := (atan2(dir.y, dir.x) - angle0[a]) * inv_tau
			if ta < 0.0:
				ta += 1.0
			var mid := int(ta * na + 0.5)
			var half := na / 4 + 1
			var kb := nb * inv_tau
			var react := Vector2.ZERO
			var drag := Vector2.ZERO
			var vb: Vector2 = drift[bs]
			var touched := false
			var rests := false
			# A sleeper (or a resting slime) is a wall: its points only feel
			# the touch, and a slime against it takes the whole overlap.
			var still: bool = b._is_wall(a)
			var against_still: bool = b._is_wall(bs)
			var share := 1.0 if against_still else 0.5
			for m in range(mid - half, mid + half + 1):
				var j := fa + (m % na + na) % na
				var rel: Vector2 = p[j] - cb
				var d2 := rel.length_squared()
				if d2 >= rb2 or d2 < 1e-6:
					continue
				var t := (atan2(rel.y, rel.x) - b0) * kb
				if t < 0.0:
					t += nb
				var k := int(t)
				if k >= nb:
					k -= nb
				var fr := t - k
				var k2 := k + 1 if k + 1 < nb else 0
				var r0: float = (p[fb + k] - cb).length()
				var r := r0 + ((p[fb + k2] - cb).length() - r0) * fr
				var rs := r + skin
				if d2 >= rs * rs:
					continue
				touched = true
				var d := sqrt(d2)
				if rel.y < -SlimeBodies.SUPPORT_NORMAL_Y * d:
					rests = true
				# Only a point of a moving ring inside b's profile is pushed.
				if still or not (d < r):
					continue
				# Past b's centre: mirrored back to a's side (see the doc).
				var out := rel
				var along := rel.dot(dir)
				if along > 0.0:
					out = rel - dir * (2.0 * along / dir.length_squared())
				var push := out * ((r - d) * share / d)
				var moved: Vector2 = p[j] + push
				p[j] = moved
				react -= push
				# Friction: slow the point's sliding along b's surface.
				var nrm := out / d
				var slide: Vector2 = moved - o[j] - vb
				slide = (slide - nrm * slide.dot(nrm)) * mu
				o[j] += slide
				drag += slide
			if touched:
				pair_touch[pair] = 1
			if rests and not still:
				supported[a] = 1
			if react != Vector2.ZERO and not against_still:
				react /= nb
				drag /= nb
				for q in range(fb, fb + nb):
					p[q] += react
					o[q] -= drag


## Edge springs, area (pressure) and shape matching, per ring (the spike's
## solver, with Jacobi edge springs).
static func solve_rings(b) -> void:
	var p: PackedVector2Array = b.pos
	var rest_off: PackedVector2Array = b.rest_off
	var state: PackedInt32Array = b.state
	var calm: PackedByteArray = b.calm
	var first: PackedInt32Array = b.first
	var npts: PackedInt32Array = b.npts
	var rest_edge: PackedFloat32Array = b.rest_edge
	var rest_area: PackedFloat32Array = b.rest_area
	var ks: float = b.edge_stiffness * 0.5
	var ka: float = b.area_stiffness
	var kshape: float = b.shape_stiffness
	var slime_count: int = b.slime_count
	for s in slime_count:
		if state[s] == SlimeBodies.STATE_SLEEPER or calm[s] != SlimeBodies.ACTIVE:
			continue
		var f: int = first[s]
		var cnt: int = npts[s]
		var last := f + cnt - 1
		var rest: float = rest_edge[s]
		# Edge springs (position-based distance constraints), Jacobi style:
		# every correction comes from the positions before the pass, so the
		# ring has no preferred direction (a sequential pass makes a squashed
		# ring creep sideways).
		var pp: Vector2 = p[last]
		var cur: Vector2 = p[f]
		var first_p := cur
		var d_prev := cur - pp
		var l_prev := d_prev.length()
		var e_prev := (l_prev - rest) / l_prev if l_prev > 1e-5 else 0.0
		for j in range(f, last + 1):
			var nx: Vector2 = p[j + 1] if j < last else first_p
			var d_next := nx - cur
			var l_next := d_next.length()
			var e_next := (l_next - rest) / l_next if l_next > 1e-5 else 0.0
			p[j] = cur + (d_next * e_next - d_prev * e_prev) * ks
			d_prev = d_next
			e_prev = e_next
			cur = nx
		# One read pass: area, area-gradient norm, centre, and the rotation
		# that best fits the rest circle.
		var area := 0.0
		var grad_sq := 0.0
		var c := Vector2.ZERO
		var sd := 0.0
		var sc := 0.0
		pp = p[last]
		cur = p[f]
		for j in range(f, last + 1):
			var nx: Vector2 = p[j + 1] if j < last else p[f]
			area += pp.cross(cur)
			grad_sq += (nx - pp).length_squared()
			c += cur
			var q: Vector2 = rest_off[j]
			sd += q.dot(cur)
			sc += q.cross(cur)
			pp = cur
			cur = nx
		area *= 0.5
		grad_sq *= 0.25
		c /= cnt
		var lam := 0.0
		if grad_sq > 1e-6:
			lam = (rest_area[s] - area) / grad_sq * ka
		var rot := Vector2(sd, sc).normalized()
		# Apply pass: area gradient, then the shape-matching pull, from the
		# neighbours' positions before the pass.
		pp = p[last]
		cur = p[f]
		first_p = cur
		for j in range(f, last + 1):
			var nx: Vector2 = p[j + 1] if j < last else first_p
			var moved := cur + Vector2(nx.y - pp.y, pp.x - nx.x) * (0.5 * lam)
			var q: Vector2 = rest_off[j]
			var goal := c + Vector2(q.x * rot.x - q.y * rot.y, q.x * rot.y + q.y * rot.x)
			p[j] = moved + (goal - moved) * kshape
			pp = cur
			cur = nx


## Ring points against the terrain segments (O78): a point inside the terrain,
## or closer than `terrain_skin` to it, goes to `terrain_skin` off the nearest
## surface point; its velocity loses the part going into the surface and
## `terrain_friction` of the part along it. A point pushed out by a surface
## facing up supports its slime. The shut doors are solved the same way,
## after the terrain. The first pass (the terrain's, else the first door's)
## also measures a box around each slime's points, and the door passes after
## it skip a slime whose box lies outside the door's grid, where every one of
## its points would have been skipped anyway. With the debug phase timers on
## (SlimeBodies.phases), the terrain and the doors are timed apart.
static func solve_terrain(b) -> void:
	var door_shut := false
	for door in b.doors:
		if door != null and not door.is_empty():
			door_shut = true
			break
	var measured := false
	if b.terrain != null and not b.terrain.is_empty():
		solve_against(b, b.terrain, door_shut, false)
		measured = door_shut
	if b.phases != null:
		b.phases.lap(SlimeBodies.TickPhase.TERRAIN)
	for door in b.doors:
		if door != null and not door.is_empty():
			solve_against(b, door, not measured, measured)
			measured = true
	if b.phases != null:
		b.phases.lap(SlimeBodies.TickPhase.DOORS)


## One pass of ring points against `tf` (see solve_terrain). `measure`:
## sets each simulated slime's box (_box_lo, _box_hi) to hold its points
## before and after the pass. `by_box`: skips the slimes whose box (set by an
## earlier pass) is outside tf's grid, and grows the box by every point it
## moves, so it still holds all the slime's points for the next door.
static func solve_against(b, tf: TerrainSegments, measure: bool, by_box: bool) -> void:
	var slime_count: int = b.slime_count
	if measure and b._box_lo.size() != slime_count:
		b._box_lo.resize(slime_count)
		b._box_hi.resize(slime_count)
	var p: PackedVector2Array = b.pos
	var o: PackedVector2Array = b.prev
	var state: PackedInt32Array = b.state
	var calm: PackedByteArray = b.calm
	var first: PackedInt32Array = b.first
	var npts: PackedInt32Array = b.npts
	var supported: PackedInt32Array = b.supported
	var box_lo: PackedVector2Array = b._box_lo
	var box_hi: PackedVector2Array = b._box_hi
	var sa := tf.seg_a
	var sdir := tf.seg_d
	var sil := tf.seg_inv_len2
	var sn := tf.seg_n
	var sna := tf.seg_na
	var snb := tf.seg_nb
	var starts := tf.cell_start
	var items := tf.cell_items
	var ox := tf.origin.x
	var oy := tf.origin.y
	var inv := tf.inv_cell
	var gw := tf.grid_w
	var gh := tf.grid_h
	var keep: float = 1.0 - b.terrain_friction
	var skin: float = b.terrain_skin
	var skin2 := skin * skin
	var track := measure or by_box
	for s in slime_count:
		if state[s] == SlimeBodies.STATE_SLEEPER or calm[s] != SlimeBodies.ACTIVE:
			continue
		var lo := Vector2.INF
		var hi := -Vector2.INF
		if by_box:
			lo = box_lo[s]
			hi = box_hi[s]
			# The per-point grid test below is monotonic in x and y: when the
			# box's far corner is off one side of the grid, so is every point.
			if (int(floor((hi.x - ox) * inv)) < 0 or int(floor((hi.y - oy) * inv)) < 0
					or int(floor((lo.x - ox) * inv)) >= gw or int(floor((lo.y - oy) * inv)) >= gh):
				continue
		var f: int = first[s]
		var carried := false
		for i in range(f, f + npts[s]):
			var c: Vector2 = p[i]
			if measure:
				lo = lo.min(c)
				hi = hi.max(c)
			var cx := int(floor((c.x - ox) * inv))
			var cy := int(floor((c.y - oy) * inv))
			if cx < 0 or cy < 0 or cx >= gw or cy >= gh:
				continue
			var cell := cy * gw + cx
			var best := -1
			var best_d2 := INF
			var best_q := Vector2.ZERO
			var best_t := 0.0
			for qi in range(starts[cell], starts[cell + 1]):
				var k: int = items[qi]
				var a: Vector2 = sa[k]
				var d: Vector2 = sdir[k]
				var t := clampf((c - a).dot(d) * sil[k], 0.0, 1.0)
				var q := a + d * t
				var d2 := c.distance_squared_to(q)
				if d2 < best_d2:
					best_d2 = d2
					best = k
					best_q = q
					best_t = t
			if best < 0:
				continue
			var n: Vector2 = sn[best]
			var off := c - best_q
			# Inside or out: at a segment's end, by the vertex's normal
			# (TerrainSegments.side_normal, inlined).
			var side := n
			if best_t <= 0.0:
				side = sna[best]
			elif best_t >= 1.0:
				side = snb[best]
			if off.dot(side) >= 0.0:
				# Outside: only within the skin, pushed away from the nearest
				# surface point (round around convex corners).
				if best_d2 >= skin2:
					continue
				if best_d2 > 1e-8:
					n = off / sqrt(best_d2)
			var target := best_q + n * skin
			p[i] = target
			if track:
				lo = lo.min(target)
				hi = hi.max(target)
			var v: Vector2 = target - o[i]
			var vn := v.dot(n)
			var vt := v - n * vn
			o[i] = target - (vt * keep + n * maxf(vn, 0.0))
			if n.y < -SlimeBodies.SUPPORT_NORMAL_Y:
				carried = true
		if carried:
			supported[s] = 1
		if track:
			box_lo[s] = lo
			box_hi[s] = hi
