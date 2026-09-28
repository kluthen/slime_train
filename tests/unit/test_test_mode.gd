extends GutTest
## TestMode configuration: the run settings (seed, time scale, fixture,
## input script), the command-line flags, and the fixture stub.

const TMP_CONFIG := "user://test_mode_config_test.json"


func after_all() -> void:
	if FileAccess.file_exists(TMP_CONFIG):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP_CONFIG))


func _has_error(errors: PackedStringArray, fragment: String) -> bool:
	for e in errors:
		if fragment in e:
			return true
	return false


func test_minimal_config() -> void:
	var tm := TestMode.from_config({"seed": 42})
	assert_eq(tm.errors, PackedStringArray())
	assert_eq(tm.seed_value, 42)
	assert_eq(tm.time_scale, 1.0)
	assert_true(tm.block_real_input)
	assert_eq(tm.input_script.last_tick, -1)


func test_full_config() -> void:
	var tm := TestMode.from_config({
		"seed": 7.0,
		"time_scale": 4,
		"block_real_input": false,
		"steps": [{"tick": 2, "do": "tilt", "degrees": 5}],
	})
	assert_eq(tm.errors, PackedStringArray())
	assert_eq(tm.seed_value, 7)
	assert_eq(tm.time_scale, 4.0)
	assert_false(tm.block_real_input)
	assert_eq(tm.inputs_for_tick(2), [Simulation.tilt(5.0)])
	assert_eq(tm.inputs_for_tick(3), [])


func test_seed_is_required() -> void:
	assert_true(_has_error(TestMode.from_config({}).errors, "seed"))
	assert_true(_has_error(TestMode.from_config({"seed": 1.5}).errors, "seed"))


func test_time_scale_bounds() -> void:
	assert_eq(TestMode.from_config({"seed": 1, "time_scale": 0}).errors, PackedStringArray(),
			"0 holds the clock: only run_ticks advances the simulation")
	assert_true(_has_error(TestMode.from_config({"seed": 1, "time_scale": -1}).errors, "time_scale"))
	assert_true(_has_error(TestMode.from_config({"seed": 1, "time_scale": 1000}).errors, "time_scale"))


func test_unknown_keys_and_step_errors_are_reported() -> void:
	assert_true(_has_error(TestMode.from_config({"seed": 1, "sead": 2}).errors, "sead"))
	var tm := TestMode.from_config({"seed": 1, "steps": [{"tick": 1, "do": "wiggle"}]})
	assert_true(_has_error(tm.errors, "wiggle"))


func test_fixture_names_resolve_under_the_test_level() -> void:
	assert_eq(TestMode.fixture_path("fresh"), "res://levels/test/fixtures/fresh.json")
	assert_eq(TestMode.fixture_path("s1-basket-5of6"), "res://levels/test/fixtures/s1-basket-5of6.json")


func test_fixture_loading_is_a_stub_until_chunk_8() -> void:
	var result := TestMode.load_fixture("fresh")
	assert_false(result["ok"])
	assert_eq(result["path"], "res://levels/test/fixtures/fresh.json")
	assert_string_contains(result["error"], "not implemented")
	var tm := TestMode.from_config({"seed": 1, "fixture": "fresh"})
	assert_true(_has_error(tm.errors, "not implemented"))


func test_bad_fixture_names_are_refused() -> void:
	for bad in ["", "../save", "Fresh", "a b", "x/y", "-lead"]:
		var result := TestMode.load_fixture(bad)
		assert_false(result["ok"])
		assert_string_contains(result["error"], "invalid fixture name")


func test_config_file_round_trip() -> void:
	var file := FileAccess.open(TMP_CONFIG, FileAccess.WRITE)
	file.store_string(JSON.stringify({"seed": 3, "steps": [{"tick": 1, "do": "tap", "at": [5, 6]}]}))
	file.close()
	var loaded := TestMode.load_config_file(TMP_CONFIG)
	assert_eq(loaded["errors"], PackedStringArray())
	var tm := TestMode.from_config(loaded["config"])
	assert_eq(tm.errors, PackedStringArray())
	assert_eq(tm.seed_value, 3)
	assert_eq(tm.inputs_for_tick(1).size(), 2)


func test_config_file_errors() -> void:
	assert_true(_has_error(TestMode.load_config_file("res://no/such.json")["errors"], "no/such.json"))


func test_command_line_flags() -> void:
	var parsed := TestMode.config_from_args(PackedStringArray([
		"--test-mode", "--seed=12", "--time-scale=2.5", "--run-ticks=300", "--print-state",
	]))
	assert_eq(parsed["errors"], PackedStringArray())
	assert_eq(parsed["config"]["seed"], 12)
	assert_eq(parsed["config"]["time_scale"], 2.5)
	assert_eq(parsed["run_ticks"], 300)
	assert_true(parsed["print_state"])


func test_command_line_seed_overrides_the_script_file() -> void:
	var file := FileAccess.open(TMP_CONFIG, FileAccess.WRITE)
	file.store_string(JSON.stringify({"seed": 3, "steps": []}))
	file.close()
	var parsed := TestMode.config_from_args(PackedStringArray([
		"--test-mode", "--test-script=" + TMP_CONFIG, "--seed=8",
	]))
	assert_eq(parsed["errors"], PackedStringArray())
	assert_eq(parsed["config"]["seed"], 8)
	assert_eq(parsed["run_ticks"], -1)


func test_command_line_errors() -> void:
	assert_true(_has_error(TestMode.config_from_args(PackedStringArray(["--seed=x"]))["errors"], "--seed"))
	assert_true(_has_error(TestMode.config_from_args(PackedStringArray(["--run-ticks=-3"]))["errors"], "--run-ticks"))
	assert_true(_has_error(TestMode.config_from_args(PackedStringArray(["--frobnicate"]))["errors"], "--frobnicate"))
