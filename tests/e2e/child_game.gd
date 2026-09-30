extends RefCounted
## The command line of a child process that runs the game with this same
## binary, for the end-to-end tests that check a run gives the same result
## in another process. In the editor the child needs `--path` to find the
## project; an exported build has its project in its pack and refuses
## `--path` (tools/linux/e2e.sh, tests/export_runner/gut_runner.gd).


## The engine arguments of a headless child that quits after `quit_after`
## frames at the latest, up to and including the "--" before the game's own
## arguments: append those to the result.
static func engine_args(quit_after: int) -> PackedStringArray:
	var args := PackedStringArray(["--headless", "--quit-after", str(quit_after)])
	if OS.has_feature("editor"):
		args.append_array(["--path", ProjectSettings.globalize_path("res://")])
	args.append("--")
	return args
