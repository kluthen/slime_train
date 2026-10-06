extends SceneTree
## EXPERIMENT (exp/geyser): rule 24's checks (D157 (4)) at the loop's start
## over a long headless run of a test-level fixture, with or without the
## geyser (src/sim/geyser.gd; --no-geyser turns it off, same build). Stepped
## with the game's own step (game.step_simulation, as --run-ticks does), read
## only: the final STATE hash is a plain run's. Not a test.
##
## Run:   godot --headless --no-header --path . -s res://tools/geyser_probe.gd --
##            [--fixture=s3-basket-59of60] [--seed=1] [--ticks=10000]
##            [--census-at=T1,T2,...] [--no-geyser] [--geyser-solo]
##            [--geyser-high] [--geyser-rate]
##            [--tick=gdscript] [--hold-view=X,Y --hold-from=T]
##            [--trace=N --trace-from=T]
##
## "Near the start": a slime's centre within NEAR px of the loop's start
## point (D150's landing stretch is the loop's first 240 px).
## Output (one line each):
##   GP          fixture, seed, geyser on/off, tick kind, start point
##   GP_WIN      every WINDOW ticks: tick; arr (arrivals: a train slime's
##               laps went up, the return route's end); dep (train slimes
##               crossing loop distance DEPART forward: leaving the first
##               stretch); clu_max (the largest awake cluster with a slime
##               near the start, max over the window); near_max (slimes
##               near the start, any calm); stuck (stuck moves), stuck_arr
##               (of slimes that arrived within ARRIVAL_TICKS before),
##               stall, oob
##   GP_TOT      the totals, and: clu_max, clu_mean, clu_over (ticks with
##               that cluster above LIMIT), clu_run (the longest run of such
##               ticks), near_mean, near_max, clear_med / clear_p90 (ticks
##               from arrival to crossing DEPART, of the arrivals that did),
##               not_clear (arrivals that hadn't when the run ended),
##               landed_off (arrivals that LANDED_CHECK ticks after arriving
##               are no train slime, outside every split zone, more than
##               OFF_LOOP px from their loop point, or out of bounds),
##               back (arrivals still short of BACK_AT px along the loop
##               LANDED_CHECK ticks on), launches, refused, carried (Geyser
##               counters; launches include the carried ones)
##   GP_LATE     from tick LATE_FROM on (the arrivals' part): per 600 ticks,
##               arr and the forward crossings of each CROSS_AT loop
##               distance (x240 is dep); pocket_mean (train slimes behind
##               the loop's start, near it: x below it, sampled every 60
##               ticks); tick_ms mean and p95 (game.step_simulation, wall
##               clock, headless); the geyser's lift counters
##   GP_OFF      the first OFF_SHOWN arrivals counted in landed_off: their
##               centre, their loop point, the loop distance nearest them,
##               the slimes right under them
##   GP_CENSUS   at each --census-at tick: the slimes near the start by state,
##               calm, support and hold (SlimeCensus' tokens)
##   STATE       the final tick and state hash
# @spec-link [[req_platform_and_performance_targets]]

const WINDOW := 600
const NEAR := 240.0
const DEPART := 240.0
const LIMIT := 20
const ARRIVAL_TICKS := 600
const LANDED_CHECK := 180
const OFF_LOOP := 80.0
const MAX_STEP := 5000.0
## An arrival still short of this loop distance LANDED_CHECK ticks on is
## counted as back at the start (`back`: smothered, or never launched).
const BACK_AT := 100.0
## Where the GP_LATE crossings are counted, px along the loop.
const CROSS_AT := [240.0, 500.0, 750.0, 1000.0, 1500.0]
## GP_LATE's part of the run starts here (arrivals start about tick 9000).
const LATE_FROM := 9000
## How many landings off the loop GP_OFF shows (where, what is under them).
const OFF_SHOWN := 12
## GP_HIST's pile over the hole: slimes within this many px of the start's x.
const STACK_X := 60.0

