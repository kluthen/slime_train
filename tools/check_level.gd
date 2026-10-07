extends SceneTree
## The level-rules checker's command line (chunk LD1): checks a level
## against the level design rules (specs/level-design.md) with LevelChecker
## (tools/level_check/) and prints what passes, what fails and what is left
## for a person.
##
## Run:   tools/level.sh check [--level=<id>] [--rule=N[,M...]] [--fast] [--json]
##   (tools/level.sh imports first and starts Godot with --no-header, so
##   --json prints the JSON alone on stdout; the raw command is
##   godot --headless --no-header --path . -s res://tools/check_level.gd -- ...)
##
##   --level=<id>   the level to check (LevelCatalog; default "test")
##   --rule=N,M     only these rules (1 to 23; default every rule)
##   --fast         skip the behaviour runs (rules 1, 2 and 7): layout only
##   --json         print one JSON object instead of text
##
## Text output: a header line, then one line per check ("load", then
## "rule N"), each "<label padded to 8> <status padded to 7> <title>", with
## its findings ("- <id> (x <screens>): <text>"), its warnings ("warn: ",
## the same shape: what may be wrong but a static estimate can't settle;
## they don't change the status), what is left for a person ("manual: ")
## and its notes ("note: ") indented under it; then a summary line. JSON
## output: {"level", "version", "fast", "load" (the load check), "results"
## (the rules, each with its "warnings"), "counts" (status -> how many
## rules), "warnings" (how many warnings)}; a finding's x is null when it
## has none.
##
## Exit code: 0 when nothing FAILs, 1 when a check FAILs (the load check or
## a rule), 2 when it can't run (bad arguments, unknown level).

const USAGE := "usage: tools/level.sh check [--level=<id>] [--rule=N[,M...]] [--fast] [--json]"


var _level_id := LevelCatalog.DEFAULT_ID
var _rules_asked := []
var _fast := false
var _json := false
var _level: Level = null


## Parses the arguments and adds the level to the tree, where it readies
## (builds, bakes its terrain) before the first frame; quits with code 2
## when it can't run.
func _initialize() -> void:
	var code := _parse()
	if code == 0:
		code = _add_level()
	if code != 0:
		quit(code)


## The first frame: the level has readied; checks it and quits.
func _process(_delta: float) -> bool:
	if _level != null:
		var code := _check()
		_level.free()
		_level = null
		quit(code)
	return false


## Reads the arguments into the settings. Returns 0, or 2 on a bad one.
func _parse() -> int:
	for arg in OS.get_cmdline_user_args():
		var parts := arg.split("=", true, 1)
		match parts[0]:
			"--level":
				_level_id = parts[1] if parts.size() > 1 else ""
			"--rule":
				_rules_asked = _rules(parts[1] if parts.size() > 1 else "")
				if _rules_asked.is_empty():
					return _fail("--rule wants rule numbers from 1 to 23, comma separated (got '%s')" % arg)
			"--fast":
				_fast = true
			"--json":
				_json = true
			_:
				return _fail("unknown argument '%s'" % arg)
	return 0


## Loads the level and adds it to the tree. Returns 0, or 2 when there is
## no such level.
func _add_level() -> int:
	var problem := LevelCatalog.problem(_level_id)
	if not problem.is_empty():
		return _fail(problem)
	var scene = load(LevelCatalog.scene_path(_level_id)).instantiate()
	if not scene is Level:
		scene.free()
		return _fail("%s: its root isn't a Level (src/components/level.gd)" % LevelCatalog.scene_path(_level_id))
	_level = scene
	root.add_child(_level)
	return 0


## Checks the readied level and prints the report. Returns the exit code.
func _check() -> int:
	var started := Time.get_ticks_msec()
	var checker := LevelChecker.new(_level)
	var loaded := checker.check_load()
	var results := checker.check_all(_fast, _rules_asked)
	var counts := LevelChecker.counts(results)
	if _json:
		print(JSON.stringify({"level": _level_id, "version": _level.level_version, "fast": _fast,
				"load": LevelChecker.to_json_data([loaded])[0], "results": LevelChecker.to_json_data(results),
				"counts": counts, "warnings": LevelChecker.warning_count(results)}))
	else:
		print("check_level: level %s (version %d): %d sections, %d base slimes"
				% [_level_id, _level.level_version, checker.sections().size(), checker.base_slimes()])
		var all := [loaded]
		all.append_array(results)
		print(LevelChecker.format(all))
		var warnings := LevelChecker.warning_count(results)
		print("check_level: %d PASS, %d FAIL, %d MANUAL, %d N/A, %d warning%s%s, %.1f s" % [counts[LevelChecker.PASS],
				counts[LevelChecker.FAIL], counts[LevelChecker.MANUAL], counts[LevelChecker.NA], warnings,
				"" if warnings == 1 else "s", " (fast: behaviour skipped)" if _fast else "",
				(Time.get_ticks_msec() - started) / 1000.0])
	return 1 if loaded["status"] == LevelChecker.FAIL or counts[LevelChecker.FAIL] > 0 else 0


## The rule numbers in `list` ("7" or "1,7,22"), or [] when one isn't a rule.
static func _rules(list: String) -> Array:
	var out := []
	for part in list.split(","):
		if not part.strip_edges().is_valid_int() or part.to_int() < 1 or part.to_int() > 23:
			return []
		out.append(part.to_int())
	return out


## Prints `message` and the usage as an error; the exit code for "can't run".
static func _fail(message: String) -> int:
	printerr("check_level: %s" % message)
	printerr(USAGE)
	return 2
