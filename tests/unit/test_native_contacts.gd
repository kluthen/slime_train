extends GutTest
## The native pair grid and slime contacts (SlimeSolver.build_pairs and
## solve_contacts, native/slime_native/src/solver_contacts.cpp, chunk 5N unit
## U2) against the GDScript passes (SlimeBodies._build_pairs and
## _solve_contacts) through the equivalence harness
## (tests/unit/native_equivalence_support.gd): every scene at several
## moments (ticks in, substeps, a second solver iteration); the pair list
## exactly, in order, with the last-mover cut, the wall-wall exclusion and
## too few slimes in the grid; the touching pairs and the support exactly;
## momentum kept by the native contacts; a tick walked with one pass native
## and the other in GDScript (as SlimeBodies._solve mixes them); a bodies the
## native contacts can't rely on refused untouched; two native runs bit for
## bit; rings deep inside each other (O91) exactly.

# @test-link [[req_waking_sleepers]]

const Eq := preload("res://tests/unit/native_equivalence_support.gd")
const Scenes := preload("res://tests/unit/native_equivalence_scenes.gd")

## Ticks run (in GDScript) on a scene before the pass, for more moments.
const TICKS_IN: Array[int] = [0, 2]
## How far momentum (the sum over every point of its move, px) may drift in
## a pass of contacts between two active slimes near the origin, where a
## float32 position rounds to about 4e-6 px.
const MOMENTUM_TOLERANCE := 1e-4


## A copy of the scene `name`, `ticks` ticks on (GDScript), brought to the
## moment `phase` runs in `substep` and `iteration` (see Eq.prepared()).
func _moment(name: String, ticks: int, phase: String, substep := 0, iteration := 0) -> SlimeBodies:
	var bodies := Eq.scene(name)
	for t in ticks:
		bodies.tick(Eq.DT)
	if not Eq.prepare(bodies, phase, substep, iteration):
		return null
	return bodies


## Whether slime index `s` of `bodies` is a wall in the contacts.
func _is_wall(bodies: SlimeBodies, s: int) -> bool:
	return bodies.state[s] == SlimeBodies.STATE_SLEEPER or bodies.calm[s] == SlimeBodies.RESTING


## The highest index of a slime in the pair grid that isn't a wall (-1: none).
func _last_mover(bodies: SlimeBodies) -> int:
	var last := -1
	for s in bodies.slime_count:
		if bodies.calm[s] == SlimeBodies.ACTIVE and bodies.state[s] != SlimeBodies.STATE_SLEEPER:
			last = s
	return last


## A copy of `bodies` after its pass `phase` run by `kind`.
func _after(bodies: SlimeBodies, phase: String, kind: String) -> SlimeBodies:
	var copy := Eq.clone(bodies)
	assert_true(Eq.run_phase(copy, phase, kind), "the %s %s pass runs" % [kind, phase])
	return copy


## What the points of `after` moved from `before`, summed in double
## precision: x and y, the sum of the moves; z, the sum of their lengths.
func _moves(before: PackedVector2Array, after: PackedVector2Array) -> Vector3:
	var x := 0.0
	var y := 0.0
	var travel := 0.0
	for i in before.size():
		var move := after[i] - before[i]
		x += move.x
		y += move.y
		travel += move.length()
	return Vector3(x, y, travel)


## One tick of `bodies` walked pass by pass as SlimeBodies._solve() does,
## each pass of `native` (phases) on the native solver, the others in
## GDScript. Returns false (after failing the test) when a native pass
## doesn't run.
func _walk(bodies: SlimeBodies, native: PackedStringArray) -> bool:
	# Tick()'s start: the substep length, the hops, the support reset.
	if not Eq.prepare(bodies, Eq.INTEGRATE):
		return false
	for step in Eq.tick_steps(bodies):
		var phase: String = step[0]
		if phase == Eq.REST:
			bodies._centre_ok.fill(0)
			bodies._touching.clear()
			for k in bodies._pair_touch.size():
				if bodies._pair_touch[k] != 0:
					bodies._touching.append(Vector2i(bodies.id[bodies._pairs[2 * k]], bodies.id[bodies._pairs[2 * k + 1]]))
		var kind := Eq.NATIVE if phase in native else Eq.GDSCRIPT
		if not Eq.run_phase(bodies, phase, kind):
			fail_test("the %s %s pass didn't run" % [kind, phase])
			return false
	return true


