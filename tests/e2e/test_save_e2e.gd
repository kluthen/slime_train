extends GutTest
## Kill and reload [DoD 28, partly], through the real game scene: a scripted
## run with a call is saved, a new game (a new session: new scene, new
## simulation, the level loaded again) starts from that save, and its slimes
## and state hash match; run on, it stays equal to the run that was never
## interrupted. Also: a fresh start without a save, autosave (every
## interval, on going to the background, off in test mode unless asked), a
## save that can't be used is left untouched, and the same through separate
## Godot processes (--save, --load).
##
## Every game here gets its own SaveStore on a scratch directory; a game a
## test adds without one never writes (only the main scene gets the default
## user://saves/).

# @test-link [[req_persistence_and_saves]]
# @test-link [[rule_saves_never_wiped]]
# @test-link [[req_test_level_and_test_mode]]

const ChildGame := preload("res://tests/e2e/child_game.gd")
const MAIN_SCENE := "res://src/main.tscn"
const SCRIPT_PATH := "res://tests/e2e/scripts/save_call.json"
const DIR := "user://test-save-e2e/"
const LEVEL := "test"
## The call (tick 120, near the first slime) has been answered by then.
const SAVE_TICK := 300
const MORE_TICKS := 600


func before_each() -> void:
	_clear(DIR)


func after_all() -> void:
	_clear(DIR)


func _clear(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)


## A game with `store` (null: none), added to the tree: its _ready loads the
## level and the store's save, if any.
func _game(store: SaveStore) -> Node:
	var game: Node = load(MAIN_SCENE).instantiate()
	game.save_store = store
	add_child_autofree(game)
	return game


func _config(overrides := {}) -> Dictionary:
	var loaded := TestMode.load_config_file(SCRIPT_PATH)
	assert_eq(loaded["errors"], PackedStringArray())
	var config: Dictionary = loaded["config"]
	config["time_scale"] = 0
	config.merge(overrides, true)
	return config


## The scripted run up to SAVE_TICK, saved to `store`.
func _played_and_saved(store: SaveStore, overrides := {}) -> Node:
	var game := _game(store)
	assert_eq(game.enable_test_mode(_config(overrides)), PackedStringArray())
	game.test_mode.run_ticks(SAVE_TICK)
	assert_eq(game.save_now(), "")
	assert_true(FileAccess.file_exists(store.path_for(LEVEL)))
	return game


func _slimes(sim: Simulation) -> Array:
	var out := []
	for slime_id in sim.slimes.ids():
		out.append({"id": slime_id, "species": sim.slimes.species_of(slime_id),
				"size": sim.slimes.size_of(slime_id), "state": sim.slimes.state_of(slime_id),
				"phase": sim.free_slimes.phase_of(slime_id), "centre": sim.slimes.centre_of(slime_id),
				"members": sim.identities.members_of(slime_id)})
	return out


func test_a_killed_game_reloads_where_it_was() -> void:
	# The view is the screen's: normal play re-syncs it to the window every
	# tick. Played on the screen the reloaded game has, the hashes compare.
	var screen := get_viewport().get_visible_rect().size
	var played := _played_and_saved(SaveStore.new(DIR), {"screen_size": [screen.x, screen.y]})
	var before: Simulation = played.simulation
	var states := []
	for slime in _slimes(before):
		states.append(slime["state"])
	assert_true(SlimeBodies.FREE in states, "the saved moment has a called slime")

	var reloaded := _game(SaveStore.new(DIR))
	var after: Simulation = reloaded.simulation
	assert_null(reloaded.test_mode, "normal play")
	assert_eq(after.tick, SAVE_TICK)
	var was := _slimes(before)
	var now := _slimes(after)
	assert_eq(now.size(), was.size())
	for k in mini(now.size(), was.size()):
		assert_eq(now[k]["id"], was[k]["id"])
		assert_eq(now[k]["species"], was[k]["species"])
		assert_eq(now[k]["size"], was[k]["size"])
		assert_eq(now[k]["state"], was[k]["state"])
		assert_eq(now[k]["phase"], was[k]["phase"])
		assert_eq(now[k]["members"], was[k]["members"])
		assert_lt((now[k]["centre"] as Vector2).distance_to(was[k]["centre"]), 0.01)
	assert_eq(after.state_hash(), before.state_hash())


