class_name SaveStore
extends RefCounted
## The save files: one per level, <directory>/<level id>.json, the directory
## being user://saves/ unless a test gives another. The text is SaveData's
## format (SaveData.to_text). Next to the save: its backup (BACKUP_SUFFIX,
## the previous save) and the side files of a write (SIDE_SUFFIX after
## either name).
##
## A missing save and backup mean a fresh start (status FRESH). The store
## never deletes a save, except on the parent's explicit delete (delete(),
## chunk 18, D43/D104), and never replaces one with nothing
## (rule_saves_never_wiped); no update, migration or load-failure path may
## call delete(). So:
## - a save with no slimes, or one that doesn't read back as JSON (a NaN,
##   say), is refused and the old file stays as it was;
## - a write goes: 1) the text to the save's side file, read back; 2) if the
##   old save reads as a save, its bytes to the backup's side file, read
##   back, renamed onto the backup; 3) the side file renamed onto the save.
##   A write that fails leaves the old save and backup; a kill at any point
##   leaves the save whole (old or new) and the backup whole (an older save).
##   An unreadable save is never copied onto the backup;
## - read(): the save if it reads, else the backup if it reads (source
##   "backup"); a file that can't be read (not JSON, not a save) is set
##   aside (renamed SET_ASIDE_SUFFIX, then .2, .3... the first free name)
##   with its bytes intact, so no write lands on it, and the level isn't
##   blocked; if nothing reads the level starts fresh. Only if a set-aside
##   fails is the level blocked (block(): no write for the session), the
##   file left where it is.
## No migration here (SaveMigration, on load): a save of a newer level
## version is blocked (by the game, block()) and kept; before an older one
## is migrated and written, the game keeps its file as it was
## (keep_version_copy(): <level id>.json.v<old version>, never removed).
# @spec-link [[req_persistence_and_saves]]
# @spec-link [[rule_saves_never_wiped]]

## No save file: start fresh.
const FRESH := "fresh"
## A save was read.
const OK := "ok"
## A file is there but isn't a readable save: left untouched.
const UNREADABLE := "unreadable"
## The side file a write goes to before it replaces the save (or the backup).
const SIDE_SUFFIX := ".new"
## The backup: the save before the last write.
const BACKUP_SUFFIX := ".bak"
## An unreadable file set aside by read(): this, then .2, .3... if taken.
const SET_ASIDE_SUFFIX := ".unreadable"
## The copy of a save from before its migration: this and the old level
## version, then .2, .3... if taken by another file.
const VERSION_SUFFIX := ".v"
## read()'s "source": the save itself, or the backup.
const SOURCE_SAVE := "save"
const SOURCE_BACKUP := "backup"
const DEFAULT_DIRECTORY := "user://saves/"

var directory := DEFAULT_DIRECTORY

## Level id -> why the store won't write that level's save.
var _blocked := {}


func _init(save_directory := DEFAULT_DIRECTORY) -> void:
	directory = save_directory if save_directory.ends_with("/") else save_directory + "/"


## The file of level `level_id`'s save.
func path_for(level_id: String) -> String:
	return directory + level_id + ".json"


