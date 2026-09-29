extends SceneTree
## Tick cost of a whole level with its population (chunk 16; any level since
## chunk LD3), headless. Not a test: on the test level it records the
## numbers in docs/dev/README.md ("Off-screen simulation (chunk 15)", "The
## whole level, 200 slimes"); on another level it measures what level rule
## 16 asks a person to look at (piles mostly still).
##
## Run:   tools/level.sh bench [--level=<id>] [--ticks=600] [--fixture=NAME[,NAME...]]
##   (or godot --headless --path . -s res://tools/bench_level.gd -- [...])
##
##   --level=<id>     the level (LevelCatalog; default "test")
##   --ticks=N        timed ticks per case (default 600)
##   --fixture=NAMES  the cases to run, by fixture name ("fresh" is the
##                    start case); default: the test level's three cases
##                    below, or for another level `start` and every fixture
##                    of its folder that has a save, each with a lead-in of
##                    MOVING_LEAD_IN ticks
##
## Exit code: 0; 2 on a bad argument, an unknown level or fixture.
##
## Each case runs Simulation.step as the game does (the view follows the
## camera first; off-screen simulation on, as src/main.gd turns it on), no
## input, and times every tick of `ticks` after a case's untimed lead-in.
## The test level's cases:
##   start          the level as new (`fresh`): the first slime on the train
##                  and 199 sleepers, the camera at the start; lead-in 600.
##   stress-still   the fixture (60 in basket 3, 140 piled in the bowl, asleep
##                  at bedtime), the camera where the fixture puts it (the
##                  bowl, zoom 0.5); lead-in REST_TICK, when the loaded pile
##                  rests, so the timed ticks are the resting pile's. They end
##                  before the idle camera's cue (at 35 s without a touch)
##                  changes the zoom; the script checks it.
##   stress-moving  the fixture (200 train slimes through the bowl), the
##                  camera on the bowl; lead-in 60 (the rings take shape
##                  from the saved centres), then the train climbing out.
## It prints one RESULT line per case (median, p95 and mean ms per tick, the
## base slimes and the slime bodies, before -> after when fusion changed them,
## and what was simulated) and a table.
# @spec-link [[req_platform_and_performance_targets]]

const USAGE := "usage: tools/level.sh bench [--level=<id>] [--ticks=N] [--fixture=NAME[,NAME...]]"
const SEED := 909
## stress-still's pile rests this many ticks after loading
## (tools/make_fixture.gd measured it; test_fixtures_e2e checks it).
const REST_TICK := 670
const START_LEAD_IN := 600
const MOVING_LEAD_IN := 60

var ticks := 600
var level_id := LevelCatalog.DEFAULT_ID
## The fixtures asked for (--fixture), or [] for the default cases.
var fixtures: PackedStringArray = []
var level: Level
var terrain: TerrainSegments
var rows: Array[String] = []


## Reads the arguments, loads the level, runs its cases and prints them.
func _init() -> void:
	var problem := _parse()
	if problem.is_empty():
		problem = LevelCatalog.problem(level_id)
	if not problem.is_empty():
		printerr("bench_level: %s" % problem)
		printerr(USAGE)
		quit(2)
		return
	level = load(LevelCatalog.scene_path(level_id)).instantiate()
	var errors := level.build()
	if not errors.is_empty():
		printerr("bench_level: level %s doesn't build: %s" % [level_id, "; ".join(errors)])
		level.free()
		quit(2)
		return
	terrain = SlimeWorld.terrain_from(level)
	for case in _cases():
		var sim := _fresh() if case[0] == "fresh" else _from_fixture(case[0])
		if sim == null:
			level.free()
			quit(2)
			return
		_case("start" if case[0] == "fresh" else case[0], sim, case[1])
	print("")
	print("| Case | Base slimes | Bodies | Ticks | Median ms/tick | p95 ms/tick | Mean ms/tick |")
	print("|---|---|---|---|---|---|---|")
	for row in rows:
		print(row)
	level.free()
	quit()


## Reads the arguments into the settings. Returns "" or the problem.
func _parse() -> String:
	for arg in OS.get_cmdline_user_args():
		var parts := arg.split("=", true, 1)
		var value := parts[1] if parts.size() > 1 else ""
		match parts[0]:
			"--ticks":
				if not value.is_valid_int() or value.to_int() < 1:
					return "--ticks wants a whole number of ticks, 1 or more (got '%s')" % value
				ticks = value.to_int()
			"--level":
				level_id = value
			"--fixture":
				fixtures = value.split(",", false)
				if fixtures.is_empty():
					return "--fixture wants fixture names, comma separated"
			_:
				return "unknown argument '%s'" % arg
	return ""


## The cases to run, [fixture name ("fresh": the level as new), lead-in
## ticks], in order (see the file's doc).
func _cases() -> Array:
	if not fixtures.is_empty():
		var asked := []
		for name in fixtures:
			asked.append([name, _lead_in(name)])
		return asked
	if level_id == LevelCatalog.DEFAULT_ID:
		return [["fresh", _lead_in("fresh")], ["stress-still", _lead_in("stress-still")],
				["stress-moving", _lead_in("stress-moving")]]
	var out := [["fresh", _lead_in("fresh")]]
	var names := []
	for file in DirAccess.get_files_at(LevelCatalog.fixtures_dir(level_id)):
		var name := file.trim_suffix(TestMode.SIDECAR_EXTENSION)
		if file.ends_with(TestMode.SIDECAR_EXTENSION) and FileAccess.file_exists(TestMode.fixture_path(name, level_id)):
			names.append(name)
	names.sort()
	for name in names:
		out.append([name, _lead_in(name)])
	return out


