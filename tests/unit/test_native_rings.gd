extends GutTest
## The native ring pass (SlimeSolver.solve_rings,
## native/slime_native/src/solver_rings.cpp; chunk 5N) against the GDScript
## one (SlimeBodies._solve_rings), through the equivalence harness
## (tests/unit/native_equivalence_support.gd): every scene at every moment of
## a tick the pass runs (more iterations too), every detail level, changed
## stiffnesses, degenerate rings; the skipped slimes and the centre cache
## left alone; two native runs bit for bit the same. The port mirrors
## GDScript's precision, so it is held to an exact match on top of the
## harness's tolerance.

const Eq := preload("res://tests/unit/native_equivalence_support.gd")
const Scenes := preload("res://tests/unit/native_equivalence_scenes.gd")


## Pending (true) while the native ring pass doesn't run (see skip_reason).
func _pending() -> bool:
	var why := Eq.skip_reason(Eq.RINGS)
	if why != "":
		pending(why)
		return true
	return false


## The ring pass's moments in a tick of `bodies`, as [substep, iteration].
func _moments(bodies: SlimeBodies) -> Array:
	var out := []
	for step in Eq.tick_steps(bodies):
		if step[0] == Eq.RINGS:
			out.append([step[1], step[2]])
	return out


## Whether the ring pass works on slime index `s` (awake and not a sleeper).
func _ringed(bodies: SlimeBodies, s: int) -> bool:
	return bodies.state[s] != SlimeBodies.SLEEPER and bodies.calm[s] == SlimeBodies.ACTIVE


## Checks `bodies` within the harness's tolerance, then exactly; one
## assertion each.
func _assert_equivalent(bodies: SlimeBodies, label: String) -> void:
	var problems := Eq.check(bodies, Eq.RINGS, label)
	assert_eq(problems, PackedStringArray(), "%s: %s" % [label, "\n".join(problems)])
	var exact := Eq.check(bodies, Eq.RINGS, label + " (exact)", Eq.EXACT)
	assert_eq(exact, PackedStringArray(), "%s: %s" % [label, "\n".join(exact)])


func test_rings_match_gdscript_in_every_scene_at_every_moment() -> void:
	if _pending():
		return
	for name in Eq.SCENES:
		for moment in _moments(Eq.scene(name)):
			var bodies := Eq.prepared(name, Eq.RINGS, moment[0], moment[1])
			_assert_equivalent(bodies, "%s, substep %d, iteration %d" % [name, moment[0], moment[1]])


## Three solver iterations per substep: the later iterations start from
## rings the earlier ones have already pulled in.
func test_rings_match_gdscript_with_more_iterations() -> void:
	if _pending():
		return
	for name in Eq.SCENES:
		var probe := Eq.scene(name)
		probe.iterations = 3
		var moments := _moments(probe)
		assert_eq(moments.size(), 6, "%s: 2 substeps x 3 iterations" % name)
		for moment in moments:
			var bodies := Eq.scene(name)
			bodies.iterations = 3
			assert_true(Eq.prepare(bodies, Eq.RINGS, moment[0], moment[1]))
			_assert_equivalent(bodies, "%s, 3 iterations, substep %d, iteration %d" % [name, moment[0], moment[1]])


## The scenes as built hold full (0) and MAX_DETAIL rings among the slimes
## the pass works on.
func test_the_scenes_hold_full_and_max_detail_rings() -> void:
	var levels := {}
	for name in Eq.SCENES:
		var bodies := Eq.prepared(name, Eq.RINGS)
		for s in bodies.slime_count:
			if _ringed(bodies, s):
				levels[bodies.detail[s]] = true
	assert_true(levels.has(0), "a full-detail ring is solved")
	assert_true(levels.has(SlimeBodies.MAX_DETAIL), "a detail-%d ring is solved" % SlimeBodies.MAX_DETAIL)


## Every crowd-detail level, each ring set to it before the tick: the area
## and shape constraints run on 6 to 18 points.
func test_rings_match_gdscript_at_every_detail_level() -> void:
	if _pending():
		return
	for name in [Eq.SYNTHETIC, Scenes.STRESS_MOVING]:
		for level in SlimeBodies.MAX_DETAIL + 1:
			for moment in [[0, 0], [1, 0]]:
				var bodies := Eq.scene(name)
				for s in bodies.slime_count:
					bodies.set_detail(bodies.id[s], level)
				assert_true(Eq.prepare(bodies, Eq.RINGS, moment[0], moment[1]))
				var solved := 0
				for s in bodies.slime_count:
					if _ringed(bodies, s) and bodies.detail[s] == level:
						solved += 1
				assert_gt(solved, 0, "%s: rings at detail %d are solved" % [name, level])
				_assert_equivalent(bodies, "%s, detail %d, substep %d" % [name, level, moment[0]])


