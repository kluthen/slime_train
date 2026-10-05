extends GutTest
## The native terrain pass (SlimeSolver.solve_terrain, chunk 5N wave 1, U4:
## native/slime_native/src/solver_terrain.cpp) against its GDScript fallback
## (SlimeBodies._solve_terrain and _solve_against): the terrain and the shut
## doors, through the equivalence harness
## (tests/unit/native_equivalence_support.gd). Every scene at several
## moments of a tick; the door passes' box skip (a slime far from a door);
## points at a segment's end (the vertex normals: the V notch, the convex
## corner); the support flags, exactly; shut, open and changed doors; the
## pit; no terrain at all; and two native runs bit for bit.

const Eq := preload("res://tests/unit/native_equivalence_support.gd")
const Scenes := preload("res://tests/unit/native_equivalence_scenes.gd")
## Whole GDScript ticks run before a moment, for more moments per scene.
const LATER_TICKS := 3


## Whether the test can run: pending (and false) while the native pass is a
## stub, or on a GDScript run without the extension.
func _can_run() -> bool:
	var why := Eq.skip_reason(Eq.TERRAIN)
	if why != "":
		pending(why)
		return false
	return true


## The moments of the terrain pass in a tick of `bodies`: [substep, iteration].
func _moments(bodies: SlimeBodies) -> Array:
	var out := []
	for sub in bodies.substeps:
		for it in bodies.iterations:
			out.append([sub, it])
	return out


## A copy of scene `name` brought to the terrain pass of substep `sub` and
## iteration `it`, after `ticks` whole GDScript ticks and with `iterations`
## solver iterations (0: the scene's).
func _at(name: String, sub: int, it: int, ticks := 0, iterations := 0) -> SlimeBodies:
	var bodies := Eq.scene(name)
	if iterations > 0:
		bodies.iterations = iterations
	for t in ticks:
		bodies.tick(Eq.DT)
	if not Eq.prepare(bodies, Eq.TERRAIN, sub, it):
		return null
	return bodies


## Asserts the native pass matches the GDScript pass on `bodies`.
func _assert_matches(bodies: SlimeBodies, label: String) -> void:
	assert_not_null(bodies, "%s: prepared" % label)
	if bodies == null:
		return
	var problems := Eq.check(bodies, Eq.TERRAIN, label)
	assert_true(problems.is_empty(), "\n".join(problems))


## `bodies` after the terrain pass run by `kind`, on a copy.
func _after(bodies: SlimeBodies, kind: String) -> SlimeBodies:
	var copy := Eq.clone(bodies)
	assert_true(Eq.run_phase(copy, Eq.TERRAIN, kind), "the %s pass runs" % kind)
	return copy


## The largest distance between `a` and `b`'s `field` (packed vectors).
func _max_gap(a: SlimeBodies, b: SlimeBodies, field: String) -> float:
	var va: PackedVector2Array = a.get(field)
	var vb: PackedVector2Array = b.get(field)
	var worst := 0.0
	for i in va.size():
		worst = maxf(worst, va[i].distance_to(vb[i]))
	return worst


## How many points of slime index `s` lie within the skin of `tf` where
## their nearest segment point is a segment's end (the vertex-normal case).
func _points_at_segment_ends(bodies: SlimeBodies, tf: TerrainSegments, s: int) -> int:
	var count := 0
	for i in range(bodies.first[s], bodies.first[s] + bodies.npts[s]):
		var c: Vector2 = bodies.pos[i]
		var k := tf.nearest_segment(c)
		if k < 0:
			continue
		var t := clampf((c - tf.seg_a[k]).dot(tf.seg_d[k]) * tf.seg_inv_len2[k], 0.0, 1.0)
		var d2 := c.distance_squared_to(tf.closest_on_segment(k, c))
		if d2 < bodies.terrain_skin * bodies.terrain_skin and (t <= 0.0 or t >= 1.0):
			count += 1
	return count


