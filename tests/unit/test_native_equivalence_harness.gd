extends GutTest
## The native solver's equivalence harness itself
## (tests/unit/native_equivalence_support.gd, chunk 5N): its scenes hold
## what they promise; a pass run by GDScript on two copies compares exactly,
## in every scene, at every moment of a tick; its walk of a tick is tick();
## a difference is reported with its field, index and values; the copies
## share no array, and a native write reaches one copy only.

const Eq := preload("res://tests/unit/native_equivalence_support.gd")
const Scenes := preload("res://tests/unit/native_equivalence_scenes.gd")


## The slime indices of `bodies` in a pair of the pair grid (after a pass of
## build_pairs).
func _paired(bodies: SlimeBodies) -> Dictionary:
	var out := {}
	for s in bodies._pairs:
		out[s] = true
	return out


## How many points of slime index `s` lie within the skin of the terrain
## where their nearest terrain point is a segment's end (the terrain pass's
## vertex-normal case).
func _points_at_segment_ends(bodies: SlimeBodies, s: int) -> int:
	var tf := bodies.terrain
	var count := 0
	for i in range(bodies.first[s], bodies.first[s] + bodies.npts[s]):
		var c: Vector2 = bodies.pos[i]
		var best_d2 := INF
		var best_t := 0.5
		for k in tf.segment_count():
			var t := clampf((c - tf.seg_a[k]).dot(tf.seg_d[k]) * tf.seg_inv_len2[k], 0.0, 1.0)
			var d2 := c.distance_squared_to(tf.seg_a[k] + tf.seg_d[k] * t)
			if d2 < best_d2:
				best_d2 = d2
				best_t = t
		if best_d2 < bodies.terrain_skin * bodies.terrain_skin and (best_t <= 0.0 or best_t >= 1.0):
			count += 1
	return count


func test_the_scenes_hold_what_they_promise() -> void:
	for name in Eq.SCENES:
		var bodies := Eq.scene(name)
		assert_not_null(bodies, "%s builds" % name)
		if bodies == null:
			return
		assert_false(bodies.uses_native(), "%s: a copy is on the GDScript tick" % name)
		if name != Scenes.STRESS_STILL:
			assert_gt(bodies.crowd_count(), 0, "%s: some slimes simulate" % name)
	var still := Eq.scene(Scenes.STRESS_STILL)
	assert_eq(still.crowd_count(), 0, "stress-still: nothing simulates")
	assert_gte(still.calm.count(SlimeBodies.RESTING), 140, "stress-still: its pile rests")
	var gate := Eq.scene(Scenes.GATE2_OPEN)
	assert_true(gate.doors.any(func(door: TerrainSegments) -> bool: return not door.is_empty()),
			"gate2-open: a door is shut")
	var syn := Eq.scene(Eq.SYNTHETIC)
	var last := syn.slime_count - 1
	assert_eq(syn.state[last], SlimeBodies.FREE, "synthetic: the dropped slime is the last")
	assert_true(syn.detail.has(SlimeBodies.MAX_DETAIL), "synthetic: detail-3 rings")
	assert_true(syn.state.has(SlimeBodies.SLEEPER), "synthetic: a sleeper")
	assert_eq(syn.calm.count(SlimeBodies.RESTING), 6, "synthetic: the pile rests")
	assert_eq(syn.calm.count(SlimeBodies.PARKED), 2, "synthetic: two parked")
	assert_eq(syn.doors.size(), 3, "synthetic: three doors (shut, far, empty)")
	var touching := {}
	for pair in syn.touching_pairs():
		touching[pair.x] = touching.get(pair.x, 0) + 1
		touching[pair.y] = touching.get(pair.y, 0) + 1
	assert_true(touching.has(syn.id[0]), "synthetic: index 0 touches a slime")
	assert_true(touching.has(syn.id[8]) and touching.has(syn.id[9]), "synthetic: a slime on the sleepers")
	assert_true(touching.has(syn.id[Scenes.ON_SLEEPERS]), "synthetic: a slime on the sleepers")
	assert_true(touching.has(syn.id[Scenes.ON_PILE]), "synthetic: a slime on the pile")
	assert_gt(_points_at_segment_ends(Eq.prepared(Eq.SYNTHETIC, Eq.TERRAIN), Scenes.ON_CORNER), 0,
			"synthetic: a point on a segment's end, at the terrain pass")
	assert_true(_paired(Eq.prepared(Eq.SYNTHETIC, Eq.CONTACTS)).has(last), "synthetic: the last index is paired")


