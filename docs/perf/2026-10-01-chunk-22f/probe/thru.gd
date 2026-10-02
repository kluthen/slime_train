extends SceneTree
## Throughput probe (22f question). Runs a test-mode fixture with the game's
## own step (game.step_simulation, as --run-ticks does) and, per WINDOW ticks,
## counts train slimes crossing loop distances X1/X2, stall moves, stuck
## moves, hops, simulated train slimes, and the bowl's back half.
## THRU_TOT adds the hold guard's releases (Train.hold_counters()).
## Since chunk 22i (D151) THRU_WIN also gives the bucket loads at the
## window's end (bucket_max: the highest load of any loop bucket; buckets_over:
## the buckets over their bucket cap), THRU_TOT the bucket cap's "bucket full"
## holds (bucket_holds=, -1 before the counter exists), and every BUCKET_EVERY
## ticks each loop bucket's load is sampled (Train.bucket_loads(), the switch
## on or off): at the end THRU_BUCKETS lines give each bucket's highest load,
## a histogram (samples by load, every bucket's), and every bucket sampled
## over OVER_LOAD after having been sampled at or under its cap (tick,
## bucket, load, cap; the bowl's starting overfill so stays apart). Read only:
## the final STATE hash is the plain run's.
## godot --headless --path . -s docs/perf/2026-10-01-chunk-22f/probe/thru.gd -- --fixture=stress-moving --seed=N --ticks=T [--level=test] [--loop-buckets] [--loop-bucket-length=PX] [--bucket-cap] [--bucket-cap-density=D]

var fixture := "stress-moving"
var seed_n := 1
var ticks := 10000
var level := "test"
const WINDOW := 600
const X1 := 19000.0
const X2 := 22000.0
const BOWL_LO := 14000.0
const BOWL_HI := 18000.0
## The bucket loads' sampling period, ticks, and the load the user's "never
## more than 15" names (D151).
const BUCKET_EVERY := 60
const OVER_LOAD := 15

## Per loop bucket: its highest sampled load; whether it was sampled at or
## under its cap since it was last listed as going over OVER_LOAD.
var bucket_top := PackedInt32Array()
var bucket_armed := PackedByteArray()
## Samples by load (load -> samples, every bucket's), the samples taken, and
## the listed crossings ("tick=T bucket=B load=L cap=C").
var load_hist := {}
var bucket_samples := 0
var crossings := PackedStringArray()


## Samples each loop bucket's load at `tick` (see the class doc). A recut (a
## gate opening: another bucket count) starts the per-bucket record afresh.
func _sample_buckets(train: Train, tick: int) -> void:
	var loads := train.bucket_loads().loads()
	var caps := train.bucket_loads().caps()
	if loads.size() != bucket_top.size():
		if not bucket_top.is_empty():
			print("THRU_BUCKETS recut tick=%d buckets=%d->%d" % [tick, bucket_top.size(), loads.size()])
		bucket_top = PackedInt32Array()
		bucket_top.resize(loads.size())
		bucket_armed = PackedByteArray()
		bucket_armed.resize(loads.size())
	bucket_samples += 1
	for b in loads.size():
		var weight := loads[b]
		bucket_top[b] = maxi(bucket_top[b], weight)
		load_hist[weight] = load_hist.get(weight, 0) + 1
		if weight <= caps[b]:
			bucket_armed[b] = 1
		elif weight > OVER_LOAD and bucket_armed[b] == 1:
			crossings.append("tick=%d bucket=%d load=%d cap=%d" % [tick, b, weight, caps[b]])
			bucket_armed[b] = 0