func test_the_pair_grid_matches_gdscript_exactly_in_every_scene() -> void:
	var why := Eq.skip_reason(Eq.BUILD_PAIRS)
	if why != "":
		pending(why)
		return
	for name in Eq.SCENES:
		for ticks in TICKS_IN:
			var bodies := _moment(name, ticks, Eq.BUILD_PAIRS)
			assert_not_null(bodies, "%s, %d ticks in prepares" % [name, ticks])
			if bodies == null:
				continue
			var problems := Eq.check(bodies, Eq.BUILD_PAIRS, "%s, %d ticks in" % [name, ticks], Eq.EXACT)
			assert_eq(problems, PackedStringArray(), "\n".join(problems))
	# The scenes pair something (and stress-still, all walls, nothing).
	assert_gt(_after(Eq.prepared(Scenes.STRESS_MOVING, Eq.BUILD_PAIRS), Eq.BUILD_PAIRS, Eq.NATIVE)._pairs.size(), 0)
	assert_eq(_after(Eq.prepared(Scenes.STRESS_STILL, Eq.BUILD_PAIRS), Eq.BUILD_PAIRS, Eq.NATIVE)._pairs.size(), 0)


## The scan stops at the last mover: with the last slimes walls (the
## dropped slime made a sleeper, the one before it resting), no pair holds a
## slime after it, two walls are never paired, and the list is GDScript's.
func test_the_last_mover_cut_and_the_wall_wall_exclusion() -> void:
	var why := Eq.skip_reason(Eq.BUILD_PAIRS)
	if why != "":
		pending(why)
		return
	var bodies := Eq.prepared(Eq.SYNTHETIC, Eq.BUILD_PAIRS)
	var last := bodies.slime_count - 1
	bodies.state[last] = SlimeBodies.STATE_SLEEPER
	bodies.calm[last - 1] = SlimeBodies.RESTING
	var mover := _last_mover(bodies)
	assert_lt(mover, last - 1, "the last two slimes are walls")
	assert_gte(mover, 0, "an active slime is left")
	var problems := Eq.check(bodies, Eq.BUILD_PAIRS, "synthetic, walls last", Eq.EXACT)
	assert_eq(problems, PackedStringArray(), "\n".join(problems))
	var after := _after(bodies, Eq.BUILD_PAIRS, Eq.NATIVE)
	var walls_paired := 0
	var wall_pairs := 0
	for k in after._pairs.size() / 2:
		var s := after._pairs[2 * k]
		var t := after._pairs[2 * k + 1]
		assert_lt(s, t, "pair %d: index a < index b" % k)
		assert_lte(s, mover, "pair %d: a is at most the last mover" % k)
		if _is_wall(after, s) and _is_wall(after, t):
			walls_paired += 1
		if _is_wall(after, s) or _is_wall(after, t):
			wall_pairs += 1
	assert_gt(after._pairs.size(), 0, "slimes are paired")
	assert_gt(wall_pairs, 0, "a slime is paired with a wall")
	assert_eq(walls_paired, 0, "two walls are never paired")
	assert_eq(after._pair_touch.size(), after._pairs.size() / 2, "one touch per pair")
	assert_false(after._pair_touch.has(1), "the touches are cleared")
	# Every slime a wall: no last mover, no pair.
	var walls := Eq.prepared(Eq.SYNTHETIC, Eq.BUILD_PAIRS)
	for s in walls.slime_count:
		if walls.calm[s] == SlimeBodies.ACTIVE:
			walls.state[s] = SlimeBodies.STATE_SLEEPER
	problems = Eq.check(walls, Eq.BUILD_PAIRS, "synthetic, all walls", Eq.EXACT)
	assert_eq(problems, PackedStringArray(), "\n".join(problems))
	assert_eq(_after(walls, Eq.BUILD_PAIRS, Eq.NATIVE)._pairs.size(), 0, "walls only: no pair")


