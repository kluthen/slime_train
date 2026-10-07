class_name LevelCatalog
extends RefCounted
## Where the levels are, by ID (chunk LD1, docs/dev/level-tooling.md). A
## level `<id>` is the scene `res://levels/<id>/level.tscn`, found by that
## convention: there is no list to keep up. Its fixtures are in
## `res://levels/<id>/fixtures/`, its save is `user://saves/<id>.json`
## (SaveStore).
##
## Choosing a level by ID is for test mode, the tools and the tests (debug
## builds only): v1 ships one level and the player never chooses one
## (TestModeGuard keeps test mode out of release builds).

const LEVELS_DIR := "res://levels/"
## The level scene inside a level's folder.
const SCENE_FILE := "level.tscn"
## The fixtures' folder inside a level's folder.
const FIXTURES_SUBDIR := "fixtures/"
## The level test mode, the tools and the tests use when none is named.
const DEFAULT_ID := "test"
## A level ID: lowercase letters and digits, words joined by hyphens.
const _ID_PATTERN := "^[a-z0-9]+(-[a-z0-9]+)*$"

static var _id_regex: RegEx


## Whether `id` is a well-formed level ID ("test", "01", "my-level").
static func is_valid_id(id: String) -> bool:
	if _id_regex == null:
		_id_regex = RegEx.create_from_string(_ID_PATTERN)
	return _id_regex.search(id) != null


## The level's folder, "res://levels/<id>/".
static func dir_of(id: String) -> String:
	return LEVELS_DIR + id + "/"


## The level's scene, "res://levels/<id>/level.tscn".
static func scene_path(id: String) -> String:
	return dir_of(id) + SCENE_FILE


## The level's fixtures' folder, "res://levels/<id>/fixtures/".
static func fixtures_dir(id: String) -> String:
	return dir_of(id) + FIXTURES_SUBDIR


## Whether level `id` exists (its scene is there).
static func exists(id: String) -> bool:
	return is_valid_id(id) and ResourceLoader.exists(scene_path(id))


## Every level's ID, sorted: the folders of LEVELS_DIR that hold a level
## scene.
# @spec-link [[req_test_level_and_test_mode]]
static func ids() -> PackedStringArray:
	var out := PackedStringArray()
	for name in DirAccess.get_directories_at(LEVELS_DIR):
		if exists(name):
			out.append(name)
	out.sort()
	return out


## Why level `id` can't be loaded, or "" when it can.
# @spec-link [[req_test_level_and_test_mode]]
static func problem(id: String) -> String:
	if not is_valid_id(id):
		return "invalid level id '%s' (expected lowercase letters, digits and hyphens)" % id
	if not exists(id):
		return "no level '%s': %s is missing (levels: %s)" % [id, scene_path(id), ", ".join(ids())]
	return ""
