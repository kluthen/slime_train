extends GutTest
## Chunk LD1: the fixture maker for any level (tools/make_fixture.gd --
## --level=<id>) and the level report (tools/level_report.gd), run as the
## designer runs them: as child processes of the Godot binary.
##
## A small level is built here, in code: two sections on one floor, section
## 1's frontier set opening its gate (s1.gate) into section 2, whose set has
## no gate (the celebration's). It is saved to res://levels/<unique id>/,
## with no fixtures' folder (make_fixture makes it), and removed after the
## script, with any folder an earlier run that crashed left behind.

# @test-link [[req_test_level_and_test_mode]]
# @test-link [[rule_max_200_slimes_per_level]]

const MAIN_SCENE := "res://src/main.tscn"
const MAKE_FIXTURE := "res://tools/make_fixture.gd"
const LEVEL_REPORT := "res://tools/level_report.gd"
## The prefix of the levels this script makes, for the clean-up.
const PREFIX := "zz-tools-"
const S := LevelData.SCREEN
## The small level: its floor's top, the loop a base slime's centre above it.
const FLOOR_Y := 600.0
const LOOP_Y := FLOOR_Y - LevelBuilder.RIDE
## Where section 1 ends and section 2 starts (the frontier), and section 2's
## end, screens.
const FRONTIER_X := 2.0
const END_X := 4.0
## The fixture maker's generic fixtures, and stale() (chunk LD3).
const LEVEL_FIXTURES := preload("res://tools/make_fixture/level_fixtures.gd")

## The small level's ID.
var level_id := ""
## make_fixture's run on it: its exit code and output.
var made_code := -1
var made_text := ""


func before_all() -> void:
	_remove_stale_levels()
	level_id = "%s%d" % [PREFIX, Time.get_ticks_usec()]
	var builder := _small_level(level_id)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(LevelCatalog.dir_of(level_id)))
	assert_eq(builder.save(LevelCatalog.scene_path(level_id)), OK)
	builder.level.free()
	var run := _run(MAKE_FIXTURE, ["--level=" + level_id])
	made_code = run["code"]
	made_text = run["text"]


func after_all() -> void:
	_remove_stale_levels()


# --- make_fixture on another level -----------------------------------------------

func test_make_fixture_writes_the_generic_fixtures() -> void:
	assert_eq(made_code, 0, made_text)
	assert_true(FileAccess.file_exists(TestMode.sidecar_path("fresh", level_id)))
	assert_false(FileAccess.file_exists(TestMode.fixture_path("fresh", level_id)), "fresh has no save")
	assert_true(FileAccess.file_exists(TestMode.sidecar_path("gate1-open", level_id)))
	assert_true(FileAccess.file_exists(TestMode.fixture_path("gate1-open", level_id)))
	assert_false(FileAccess.file_exists(TestMode.sidecar_path("gate2-open", level_id)), "one gate, one gate fixture")


func test_the_gate_fixture_says_what_it_is_and_where_the_camera_starts() -> void:
	var loaded := TestMode.load_fixture("gate1-open", level_id)
	assert_true(loaded["ok"], str(loaded["error"]))
	assert_string_contains(loaded["description"], "s1.gate (basket s1.basket, switch s1.switch)")
	assert_string_contains(loaded["description"], "section 2")
	assert_eq(loaded["camera"], Vector2(FRONTIER_X * S, LOOP_Y), "section 2's start: s2.loop's first point")
	var fresh := TestMode.load_fixture("fresh", level_id)
	assert_true(fresh["ok"], str(fresh["error"]))
	assert_eq(fresh["save"], {})
	assert_string_contains(fresh["description"], "The level as new")


func test_gate1_open_loads_in_test_mode_with_the_gate_open() -> void:
	var game := _boot_run({"level": level_id, "fixture": "gate1-open"})
	var sim: Simulation = game.simulation
	assert_eq(game.level.level_id, level_id)
	assert_eq(sim.train.open_gates, ["s1.gate"])
	assert_true(sim.gate_states["s1.gate"]["open"])
	assert_true(sim.gate_states["s1.gate"]["entrance_closed"])
	assert_eq(sim.object_states["s1.basket"]["phase"], FrontierSets.FIRED)
	assert_true(sim.object_states["s1.switch"]["flipped"])
	assert_ne(sim.object_states["s2.basket"]["phase"], FrontierSets.FIRED, "section 2's set untouched")
	assert_eq(sim.slimes.slime_count, 3, "otherwise as new: the first slime and both sleepers")
	game.test_mode.run_ticks(30)
	assert_eq(sim.tick, 30)