## Case `name`'s lead-in, ticks: the test level's own cases keep theirs
## (so a --fixture run matches the default one), any other MOVING_LEAD_IN.
func _lead_in(name: String) -> int:
	if name == "fresh":
		return START_LEAD_IN
	if level_id == LevelCatalog.DEFAULT_ID and name == "stress-still":
		return REST_TICK
	return MOVING_LEAD_IN


## The level as new, the camera at the start (Simulation.load_level puts it
## there), simulated only near the view.
func _fresh() -> Simulation:
	var sim := Simulation.new(SEED)
	sim.slimes.terrain = terrain
	sim.load_level(level.data)
	sim.offscreen.enabled = true
	return sim


## Fixture `fixture_name` loaded as test mode loads it: its save, the camera
## on the rails nearest the fixture's point (or thing, Level.point_of),
## simulated only near the view. Null (said on stderr) when it can't load.
func _from_fixture(fixture_name: String) -> Simulation:
	var loaded := TestMode.load_fixture(fixture_name, level_id)
	if not loaded["ok"]:
		printerr("bench_level: fixture %s of level %s: %s" % [fixture_name, level_id, loaded["error"]])
		return null
	if loaded["save"].is_empty():
		printerr("bench_level: fixture %s of level %s has no save: use \"fresh\" for the level as new"
				% [fixture_name, level_id])
		return null
	var sim := Simulation.from_save(loaded["save"], level.data, terrain, SEED)
	if sim == null:
		printerr("bench_level: fixture %s doesn't load on level %s: %s" % [fixture_name, level_id,
				"; ".join(SaveData.problems(loaded["save"], level.data))])
		return null
	var camera: Variant = loaded["camera"]
	if camera is String:
		var named: String = camera
		camera = level.point_of(named)
		if camera == null:
			printerr("bench_level: fixture %s's camera: no '%s' in level %s" % [fixture_name, named, level_id])
			return null
	if camera != null:
		sim.camera.start(level.data.loop, sim.train.open_gates, camera)
	sim.offscreen.enabled = true
	sim.hint.world_shown(sim.tick)
	return sim


## Runs `lead_in` ticks untimed, then times each of `ticks` ticks and prints
## the case's RESULT line.
func _case(case_name: String, sim: Simulation, lead_in: int) -> void:
	if sim == null:
		return
	for t in lead_in:
		_step(sim)
	var zoom_before := sim.camera.zoom
	var bodies_before := sim.slimes.slime_count
	var resting_before := _count_calm(sim, SlimeBodies.RESTING)
	var spent := PackedFloat64Array()
	spent.resize(ticks)
	for t in ticks:
		var start := Time.get_ticks_usec()
		_step(sim)
		spent[t] = (Time.get_ticks_usec() - start) / 1000.0
	var total := 0.0
	for ms in spent:
		total += ms
	var sorted := spent.duplicate()
	sorted.sort()
	var median := sorted[sorted.size() / 2]
	var p95 := sorted[mini(sorted.size() - 1, int(ceil(sorted.size() * 0.95)) - 1)]
	var mean := total / ticks
	var steady := is_equal_approx(sim.camera.zoom, zoom_before) and sim.camera.mode == Camera.RAILS
	var bodies := "%d" % bodies_before
	if sim.slimes.slime_count != bodies_before:
		bodies += "->%d" % sim.slimes.slime_count
	print("RESULT case=%s base=%d bodies=%s ticks=%d lead_in=%d median_ms=%.3f p95_ms=%.3f mean_ms=%.3f parked=%d resting=%d->%d zoom=%.3f camera_steady=%s" % [
		case_name, _base_slimes(sim), bodies, ticks, lead_in, median, p95, mean, _count_calm(sim, SlimeBodies.PARKED),
		resting_before, _count_calm(sim, SlimeBodies.RESTING), sim.camera.zoom, steady])
	rows.append("| %s | %d | %s | %d | %.3f | %.3f | %.3f |" % [case_name, _base_slimes(sim), bodies, ticks, median, p95,
			mean])


## One tick as the game runs it: the view follows the camera first.
func _step(sim: Simulation) -> void:
	sim.camera.apply_to(sim.view, ScreenView.DEFAULT_SIZE)
	sim.step()


## How many base slimes `sim` holds: its slimes' sizes added up.
func _base_slimes(sim: Simulation) -> int:
	var count := 0
	for slime_id in sim.slimes.ids():
		count += sim.slimes.size_of(slime_id)
	return count


## How many of `sim`'s slimes are `calm` (SlimeBodies.RESTING or PARKED).
func _count_calm(sim: Simulation, calm: int) -> int:
	var count := 0
	for slime_id in sim.slimes.ids():
		if sim.slimes.calm_of(slime_id) == calm:
			count += 1
	return count