var fixture := "s3-basket-59of60"
var seed_n := 1
var ticks := 10000
var census_at := PackedInt32Array()
## --trace=N: the first N arrivals' centres every TRACE_EVERY ticks for
## TRACE_TICKS ticks (GP_TRACE).
var trace_n := 0
var trace_from := 0
## --hold-view=X,Y: the camera put back there after every step (the
## start area watched throughout, whatever the idle camera follows).
var hold_view := Vector2.INF
## --hold-from=T: from tick T on (default 0). Held from the start, section
## 3's basket is never in view, never fires, and nobody comes home.
var hold_from := 0
const TRACE_EVERY := 6
const TRACE_TICKS := 180


func _initialize() -> void:
	var problem := _parse()
	if problem != "":
		printerr("geyser_probe: ", problem)
		quit(2)
		return
	var game: Node = load("res://src/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var parsed: Dictionary = load("res://src/test_mode/test_mode.gd").config_from_args(PackedStringArray(
			["--test-mode", "--level=test", "--fixture=" + fixture, "--seed=%d" % seed_n]))
	var errs: PackedStringArray = game.enable_test_mode(parsed["config"])
	if not errs.is_empty():
		printerr("geyser_probe: ", errs)
		quit(2)
		return
	_run(game)
	quit(0)


## Reads the user arguments; returns the problem, or "" when valid.
func _parse() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg in ["--no-geyser", "--geyser-solo", "--geyser-high", "--geyser-rate"] or arg.begins_with("--tick="):
			continue
		var p := arg.trim_prefix("--").split("=", true, 1)
		if p.size() != 2:
			return "expected --name=value, got '%s'" % arg
		match p[0]:
			"fixture":
				fixture = p[1]
			"seed":
				seed_n = int(p[1])
			"ticks":
				ticks = int(p[1])
			"trace":
				trace_n = int(p[1])
			"hold-view":
				var xy := p[1].split(",")
				hold_view = Vector2(float(xy[0]), float(xy[1]))
			"hold-from":
				hold_from = int(p[1])
			"trace-from":
				trace_from = int(p[1])
			"census-at":
				for t in p[1].split(","):
					census_at.append(int(t))
			_:
				return "unknown argument '%s'" % arg
	return ""