func test_a_reloaded_game_carries_on_like_the_one_never_stopped() -> void:
	var store := SaveStore.new(DIR)
	var played := _played_and_saved(store)
	played.test_mode.run_ticks(MORE_TICKS)
	var resumed := _game(null)
	assert_eq(resumed.enable_test_mode(_config({"load": store.path_for(LEVEL)})), PackedStringArray())
	assert_eq(resumed.simulation.tick, SAVE_TICK)
	resumed.test_mode.run_ticks(MORE_TICKS)
	assert_eq(resumed.simulation.tick, played.simulation.tick)
	assert_eq(resumed.simulation.state_hash(), played.simulation.state_hash())


func test_without_a_save_the_game_starts_fresh() -> void:
	var game := _game(SaveStore.new(DIR))
	var sim: Simulation = game.simulation
	assert_eq(sim.tick, 0)
	assert_eq(sim.slimes.slime_count, 1 + game.level.data.sleepers.size(),
			"the first slime is woken, the sleepers are placed")
	var awake: Array[int] = []
	for slime_id in sim.slimes.ids():
		if sim.slimes.state_of(slime_id) != SlimeBodies.SLEEPER:
			awake.append(slime_id)
	assert_eq(awake.size(), 1)
	assert_eq(sim.identities.members_of(awake[0]), PackedStringArray(["start.first-slime"]))
	assert_false(FileAccess.file_exists(DIR + "test.json"), "nothing written yet")


func test_normal_play_autosaves_every_interval() -> void:
	var game := _game(SaveStore.new(DIR))
	game.autosave.interval = 0.1
	await wait_seconds(0.5)
	var result := SaveStore.read_file(DIR + "test.json")
	assert_eq(result["status"], SaveStore.OK)
	if result["status"] == SaveStore.OK:
		assert_gt(int(result["save"]["sim"]["tick"]), 0)


func test_going_to_the_background_saves() -> void:
	var game := _game(SaveStore.new(DIR))
	game.simulation.run(30)
	game.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	var result := SaveStore.read_file(DIR + "test.json")
	assert_eq(result["status"], SaveStore.OK)
	if result["status"] == SaveStore.OK:
		assert_eq(int(result["save"]["sim"]["tick"]), game.simulation.tick)


func test_autosave_is_off_in_test_mode_unless_asked() -> void:
	var quiet := _game(SaveStore.new(DIR))
	assert_eq(quiet.enable_test_mode(_config({"time_scale": 1})), PackedStringArray())
	quiet.autosave.interval = 0.05
	await wait_seconds(0.3)
	quiet.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_false(FileAccess.file_exists(DIR + "test.json"), "test mode: no autosave")
	var asked := _game(SaveStore.new(DIR))
	assert_eq(asked.enable_test_mode(_config({"time_scale": 1, "autosave": true})), PackedStringArray())
	asked.autosave.interval = 0.05
	await wait_seconds(0.3)
	assert_true(FileAccess.file_exists(DIR + "test.json"), "autosave asked for")


func test_test_mode_can_save_on_demand() -> void:
	var game := _game(SaveStore.new(DIR))
	assert_eq(game.enable_test_mode(_config()), PackedStringArray())
	game.test_mode.run_ticks(10)
	assert_eq(game.save_now(), "")
	assert_eq(int(SaveStore.read_file(DIR + "test.json")["save"]["sim"]["tick"]), 10)


func test_a_game_without_a_store_never_writes() -> void:
	var game := _game(null)
	assert_null(game.save_store, "only the main scene gets the default store")
	assert_ne(game.save_now(), "")


## Chunk 19 (decision A, proposed): with no backup, the unreadable file is
## set aside with its bytes intact, never written over, and the fresh level
## saves again.
# @test-link [[rule_saves_never_wiped]]
func test_an_unreadable_save_starts_fresh_and_is_never_written_over() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	var corrupt := "{\"format\": 1, \"slimes\": [ truncated"
	var file := FileAccess.open(DIR + "test.json", FileAccess.WRITE)
	file.store_string(corrupt)
	file.close()
	var game := _game(SaveStore.new(DIR))
	assert_eq(game.simulation.tick, 0, "fresh")
	assert_eq(game.simulation.slimes.slime_count, 1 + game.level.data.sleepers.size(),
			"the first slime and the sleepers")
	var aside := DIR + "test.json" + SaveStore.SET_ASIDE_SUFFIX
	assert_eq(FileAccess.get_file_as_string(aside), corrupt, "set aside, untouched")
	assert_eq(game.save_now(), "", "the fresh level saves")
	game.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_eq(SaveStore.read_file(DIR + "test.json")["status"], SaveStore.OK)
	assert_eq(FileAccess.get_file_as_string(aside), corrupt, "never written over")


