extends Node
## Reports on the slime_native GDExtension (the native tick, chunk 5N,
## docs/dev/native.md). Godot registers the extension at startup
## (addons/slime_native/slime_native.gdextension, listed in
## .godot/extension_list.cfg by the import) and every export ships it.
##
## Used by `test_native_extension.gd` (through `load_error`) and, as the main
## scene of a temporary debug export, for a check on the phone: it prints
## `NATIVE_CHECK` lines to the log (logcat tag `godot`) and quits.

const EXTENSION_PATH := "res://addons/slime_native/slime_native.gdextension"
const NATIVE_CLASS := "SlimeNative"

## Operands of the fused multiply-add probe. a * b is 1 + 2^-29 + 2^-60
## exactly: rounded to a double first (two roundings, what GDScript and a
## build with -ffp-contract=off do), a * b + c is 0; fused (one rounding) it
## is 2^-60.
const FMA_A := 1.0 + 1.0 / 1073741824.0
const FMA_B := 1.0 + 1.0 / 1073741824.0
const FMA_C := -(1.0 + 1.0 / 536870912.0)
const FMA_FUSED := 1.0 / 1152921504606846976.0


## Why `SlimeNative` isn't available, or "" when the extension registered it
## at startup. It never loads the extension itself: a run that needs it
## loading by hand would hide a build where it doesn't load.
static func load_error() -> String:
	if ClassDB.class_exists(NATIVE_CLASS):
		return ""
	if not FileAccess.file_exists(EXTENSION_PATH):
		return "%s is missing" % EXTENSION_PATH
	return ("the extension didn't register %s at startup: build its library with"
			+ " tools/build_native.sh, then import (godot --headless --import)") % NATIVE_CLASS


func _ready() -> void:
	var error := load_error()
	if not error.is_empty():
		print("NATIVE_CHECK FAIL %s" % error)
	else:
		var native: Object = ClassDB.instantiate(NATIVE_CLASS)
		var probe: float = native.mul_add(FMA_A, FMA_B, FMA_C)
		print("NATIVE_CHECK version=\"%s\"" % native.version())
		print("NATIVE_CHECK sum=%s (expected 7)" % native.sum(PackedFloat32Array([1.5, 2.25, -0.75, 4.0])))
		print("NATIVE_CHECK mul_add=%s fused=%s -> %s" % [probe, probe == FMA_FUSED,
				"OK (no FMA contraction)" if probe == FMA_A * FMA_B + FMA_C else "FAIL"])
	get_tree().quit()