func _run(game: Node) -> void:
	var sim: Simulation = game.simulation
	var train: Train = sim.train
	var bodies: SlimeBodies = sim.slimes
	var start := train.position_at(0.0)
	print("GP fixture=%s seed=%d geyser=%s carry=%s wide=%s land=%.0f-%.0f rate=%s tick=%s start=%s tick0=%d slimes=%d" % [fixture, seed_n,
			"on" if sim.geyser.enabled else "off", sim.geyser.carry, sim.geyser.wide, sim.geyser.land_min,
			sim.geyser.land_max, sim.geyser.by_rate, "native" if bodies.uses_native() else "gdscript", start,
			sim.tick, bodies.slime_count])
	var laps := {}
	var dist := {}
	for id in train.tracked_ids():
		laps[id] = train.laps_of(id)
		dist[id] = train.distance_of(id)
	var arrived := {}  # id -> last arrival tick
	var pending_clear := {}  # id -> arrival tick, until it crosses DEPART
	var to_check := []  # [check tick, id]
	var clear_times := PackedInt32Array()
	var w := _zero()
	var tot := _zero()
	var clu_sum := 0.0
	var clu_over := 0
	var clu_run := 0
	var clu_run_max := 0
	var near_sum := 0.0
	var landed_off := 0
	var traced := {}  # id -> arrival tick
	var fell_back := 0
	var off_kinds := {}
	var off_shown := 0
	var late_arr := 0
	var late_cross := PackedInt32Array()
	late_cross.resize(CROSS_AT.size())
	var pocket_sum := 0
	var pocket_n := 0
	var step_us := PackedInt32Array()
	for i in ticks:
		var t0 := Time.get_ticks_usec()
		game.step_simulation()
		if sim.tick > LATE_FROM:
			step_us.append(Time.get_ticks_usec() - t0)
		if hold_view != Vector2.INF and sim.tick >= hold_from:
			sim.camera.position = hold_view
		var t := sim.tick - 1
		for id in train.tracked_ids():
			var l := train.laps_of(id)
			var d := train.distance_of(id)
			if laps.has(id) and l > laps[id]:
				w["arr"] += 1
				if t >= LATE_FROM:
					late_arr += 1
				arrived[id] = t
				pending_clear[id] = t
				to_check.append([t + LANDED_CHECK, id])
				if traced.size() < trace_n and t >= trace_from:
					traced[id] = t
			if dist.has(id):
				var p: float = dist[id]
				if t >= LATE_FROM and d >= p and d - p < MAX_STEP:
					for c in CROSS_AT.size():
						if p < CROSS_AT[c] and d >= CROSS_AT[c]:
							late_cross[c] += 1
				if d >= p and d - p < MAX_STEP and p < DEPART and d >= DEPART:
					w["dep"] += 1
					if pending_clear.has(id):
						clear_times.append(t - pending_clear[id])
						pending_clear.erase(id)
			laps[id] = l
			dist[id] = d
		for e in train.stalled:
			if e["tick"] == t:
				w["stall" if e["reason"] == Train.STALLED else "oob"] += 1
				pending_clear.erase(e["id"])
		for e in sim.stuck_slimes.stuck:
			if e["tick"] == t and e["moved"]:
				w["stuck"] += 1
				if arrived.has(e["id"]) and t - arrived[e["id"]] <= ARRIVAL_TICKS:
					w["stuck_arr"] += 1
				pending_clear.erase(e["id"])
		while not to_check.is_empty() and to_check[0][0] <= t:
			var kind := _landed_off(sim, to_check[0][1])
			var checked: int = to_check[0][1]
			if bodies.has(checked) and train.tracks(checked) and train.distance_of(checked) < BACK_AT:
				fell_back += 1
			if kind != "" and off_shown < OFF_SHOWN and bodies.has(checked):
				off_shown += 1
				var c := bodies.centre_of(checked)
				var under := 0
				for other in bodies.ids():
					var q := bodies.centre_of(other)
					if other != checked and absf(q.x - c.x) < 30.0 and q.y > c.y and q.y - c.y < 60.0:
						under += 1
				print("GP_OFF id=%d kind=%s pos=%s loop_pt=%s dist=%.0f near_d=%.0f under=%d supported=%d" % [checked,
						kind, c.round(), train.position_at(train.distance_of(checked)).round(), train.distance_of(checked),
						train._closest_distance(c), under, bodies.supported[bodies.index_of(checked)]])
			if kind != "":
				landed_off += 1
				off_kinds[kind] = off_kinds.get(kind, 0) + 1
			to_check.pop_front()
		for id in traced:
			var age: int = t - traced[id]
			if age <= TRACE_TICKS and (age % TRACE_EVERY == 0 or age < 12) and bodies.has(id):
				var s := bodies.index_of(id)
				var touch := []
				for pair: Vector2i in bodies.touching_pairs():
					if pair.x == id or pair.y == id:
						var o := pair.y if pair.x == id else pair.x
						touch.append("%d@%s" % [o, bodies.centre_of(o).round()])
				print("GP_TRACE id=%d age=%d pos=%s vel=%s sup=%d calm=%d dist=%.0f touch=%s" % [id, age,
						bodies.centre_of(id).round(), bodies.velocity_of(id).round(), bodies.supported[s],
						bodies.calm[s], train.distance_of(id), ",".join(touch)])
		var near := _near_count(bodies, start)
		var clu := _cluster_near(bodies, start)
		w["clu_max"] = maxi(w["clu_max"], clu)
		w["near_max"] = maxi(w["near_max"], near)
		clu_sum += clu
		near_sum += near
		if clu > LIMIT:
			clu_over += 1
			clu_run += 1
			clu_run_max = maxi(clu_run_max, clu_run)
		else:
			clu_run = 0
		if t >= LATE_FROM and t % 60 == 0:
			pocket_sum += _pocket(sim, start)
			pocket_n += 1
		if census_at.has(t):
			_census(sim, start, t)
		if sim.tick % WINDOW == 0 or i == ticks - 1:
			print("GP_WIN tick=%d arr=%d dep=%d clu_max=%d near_max=%d stuck=%d stuck_arr=%d stall=%d oob=%d cam=%s" % [
					sim.tick, w["arr"], w["dep"], w["clu_max"], w["near_max"], w["stuck"], w["stuck_arr"],
					w["stall"], w["oob"], sim.view.centre.round()])
			for k in w:
				if k.ends_with("_max"):
					tot[k] = maxi(tot[k], w[k])
				else:
					tot[k] += w[k]
			w = _zero()
	clear_times.sort()
	var med := clear_times[clear_times.size() / 2] if not clear_times.is_empty() else -1
	var p90 := clear_times[int(clear_times.size() * 0.9)] if not clear_times.is_empty() else -1
	print(("GP_TOT tick=%d arr=%d dep=%d stuck=%d stuck_arr=%d stall=%d oob=%d clu_max=%d clu_mean=%.2f"
			+ " clu_over=%d clu_run=%d near_mean=%.2f near_max=%d clear_med=%d clear_p90=%d not_clear=%d"
			+ " landed_off=%d %s back=%d launches=%d refused=%d carried=%d") % [sim.tick, tot["arr"], tot["dep"], tot["stuck"],
			tot["stuck_arr"], tot["stall"], tot["oob"], tot["clu_max"], clu_sum / ticks, clu_over, clu_run_max,
			near_sum / ticks, tot["near_max"], med, p90, pending_clear.size(), landed_off, off_kinds, fell_back,
			sim.geyser.launches, sim.geyser.refused, sim.geyser.carried])
	var late_windows := maxf(1.0, (sim.tick - LATE_FROM) / float(WINDOW))
	var cross := []
	for c in CROSS_AT.size():
		cross.append("x%d=%.1f" % [CROSS_AT[c], late_cross[c] / late_windows])
	step_us.sort()
	var ms_mean := 0.0
	for us in step_us:
		ms_mean += us
	ms_mean = ms_mean / maxf(1.0, step_us.size()) / 1000.0
	var ms_p95 := step_us[int(step_us.size() * 0.95)] / 1000.0 if not step_us.is_empty() else -1.0
	var geyser := sim.geyser
	print("GP_LATE from=%d arr=%.1f %s pocket_mean=%.1f tick_ms=%.2f p95=%.2f lifted=%d lift_mean=%.0f lift_max=%.0f" % [
			LATE_FROM, late_arr / late_windows, " ".join(cross), pocket_sum / maxf(1.0, pocket_n), ms_mean, ms_p95,
			geyser.lifted, geyser.lift_total / maxf(1.0, geyser.lifted), geyser.lift_highest])
	print("STATE tick=%d hash=%s" % [sim.tick, sim.state_hash()])


