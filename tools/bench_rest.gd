extends SceneTree
## The resting-pile rule measured (chunk 22, D107), headless on the test
## level: how long a bedtime pile on open ground takes to rest, and how often
## awake slimes hopping against a resting pile wake it. Not a test (the rule
## is SlimeBodies' REST_DRIFT, REST_TICKS and WAKE_SPEED; this only measures
## it); tests/e2e/test_bench_rest_e2e.gd pins its first outcome.
##
## Run:   tools/level.sh rest [--case=open|wake|all] [--slimes=20,40,80]
##            [--seeds=1,2,3] [--within=14400] [--after=300] [--pile=bowl|open]
##            [--hoppers=0,1,3] [--ticks=3600]
##   (or godot --headless --path . -s res://tools/bench_rest.gd -- [...])
##
##   --case=NAME     open, wake or all (default all)
##   --slimes=NS     open: the pile sizes (default 20,40,80)
##   --seeds=SEEDS   the run seeds, for both cases (default 1,2,3)
##   --within=N      the most ticks waited for a pile to rest (14400: 4 min)
##   --after=N       open: ticks timed once it rests (300)
##   --pile=NAME     wake: the resting pile, bowl (stress-still's 140) or
##                   open (the first --slimes size's open pile) (bowl)
##   --hoppers=KS    wake: how many hoppers at a time, per case (0,1,3)
##   --ticks=N       wake: the ticks counted once the pile rests (3600)
##
## Exit code: 0; 2 on a bad argument or a case that can't be built; 3 when a
## wake case's pile doesn't rest within --within before the hoppers come
## (nothing counted: wakes of an unrested pile mean nothing).
##
## Every tick runs Simulation.step as the game does (the view follows the
## camera first; off-screen simulation on), no input, each tick timed.
##   open  tools/bench_rest/open_pile.gd: a heap of N size-1 slimes on the
##         parade (section 2's flat floor) falls asleep at bedtime; the pile
##         (every slime asleep for the night, tools/bench_level/pile_rest.gd)
##         is stepped until it rests. RESULT: rested_at (ticks, or never),
##         seconds, calm_at (the first tick none of it is ACTIVE: resting or
##         parked off screen), the heap's rows and width, the pile's spread
##         along x at the end, mean and max ms per tick while settling, mean
##         ms per tick over --after ticks at rest, and the pile's resting,
##         parked and active counts at the end.
##   wake  the pile rests first (stress-still's loaded as tools/bench_level.gd
##         loads it, or the open one), then --ticks ticks with K hoppers
##         (tools/bench_rest/hoppers.gd: train slimes passing along the
##         pile, one after the other). A wake is the pile going from resting
##         (every member RESTING) to not; it lasts until it rests again.
##         RESULT: wakes, wakes per minute, mean and max wake length
##         (ticks), the share of ticks awake, ticks still awake at the end
##         (open_wake), the most pile members awake at once, the hoppers'
##         passes and strays (a stalled train slime is moved to the start of
##         the loop after a minute: a stray), mean ms per tick
##         while the pile rests and while it is awake, and the mean overall.
# @spec-link [[req_offscreen_simulation]]

const USAGE := ("usage: tools/level.sh rest [--case=open|wake|all] [--slimes=N,...] [--seeds=S,...] "
		+ "[--within=N] [--after=N] [--pile=bowl|open] [--hoppers=K,...] [--ticks=N]")
const PILE_REST := preload("res://tools/bench_level/pile_rest.gd")
const OPEN_PILE := preload("res://tools/bench_rest/open_pile.gd")
const HOPPERS := preload("res://tools/bench_rest/hoppers.gd")
const BOWL_FIXTURE := "stress-still"
const MINUTE_TICKS := 60 * Simulation.TICK_RATE

var case_name := "all"
var sizes: Array[int] = [20, 40, 80]
var seeds: Array[int] = [1, 2, 3]
var within := 14400
var after := 300
var pile_source := "bowl"
var hopper_counts: Array[int] = [0, 1, 3]
var ticks := 3600
var level: Level
var terrain: TerrainSegments
var rows: Array[String] = []


