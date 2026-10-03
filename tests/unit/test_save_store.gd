extends GutTest
## The save files (src/save/save_store.gd): one file per level,
## <directory>/<level id>.json, plus its backup (.json.bak, the previous
## save) and the side files of a write (.json.new, .json.bak.new). A missing
## file means a fresh start. The store never deletes a save and never
## replaces one with nothing:
## - an empty save (no slimes) or one that can't be written as JSON is
##   refused, and the old file stays as it was;
## - a write that fails keeps the old file (the new text goes to a side file
##   first and only then takes the old file's place); before that swap the
##   old save, if it reads, becomes the backup (through its own side file);
## - a kill at any point of a write leaves the save and the backup whole
##   (the kill cases are laid out on disk as a kill would leave them);
## - a save that can't be read is never written over: the backup is used if
##   it reads, and the unreadable file is set aside (renamed .unreadable,
##   .unreadable.2, ...) with its bytes intact; if nothing reads, the level
##   starts fresh; only when a set-aside fails is the level blocked (no write
##   for the rest of the session);
## - the parent's explicit delete (SaveStore.delete, chunk 18, D43/D104) is
##   the one way a save goes: it removes the level's file, its backup and
##   their side files; set-aside files, other levels' saves and other files
##   stay, and the level can be saved fresh after it (proposed: even if it
##   was blocked);
## - no other code under src/ can delete a file (but the debug-only save
##   wipe, chunk 19w), and only the game root's delete_level_save() calls the
##   store's delete (the lints below);
## - before the app has shipped (D149), a save the level refuses is set aside
##   with its backup (set_aside_save: renames, bytes untouched), so the fresh
##   level saves again; a set-aside that fails blocks the level.

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