func _zero() -> Dictionary:
	return {"arr": 0, "dep": 0, "clu_max": 0, "near_max": 0, "stuck": 0, "stuck_arr": 0, "stall": 0, "oob": 0}


## Why arrival `slime_id` landed off, LANDED_CHECK ticks on ("" when fine).
func _landed_off(sim: Simulation, slime_id: int) -> String:
	var bodies := sim.slimes
	if not bodies.has(slime_id):
		return "gone"
	if bodies.state_of(slime_id) != SlimeBodies.TRAIN:
		return "state_%s" % SlimeBodies.STATE_NAMES[bodies.state_of(slime_id)]
	var c := bodies.centre_of(slime_id)
	if sim.train.is_out_of_bounds(c):
		return "oob"
	if not sim.train.tracks(slime_id):
		return "untracked"
	if c.distance_to(sim.train.position_at(sim.train.distance_of(slime_id))) > OFF_LOOP:
		return "off_loop"
	return ""


func _near_count(bodies: SlimeBodies, start: Vector2) -> int:
	var n := 0
	for s in bodies.slime_count:
		if bodies.centre_of(bodies.id[s]).distance_to(start) <= NEAR:
			n += 1
	return n


## The largest awake cluster (DebugCounts' rule) with a member near the start.
func _cluster_near(bodies: SlimeBodies, start: Vector2) -> int:
	var physics := DebugCounts.physics_slime_ids(bodies)
	var pairs: Array = DebugCounts.touching_by_distance(bodies, physics) if bodies.candidate_pair_count() == 0 \
			else bodies.touching_pairs()
	var index := {}
	for i in physics.size():
		index[physics[i]] = i
	var parent := PackedInt32Array()
	parent.resize(physics.size())
	for i in physics.size():
		parent[i] = i
	for pair: Vector2i in pairs:
		if not (index.has(pair.x) and index.has(pair.y)):
			continue
		var a := _root(parent, index[pair.x])
		var b := _root(parent, index[pair.y])
		if a != b:
			parent[b] = a
	var size := {}
	var near := {}
	for i in physics.size():
		var r := _root(parent, i)
		size[r] = size.get(r, 0) + 1
		if bodies.centre_of(physics[i]).distance_to(start) <= NEAR:
			near[r] = true
	var best := 0
	for r in near:
		best = maxi(best, size[r])
	return best


