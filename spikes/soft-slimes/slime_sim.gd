extends RefCounted
## Spike 1 (throwaway): ring-of-springs slime simulation at scale.
##
## Data layout (struct of arrays): every point of every slime lives in one flat
## PackedVector2Array (`pos`, with `prev` for Verlet); a slime is a
## (first, npts) slice of it plus a few per-slime arrays. Fixed step, split
## into substeps (small steps converge much better than more iterations).
##
## Per substep: Verlet integration (with the points' velocities pulled a
## little toward their slime's mean velocity, which stops internal jiggle),
## hops, then `iterations` passes of:
##   - slime-slime contacts: each point of ring A inside ring B's radial
##     profile moves out by half the overlap, and the whole of ring B moves
##     back by the same total (momentum kept). The mirror call dents B.
##   - ring constraints: edge springs, area (pressure), and a weak pull toward
##     the rest circle rotated to the ring's orientation (shape matching).
##   - floor and walls.
## A uniform grid on slime centres is the broadphase, rebuilt once per step.

const GRAVITY := Vector2(0.0, 1400.0)

var dt: float = 1.0 / 60.0
var substeps: int = 2
var iterations: int = 1
var edge_stiffness: float = 0.8
var area_stiffness: float = 0.6
var shape_stiffness: float = 0.3
var damping: float = 0.996
var internal_damping: float = 0.1
var floor_friction: float = 0.4
var max_speed: float = 1200.0 # px/s, a safety clamp
var hopping: bool = false

# World bounds (logical pixels).
var floor_y: float = 600.0
var wall_left: float = 0.0
var wall_right: float = 1152.0

# Per point.
var pos := PackedVector2Array()
var prev := PackedVector2Array()
var rest_off := PackedVector2Array() # offset from the centre in the rest circle

# Per slime.
var slime_count: int = 0
var first := PackedInt32Array()
var npts := PackedInt32Array()
var size_of := PackedInt32Array()
var species := PackedInt32Array()
var ring_radius := PackedFloat32Array()
var bound_r := PackedFloat32Array()  # broadphase radius (rest radius plus room to squish)
var rest_area := PackedFloat32Array()
var rest_edge := PackedFloat32Array()
var hop_timer := PackedFloat32Array()
var centre := PackedVector2Array()   # mean of the points, per substep
var angle0 := PackedFloat32Array()   # angle of the slime's point 0 around its centre

# Broadphase grid.
var cell_size: float = 80.0
var grid_w: int = 1
var grid_h: int = 1
var cell_start := PackedInt32Array()
var cell_items := PackedInt32Array()
var slime_cell := PackedInt32Array()
var pairs := PackedInt32Array()      # candidate pairs (a, b), per step

var rng := RandomNumberGenerator.new()

var contact_tests: int = 0 # points tested against a ring profile, last pass


func setup_world(width: float, floor_at: float, seed_value: int) -> void:
	wall_left = 0.0
	wall_right = width
	floor_y = floor_at
	rng.seed = seed_value
	grid_w = int(ceil(width / cell_size)) + 1
	grid_h = int(ceil((floor_at + 2000.0) / cell_size)) + 1


func add_slime(at: Vector2, size: int, species_id: int, points: int, radius: float) -> void:
	slime_count += 1
	first.append(pos.size())
	npts.append(points)
	size_of.append(size)
	species.append(species_id)
	ring_radius.append(radius)
	bound_r.append(radius * 1.3)
	rest_area.append(0.5 * points * radius * radius * sin(TAU / points))
	rest_edge.append(2.0 * radius * sin(PI / points))
	hop_timer.append(rng.randf_range(0.2, 3.0))
	centre.append(at)
	angle0.append(0.0)
	slime_cell.append(0)
	for i in points:
		var a := TAU * i / points
		var off := Vector2(cos(a), sin(a)) * radius
		pos.append(at + off)
		prev.append(at + off)
		rest_off.append(off)


