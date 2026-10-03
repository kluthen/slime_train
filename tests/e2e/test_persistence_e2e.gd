extends GutTest
## Persistence through the real game scene (chunk 19, DoD 28): "killing the
## app at any moment and reopening it restores slimes, objects and gates as
## of the last save, with no slime left in mid-air".
##
## - `midair` (a fixture of slimes saved in the air): loaded, in test mode or
##   in normal play, every awake slime is on what is below it (D12), none
##   lost, the population whole.
## - `old-version` (a fixture saved by the test level's version 1, one sleeper
##   elsewhere than version 2 has it): the moved sleeper is lost the usual way
##   (to the loop start, in the lost log), no slime is dropped, the file as it
##   was is kept as test.json.v1, and the next save is at version 2 (D72).
## - A kill during a write, simulated deterministically: the files are laid
##   out as a kill at each point of SaveStore's write sequence would leave
##   them (side file half written, backup's side file half written, new save
##   whole but not yet swapped in), and as storage that damaged the save
##   mid-write would (the backup then used). A new game on the same store
##   resumes from the last whole save and saves again (not blocked).
##
## Every game here gets its own SaveStore on a scratch directory.

# @test-link [[req_persistence_and_saves]]

const MAIN_SCENE := "res://src/main.tscn"
const SCRIPT_PATH := "res://tests/e2e/scripts/save_call.json"
const DIR := "user://test-persistence-e2e/"
const LEVEL := "test"
const SEED := 5
## The test level's population: the first slime and 199 sleepers.
const POPULATION := 200
## The test level's version since chunk 19, and old-version's.
const VERSION := 2
const OLD_VERSION := 1
## The two saves of the kill tests (A, then B), and how far the game plays
## on after B.
const SAVE_A_TICK := 300
const SAVE_B_TICK := 600
const PAST_B_TICK := 900
## A landed slime has a ring point this close to what it rests on, px (the
## terrain keeps a ring point SlimeBodies.terrain_skin, 3 px, off it).
const LANDED := 5.0
## midair's highest slime falls at least this far when it is loaded, px.
const WELL_ABOVE := 100.0


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
## level and the store's save, if any (normal play).
func _game(store: SaveStore) -> Node:
	var game: Node = load(MAIN_SCENE).instantiate()
	game.save_store = store
	add_child_autofree(game)
	return game


## A game without a store in test mode with `config` over the defaults.
func _boot(config: Dictionary) -> Node:
	var game := _game(null)
	var run := {"seed": SEED, "time_scale": 0}
	run.merge(config, true)
	assert_eq(game.enable_test_mode(run), PackedStringArray())
	return game


## Writes `bytes` to `path` in DIR (made if needed).
func _put(path: String, bytes: PackedByteArray) -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()


## The first half of `bytes`: a file cut off mid-write.
static func _half(bytes: PackedByteArray) -> PackedByteArray:
	return bytes.slice(0, bytes.size() / 2)


## The runtime id of the slime holding stable ID `id` in `sim`, or -1.
static func _holder(sim: Simulation, id: String) -> int:
	for slime_id in sim.slimes.ids():
		if id in sim.identities.members_of(slime_id):
			return slime_id
	return -1


## The weight of every slime of `sim` (their sizes summed).
static func _weight(sim: Simulation) -> int:
	var out := 0
	for slime_id in sim.slimes.ids():
		out += sim.slimes.size_of(slime_id)
	return out


## Whether a ring point of slime `slime_id` is within LANDED of the terrain,
## a shut door or another slime's ring: what it rests on.
static func _on_something(sim: Simulation, slime_id: int) -> bool:
	var bodies := sim.slimes
	var points := bodies.points_of(slime_id)
	var solids: Array[TerrainSegments] = [bodies.terrain]
	solids.append_array(bodies.doors)
	for solid in solids:
		for p in points:
			if solid.resolve(p)["distance"] <= LANDED:
				return true
	var reach := 4.0 * bodies.radius_of(slime_id)
	for other in bodies.ids():
		if other == slime_id or bodies.centre_of(other).distance_to(bodies.centre_of(slime_id)) > reach:
			continue
		for q in bodies.points_of(other):
			for p in points:
				if p.distance_to(q) <= LANDED:
					return true
	return false