## Whether slime index `s`'s box (as the GDScript pass left it) lies outside
## `tf`'s grid, so a door pass skips it.
func _box_outside(bodies: SlimeBodies, tf: TerrainSegments, s: int) -> bool:
	var lo: Vector2 = bodies._box_lo[s]
	var hi: Vector2 = bodies._box_hi[s]
	return (floori((hi.x - tf.origin.x) * tf.inv_cell) < 0 or floori((hi.y - tf.origin.y) * tf.inv_cell) < 0
			or floori((lo.x - tf.origin.x) * tf.inv_cell) >= tf.grid_w
			or floori((lo.y - tf.origin.y) * tf.inv_cell) >= tf.grid_h)


## Whether slime index `s` is simulated (the terrain pass touches it).
func _simulated(bodies: SlimeBodies, s: int) -> bool:
	return bodies.state[s] != SlimeBodies.STATE_SLEEPER and bodies.calm[s] == SlimeBodies.ACTIVE


# --- Every scene, several moments ---------------------------------------------

func test_terrain_matches_gdscript_in_every_scene_and_moment() -> void:
	if not _can_run():
		return
	for name in Eq.SCENES:
		var probe := Eq.scene(name)
		for moment in _moments(probe):
			for ticks in [0, LATER_TICKS]:
				var label := "%s, substep %d, iteration %d, after %d ticks" % [name, moment[0], moment[1], ticks]
				_assert_matches(_at(name, moment[0], moment[1], ticks), label)


func test_terrain_matches_gdscript_with_two_iterations() -> void:
	if not _can_run():
		return
	for name in Eq.SCENES:
		for sub in Eq.scene(name).substeps:
			for it in 2:
				_assert_matches(_at(name, sub, it, 0, 2), "%s, 2 iterations, substep %d, iteration %d" % [name, sub, it])


func test_terrain_matches_gdscript_with_other_friction_and_skin() -> void:
	if not _can_run():
		return
	for name in [Scenes.STRESS_MOVING, Scenes.GATE2_OPEN, Eq.SYNTHETIC]:
		for tuning in [[0.0, 3.0], [1.0, 3.0], [0.4, 0.0], [0.25, 6.5]]:
			var bodies := _at(name, 0, 0)
			bodies.terrain_friction = tuning[0]
			bodies.terrain_skin = tuning[1]
			_assert_matches(bodies, "%s, friction %s, skin %s" % [name, tuning[0], tuning[1]])


func test_terrain_differences_stay_far_below_the_tolerance() -> void:
	if not _can_run():
		return
	var worst := {"pos": 0.0, "prev": 0.0}
	for name in Eq.SCENES:
		for moment in _moments(Eq.scene(name)):
			var bodies := _at(name, moment[0], moment[1])
			var gd := _after(bodies, Eq.GDSCRIPT)
			var native := _after(bodies, Eq.NATIVE)
			for field in worst:
				worst[field] = maxf(worst[field], _max_gap(gd, native, field))
	gut.p("terrain, the largest GDScript-native gap: pos %s px, prev %s px" % [worst["pos"], worst["prev"]])
	for field in worst:
		assert_lt(worst[field], Eq.DEFAULT_TOLERANCE, "%s within the tolerance" % field)


# --- The cases of this pass ---------------------------------------------------

## A door pass skips the slimes whose box lies outside its grid: the
## synthetic far door holds no slime, gate2-open's doors skip most of the
## crowd; the native pass gives the same result.
func test_the_box_skip_of_the_door_passes() -> void:
	if not _can_run():
		return
	for name in [Eq.SYNTHETIC, Scenes.GATE2_OPEN]:
		var bodies := _at(name, 0, 0)
		var gd := _after(bodies, Eq.GDSCRIPT)
		var skipped := 0
		var inside := 0
		for door in bodies.doors:
			if door == null or door.is_empty():
				continue
			for s in bodies.slime_count:
				if not _simulated(bodies, s):
					continue
				if _box_outside(gd, door, s):
					skipped += 1
				else:
					inside += 1
		assert_gt(skipped, 0, "%s: a door pass skips a slime by its box" % name)
		assert_gt(inside, 0, "%s: a door pass sees a slime" % name)
		_assert_matches(bodies, "%s, the box skip" % name)
	# The far door: every simulated slime is skipped by box.
	var syn := _at(Eq.SYNTHETIC, 0, 0)
	var far: TerrainSegments = syn.doors[1]
	var gd_syn := _after(syn, Eq.GDSCRIPT)
	for s in syn.slime_count:
		if _simulated(syn, s):
			assert_true(_box_outside(gd_syn, far, s), "synthetic: the far door skips slime index %d" % s)


