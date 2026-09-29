extends GutTest
## Chunk LD1: test mode plays the level it is given by ID ("level",
## --level=<id>), looks its fixtures up in that level's folder, and starts
## the camera where "at" says (a stable ID or a level point, over the
## fixture's camera). A normal debug run still plays the test level.
##
## A second level is built here, in code: a tiny valid level (a loop of one
## section, its return route, the start's split zone, the first slime, one
## floor and one sleeper) saved to res://levels/<unique id>/ with two
## fixtures, and a broken one (no loop). Both folders are removed after the
## script, and any left by an earlier run that crashed before.

# @test-link [[req_test_level_and_test_mode]]

const MAIN_SCENE := "res://src/main.tscn"
## The prefix of the levels this script makes, for the clean-up.
const PREFIX := "zz-selection-"
## The tiny level's loop runs at a base slime's centre height over its floor.
const FLOOR_Y := 600.0
const LOOP_Y := FLOOR_Y - PlaceholderArt.SLIME_RADIUS
const LOOP_LEFT := 200.0
const LOOP_RIGHT := 3400.0
const FIRST_SLIME_AT := Vector2(400.0, LOOP_Y)
## The sleeper, far from the start: where "at" puts the camera.
const SLEEPER_ID := "start.sleeper.01"
const SLEEPER_AT := Vector2(2600.0, LOOP_Y)
const TICKS := 30

## The tiny valid level's ID, and the broken level's.
var level_id := ""
var broken_id := ""


func before_all() -> void:
	_remove_stale_levels()
	var stamp := Time.get_ticks_usec()
	level_id = "%s%d" % [PREFIX, stamp]
	broken_id = "%sbroken-%d" % [PREFIX, stamp]
	_save_level(_tiny_level(level_id), level_id)
	_write_fixture(level_id, "fresh", {"description": "The tiny level as new.", "save": false})
	_write_fixture(level_id, "sleeper-view", {"description": "Fresh, the camera on the sleeper.", "save": false,
			"camera": [SLEEPER_AT.x, SLEEPER_AT.y]})
	var broken := Level.new()
	broken.name = "Level"
	broken.level_id = broken_id
	_save_level(broken, broken_id)


func after_all() -> void:
	_remove_stale_levels()


## A game (the main scene) added to the test, in a debug build.
func _boot() -> Node:
	var game: Node = load(MAIN_SCENE).instantiate()
	game.test_mode_guard = TestModeGuard.new(true)
	add_child_autofree(game)
	return game


## A game in test mode with `config` over {"seed": 1, "time_scale": 0}.
func _boot_run(config: Dictionary) -> Node:
	var game := _boot()
	var run := {"seed": 1, "time_scale": 0}
	run.merge(config, true)
	assert_eq(game.enable_test_mode(run), PackedStringArray(), str(config))
	return game


## The Level nodes under the game root.
func _levels_in(game: Node) -> Array:
	return game.get_children().filter(func(child): return child is Level)


func _has_error(errors: PackedStringArray, fragment: String) -> bool:
	for e in errors:
		if fragment in e:
			return true
	return false


func test_the_tiny_level_is_found_by_id() -> void:
	assert_true(LevelCatalog.exists(level_id))
	assert_true(level_id in LevelCatalog.ids())


func test_test_mode_plays_the_level_it_is_given() -> void:
	var game := _boot_run({"level": level_id})
	assert_eq(game.level.level_id, level_id)
	assert_eq(game.level.load_errors, PackedStringArray())
	assert_eq(game.simulation.level, game.level.data)
	assert_eq(game.simulation.dump()["level"]["id"], level_id)
	assert_eq(_levels_in(game), [game.level], "the test level is gone: one level in the game")
	assert_eq(game.get_child(0), game.level, "drawn under the slimes")
	var sim: Simulation = game.simulation
	assert_eq(sim.slimes.slime_count, 2, "the first slime and the sleeper")
	var first := -1
	for slime_id in sim.slimes.ids():
		if sim.identities.stable_id_of(slime_id) == "start.first-slime":
			first = slime_id
	assert_ne(first, -1, "the first slime is woken")
	if first != -1:
		assert_eq(sim.slimes.state_of(first), SlimeBodies.TRAIN)
		assert_lt(sim.slimes.centre_of(first).distance_to(FIRST_SLIME_AT), 1.0, "on the tiny level's spot")
	game.test_mode.run_ticks(TICKS)
	assert_eq(sim.tick, TICKS)


