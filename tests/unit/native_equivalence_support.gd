extends RefCounted
## The native solver's equivalence harness (chunk 5N, docs/dev/native.md; not
## a test script: no test_ prefix). A native pass (SlimeSolver.integrate,
## build_pairs, solve_contacts, solve_rings, solve_terrain, rest) is checked
## against the GDScript pass tick() runs instead (SlimeBodies._integrate,
## _build_pairs, _solve_contacts, _solve_rings, _solve_terrain, _rest): two
## independent copies of the same bodies, at the moment of a tick when the
## pass runs, one pass each, then every field compared.
##
##   prepared(scene, phase, substep, iteration)  a copy of a scene
##       (native_equivalence_scenes.gd: SCENES) brought, in GDScript, to the
##       moment `phase` runs (tick()'s start, then the passes before it); a
##       test may change it (tilt, max_speed, rest_enabled...) before:
##   check(bodies, phase, label, tolerances)  copies `bodies` twice, runs the
##       GDScript pass on one and the native pass on the other, compares;
##       returns the problems, empty when equivalent;
##   check_kinds(bodies, phase, label, kind_a, kind_b, tolerances)  the same
##       for any two kinds: NATIVE twice with EXACT (repeatable), GDSCRIPT
##       twice with EXACT (the harness itself);
##   phase_supported(phase), skip_reason(phase)  whether the native pass runs
##       yet (a stub returns false): a test is pending until it does.
##
## Comparing (compare()): every script variable of SlimeBodies. CONTINUOUS
## fields within a tolerance (DEFAULT_TOLERANCE px; angle0 in radians, the
## difference wrapped), every other field exactly (the discrete ones, and the
## ones the solver only reads, which it must leave as they were). Per field,
## `tolerances` overrides it ({"pos": 1e-4}); "*" overrides the default of
## every continuous field (EXACT: {"*": 0.0}). A NaN never compares equal.
## SCRATCH (the GDScript passes' own scratch, which the native solver keeps
## apart) is left out of a GDScript-native comparison. One problem per field:
## the label, the field, the first index that differs (with its slime), both
## values, how many elements differ and the largest difference.
##
## Copies (clone()): every array duplicated; the terrain and the doors (each
## TerrainSegments) shared, read only; the random streams copied; on the
## GDScript tick.
##
## Running Godot from parallel agents (chunk 5N's wave 1): one Godot process
## at a time on this checkout. Run every Godot command (tools/test.sh, a
## fixture hash) under one shared lock file outside the repo, for example:
##   flock /tmp/slime_train-godot.lock <command>
## (tools/build_native.sh takes its own lock around SCons.)
##
## Example (a wave-1 test):
##   const Eq := preload("res://tests/unit/native_equivalence_support.gd")
##   func test_rings_match_gdscript() -> void:
##       var why := Eq.skip_reason(Eq.RINGS)
##       if why != "":
##           pending(why)
##           return
##       for scene in Eq.SCENES:
##           var bodies := Eq.prepared(scene, Eq.RINGS)
##           var problems := Eq.check(bodies, Eq.RINGS, scene)
##           assert_true(problems.is_empty(), "\n".join(problems))

const Scenes := preload("res://tests/unit/native_equivalence_scenes.gd")
const SCENES := Scenes.NAMES
const SYNTHETIC := Scenes.SYNTHETIC

## The passes, by SlimeSolver's method names, in tick order.
const INTEGRATE := "integrate"
const BUILD_PAIRS := "build_pairs"
const CONTACTS := "solve_contacts"
const RINGS := "solve_rings"
const TERRAIN := "solve_terrain"
const REST := "rest"
const PHASES: PackedStringArray = [INTEGRATE, BUILD_PAIRS, CONTACTS, RINGS, TERRAIN, REST]
## Which pass runs a phase.
const GDSCRIPT := "gdscript"
const NATIVE := "native"

const DEFAULT_TOLERANCE := 1e-3
const EXACT := {"*": 0.0}
## The fields compared within a tolerance (see the class doc).
const CONTINUOUS: PackedStringArray = ["pos", "prev", "centre", "angle0", "_drift", "rest_anchor", "_centre_cache"]
const ANGLES: PackedStringArray = ["angle0"]
## The GDScript passes' scratch (the pair grid, the terrain boxes).
const SCRATCH: PackedStringArray = ["_cell_size", "_grid_w", "_grid_h", "_grid_origin", "_cell_start",
		"_cell_items", "_slime_cell", "_box_lo", "_box_hi"]
