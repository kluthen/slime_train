class_name SaveStore
extends RefCounted
## The save files: one per level, <directory>/<level id>.json, the directory
## being user://saves/ unless a test gives another. The text is SaveData's
## format (SaveData.to_text).
##
## A missing file means a fresh start (status FRESH). The store never
## deletes a save and never replaces one with nothing (rule_saves_never_wiped):
## - a save with no slimes, or one that doesn't read back as JSON (a NaN,
##   say), is refused and the old file stays as it was;
## - a file that can't be read (not JSON, not a save) is left untouched, and
##   the store writes nothing over it for the rest of the session (block());
##   the game starts that level fresh and says why;
## - a write goes to a side file (SIDE_SUFFIX) first, is read back, and only
##   then takes the old file's place: a write that fails leaves the old file.
## No migration here: a save of another level version is blocked the same
## way (by the game, block()) and kept for chunk 19, which adds migration and
## a backup copy.
# @spec-link [[req_persistence_and_saves]]
# @spec-link [[rule_saves_never_wiped]]

## No save file: start fresh.
const FRESH := "fresh"
## A save was read.
const OK := "ok"
## A file is there but isn't a readable save: left untouched.
const UNREADABLE := "unreadable"
## The side file a write goes to before it replaces the save.
const SIDE_SUFFIX := ".new"
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
## data, {} unless OK), "error"}. An unreadable file blocks the level.
func read(level_id: String) -> Dictionary:
	var result := read_file(path_for(level_id))
	if result["status"] == UNREADABLE:
		block(level_id, result["error"])
	return result


## Whether write() may write level `level_id`'s save.
func can_write(level_id: String) -> bool:
	return not _blocked.has(level_id)


## Keeps level `level_id`'s file as it is for the rest of the session, for
## `reason`: every write() to it is refused.
func block(level_id: String, reason: String) -> void:
	_blocked[level_id] = reason


## Writes `save` as its level's file. Returns "" on success, else why nothing
## was written (the old file, if any, is as it was).
func write(save: Dictionary) -> String:
	var header: Variant = save.get("level")
	if typeof(header) != TYPE_DICTIONARY or str(header.get("id", "")) == "":
		return "SaveStore: the save names no level"
	var level_id := str(header["id"])
	if not can_write(level_id):
		return "SaveStore: not writing over %s: %s" % [path_for(level_id), _blocked[level_id]]
	return write_file(path_for(level_id), save)


## The save in the file at `path` (see read()), without blocking anything.
static func read_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"status": FRESH, "save": {}, "error": ""}
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
	return {"status": OK, "save": json.data, "error": ""}


## Writes `save` to the file at `path` through a side file (see above),
## making its directory if needed. Returns "" or why nothing was written.
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
	if DirAccess.dir_exists_absolute(side):
		return "SaveStore: %s is a directory; the old save is kept" % side
	var file := FileAccess.open(side, FileAccess.WRITE)
	if file == null:
		return "SaveStore: can't write %s (%s); the old save is kept" % [
				side, error_string(FileAccess.get_open_error())]
	file.store_string(text)
	var failed := file.get_error()
	file.close()
	if failed != Error.OK or FileAccess.get_file_as_string(side) != text:
		return "SaveStore: writing %s failed; the old save is kept" % side
	var swapped := DirAccess.rename_absolute(side, path)
	if swapped != Error.OK:
		return "SaveStore: can't move %s into place (%s); the old save is kept" % [side, error_string(swapped)]
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


static func _unreadable(path: String, why: String) -> Dictionary:
	return {"status": UNREADABLE, "save": {}, "error": "%s is unreadable: %s. It is left as it is." % [path, why]}