func test_gdscript_twice_compares_exactly_in_every_scene_and_phase() -> void:
	for name in Eq.SCENES:
		var steps: Array = Eq.tick_steps(Eq.scene(name))
		for step in steps:
			var bodies := Eq.prepared(name, step[0], step[1], step[2])
			var label := "%s, substep %d, iteration %d" % [name, step[1], step[2]]
			var problems := Eq.check_kinds(bodies, step[0], label, Eq.GDSCRIPT, Eq.GDSCRIPT, Eq.EXACT)
			assert_eq(problems, PackedStringArray(), "%s %s: %s" % [label, step[0], "\n".join(problems)])


## The synthetic scene exercises every pass: each one changes something, so
## comparing two runs of it compares something.
func test_every_pass_changes_the_synthetic_scene() -> void:
	for phase in Eq.PHASES:
		var before := Eq.prepared(Eq.SYNTHETIC, phase)
		var after := Eq.clone(before)
		assert_true(Eq.run_phase(after, phase, Eq.GDSCRIPT))
		var changes := Eq.compare(before, after, phase, Eq.EXACT, PackedStringArray())
		assert_gt(changes.size(), 0, "%s changes the synthetic scene" % phase)


## prepare() and the passes walk a tick as tick() does: the same state, bit
## for bit, every field (scratch and random streams included).
func test_walking_the_phases_is_one_tick() -> void:
	for name in Eq.SCENES:
		var ticked := Eq.scene(name)
		var walked := Eq.clone(ticked)
		for t in 3:
			ticked.tick(Eq.DT)
			Eq.tick_by_phases(walked)
		var problems := Eq.compare(ticked, walked, name, Eq.EXACT, PackedStringArray(), ["tick()", "walk"])
		assert_eq(problems, PackedStringArray(), "\n".join(problems))


func test_a_difference_is_reported_with_its_field_index_and_values() -> void:
	var a := Eq.scene(Eq.SYNTHETIC)
	var last := a.slime_count - 1
	var i := a.first[last] + 2
	var b := Eq.clone(a)
	b.pos[i] += Vector2(0.01, 0.0)
	var problems := Eq.compare(a, b, "synthetic", {}, Eq.SCRATCH, ["gdscript", "native"])
	assert_eq(problems.size(), 1, "\n".join(problems))
	var message := problems[0] if problems.size() == 1 else ""
	for part in ["synthetic: pos[%d]" % i, "slime index %d, id %d, point 2 of" % [last, a.id[last]],
			"gdscript (%.8f, %.8f)" % [a.pos[i].x, a.pos[i].y], "native (%.8f, %.8f)" % [b.pos[i].x, b.pos[i].y],
			"tolerance 0.00100000", "1 of %d differ" % a.pos.size()]:
		assert_string_contains(message, part)
	# Within the tolerance it is the same; a field's own tolerance overrides.
	var close := Eq.clone(a)
	close.pos[i] += Vector2(1e-4, 0.0)
	assert_eq(Eq.compare(a, close, "close"), PackedStringArray())
	assert_eq(Eq.compare(a, close, "close", {"pos": 1e-5}).size(), 1)
	assert_eq(Eq.compare(a, close, "close", Eq.EXACT).size(), 1)
	# A NaN never compares equal.
	var nan := Eq.clone(a)
	nan.pos[i] = Vector2(NAN, 0.0)
	assert_eq(Eq.compare(a, nan, "nan").size(), 1)
	# Discrete fields compare exactly.
	var calm := Eq.clone(a)
	calm.still_ticks[3] += 1
	var calm_problems := Eq.compare(a, calm, "still")
	assert_eq(calm_problems.size(), 1)
	assert_string_contains(calm_problems[0] if calm_problems.size() == 1 else "",
			"still: still_ticks[3] (slime index 3, id %d): a %d, b %d" % [a.id[3], a.still_ticks[3], calm.still_ticks[3]])
	var touching := Eq.clone(a)
	touching._touching.append(Vector2i(1, 2))
	assert_eq(Eq.compare(a, touching, "touching").size(), 1)
	# An angle compares wrapped: just under PI and just over -PI are close.
	var wrapped := Eq.clone(a)
	var angled := Eq.clone(a)
	wrapped.angle0[0] = PI - 1e-5
	angled.angle0[0] = -PI + 1e-5
	assert_eq(Eq.compare(wrapped, angled, "wrapped"), PackedStringArray())