func test_fresh_loads_in_test_mode_as_the_level_new() -> void:
	var fixture := _boot_run({"level": level_id, "fixture": "fresh"})
	var plain := _boot_run({"level": level_id})
	fixture.test_mode.run_ticks(30)
	plain.test_mode.run_ticks(30)
	assert_eq(fixture.simulation.state_hash(), plain.simulation.state_hash())


# --- Stale fixtures (chunk LD3) -----------------------------------------------------

## The small level, built, and gate1-open's save as make_fixture wrote it.
func _level_and_gate_save() -> Array:
	var level: Level = load(LevelCatalog.scene_path(level_id)).instantiate()
	add_child_autofree(level)
	var loaded := TestMode.load_fixture("gate1-open", level_id)
	assert_true(loaded["ok"], str(loaded["error"]))
	return [level, loaded["save"]]


func test_a_fixture_just_made_is_not_older_than_the_level() -> void:
	var made := _level_and_gate_save()
	assert_eq(LEVEL_FIXTURES.stale(made[1], made[0].data), PackedStringArray())


func test_a_fixture_is_older_than_the_level_when_a_sleeper_is_new_moved_or_gone() -> void:
	var made := _level_and_gate_save()
	var level: Level = made[0]
	var save: Dictionary = made[1]
	var without: Dictionary = save.duplicate(true)
	without["slimes"] = without["slimes"].filter(func(slime): return slime["id"] != "s2.sleeper.01")
	assert_eq(LEVEL_FIXTURES.stale(without, level.data), PackedStringArray(["the level's s2.sleeper.01 isn't in it"]),
			"a sleeper added to the level since")
	var moved: Dictionary = save.duplicate(true)
	for slime in moved["slimes"]:
		if slime["id"] == "s1.sleeper.01":
			slime["centre"] = [slime["centre"][0] + 50.0, slime["centre"][1]]
	var problems := LEVEL_FIXTURES.stale(moved, level.data)
	assert_eq(problems.size(), 1, str(problems))
	assert_string_contains(problems[0] if not problems.is_empty() else "", "s1.sleeper.01 sleeps at")
	var gone: Dictionary = save.duplicate(true)
	gone["slimes"].append({"id": "s1.sleeper.09", "members": ["s1.sleeper.09"], "centre": [0.0, 0.0], "size": 1,
			"species": "B", "state": "sleeper"})
	assert_eq(LEVEL_FIXTURES.stale(gone, level.data),
			PackedStringArray(["its slime s1.sleeper.09 holds s1.sleeper.09, which the level doesn't have"]),
			"a sleeper taken out of the level since")


func test_a_fixture_camera_may_be_a_stable_id() -> void:
	var sidecar := TestMode.sidecar_path("zz-camera-by-id", level_id)
	var file := FileAccess.open(sidecar, FileAccess.WRITE)
	file.store_string(JSON.stringify({"description": "the camera on switch 1", "save": false, "camera": "s1.switch"}))
	file.close()
	var loaded := TestMode.load_fixture("zz-camera-by-id", level_id)
	assert_true(loaded["ok"], str(loaded["error"]))
	assert_eq(loaded["camera"], "s1.switch", "kept as given: the game finds it in the level")
	var game := _boot_run({"level": level_id, "fixture": "zz-camera-by-id"})
	var switch: Vector2 = game.level.position_of(game.level.find("s1.switch"))
	var by_point := _boot_run({"level": level_id, "at": [switch.x, switch.y]})
	assert_eq(game.camera.position, by_point.camera.position, "the camera starts as it would at the switch's point")
	var bad := FileAccess.open(sidecar, FileAccess.WRITE)
	bad.store_string(JSON.stringify({"description": "a camera that isn't one", "save": false, "camera": "S1 Switch"}))
	bad.close()
	assert_string_contains(TestMode.load_fixture("zz-camera-by-id", level_id)["error"],
			"'camera' must be [x, y] or a stable ID")
	var unknown := FileAccess.open(sidecar, FileAccess.WRITE)
	unknown.store_string(JSON.stringify({"description": "a camera on nothing", "save": false, "camera": "s9.switch"}))
	unknown.close()
	var refused: Node = load(MAIN_SCENE).instantiate()
	refused.test_mode_guard = TestModeGuard.new(true)
	add_child_autofree(refused)
	var errors: PackedStringArray = refused.enable_test_mode({"seed": 1, "time_scale": 0, "level": level_id,
			"fixture": "zz-camera-by-id"})
	assert_eq(errors.size(), 1, str(errors))
	assert_string_contains("\n".join(errors), "no 's9.switch' in level")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(sidecar))