## Level `level_id`'s save: {"status" (FRESH, OK or UNREADABLE), "save" (the
## data, {} unless OK), "error" (why the save wasn't used as is, "" if it
## was), "source" (SOURCE_SAVE, SOURCE_BACKUP, or "" when nothing was read),
## "set_aside" (the new paths of the files set aside)}. The save if it
## reads, else the backup if it reads; unreadable files are set aside (see
## above). FRESH with an error: nothing read, the files set aside.
## UNREADABLE: a file couldn't be set aside, and the level is blocked.
# @spec-link [[req_persistence_and_saves]]
# @spec-link [[rule_saves_never_wiped]]
func read(level_id: String) -> Dictionary:
	var path := path_for(level_id)
	var saved := read_file(path)
	if saved["status"] == OK:
		return _result(saved, SOURCE_SAVE, "", [])
	var backup := read_file(path + BACKUP_SUFFIX)
	var set_aside := []
	var notes := PackedStringArray()
	for damaged in [saved, backup]:
		if damaged["status"] != UNREADABLE:
			continue
		var moved := _set_aside(damaged["path"])
		if moved["error"] != "":
			var why := "%s %s; it is left as it is and not written over this session." % [
					damaged["error"], moved["error"]]
			block(level_id, why)
			var used := backup if backup["status"] == OK else {"status": UNREADABLE, "save": {}}
			return _result(used, SOURCE_BACKUP if backup["status"] == OK else "", why, set_aside)
		set_aside.append(moved["path"])
		notes.append("%s It was set aside as %s." % [damaged["error"], moved["path"]])
	if backup["status"] == OK:
		if saved["status"] == FRESH:
			notes.append("%s is missing." % path)
		notes.append("The backup %s was used." % backup["path"])
		return _result(backup, SOURCE_BACKUP, " ".join(notes), set_aside)
	return _result({"status": FRESH, "save": {}}, "", " ".join(notes), set_aside)


## Whether write() may write level `level_id`'s save.
func can_write(level_id: String) -> bool:
	return not _blocked.has(level_id)


## Keeps level `level_id`'s file as it is for the rest of the session, for
## `reason`: every write() to it is refused.
func block(level_id: String, reason: String) -> void:
	_blocked[level_id] = reason


## The parent's delete of level `level_id`'s save (settings, D43, DoD 29 "its
## backup goes too"): removes its side file, its backup's side file, its
## backup and its file, in that order (a delete that stops half-way never
## leaves a backup that would come back as the save). Set-aside files stay
## (proposed: they aren't the save). Only the game root's
## delete_level_save() calls it (rule_saves_never_wiped). A save that isn't
## there is no error. Once the files are gone the level is no longer blocked
## (proposed): the block only kept an other-version file (or one that
## couldn't be set aside) from being written over, and the parent chose to
## drop it, so the fresh level saves again. Returns "" or why a file stays
## (the block then stays too).
# @spec-link [[req_persistence_and_saves]]
# @spec-link [[rule_saves_never_wiped]]
func delete(level_id: String) -> String:
	var path := path_for(level_id)
	var backup := path + BACKUP_SUFFIX
	for file in [path + SIDE_SUFFIX, backup + SIDE_SUFFIX, backup, path]:
		if not FileAccess.file_exists(file) and not DirAccess.dir_exists_absolute(file):
			continue
		var removed := DirAccess.remove_absolute(file)
		if removed != Error.OK:
			return "SaveStore: can't delete %s (%s)" % [file, error_string(removed)]
	_blocked.erase(level_id)
	return ""


## Keeps a copy of level `level_id`'s file as read (the save, or the backup
## for `source` SOURCE_BACKUP), saved by version `version` of the level,
## before its migrated save is first written (chunk 19, decision C): its
## bytes go to <save>.json.v<version> through a side file, read back, then
## renamed into place. An existing copy is never written over: one with the
## same bytes is the copy already (a migration stopped before its first
## write), else the next free name (.2, .3...) is taken. Returns {"path"
## (the copy's), "error" ("" or why there is no copy: the level is then
## blocked, so the old file is never written over)}.
# @spec-link [[req_persistence_and_saves]]
# @spec-link [[rule_saves_never_wiped]]
func keep_version_copy(level_id: String, version: int, source: String) -> Dictionary:
	assert(source in [SOURCE_SAVE, SOURCE_BACKUP], "SaveStore.keep_version_copy: source '%s'" % source)
	var from := path_for(level_id) + (BACKUP_SUFFIX if source == SOURCE_BACKUP else "")
	var copied := _copy_once(from, "%s%s%d" % [path_for(level_id), VERSION_SUFFIX, version])
	if copied["error"] != "":
		var why := "no copy of %s from before its migration (%s); it won't be written over this session." % [
				from, copied["error"]]
		block(level_id, why)
		return {"path": "", "error": why}
	return copied


