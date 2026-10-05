extends GutTest
## The native solver's boundary (SlimeSolver, chunk 5N, docs/dev/native.md):
## it reads and writes a SlimeBodies' arrays by name (a write reaches the
## GDScript arrays), it checks it can (check_schema), and SlimeBodies runs
## its GDScript pass wherever a native pass doesn't run (use_native). The
## native tick (SlimeSolver.step) gives the GDScript tick's results, bit for
## bit on the desktop. Pending when the run asked for the GDScript tick without the extension
## (SLIME_TICK=gdscript); failing otherwise.

const Support := preload("res://tests/unit/slime_test_support.gd")
const BODIES_SCRIPT := "res://src/sim/slime_bodies.gd"
## The lines of SlimeBodies._init that take the run's tick.
const TAKES_THE_RUN_TICK := "\tif TickChoice.current().native:\n\t\tuse_native(true)\n"


## A new solver, or null after failing the test (pending when the run asked
## for the GDScript tick).
func _solver_or_fail() -> Object:
	if ClassDB.class_exists(TickChoice.SOLVER_CLASS):
		return ClassDB.instantiate(TickChoice.SOLVER_CLASS)
	if OS.get_environment(TickChoice.ENV) == TickChoice.GDSCRIPT:
		pending("SLIME_TICK=gdscript and the extension isn't loaded")
	else:
		fail_test("SlimeSolver is not registered: the slime_native extension didn't load")
	return null


## Three slimes in a box, one asleep, after a few ticks: every array filled.
func _scene(master_seed := 1) -> SlimeBodies:
	var bodies := SlimeBodies.new(Rng.new(master_seed))
	bodies.terrain = TerrainSegments.new(Support.box_polygons(300.0))
	bodies.create(0, 1, Vector2(-60, -30))
	bodies.create(1, 2, Vector2(0, -80))
	bodies.create(2, 3, Vector2(70, -40), SlimeBodies.STATE_SLEEPER)
	return bodies


## SlimeBodies' script with `text` replaced by `replacement` everywhere (a
## field renamed or retyped, a constant changed, as a refactor would), on the
## GDScript tick: class_name dropped so it loads beside the real one, and its
## _init doesn't take the run's tick (so it pushes no error of its own).
func _bodies_with_renamed_field(text: String, replacement: String) -> Object:
	var source: String = (load(BODIES_SCRIPT) as GDScript).source_code
	assert_true(source.contains(text), "'%s' is in %s" % [text, BODIES_SCRIPT])
	assert_true(source.contains(TAKES_THE_RUN_TICK), "_init takes the run's tick")
	var script := GDScript.new()
	script.source_code = (source.replace("class_name SlimeBodies\n", "").replace(TAKES_THE_RUN_TICK, "")
			.replace(text, replacement))
	assert_eq(script.reload(), OK, "the changed script compiles")
	return script.new(Rng.new(1))


func test_native_write_reaches_the_gdscript_arrays() -> void:
	var solver := _solver_or_fail()
	if solver == null:
		return
	var bodies := _scene()
	bodies.tick(1.0 / 60.0)
	var before_pos := bodies.pos.duplicate()
	var before_prev := bodies.prev.duplicate()
	# A copy taken before the call: packed arrays are copy-on-write, so it
	# keeps the old values while the member gets the native ones.
	var alias := bodies.pos
	var delta := Vector2(3.0, -2.0)
	assert_true(solver.probe_marshal(bodies, delta))
	assert_eq(bodies.pos.size(), before_pos.size())
	var moved := 0
	for i in before_pos.size():
		if bodies.pos[i] == before_pos[i] + delta and bodies.prev[i] == before_prev[i] + delta:
			moved += 1
	assert_eq(moved, before_pos.size(), "every point moved by delta, read back in GDScript")
	assert_eq(alias, before_pos, "the copy taken before is unchanged")
	assert_eq(bodies.points_of(1)[0], before_pos[0] + delta, "the accessors see it")