## Fewer than two slimes in the grid (the rest parked): no pair, and the
## touches of the last list are dropped; a stale list is replaced.
func test_too_few_slimes_in_the_grid_and_a_stale_list() -> void:
	var why := Eq.skip_reason(Eq.BUILD_PAIRS)
	if why != "":
		pending(why)
		return
	var bodies := Eq.prepared(Eq.SYNTHETIC, Eq.BUILD_PAIRS)
	for s in range(1, bodies.slime_count):
		bodies.calm[s] = SlimeBodies.PARKED
	bodies._pairs = PackedInt32Array([0, 1, 0, 2])
	bodies._pair_touch = PackedByteArray([1, 1])
	var problems := Eq.check(bodies, Eq.BUILD_PAIRS, "synthetic, one slime placed", Eq.EXACT)
	assert_eq(problems, PackedStringArray(), "\n".join(problems))
	var after := _after(bodies, Eq.BUILD_PAIRS, Eq.NATIVE)
	assert_eq(after._pairs, PackedInt32Array())
	assert_eq(after._pair_touch, PackedByteArray())
	# A stale list (another tick's, touches set) gives way to the new one.
	var stale := Eq.prepared(Scenes.STRESS_MOVING, Eq.BUILD_PAIRS)
	stale._pairs = PackedInt32Array([3, 4])
	stale._pair_touch = PackedByteArray([1])
	problems = Eq.check(stale, Eq.BUILD_PAIRS, "stress-moving, a stale list", Eq.EXACT)
	assert_eq(problems, PackedStringArray(), "\n".join(problems))


func test_the_contacts_match_gdscript_in_every_scene_at_every_substep() -> void:
	var why := Eq.skip_reason(Eq.CONTACTS)
	if why != "":
		pending(why)
		return
	for name in Eq.SCENES:
		for ticks in TICKS_IN:
			for sub in Eq.scene(name).substeps:
				var bodies := _moment(name, ticks, Eq.CONTACTS, sub)
				assert_not_null(bodies, "%s, %d ticks in, substep %d prepares" % [name, ticks, sub])
				if bodies == null:
					continue
				var label := "%s, %d ticks in, substep %d" % [name, ticks, sub]
				var problems := Eq.check(bodies, Eq.CONTACTS, label)
				assert_eq(problems, PackedStringArray(), "\n".join(problems))


## A second solver iteration: the contacts run again on the pushed points,
## with the touches of the first iteration set.
func test_the_contacts_match_gdscript_in_a_second_iteration() -> void:
	var why := Eq.skip_reason(Eq.CONTACTS)
	if why != "":
		pending(why)
		return
	for name in Eq.SCENES:
		var bodies := Eq.scene(name)
		bodies.iterations = 2
		assert_true(Eq.prepare(bodies, Eq.CONTACTS, 1, 1), "%s prepares" % name)
		var problems := Eq.check(bodies, Eq.CONTACTS, "%s, substep 1, iteration 1" % name)
		assert_eq(problems, PackedStringArray(), "\n".join(problems))


## The touching pairs and the support compare exactly (check() does), and
## the scenes give both: the comparison compares something.
func test_the_touches_and_the_support_are_exact_and_present() -> void:
	var why := Eq.skip_reason(Eq.CONTACTS)
	if why != "":
		pending(why)
		return
	for name in [Eq.SYNTHETIC, Scenes.STRESS_MOVING, Scenes.S3_BASKET]:
		var bodies := Eq.prepared(name, Eq.CONTACTS)
		var touch_before := bodies._pair_touch.count(1)
		var supported_before := bodies.supported.count(1)
		var native := _after(bodies, Eq.CONTACTS, Eq.NATIVE)
		var gdscript := _after(bodies, Eq.CONTACTS, Eq.GDSCRIPT)
		assert_gt(native._pair_touch.count(1), touch_before, "%s: the pass finds touching pairs" % name)
		assert_gt(native.supported.count(1), supported_before, "%s: the pass finds support" % name)
		assert_eq(native._pair_touch, gdscript._pair_touch, "%s: the same touching pairs" % name)
		assert_eq(native.supported, gdscript.supported, "%s: the same support" % name)