## Reads the arguments, loads the test level, runs the cases and prints them.
func _init() -> void:
	var problem := _parse()
	if not problem.is_empty():
		_quit_bad(problem)
		return
	level = load(LevelCatalog.scene_path(LevelCatalog.DEFAULT_ID)).instantiate()
	var errors := level.build()
	if not errors.is_empty():
		_quit_bad("the test level doesn't build: %s" % "; ".join(errors))
		return
	terrain = SlimeWorld.terrain_from(level)
	var code := 0
	if case_name in ["open", "all"]:
		code = _open_cases()
	if code == 0 and case_name in ["wake", "all"]:
		code = _wake_cases()
	for row in rows:
		print(row)
	level.free()
	quit(code)


## Says `problem` and the usage on stderr and quits with 2.
func _quit_bad(problem: String) -> void:
	printerr("bench_rest: %s" % problem)
	printerr(USAGE)
	if level != null:
		level.free()
	quit(2)


## Reads the arguments into the settings. Returns "" or the problem.
func _parse() -> String:
	for arg in OS.get_cmdline_user_args():
		var parts := arg.split("=", true, 1)
		var value := parts[1] if parts.size() > 1 else ""
		match parts[0]:
			"--case":
				if not value in ["open", "wake", "all"]:
					return "--case wants open, wake or all (got '%s')" % value
				case_name = value
			"--pile":
				if not value in ["bowl", "open"]:
					return "--pile wants bowl or open (got '%s')" % value
				pile_source = value
			"--slimes", "--seeds", "--hoppers":
				var numbers := _numbers(value, 1 if parts[0] == "--slimes" else 0)
				if numbers.is_empty():
					return "%s wants whole numbers, comma separated (got '%s')" % [parts[0], value]
				if parts[0] == "--slimes":
					sizes = numbers
				elif parts[0] == "--seeds":
					seeds = numbers
				else:
					hopper_counts = numbers
			"--within", "--after", "--ticks":
				if not value.is_valid_int() or value.to_int() < 1:
					return "%s wants a whole number of ticks, 1 or more (got '%s')" % [parts[0], value]
				if parts[0] == "--within":
					within = value.to_int()
				elif parts[0] == "--after":
					after = value.to_int()
				else:
					ticks = value.to_int()
			_:
				return "unknown argument '%s'" % arg
	return ""


## `text`'s comma-separated whole numbers, each at least `least`; [] when
## one isn't.
static func _numbers(text: String, least: int) -> Array[int]:
	var out: Array[int] = []
	for part in text.split(",", false):
		if not part.is_valid_int() or part.to_int() < least:
			return []
		out.append(part.to_int())
	return out


## The open-ground cases: each size, each seed. Returns the exit code.
func _open_cases() -> int:
	rows.append_array(["", "| Open pile | Seed | Rested at (ticks) | Seconds | None active at | Heap rows x width (px) "
			+ "| Spread (px) | Settling mean ms/tick | Settling max ms/tick | At rest mean ms/tick "
			+ "| Resting/parked/active |", "|---|---|---|---|---|---|---|---|---|---|---|"])
	for size in sizes:
		for run_seed in seeds:
			var built := OPEN_PILE.build(level, terrain, size, run_seed)
			if built["sim"] == null:
				printerr("bench_rest: open pile of %d, seed %d: %s" % [size, run_seed, built["error"]])
				return 2
			_open_case(built["sim"], size, run_seed, built["spots"])
	return 0