func test_the_fixture_is_looked_up_in_the_level() -> void:
	var fixture := _boot_run({"level": level_id, "fixture": "fresh"})
	var plain := _boot_run({"level": level_id})
	fixture.test_mode.run_ticks(TICKS)
	plain.test_mode.run_ticks(TICKS)
	assert_eq(fixture.simulation.state_hash(), plain.simulation.state_hash(), "fresh is the level as new")
	var game := _boot()
	var errors: PackedStringArray = game.enable_test_mode({"seed": 1, "level": level_id, "fixture": "bump"})
	assert_true(_has_error(errors, "level '%s'" % level_id), "the error names the level: %s" % errors)
	assert_true(_has_error(errors, LevelCatalog.fixtures_dir(level_id) + "bump.fixture.json"), str(errors))


func test_an_unknown_level_leaves_the_game_as_it_was() -> void:
	var game := _boot()
	var level: Level = game.level
	var simulation: Simulation = game.simulation
	var errors: PackedStringArray = game.enable_test_mode({"seed": 1, "level": "zz-no-such-level"})
	assert_true(_has_error(errors, "res://levels/zz-no-such-level/level.tscn"), str(errors))
	assert_eq(game.level, level)
	assert_eq(game.simulation, simulation)
	assert_null(game.test_mode)


func test_a_broken_level_is_refused() -> void:
	var game := _boot()
	var level: Level = game.level
	var simulation: Simulation = game.simulation
	var errors: PackedStringArray = game.enable_test_mode({"seed": 1, "level": broken_id})
	assert_true(_has_error(errors, "level %s: the level has no loop" % broken_id), str(errors))
	assert_eq(game.level, level)
	assert_eq(game.simulation, simulation)
	assert_null(game.test_mode)
	assert_eq(_levels_in(game), [level])


func test_at_a_stable_id_starts_the_camera_there() -> void:
	var by_fixture := _boot_run({"level": level_id, "fixture": "sleeper-view"})
	var by_id := _boot_run({"level": level_id, "at": SLEEPER_ID})
	var by_point := _boot_run({"level": level_id, "at": [SLEEPER_AT.x, SLEEPER_AT.y]})
	var plain := _boot_run({"level": level_id})
	assert_gt(by_fixture.camera.position.distance_to(plain.camera.position), 1000.0, "the fixture moves it")
	assert_eq(by_id.camera.position, by_fixture.camera.position, "as a fixture camera on the sleeper")
	assert_eq(by_point.camera.position, by_fixture.camera.position)
	assert_eq(by_id.simulation.camera.distance, by_fixture.simulation.camera.distance)


func test_at_wins_over_the_fixture_camera() -> void:
	var both := _boot_run({"level": level_id, "fixture": "sleeper-view", "at": [FIRST_SLIME_AT.x, FIRST_SLIME_AT.y]})
	var at_only := _boot_run({"level": level_id, "at": [FIRST_SLIME_AT.x, FIRST_SLIME_AT.y]})
	var fixture_only := _boot_run({"level": level_id, "fixture": "sleeper-view"})
	assert_eq(both.camera.position, at_only.camera.position)
	assert_ne(both.camera.position, fixture_only.camera.position)


func test_at_works_on_the_test_level() -> void:
	var game := _boot_run({"at": "s1.gate"})
	var gate_at: Vector2 = game.level.position_of(game.level.find("s1.gate"))
	var near := _boot_run({"at": [gate_at.x, gate_at.y]})
	assert_eq(game.camera.position, near.camera.position)


func test_at_a_route_starts_the_camera_at_its_start() -> void:
	# A loop segment or a route back is placed by its curve: "at" is its
	# first point, not the node's origin.
	var game := _boot_run({"at": "s2.loop"})
	var start: Vector2 = game.level.data.loop.segment("s2.loop")["points"][0]
	var near := _boot_run({"at": [start.x, start.y]})
	assert_eq(game.camera.position, near.camera.position)


func test_an_unknown_at_is_reported_and_the_game_kept() -> void:
	var game := _boot()
	var simulation: Simulation = game.simulation
	var errors: PackedStringArray = game.enable_test_mode({"seed": 1, "level": level_id, "at": "s9.nothing"})
	assert_true(_has_error(errors, "s9.nothing"), str(errors))
	assert_true(_has_error(errors, level_id), "names the level: %s" % errors)
	assert_eq(game.level.level_id, LevelCatalog.DEFAULT_ID, "the level wasn't switched")
	assert_eq(game.simulation, simulation)
	assert_null(game.test_mode)


func test_switching_back_to_the_test_level() -> void:
	var game := _boot_run({"level": level_id})
	assert_eq(game.enable_test_mode({"seed": 5, "time_scale": 0}), PackedStringArray())
	assert_eq(game.level.level_id, LevelCatalog.DEFAULT_ID)
	assert_eq(game.simulation.level, game.level.data)
	assert_eq(_levels_in(game), [game.level])
	var reference := _boot()
	assert_eq(reference.enable_test_mode({"seed": 5, "time_scale": 0}), PackedStringArray())
	game.test_mode.run_ticks(60)
	reference.test_mode.run_ticks(60)
	assert_eq(game.simulation.state_hash(), reference.simulation.state_hash(),
			"the test level plays as if it had never been left (its terrain rebuilt)")
	assert_eq(game.restart_fresh().level, game.level.data, "a restart stays on the loaded level")


