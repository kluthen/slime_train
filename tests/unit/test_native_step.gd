extends GutTest
## The native step (SlimeSolver.step, chunk 5N U6): the whole solver part of
## a tick in one call, against the GDScript one (SlimeBodies._solve), on the
## equivalence harness (tests/unit/native_equivalence_support.gd): every
## scene for consecutive ticks, each copy run on its own (so the
## trajectories, not one tick, are compared), every field exactly (the
## touching list and the cleared centre cache included); two native runs
## bit-equal; bodies it can't read refused before anything is written, and
## then the tick run pass by pass (the per-tick fallback), which still gives
## the GDScript tick. Pending when the run asked for the GDScript tick
## without the extension (SLIME_TICK=gdscript); failing otherwise.
# @test-link [[req_slime_states]]
# @test-link [[req_offscreen_simulation]]

const Eq := preload("res://tests/unit/native_equivalence_support.gd")
const DT := 1.0 / 60.0
## Consecutive ticks each scene runs.
const TICKS := 30
## A square door far from every slime of the synthetic scene.
const FAR_DOOR := [Vector2(50000, 0), Vector2(50100, 0), Vector2(50100, 100), Vector2(50000, 100)]


## A new solver, or null after marking the test pending (SLIME_TICK=gdscript
## without the extension) or failing it (the extension didn't load).
func _solver() -> Object:
	if ClassDB.class_exists(TickChoice.SOLVER_CLASS):
		return ClassDB.instantiate(TickChoice.SOLVER_CLASS)
	if OS.get_environment(TickChoice.ENV) == TickChoice.GDSCRIPT:
		pending("SLIME_TICK=gdscript and the slime_native extension isn't loaded")
	else:
		fail_test("SlimeSolver is not registered: the slime_native extension didn't load")
	return null


## Fills every slime's centre cache (as a reader of centre_of() between
## ticks does), so a tick must clear it.
func _warm_centre_cache(bodies: SlimeBodies) -> void:
	for slime_id in bodies.ids():
		bodies.centre_of(slime_id)


## One tick of `bodies` with its solver part run by `solver`'s step()
## (null: the GDScript _solve). False when step() didn't run.
func _tick(bodies: SlimeBodies, solver: Object) -> bool:
	_warm_centre_cache(bodies)
	# The tick's start, as tick() runs it (the substep length, the hops, the
	# support reset), and no pass.
	if not Eq.prepare(bodies, Eq.INTEGRATE):
		return false
	if solver == null:
		bodies._solve(null)
		return true
	return solver.step(bodies, bodies._h)


## step() against _solve() on every scene for TICKS consecutive ticks, each
## copy run on its own, every field exact (the GDScript passes' scratch
## aside: the native solver keeps its own).
func test_step_matches_the_gdscript_solve_exactly_tick_after_tick() -> void:
	var solver := _solver()
	if solver == null:
		return
	for name in Eq.SCENES:
		var gdscript := Eq.scene(name)
		var native := Eq.scene(name)
		for t in TICKS:
			_tick(gdscript, null)
			assert_true(_tick(native, solver), "%s, tick %d: step ran" % [name, t])
			var label := "%s, tick %d" % [name, t]
			var problems := Eq.compare(gdscript, native, label, Eq.EXACT, Eq.SCRATCH, ["gdscript", "native"])
			if not problems.is_empty():
				fail_test("\n".join(problems))
				break
		assert_eq(native._centre_ok.count(1), 0, "%s: the centre cache cleared" % name)
		assert_eq(native._touching, gdscript._touching, "%s: the touching list" % name)
		gut.p("%s: %d ticks, %d touching pairs at the end" % [name, TICKS, native._touching.size()])


## Two copies of each scene run TICKS ticks of step(): the same state, bit
## for bit, every field.
func test_two_native_runs_are_bit_equal() -> void:
	var solver := _solver()
	if solver == null:
		return
	for name in Eq.SCENES:
		var a := Eq.scene(name)
		var b := Eq.scene(name)
		for t in TICKS:
			assert_true(_tick(a, solver) and _tick(b, solver), "%s, tick %d: step ran" % [name, t])
		var problems := Eq.compare(a, b, name, Eq.EXACT, PackedStringArray(), ["native 1", "native 2"])
		assert_eq(problems, PackedStringArray(), "\n".join(problems))


## Every field of `after` is `before`'s, bit for bit (a NaN included).
func _assert_unchanged(before: SlimeBodies, after: SlimeBodies, label: String) -> void:
	var problems := Eq.compare(before, after, label, Eq.EXACT, PackedStringArray(["pos"]), ["before", "after"])
	assert_eq(problems, PackedStringArray(), "\n".join(problems))
	assert_eq(var_to_bytes(after.pos), var_to_bytes(before.pos), label + ": pos, bit for bit")


## A slime index of `bodies` that simulates (active, not a sleeper).
func _a_mover(bodies: SlimeBodies) -> int:
	for s in bodies.slime_count:
		if bodies.calm[s] == SlimeBodies.ACTIVE and bodies.state[s] != SlimeBodies.STATE_SLEEPER:
			return s
	return -1


## Bodies step() can't read, before its passes (a per-slime array of
## another size) and in the middle of the tick (a point turned NaN: the pair
## grid can't hold its centre, after integrate ran): refused with an error,
## and nothing reaches the bodies.
func test_step_refuses_what_it_cant_read_and_writes_nothing() -> void:
	var solver := _solver()
	if solver == null:
		return
	var bodies := Eq.scene(Eq.SYNTHETIC)
	assert_true(Eq.prepare(bodies, Eq.INTEGRATE))
	var short_centre := Eq.clone(bodies)
	short_centre.centre.resize(short_centre.slime_count - 1)
	var before := Eq.clone(short_centre)
	assert_false(solver.step(short_centre, short_centre._h), "a short centre array is refused")
	assert_engine_error("per-slime array")
	_assert_unchanged(before, short_centre, "short centre")

	var mover := _a_mover(bodies)
	assert_gt(mover, -1, "the synthetic scene has a mover")
	var nan_point := Eq.clone(bodies)
	nan_point.pos[nan_point.first[mover]] = Vector2(NAN, NAN)
	before = Eq.clone(nan_point)
	assert_false(solver.step(nan_point, nan_point._h), "a NaN centre is refused by the pair grid")
	assert_engine_error("isn't finite")
	_assert_unchanged(before, nan_point, "NaN point")


## The per-tick fallback: a shut door whose grid the native solver can't
## read (its cell starts cut short), far from every slime. step() refuses
## it, so tick() runs the passes one by one: the native ones run, but the
## terrain pass, which refuses it too and is replaced by the GDScript pass
## (whose door passes skip it: no slime's box is near). The tick is the
## GDScript tick, exactly.
func test_a_refused_step_falls_back_to_the_passes_one_by_one() -> void:
	if _solver() == null:
		return
	var reference := Eq.scene(Eq.SYNTHETIC)
	var door := TerrainSegments.new([PackedVector2Array(FAR_DOOR)])
	door.cell_start = PackedInt32Array([0])
	reference.doors.append(door)
	var fallback := Eq.clone(reference)
	assert_true(fallback.use_native(true))
	reference.tick(DT)
	fallback.tick(DT)
	# step() once, then the native terrain pass at every iteration.
	assert_engine_error_count(1 + fallback.substeps * fallback.iterations)
	var problems := Eq.compare(reference, fallback, "a door the solver can't read", Eq.EXACT, Eq.SCRATCH,
			["gdscript", "fallback"])
	assert_eq(problems, PackedStringArray(), "\n".join(problems))