func _root(parent: PackedInt32Array, i: int) -> int:
	while parent[i] != i:
		parent[i] = parent[parent[i]]
		i = parent[i]
	return i


## GP_CENSUS: the census tokens of the slimes near the start, counted.
func _census(sim: Simulation, start: Vector2, t: int) -> void:
	var counts := {}
	var n := 0
	for line in SlimeCensus.lines(sim, "probe", fixture):
		var tokens := {}
		for part in line.split(" "):
			var kv := part.split("=", true, 1)
			if kv.size() == 2:
				tokens[kv[0]] = kv[1]
		if not tokens.has("pos"):
			continue
		var xy: PackedStringArray = tokens["pos"].split(",")
		if xy.size() != 2 or Vector2(float(xy[0]), float(xy[1])).distance_to(start) > NEAR:
			continue
		n += 1
		for key in ["state", "calm", "supported", "hold", "in_air", "stuck", "next_kind"]:
			if tokens.has(key):
				var k := "%s=%s" % [key, tokens[key]]
				counts[k] = counts.get(k, 0) + 1
	var keys := counts.keys()
	keys.sort()
	var parts := []
	for k in keys:
		parts.append("%s:%d" % [k, counts[k]])
	print("GP_CENSUS tick=%d near=%d %s" % [t, n, " ".join(parts)])
	# Where the train slimes of the first 1000 px are: 100 px bins of loop
	# distance, and those in the pocket (behind the loop's start: near it, x
	# below it).
	var bins := {}
	var bodies := sim.slimes
	for id in sim.train.tracked_ids():
		var d := sim.train.distance_of(id)
		if d < 2000.0:
			var b := int(d / 100.0)
			bins[b] = bins.get(b, 0) + 1
	var hist := []
	for b in range(20):
		hist.append("%d:%d" % [b * 100, bins.get(b, 0)])
	# The pile over the hole: the highest ring top within STACK_X px of the
	# start's x, near the start (start.y less it: the pile's height).
	var top := start.y
	for s in bodies.slime_count:
		var c := bodies.centre_of(bodies.id[s])
		if absf(c.x - start.x) < STACK_X and c.distance_to(start) <= NEAR:
			top = minf(top, c.y - bodies.radius_of(bodies.id[s]))
	print("GP_HIST tick=%d pocket=%d stack=%.0f %s" % [t, _pocket(sim, start), start.y - top, " ".join(hist)])


## The train slimes in the pocket behind the loop's start: near it, x below it.
func _pocket(sim: Simulation, start: Vector2) -> int:
	var pocket := 0
	var bodies := sim.slimes
	for id in sim.train.tracked_ids():
		if bodies.centre_of(id).x < start.x and bodies.centre_of(id).distance_to(start) <= NEAR:
			pocket += 1
	return pocket