## One open-ground case: steps until the pile rests (at most `within`), then
## `after` ticks more, and prints its RESULT line. Also noted: the first
## tick none of the pile is ACTIVE (calm_at: each member RESTING or PARKED,
## nothing of it simulated; a member that crept off screen is parked, and a
## parked slime never counts as resting), and the pile's calms at the end.
func _open_case(sim: Simulation, size: int, run_seed: int, spots: Array) -> void:
	var pile: Array[int] = PILE_REST.pile_of(sim)
	var settling := PackedFloat64Array()
	var rested_at := PILE_REST.NEVER
	var calm_at := PILE_REST.NEVER
	while rested_at == PILE_REST.NEVER and settling.size() < within:
		settling.append(_timed_step(sim))
		if calm_at == PILE_REST.NEVER and _calm_count(sim, pile, SlimeBodies.ACTIVE) == 0:
			calm_at = settling.size()
		if PILE_REST.rests(sim, pile):
			rested_at = settling.size()
	var spread := _spread(sim, pile)
	var at_rest := PackedFloat64Array()
	if rested_at != PILE_REST.NEVER:
		for t in after:
			at_rest.append(_timed_step(sim))
	var rested := _ticks_text(rested_at)
	var seconds := "-" if rested_at == PILE_REST.NEVER else "%.2f" % (rested_at / float(Simulation.TICK_RATE))
	var heap := _heap_shape(spots)
	var calms := "%d/%d/%d" % [_calm_count(sim, pile, SlimeBodies.RESTING), _calm_count(sim, pile, SlimeBodies.PARKED),
			_calm_count(sim, pile, SlimeBodies.ACTIVE)]
	print(("RESULT case=open slimes=%d seed=%d rested_at=%s seconds=%s calm_at=%s heap_rows=%d heap_width=%d "
			+ "spread=%d settle_mean_ms=%.3f settle_max_ms=%.3f rest_mean_ms=%s after=%d "
			+ "resting/parked/active=%s zoom=%.3f") % [size, run_seed, rested, seconds, _ticks_text(calm_at), heap.x,
			heap.y, spread, _mean(settling), _max(settling), _mean_text(at_rest), at_rest.size(), calms,
			sim.camera.zoom])
	rows.append("| %d | %d | %s | %s | %s | %d x %d | %d | %.3f | %.3f | %s | %s |" % [size, run_seed, rested,
			seconds, _ticks_text(calm_at), heap.x, heap.y, spread, _mean(settling), _max(settling),
			_mean_text(at_rest), calms])


## How many of `pile` are `calm` (SlimeBodies.ACTIVE, RESTING or PARKED).
static func _calm_count(sim: Simulation, pile: Array[int], calm: int) -> int:
	return pile.filter(func(slime_id: int) -> bool: return sim.slimes.calm_of(slime_id) == calm).size()


## `ticks` as text: "never" for PILE_REST.NEVER.
static func _ticks_text(ticks_found: int) -> String:
	return "never" if ticks_found == PILE_REST.NEVER else "%d" % ticks_found


## The wake cases: each hopper count, each seed. Returns the exit code.
func _wake_cases() -> int:
	rows.append_array(["", "| Pile | Hoppers | Seed | Pile rested at | Wakes | Wakes/min | Mean wake (ticks) "
			+ "| Max wake (ticks) | Awake share | Most awake | Passes/strays | At rest ms/tick | Awake ms/tick | Mean ms/tick |",
			"|---|---|---|---|---|---|---|---|---|---|---|---|---|---|"])
	for hoppers in hopper_counts:
		for run_seed in seeds:
			var sim := _resting_pile_sim(run_seed)
			if sim == null:
				return 2
			var pile: Array[int] = PILE_REST.pile_of(sim)
			var rested_at := PILE_REST.ticks_to_rest(sim, pile, within, _step.bind(sim))
			if rested_at == PILE_REST.NEVER:
				printerr("bench_rest: the %s pile (seed %d) doesn't rest within %d ticks: nothing counted"
						% [pile_source, run_seed, within])
				return 3
			_wake_case(sim, pile, hoppers, run_seed, rested_at)
	return 0


## The simulation with the wake cases' pile, not yet rested: stress-still as
## tools/bench_level.gd loads it (bowl), or the first --slimes size's open
## pile (open).
## Null (said on stderr) when it can't be built.
func _resting_pile_sim(run_seed: int) -> Simulation:
	if pile_source == "open":
		var built := OPEN_PILE.build(level, terrain, sizes[0], run_seed)
		if built["sim"] == null:
			printerr("bench_rest: open pile of %d, seed %d: %s" % [sizes[0], run_seed, built["error"]])
		return built["sim"]
	var loaded := TestMode.load_fixture(BOWL_FIXTURE)
	if not loaded["ok"] or not loaded["camera"] is Vector2:
		printerr("bench_rest: fixture %s: %s" % [BOWL_FIXTURE, loaded.get("error", "no camera point")])
		return null
	var sim := Simulation.from_save(loaded["save"], level.data, terrain, run_seed)
	if sim == null:
		printerr("bench_rest: fixture %s doesn't load on the test level" % BOWL_FIXTURE)
		return null
	sim.camera.start(level.data.loop, sim.train.open_gates, loaded["camera"])
	sim.offscreen.enabled = true
	sim.hint.world_shown(sim.tick)
	return sim


