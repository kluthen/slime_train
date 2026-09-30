extends Node
## Runs GUT inside an exported debug build, where the export template has no
## `-s` (--script) option: tools/linux/e2e.sh makes this scene the main scene
## through an override.cfg next to the binary, for that run only. The GUT
## options (-g...) come from the command line, as with gut_cmdln.gd in the
## editor. Started without them, it is a test's child process of the same
## binary (tests/e2e/child_game.gd), and it hands over to the game.
## Test mode is debug-build-only, so a release build refuses to run tests.

## The game's main scene (run/main_scene in project.godot), which the
## override replaces for the binary's whole directory.
const GAME_SCENE := "res://src/main.tscn"


## Starts GUT's command-line runner once the tree is up (what
## addons/gut/gut_cmdln.gd does for `godot -s`), or boots the game for a
## child process.
func _ready() -> void:
	if not OS.is_debug_build():
		printerr("tests/export_runner: tests only run in a debug build.")
		get_tree().quit(2)
		return
	if not _has_gut_options():
		get_tree().change_scene_to_file.call_deferred(GAME_SCENE)
		return
	# Loading the loader runs its _static_init: GUT's own warnings are off
	# and its scripts are loaded before any test.
	load("res://addons/gut/gut_loader.gd")
	var cli: Node = load("res://addons/gut/cli/gut_cli.gd").new()
	get_tree().root.add_child.call_deferred(cli)
	await cli.ready
	cli.call("main")


## Whether the command line holds a GUT option (they all start with "-g").
func _has_gut_options() -> bool:
	for arg in OS.get_cmdline_args():
		if arg.begins_with("-g"):
			return true
	return false