## Asserts no slime of `sim` is in mid-air: every one that is awake, not in
## a basket and not parked is supported and rests on something.
func _assert_none_in_the_air(sim: Simulation, label: String) -> void:
	for slime_id in sim.slimes.ids():
		var state := sim.slimes.state_of(slime_id)
		if state == SlimeBodies.SLEEPER or state == SlimeBodies.IN_BASKET or sim.slimes.is_parked(slime_id):
			continue
		var what := "%s: slime %d (%s)" % [label, slime_id, ", ".join(sim.identities.members_of(slime_id))]
		assert_true(sim.slimes.body_of(slime_id)["supported"], what + " is supported")
		assert_true(_on_something(sim, slime_id), what + " rests on what is below it")


# --- midair ------------------------------------------------------------------------

## Checks a game just loaded from the midair fixture's save `saved`: the
## population whole, none lost, no slime in the air, and every awake slime
## put straight down from where it was saved (the highest well down).
func _check_midair(sim: Simulation, saved: Dictionary, label: String) -> void:
	assert_eq(sim.slimes.slime_count, POPULATION, label + ": every slime")
	assert_eq(_weight(sim), POPULATION, label)
	assert_eq(sim.offscreen.lost, [], label + ": none lost")
	_assert_none_in_the_air(sim, label)
	var awake := 0
	var deepest := 0.0
	for entry in saved["slimes"]:
		if entry["state"] == "sleeper":
			continue
		awake += 1
		var slime := _holder(sim, entry["members"][0])
		var was := SaveData.vector_from(entry["centre"])
		var now := sim.slimes.centre_of(slime)
		assert_eq(sim.identities.members_of(slime), PackedStringArray(entry["members"]), label)
		assert_almost_eq(now.x, was.x, 0.01, "%s: %s straight down" % [label, entry["members"][0]])
		assert_gte(now.y, was.y - 0.01, "%s: %s never up" % [label, entry["members"][0]])
		deepest = maxf(deepest, now.y - was.y)
	var now_awake := 0
	for slime_id in sim.slimes.ids():
		if sim.slimes.state_of(slime_id) != SlimeBodies.SLEEPER:
			now_awake += 1
	assert_eq(now_awake, awake, label + ": as many awake as saved")
	assert_gt(awake, 3, label + ": several awake slimes")
	assert_gt(deepest, WELL_ABOVE, label + ": one was well above the ground")


func test_midair_loads_in_test_mode_with_no_slime_in_the_air() -> void:
	var saved: Dictionary = TestMode.load_fixture("midair")["save"]
	assert_false(saved.is_empty(), "midair has a save")
	var game := _boot({"fixture": "midair"})
	_check_midair(game.simulation, saved, "test mode")


func test_midair_reopened_in_normal_play_has_no_slime_in_the_air() -> void:
	var saved: Dictionary = TestMode.load_fixture("midair")["save"]
	_put(DIR + "test.json", FileAccess.get_file_as_bytes(TestMode.fixture_path("midair")))
	var game := _game(SaveStore.new(DIR))
	assert_null(game.test_mode, "normal play")
	_check_midair(game.simulation, saved, "normal play")
	assert_eq(game.save_now(), "", "not blocked")


# --- old-version -------------------------------------------------------------------

## The stable ID of the one sleeper old-version's save keeps elsewhere than
## the level: found from the files, so the test names no sleeper.
func _moved_sleeper(level: Level) -> String:
	var saved: Dictionary = TestMode.load_fixture("old-version")["save"]
	var moved := []
	for entry in saved["slimes"]:
		if entry["state"] == "sleeper" and SaveMigration.sleeper_moved(entry, level.data.sleepers[entry["id"]]):
			moved.append(entry["id"])
	assert_eq(moved.size(), 1, "old-version moves one sleeper: %s" % [moved])
	return moved[0] if moved.size() == 1 else ""