func test_list_prints_each_fixture_with_its_description() -> void:
	var run := _run(MAKE_FIXTURE, ["--level=" + level_id, "--list"])
	assert_eq(run["code"], 0, run["text"])
	var lines := _lines_starting(run["text"], ["fresh: ", "gate"])
	assert_eq(lines.size(), 2, run["text"])
	if lines.size() == 2:
		assert_string_starts_with(lines[0], "fresh: The level as new")
		assert_string_starts_with(lines[1], "gate1-open: Gate open as after its basket fired")
	assert_false("make_fixture: wrote" in run["text"], "--list writes nothing")


func test_list_on_the_test_level_prints_its_own_table() -> void:
	var run := _run(MAKE_FIXTURE, ["--list"])
	assert_eq(run["code"], 0, run["text"])
	for name in ["fresh: The test level as new", "bump: ", "gate1-open: ", "gate2-open: ", "stress-still: "]:
		assert_eq(_lines_starting(run["text"], [name]).size(), 1, "%s in:\n%s" % [name, run["text"]])


func test_an_unknown_fixture_is_refused_naming_the_known_ones() -> void:
	var run := _run(MAKE_FIXTURE, ["--level=" + level_id, "gate9-open"])
	assert_eq(run["code"], 1, run["text"])
	assert_string_contains(run["text"], "gate9-open")
	assert_string_contains(run["text"], "fresh, gate1-open")
	assert_false(FileAccess.file_exists(TestMode.sidecar_path("gate9-open", level_id)))


func test_an_unknown_level_is_refused_naming_the_levels() -> void:
	var run := _run(MAKE_FIXTURE, ["--level=zz-no-such-level"])
	assert_eq(run["code"], 1, run["text"])
	assert_string_contains(run["text"], "no level 'zz-no-such-level'")
	assert_string_contains(run["text"], "test")


func test_an_unknown_argument_is_refused() -> void:
	var run := _run(MAKE_FIXTURE, ["--level=" + level_id, "--everything"])
	assert_eq(run["code"], 1, run["text"])
	assert_string_contains(run["text"], "--everything")


# --- The level report ----------------------------------------------------------------

func test_the_report_on_the_test_level() -> void:
	var run := _run(LEVEL_REPORT, [])
	var text: String = run["text"]
	assert_eq(run["code"], 0, text)
	assert_string_contains(text, "level_report: level test (version 1), 3 sections, 200 base slimes, first slime A")
	assert_string_contains(text, "base slimes: 200 of at most 200 (rule 16): PASS")
	assert_string_contains(text, "species per section (rule 11: section 1 has 3, each later section adds 1): "
			+ "section 1: A, B, C; section 2 adds D; section 3 adds E: PASS")
	var sets := _lines_starting(text, ["set "])
	assert_eq(sets.size(), 3, text)
	if sets.size() == 3:
		assert_string_contains(sets[0], "basket s1.basket, quota 6, opens gate s1.gate; available by then 30")
		assert_string_contains(sets[1], "basket s2.basket, quota 15, opens gate s2.gate; available by then 70")
		assert_string_contains(sets[2], "basket s3.basket, quota 60, no gate: the celebration")
		assert_string_contains(sets[2], "available by then 200")
	for section in ["== loop ==", "== population ==", "== sleeper rows ==", "== exploration branches ==",
			"== frontier sets ==", "== framing zones ==", "== reach", "== progress"]:
		assert_eq(_lines_starting(text, [section]).size(), 1, section)
	assert_eq(_lines_starting(text, ["section 1: basket s1.basket, quota 6; awake by then about ",
			"section 2: basket s2.basket, quota 15; ", "section 3: basket s3.basket, quota 60; "]).size(), 3,
			"one progress line per basket")
	assert_eq(_lines_starting(text, ["loop at section "]).size(), 3, "one line per gate state")
	assert_eq(_lines_starting(text, ["s2.branch.cave: "]).size(), 1, "the cave branch")