## Copies the file at `from` to `target`, or to the first free name among
## target.2, target.3... if another file holds `target`; a file there with
## the same bytes is the copy already. Through a side file, read back, then
## renamed. Returns {"path" (the copy's), "error" ("" or why there is none)}.
# @spec-link [[rule_saves_never_wiped]]
static func _copy_once(from: String, target: String) -> Dictionary:
	if not FileAccess.file_exists(from):
		return {"path": "", "error": "%s is missing" % from}
	var bytes := FileAccess.get_file_as_bytes(from)
	var name := target
	var n := 1
	while FileAccess.file_exists(name) or DirAccess.dir_exists_absolute(name):
		if FileAccess.file_exists(name) and FileAccess.get_file_as_bytes(name) == bytes:
			return {"path": name, "error": ""}
		n += 1
		name = "%s.%d" % [target, n]
	var side := name + SIDE_SUFFIX
	var written := _write_side(side, bytes)
	if written != "":
		return {"path": "", "error": written}
	var moved := DirAccess.rename_absolute(side, name)
	if moved != Error.OK:
		return {"path": "", "error": "can't move %s into place (%s)" % [side, error_string(moved)]}
	return {"path": name, "error": ""}


## Writes `save` as its level's file. Returns "" on success, else why nothing
## was written (the old file, if any, is as it was).
# @spec-link [[req_persistence_and_saves]]
func write(save: Dictionary) -> String:
	var header: Variant = save.get("level")
	if typeof(header) != TYPE_DICTIONARY or str(header.get("id", "")) == "":
		return "SaveStore: the save names no level"
	var level_id := str(header["id"])
	if not can_write(level_id):
		return "SaveStore: not writing over %s: %s" % [path_for(level_id), _blocked[level_id]]
	return write_file(path_for(level_id), save)


## read()'s result from a read_file() result `found` (its status and save),
## with `source`, the note `error` and the `set_aside` paths.
static func _result(found: Dictionary, source: String, error: String, set_aside: Array) -> Dictionary:
	return {"status": found["status"], "save": found["save"], "error": error,
			"source": source, "set_aside": set_aside}


## Moves the unreadable file at `path` out of the way, to the first free
## name among path + SET_ASIDE_SUFFIX, then .2, .3...: a rename, its bytes
## untouched (rule_saves_never_wiped). Returns {"path" (the new path),
## "error" ("" or why it stays where it is)}.
# @spec-link [[rule_saves_never_wiped]]
static func _set_aside(path: String) -> Dictionary:
	var target := path + SET_ASIDE_SUFFIX
	var n := 1
	while FileAccess.file_exists(target) or DirAccess.dir_exists_absolute(target):
		n += 1
		target = "%s%s.%d" % [path, SET_ASIDE_SUFFIX, n]
	var moved := DirAccess.rename_absolute(path, target)
	if moved != Error.OK:
		return {"path": "", "error": "It can't be set aside as %s (%s)" % [target, error_string(moved)]}
	return {"path": target, "error": ""}


## The save in the file at `path`, as it is (no backup, nothing set aside
## or blocked): {"status" (FRESH: no file, OK or UNREADABLE), "save" ({}
## unless OK), "error" ("" unless UNREADABLE), "path"}.
static func read_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"status": FRESH, "save": {}, "error": "", "path": path}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _unreadable(path, "can't open it (%s)" % error_string(FileAccess.get_open_error()))
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != Error.OK:
		return _unreadable(path, "not JSON (line %d: %s)" % [json.get_error_line(), json.get_error_message()])
	if typeof(json.data) != TYPE_DICTIONARY:
		return _unreadable(path, "not a save (expected a JSON object)")
	return {"status": OK, "save": json.data, "error": "", "path": path}