## Never copied nor compared: the native solver and the debug phase timers.
const UNCOMPARED: PackedStringArray = ["_solver", "phases"]
## The per-point arrays (an index there is a point of a slime).
const POINT_FIELDS: PackedStringArray = ["pos", "prev", "rest_off"]
## The per-pair arrays (_pairs holds two slime indices per pair).
const PAIR_FIELDS: PackedStringArray = ["_pairs", "_pair_touch"]
const DT := 1.0 / Simulation.TICK_RATE

## phase_supported()'s answers, by phase.
static var _supported := {}


# --- Scenes and copies --------------------------------------------------------

## A fresh copy of the scene `name` (one of SCENES), at a tick boundary.
static func scene(name: String) -> SlimeBodies:
	var source := Scenes.source(name)
	return clone(source) if source != null else null


## A copy of the scene `name` at the moment `phase` runs in substep `substep`
## and solver iteration `iteration` of a tick (see prepare()).
static func prepared(name: String, phase: String, substep := 0, iteration := 0) -> SlimeBodies:
	var bodies := scene(name)
	if bodies != null and not prepare(bodies, phase, substep, iteration):
		return null
	return bodies


## A deep copy of `bodies` (see the class doc), on the GDScript tick.
static func clone(bodies: SlimeBodies) -> SlimeBodies:
	var copy := SlimeBodies.new(_rng_copy(bodies._master))
	copy.use_native(false)
	for field in fields(bodies):
		var value: Variant = bodies.get(field)
		match field:
			"_master":
				pass
			"terrain":
				copy.terrain = value
			"doors":
				copy.doors = bodies.doors.duplicate()
			"_streams":
				var streams: Array[Rng] = []
				for stream in bodies._streams:
					streams.append(_rng_copy(stream))
				copy._streams = streams
			_:
				if value is Object or typeof(value) == TYPE_DICTIONARY:
					push_error("native_equivalence_support: clone() doesn't know how to copy %s" % field)
				copy.set(field, value.duplicate() if is_sequence(value) else value)
	return copy


# --- Running a pass -----------------------------------------------------------

## Brings `bodies` to the moment `phase` runs in substep `substep` and
## iteration `iteration` of a tick, in GDScript: tick()'s start (the substep
## length, the hops, the support reset), the passes before it, and for REST
## the touching list (as _solve() does). BUILD_PAIRS runs in substep 0 only,
## REST once (substep and iteration 0). False, with an error, for a moment
## that isn't in a tick.
static func prepare(bodies: SlimeBodies, phase: String, substep := 0, iteration := 0) -> bool:
	var steps := tick_steps(bodies)
	var at := steps.find([phase, substep, iteration])
	if at < 0:
		push_error("native_equivalence_support: no %s in substep %d, iteration %d of a tick (substeps %d, iterations %d)"
				% [phase, substep, iteration, bodies.substeps, bodies.iterations])
		return false
	bodies._h = DT / bodies.substeps
	bodies.hopped.clear()
	bodies.train_hopped.clear()
	if bodies.auto_hops:
		bodies._auto_hops(DT)
	for s in bodies.slime_count:
		if bodies.calm[s] == SlimeBodies.ACTIVE:
			bodies.supported[s] = 0
	for k in at:
		run_phase(bodies, steps[k][0], GDSCRIPT)
	if phase == REST:
		bodies._centre_ok.fill(0)
		bodies._touching.clear()
		for k in bodies._pair_touch.size():
			if bodies._pair_touch[k] != 0:
				bodies._touching.append(Vector2i(bodies.id[bodies._pairs[2 * k]], bodies.id[bodies._pairs[2 * k + 1]]))
	return true


## One whole tick of `bodies` through prepare() and the GDScript passes: the
## harness's own walk of a tick, which must give tick()'s state.
static func tick_by_phases(bodies: SlimeBodies) -> void:
	if prepare(bodies, REST):
		run_phase(bodies, REST, GDSCRIPT)


## Runs `phase` on `bodies`, its GDScript pass or its native one (`kind`),
## with the substep length tick() would give it (bodies._h). Returns whether
## it ran: false for a native pass that is a stub or without the extension,
## and, with an error, for an unknown phase or kind.
static func run_phase(bodies: SlimeBodies, phase: String, kind: String) -> bool:
	if phase not in PHASES:
		push_error("native_equivalence_support: no phase '%s' (the phases: %s)" % [phase, ", ".join(PHASES)])
		return false
	if kind == GDSCRIPT:
		match phase:
			INTEGRATE:
				bodies._integrate(bodies._h)
			BUILD_PAIRS:
				bodies._build_pairs()
			CONTACTS:
				bodies._solve_contacts()
			RINGS:
				bodies._solve_rings()
			TERRAIN:
				bodies._solve_terrain()
			REST:
				bodies._rest()
		return true
	if kind != NATIVE:
		push_error("native_equivalence_support: no kind '%s' (gdscript or native)" % kind)
		return false
	if not ClassDB.class_exists(TickChoice.SOLVER_CLASS):
		return false
	var solver: Object = ClassDB.instantiate(TickChoice.SOLVER_CLASS)
	match phase:
		INTEGRATE:
			return solver.integrate(bodies, bodies._h)
		REST:
			return solver.rest(bodies, bodies._h)
	return solver.call(phase, bodies)