func test_rings_match_gdscript_with_other_stiffnesses() -> void:
	if _pending():
		return
	for stiff in [[1.0, 0.2, 0.0], [0.3, 1.0, 1.0], [0.0, 0.0, 0.5]]:
		for name in [Eq.SYNTHETIC, Scenes.STRESS_MOVING]:
			var bodies := Eq.prepared(name, Eq.RINGS)
			bodies.edge_stiffness = stiff[0]
			bodies.area_stiffness = stiff[1]
			bodies.shape_stiffness = stiff[2]
			_assert_equivalent(bodies, "%s, stiffnesses %s" % [name, str(stiff)])


## Hand-made rings in an empty world: squashed (the Jacobi edge pass), one
## point dragged far out, two points on one spot (a zero-length edge), a
## ring collapsed onto one spot (no area gradient), one collapsed onto the
## origin (no best-fit rotation), one turned inside out (negative area), and
## one far from the origin (float rounding at large coordinates).
func test_rings_match_gdscript_on_degenerate_rings() -> void:
	if _pending():
		return
	var bodies := SlimeBodies.new(Rng.new(7))
	bodies.use_native(false)
	var ids := PackedInt32Array()
	for k in 7:
		ids.append(bodies.create(0, 1 + k % 3, Vector2(100.0 * k, -50.0), SlimeBodies.FREE))
	var points := func(k: int) -> Array:
		var s := bodies.index_of(ids[k])
		return range(bodies.first[s], bodies.first[s] + bodies.npts[s])
	var c0: Vector2 = bodies.centre_of(ids[0])
	for i in points.call(0):
		bodies.pos[i] = c0 + (bodies.pos[i] - c0) * Vector2(1.6, 0.3)
	var far: int = points.call(1)[3]
	bodies.pos[far] += Vector2(80.0, -45.0)
	var pair: Array = points.call(2)
	bodies.pos[pair[1]] = bodies.pos[pair[0]]
	for i in points.call(3):
		bodies.pos[i] = Vector2(310.0, -40.0)
	for i in points.call(4):
		bodies.pos[i] = Vector2.ZERO
	var ring: Array = points.call(5)
	var reversed := PackedVector2Array()
	for i in ring:
		reversed.append(bodies.pos[i])
	reversed.reverse()
	for k in ring.size():
		bodies.pos[ring[k]] = reversed[k]
	for i in points.call(6):
		bodies.pos[i] += Vector2(48000.0, -9000.0)
	_assert_equivalent(bodies, "degenerate rings")


## Sleepers, resting and parked slimes keep their points bit for bit; the
## centre cache (_centre_cache, _centre_ok) stays as it was, valid flags and
## stale centres included, as the GDScript pass leaves it.
func test_skipped_slimes_and_the_centre_cache_are_left_alone() -> void:
	if _pending():
		return
	var bodies := Eq.prepared(Eq.SYNTHETIC, Eq.RINGS)
	for s in range(0, bodies.slime_count, 2):
		bodies.centre_of(bodies.id[s])
	assert_gt(bodies._centre_ok.count(1), 0, "some centres are cached")
	var before := Eq.clone(bodies)
	var after := Eq.clone(bodies)
	assert_true(Eq.run_phase(after, Eq.RINGS, Eq.NATIVE))
	assert_eq(after._centre_cache, before._centre_cache, "the centre cache is untouched")
	assert_eq(after._centre_ok, before._centre_ok, "the centre flags are untouched")
	var kinds := {"sleeper": 0, "resting": 0, "parked": 0}
	var moved := 0
	for s in bodies.slime_count:
		var f := bodies.first[s]
		var same := after.pos.slice(f, f + bodies.npts[s]) == before.pos.slice(f, f + bodies.npts[s])
		if _ringed(bodies, s):
			moved += 0 if same else 1
			continue
		if bodies.state[s] == SlimeBodies.SLEEPER:
			kinds["sleeper"] += 1
		elif bodies.calm[s] == SlimeBodies.RESTING:
			kinds["resting"] += 1
		else:
			kinds["parked"] += 1
		assert_true(same, "slime index %d (%s) keeps its points" % [s, bodies.STATE_NAMES[bodies.state[s]]])
	for kind in kinds:
		assert_gt(kinds[kind], 0, "a %s slime is skipped" % kind)
	assert_gt(moved, 0, "the pass moves the awake rings")
	var problems := Eq.check(bodies, Eq.RINGS, "synthetic, cached centres", {"_centre_cache": 0.0})
	assert_eq(problems, PackedStringArray(), "\n".join(problems))


func test_native_twice_is_bit_equal() -> void:
	if _pending():
		return
	for name in Eq.SCENES:
		for moment in _moments(Eq.scene(name)):
			var bodies := Eq.prepared(name, Eq.RINGS, moment[0], moment[1])
			var label := "%s, substep %d" % [name, moment[0]]
			var problems := Eq.check_kinds(bodies, Eq.RINGS, label, Eq.NATIVE, Eq.NATIVE, Eq.EXACT)
			assert_eq(problems, PackedStringArray(), "%s: %s" % [label, "\n".join(problems)])