## Between two active slimes a contact moves the points of one out and the
## whole of the other back by the same total, and the friction drags them
## alike: the pass keeps momentum (the sum of the positions and of the
## previous positions). Two slimes pressed together near the origin keep it
## within the float32 rounding of their points; in the scenes (points
## thousands of px out, where the rounding of every write adds up to a few
## hundredths) the native pass moves the sums as the GDScript pass does,
## within the harness tolerance.
func test_the_native_contacts_keep_momentum_between_active_slimes() -> void:
	var why := Eq.skip_reason(Eq.CONTACTS)
	if why != "":
		pending(why)
		return
	var pair := SlimeBodies.new(Rng.new(5))
	pair.use_native(false)
	pair.auto_hops = false
	pair.create(1, 2, Vector2.ZERO, SlimeBodies.STATE_FREE)
	pair.create(1, 3, Vector2(30.0, -6.0), SlimeBodies.STATE_FREE)
	assert_true(Eq.prepare(pair, Eq.CONTACTS))
	var pressed := _after(pair, Eq.CONTACTS, Eq.NATIVE)
	assert_eq(pressed._pair_touch, PackedByteArray([1]), "the two slimes touch")
	for field in ["pos", "prev"]:
		var moves := _moves(pair.get(field), pressed.get(field))
		assert_gt(moves.z, 1.0, "the contact moves the %s of the points" % field)
		assert_lt(Vector2(moves.x, moves.y).length(), MOMENTUM_TOLERANCE, "the sum of %s is kept" % field)
	var problems := Eq.check(pair, Eq.CONTACTS, "two slimes pressed together")
	assert_eq(problems, PackedStringArray(), "\n".join(problems))
	for name in [Scenes.STRESS_MOVING, Scenes.S3_BASKET, Eq.SYNTHETIC]:
		var bodies := Eq.prepared(name, Eq.CONTACTS)
		# Only the pairs of two active slimes (no wall takes a push).
		var kept := PackedInt32Array()
		for k in bodies._pairs.size() / 2:
			var s := bodies._pairs[2 * k]
			var t := bodies._pairs[2 * k + 1]
			if not _is_wall(bodies, s) and not _is_wall(bodies, t):
				kept.append(s)
				kept.append(t)
		bodies._pairs = kept
		bodies._pair_touch = PackedByteArray()
		bodies._pair_touch.resize(kept.size() / 2)
		bodies._pair_touch.fill(0)
		var native := _after(bodies, Eq.CONTACTS, Eq.NATIVE)
		var gdscript := _after(bodies, Eq.CONTACTS, Eq.GDSCRIPT)
		assert_gt(native._pair_touch.count(1), 0, "%s: active slimes touch" % name)
		for field in ["pos", "prev"]:
			var moves_native := _moves(bodies.get(field), native.get(field))
			var moves_gdscript := _moves(bodies.get(field), gdscript.get(field))
			assert_gt(moves_native.z, 0.0, "%s: the contacts move %s" % [name, field])
			var net_gap := Vector2(moves_native.x - moves_gdscript.x, moves_native.y - moves_gdscript.y)
			assert_lt(net_gap.length(), Eq.DEFAULT_TOLERANCE, "%s: the native and GDScript sums of %s agree" % [name, field])
		problems = Eq.check(bodies, Eq.CONTACTS, "%s, active pairs only" % name)
		assert_eq(problems, PackedStringArray(), "\n".join(problems))


## SlimeBodies._solve() mixes native and GDScript passes (a native pass that
## doesn't run falls back): a tick walked with the native pair grid and the
## GDScript contacts is the GDScript tick exactly (the pair list is the
## same); with the GDScript pair grid and the native contacts, and with both
## native, it is within the tolerance (the discrete fields exactly).
func test_a_tick_mixing_native_and_gdscript_passes() -> void:
	for phase in [Eq.BUILD_PAIRS, Eq.CONTACTS]:
		var why := Eq.skip_reason(phase)
		if why != "":
			pending(why)
			return
	var mixes := [
		[PackedStringArray([Eq.BUILD_PAIRS]), Eq.EXACT],
		[PackedStringArray([Eq.CONTACTS]), {}],
		[PackedStringArray([Eq.BUILD_PAIRS, Eq.CONTACTS]), {}],
	]
	for name in Eq.SCENES:
		var reference := Eq.scene(name)
		if not _walk(reference, PackedStringArray()):
			return
		for mix in mixes:
			var native: PackedStringArray = mix[0]
			var bodies := Eq.scene(name)
			if not _walk(bodies, native):
				return
			var label := "%s, a tick with native %s" % [name, ", ".join(native)]
			var problems := Eq.compare(reference, bodies, label, mix[1], Eq.SCRATCH, ["gdscript", "mixed"])
			assert_eq(problems, PackedStringArray(), "\n".join(problems))


