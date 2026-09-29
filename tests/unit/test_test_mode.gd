extends GutTest
## TestMode configuration: the run settings (seed, time scale, fixture or
## save to load, autosave, input script, the level and where the camera
## starts), the command-line flags, and loading the levels' fixtures.

# @test-link [[req_test_level_and_test_mode]]

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


func test_fixtures_load_from_the_test_level() -> void:
	var fresh := TestMode.load_fixture("fresh")
	assert_true(fresh["ok"], str(fresh["error"]))
	assert_eq(fresh["save"], {}, "fresh has no save: the level starts as new")
	var bump := TestMode.load_fixture("bump")
	assert_true(bump["ok"], str(bump["error"]))
	assert_eq(bump["path"], "res://levels/test/fixtures/bump.json")
	assert_false(bump["save"].is_empty())
	assert_eq(typeof(bump["camera"]), TYPE_VECTOR2, "the sidecar's camera")
	var tm := TestMode.from_config({"seed": 1, "fixture": "bump"})
	assert_eq(tm.errors, PackedStringArray())
	assert_eq(tm.save_data, bump["save"])
	assert_eq(tm.camera, bump["camera"])


func test_an_unknown_fixture_is_reported() -> void:
	var result := TestMode.load_fixture("no-such-fixture")
	assert_false(result["ok"])
	assert_string_contains(result["error"], "no-such-fixture.fixture.json")
	assert_true(_has_error(TestMode.from_config({"seed": 1, "fixture": "no-such-fixture"}).errors, "no-such-fixture"))


func test_a_save_file_can_be_loaded_instead_of_a_fixture() -> void:
	assert_true(_has_error(TestMode.from_config({"seed": 1, "load": "user://no/such/save.json"}).errors, "no/such/save.json"))
	assert_true(_has_error(TestMode.from_config({"seed": 1, "load": "user://x.json", "fixture": "fresh"}).errors,
			"not both"))
	var file := FileAccess.open(TMP_CONFIG, FileAccess.WRITE)
	file.store_string(JSON.stringify({"format": 1, "level": {"id": "test", "version": 1}, "slimes": []}))
	file.close()
	var tm := TestMode.from_config({"seed": 1, "load": TMP_CONFIG})
	assert_eq(tm.errors, PackedStringArray())
	assert_eq(tm.save_data["level"]["id"], "test")


func test_autosave_is_off_unless_asked() -> void:
	assert_false(TestMode.from_config({"seed": 1}).autosave)
	assert_true(TestMode.from_config({"seed": 1, "autosave": true}).autosave)
	assert_true(_has_error(TestMode.from_config({"seed": 1, "autosave": "yes"}).errors, "autosave"))


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
	assert_eq(parsed["save_path"], "")


func test_command_line_save_and_load() -> void:
	var parsed := TestMode.config_from_args(PackedStringArray([
		"--test-mode", "--seed=1", "--load=/tmp/a.json", "--run-ticks=10", "--save=/tmp/b.json",
	]))
	assert_eq(parsed["errors"], PackedStringArray())
	assert_eq(parsed["config"]["load"], "/tmp/a.json")
	assert_eq(parsed["save_path"], "/tmp/b.json")
	assert_true(_has_error(TestMode.config_from_args(PackedStringArray(["--save="]))["errors"], "--save"))
	assert_true(_has_error(TestMode.config_from_args(PackedStringArray(["--save=/tmp/b.json"]))["errors"],
			"--run-ticks"))


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


# Choosing the level (chunk LD1): "level", "at", --level and --at.

func test_the_level_defaults_to_the_test_level() -> void:
	var tm := TestMode.from_config({"seed": 1})
	assert_eq(tm.errors, PackedStringArray())
	assert_eq(tm.level_id, LevelCatalog.DEFAULT_ID)
	assert_eq(TestMode.from_config({"seed": 1, "level": "test"}).level_id, "test")


func test_an_unknown_level_is_reported() -> void:
	var tm := TestMode.from_config({"seed": 1, "level": "no-such-level"})
	assert_true(_has_error(tm.errors, "res://levels/no-such-level/level.tscn"), str(tm.errors))
	assert_true(_has_error(tm.errors, "levels: test"), "the error lists the levels")
	assert_true(_has_error(TestMode.from_config({"seed": 1, "level": "Bad Id"}).errors, "invalid level id"))
	assert_true(_has_error(TestMode.from_config({"seed": 1, "level": 3}).errors, "'level'"))


func test_an_unknown_level_skips_its_fixture() -> void:
	var tm := TestMode.from_config({"seed": 1, "level": "no-such-level", "fixture": "fresh"})
	assert_eq(tm.errors.size(), 1, "one error, the level's: %s" % tm.errors)


func test_fixtures_resolve_under_the_level() -> void:
	assert_eq(TestMode.fixture_path("fresh", "01"), "res://levels/01/fixtures/fresh.json")
	assert_eq(TestMode.sidecar_path("bump", "my-level"), "res://levels/my-level/fixtures/bump.fixture.json")
	assert_eq(TestMode.sidecar_path("bump"), "res://levels/test/fixtures/bump.fixture.json", "the test level by default")
	assert_true(TestMode.load_fixture("fresh", "test")["ok"])


func test_a_fixture_of_an_unknown_level_is_reported() -> void:
	var result := TestMode.load_fixture("fresh", "no-such-level")
	assert_false(result["ok"])
	assert_string_contains(result["error"], "res://levels/no-such-level/level.tscn")


func test_at_is_a_stable_id_or_a_level_point() -> void:
	var by_id := TestMode.from_config({"seed": 1, "at": "s1.gate"})
	assert_eq(by_id.errors, PackedStringArray())
	assert_eq(by_id.at, "s1.gate", "kept as given: the game finds it in the level")
	var by_point := TestMode.from_config({"seed": 1, "at": [100, -20.5]})
	assert_eq(by_point.errors, PackedStringArray())
	assert_eq(by_point.at, Vector2(100, -20.5))
	assert_null(TestMode.from_config({"seed": 1}).at, "no 'at': the fixture's camera, or the level's start")


func test_at_type_errors() -> void:
	for bad in [5, "", "Not An Id", [1], [1, "x"], [1, 2, 3], {"x": 1}]:
		assert_true(_has_error(TestMode.from_config({"seed": 1, "at": bad}).errors, "'at'"), str(bad))


func test_command_line_level_and_at() -> void:
	var parsed := TestMode.config_from_args(PackedStringArray([
		"--test-mode", "--seed=1", "--level=test", "--at=s1.gate",
	]))
	assert_eq(parsed["errors"], PackedStringArray())
	assert_eq(parsed["config"]["level"], "test")
	assert_eq(parsed["config"]["at"], "s1.gate")
	var point := TestMode.config_from_args(PackedStringArray(["--seed=1", "--at=100,-20.5"]))
	assert_eq(point["errors"], PackedStringArray())
	assert_eq(point["config"]["at"], [100.0, -20.5])
	assert_eq(TestMode.from_config(point["config"]).at, Vector2(100, -20.5))
	assert_true(_has_error(TestMode.config_from_args(PackedStringArray(["--level="]))["errors"], "--level"))
	assert_true(_has_error(TestMode.config_from_args(PackedStringArray(["--at="]))["errors"], "--at"))
	assert_true(_has_error(TestMode.config_from_args(PackedStringArray(["--at=1,2,3"]))["errors"], "--at"))