func test_the_report_on_another_level_as_json() -> void:
	# Through tools/level.sh (chunk LD3): it imports first and starts Godot
	# without its banner, so stdout is the JSON alone.
	var run := _run_wrapper(["report", "--level=" + level_id, "--json"])
	var text: String = run["text"]
	assert_eq(run["code"], 0, text)
	var json := JSON.new()
	assert_eq(json.parse(text), OK, "stdout is the JSON alone (--no-header): " + text)
	var report: Dictionary = json.data if typeof(json.data) == TYPE_DICTIONARY else {}
	assert_eq(report.get("level"), level_id)
	assert_eq(report.get("first_slime"), "A")
	assert_eq(report.get("population", {}).get("base_slimes"), 3.0, "the first slime and two sleepers")
	var progress: Array = report.get("progress", [])
	assert_eq(progress.size(), 2, "a line per basket")
	if progress.size() == 2:
		# Each ledge's sleeper is 160 px over the loop: out of a called base
		# slime's hop (about 133 px), so neither basket can fill.
		assert_eq(progress[0]["unreached"], ["s1.sleeper.01"])
		assert_false(progress[0]["progresses"])
	var sets: Array = report.get("frontier_sets", [])
	assert_eq(sets.size(), 2)
	if sets.size() == 2:
		assert_eq(sets[0]["gate"], "s1.gate")
		assert_eq(sets[1]["gate"], "", "section 2's set: the celebration")
		assert_eq(sets[1]["available"], 3.0)


func test_the_wrapper_refuses_an_unknown_tool() -> void:
	var run := _run_wrapper(["everything"])
	assert_eq(run["code"], 2)
	assert_eq(run["text"].strip_edges(), "", "what it says goes to stderr")


func test_the_report_refuses_an_unknown_level() -> void:
	var run := _run(LEVEL_REPORT, ["--level=zz-no-such-level"])
	assert_eq(run["code"], 2, run["text"])
	assert_string_contains(run["text"], "no level 'zz-no-such-level'")


# --- Helpers ----------------------------------------------------------------------------

## Runs `script` headless in a child Godot on this project with `args`:
## {"code", "text" (stdout and stderr)}.
func _run(script: String, args: Array) -> Dictionary:
	var argv := PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://"), "-s", script, "--"])
	argv.append_array(PackedStringArray(args))
	var output := []
	var code := OS.execute(OS.get_executable_path(), argv, output, true)
	return {"code": code, "text": "\n".join(output)}


## Runs tools/level.sh with `args` (the tool, then its arguments), as a
## designer does: {"code", "text" (stdout alone)}.
func _run_wrapper(args: Array) -> Dictionary:
	var argv := PackedStringArray(["GODOT=" + OS.get_executable_path(), "bash",
			ProjectSettings.globalize_path("res://tools/level.sh")])
	argv.append_array(PackedStringArray(args))
	var output := []
	var code := OS.execute("env", argv, output, false)
	return {"code": code, "text": "\n".join(output)}


## The lines of `text` starting with any of `prefixes`, in order.
static func _lines_starting(text: String, prefixes: Array) -> Array:
	var out := []
	for line in text.split("\n"):
		for prefix in prefixes:
			if line.begins_with(prefix):
				out.append(line)
				break
	return out