## Chunk 19 (decision C, proposed): a save of an older version of the level
## is migrated and loaded; the file as it was is kept as <level>.json.v<old
## version> before anything is written, and the next save is at the level's
## version.
# @test-link [[rule_released_level_stable_with_migration]]
# @test-link [[rule_saves_never_wiped]]
func test_a_save_of_an_older_level_version_is_migrated_and_its_file_kept() -> void:
	var store := SaveStore.new(DIR)
	var played := _played_and_saved(store)
	var version: int = played.level.data.level_version
	var save: Dictionary = store.read(LEVEL)["save"]
	save["level"]["version"] = version - 1
	assert_eq(SaveStore.write_file(store.path_for(LEVEL), save), "")
	var before := FileAccess.get_file_as_bytes(store.path_for(LEVEL))
	var game := _game(SaveStore.new(DIR))
	assert_eq(game.simulation.tick, SAVE_TICK, "loaded, not fresh")
	assert_eq(game.simulation.slimes.slime_count, played.simulation.slimes.slime_count, "every slime")
	var copy := store.path_for(LEVEL) + ".v%d" % (version - 1)
	assert_eq(FileAccess.get_file_as_bytes(copy), before, "the pre-migration file kept, byte for byte")
	assert_eq(game.save_now(), "", "the migrated save is written")
	assert_eq(int(store.read(LEVEL)["save"]["level"]["version"]), version, "at the level's version")
	assert_eq(FileAccess.get_file_as_bytes(copy), before, "the copy stays")


## A save of a newer version of the level (a newer game) can't be read: it
## is kept as it is, and nothing is written over it (the level plays fresh).
# @test-link [[rule_saves_never_wiped]]
func test_a_save_of_a_newer_level_version_is_not_loaded_nor_written_over() -> void:
	var store := SaveStore.new(DIR)
	_played_and_saved(store)
	var save: Dictionary = store.read(LEVEL)["save"]
	save["level"]["version"] = 999
	assert_eq(SaveStore.write_file(store.path_for(LEVEL), save), "")
	var before := FileAccess.get_file_as_bytes(store.path_for(LEVEL))
	var game := _game(SaveStore.new(DIR))
	assert_eq(game.simulation.tick, 0, "fresh")
	assert_ne(game.save_now(), "", "refused")
	assert_eq(FileAccess.get_file_as_bytes(store.path_for(LEVEL)), before, "untouched")


func test_separate_processes_save_and_reload() -> void:
	var path := ProjectSettings.globalize_path(DIR + "child.json")
	var first := _child(["--run-ticks=%d" % SAVE_TICK, "--save=" + path])
	assert_eq(first["code"], 0, "saving child exit code")
	assert_true(FileAccess.file_exists(path))
	var second := _child(["--load=" + path, "--run-ticks=%d" % MORE_TICKS])
	assert_eq(second["code"], 0, "loading child exit code")
	var game := _game(null)
	assert_eq(game.enable_test_mode(_config()), PackedStringArray())
	game.test_mode.run_ticks(SAVE_TICK)
	assert_eq(first["hash"], game.simulation.state_hash(), "saved at the same state")
	game.test_mode.run_ticks(MORE_TICKS)
	assert_eq(second["tick"], SAVE_TICK + MORE_TICKS)
	assert_eq(second["hash"], game.simulation.state_hash(), "carried on the same")


## Runs the game in a child process in test mode with the call script and
## `extra` flags. Returns {"code", "tick", "hash"}.
func _child(extra: Array) -> Dictionary:
	var args := ChildGame.engine_args(3000)
	args.append_array([
		"--test-mode", "--test-script=" + SCRIPT_PATH,
	])
	args.append_array(PackedStringArray(extra))
	var output := []
	var code := OS.execute(OS.get_executable_path(), args, output, true)
	var text := "\n".join(output)
	var line := RegEx.create_from_string("STATE tick=(\\d+) hash=([0-9a-f]{64})").search(text)
	assert_not_null(line, "no STATE line in:\n%s" % text)
	if line == null:
		return {"code": code, "tick": -1, "hash": ""}
	return {"code": code, "tick": line.get_string(1).to_int(), "hash": line.get_string(2)}
