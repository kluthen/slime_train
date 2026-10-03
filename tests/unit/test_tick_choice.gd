extends GutTest
## Which simulation tick a run uses (TickChoice, src/sim/tick_choice.gd,
## chunk 5N): resolve() is a pure function of the user arguments, the
## SLIME_TICK value, the build and the extension; current() is this run's.

func _resolve(args: Array, env_value := "", debug_build := true, has_solver := true) -> TickChoice:
	return TickChoice.resolve(PackedStringArray(args), env_value, debug_build, has_solver)


func test_default_is_native_when_the_extension_is_loaded() -> void:
	var choice := _resolve([])
	assert_true(choice.native)
	assert_eq(choice.line(), "TICK native (default)")
	assert_eq(choice.errors, PackedStringArray())
	assert_eq(choice.notes, PackedStringArray())


func test_default_is_gdscript_when_the_extension_is_missing() -> void:
	var choice := _resolve([], "", true, false)
	assert_false(choice.native)
	assert_eq(choice.line(), "TICK gdscript (extension missing)")
	assert_eq(choice.errors, PackedStringArray(), "a missing extension isn't an error by default")


func test_release_build_defaults_like_a_debug_one() -> void:
	assert_eq(_resolve([], "", false, true).line(), "TICK native (default)")
	assert_eq(_resolve([], "", false, false).line(), "TICK gdscript (extension missing)")


func test_flag_picks_the_tick_in_a_debug_build() -> void:
	assert_eq(_resolve(["--tick=gdscript"]).line(), "TICK gdscript (--tick=gdscript)")
	assert_eq(_resolve(["--tick=native"]).line(), "TICK native (--tick=native)")
	assert_eq(_resolve(["--test-mode", "--tick=gdscript", "--seed=1"]).line(),
			"TICK gdscript (--tick=gdscript)", "among other arguments")


func test_flag_wins_over_the_environment() -> void:
	assert_eq(_resolve(["--tick=gdscript"], "native").line(), "TICK gdscript (--tick=gdscript)")
	assert_eq(_resolve(["--tick=native"], "gdscript").line(), "TICK native (--tick=native)")


func test_the_last_flag_counts() -> void:
	assert_eq(_resolve(["--tick=native", "--tick=gdscript"]).line(), "TICK gdscript (--tick=gdscript)")


func test_flag_is_ignored_in_a_release_build_with_a_log_line() -> void:
	var choice := _resolve(["--tick=gdscript"], "", false, true)
	assert_true(choice.native, "the release build keeps its default")
	assert_eq(choice.line(), "TICK native (default)")
	assert_eq(choice.notes, PackedStringArray(["TICK --tick=gdscript ignored, not a debug build."]))
	assert_eq(choice.errors, PackedStringArray())


func test_environment_picks_the_tick() -> void:
	assert_eq(_resolve([], "gdscript").line(), "TICK gdscript (SLIME_TICK=gdscript)")
	assert_eq(_resolve([], "native").line(), "TICK native (SLIME_TICK=native)")
	assert_eq(_resolve([], "gdscript", false, true).line(), "TICK gdscript (SLIME_TICK=gdscript)",
			"in a release build too")


func test_gdscript_asked_for_needs_no_extension() -> void:
	var choice := _resolve(["--tick=gdscript"], "", true, false)
	assert_eq(choice.line(), "TICK gdscript (--tick=gdscript)")
	assert_eq(choice.errors, PackedStringArray())


func test_native_asked_for_without_the_extension_is_an_error() -> void:
	var by_flag := _resolve(["--tick=native"], "", true, false)
	assert_false(by_flag.native)
	assert_eq(by_flag.line(), "TICK gdscript (extension missing, --tick=native not met)")
	assert_eq(by_flag.errors.size(), 1)
	var by_env := _resolve([], "native", true, false)
	assert_false(by_env.native)
	assert_eq(by_env.line(), "TICK gdscript (extension missing, SLIME_TICK=native not met)")
	assert_eq(by_env.errors.size(), 1)


func test_unknown_values_are_errors_and_ignored() -> void:
	var by_flag := _resolve(["--tick=fast"], "gdscript")
	assert_eq(by_flag.line(), "TICK gdscript (SLIME_TICK=gdscript)", "the next source decides")
	assert_eq(by_flag.errors.size(), 1)
	assert_string_contains(by_flag.errors[0], "--tick=fast")
	var bare := _resolve(["--tick"])
	assert_eq(bare.line(), "TICK native (default)")
	assert_eq(bare.errors.size(), 1)
	var by_env := _resolve([], "c++")
	assert_eq(by_env.line(), "TICK native (default)")
	assert_eq(by_env.errors.size(), 1)
	assert_string_contains(by_env.errors[0], "SLIME_TICK=c++")


func test_other_arguments_are_not_the_flag() -> void:
	var choice := _resolve(["--ticks=600", "--tickle"])
	assert_eq(choice.line(), "TICK native (default)")
	assert_eq(choice.errors, PackedStringArray())


func test_resolve_has_no_side_effect() -> void:
	var first := _resolve(["--tick=gdscript"])
	var second := _resolve(["--tick=gdscript"])
	assert_ne(first, second, "a new choice each time")
	assert_eq(first.line(), second.line())


## This run's tick is the one the run asked for: tools/test.sh sets
## SLIME_TICK (native unless told gdscript), so a suite whose extension
## doesn't load fails here instead of running on the fallback.
func test_this_run_uses_the_tick_it_asked_for() -> void:
	var asked := OS.get_environment(TickChoice.ENV)
	var current := TickChoice.current()
	assert_eq(current, TickChoice.current(), "resolved once")
	if asked == TickChoice.NATIVE:
		assert_true(current.native, current.line())
		assert_true(ClassDB.class_exists(TickChoice.SOLVER_CLASS))
	elif asked == TickChoice.GDSCRIPT:
		assert_false(current.native, current.line())
	else:
		assert_eq(current.native, ClassDB.class_exists(TickChoice.SOLVER_CLASS), current.line())
	var bodies := SlimeBodies.new(Rng.new(1))
	assert_eq(bodies.uses_native(), current.native, "new bodies take the run's tick")