## A game (the main scene) in test mode, in a debug build, with `config`
## over {"seed": 1, "time_scale": 0}.
func _boot_run(config: Dictionary) -> Node:
	var game: Node = load(MAIN_SCENE).instantiate()
	game.test_mode_guard = TestModeGuard.new(true)
	add_child_autofree(game)
	var run := {"seed": 1, "time_scale": 0}
	run.merge(config, true)
	assert_eq(game.enable_test_mode(run), PackedStringArray(), str(config))
	return game


## The small level `id`, in a builder (free its level): a floor, a loop of
## two sections (s1.slide retired by s1.gate), the start's split zone and
## first slime, a sleeper on a ledge in each section, and a frontier set per
## section (section 2's with no gate, its basket releasing on the loop).
static func _small_level(id: String) -> LevelBuilder:
	var b := LevelBuilder.new(id, 1, "LevelTools")
	var terrain := b.group(b.level, "Terrain")
	b.terrain(terrain, "Floor", [[-0.5, FLOOR_Y], [END_X + 1.0, FLOOR_Y], [END_X + 1.0, FLOOR_Y + 300],
			[-0.5, FLOOR_Y + 300]])
	b.terrain(terrain, "Ledge1", [[1.0, 440], [1.3, 440], [1.3, 460], [1.0, 460]])
	b.terrain(terrain, "Ledge2", [[2.9, 440], [3.2, 440], [3.2, 460], [2.9, 460]])
	var loop := b.loop()
	b.segment(loop, "s1.loop", [[0.2, LOOP_Y], [FRONTIER_X, LOOP_Y]], 1, LoopData.OUTGOING, "")
	b.segment(loop, "s1.slide", [[FRONTIER_X, LOOP_Y], [FRONTIER_X, 300], [0.2, 300], [0.2, LOOP_Y]], 1,
			LoopData.RETURN, "s1.gate")
	b.segment(loop, "s2.loop", [[FRONTIER_X, LOOP_Y], [END_X, LOOP_Y]], 2, LoopData.OUTGOING, "")
	b.segment(loop, "s2.slide", [[END_X, LOOP_Y], [END_X, 200], [0.2, 200], [0.2, LOOP_Y]], 2, LoopData.RETURN, "")
	var start := b.group(b.level, "Start")
	b.split_zone(start, "start.split-zone", LevelBuilder.at(0.3, LOOP_Y), Vector2(0.3 * S, 150))
	b.first_slime(start, "A", LevelBuilder.at(0.25, LOOP_Y))
	var one := b.group(b.level, "Section1")
	b.sleeper_row(one, "s1", [[1.1, 440 - LevelBuilder.RIDE, "B"]])
	b.frontier_set(one, "s1", LevelBuilder.at(1.5, LOOP_Y), LevelBuilder.at(1.6, LOOP_Y), [1.62, FLOOR_Y, 1.8, 625],
			LevelBuilder.at(1.7, 700), Vector2(0.2 * S, 150), 2, LevelBuilder.at(1.9, LOOP_Y - 80))
	var two := b.group(b.level, "Section2")
	b.sleeper_row(two, "s2", [[3.0, 440 - LevelBuilder.RIDE, "D"]])
	var last := b.frontier_set(two, "s2", LevelBuilder.at(3.5, LOOP_Y), LevelBuilder.at(3.6, LOOP_Y),
			[3.62, FLOOR_Y, 3.8, 625], LevelBuilder.at(3.7, 700), Vector2(0.2 * S, 150), 2)
	LevelBuilder.outlet_at(last.basket, LevelBuilder.at(3.9, LOOP_Y))
	return b


## Removes every level folder this script makes (PREFIX), this run's and
## any an earlier run left behind.
func _remove_stale_levels() -> void:
	for name in DirAccess.get_directories_at(LevelCatalog.LEVELS_DIR):
		if name.begins_with(PREFIX):
			_remove_tree(ProjectSettings.globalize_path(LevelCatalog.dir_of(name)))


## Removes the folder `path` (absolute) and everything in it.
func _remove_tree(path: String) -> void:
	for sub in DirAccess.get_directories_at(path):
		_remove_tree(path.path_join(sub))
	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)
