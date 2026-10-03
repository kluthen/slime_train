class_name SaveWipe
extends RefCounted
## The save wipe (chunk 19w, D148, D149): with --wipe-save among the user
## arguments (after "--"; on Android in the launch intent's slime_args), a
## debug build deletes every file in the level saves' directory at launch
## (each level's save, its backup, side files, set-aside files and version
## copies), before anything reads a save, so the level saves start as on a
## fresh install. The parent code (user://parent.json and its backup, outside
## that directory) is kept. For automated test runs only (tools/android/perf.sh
## --wipe-save, a scripted desktop launch); by hand a level is started over
## with the parent's delete of its save. Never on by default, per launch only.
##
## Debug builds only: the game root (main.gd, wipe_saves()) names this file by
## path after TestModeGuard.allows(), and a release build ignores the flag
## there, so the release preset leaves this file out with src/debug/*. It is
## not SaveStore's: the store deletes only on the parent's delete
## (rule_saves_never_wiped, whose approved wording leaves out a development
## aid that exists only in debug builds).
##
## A launch that also names a save to start from (--load=PATH, or a test
## script with "load") is refused: nothing deleted, and the game root quits
## with exit code 1, so a save and restore run that carries the flag by
## mistake fails loudly. --fixture is no conflict (fixtures are res:// files).

## The user argument that asks for the wipe.
const FLAG := "--wipe-save"
## Test mode's script, named by path (as the game root names it).
const TEST_MODE_SCRIPT := "res://src/test_mode/test_mode.gd"


## The wipe this launch's `user_args` ask for, on `directory` (the main
## scene's is SaveStore.DEFAULT_DIRECTORY). Without FLAG it does nothing.
## Returns {"refusal" ("" or why the wipe was refused, nothing deleted: a
## debug launch then quits with exit code 1), "log" (the lines for the
## standard output: the wipe's count), "errors" (the files that couldn't be
## deleted, one line each: the launch carries on)}.
# @spec-link [[req_test_level_and_test_mode]]
static func run(user_args: PackedStringArray, directory: String) -> Dictionary:
	var result := {"refusal": "", "log": PackedStringArray(), "errors": PackedStringArray()}
	if FLAG not in user_args:
		return result
	var conflict := _save_to_start_from(user_args)
	if conflict != "":
		result["refusal"] = "Save wipe: %s refused, nothing deleted: %s." % [FLAG, conflict]
		return result
	var wiped := wipe(directory)
	result["errors"] = wiped["errors"]
	result["log"].append("Save wipe (%s): deleted %d files from %s; parent.json kept." % [
			FLAG, wiped["deleted"], directory])
	return result


## Deletes every file in `directory` (not its subdirectories; a missing
## directory holds none). Returns {"deleted" (how many), "errors" (a line for
## each file that couldn't be deleted)}.
# @spec-link [[req_test_level_and_test_mode]]
static func wipe(directory: String) -> Dictionary:
	var out := {"deleted": 0, "errors": PackedStringArray()}
	if not DirAccess.dir_exists_absolute(directory):
		return out
	for file in DirAccess.get_files_at(directory):
		var path := directory.path_join(file)
		var removed := DirAccess.remove_absolute(path)
		if removed == OK:
			out["deleted"] += 1
		else:
			out["errors"].append("Save wipe: can't delete %s (%s); the launch carries on." % [
					path, error_string(removed)])
	return out


## Why `user_args` name a save to start from: --load=PATH, a test script
## holding "load", or a test script that can't be read (it may hold one);
## "" when they name none.
# @spec-link [[req_test_level_and_test_mode]]
static func _save_to_start_from(user_args: PackedStringArray) -> String:
	for arg in user_args:
		if arg.get_slice("=", 0) == "--load":
			return "%s names a save to start from" % arg
	for arg in user_args:
		if arg.get_slice("=", 0) != "--test-script":
			continue
		var path := arg.substr("--test-script=".length())
		var loaded: Dictionary = load(TEST_MODE_SCRIPT).load_config_file(path)
		if not loaded["errors"].is_empty():
			return "the test script %s can't be read, so it may name a save to start from (%s)" % [
					path, "; ".join(loaded["errors"])]
		if loaded["config"].has("load"):
			return "the test script %s has \"load\", a save to start from" % path
	return ""