func test_a_normal_debug_game_plays_the_test_level() -> void:
	var game := _boot()
	assert_null(game.test_mode)
	assert_eq(game.level.level_id, LevelCatalog.DEFAULT_ID)
	assert_eq(game.simulation.level, game.level.data)


func test_the_command_line_plays_the_level() -> void:
	var args := PackedStringArray([
		"--headless", "--quit-after", "3000", "--path", ProjectSettings.globalize_path("res://"), "--",
		"--test-mode", "--level=" + level_id, "--seed=1", "--run-ticks=%d" % TICKS,
	])
	var output := []
	var code := OS.execute(OS.get_executable_path(), args, output, true)
	var text := "\n".join(output)
	assert_eq(code, 0, text)
	var line := RegEx.create_from_string("STATE tick=(\\d+) hash=([0-9a-f]{64})").search(text)
	assert_not_null(line, "no STATE line in:\n%s" % text)
	if line == null:
		return
	assert_eq(line.get_string(1).to_int(), TICKS)
	var here := _boot_run({"level": level_id})
	here.test_mode.run_ticks(TICKS)
	assert_eq(line.get_string(2), here.simulation.state_hash(), "the child played the tiny level")


## The tiny valid level `id`, every node owned by its root.
func _tiny_level(id: String) -> Level:
	var root := Level.new()
	root.name = "Level"
	root.level_id = id
	var floor_piece := Terrain.new()
	floor_piece.name = "Floor"
	floor_piece.curve = _curve([Vector2(-400, FLOOR_Y), Vector2(3800, FLOOR_Y), Vector2(3800, FLOOR_Y + 300),
			Vector2(-400, FLOOR_Y + 300), Vector2(-400, FLOOR_Y)])
	_own(root, root, floor_piece)
	var loop := Loop.new()
	loop.name = "Loop"
	_own(root, root, loop)
	var outgoing := LoopSegment.new()
	outgoing.name = "S1Loop"
	outgoing.stable_id = "s1.loop"
	outgoing.kind = "outgoing"
	outgoing.curve = _curve([Vector2(LOOP_LEFT, LOOP_Y), Vector2(LOOP_RIGHT, LOOP_Y)])
	_own(root, loop, outgoing)
	var slide := LoopSegment.new()
	slide.name = "S1Slide"
	slide.stable_id = "s1.slide"
	slide.kind = "return"
	slide.curve = _curve([Vector2(LOOP_RIGHT, LOOP_Y), Vector2(LOOP_RIGHT, 300), Vector2(LOOP_LEFT, 300),
			Vector2(LOOP_LEFT, LOOP_Y)])
	_own(root, loop, slide)
	var split := SplitZone.new()
	split.name = "SplitZone"
	split.stable_id = "start.split-zone"
	split.position = Vector2(LOOP_LEFT, LOOP_Y)
	_own(root, root, split)
	var first := FirstSlime.new()
	first.name = "FirstSlime"
	first.position = FIRST_SLIME_AT
	_own(root, root, first)
	var sleeper := Sleeper.new()
	sleeper.name = "Sleeper01"
	sleeper.stable_id = SLEEPER_ID
	sleeper.position = SLEEPER_AT
	_own(root, root, sleeper)
	return root


func _curve(points: Array) -> Curve2D:
	var curve := Curve2D.new()
	for point in points:
		curve.add_point(point)
	return curve


func _own(root: Node, parent: Node, child: Node) -> void:
	parent.add_child(child)
	child.owner = root


## Packs `root` and saves it as level `id`'s scene (and its fixtures'
## folder); frees `root`.
func _save_level(root: Level, id: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(LevelCatalog.fixtures_dir(id)))
	var packed := PackedScene.new()
	assert_eq(packed.pack(root), OK)
	assert_eq(ResourceSaver.save(packed, LevelCatalog.scene_path(id)), OK)
	root.free()


func _write_fixture(id: String, name: String, sidecar: Dictionary) -> void:
	var file := FileAccess.open(TestMode.sidecar_path(name, id), FileAccess.WRITE)
	file.store_string(JSON.stringify(sidecar, "\t"))
	file.close()


## Removes every level folder this script makes (PREFIX), this run's and
## any an earlier run left behind.
func _remove_stale_levels() -> void:
	for name in DirAccess.get_directories_at(LevelCatalog.LEVELS_DIR):
		if name.begins_with(PREFIX):
			_remove_tree(ProjectSettings.globalize_path(LevelCatalog.dir_of(name)))


func _remove_tree(path: String) -> void:
	for sub in DirAccess.get_directories_at(path):
		_remove_tree(path.path_join(sub))
	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)