## Checks a game just loaded from old-version: the moved sleeper back on the
## train at the loop start and in the lost log, every slime counted.
func _check_migrated(game: Node, label: String) -> void:
	var sim: Simulation = game.simulation
	var moved := _moved_sleeper(game.level)
	var slime := _holder(sim, moved)
	assert_ne(slime, -1, "%s: %s still in the game" % [label, moved])
	if slime == -1:
		return
	assert_eq(sim.slimes.state_of(slime), SlimeBodies.TRAIN, label + ": on the train")
	assert_true(sim.train.tracks(slime), label + ": the train tracks it")
	assert_lte(sim.train.distance_of(slime), LoopStart.STRETCH, label + ": at the loop start")
	var lost := sim.offscreen.lost.filter(func(entry): return entry["reason"] == Offscreen.LOST)
	assert_eq(lost.map(func(entry): return entry["id"]), [slime], label + ": in the lost log, alone")
	assert_eq(sim.slimes.slime_count, POPULATION, label + ": no slime dropped, none added")
	assert_eq(_weight(sim), POPULATION, label + ": every base slime counted")
	_assert_none_in_the_air(sim, label)


# @test-link [[rule_released_level_stable_with_migration]]
# @test-link [[rule_saves_never_wiped]]
func test_old_version_reopened_in_normal_play_migrates_and_keeps_its_file() -> void:
	var original := FileAccess.get_file_as_bytes(TestMode.fixture_path("old-version"))
	assert_eq(int(TestMode.load_fixture("old-version")["save"]["level"]["version"]), OLD_VERSION)
	_put(DIR + "test.json", original)
	var store := SaveStore.new(DIR)
	var game := _game(store)
	assert_null(game.test_mode, "normal play")
	assert_eq(game.level.level_version, VERSION, "the test level is at version 2")
	_check_migrated(game, "normal play")
	var copy := DIR + "test.json" + SaveStore.VERSION_SUFFIX + str(OLD_VERSION)
	assert_eq(FileAccess.get_file_as_bytes(copy), original, "test.json.v1 kept byte for byte")
	assert_eq(game.save_now(), "", "the migrated save is written")
	var written := store.read(LEVEL)
	assert_eq(written["status"], SaveStore.OK)
	assert_eq(int(written["save"]["level"]["version"]), VERSION, "at version 2")
	assert_eq(SaveData.problems(written["save"], game.level.data), PackedStringArray())
	var again := _game(SaveStore.new(DIR))
	assert_eq(again.simulation.tick, game.simulation.tick, "the next save loads")
	assert_eq(again.simulation.slimes.slime_count, POPULATION)
	assert_eq(again.simulation.state_hash(), game.simulation.state_hash(), "as it was saved")
	assert_eq(FileAccess.get_file_as_bytes(copy), original, "the copy stays")


# @test-link [[rule_released_level_stable_with_migration]]
func test_old_version_boots_in_test_mode_migrated() -> void:
	var game := _boot({"fixture": "old-version"})
	_check_migrated(game, "test mode")


# --- A kill during a write (DoD 28) ------------------------------------------------

## Plays the scripted call run in test mode on a store on DIR, saving at
## SAVE_A_TICK (A) and SAVE_B_TICK (B), then playing on to PAST_B_TICK
## unsaved. Returns {"a", "b" (the saves' bytes), "c" (the bytes a save at
## PAST_B_TICK would write), "game"}. DIR then holds test.json (B) and
## test.json.bak (A).
func _played_twice() -> Dictionary:
	var store := SaveStore.new(DIR)
	var game := _game(store)
	var loaded := TestMode.load_config_file(SCRIPT_PATH)
	assert_eq(loaded["errors"], PackedStringArray())
	var config: Dictionary = loaded["config"]
	config["time_scale"] = 0
	assert_eq(game.enable_test_mode(config), PackedStringArray())
	game.test_mode.run_until(SAVE_A_TICK)
	assert_eq(game.save_now(), "")
	var a := FileAccess.get_file_as_bytes(store.path_for(LEVEL))
	game.test_mode.run_until(SAVE_B_TICK)
	assert_eq(game.save_now(), "")
	var b := FileAccess.get_file_as_bytes(store.path_for(LEVEL))
	assert_eq(FileAccess.get_file_as_bytes(store.path_for(LEVEL) + SaveStore.BACKUP_SUFFIX), a, "A backed up")
	game.test_mode.run_until(PAST_B_TICK)
	var c := SaveData.to_text(game.simulation.to_save()).to_utf8_buffer()
	return {"a": a, "b": b, "c": c, "game": game}


