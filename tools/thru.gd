extends SceneTree
## The train's throughput over a long run, headless on the test level: a
## test-mode fixture stepped with the game's own step
## (game.step_simulation, as --run-ticks does) for --ticks ticks (default
## 10,000), counting what the train does. Read only: the final STATE hash is
## a plain run's (`--test-mode --level=test --fixture=F --seed=N
## --run-ticks=T`). Not a test; the loop distances below are the test level's.
##
## Run:   godot --headless --no-header --path . -s res://tools/thru.gd --
##            [--fixture=stress-moving] [--seed=1] [--ticks=10000]
##
## Output (one line each, comma-separated after the tag):
##   THRU       the fixture, seed, starting tick, slimes and loop length
##   THRU_HDR   THRU_WIN's columns
##   THRU_WIN   every WINDOW ticks (and at the last tick): win_end (the
##              tick); x19, x22 (train slimes crossing loop distances X1, X2
##              forward); stall (train moves refused, Train.STALLED); oob
##              (the other refused moves); stuck (slimes the stuck rule
##              moved); hops (train hops taken, Train.hops_taken); sim_train
##              (train slimes not parked), all_train (every train slime);
##              bowl_n (train slimes in section 3's bowl, BOWL_LO to
##              BOWL_HI); back_mean (the mean loop distance of the bowl's
##              back half), back_adv (how far the back half at the window's
##              start advanced over it)
##   THRU_TOT   the totals: tick, x19, x22, stall, oob, stuck, hops,
##              first_stall (the first stalled tick, -1 for none)
##   THRU_HIST  where the train slimes end: 2000 px bins of loop distance,
##              count (parked)
##   STATE      the final tick and state hash
# @spec-link [[req_platform_and_performance_targets]]

const WINDOW := 600
## Loop distances (test level) whose forward crossings THRU_WIN counts.
const X1 := 19000.0
const X2 := 22000.0
## Section 3's bowl on the test level's loop, loop distances.
const BOWL_LO := 14000.0
const BOWL_HI := 18000.0
## A jump larger than this between two ticks is a recut or a move to the
## loop start, not a crossing.
const MAX_STEP := 5000.0

var fixture := "stress-moving"
var seed_n := 1
var ticks := 10000


func _initialize() -> void:
	var problem := _parse()
	if problem != "":
		printerr("thru: ", problem)
		quit(2)
		return
	var game: Node = load("res://src/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var parsed: Dictionary = load("res://src/test_mode/test_mode.gd").config_from_args(PackedStringArray(
			["--test-mode", "--level=test", "--fixture=" + fixture, "--seed=%d" % seed_n]))
	if not parsed["errors"].is_empty():
		printerr("thru: ", parsed["errors"])
		quit(2)
		return
	var errs: PackedStringArray = game.enable_test_mode(parsed["config"])
	if not errs.is_empty():
		printerr("thru: ", errs)
		quit(2)
		return
	_run(game)
	quit(0)


## Reads the user arguments into fixture, seed_n and ticks; returns the
## problem, or "" when they are all valid.
func _parse() -> String:
	for arg in OS.get_cmdline_user_args():
		var p := arg.trim_prefix("--").split("=", true, 1)
		if p.size() != 2:
			return "expected --name=value, got '%s'" % arg
		match p[0]:
			"fixture":
				fixture = p[1]
			"seed":
				if not p[1].is_valid_int():
					return "--seed must be an integer, got '%s'" % p[1]
				seed_n = int(p[1])
			"ticks":
				if not p[1].is_valid_int() or int(p[1]) < 1:
					return "--ticks must be a positive integer, got '%s'" % p[1]
				ticks = int(p[1])
			_:
				return "unknown argument '%s' (usage: --fixture=F --seed=N --ticks=T)" % arg
	return ""