## Whether the native pass of `phase` runs (isn't a stub): false without the
## extension. Asked once per run, on the synthetic scene.
static func phase_supported(phase: String) -> bool:
	if phase not in PHASES:
		push_error("native_equivalence_support: no phase '%s' (the phases: %s)" % [phase, ", ".join(PHASES)])
		return false
	if not ClassDB.class_exists(TickChoice.SOLVER_CLASS):
		return false
	if not _supported.has(phase):
		var bodies := prepared(SYNTHETIC, phase)
		_supported[phase] = bodies != null and run_phase(bodies, phase, NATIVE)
	return _supported[phase]


## Why a test of `phase`'s native pass is pending ("" when it can run): the
## pass is a stub, or the run asked for the GDScript tick and the extension
## isn't loaded. Without the extension on a native run it is "": the test
## runs and fails (check() reports the pass didn't run), as the native tests
## do (tests/unit/test_native_solver.gd).
static func skip_reason(phase: String) -> String:
	if not ClassDB.class_exists(TickChoice.SOLVER_CLASS):
		if OS.get_environment(TickChoice.ENV) == TickChoice.GDSCRIPT:
			return "SLIME_TICK=gdscript and the slime_native extension isn't loaded"
		return ""
	if not phase_supported(phase):
		return "the native %s pass is a stub (SlimeSolver.%s returns false)" % [phase, phase]
	return ""


# --- Checking -----------------------------------------------------------------

## The GDScript pass against the native pass of `phase` on two copies of
## `bodies` (see the class doc). The problems, empty when equivalent.
static func check(bodies: SlimeBodies, phase: String, label: String, tolerances := {}) -> PackedStringArray:
	return check_kinds(bodies, phase, label, GDSCRIPT, NATIVE, tolerances)


## `phase` run by `kind_a` on one copy of `bodies` and by `kind_b` on
## another, compared. A pass that doesn't run is a problem.
static func check_kinds(bodies: SlimeBodies, phase: String, label: String, kind_a: String, kind_b: String,
		tolerances := {}) -> PackedStringArray:
	var full := "%s, %s" % [label, phase]
	var a := clone(bodies)
	var b := clone(bodies)
	var problems := PackedStringArray()
	if not run_phase(a, phase, kind_a):
		problems.append("%s: the %s pass didn't run (a stub, or no slime_native extension)" % [full, kind_a])
	if not run_phase(b, phase, kind_b):
		problems.append("%s: the %s pass didn't run (a stub, or no slime_native extension)" % [full, kind_b])
	if not problems.is_empty():
		return problems
	var names := PackedStringArray([kind_a, kind_b])
	if kind_a == kind_b:
		names = PackedStringArray([kind_a + " 1", kind_b + " 2"])
	return compare(a, b, full, tolerances, PackedStringArray() if kind_a == kind_b else SCRATCH, names)


## Every field of `a` against `b` but `skip` (see the class doc): one
## problem per field that differs, empty when none does. `names` names a and
## b in the messages.
static func compare(a: SlimeBodies, b: SlimeBodies, label: String, tolerances := {}, skip := SCRATCH,
		names := PackedStringArray(["a", "b"])) -> PackedStringArray:
	var problems := PackedStringArray()
	for field in fields(a):
		if field in skip:
			continue
		var tolerance := 0.0
		if tolerances.has(field):
			tolerance = tolerances[field]
		elif field in CONTINUOUS:
			tolerance = tolerances.get("*", DEFAULT_TOLERANCE)
		var problem := _field_problem(a, field, a.get(field), b.get(field), tolerance, names)
		if problem != "":
			problems.append("%s: %s" % [label, problem])
	return problems