## Reopens a new game on DIR as the files are, and checks it resumed from
## the save in `expected` (its bytes) at `tick`: the same state as that
## save loaded on its own (Simulation.from_save; both loads land mid-air
## slimes), its slimes, objects and gates, no slime in mid-air, and the
## level not blocked.
func _assert_resumes_from(expected: PackedByteArray, tick: int, label: String) -> void:
	var game := _game(SaveStore.new(DIR))
	var sim: Simulation = game.simulation
	assert_null(game.test_mode, label + ": normal play")
	assert_eq(sim.tick, tick, label + ": resumed from the right save")
	var json := JSON.new()
	assert_eq(json.parse(expected.get_string_from_utf8()), OK)
	var reference := Simulation.from_save(json.data, game.level.data, sim.slimes.terrain, 1)
	# As the game does to the simulation it loads (main._use_simulation).
	reference.offscreen.enabled = true
	reference.hint.world_shown(reference.tick)
	reference.view = sim.view
	assert_eq(sim.slimes.slime_count, reference.slimes.slime_count, label + ": slimes")
	for slime_id in reference.slimes.ids():
		assert_eq(sim.identities.members_of(slime_id), reference.identities.members_of(slime_id), label)
		assert_eq(sim.slimes.state_of(slime_id), reference.slimes.state_of(slime_id), label)
		assert_eq(sim.slimes.centre_of(slime_id), reference.slimes.centre_of(slime_id), label)
	assert_eq(sim.object_states, reference.object_states, label + ": objects")
	assert_eq(sim.gate_states, reference.gate_states, label + ": gates")
	assert_eq(sim.state_hash(), reference.state_hash(), label + ": the same state")
	_assert_none_in_the_air(sim, label)
	assert_eq(game.save_now(), "", label + ": the level saves again (not blocked)")


## Deterministic simulation of a kill: the files are laid out as a kill at
## each point of SaveStore.write_file's sequence (side file, backup copy,
## renames) would leave them while writing C over B; the save file is never
## missing, so the game resumes from B every time.
func test_a_kill_during_a_write_resumes_from_the_last_whole_save() -> void:
	var saves := _played_twice()
	var path := DIR + "test.json"
	var bak := path + SaveStore.BACKUP_SUFFIX
	var layouts := {
		"killed writing the side file": {path: saves["b"], bak: saves["a"],
				path + SaveStore.SIDE_SUFFIX: _half(saves["c"])},
		"killed copying the backup": {path: saves["b"], bak: saves["a"], path + SaveStore.SIDE_SUFFIX: saves["c"],
				bak + SaveStore.SIDE_SUFFIX: _half(saves["b"])},
		"killed before the save's rename": {path: saves["b"], bak: saves["b"],
				path + SaveStore.SIDE_SUFFIX: saves["c"]},
	}
	for label in layouts:
		_clear(DIR)
		var files: Dictionary = layouts[label]
		for file in files:
			_put(file, files[file])
		_assert_resumes_from(saves["b"], SAVE_B_TICK, label)


## The storage damaged the save mid-write (truncated): the backup (A) is
## used, the damaged file set aside untouched, and the level saves again.
# @test-link [[rule_saves_never_wiped]]
func test_a_save_damaged_mid_write_resumes_from_the_backup() -> void:
	var saves := _played_twice()
	_clear(DIR)
	var path := DIR + "test.json"
	_put(path, _half(saves["b"]))
	_put(path + SaveStore.BACKUP_SUFFIX, saves["a"])
	_assert_resumes_from(saves["a"], SAVE_A_TICK, "a truncated save")
	assert_eq(FileAccess.get_file_as_bytes(path + SaveStore.SET_ASIDE_SUFFIX), _half(saves["b"]),
			"the damaged save set aside, byte for byte")


func test_a_game_killed_between_saves_resumes_at_the_last_save() -> void:
	var saves := _played_twice()
	assert_eq(saves["game"].simulation.tick, PAST_B_TICK, "played on past B")
	_assert_resumes_from(saves["b"], SAVE_B_TICK, "killed between saves")