## Lays `text` down as the file at `path` (the scratch directory made).
func _put(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


## The text of a save at `tick`, as SaveStore writes it.
func _text(tick := 10) -> String:
	return SaveData.to_text(_save(tick))


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


# @test-link [[rule_saves_never_wiped]]
func test_an_unreadable_file_without_a_backup_is_set_aside_and_the_level_starts_fresh() -> void:
	# Decision A (proposed): set aside rather than block, so the fresh level
	# saves again; the unreadable bytes are kept, never written over.
	var store := SaveStore.new(DIR)
	var corrupt := "{\"format\": 1, \"slimes\": [ this is not json"
	_put(store.path_for(LEVEL), corrupt)
	var result := store.read(LEVEL)
	assert_eq(result["status"], SaveStore.FRESH)
	assert_eq(result["save"], {})
	assert_eq(result["source"], "")
	assert_string_contains(result["error"], "unreadable")
	var aside := store.path_for(LEVEL) + SaveStore.SET_ASIDE_SUFFIX
	assert_eq(result["set_aside"], [aside])
	assert_eq(FileAccess.get_file_as_string(aside), corrupt, "its bytes are kept")
	assert_true(store.can_write(LEVEL), "not blocked")
	assert_eq(store.write(_save()), "", "the fresh level saves")
	assert_eq(store.read(LEVEL)["status"], SaveStore.OK)
	assert_eq(FileAccess.get_file_as_string(aside), corrupt, "the set-aside file is untouched")
	assert_true(store.can_write("other"), "other levels still save")


# @test-link [[rule_saves_never_wiped]]
func test_a_file_that_isnt_a_save_counts_as_unreadable() -> void:
	var store := SaveStore.new(DIR)
	_put(store.path_for(LEVEL), "[1, 2, 3]")
	assert_eq(SaveStore.read_file(store.path_for(LEVEL))["status"], SaveStore.UNREADABLE)
	assert_eq(FileAccess.get_file_as_string(store.path_for(LEVEL)), "[1, 2, 3]", "reading it touches nothing")
	assert_eq(store.read(LEVEL)["status"], SaveStore.FRESH, "set aside: the level starts fresh")
	assert_eq(FileAccess.get_file_as_string(store.path_for(LEVEL) + SaveStore.SET_ASIDE_SUFFIX), "[1, 2, 3]")


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


# --- The backup and the kill during a write (chunk 19) ---------------------------

# @test-link [[req_persistence_and_saves]]
func test_a_write_keeps_the_previous_save_as_the_backup() -> void:
	var store := SaveStore.new(DIR)
	var path := store.path_for(LEVEL)
	var backup := path + SaveStore.BACKUP_SUFFIX
	assert_eq(store.write(_save(10)), "")
	assert_false(FileAccess.file_exists(backup), "the first save has nothing to back up")
	var first := FileAccess.get_file_as_string(path)
	assert_eq(store.write(_save(20)), "")
	assert_eq(FileAccess.get_file_as_string(backup), first, "the backup holds the first save")
	assert_eq(int(store.read(LEVEL)["save"]["sim"]["tick"]), 20, "the save is the newer one")
	assert_eq(store.read(LEVEL)["source"], "save")
	assert_false(FileAccess.file_exists(path + SaveStore.SIDE_SUFFIX), "no side file left")
	assert_false(FileAccess.file_exists(backup + SaveStore.SIDE_SUFFIX), "no backup side file left")


# @test-link [[req_persistence_and_saves]]
func test_a_kill_leaving_a_half_written_side_file_loses_nothing() -> void:
	# A kill during step 1 of a write, laid out as it would leave the files:
	# the good save in place and a truncated side file next to it.
	var store := SaveStore.new(DIR)
	var path := store.path_for(LEVEL)
	_put(path, _text(10))
	_put(path + SaveStore.SIDE_SUFFIX, _text(20).left(15))
	var result := store.read(LEVEL)
	assert_eq(result["status"], SaveStore.OK)
	assert_eq(int(result["save"]["sim"]["tick"]), 10, "the good save")
	assert_eq(result["set_aside"], [])
	assert_eq(store.write(_save(30)), "", "the next write goes through")
	assert_eq(int(store.read(LEVEL)["save"]["sim"]["tick"]), 30)
	assert_eq(FileAccess.get_file_as_string(path + SaveStore.BACKUP_SUFFIX), _text(10))


# @test-link [[req_persistence_and_saves]]
func test_a_kill_leaving_a_half_written_backup_side_file_loses_nothing() -> void:
	# A kill during step 2 of a write, laid out as it would leave the files:
	# the save and the older backup whole, the backup's side file truncated.
	var store := SaveStore.new(DIR)
	var path := store.path_for(LEVEL)
	var backup := path + SaveStore.BACKUP_SUFFIX
	_put(path, _text(20))
	_put(backup, _text(10))
	_put(backup + SaveStore.SIDE_SUFFIX, _text(20).left(15))
	var result := store.read(LEVEL)
	assert_eq(result["status"], SaveStore.OK)
	assert_eq(int(result["save"]["sim"]["tick"]), 20)
	assert_eq(store.write(_save(30)), "", "the next write goes through")
	assert_eq(int(store.read(LEVEL)["save"]["sim"]["tick"]), 30)
	assert_eq(FileAccess.get_file_as_string(backup), _text(20), "the backup is the save before")


# @test-link [[req_persistence_and_saves]]
# @test-link [[rule_saves_never_wiped]]
func test_a_damaged_save_with_a_good_backup_loads_the_backup_and_is_set_aside() -> void:
	# A damaged save (truncated, as a failing disk could leave it) next to a
	# good backup.
	var store := SaveStore.new(DIR)
	var path := store.path_for(LEVEL)
	var damaged := _text(20).left(25)
	_put(path, damaged)
	_put(path + SaveStore.BACKUP_SUFFIX, _text(10))
	var result := store.read(LEVEL)
	assert_eq(result["status"], SaveStore.OK)
	assert_eq(result["source"], "backup")
	assert_eq(int(result["save"]["sim"]["tick"]), 10, "the backup's save")
	assert_string_contains(result["error"], "backup")
	var aside := path + SaveStore.SET_ASIDE_SUFFIX
	assert_eq(result["set_aside"], [aside])
	assert_eq(FileAccess.get_file_as_string(aside), damaged, "the damaged bytes are kept")
	assert_false(FileAccess.file_exists(path), "moved out of the way")
	assert_true(store.can_write(LEVEL), "not blocked")
	assert_eq(store.write(_save(30)), "")
	assert_eq(int(store.read(LEVEL)["save"]["sim"]["tick"]), 30)
	assert_eq(FileAccess.get_file_as_string(aside), damaged, "the set-aside file is untouched")
	assert_eq(FileAccess.get_file_as_string(path + SaveStore.BACKUP_SUFFIX), _text(10), "the backup stays")


# @test-link [[req_persistence_and_saves]]
func test_a_missing_save_with_a_good_backup_loads_the_backup() -> void:
	var store := SaveStore.new(DIR)
	_put(store.path_for(LEVEL) + SaveStore.BACKUP_SUFFIX, _text(10))
	var result := store.read(LEVEL)
	assert_eq(result["status"], SaveStore.OK)
	assert_eq(result["source"], "backup")
	assert_eq(int(result["save"]["sim"]["tick"]), 10)
	assert_eq(result["set_aside"], [])
	assert_true(store.can_write(LEVEL))


# @test-link [[rule_saves_never_wiped]]
func test_when_neither_the_save_nor_the_backup_reads_both_are_set_aside() -> void:
	# Decision A (proposed): status FRESH, the set-aside paths listed and an
	# error saying why; nothing is blocked, deleted or written over.
	var store := SaveStore.new(DIR)
	var path := store.path_for(LEVEL)
	var backup := path + SaveStore.BACKUP_SUFFIX
	_put(path, "not json")
	_put(backup, "[1, 2]")
	var result := store.read(LEVEL)
	assert_eq(result["status"], SaveStore.FRESH)
	assert_eq(result["save"], {})
	assert_eq(result["source"], "")
	assert_ne(result["error"], "")
	var aside := path + SaveStore.SET_ASIDE_SUFFIX
	var backup_aside := backup + SaveStore.SET_ASIDE_SUFFIX
	assert_eq(result["set_aside"], [aside, backup_aside])
	assert_eq(FileAccess.get_file_as_string(aside), "not json")
	assert_eq(FileAccess.get_file_as_string(backup_aside), "[1, 2]")
	assert_true(store.can_write(LEVEL), "not blocked")
	assert_eq(store.write(_save()), "", "the fresh level saves")
	assert_eq(store.write(_save(20)), "")
	assert_eq(FileAccess.get_file_as_string(aside), "not json", "untouched")
	assert_eq(FileAccess.get_file_as_string(backup_aside), "[1, 2]", "untouched")


# @test-link [[rule_saves_never_wiped]]
func test_a_missing_save_with_an_unreadable_backup_starts_fresh_and_sets_it_aside() -> void:
	# (proposed) The unreadable backup is set aside too, so no later write's
	# backup copy lands on it.
	var store := SaveStore.new(DIR)
	var backup := store.path_for(LEVEL) + SaveStore.BACKUP_SUFFIX
	_put(backup, "not json")
	var result := store.read(LEVEL)
	assert_eq(result["status"], SaveStore.FRESH)
	assert_eq(result["set_aside"], [backup + SaveStore.SET_ASIDE_SUFFIX])
	assert_eq(FileAccess.get_file_as_string(backup + SaveStore.SET_ASIDE_SUFFIX), "not json")
	assert_true(store.can_write(LEVEL))


# @test-link [[rule_saves_never_wiped]]
func test_setting_aside_picks_the_next_free_name() -> void:
	var store := SaveStore.new(DIR)
	var path := store.path_for(LEVEL)
	var aside := path + SaveStore.SET_ASIDE_SUFFIX
	_put(aside, "first")
	_put(aside + ".2", "second")
	_put(path, "third")
	var result := store.read(LEVEL)
	assert_eq(result["set_aside"], [aside + ".3"])
	assert_eq(FileAccess.get_file_as_string(aside), "first", "earlier set-aside files stay")
	assert_eq(FileAccess.get_file_as_string(aside + ".2"), "second")
	assert_eq(FileAccess.get_file_as_string(aside + ".3"), "third")


# @test-link [[rule_saves_never_wiped]]
func test_a_set_aside_that_fails_blocks_the_level() -> void:
	# The directory is made read-only: the rename can't happen, so the store
	# falls back to blocking the level, and the file stays where it is.
	var store := SaveStore.new(DIR)
	var path := store.path_for(LEVEL)
	_put(path, "not json")
	var dir := ProjectSettings.globalize_path(DIR)
	var mode := FileAccess.get_unix_permissions(dir)
	FileAccess.set_unix_permissions(dir, FileAccess.UNIX_READ_OWNER | FileAccess.UNIX_EXECUTE_OWNER)
	var result := store.read(LEVEL)
	FileAccess.set_unix_permissions(dir, mode)
	assert_eq(result["status"], SaveStore.UNREADABLE)
	assert_eq(result["set_aside"], [])
	assert_false(store.can_write(LEVEL), "blocked")
	assert_ne(store.write(_save()), "", "writing over it is refused")
	assert_eq(FileAccess.get_file_as_string(path), "not json", "the file is as it was")


# @test-link [[rule_saves_never_wiped]]
func test_an_unreadable_save_is_never_copied_over_the_backup() -> void:
	var path := DIR + "explicit.json"
	var backup := path + SaveStore.BACKUP_SUFFIX
	_put(path, "not json")
	_put(backup, _text(10))
	assert_eq(SaveStore.write_file(path, _save(20)), "")
	assert_eq(FileAccess.get_file_as_string(backup), _text(10), "the good backup is kept")
	assert_eq(int(SaveStore.read_file(path)["save"]["sim"]["tick"]), 20)


# @test-link [[req_persistence_and_saves]]
func test_a_failed_backup_copy_keeps_the_old_save_and_backup() -> void:
	var store := SaveStore.new(DIR)
	var path := store.path_for(LEVEL)
	store.write(_save(10))
	store.write(_save(20))
	var before := _bytes(path)
	var backup_before := _bytes(path + SaveStore.BACKUP_SUFFIX)
	# The backup's side file's place is taken by a directory: the copy can't
	# be written, so nothing is swapped.
	DirAccess.make_dir_recursive_absolute(path + SaveStore.BACKUP_SUFFIX + SaveStore.SIDE_SUFFIX)
	assert_string_contains(store.write(_save(30)), "backup")
	assert_eq(_bytes(path), before, "the old save is kept")
	assert_eq(_bytes(path + SaveStore.BACKUP_SUFFIX), backup_before, "the old backup is kept")


# --- A save the build can't use, before shipping (D149) ---------------------------

# @test-link [[req_persistence_and_saves]]
# @test-link [[rule_saves_never_wiped]]
func test_setting_a_refused_save_aside_takes_its_backup_with_it() -> void:
	var store := SaveStore.new(DIR)
	var path := store.path_for(LEVEL)
	var backup := path + SaveStore.BACKUP_SUFFIX
	_put(path, _text(20))
	_put(backup, _text(10))
	var result := store.set_aside_save(LEVEL)
	var aside := path + SaveStore.SET_ASIDE_SUFFIX
	var backup_aside := backup + SaveStore.SET_ASIDE_SUFFIX
	assert_eq(result, {"set_aside": [aside, backup_aside], "error": ""})
	assert_eq(FileAccess.get_file_as_string(aside), _text(20), "a rename, its bytes untouched")
	assert_eq(FileAccess.get_file_as_string(backup_aside), _text(10))
	assert_false(FileAccess.file_exists(path))
	assert_false(FileAccess.file_exists(backup))
	assert_eq(store.read(LEVEL)["status"], SaveStore.FRESH, "the level starts fresh")
	assert_true(store.can_write(LEVEL), "not blocked")
	assert_eq(store.write(_save(30)), "", "the fresh level saves")
	assert_eq(FileAccess.get_file_as_string(aside), _text(20), "never written over")


# @test-link [[rule_saves_never_wiped]]
func test_setting_a_refused_save_aside_takes_the_next_free_name() -> void:
	var store := SaveStore.new(DIR)
	var path := store.path_for(LEVEL)
	_put(path, _text(20))
	_put(path + SaveStore.SET_ASIDE_SUFFIX, "set aside before")
	var result := store.set_aside_save(LEVEL)
	assert_eq(result, {"set_aside": [path + SaveStore.SET_ASIDE_SUFFIX + ".2"], "error": ""}, "no backup: the save only")
	assert_eq(FileAccess.get_file_as_string(path + SaveStore.SET_ASIDE_SUFFIX), "set aside before", "kept")
	assert_eq(FileAccess.get_file_as_string(path + SaveStore.SET_ASIDE_SUFFIX + ".2"), _text(20))


# @test-link [[rule_saves_never_wiped]]
func test_setting_a_refused_backup_aside_when_the_save_is_missing() -> void:
	var store := SaveStore.new(DIR)
	var backup := store.path_for(LEVEL) + SaveStore.BACKUP_SUFFIX
	_put(backup, _text(10))
	var result := store.set_aside_save(LEVEL)
	assert_eq(result, {"set_aside": [backup + SaveStore.SET_ASIDE_SUFFIX], "error": ""})
	assert_eq(store.read(LEVEL)["status"], SaveStore.FRESH)


# @test-link [[rule_saves_never_wiped]]
func test_a_refused_save_that_cant_be_set_aside_blocks_the_level() -> void:
	var store := SaveStore.new(DIR)
	var path := store.path_for(LEVEL)
	_put(path, _text(20))
	var dir := ProjectSettings.globalize_path(DIR)
	var mode := FileAccess.get_unix_permissions(dir)
	FileAccess.set_unix_permissions(dir, FileAccess.UNIX_READ_OWNER | FileAccess.UNIX_EXECUTE_OWNER)
	var result := store.set_aside_save(LEVEL)
	FileAccess.set_unix_permissions(dir, mode)
	assert_ne(result["error"], "")
	assert_eq(result["set_aside"], [])
	assert_false(store.can_write(LEVEL), "blocked")
	assert_ne(store.write(_save()), "", "writing over it is refused")
	assert_eq(FileAccess.get_file_as_string(path), _text(20), "the file is as it was")


# --- The pre-migration copy (chunk 19, decision C) --------------------------------

# @test-link [[req_persistence_and_saves]]
# @test-link [[rule_saves_never_wiped]]
func test_a_version_copy_keeps_the_pre_migration_file_byte_for_byte() -> void:
	var store := SaveStore.new(DIR)
	var path := store.path_for(LEVEL)
	assert_eq(store.write(_save(10)), "")
	var before := _bytes(path)
	var kept := store.keep_version_copy(LEVEL, 1, SaveStore.SOURCE_SAVE)
	assert_eq(kept, {"path": path + ".v1", "error": ""})
	assert_eq(_bytes(path + ".v1"), before, "the same bytes")
	assert_false(FileAccess.file_exists(path + ".v1" + SaveStore.SIDE_SUFFIX), "no side file left")
	assert_eq(store.write(_save(20)), "", "the migrated save is written after")
	assert_eq(_bytes(path + ".v1"), before, "the copy stays")
	assert_true(store.can_write(LEVEL))


# @test-link [[rule_saves_never_wiped]]
func test_a_version_copy_is_never_written_over() -> void:
	var store := SaveStore.new(DIR)
	var path := store.path_for(LEVEL)
	assert_eq(store.write(_save(10)), "")
	assert_eq(store.keep_version_copy(LEVEL, 1, SaveStore.SOURCE_SAVE)["error"], "")
	var first := _bytes(path + ".v1")
	# The same file again (a migration killed before its first write): the
	# copy is there already.
	assert_eq(store.keep_version_copy(LEVEL, 1, SaveStore.SOURCE_SAVE), {"path": path + ".v1", "error": ""})
	# Another file of that version: the next free name, the first copy kept.
	assert_eq(store.write(_save(30)), "")
	assert_eq(store.keep_version_copy(LEVEL, 1, SaveStore.SOURCE_SAVE), {"path": path + ".v1.2", "error": ""})
	assert_eq(_bytes(path + ".v1"), first, "never written over")
	assert_eq(_bytes(path + ".v1.2"), _bytes(path))


# @test-link [[req_persistence_and_saves]]
func test_a_version_copy_of_a_save_read_from_the_backup_copies_the_backup() -> void:
	var store := SaveStore.new(DIR)
	var path := store.path_for(LEVEL)
	_put(path + SaveStore.BACKUP_SUFFIX, _text(10))
	var kept := store.keep_version_copy(LEVEL, 1, SaveStore.SOURCE_BACKUP)
	assert_eq(kept, {"path": path + ".v1", "error": ""})
	assert_eq(FileAccess.get_file_as_string(path + ".v1"), _text(10))


# @test-link [[rule_saves_never_wiped]]
func test_a_version_copy_that_fails_blocks_the_level() -> void:
	var store := SaveStore.new(DIR)
	var path := store.path_for(LEVEL)
	assert_eq(store.write(_save(10)), "")
	var before := _bytes(path)
	# The copy's side file's place is taken by a directory: no copy.
	DirAccess.make_dir_recursive_absolute(path + ".v1" + SaveStore.SIDE_SUFFIX)
	var kept := store.keep_version_copy(LEVEL, 1, SaveStore.SOURCE_SAVE)
	assert_ne(kept["error"], "")
	assert_false(store.can_write(LEVEL), "blocked: the old save is never written over")
	assert_ne(store.write(_save(20)), "")
	assert_eq(_bytes(path), before, "the old save as it was")


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


# @test-link [[req_persistence_and_saves]]
# @test-link [[rule_saves_never_wiped]]
func test_delete_removes_the_backup_and_side_files_and_leaves_set_aside_files() -> void:
	# DoD 29: "its backup goes too". Set-aside files aren't the save
	# (proposed): they stay.
	var store := SaveStore.new(DIR)
	var path := store.path_for(LEVEL)
	var backup := path + SaveStore.BACKUP_SUFFIX
	assert_eq(store.write(_save(10)), "")
	assert_eq(store.write(_save(20)), "")
	_put(path + SaveStore.SIDE_SUFFIX, "half a write")
	_put(backup + SaveStore.SIDE_SUFFIX, "half a copy")
	_put(path + SaveStore.SET_ASIDE_SUFFIX, "set aside")
	_put(backup + SaveStore.SET_ASIDE_SUFFIX + ".2", "set aside too")
	assert_eq(store.delete(LEVEL), "")
	for gone in [path, path + SaveStore.SIDE_SUFFIX, backup, backup + SaveStore.SIDE_SUFFIX]:
		assert_false(FileAccess.file_exists(gone), "%s is gone" % gone)
	assert_eq(FileAccess.get_file_as_string(path + SaveStore.SET_ASIDE_SUFFIX), "set aside")
	assert_eq(FileAccess.get_file_as_string(backup + SaveStore.SET_ASIDE_SUFFIX + ".2"), "set aside too")
	assert_eq(store.read(LEVEL)["status"], SaveStore.FRESH, "the level starts fresh, not from the backup")


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
	# (proposed) The block keeps an other-version file (or one that couldn't
	# be set aside) from being written over. Once the parent deleted that
	# file, there is nothing left to protect: the fresh level saves again.
	var store := SaveStore.new(DIR)
	assert_eq(store.write(_save()), "")
	store.block(LEVEL, "saved by another level version")
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
## exception, chunk 18) and the debug-only save wipe (chunk 19w, see
## _allowed).
# @test-link [[rule_saves_never_wiped]]
func test_no_game_code_can_delete_a_file() -> void:
	var offenders := PackedStringArray()
	var pattern := RegEx.create_from_string("remove_absolute|move_to_trash|\\.remove\\(|\\brename(_absolute)?\\(")
	for path in _scripts("res://src/"):
		var lines := FileAccess.get_file_as_string(path).split("\n")
		var function := ""
		for n in lines.size():
			var line := lines[n].strip_edges()
			if line.begins_with("func ") or line.begins_with("static func "):
				function = line
			if line.begins_with("#"):
				continue
			if pattern.search(line) != null and not _allowed(path, function, line):
				offenders.append("%s:%d: %s" % [path, n + 1, line])
	assert_eq(offenders, PackedStringArray())


## The allowed file moves: SaveStore swapping a fully written side file in
## (the save's or the backup's) and setting an unreadable or refused file
## aside (all renames), removing a level's files only in SaveStore.delete (the
## parent's delete), and ParentStore swapping its fully written side files in
## (the app-wide parent code file, never a level save). One debug-only
## exception (chunk 19w, D148): the save wipe's one remove, in SaveWipe's
## wipe() (src/debug/save_wipe.gd), a development aid that a release build
## ignores and its preset leaves out (tests/unit/test_save_wipe.gd), outside
## rule_saves_never_wiped as its approved wording says.
func _allowed(path: String, function: String, line: String) -> bool:
	if path == "res://src/save/parent_store.gd":
		return "rename_absolute(" in line
	if path == "res://src/debug/save_wipe.gd":
		return "remove_absolute(" in line and function.begins_with("static func wipe(")
	if path != "res://src/save/save_store.gd":
		return false
	return "rename_absolute(" in line or ("remove_absolute(" in line and function.begins_with("func delete("))


## rule_saves_never_wiped: no update, migration or load-failure path deletes
## a save. The only caller of the store's delete is the game root's
## delete_level_save(), the parent's action.
# @test-link [[rule_saves_never_wiped]]
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
