extends GutHookScript
## GUT post-run hook: closes the ways a broken suite could still exit with 0.
## - A test script that doesn't load (a parse error, for example) is dropped
##   by GUT without a failure. Every test_*.gd under res://tests/ is loaded
##   here, and one that fails to load fails the run.
## - A run with no tests at all fails.
## - When tools/test.sh sets SLIME_TEST_MARKER, this hook writes that file, so
##   the script can tell a finished run from GUT quitting early with code 0.
## Otherwise GUT's own exit code stands (0 when every test passes, 1 if not).

const TESTS_ROOT := "res://tests/"


func run() -> void:
	var broken := _find_broken_test_scripts(TESTS_ROOT)
	for path in broken:
		gut.logger.error("Test script failed to load: %s" % path)
	if not broken.is_empty():
		set_exit_code(1)
	elif gut.get_test_count() == 0:
		gut.logger.error("No tests ran. Treating the run as a failure.")
		set_exit_code(1)
	_write_marker()


func _find_broken_test_scripts(dir_path: String) -> PackedStringArray:
	var broken := PackedStringArray()
	for sub in DirAccess.get_directories_at(dir_path):
		broken.append_array(_find_broken_test_scripts(dir_path.path_join(sub)))
	for file in DirAccess.get_files_at(dir_path):
		if file.begins_with("test_") and file.ends_with(".gd"):
			var path := dir_path.path_join(file)
			var script := load(path) as Script
			if script == null or not script.can_instantiate():
				broken.append(path)
	return broken


func _write_marker() -> void:
	var marker_path := OS.get_environment("SLIME_TEST_MARKER")
	if marker_path.is_empty():
		return
	var file := FileAccess.open(marker_path, FileAccess.WRITE)
	if file == null:
		gut.logger.error("Could not write the run marker %s" % marker_path)
		set_exit_code(1)
		return
	file.store_line("tests=%d failing=%d" % [gut.get_test_count(), gut.get_fail_count()])
