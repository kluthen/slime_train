extends SceneTree
## Tick cost of the whole test level with its full population (chunk 16),
## headless. Not a test: it records the numbers in docs/dev/README.md
## ("Off-screen simulation (chunk 15)", "The whole level, 200 slimes").
##
## Run:   godot --headless --path . -s res://tools/bench_level.gd [-- --ticks=600]
##
## Each case runs Simulation.step as the game does (the view follows the
## camera first; off-screen simulation on, as src/main.gd turns it on), no
## input, and times every tick of `ticks` after a case's untimed lead-in:
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

const LEVEL_SCENE := "res://levels/test/level.tscn"
const SEED := 909
## stress-still's pile rests this many ticks after loading
## (tools/make_fixture.gd measured it; test_fixtures_e2e checks it).
const REST_TICK := 670
const START_LEAD_IN := 600
const MOVING_LEAD_IN := 60

var ticks := 600
var level: Level
var terrain: TerrainSegments
var rows: Array[String] = []


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=", true, 1)
		if parts[0] == "ticks":
			ticks = int(parts[1])
	level = load(LEVEL_SCENE).instantiate()
	level.build()
	terrain = SlimeWorld.terrain_from(level)
	_case("start", _fresh(), START_LEAD_IN)
	_case("stress-still", _from_fixture("stress-still"), REST_TICK)
	_case("stress-moving", _from_fixture("stress-moving"), MOVING_LEAD_IN)
	print("")
	print("| Case | Base slimes | Bodies | Ticks | Median ms/tick | p95 ms/tick | Mean ms/tick |")
	print("|---|---|---|---|---|---|---|")
	for row in rows:
		print(row)
	level.free()
	quit()


## The level as new, the camera at the start (Simulation.load_level puts it
## there), simulated only near the view.
func _fresh() -> Simulation:
	var sim := Simulation.new(SEED)
	sim.slimes.terrain = terrain
	sim.load_level(level.data)
	sim.offscreen.enabled = true
	return sim


## Fixture `fixture_name` loaded as test mode loads it: its save, the camera
## on the rails nearest the fixture's point, simulated only near the view.
func _from_fixture(fixture_name: String) -> Simulation:
	var loaded := TestMode.load_fixture(fixture_name)
	if not loaded["ok"]:
		push_error("bench_level: fixture %s: %s" % [fixture_name, loaded["error"]])
		quit(1)
		return null
	var sim := Simulation.from_save(loaded["save"], level.data, terrain, SEED)
	if loaded["camera"] != null:
		sim.camera.start(level.data.loop, sim.train.open_gates, loaded["camera"])
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