func test_check_schema_passes_on_slime_bodies() -> void:
	var solver := _solver_or_fail()
	if solver == null:
		return
	var bodies := _scene()
	assert_eq(solver.check_schema(bodies), PackedStringArray(), "with a terrain")
	bodies.doors.append(TerrainSegments.new([Support.floor_polygon()]))
	assert_eq(solver.check_schema(bodies), PackedStringArray(), "with a door")
	assert_eq(solver.check_schema(SlimeBodies.new(Rng.new(2))), PackedStringArray(), "empty, no terrain")


func test_check_schema_fails_on_a_renamed_field() -> void:
	var solver := _solver_or_fail()
	if solver == null:
		return
	var renamed := _bodies_with_renamed_field("_drift", "_slide")
	var problems: PackedStringArray = solver.check_schema(renamed)
	assert_eq(problems, PackedStringArray(["_drift: missing (PackedVector2Array)"]))
	var rest_ticks := _bodies_with_renamed_field("REST_TICKS", "REST_COUNT")
	assert_eq(solver.check_schema(rest_ticks), PackedStringArray(["REST_TICKS: constant missing"]))


func test_check_schema_fails_on_a_retyped_field_and_a_changed_constant() -> void:
	var solver := _solver_or_fail()
	if solver == null:
		return
	var retyped := _bodies_with_renamed_field("var calm := PackedByteArray()", "var calm := PackedInt32Array()")
	assert_eq(solver.check_schema(retyped),
			PackedStringArray(["calm: PackedInt32Array, expected PackedByteArray"]))
	var changed := _bodies_with_renamed_field("const WAKE_SPEED := 30.0", "const WAKE_SPEED := 40.0")
	assert_eq(solver.check_schema(changed), PackedStringArray(["WAKE_SPEED: constant is 40.0, the solver has 30.0"]))


func test_check_schema_checks_the_terrain_fields() -> void:
	var solver := _solver_or_fail()
	if solver == null:
		return
	# A door of another class (the doors untyped to hold it): every
	# TerrainSegments field is missing.
	var bodies := _bodies_with_renamed_field("var doors: Array[TerrainSegments] = []", "var doors: Array = []")
	bodies.doors = [RefCounted.new()]
	var problems: PackedStringArray = solver.check_schema(bodies)
	assert_eq(problems.size(), 12, ", ".join(problems))
	assert_eq(problems[0], "doors[0].seg_a: missing (PackedVector2Array)")


func test_use_native_switches_the_tick() -> void:
	if _solver_or_fail() == null:
		return
	var bodies := _scene()
	assert_true(bodies.use_native(true))
	assert_true(bodies.uses_native())
	assert_true(bodies.use_native(false))
	assert_false(bodies.uses_native())


func test_use_native_refuses_bodies_the_solver_cant_read() -> void:
	if _solver_or_fail() == null:
		return
	var renamed := _bodies_with_renamed_field("_drift", "_slide")
	assert_false(renamed.uses_native())
	assert_false(renamed.use_native(true))
	assert_push_error("can't read these bodies")
	assert_false(renamed.uses_native(), "the GDScript tick runs on")


## The native tick (one SlimeSolver.step per tick) and the GDScript tick
## give the same state over 240 ticks, bit for bit (a door shut, a sleeper):
## every native pass is a line-for-line port, with the same float32/double
## split, compiled without fused multiply-adds (docs/dev/native.md).
func test_the_native_tick_gives_the_gdscript_tick_bit_for_bit() -> void:
	if _solver_or_fail() == null:
		return
	var on := _scene(7)
	var off := _scene(7)
	assert_true(on.use_native(true))
	assert_true(off.use_native(false))
	off.doors.append(TerrainSegments.new([Support.floor_polygon()]))
	on.doors.append(TerrainSegments.new([Support.floor_polygon()]))
	for t in 240:
		on.tick(1.0 / 60.0)
		off.tick(1.0 / 60.0)
	assert_eq(on.pos, off.pos)
	assert_eq(on.prev, off.prev)
	assert_eq(on.dump(), off.dump())
	assert_eq(on.touching_pairs(), off.touching_pairs())