## No terrain, doors only: the first door's pass measures the boxes, the
## next ones skip by them.
func test_doors_without_terrain() -> void:
	if not _can_run():
		return
	for name in [Eq.SYNTHETIC, Scenes.GATE2_OPEN]:
		var bodies := _at(name, 0, 0)
		bodies.terrain = null
		_assert_matches(bodies, "%s, no terrain" % name)
		var empty_terrain := _at(name, 0, 0)
		empty_terrain.terrain = TerrainSegments.new()
		_assert_matches(empty_terrain, "%s, an empty terrain" % name)


## Nothing to collide with: nothing changes, and the pass still runs.
func test_no_terrain_and_no_door_changes_nothing() -> void:
	if not _can_run():
		return
	var bodies := _at(Eq.SYNTHETIC, 0, 0)
	bodies.terrain = null
	bodies.doors.clear()
	var native := _after(bodies, Eq.NATIVE)
	var problems := Eq.compare(bodies, native, "no terrain, no door", Eq.EXACT)
	assert_true(problems.is_empty(), "\n".join(problems))
	_assert_matches(bodies, "synthetic, no terrain, no door")


## Points whose nearest terrain point is a segment's end (inside or out by
## the vertex's normal): the convex corner and the V notch of the synthetic
## scene.
func test_points_at_segment_ends() -> void:
	if not _can_run():
		return
	var found := 0
	for moment in _moments(Eq.scene(Eq.SYNTHETIC)):
		var bodies := _at(Eq.SYNTHETIC, moment[0], moment[1])
		for s in [Scenes.ON_CORNER, 0, 1]:
			found += _points_at_segment_ends(bodies, bodies.terrain, s)
		_assert_matches(bodies, "synthetic, segment ends, substep %d" % moment[0])
	var corner := _at(Eq.SYNTHETIC, 0, 0)
	assert_gt(_points_at_segment_ends(corner, corner.terrain, Scenes.ON_CORNER), 0,
			"synthetic: a point of ON_CORNER at the convex corner")
	assert_gt(found, 0, "some points at a segment's end")


## Two sharp spikes, the apex listed as a segment's start in one and as its
## end in the other, and one point of a slime in the wedge just outside each
## apex, where the nearest segment's own normal says inside but the vertex's
## normal says outside (TerrainSegments' class doc): the point is pushed
## away from the apex, by the skin, in both passes. The scenes' corners are
## too blunt for the two normals to disagree.
func test_points_in_the_wedge_of_a_sharp_corner() -> void:
	if not _can_run():
		return
	var bodies := SlimeBodies.new(Rng.new(1))
	bodies.use_native(false)
	var apexes := [Vector2(10, -100), Vector2(210, -100)]
	# The first: segment 0 starts at the apex (seg_na); the second: segment 3
	# (the second outline's first) ends at it (seg_nb).
	bodies.terrain = TerrainSegments.new([
		PackedVector2Array([apexes[0], Vector2(20, 0), Vector2(0, 0)]),
		PackedVector2Array([Vector2(200, 0), apexes[1], Vector2(220, 0)]),
	])
	var offsets := [Vector2(-0.5, -2.0), Vector2(0.5, -2.0)]
	var tf := bodies.terrain
	assert_lt(offsets[0].dot(tf.seg_n[0]), 0.0, "spike 0: the segment's normal says inside")
	assert_gte(offsets[0].dot(tf.seg_na[0]), 0.0, "spike 0: the vertex's normal says outside")
	assert_lt(offsets[1].dot(tf.seg_n[3]), 0.0, "spike 1: the segment's normal says inside")
	assert_gte(offsets[1].dot(tf.seg_nb[3]), 0.0, "spike 1: the vertex's normal says outside")
	var points := []
	for k in 2:
		var s := bodies.index_of(bodies.create(0, 1, apexes[k] + Vector2(0, -30), SlimeBodies.TRAIN))
		var i: int = bodies.first[s] + bodies.npts[s] / 2
		bodies.pos[i] = apexes[k] + offsets[k]
		bodies.prev[i] = bodies.pos[i]
		points.append(i)
	var gd := _after(bodies, Eq.GDSCRIPT)
	for k in 2:
		var i: int = points[k]
		var away: Vector2 = apexes[k] + offsets[k].normalized() * bodies.terrain_skin
		assert_almost_eq(gd.pos[i].distance_to(away), 0.0, 1e-4, "spike %d: pushed away from the apex" % k)
	_assert_matches(bodies, "two sharp spikes")