## Writes `save` to the file at `path` through a side file, the old save
## (if it reads) becoming the backup first (see above), making its directory
## if needed. Returns "" or why nothing was swapped in.
# @spec-link [[req_persistence_and_saves]]
static func write_file(path: String, save: Dictionary) -> String:
	var slimes: Variant = save.get("slimes")
	if typeof(slimes) != TYPE_ARRAY or slimes.is_empty():
		return "SaveStore: refusing to write a save with no slimes to %s" % path
	if not _all_finite(save):
		return "SaveStore: the save holds a NaN or an infinity, which JSON can't carry; %s not written" % path
	var text := SaveData.to_text(save)
	var check := JSON.new()
	if check.parse(text) != Error.OK or typeof(check.data) != TYPE_DICTIONARY:
		return "SaveStore: the save doesn't read back as JSON (%s); %s not written" % [
				check.get_error_message(), path]
	var made := DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if made != Error.OK and made != ERR_ALREADY_EXISTS:
		return "SaveStore: can't make %s (%s)" % [path.get_base_dir(), error_string(made)]
	var side := path + SIDE_SUFFIX
	var written := _write_side(side, text.to_utf8_buffer())
	if written != "":
		return written
	var backed := _back_up(path)
	if backed != "":
		return backed
	var swapped := DirAccess.rename_absolute(side, path)
	if swapped != Error.OK:
		return "SaveStore: can't move %s into place (%s); the old save is kept" % [side, error_string(swapped)]
	return ""


## Step 2 of a write: if the save at `path` reads as a save, copies its bytes
## to the backup's side file, reads them back and renames it onto the backup.
## An unreadable (or missing) save is never copied: the backup stays. Returns
## "" or why the backup couldn't be made (the write then stops there).
# @spec-link [[req_persistence_and_saves]]
# @spec-link [[rule_saves_never_wiped]]
static func _back_up(path: String) -> String:
	if read_file(path)["status"] != OK:
		return ""
	var backup := path + BACKUP_SUFFIX
	var side := backup + SIDE_SUFFIX
	var written := _write_side(side, FileAccess.get_file_as_bytes(path))
	if written != "":
		return "SaveStore: no backup of %s: %s" % [path, written]
	var swapped := DirAccess.rename_absolute(side, backup)
	if swapped != Error.OK:
		return "SaveStore: can't move %s into place (%s); the old save and backup are kept" % [
				side, error_string(swapped)]
	return ""


## Writes `bytes` to the side file at `side` and reads them back. Returns ""
## or why they aren't there whole (nothing else is touched).
static func _write_side(side: String, bytes: PackedByteArray) -> String:
	if DirAccess.dir_exists_absolute(side):
		return "SaveStore: %s is a directory; the old save is kept" % side
	var file := FileAccess.open(side, FileAccess.WRITE)
	if file == null:
		return "SaveStore: can't write %s (%s); the old save is kept" % [
				side, error_string(FileAccess.get_open_error())]
	file.store_buffer(bytes)
	var failed := file.get_error()
	file.close()
	if failed != Error.OK or FileAccess.get_file_as_bytes(side) != bytes:
		return "SaveStore: writing %s failed; the old save is kept" % side
	return ""


## Whether every number in `value` (dictionaries and arrays walked) is finite.
static func _all_finite(value: Variant) -> bool:
	match typeof(value):
		TYPE_FLOAT:
			return is_finite(value)
		TYPE_DICTIONARY:
			for key in value:
				if not _all_finite(value[key]):
					return false
		TYPE_ARRAY:
			for item in value:
				if not _all_finite(item):
					return false
	return true


## read_file()'s result for the unreadable file at `path`, for `why`.
static func _unreadable(path: String, why: String) -> Dictionary:
	return {"status": UNREADABLE, "save": {}, "error": "%s is unreadable: %s." % [path, why], "path": path}