func step() -> void:
	var h := dt / substeps
	for sub in substeps:
		_integrate(h, sub == 0)
		if sub == 0:
			_build_grid()
		for it in iterations:
			_solve_contacts()
			_solve_rings()
			_solve_bounds()


## Verlet step; also refreshes each slime's centre and point-0 angle.
func _integrate(h: float, first_sub: bool) -> void:
	var p := pos
	var o := prev
	var g := GRAVITY * h * h
	var ms := max_speed * h
	var idamp := internal_damping
	var damp := damping
	var hop := hopping and first_sub
	for s in slime_count:
		var f: int = first[s]
		var cnt: int = npts[s]
		var end: int = f + cnt
		var mean := Vector2.ZERO
		for i in range(f, end):
			mean += p[i] - o[i]
		mean /= cnt
		var kick := Vector2.ZERO
		if hop:
			kick = _hop_kick(s, h)
		var c := Vector2.ZERO
		for i in range(f, end):
			var cur: Vector2 = p[i]
			var v: Vector2 = cur - o[i]
			v = ((v + (mean - v) * idamp) * damp).limit_length(ms) + g + kick
			o[i] = cur
			var nxt := cur + v
			p[i] = nxt
			c += nxt
		c /= cnt
		centre[s] = c
		var r0: Vector2 = p[f] - c
		angle0[s] = atan2(r0.y, r0.x)


func _hop_kick(s: int, h: float) -> Vector2:
	var t: float = hop_timer[s] - dt
	if t > 0.0:
		hop_timer[s] = t
		return Vector2.ZERO
	var size: int = size_of[s]
	# Bigger slimes hop a little less often, further and higher.
	hop_timer[s] = rng.randf_range(1.5, 3.0) * (1.0 + 0.15 * (size - 1))
	var up := -rng.randf_range(520.0, 680.0) * (1.0 + 0.12 * (size - 1))
	var side := rng.randf_range(-160.0, 160.0)
	return Vector2(side, up) * h


## Counting sort of slimes into grid cells, then the candidate pair list.
func _build_grid() -> void:
	var cells := grid_w * grid_h
	if cell_start.size() != cells + 1:
		cell_start.resize(cells + 1)
	cell_start.fill(0)
	if cell_items.size() != slime_count:
		cell_items.resize(slime_count)
	var top := floor_y - (grid_h - 1) * cell_size
	for s in slime_count:
		var c: Vector2 = centre[s]
		var cx := clampi(int((c.x - wall_left) / cell_size), 0, grid_w - 1)
		var cy := clampi(int((c.y - top) / cell_size), 0, grid_h - 1)
		var cell := cy * grid_w + cx
		slime_cell[s] = cell
		cell_start[cell + 1] += 1
	for k in cells:
		cell_start[k + 1] += cell_start[k]
	var fill := cell_start.slice(0, cells)
	for s in slime_count:
		var cell: int = slime_cell[s]
		cell_items[fill[cell]] = s
		fill[cell] += 1
	pairs.clear()
	for s in slime_count:
		var cell: int = slime_cell[s]
		var cx := cell % grid_w
		var cy := cell / grid_w
		var cs: Vector2 = centre[s]
		var rs: float = bound_r[s]
		for gy in range(maxi(cy - 1, 0), mini(cy + 2, grid_h)):
			for gx in range(maxi(cx - 1, 0), mini(cx + 2, grid_w)):
				var gc := gy * grid_w + gx
				for q in range(cell_start[gc], cell_start[gc + 1]):
					var t: int = cell_items[q]
					if t <= s:
						continue
					# Margin: slimes may close in during the step's substeps.
					var rr: float = rs + bound_r[t] + 8.0
					if (centre[t] - cs).length_squared() < rr * rr:
						pairs.append(s)
						pairs.append(t)


