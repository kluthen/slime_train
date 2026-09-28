extends Node
## Loads the slime_native GDExtension and reports on it. The native tick is a
## deferred contingency (D96, docs/dev/native.md): `native/` holds a
## `.gdignore`, so Godot never registers the extension on its own and nothing
## else in the game loads it.
##
## Used by `test_native_extension.gd` (through `ensure_loaded`) and, as the
## main scene of a temporary export, for the one-off check on the phone: it
## prints `NATIVE_CHECK` lines to the log (logcat tag `godot`) and quits.

const EXTENSION_PATH := "res://native/slime_native.gdextension"
const NATIVE_CLASS := "SlimeNative"

## Operands of the fused multiply-add probe. a * b is 1 + 2^-29 + 2^-60
## exactly: rounded to a double first (two roundings, what GDScript and a
## build with -ffp-contract=off do), a * b + c is 0; fused (one rounding) it
## is 2^-60.
const FMA_A := 1.0 + 1.0 / 1073741824.0
const FMA_B := 1.0 + 1.0 / 1073741824.0
const FMA_C := -(1.0 + 1.0 / 536870912.0)
const FMA_FUSED := 1.0 / 1152921504606846976.0


## Loads the extension unless its class is already registered (an export that
## lists the extension loads it at startup). Returns an error message, or ""
## when `SlimeNative` is available.
static func ensure_loaded() -> String:
	if ClassDB.class_exists(NATIVE_CLASS):
		return ""
	if not FileAccess.file_exists(EXTENSION_PATH):
		return "%s is missing" % EXTENSION_PATH
	var status := GDExtensionManager.load_extension(EXTENSION_PATH)
	if status != GDExtensionManager.LOAD_STATUS_OK:
		return ("GDExtensionManager.load_extension(%s) returned %d; build the library"
				+ " with tools/build_native.sh") % [EXTENSION_PATH, status]
	if not ClassDB.class_exists(NATIVE_CLASS):
		return "the extension loaded but did not register %s" % NATIVE_CLASS
	return ""


func _ready() -> void:
	var at_startup := ClassDB.class_exists(NATIVE_CLASS)
	var error := ensure_loaded()
	if not error.is_empty():
		print("NATIVE_CHECK FAIL %s" % error)
	else:
		var native: Object = ClassDB.instantiate(NATIVE_CLASS)
		var probe: float = native.mul_add(FMA_A, FMA_B, FMA_C)
		print("NATIVE_CHECK version=\"%s\" loaded_at_startup=%s" % [native.version(), at_startup])
		print("NATIVE_CHECK sum=%s (expected 7)" % native.sum(PackedFloat32Array([1.5, 2.25, -0.75, 4.0])))
		print("NATIVE_CHECK mul_add=%s fused=%s -> %s" % [probe, probe == FMA_FUSED,
				"OK (no FMA contraction)" if probe == FMA_A * FMA_B + FMA_C else "FAIL"])
	get_tree().quit()
