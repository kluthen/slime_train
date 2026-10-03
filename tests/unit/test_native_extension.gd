extends GutTest
## The slime_native GDExtension, the native tick's toolchain (chunk 5N,
## docs/dev/native.md): Godot registers it at startup, its build is named,
## and it rounds like GDScript (no fused multiply-add). In the default suite:
## tools/test.sh builds the Linux library first and fails without it. These
## tests fail, never skip, when the extension isn't registered, unless the
## run asked for the GDScript tick (SLIME_TICK=gdscript), which doesn't need
## it: then they are pending.

const NativeCheck := preload("res://tests/unit/native_check.gd")

var _load_error := ""
var _native: Object


func before_all() -> void:
	_load_error = NativeCheck.load_error()
	if _load_error.is_empty():
		_native = ClassDB.instantiate(NativeCheck.NATIVE_CLASS)


## The extension's object, or null after failing the test (or marking it
## pending when the run asked for the GDScript tick).
func _native_or_fail() -> Object:
	if _native == null:
		if OS.get_environment(TickChoice.ENV) == TickChoice.GDSCRIPT:
			pending("SLIME_TICK=gdscript and the extension isn't loaded: %s" % _load_error)
		else:
			fail_test("SlimeNative is not available: %s" % _load_error)
	return _native


func test_extension_registers_its_classes_at_startup() -> void:
	if _native_or_fail() == null:
		return
	assert_eq(_load_error, "", "the extension loads at startup")
	assert_true(ClassDB.class_exists(NativeCheck.NATIVE_CLASS), "SlimeNative is registered")
	assert_true(ClassDB.class_exists(TickChoice.SOLVER_CLASS), "SlimeSolver is registered")
	assert_true(GDExtensionManager.is_extension_loaded(NativeCheck.EXTENSION_PATH),
			"loaded from %s" % NativeCheck.EXTENSION_PATH)


func test_version_names_the_build() -> void:
	var native := _native_or_fail()
	if native == null:
		return
	var version: String = native.version()
	assert_true(version.begins_with("slime_native 0.1.0 ("), version)
	assert_string_contains(version, "linux.template_debug.x86_64")


func test_sum_of_a_packed_float32_array() -> void:
	var native := _native_or_fail()
	if native == null:
		return
	assert_eq(native.sum(PackedFloat32Array([1.5, 2.25, -0.75, 4.0])), 7.0)
	assert_eq(native.sum(PackedFloat32Array()), 0.0)
	# The float32 value itself, widened, not the double 0.1.
	var tenth := PackedFloat32Array([0.1])
	assert_eq(native.sum(tenth), tenth[0])


func test_mul_add_rounds_twice_like_gdscript() -> void:
	# -ffp-contract=off (D96): no fused multiply-add, so the native code rounds
	# like GDScript. On x86_64 this holds anyway (no FMA in the baseline ISA);
	# the phone check is what proves it on arm64 (docs/dev/native.md).
	var native := _native_or_fail()
	if native == null:
		return
	var probe: float = native.mul_add(NativeCheck.FMA_A, NativeCheck.FMA_B, NativeCheck.FMA_C)
	assert_eq(probe, NativeCheck.FMA_A * NativeCheck.FMA_B + NativeCheck.FMA_C)
	assert_eq(probe, 0.0)
	assert_ne(probe, NativeCheck.FMA_FUSED)