## The support flags: set by the pass (exactly as GDScript sets them), never
## cleared; some slimes become supported in this pass.
func test_support_flags_are_exact() -> void:
	if not _can_run():
		return
	for name in Eq.SCENES:
		var bodies := _at(name, 0, 0)
		var gd := _after(bodies, Eq.GDSCRIPT)
		var native := _after(bodies, Eq.NATIVE)
		assert_eq(native.supported, gd.supported, "%s: supported, exactly" % name)
		if name == Scenes.STRESS_STILL:
			continue
		var newly := 0
		for s in bodies.slime_count:
			if bodies.supported[s] == 0 and native.supported[s] == 1:
				newly += 1
		assert_gt(newly, 0, "%s: the pass supports some slimes" % name)


## A shut door (gate2-open's, the synthetic slab under slime 13) against
## the same scene with every door open; then a door shut or opened between two native passes:
## the pass reads the doors on every call (nothing cached across calls).
func test_shut_and_open_doors() -> void:
	if not _can_run():
		return
	for name in [Scenes.GATE2_OPEN, Eq.SYNTHETIC]:
		var shut := _at(name, 0, 0)
		_assert_matches(shut, "%s, doors shut" % name)
		var open := _at(name, 0, 0)
		open.doors.clear()
		_assert_matches(open, "%s, doors open" % name)
		if name == Eq.SYNTHETIC:
			# The slab holds slime 13 up: the two results differ.
			var with_doors := _after(shut, Eq.NATIVE)
			var without := _after(open, Eq.NATIVE)
			assert_true(with_doors.pos != without.pos, "%s: a shut door moves points" % name)
		# A door opens between two native passes.
		var opening := _at(name, 0, 0)
		assert_true(Eq.run_phase(opening, Eq.TERRAIN, Eq.NATIVE))
		opening.doors.clear()
		_assert_matches(opening, "%s, a door opened since the last pass" % name)
	# A door shuts between two native passes (the synthetic slab, again).
	var shutting := _at(Eq.SYNTHETIC, 0, 0)
	var slab: TerrainSegments = shutting.doors[0]
	shutting.doors.clear()
	assert_true(Eq.run_phase(shutting, Eq.TERRAIN, Eq.NATIVE))
	shutting.doors.append(slab)
	_assert_matches(shutting, "synthetic, a door shut since the last pass")
	# Null and empty doors in the list do nothing.
	var odd := _at(Eq.SYNTHETIC, 0, 0)
	odd.doors.insert(0, TerrainSegments.new())
	odd.doors.append(null)
	_assert_matches(odd, "synthetic, empty and null doors")


## The slime wedged in the pit: the pass moves its points, as GDScript does.
func test_the_pit() -> void:
	if not _can_run():
		return
	var moved := 0
	for moment in _moments(Eq.scene(Eq.SYNTHETIC)):
		var bodies := _at(Eq.SYNTHETIC, moment[0], moment[1])
		var native := _after(bodies, Eq.NATIVE)
		var s := Scenes.IN_PIT
		for i in range(bodies.first[s], bodies.first[s] + bodies.npts[s]):
			if native.pos[i] != bodies.pos[i]:
				moved += 1
		_assert_matches(bodies, "synthetic, the pit, substep %d" % moment[0])
	assert_gt(moved, 0, "the pass moves points of the slime in the pit")


## Two native runs from the same state are bit for bit the same.
func test_native_is_deterministic() -> void:
	if not _can_run():
		return
	for name in Eq.SCENES:
		for moment in _moments(Eq.scene(name)):
			var bodies := _at(name, moment[0], moment[1])
			var problems := Eq.check_kinds(bodies, Eq.TERRAIN, "%s, substep %d" % [name, moment[0]], Eq.NATIVE,
					Eq.NATIVE, Eq.EXACT)
			assert_true(problems.is_empty(), "\n".join(problems))