## Bodies the native contacts can't rely on (a touch list that doesn't match
## the pair list, a pair index out of range): the pass refuses them with an
## error and writes nothing, so SlimeBodies runs its GDScript pass.
func test_the_native_contacts_refuse_bodies_they_cant_rely_on() -> void:
	var why := Eq.skip_reason(Eq.CONTACTS)
	if why != "":
		pending(why)
		return
	var bodies := Eq.prepared(Eq.SYNTHETIC, Eq.CONTACTS)
	var short_touch := Eq.clone(bodies)
	short_touch._pair_touch.resize(short_touch._pair_touch.size() - 1)
	assert_false(Eq.run_phase(short_touch, Eq.CONTACTS, Eq.NATIVE), "a short _pair_touch is refused")
	assert_engine_error("_pair_touch")
	var out_of_range := Eq.clone(bodies)
	out_of_range._pairs[1] = out_of_range.slime_count
	assert_false(Eq.run_phase(out_of_range, Eq.CONTACTS, Eq.NATIVE), "a pair index out of range is refused")
	assert_engine_error("_pairs")
	for refused in [short_touch, out_of_range]:
		assert_eq(refused.pos, bodies.pos, "nothing written")
		assert_eq(refused.prev, bodies.prev, "nothing written")
		assert_eq(refused.supported, bodies.supported, "nothing written")


## Two native runs of each pass give the same state, bit for bit.
func test_two_native_runs_are_bit_equal() -> void:
	for phase in [Eq.BUILD_PAIRS, Eq.CONTACTS]:
		var why := Eq.skip_reason(phase)
		if why != "":
			pending(why)
			return
		for name in Eq.SCENES:
			for sub in (Eq.scene(name).substeps if phase == Eq.CONTACTS else 1):
				var bodies := Eq.prepared(name, phase, sub)
				var label := "%s, substep %d" % [name, sub]
				var problems := Eq.check_kinds(bodies, phase, label, Eq.NATIVE, Eq.NATIVE, Eq.EXACT)
				assert_eq(problems, PackedStringArray(), "\n".join(problems))


## Rings deep inside each other (O91): a point of one ring past the other's
## centre is pushed back out on its own side (SlimeBodies._solve_contacts).
## The native contacts do it bit for bit, at every substep, as the rings
## part a few ticks in. Pairs of other species, one centre a share of the
## smaller radius from the other, far apart from the next pair.
func test_the_contacts_match_gdscript_exactly_for_rings_deep_inside_each_other() -> void:
	var why := Eq.skip_reason(Eq.CONTACTS)
	if why != "":
		pending(why)
		return
	var source := SlimeBodies.new(Rng.new(5))
	source.use_native(false)
	source.gravity = Vector2.ZERO
	source.rest_enabled = false
	var x := 0.0
	for sizes: Vector2i in [Vector2i(1, 1), Vector2i(1, 3), Vector2i(2, 3), Vector2i(3, 3)]:
		var radius := minf(SlimeBodies.ring_radius_for(sizes.x), SlimeBodies.ring_radius_for(sizes.y))
		for depth in [0.1, 0.5, 0.9]:
			source.create(1, sizes.y, Vector2(x, 0.0), SlimeBodies.BEDTIME_ASLEEP)
			source.create(0, sizes.x, Vector2(x + depth * radius, 0.25), SlimeBodies.BEDTIME_ASLEEP)
			x += 400.0
	for ticks in [0, 1, 3]:
		for sub in source.substeps:
			var bodies := Eq.clone(source)
			for t in ticks:
				bodies.tick(Eq.DT)
			assert_true(Eq.prepare(bodies, Eq.CONTACTS, sub), "%d ticks in, substep %d prepares" % [ticks, sub])
			var label := "deep pairs, %d ticks in, substep %d" % [ticks, sub]
			var problems := Eq.check(bodies, Eq.CONTACTS, label, Eq.EXACT)
			assert_eq(problems, PackedStringArray(), "\n".join(problems))