## One wake case: `ticks` ticks with `count` hoppers against the resting
## `pile`, counted and timed; prints its RESULT line.
func _wake_case(sim: Simulation, pile: Array[int], count: int, run_seed: int, rested_at: int) -> void:
	var hoppers: HOPPERS = HOPPERS.new(sim, pile, count)
	var resting := true
	var woke_at := 0
	var lengths: Array[int] = []
	var rest_ms := PackedFloat64Array()
	var awake_ms := PackedFloat64Array()
	var most_awake := 0
	for t in ticks:
		hoppers.before_tick()
		var ms := _timed_step(sim)
		if resting:
			rest_ms.append(ms)
		else:
			awake_ms.append(ms)
		var now := PILE_REST.rests(sim, pile)
		if not now:
			most_awake = maxi(most_awake, _calm_count(sim, pile, SlimeBodies.ACTIVE))
		if resting and not now:
			woke_at = t
		elif now and not resting:
			lengths.append(t - woke_at)
		resting = now
	var open_wake := 0 if resting else ticks - woke_at
	var wakes := lengths.size() + (0 if resting else 1)
	var total := rest_ms.size() + awake_ms.size()
	var per_minute := wakes * MINUTE_TICKS / float(ticks)
	var mean_len := "-" if lengths.is_empty() else "%.1f" % (lengths.reduce(func(a, b): return a + b, 0)
			/ float(lengths.size()))
	var max_len := "-" if lengths.is_empty() else "%d" % lengths.max()
	var awake_share := awake_ms.size() / float(total)
	var mean_all := (_sum(rest_ms) + _sum(awake_ms)) / total
	print(("RESULT case=wake pile=%s slimes=%d hoppers=%d seed=%d rested_at=%d ticks=%d wakes=%d wakes_per_min=%.2f "
			+ "mean_wake_ticks=%s max_wake_ticks=%s open_wake=%d awake_share=%.3f most_awake=%d passes=%d strays=%d "
			+ "rest_mean_ms=%s awake_mean_ms=%s mean_ms=%.3f zoom=%.3f") % [pile_source, pile.size(), count,
			run_seed, rested_at, ticks, wakes, per_minute, mean_len, max_len, open_wake, awake_share, most_awake,
			hoppers.passes, hoppers.strays, _mean_text(rest_ms), _mean_text(awake_ms), mean_all, sim.camera.zoom])
	rows.append("| %s %d | %d | %d | %d | %d | %.2f | %s | %s | %.3f | %d | %d/%d | %s | %s | %.3f |" % [
			pile_source, pile.size(), count, run_seed, rested_at, wakes, per_minute, mean_len, max_len, awake_share,
			most_awake, hoppers.passes, hoppers.strays, _mean_text(rest_ms), _mean_text(awake_ms), mean_all])


## One tick as the game runs it: the view follows the camera first.
func _step(sim: Simulation) -> void:
	sim.camera.apply_to(sim.view, ScreenView.DEFAULT_SIZE)
	sim.step()


## _step(), timed: returns the milliseconds it took.
func _timed_step(sim: Simulation) -> float:
	var start := Time.get_ticks_usec()
	_step(sim)
	return (Time.get_ticks_usec() - start) / 1000.0


## The heap's rows (the most spots in one column) and width (its outer
## columns' centres apart, px), as Vector2i(rows, width).
static func _heap_shape(spots: Array) -> Vector2i:
	var per_column := {}
	for spot in spots:
		per_column[spot.x] = per_column.get(spot.x, 0) + 1
	var xs := per_column.keys()
	return Vector2i(per_column.values().max(), int(xs.max() - xs.min()))


## How far apart the pile's outermost centres are along x, px.
static func _spread(sim: Simulation, pile: Array[int]) -> int:
	var low := INF
	var high := -INF
	for slime_id in pile:
		var x := sim.slimes.centre_of(slime_id).x
		low = minf(low, x)
		high = maxf(high, x)
	return int(high - low)


## The sum of `values`.
static func _sum(values: PackedFloat64Array) -> float:
	var total := 0.0
	for value in values:
		total += value
	return total


## The mean of `values` (0 when empty).
static func _mean(values: PackedFloat64Array) -> float:
	return _sum(values) / values.size() if not values.is_empty() else 0.0


## The mean of `values` to 3 decimals, or "-" when empty.
static func _mean_text(values: PackedFloat64Array) -> String:
	return "-" if values.is_empty() else "%.3f" % _mean(values)


## The largest of `values` (0 when empty).
static func _max(values: PackedFloat64Array) -> float:
	var top := 0.0
	for value in values:
		top = maxf(top, value)
	return top