## What differs in `field` between `va` (a's) and `vb` (see compare()), or "".
static func _field_problem(a: SlimeBodies, field: String, va: Variant, vb: Variant, tolerance: float,
		names: PackedStringArray) -> String:
	if typeof(va) != typeof(vb):
		return "%s: %s %s, %s %s" % [field, names[0], type_string(typeof(va)), names[1], type_string(typeof(vb))]
	if not is_sequence(va):
		var gap := _gap(va, vb, field in ANGLES)
		if gap > tolerance:
			return "%s: %s %s, %s %s" % [field, names[0], _text(va), names[1], _text(vb)]
		return ""
	if va.size() != vb.size():
		return "%s: %s holds %d, %s %d" % [field, names[0], va.size(), names[1], vb.size()]
	# Equal element for element (objects by identity; a NaN is never equal).
	if va == vb:
		return ""
	var first := -1
	var count := 0
	var worst := 0.0
	var worst_at := -1
	for i in va.size():
		var gap := _gap(va[i], vb[i], field in ANGLES)
		if gap <= tolerance:
			continue
		count += 1
		if first < 0:
			first = i
		if gap > worst:
			worst = gap
			worst_at = i
	if first < 0:
		return ""
	var out := "%s[%d]%s: %s %s, %s %s" % [field, first, _where(a, field, first), names[0], _text(va[first]),
			names[1], _text(vb[first])]
	if tolerance > 0.0:
		out += " (tolerance %s)" % _text(tolerance)
	out += "; %d of %d differ" % [count, va.size()]
	if worst != INF:
		out += ", the most %s at [%d]" % [_text(worst), worst_at]
	return out


## How far apart two values are: 0 when equal; the difference of two floats
## (wrapped for an `angle`), the distance between two vectors; INF otherwise
## (a NaN, unequal discrete values). Objects: Rng by state, the rest by
## identity (the terrain and the doors are shared).
static func _gap(x: Variant, y: Variant, angle: bool) -> float:
	if x is Rng and y is Rng:
		return 0.0 if x.state == y.state and x.seed_value == y.seed_value else INF
	if x is Object or y is Object:
		return 0.0 if is_same(x, y) else INF
	if typeof(x) == typeof(y) and x == y:
		return 0.0
	var gap := INF
	if typeof(x) == TYPE_FLOAT and typeof(y) == TYPE_FLOAT:
		gap = absf(angle_difference(x, y)) if angle else absf(x - y)
	elif typeof(x) == TYPE_VECTOR2 and typeof(y) == TYPE_VECTOR2:
		gap = (x - y).length()
	return INF if is_nan(gap) else gap


## Which slime element `i` of `field` belongs to, in a (" (slime ...)"), or "".
static func _where(a: SlimeBodies, field: String, i: int) -> String:
	if field in POINT_FIELDS:
		for s in a.slime_count:
			if i < a.first[s] + a.npts[s]:
				return " (slime index %d, id %d, point %d of %d)" % [s, a.id[s], i - a.first[s], a.npts[s]]
		return ""
	if field in PAIR_FIELDS:
		var k := i / 2 if field == "_pairs" else i
		if 2 * k + 1 < a._pairs.size():
			return " (pair %d: slime ids %d and %d)" % [k, a.id[a._pairs[2 * k]], a.id[a._pairs[2 * k + 1]]]
		return " (pair %d)" % k
	var value: Variant = a.get(field)
	if typeof(value) != TYPE_ARRAY and is_sequence(value) and value.size() == a.slime_count:
		return " (slime index %d, id %d)" % [i, a.id[i]]
	return ""


## A value as the messages print it: floats and vectors to 8 decimals.
static func _text(value: Variant) -> String:
	match typeof(value):
		TYPE_FLOAT:
			return "%.8f" % value
		TYPE_VECTOR2:
			return "(%.8f, %.8f)" % [value.x, value.y]
	if value is Rng:
		return "Rng(state %d)" % value.state
	return str(value)


# --- Helpers ------------------------------------------------------------------

## The script variables of SlimeBodies but UNCOMPARED, in declaration order.
static func fields(bodies: SlimeBodies) -> PackedStringArray:
	var out := PackedStringArray()
	for property in bodies.get_property_list():
		if property["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE and property["name"] not in UNCOMPARED:
			out.append(property["name"])
	return out


## The passes of one tick of `bodies`, in order, as [phase, substep,
## iteration] (_solve()'s loops): every moment prepare() takes.
static func tick_steps(bodies: SlimeBodies) -> Array:
	var out := []
	for sub in bodies.substeps:
		out.append([INTEGRATE, sub, 0])
		if sub == 0:
			out.append([BUILD_PAIRS, 0, 0])
		for it in bodies.iterations:
			for phase in [CONTACTS, RINGS, TERRAIN]:
				out.append([phase, sub, it])
	out.append([REST, 0, 0])
	return out


## Whether `value` is an Array or a packed array.
static func is_sequence(value: Variant) -> bool:
	var type := typeof(value)
	return type == TYPE_ARRAY or (type >= TYPE_PACKED_BYTE_ARRAY and type <= TYPE_PACKED_VECTOR4_ARRAY)


## A new Rng at `source`'s seed and state.
static func _rng_copy(source: Rng) -> Rng:
	var copy := Rng.new(source.seed_value)
	copy.state = source.state
	return copy
