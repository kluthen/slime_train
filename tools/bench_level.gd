extends SceneTree
## Tick cost of a whole level with its population (chunk 16; any level since
## chunk LD3), headless. Not a test: on the test level it records the
## numbers in docs/dev/README.md ("Off-screen simulation (chunk 15)", "The
## whole level, 200 slimes"); on another level it measures what level rule
## 16 asks a person to look at (piles mostly still).
##
## Run:   tools/level.sh bench [--level=<id>] [--ticks=600] [--fixture=NAME[,NAME...]] [--lead-in=N] [--phases]
##   (or godot --headless --path . -s res://tools/bench_level.gd -- [...])
##
##   --level=<id>     the level (LevelCatalog; default "test")
##   --ticks=N        timed ticks per case (default 600)
##   --fixture=NAMES  the cases to run, by fixture name ("fresh" is the
##                    start case); default: the test level's three cases
##                    below, or for another level `start` and every fixture
##                    of its folder that has a save, each with a lead-in of
##                    MOVING_LEAD_IN ticks
##   --lead-in=N      every case's untimed lead-in, N ticks (0 or more), in
##                    place of its own (stress-still's rest detection
##                    included); to time a later moment of a fixture, e.g.
##                    s3-basket-59of60's basket releasing (full about tick
##                    554, fired about 2 s later): --lead-in=700
##   --phases         also times each case's timed ticks phase by phase (the
##                    debug phase timers, src/debug/phase_timers.gd, chunk 5N
##                    U0a): after its RESULT line, a case prints a PHASES line
##                    (whole step, solver and behaviour, mean µs per tick)
##                    and a table, one row per phase (mean µs per tick, kind,
##                    share of the step). The timers cost a few µs a tick,
##                    inside the RESULT line's times
##
## Exit code: 0; 2 on a bad argument, an unknown level or fixture; 3 when
## stress-still's pile doesn't rest within REST_WITHIN ticks (nothing timed:
## an unrested pile is never measured as a resting one).
##
## Each case runs Simulation.step as the game does (the view follows the
## camera first; off-screen simulation on, as src/main.gd turns it on), no
## input, and times every tick of `ticks` after a case's untimed lead-in.
## The test level's cases:
##   start          the level as new (`fresh`): the first slime on the train
##                  and 199 sleepers, the camera at the start; lead-in 600.
##   stress-still   the fixture (60 in basket 3, 140 piled in the bowl, asleep
##                  at bedtime), the camera where the fixture puts it (the
##                  bowl, zoom 0.5); lead-in until the loaded pile rests
##                  (chunk 22, D131: tools/bench_level/pile_rest.gd, every
##                  slime asleep for the night RESTING, detected tick by
##                  tick, at most REST_WITHIN; about 410 ticks since chunk
##                  19), so the timed ticks are the resting pile's. They end
##                  before the idle camera's cue (at 35 s without a touch)
##                  changes the zoom; the script checks it (camera_steady).
##   stress-moving  the fixture (200 train slimes through the bowl), the
##                  camera on the bowl; lead-in 60 (the rings take shape
##                  from the saved centres), then the train climbing out.
## It prints one RESULT line per case and a table: median, p95, max and mean
## ms per tick; the base slimes and the slime bodies, before -> after when
## fusion changed them; the lead-in (lead_in) and, for stress-still, the tick
## its pile rested at (rested_at, "-" for the other cases); the slime counts
## at the end of the timed ticks, as the debug overlay counts them
## (DebugCounts.count_slimes: physics, calm ACTIVE and not a sleeper; on
## screen, centre in the view, any state; in range, not parked; parked; the
## groups overlap; the table shows the last three and rule 23's numbers below); the resting slimes
## before -> after; the camera's zoom and whether it stayed steady; and, as
## means over the timed ticks, the slimes
## that cost physics (active: SlimeBodies.crowd_count, the same count as
## physics, baskets and slimes asleep at bedtime still settling included) and
## the solver's candidate pairs (pairs: SlimeBodies.candidate_pair_count).
## Level rule 23's measure over the timed ticks (chunk 24, item 24.7:
## ClusterWatch, tools/level_check/cluster_watch.gd, sampled every 0.1 s
## outside the timed span): the largest awake cluster, the slimes inside a
## basket's box and the train slimes on the loop's route left out
## (largest_cluster, in slimes), the seconds it was above ClusterWatch.LIMIT (above_limit_s) and
## the longest of them in a row (longest_above_s); numbers only, no verdict
## (a case isn't a level's played run: the played test gives the verdict).
# @spec-link [[req_platform_and_performance_targets]]
# @spec-link [[req_level_design_rules]]
# @spec-link [[rule_no_spot_where_slimes_gather_awake]]