## The THRU_BUCKETS lines (see the class doc).
func _print_buckets(train: Train) -> void:
	var caps := train.bucket_loads().caps()
	var top := []
	for b in bucket_top.size():
		if bucket_top[b] > 0:
			top.append("%d:%d/%d" % [b, bucket_top[b], caps[b] if b < caps.size() else -1])
	# buckets_overN: the buckets whose highest sampled load passed OVER_LOAD.
	print("THRU_BUCKETS samples=%d buckets=%d density=%.3f max=%d buckets_over%d=%d crossings=%d" % [
			bucket_samples, bucket_top.size(), train.bucket_loads().density_used(),
			Array(bucket_top).max() if not bucket_top.is_empty() else 0, OVER_LOAD,
			Array(bucket_top).filter(func(x: int) -> bool: return x > OVER_LOAD).size(), crossings.size()])
	print("THRU_BUCKETS top bucket:highest/cap (buckets never loaded left out) ", " ".join(top))
	var keys := load_hist.keys()
	keys.sort()
	var hist := []
	for k in keys:
		hist.append("%d:%d" % [k, load_hist[k]])
	print("THRU_BUCKETS hist load:samples ", " ".join(hist))
	for crossing in crossings:
		print("THRU_BUCKETS over%d %s" % [OVER_LOAD, crossing])


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


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var p := arg.trim_prefix("--").split("=", true, 1)
		if p[0] == "fixture": fixture = p[1]
		if p[0] == "seed": seed_n = int(p[1])
		if p[0] == "ticks": ticks = int(p[1])
		if p[0] == "level": level = p[1]
	var game: Node = load("res://src/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	# --loop-buckets / --loop-bucket-length=PX (chunk 22g), forwarded: main.gd reads them only as the current scene.
	var bucket_errs: PackedStringArray = game.use_loop_buckets(OS.get_cmdline_user_args())
	if not bucket_errs.is_empty():
		print("ERR ", bucket_errs)
		quit(1)
		return
	var parsed: Dictionary = load("res://src/test_mode/test_mode.gd").config_from_args(PackedStringArray(
			["--test-mode", "--level=" + level, "--fixture=" + fixture, "--seed=%d" % seed_n]))
	if not parsed["errors"].is_empty():
		print("ERR ", parsed["errors"])
		quit(1)
		return
	var errs = game.enable_test_mode(parsed["config"])
	if not errs.is_empty():
		print("ERR ", errs)
		quit(1)
		return
	var sim: Simulation = game.simulation
	var train: Train = sim.train
	var bodies: SlimeBodies = sim.slimes
	var length := train.length()
	print("THRU fixture=%s seed=%d tick0=%d slimes=%d loop_len=%.0f" % [fixture, seed_n, sim.tick, bodies.slime_count, length])
	print("THRU_HDR win_end,x19,x22,stall,oob,stuck,hops,sim_train,all_train,bowl_n,back_mean,back_adv,bucket_max,buckets_over")
	var prev := {}
	for id in train.tracked_ids():
		prev[id] = train.distance_of(id)
	var w := {"x1": 0, "x2": 0, "stall": 0, "oob": 0, "stuck": 0}
	var hops0: int = train.hops_taken
	var tot := {"x1": 0, "x2": 0, "stall": 0, "oob": 0, "stuck": 0}
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
				if d >= p and d - p < 5000.0:
					if p < X1 and d >= X1:
						w["x1"] += 1
					if p < X2 and d >= X2:
						w["x2"] += 1
		prev = now
		if sim.tick % BUCKET_EVERY == 0:
			_sample_buckets(train, sim.tick)
		for e in train.stalled:
			if e["tick"] == t:
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
			# Mean advance over the window of the back half at the window's start.
			var adv := 0.0
			var adv_n := 0
			for b in back0:
				if now.has(b[1]):
					var d2: float = now[b[1]]
					if d2 >= b[0] - 100.0:
						adv += d2 - b[0]
						adv_n += 1
			adv = adv / maxf(adv_n, 1)
			back0 = back
			var hops: int = train.hops_taken - hops0
			hops0 = train.hops_taken
			var loads := train.bucket_loads()
			print("THRU_WIN %d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%.0f,%.0f,%d,%d" % [sim.tick, w["x1"], w["x2"], w["stall"],
					w["oob"], w["stuck"], hops, sim_train, all_train, bowl_n, mean, adv, loads.max_load(),
					loads.over_count()])
			for k in w:
				tot[k] += w[k]
				w[k] = 0
	var hc: Dictionary = train.hold_counters()
	print("THRU_TOT tick=%d x19=%d x22=%d stall=%d oob=%d stuck=%d hops=%d guard=%d first_stall=%d bucket_holds=%d" % [
			sim.tick, tot["x1"], tot["x2"], tot["stall"], tot["oob"], tot["stuck"], train.hops_taken,
			hc["guard_releases"], first_stall, hc.get("bucket_holds", -1)])
	_print_buckets(train)
	# Where the train slimes are at the end: 2000 px bins of loop distance.
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
	print("STATE tick=%d hash=%s" % [sim.tick, sim.state_hash()])
	quit(0)