func _solve_contacts() -> void:
	var tests := 0
	var p := pos
	var np := pairs.size()
	var inv_tau := 1.0 / TAU
	var i := 0
	while i < np:
		var s0: int = pairs[i]
		var s1: int = pairs[i + 1]
		i += 2
		var rr: float = bound_r[s0] + bound_r[s1]
		if (centre[s1] - centre[s0]).length_squared() >= rr * rr:
			continue
		# Both directions, inlined (GDScript calls are expensive): push the
		# points of ring a that face ring b out of b's radial profile. b's
		# surface in the direction of a point is read off its points, which
		# are ordered by angle around its centre, so no polygon search is
		# needed. Half the overlap moves the point; the whole of ring b moves
		# back by the same total. Only the half of ring a facing b is scanned.
		for side in 2:
			var a := s0 if side == 0 else s1
			var b := s1 if side == 0 else s0
			var ca: Vector2 = centre[a]
			var cb: Vector2 = centre[b]
			var rb: float = bound_r[b]
			var rb2 := rb * rb
			var nb: int = npts[b]
			var fb: int = first[b]
			var b0: float = angle0[b]
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
			for m in range(mid - half, mid + half + 1):
				var j := fa + (m % na + na) % na
				var rel: Vector2 = p[j] - cb
				var d2 := rel.length_squared()
				if d2 >= rb2 or d2 < 1e-6:
					continue
				tests += 1
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
				if d2 < r * r:
					var d := sqrt(d2)
					var push := rel * ((r - d) * 0.5 / d)
					p[j] += push
					react -= push
			if react != Vector2.ZERO:
				react /= nb
				for q in range(fb, fb + nb):
					p[q] += react
	contact_tests = tests


func _solve_rings() -> void:
	var p := pos
	var ks := edge_stiffness * 0.5
	var ka := area_stiffness
	var kshape := shape_stiffness
	for s in slime_count:
		var f: int = first[s]
		var cnt: int = npts[s]
		var last := f + cnt - 1
		var rest: float = rest_edge[s]
		# Edge springs (position-based distance constraints).
		for j in range(f, last + 1):
			var k := j + 1 if j < last else f
			var a: Vector2 = p[j]
			var b: Vector2 = p[k]
			var d := b - a
			var len := d.length()
			if len > 1e-5:
				var corr := d * ((len - rest) / len * ks)
				p[j] = a + corr
				p[k] = b - corr
		# One read pass: area, area-gradient norm, centre, and the rotation
		# that best fits the rest circle (sum of rest_off is zero, so the
		# centre isn't needed to get the rotation).
		var area := 0.0
		var grad_sq := 0.0
		var c := Vector2.ZERO
		var sd := 0.0
		var sc := 0.0
		var pp: Vector2 = p[last]
		var cur: Vector2 = p[f]
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
		var rot := Vector2(sd, sc).normalized() # (cos, sin) of the fitted rotation
		# Apply pass: area gradient 0.5*(y[j+1]-y[j-1], x[j-1]-x[j+1]), then
		# the shape-matching pull. Uses the pre-pass positions of neighbours.
		pp = p[last]
		cur = p[f]
		var first_p := cur
		for j in range(f, last + 1):
			var nx: Vector2 = p[j + 1] if j < last else first_p
			var moved := cur + Vector2(nx.y - pp.y, pp.x - nx.x) * (0.5 * lam)
			var q: Vector2 = rest_off[j]
			var goal := c + Vector2(q.x * rot.x - q.y * rot.y, q.x * rot.y + q.y * rot.x)
			p[j] = moved + (goal - moved) * kshape
			pp = cur
			cur = nx


func _solve_bounds() -> void:
	var p := pos
	var o := prev
	var fy := floor_y
	var wl := wall_left
	var wr := wall_right
	var fric := floor_friction
	for i in p.size():
		var c: Vector2 = p[i]
		if c.y <= fy and c.x >= wl and c.x <= wr:
			continue
		if c.y > fy:
			c.y = fy
			var ov: Vector2 = o[i]
			ov.x = lerpf(ov.x, c.x, fric)
			o[i] = ov
		c.x = clampf(c.x, wl, wr)
		p[i] = c
