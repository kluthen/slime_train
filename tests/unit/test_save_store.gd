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
## - the parent's explicit delete (SaveStore.delete, chunk 18, D43/D104) is
##   the one way a save goes: it removes the level's file and its side file,
##   other levels' saves and other files stay, and the level can be saved
##   fresh after it (proposed: even if it was blocked);
## - no other code under src/ can delete a file, and only the game root's
##   delete_level_save() calls the store's delete (the lints below).

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


# --- The parent's delete (chunk 18) --------------------------------------------

func test_delete_removes_the_level_save_and_its_side_file_only() -> void:
	var store := SaveStore.new(DIR)
	assert_eq(store.write(_save()), "")
	var other := _save()
	other["level"]["id"] = "other"
	assert_eq(store.write(other), "")
	var side := store.path_for(LEVEL) + SaveStore.SIDE_SUFFIX
	var leftover := FileAccess.open(side, FileAccess.WRITE)
	leftover.store_string("half a write")
	leftover.close()
	var bystander := FileAccess.open(DIR + "parent.json", FileAccess.WRITE)
	bystander.store_string("{}")
	bystander.close()
	assert_eq(store.delete(LEVEL), "")
	assert_false(FileAccess.file_exists(store.path_for(LEVEL)), "the save is gone")
	assert_false(FileAccess.file_exists(side), "its side file too")
	assert_eq(store.read(LEVEL)["status"], SaveStore.FRESH, "the level starts fresh")
	assert_eq(store.read("other")["status"], SaveStore.OK, "another level's save stays")
	assert_true(FileAccess.file_exists(DIR + "parent.json"), "other files stay")


func test_deleting_a_missing_save_is_not_an_error() -> void:
	var store := SaveStore.new(DIR)
	assert_eq(store.delete(LEVEL), "", "no directory yet")
	DirAccess.make_dir_recursive_absolute(DIR)
	assert_eq(store.delete(LEVEL), "", "no file")


func test_after_a_delete_the_fresh_save_can_be_written() -> void:
	var store := SaveStore.new(DIR)
	assert_eq(store.write(_save()), "")
	assert_eq(store.delete(LEVEL), "")
	assert_eq(store.write(_save(3)), "")
	assert_eq(int(store.read(LEVEL)["save"]["sim"]["tick"]), 3)


func test_deleting_a_blocked_save_unblocks_the_level() -> void:
	# (proposed) The block keeps an unreadable or other-version file from
	# being written over. Once the parent deleted that file, there is nothing
	# left to protect: the fresh level saves again.
	var store := SaveStore.new(DIR)
	DirAccess.make_dir_recursive_absolute(DIR)
	var file := FileAccess.open(store.path_for(LEVEL), FileAccess.WRITE)
	file.store_string("not json")
	file.close()
	assert_eq(store.read(LEVEL)["status"], SaveStore.UNREADABLE)
	assert_false(store.can_write(LEVEL))
	assert_eq(store.delete(LEVEL), "")
	assert_true(store.can_write(LEVEL))
	assert_eq(store.write(_save()), "")
	assert_eq(store.read(LEVEL)["status"], SaveStore.OK)


func test_a_delete_that_fails_says_why_and_keeps_the_block() -> void:
	var store := SaveStore.new(DIR)
	# The save's place is taken by a directory with something in it: it
	# can't be removed.
	DirAccess.make_dir_recursive_absolute(store.path_for(LEVEL).path_join("inside"))
	store.block(LEVEL, "unreadable")
	assert_ne(store.delete(LEVEL), "")
	assert_true(DirAccess.dir_exists_absolute(store.path_for(LEVEL)), "left as it was")
	assert_false(store.can_write(LEVEL), "still blocked")


# --- Lint -----------------------------------------------------------------------

## rule_saves_never_wiped: the game's code has no way to delete a file, but
## for the parent's explicit delete (SaveStore.delete, the one reviewed
## exception, chunk 18).
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


## The allowed file moves: SaveStore swapping a fully written side file in,
## removing a level's files in SaveStore.delete (the parent's delete), and
## ParentStore swapping its fully written side file in (the app-wide parent
## code file, never a level save).
func _allowed(path: String, line: String) -> bool:
	if path == "res://src/save/parent_store.gd":
		return "rename_absolute(" in line
	return path == "res://src/save/save_store.gd" and ("rename_absolute(" in line or "remove_absolute(" in line)


## rule_saves_never_wiped: no update, migration or load-failure path deletes
## a save. The only caller of the store's delete is the game root's
## delete_level_save(), the parent's action.
func test_only_the_parents_delete_calls_the_store_delete() -> void:
	var callers := PackedStringArray()
	var call := RegEx.create_from_string("\\bdelete\\(")
	for path in _scripts("res://src/"):
		var lines := FileAccess.get_file_as_string(path).split("\n")
		var function := ""
		for n in lines.size():
			var line := lines[n].strip_edges()
			if line.begins_with("func "):
				function = line
			if not line.begins_with("#") and call.search(line) != null and not line.begins_with("func delete("):
				callers.append("%s: %s" % [path, function])
	assert_eq(callers, PackedStringArray(["res://src/main.gd: func delete_level_save() -> String:"]))


func _scripts(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	for sub in DirAccess.get_directories_at(dir):
		out.append_array(_scripts(dir.path_join(sub)))
	for file in DirAccess.get_files_at(dir):
		if file.ends_with(".gd"):
			out.append(dir.path_join(file))
	return out