const USAGE := ("usage: tools/level.sh bench [--level=<id>] [--ticks=N] [--fixture=NAME[,NAME...]] [--lead-in=N]"
		+ " [--phases]")
const SEED := 909
## When stress-still's pile rests (the lead-in until it does).
const PILE_REST := preload("res://tools/bench_level/pile_rest.gd")
## stress-still's pile must rest within this many ticks of loading (about
## 410 since chunk 19; the rest is margin, as test_fixtures_e2e's
## PILE_RESTS_WITHIN), else the bench fails (exit code 3).
const REST_WITHIN := 900
## A case's lead-in that runs until its loaded pile rests (PILE_REST), not a
## fixed number of ticks.
const UNTIL_PILE_RESTS := -1
const START_LEAD_IN := 600
const MOVING_LEAD_IN := 60

var ticks := 600
var level_id := LevelCatalog.DEFAULT_ID
## The fixtures asked for (--fixture), or [] for the default cases.
var fixtures: PackedStringArray = []
## The lead-in asked for (--lead-in), ticks, or -1: each case's own.
var lead_in_override := -1
## Whether each case's timed ticks are also timed phase by phase (--phases).
var time_phases := false
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
		if not _case("start" if case[0] == "fresh" else case[0], sim, case[1]):
			level.free()
			quit(3)
			return
	print("")
	print("| Case | Base slimes | Bodies | Ticks | Lead-in | Median ms/tick | p95 ms/tick | Max ms/tick "
			+ "| Mean ms/tick | On screen | In range | Parked | Largest cluster | Above limit s | Longest above s |")
	print("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
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
			"--lead-in":
				if not value.is_valid_int() or value.to_int() < 0:
					return "--lead-in wants a whole number of ticks, 0 or more (got '%s')" % value
				lead_in_override = value.to_int()
			"--phases":
				if parts.size() > 1:
					return "--phases takes no value (got '%s')" % arg
				time_phases = true
			_:
				return "unknown argument '%s'" % arg
	return ""


## The cases to run, [fixture name ("fresh": the level as new), lead-in
## ticks or UNTIL_PILE_RESTS], in order (see the file's doc).
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


## Case `name`'s lead-in, ticks or UNTIL_PILE_RESTS: --lead-in's when
## given, else the test level's own cases keep theirs (so a --fixture run
## matches the default one), any other MOVING_LEAD_IN.
func _lead_in(name: String) -> int:
	if lead_in_override >= 0:
		return lead_in_override
	if name == "fresh":
		return START_LEAD_IN
	if level_id == LevelCatalog.DEFAULT_ID and name == "stress-still":
		return UNTIL_PILE_RESTS
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


## Runs the lead-in untimed (`lead_in` ticks, or until the loaded pile
## rests for UNTIL_PILE_RESTS), then times each of `ticks` ticks and prints
## the case's RESULT line. False (said on stderr) when the pile doesn't rest
## within REST_WITHIN: nothing is timed then.
func _case(case_name: String, sim: Simulation, lead_in: int) -> bool:
	var rested_at := "-"
	if lead_in == UNTIL_PILE_RESTS:
		lead_in = PILE_REST.ticks_to_rest(sim, PILE_REST.pile_of(sim), REST_WITHIN, _step.bind(sim))
		if lead_in == PILE_REST.NEVER:
			push_error("bench_level: %s's pile doesn't rest within %d ticks: not timed" % [case_name, REST_WITHIN])
			printerr("bench_level: %s's pile doesn't rest within %d ticks: not timed" % [case_name, REST_WITHIN])
			return false
		rested_at = "%d" % lead_in
	else:
		for t in lead_in:
			_step(sim)
	var zoom_before := sim.camera.zoom
	var bodies_before := sim.slimes.slime_count
	var resting_before := _count_calm(sim, SlimeBodies.RESTING)
	var spent := PackedFloat64Array()
	spent.resize(ticks)
	var active_sum := 0
	var pairs_sum := 0
	var clusters := ClusterWatch.new()
	if time_phases:
		PhaseTimers.attach(sim)
	for t in ticks:
		var start := Time.get_ticks_usec()
		_step(sim)
		spent[t] = (Time.get_ticks_usec() - start) / 1000.0
		clusters.watch(sim)
		active_sum += sim.slimes.crowd_count()
		pairs_sum += sim.slimes.candidate_pair_count()
	var total := 0.0
	for ms in spent:
		total += ms
	var sorted := spent.duplicate()
	sorted.sort()
	var median := sorted[sorted.size() / 2]
	var p95 := sorted[mini(sorted.size() - 1, int(ceil(sorted.size() * 0.95)) - 1)]
	var worst := sorted[sorted.size() - 1]
	var mean := total / ticks
	var steady := is_equal_approx(sim.camera.zoom, zoom_before) and sim.camera.mode == Camera.RAILS
	var bodies := "%d" % bodies_before
	if sim.slimes.slime_count != bodies_before:
		bodies += "->%d" % sim.slimes.slime_count
	var counts := DebugCounts.count_slimes(sim)
	print(("RESULT case=%s base=%d bodies=%s ticks=%d lead_in=%d rested_at=%s median_ms=%.3f p95_ms=%.3f "
			+ "max_ms=%.3f mean_ms=%.3f physics=%d on_screen=%d in_range=%d parked=%d resting=%d->%d "
			+ "zoom=%.3f camera_steady=%s active=%.1f pairs=%.1f %s") % [case_name, _base_slimes(sim), bodies, ticks,
			lead_in, rested_at, median, p95, worst, mean, counts[DebugCounts.PHYSICS], counts[DebugCounts.ON_SCREEN],
			counts[DebugCounts.IN_RANGE], counts[DebugCounts.PARKED], resting_before,
			_count_calm(sim, SlimeBodies.RESTING), sim.camera.zoom, steady, float(active_sum) / ticks,
			float(pairs_sum) / ticks, clusters.fields()])
	rows.append("| %s | %d | %s | %d | %d | %.3f | %.3f | %.3f | %.3f | %d | %d | %d | %d | %.1f | %.1f |" % [
			case_name, _base_slimes(sim), bodies, ticks, lead_in, median, p95, worst, mean,
			counts[DebugCounts.ON_SCREEN], counts[DebugCounts.IN_RANGE], counts[DebugCounts.PARKED], clusters.largest,
			clusters.above_limit_s(), clusters.longest_above_s()])
	if time_phases:
		_print_phases(case_name, sim)
	return true


## Prints `sim`'s phase timers (attached for the timed ticks): the PHASES
## line and the per-phase table (PhaseTimers.table()).
func _print_phases(case_name: String, sim: Simulation) -> void:
	var means := PhaseTimers.means(sim)
	var split := PhaseTimers.split(means)
	var total := split.x + split.y
	print("PHASES case=%s ticks=%d step_us=%.1f solver_us=%.1f solver_share=%.1f behaviour_us=%.1f" % [case_name,
			sim.phases.ticks, total, split.x, 100.0 * split.x / total if total > 0.0 else 0.0, split.y])
	for line in PhaseTimers.table(means):
		print(line)
	PhaseTimers.detach(sim)


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
