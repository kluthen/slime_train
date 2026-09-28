extends GutTest
## The save files (src/save/save_store.gd): one file per level,
## <directory>/<level id>.json. A missing file means a fresh start. The store
## never deletes a save and never replaces one with nothing:
## - an empty save (no slimes) or one that can't be written as JSON is
##   refused, and the old file stays as it was;
## - a file that can't be read is left untouched, and no save is written
##   over it for the rest of the session;
## - a write that fails keeps the old file (the new text goes to a side file
##   first and only then takes the old file's place);
## - no code under src/ can delete a file (the lint below).

# @test-link [[req_persistence_and_saves]]
# @test-link [[rule_saves_never_wiped]]

const DIR := "user://test-save-store/"
const LEVEL := "test"


func before_each() -> void:
	_clear(DIR)


func after_all() -> void:
	_clear(DIR)


## Tests may delete their own scratch files; the game's code may not.
func _clear(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for sub in DirAccess.get_directories_at(path):
		_clear(path.path_join(sub))
	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)


func _save(tick := 10) -> Dictionary:
	return {"format": SaveData.FORMAT, "level": {"id": LEVEL, "version": 1},
			"sim": {"tick": tick}, "slimes": [{"species": "A", "size": 1, "state": "train",
			"centre": [10, 20]}], "objects": {}, "gates": {}}


func _bytes(path: String) -> PackedByteArray:
	return FileAccess.get_file_as_bytes(path)


func test_one_file_per_level_in_the_directory() -> void:
	var store := SaveStore.new(DIR)
	assert_eq(store.path_for("test"), DIR + "test.json")
	assert_eq(SaveStore.new().path_for("meadow"), "user://saves/meadow.json", "the default directory")


func test_a_missing_file_means_fresh() -> void:
	var store := SaveStore.new(DIR)
	var result := store.read(LEVEL)
	assert_eq(result["status"], SaveStore.FRESH)
	assert_eq(result["save"], {})
	assert_true(store.can_write(LEVEL), "a fresh level can be saved")


func test_a_written_save_reads_back() -> void:
	var store := SaveStore.new(DIR)
	assert_eq(store.write(_save()), "")
	var result := store.read(LEVEL)
	assert_eq(result["status"], SaveStore.OK)
	assert_eq(int(result["save"]["sim"]["tick"]), 10)
	assert_eq(store.write(_save(20)), "", "a newer save takes its place")
	assert_eq(int(store.read(LEVEL)["save"]["sim"]["tick"]), 20)
	assert_false(FileAccess.file_exists(store.path_for(LEVEL) + SaveStore.SIDE_SUFFIX), "no side file left")


func test_an_empty_save_is_refused_and_the_old_file_kept() -> void:
	var store := SaveStore.new(DIR)
	store.write(_save())
	var before := _bytes(store.path_for(LEVEL))
	var empty := _save()
	empty["slimes"] = []
	assert_ne(store.write(empty), "", "no slimes: refused")
	assert_ne(store.write({}), "", "nothing: refused")
	assert_eq(_bytes(store.path_for(LEVEL)), before)


func test_a_save_that_cant_be_written_as_json_is_refused_and_the_old_file_kept() -> void:
	var store := SaveStore.new(DIR)
	store.write(_save())
	var before := _bytes(store.path_for(LEVEL))
	var broken := _save()
	broken["slimes"][0]["centre"] = [NAN, 20]
	assert_ne(store.write(broken), "")
	assert_eq(_bytes(store.path_for(LEVEL)), before)


func test_an_unreadable_file_is_left_untouched_and_never_written_over() -> void:
	var store := SaveStore.new(DIR)
	DirAccess.make_dir_recursive_absolute(DIR)
	var corrupt := "{\"format\": 1, \"slimes\": [ this is not json"
	var file := FileAccess.open(store.path_for(LEVEL), FileAccess.WRITE)
	file.store_string(corrupt)
	file.close()
	var result := store.read(LEVEL)
	assert_eq(result["status"], SaveStore.UNREADABLE)
	assert_ne(result["error"], "")
	assert_false(store.can_write(LEVEL))
	assert_ne(store.write(_save()), "", "writing over it is refused")
	assert_eq(FileAccess.get_file_as_string(store.path_for(LEVEL)), corrupt, "the file is as it was")
	assert_true(store.can_write("other"), "other levels still save")


func test_a_file_that_isnt_a_save_counts_as_unreadable() -> void:
	var store := SaveStore.new(DIR)
	DirAccess.make_dir_recursive_absolute(DIR)
	var file := FileAccess.open(store.path_for(LEVEL), FileAccess.WRITE)
	file.store_string("[1, 2, 3]")
	file.close()
	assert_eq(store.read(LEVEL)["status"], SaveStore.UNREADABLE)
	assert_eq(FileAccess.get_file_as_string(store.path_for(LEVEL)), "[1, 2, 3]")


func test_a_level_can_be_blocked_from_saving() -> void:
	var store := SaveStore.new(DIR)
	store.write(_save())
	var before := _bytes(store.path_for(LEVEL))
	store.block(LEVEL, "saved by another level version")
	assert_false(store.can_write(LEVEL))
	assert_string_contains(store.write(_save(99)), "another level version")
	assert_eq(_bytes(store.path_for(LEVEL)), before)


func test_a_failed_write_keeps_the_old_file() -> void:
	var store := SaveStore.new(DIR)
	store.write(_save())
	var before := _bytes(store.path_for(LEVEL))
	# The side file's place is taken by a directory: the new text can't be
	# written, so the old save must stay.
	DirAccess.make_dir_recursive_absolute(store.path_for(LEVEL) + SaveStore.SIDE_SUFFIX)
	assert_ne(store.write(_save(20)), "")
	assert_eq(_bytes(store.path_for(LEVEL)), before)


func test_static_file_access_for_explicit_paths() -> void:
	var path := DIR + "sub/explicit.json"
	assert_eq(SaveStore.read_file(path)["status"], SaveStore.FRESH)
	assert_eq(SaveStore.write_file(path, _save(7)), "")
	var result := SaveStore.read_file(path)
	assert_eq(result["status"], SaveStore.OK)
	assert_eq(int(result["save"]["sim"]["tick"]), 7)


# --- Lint -----------------------------------------------------------------------

## rule_saves_never_wiped: the game's code has no way to delete a file.
## Deleting a save (settings, a second confirmation) comes with chunk 18 and
## will get its own reviewed exception here.
func test_no_game_code_can_delete_a_file() -> void:
	var offenders := PackedStringArray()
	var pattern := RegEx.create_from_string("remove_absolute|move_to_trash|\\.remove\\(|\\brename(_absolute)?\\(")
	for path in _scripts("res://src/"):
		var lines := FileAccess.get_file_as_string(path).split("\n")
		for n in lines.size():
			var line := lines[n].strip_edges()
			if line.begins_with("#"):
				continue
			if pattern.search(line) != null and not _allowed(path, line):
				offenders.append("%s:%d: %s" % [path, n + 1, line])
	assert_eq(offenders, PackedStringArray())


## The one allowed rename: SaveStore swapping a fully written side file in.
func _allowed(path: String, line: String) -> bool:
	return path == "res://src/save/save_store.gd" and "rename_absolute(" in line


func _scripts(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	for sub in DirAccess.get_directories_at(dir):
		out.append_array(_scripts(dir.path_join(sub)))
	for file in DirAccess.get_files_at(dir):
		if file.ends_with(".gd"):
			out.append(dir.path_join(file))
	return out