func test_the_copies_share_no_array() -> void:
	var source := Eq.scene(Eq.SYNTHETIC)
	var copies := [Eq.clone(source), Eq.clone(source)]
	var written := 0
	for field in Eq.fields(source):
		var value: Variant = source.get(field)
		if field in ["terrain", "doors"] or not Eq.is_sequence(value):
			continue
		for copy in copies:
			assert_false(is_same(copy.get(field), value), "%s: a copy has its own array" % field)
		assert_false(is_same(copies[0].get(field), copies[1].get(field)), "%s: each copy its own" % field)
		if value.is_empty() or value[0] is Object:
			continue
		# A write into one copy's array, in place (GDScript shares the
		# array, as the passes write it): the other copy and the source keep
		# theirs.
		var array: Variant = copies[0].get(field)
		var kept: Variant = value[0]
		array[0] = Vector2i(-7, -7) if kept is Vector2i else (Vector2(-7, -7) if kept is Vector2 else 77)
		assert_ne(copies[0].get(field)[0], kept, "%s: written in place" % field)
		assert_eq(copies[1].get(field)[0], kept, "%s: the other copy keeps its value" % field)
		assert_eq(source.get(field)[0], kept, "%s: the source keeps its value" % field)
		written += 1
	assert_gt(written, 20, "every non-empty array written")
	# The terrain and the door pieces are shared (read only); the list of
	# doors is each copy's own.
	assert_true(is_same(copies[0].terrain, source.terrain))
	assert_true(is_same(copies[0].doors[0], source.doors[0]))
	copies[0].doors.clear()
	assert_eq(source.doors.size(), 3)
	# The random streams are copies at the same state.
	assert_false(is_same(copies[0]._streams[0], source._streams[0]))
	assert_eq(copies[0]._streams[0].state, source._streams[0].state)


func test_a_native_write_reaches_one_copy_only() -> void:
	if not ClassDB.class_exists(TickChoice.SOLVER_CLASS):
		if OS.get_environment(TickChoice.ENV) == TickChoice.GDSCRIPT:
			pending("SLIME_TICK=gdscript and the extension isn't loaded")
		else:
			fail_test("SlimeSolver is not registered: the slime_native extension didn't load")
		return
	var source := Eq.scene(Eq.SYNTHETIC)
	var a := Eq.clone(source)
	var b := Eq.clone(source)
	var solver: Object = ClassDB.instantiate(TickChoice.SOLVER_CLASS)
	assert_true(solver.probe_marshal(a, Vector2(1, 0)))
	var problems := Eq.compare(b, a, "probe", {}, Eq.SCRATCH, ["b", "a"])
	assert_eq(problems.size(), 2, "pos and prev moved in a: " + "\n".join(problems))
	assert_eq(Eq.compare(source, b, "source", Eq.EXACT, PackedStringArray()), PackedStringArray(),
			"b and the source unchanged")


func test_phase_supported_tells_whether_the_native_pass_runs() -> void:
	assert_false(Eq.phase_supported("no_such_pass"))
	assert_push_error("no phase 'no_such_pass'")
	for phase in Eq.PHASES:
		var runs := Eq.run_phase(Eq.prepared(Eq.SYNTHETIC, phase), phase, Eq.NATIVE)
		assert_eq(Eq.phase_supported(phase), runs, phase)
		if ClassDB.class_exists(TickChoice.SOLVER_CLASS):
			assert_eq(Eq.skip_reason(phase) == "", runs, "%s: pending exactly while a stub" % phase)


func test_prepare_refuses_a_moment_not_in_a_tick() -> void:
	var bodies := Eq.scene(Eq.SYNTHETIC)
	assert_false(Eq.prepare(bodies, Eq.BUILD_PAIRS, 1))
	assert_false(Eq.prepare(bodies, Eq.INTEGRATE, bodies.substeps))
	assert_false(Eq.prepare(bodies, Eq.REST, 1))
	assert_push_error_count(3, "a moment not in a tick")
