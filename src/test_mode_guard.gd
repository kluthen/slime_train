class_name TestModeGuard
extends RefCounted
## The one check between the game and test mode. Test mode (scripted input,
## time control, fixtures) runs only in a debug build: the editor, the Linux
## build used for tests, and debug Android builds. A release export is never a
## debug build (OS.is_debug_build() is false there), so the guard refuses and
## the game never loads anything from src/test_mode/.
##
## The game names test-mode code only by path, after this guard allows it, so
## a release export preset can also leave src/test_mode/ out entirely (chunk
## 20). tests/unit/test_test_mode_guard.gd checks both.
##
## Tests build a guard with an explicit answer to check the refusal path.

## The command-line flag that asks for test mode (after "--").
const FLAG := "--test-mode"

var _is_debug_build: bool


func _init(is_debug_build: bool) -> void:
	_is_debug_build = is_debug_build


## The guard for the running build.
static func for_this_build() -> TestModeGuard:
	return TestModeGuard.new(OS.is_debug_build())


## Whether this build may run test mode.
# @spec-link [[req_test_level_and_test_mode]]
func allows() -> bool:
	return _is_debug_build


## Whether the command line asks for test mode. Test mode is never on by
## default, even in a debug build.
static func requested(user_args: PackedStringArray) -> bool:
	return FLAG in user_args