## Steps `game` for `ticks` ticks, printing THRU_WIN per window, then
## THRU_TOT, THRU_HIST and STATE (see the class doc).
func _run(game: Node) -> void:
	var sim: Simulation = game.simulation
	var train: Train = sim.train
	var bodies: SlimeBodies = sim.slimes
	print("THRU fixture=%s seed=%d tick0=%d slimes=%d loop_len=%.0f" % [fixture, seed_n, sim.tick,
			bodies.slime_count, train.length()])
	print("THRU_HDR win_end,x19,x22,stall,oob,stuck,hops,sim_train,all_train,bowl_n,back_mean,back_adv")
	var prev := {}
	for id in train.tracked_ids():
		prev[id] = train.distance_of(id)
	var w := {"x1": 0, "x2": 0, "stall": 0, "oob": 0, "stuck": 0}
	var tot := {"x1": 0, "x2": 0, "stall": 0, "oob": 0, "stuck": 0}
	var hops0: int = train.hops_taken
	var first_stall := -1
	var back0 := _back_half(train, train.tracked_ids(), bodies)
	for i in ticks:
		game.step_simulation()
		var t := sim.tick - 1
		var now := {}
		for id in train.tracked_ids():
			var d := train.distance_of(id)
			now[id] = d
			if prev.has(id):
				var p: float = prev[id]
				if d >= p and d - p < MAX_STEP:
					w["x1"] += int(p < X1 and d >= X1)
					w["x2"] += int(p < X2 and d >= X2)
		prev = now
		for e in train.stalled:
			if e["tick"] != t:
				continue
			if e["reason"] == Train.STALLED:
				w["stall"] += 1
				if first_stall < 0:
					first_stall = t
			else:
				w["oob"] += 1
		for e in sim.stuck_slimes.stuck:
			if e["tick"] == t and e["moved"]:
				w["stuck"] += 1
		if sim.tick % WINDOW == 0 or i == ticks - 1:
			back0 = _print_window(sim, w, train.hops_taken - hops0, now, back0)
			hops0 = train.hops_taken
			for k in w:
				tot[k] += w[k]
				w[k] = 0
	print("THRU_TOT tick=%d x19=%d x22=%d stall=%d oob=%d stuck=%d hops=%d first_stall=%d" % [
			sim.tick, tot["x1"], tot["x2"], tot["stall"], tot["oob"], tot["stuck"], train.hops_taken,
			first_stall])
	_print_hist(train, bodies)
	print("STATE tick=%d hash=%s" % [sim.tick, sim.state_hash()])


## Prints one THRU_WIN line for the window ending now: `w` its counts,
## `hops` its hops, `now` every tracked slime's loop distance, `back0` the
## bowl's back half at its start. Returns the back half now (the next
## window's start).
func _print_window(sim: Simulation, w: Dictionary, hops: int, now: Dictionary, back0: Array) -> Array:
	var train: Train = sim.train
	var bodies: SlimeBodies = sim.slimes
	var sim_train := 0
	var all_train := 0
	for s in bodies.slime_count:
		if bodies.state[s] == SlimeBodies.TRAIN:
			all_train += 1
			if bodies.calm[s] != SlimeBodies.PARKED:
				sim_train += 1
	var ids := train.tracked_ids()
	var bowl_n := 0
	for id in ids:
		var d := train.distance_of(id)
		if bodies.state_of(id) == SlimeBodies.TRAIN and d >= BOWL_LO and d <= BOWL_HI:
			bowl_n += 1
	var back := _back_half(train, ids, bodies)
	var mean := 0.0
	for b in back:
		mean += b[0]
	mean = mean / maxf(back.size(), 1)
	# The mean advance of the window's starting back half (those still near
	# or ahead of where they were).
	var adv := 0.0
	var adv_n := 0
	for b in back0:
		if now.has(b[1]):
			var d2: float = now[b[1]]
			if d2 >= b[0] - 100.0:
				adv += d2 - b[0]
				adv_n += 1
	adv = adv / maxf(adv_n, 1)
	print("THRU_WIN %d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%.0f,%.0f" % [sim.tick, w["x1"], w["x2"], w["stall"],
			w["oob"], w["stuck"], hops, sim_train, all_train, bowl_n, mean, adv])
	return back


## The back half (lowest loop distances) of the train slimes in the bowl, as
## [distance, id] pairs sorted by distance.
func _back_half(train: Train, ids: PackedInt32Array, bodies: SlimeBodies) -> Array:
	var ds := []
	for id in ids:
		if bodies.state_of(id) != SlimeBodies.TRAIN:
			continue
		var d := train.distance_of(id)
		if d >= BOWL_LO and d <= BOWL_HI:
			ds.append([d, id])
	ds.sort()
	return ds.slice(0, ds.size() / 2)


## Prints THRU_HIST: the train slimes by 2000 px bin of loop distance, and
## how many of each are parked.
func _print_hist(train: Train, bodies: SlimeBodies) -> void:
	var hist := {}
	var parked := {}
	for id in train.tracked_ids():
		if bodies.state_of(id) != SlimeBodies.TRAIN:
			continue
		var bin := int(train.distance_of(id) / 2000.0) * 2
		hist[bin] = hist.get(bin, 0) + 1
		if bodies.calm[bodies.index_of(id)] == SlimeBodies.PARKED:
			parked[bin] = parked.get(bin, 0) + 1
	var keys := hist.keys()
	keys.sort()
	var parts := []
	for k in keys:
		parts.append("%dk:%d(p%d)" % [k, hist[k], parked.get(k, 0)])
	print("THRU_HIST ", " ".join(parts))
