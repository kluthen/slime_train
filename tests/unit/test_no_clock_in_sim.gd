extends GutTest
## The clock rule (CODING_RULE.md rule 2): the simulation (everything under
## src/sim/) never reads a clock and never schedules work on its own. Ticks
## come from the fixed 60 Hz step, and wall and monotonic time enter through
## the scene layer, so a run repeats (same seed, same state hash). The
## patterns are the clock ones of tools/code_health_check.py; global
## randomness has its own test (test_no_global_random.gd).

const SIM_ROOT := "res://src/sim/"
const CLOCK_PATTERNS := [
	"\\bTime\\s*\\.",
	"\\bOS\\s*\\.\\s*get_ticks_(msec|usec)\\b",
	"\\bOS\\s*\\.\\s*get_unix_time\\b",
	"\\bOS\\s*\\.\\s*get_system_time_(msecs|secs)\\b",
	"\\bEngine\\s*\\.\\s*get_(physics|process)_frames\\b",
	"\\bEngine\\s*\\.\\s*get_frames_drawn\\b",
	"\\bget_(physics_)?process_delta_time\\b",
	"\\bTimer\\s*\\.\\s*new\\b",
	"\\bcreate_timer\\s*\\(",
	"\\bThread\\s*\\.\\s*new\\b",
]


func test_no_clock_reads_in_sim() -> void:
	var patterns := _patterns()
	var strings := _string_literal()
	var offenders := PackedStringArray()
	for path in _gd_files(SIM_ROOT):
		var lines := FileAccess.get_file_as_string(path).split("\n")
		for i in lines.size():
			if _reads_a_clock(_code(lines[i], strings), patterns):
				offenders.append("%s:%d: %s" % [path, i + 1, lines[i].strip_edges()])
	assert_eq(offenders, PackedStringArray(),
			"time enters through the scene layer (src/save/session_clock.gd, TestClock)")


func test_the_check_catches_offenders() -> void:
	# Guards the regular expressions above against silently matching nothing.
	var patterns := _patterns()
	var strings := _string_literal()
	for bad in ["var t := Time.get_ticks_msec()", "var now = OS.get_ticks_usec()",
			"OS.get_unix_time()", "x = OS.get_system_time_msecs()", "Engine.get_physics_frames()",
			"Engine.get_frames_drawn()", "var dt := get_process_delta_time()",
			"var t := Timer.new()", "get_tree().create_timer(1.0)", "var th := Thread.new()"]:
		assert_true(_reads_a_clock(_code(bad, strings), patterns), bad)
	for good in ["var tick_time := 1.0", "sim.tick += 1", "# Time.get_ticks_msec() is refused",
			"push_error(\"no Time.get_ticks_msec() here\")", "var frames := hop_frames"]:
		assert_false(_reads_a_clock(_code(good, strings), patterns), good)


## The compiled CLOCK_PATTERNS.
func _patterns() -> Array[RegEx]:
	var compiled: Array[RegEx] = []
	for pattern: String in CLOCK_PATTERNS:
		compiled.append(RegEx.create_from_string(pattern))
	return compiled


## A double- or single-quoted string literal.
func _string_literal() -> RegEx:
	return RegEx.create_from_string("\"(?:\\\\.|[^\"\\\\])*\"|'(?:\\\\.|[^'\\\\])*'")


## `line` without its string literals and its trailing comment.
func _code(line: String, strings: RegEx) -> String:
	return strings.sub(line, "\"\"", true).split("#")[0]


## Whether `code` matches one of `patterns`.
func _reads_a_clock(code: String, patterns: Array[RegEx]) -> bool:
	for pattern in patterns:
		if pattern.search(code) != null:
			return true
	return false


## Every .gd file under `dir_path`, recursively.
func _gd_files(dir_path: String) -> PackedStringArray:
	var files := PackedStringArray()
	for sub in DirAccess.get_directories_at(dir_path):
		files.append_array(_gd_files(dir_path.path_join(sub)))
	for file in DirAccess.get_files_at(dir_path):
		if file.ends_with(".gd"):
			files.append(dir_path.path_join(file))
	return files
