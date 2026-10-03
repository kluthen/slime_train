class_name TickChoice
extends RefCounted
## Which simulation tick a run uses (chunk 5N, D158): the native solver
## (SlimeSolver, the slime_native GDExtension, addons/slime_native/) or the
## GDScript one, which stays as the fallback (D140). In order:
##   1. `--tick=gdscript` or `--tick=native` among the user arguments (after
##      `--`), in a debug build only: a release build ignores it, saying so;
##   2. the environment variable SLIME_TICK (`gdscript` or `native`);
##   3. the default: native when the extension is loaded (SlimeSolver is a
##      class), else GDScript ("extension missing": the game still runs).
## A native tick asked for (1 or 2) when the extension is missing gives the
## GDScript tick and an error; so does an unknown value, which is ignored.
## Either way the run prints `TICK <kind> (<reason>)` once, to stderr
## (current()).
##
## The solver is named only through ClassDB (SOLVER_CLASS), so every script
## parses without the extension. SlimeBodies asks current() when it is
## created (SlimeBodies.use_native).

## The native solver's class, registered by the extension.
const SOLVER_CLASS := "SlimeSolver"
## The user argument: --tick=gdscript or --tick=native (debug builds only).
const FLAG := "--tick"
## The environment variable: SLIME_TICK=gdscript or SLIME_TICK=native.
const ENV := "SLIME_TICK"
const NATIVE := "native"
const GDSCRIPT := "gdscript"

## Whether the run uses the native tick.
var native := false
## Why: the argument or variable that chose it, "default", or "extension
## missing".
var reason := ""
## Lines to print before the TICK line (a switch ignored in a release build).
var notes := PackedStringArray()
## What went wrong (an unknown value, a native tick asked for but missing).
var errors := PackedStringArray()

static var _current: TickChoice = null


## The choice for these inputs, with no side effect: the user arguments,
## the value of SLIME_TICK ("" when unset), whether the build is a debug
## one, and whether the extension's solver class exists.
static func resolve(user_args: PackedStringArray, env_value: String, debug_build: bool,
		has_solver: bool) -> TickChoice:
	var choice := TickChoice.new()
	var asked := ""
	var source := ""
	for arg in user_args:
		if arg != FLAG and not arg.begins_with(FLAG + "="):
			continue
		if not debug_build:
			choice.notes.append("TICK %s ignored, not a debug build." % arg)
			continue
		var value := arg.substr(FLAG.length() + 1)
		if value != NATIVE and value != GDSCRIPT:
			choice.errors.append("TICK %s ignored: expects %s=%s or %s=%s." % [arg, FLAG, GDSCRIPT, FLAG, NATIVE])
			continue
		asked = value
		source = arg
	if asked.is_empty() and not env_value.is_empty():
		if env_value == NATIVE or env_value == GDSCRIPT:
			asked = env_value
			source = "%s=%s" % [ENV, env_value]
		else:
			choice.errors.append("TICK %s=%s ignored: expects %s or %s." % [ENV, env_value, GDSCRIPT, NATIVE])
	if asked == GDSCRIPT:
		choice.reason = source
	elif asked == NATIVE and has_solver:
		choice.native = true
		choice.reason = source
	elif asked == NATIVE:
		choice.reason = "extension missing, %s not met" % source
		choice.errors.append("TICK %s: the native tick is asked for but the extension is missing." % source)
	elif has_solver:
		choice.native = true
		choice.reason = "default"
	else:
		choice.reason = "extension missing"
	return choice


## This run's choice, resolved on the first call from the command line, the
## environment, the build and the extension, which it reports (report()).
static func current() -> TickChoice:
	if _current == null:
		_current = resolve(OS.get_cmdline_user_args(), OS.get_environment(ENV), OS.is_debug_build(),
				ClassDB.class_exists(SOLVER_CLASS))
		_current.report()
	return _current


## "native" or "gdscript".
func kind() -> String:
	return NATIVE if native else GDSCRIPT


## The line a run prints: `TICK <kind> (<reason>)`.
func line() -> String:
	return "TICK %s (%s)" % [kind(), reason]


## Prints the notes and the TICK line, and pushes the errors. To stderr, a
## diagnostic: a tool's stdout stays its own (level_report.gd --json).
func report() -> void:
	for note in notes:
		printerr(note)
	for error in errors:
		push_error(error)
	printerr(line())
